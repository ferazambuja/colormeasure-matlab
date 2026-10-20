classdef PR655 < handle
    % PR655 Serial control of PR-655, with tentative PR-670 support.
    %   pr = colormeasure.drivers.pr.PR655('COM3') selects a Windows port explicitly.
    %   pr = colormeasure.drivers.pr.PR655() tries one available port, then verifies the model.
    %   Multiple candidates require an explicit port; devices are not scanned.
    %   pr = colormeasure.drivers.pr.PR655(port, 'Timeout', 300) sets the measurement timeout (s).
    %   pr = colormeasure.drivers.pr.PR655(port, 'Metadata', true) enables extra read-only reports.
    %   pr = colormeasure.drivers.pr.PR655(port, 'Clock', clock) runs deadlines and pacing on a
    %   clock with now and sleep (test seam; the default is the wall clock).
    %   Metadata queries are disabled by default pending physical validation.
    %   measurement = pr.measure() returns one spectrum and updates history.
    %   See docs/drivers/pr/README.md for setup and limitations.
    %   Color calculations, scientific sources and inherited XYZ convention:
    %   docs/session/color-science.md (colormeasure.colorimetry.spectra2XYZ).
    %
    %   MCSL PR-655 driver contributors, from repository history:
    %   Tucker Downs: class implementation and updates (2020-2021).
    %   Luke Hellwig: earlier serial routines (2020), class updates (2022).
    %   Driver, documentation and tentative PR-670 improvements (2026):
    %   Fernando Voltolini de Azambuja.
    %   Original copyright is retained in LICENSE.txt at the repository root.
    %   Command pacing and remote-mode initialization adapt Psychtoolbox
    %   PR670write/PR670init; see docs/drivers/pr/THIRD_PARTY_NOTICES.md.

    properties (SetAccess = public)
        radiance = [];
        wl = [];
        XYZ = [];
        flicker = [];
        totalRadiance = [];
        errorCode = [];
    end
    properties (SetAccess = private)
        deviceType = '';
        portName = '';
        Timeout = 300;
        Metadata = false; % Opt in to identity/setup reports after each spectrum.
        instrumentMetadata = struct([]); % One record per successful reading.
    end
    properties (SetAccess = protected)
        port = [];
    end
    properties (Access = protected)
        clock = []; % now and sleep: the wall clock unless a test injects one.
    end
    properties (Access = private)
        Transport = [];
        receiveBuffer = '';
        expectedWavelengths = [];
        needsReconnect = false;
        writeFailed = false; % A partial command forbids further serial writes.
        identityCache = struct();
        connectionCleanupConfirmed = true;
    end

    properties (Constant, Access = private)
        % Resource policy per raw CR/LF-delimited line, not a manufacturer maximum.
        MaxReplyLineBytes = 4096;
    end

    methods
        function obj = PR655(portID, varargin)
            if nargin == 0
                portID = '';
            end
            if ~(ischar(portID) && (isrow(portID) || isempty(portID))) && ...
                    ~(isstring(portID) && isscalar(portID) && ~ismissing(portID))
                error('PR655:InvalidPort', 'Port must be a character vector or a scalar string.');
            end
            portID = char(portID);
            options = inputParser;
            options.addParameter('Timeout', 300, ...
                @(x) isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x) && x > 0);
            options.addParameter('Metadata', false, @(x) islogical(x) && isscalar(x));
            % Transport substitutes the serial port object; the protocol,
            % pacing and parsing run unchanged against it (tests, simulators).
            options.addParameter('Transport', [], @(x) isempty(x) || (isobject(x) && isscalar(x)));
            % Clock substitutes the wall clock behind every deadline and pacing
            % wait; the loop and its intervals are unchanged (deadline tests).
            options.addParameter('Clock', [], @(x) isempty(x) || (isobject(x) && isscalar(x)));
            options.parse(varargin{:});
            obj.Timeout = options.Results.Timeout;
            obj.Metadata = options.Results.Metadata;
            obj.Transport = options.Results.Transport;
            obj.clock = options.Results.Clock;
            if isempty(obj.clock), obj.clock = colormeasure.drivers.RealClock(); end

            try
                % Selection precedes acquisition. Its refusal leaves this
                % owner's initial confirmed-closed state unchanged.
                portID = colormeasure.session.choosePort(portID, ...
                    @() obj.listPorts('available'), 'PR655', obj.isMac());
                obj.connectionCleanupConfirmed = false;
                obj.port = obj.openConnection(portID);
                obj.writeFailed = true; % No cleanup write before deadlines are configured.
                colormeasure.drivers.configureSerialWrites(obj.port, obj.commandTimeout());
                obj.writeFailed = false;
                obj.portName = portID;
                obj.resetInput();
                obj.writeCommand('Q', false);
                % Psychtoolbox allows the meter to leave remote mode first.
                obj.clock.sleep(0.5);
                obj.resetInput();
                obj.writeCommand('PHOTO', false);
                reply = obj.readReply('PHOTO', obj.clock.now(), min(10, obj.Timeout));
                if ~strcmp(reply, 'REMOTE MODE')
                    error('PR655:RemoteMode', 'Expected REMOTE MODE from %s; received "%s".', portID, reply);
                end

                fields = obj.checkedFields(obj.requestLine('D111'), 'D111');
                if numel(fields) ~= 2
                    error('PR655:InvalidResponse', 'Expected status and model name in the D111 response.');
                end
                obj.deviceType = strtrim(fields{2});
                switch obj.deviceType
                    case 'PR-655'
                        obj.expectedWavelengths = (380:4:780)';
                    case 'PR-670'
                        obj.expectedWavelengths = (380:2:780)';
                    otherwise
                        error('PR655:UnsupportedModel', ...
                            'Instrument reported "%s"; this driver supports PR-655 and PR-670.', obj.deviceType);
                end
            catch err
                if ~isempty(obj.port)
                    try
                        obj.writeCommand('Q', false);
                    catch
                        % Preserve the initialization error if unplugged.
                    end
                end
                closed=false;
                try
                    closed=obj.closePort();
                catch cleanupError
                    err=addCause(err,cleanupError);
                end
                if closed
                    err=colormeasure.drivers.confirmedConnectionFailure(err);
                end
                rethrow(err);
            end
        end

        function measurement = measure(obj)
            % Return one spectrum and preserve earlier successful measurements.
            % unitsCode preserves the instrument header. XYZ assumes a spectral
            % radiance measurement with the appropriate optical accessory.
            obj.requireReady();
            % Stay uncertain until a complete response has been validated.
            % Cleanup acknowledgements cannot account for late spectral bytes.
            obj.needsReconnect = true;
            restore = onCleanup(@() obj.restoreBacklight());
            try
                obj.setBacklight(0);
                obj.resetInput();
                obj.writeCommand('M5');
                started = obj.clock.now();
                fields = obj.checkedFields(obj.readReply('M5', started, obj.Timeout), 'M5');
                if numel(fields) ~= 5
                    error('PR655:InvalidResponse', 'Expected five fields in the M5 spectral header.');
                end
                metadata = obj.checkedNumbers(strjoin(fields,','),5,'PR655:InvalidResponse', ...
                    'M5 spectral header must contain finite real numbers.');

                % Native sample count marks completion, even when packets
                % arrive with gaps. A temporary empty buffer is not the end.
                wavelengths = obj.expectedWavelengths;
                spectrum = zeros(size(wavelengths));
                for row = 1:numel(wavelengths)
                    line = obj.readLine(started, obj.Timeout, 'M5');
                    numbers = obj.checkedNumbers(line,2,'PR655:InvalidSpectrum', ...
                        sprintf('Invalid spectral row %d: "%s".',row,line));
                    if numbers(1) ~= wavelengths(row)
                        error('PR655:WavelengthGrid', ...
                            'Expected %g nm at row %d for %s; received %g nm.', ...
                            wavelengths(row), row, obj.deviceType, numbers(1));
                    end
                    spectrum(row) = numbers(2);
                end

                % Refuse surplus data already received with the native grid.
                % This does not infer completion from a pause between packets.
                obj.checkSurplus('M5','PR655:InvalidSpectrum', ...
                    'M5 returned extra data beyond its native spectral grid.');

                obj.needsReconnect = false;
                % Convert only the new spectrum, not the accumulated history.
                xyz = colormeasure.colorimetry.spectra2XYZ(spectrum, wavelengths);
                total = colormeasure.colorimetry.spectralIntegral(spectrum, wavelengths);
                stored = colormeasure.drivers.pr.storedText();
                measurement = struct('radiance', spectrum, 'lambda', wavelengths, ...
                    'XYZ', xyz, 'xyzMethod', stored.xyzMethod, ...
                    'totalRadiance', total, 'deviceType', obj.deviceType, ...
                    'unitsCode', metadata(2), 'peakWavelength', metadata(3), ...
                    'instrumentTotalRadiance', metadata(4), ...
                    'integratedPhotonRadiance', metadata(5), 'isSynthetic', false);
                % Explicitly enabled read-only reports follow the complete M5.
                % Otherwise retain the schema with unavailable/notQueried values.
                % A metadata failure retains this spectrum; an uncertain reply
                % prevents another exchange until the connection is replaced.
                measurement.instrumentMetadata = obj.captureMetadata();
                % Commit a successful measurement only after validation.
                obj.radiance(:, end+1) = spectrum;
                obj.wl = wavelengths;
                obj.XYZ(end+1, :) = xyz;
                obj.totalRadiance(end+1) = total;
                if isempty(obj.instrumentMetadata)
                    obj.instrumentMetadata = measurement.instrumentMetadata;
                else
                    obj.instrumentMetadata(end+1) = measurement.instrumentMetadata;
                end
                obj.errorCode = [];
            catch err
                if strcmp(err.identifier, 'PR655:InstrumentError')
                    % A terminated, standalone error is a complete reply.
                    obj.needsReconnect = false;
                end
                obj.errorCode = err;
                rethrow(err);
            end
        end

        function report = readSettings(obj)
            % Explicit read-only inspection; no exposure or setter commands.
            % Catalog discovery is opt-in through this call, not constructor I/O.
            obj.requireReady();
            report = obj.readSettingsReport(true);
        end

        function receipt = applyAutomaticSettings(obj, overrides)
            % Normal session policy. Native measure() itself remains unchanged.
            if nargin < 2, overrides = struct(); end
            receipt = obj.applySettings(colormeasure.drivers.pr.automaticSettings(overrides));
        end

        function receipt = applySettings(obj, overrides)
            % Explicit partial setter. An empty struct performs no serial I/O.
            % Validate the whole request before its first setter. A failed
            % receipt can describe partial changes; there is no automatic undo.
            colormeasure.drivers.pr.settingsCommands(overrides, obj.deviceType, []);
            receipt = colormeasure.drivers.pr.settingsReceipt(overrides);
            if isempty(fieldnames(overrides)), return; end
            try
                obj.requireReady();
                dynamic = {'primaryAccessoryId','addon1Id','addon2Id','addon3Id','apertureId'};
                discover = any(ismember(fieldnames(overrides), dynamic));
                receipt.before = obj.readSettingsReport(discover);
                obj.requireReady();
                commands = colormeasure.drivers.pr.settingsCommands(overrides, obj.deviceType, receipt.before);
                for index = 1:numel(commands)
                    command = commands{index};
                    receipt.commands{end+1} = command;
                    response = obj.settingsQuery(command, 1);
                    receipt.acknowledgements(end+1) = struct('command',command, ...
                        'rawReply',response.rawReply,'status',response.status);
                    if ~strcmp(response.status,'available')
                        error(response.errorIdentifier, '%s', response.errorMessage);
                    end
                    if numel(response.fields{1}) ~= 1
                        error('PR655:InvalidResponse','%s did not return a standalone acknowledgement.',command);
                    end
                end
                if isempty(commands)
                    receipt.after = receipt.before;
                    return
                end
                receipt.after = obj.readSettingsReport(false);
                obj.requireReady();
                % A known contradictory readback is failure. Missing readback
                % remains unknown (notably SZ); acknowledgements stay separate.
                requestedIds = fieldnames(overrides);
                for index = 1:numel(requestedIds)
                    id = requestedIds{index}; actual = receipt.after.values.(id);
                    known = ~(isempty(actual) || (isnumeric(actual)&&isnan(actual)));
                    expected = overrides.(id);
                    if isstring(expected), expected = char(expected); end
                    if known && ~isequal(actual,expected)
                        error('PR655:SettingsMismatch','%s readback differs from the requested value.',id);
                    end
                end
                receipt.status = 'applied';
            catch problem
                receipt.status = 'failed';
                receipt.error = struct('identifier',problem.identifier,'message',problem.message);
                if ~isempty(receipt.commands)
                    % Even a clean rejected setter may follow successful writes.
                    % Prevent exposure on this object after partial application.
                    obj.needsReconnect = true;
                end
            end
        end

        function getFlicker(obj)
            % Store the Auto Sync frequency reported by D14, in Hz.
            obj.requireReady();
            obj.needsReconnect = true;
            try
                fields = obj.checkedFields(obj.requestLine('D14'), 'D14');
                if numel(fields) ~= 3
                    error('PR655:InvalidResponse', 'Expected status, sync mode and frequency in the D14 response.');
                end
                if strcmp(strtrim(fields{2}), 'Auto Sync')
                    token = regexpi(strtrim(fields{3}), ...
                        '^([0-9]+(?:\.[0-9]*)?)(?:\s+Hertz)?$', 'tokens', 'once');
                    if isempty(token)
                        error('PR655:InvalidResponse', 'D14 returned an invalid sync frequency.');
                    end
                    frequency = str2double(token{1});
                    if ~isfinite(frequency)
                        error('PR655:InvalidResponse', 'D14 returned an invalid sync frequency.');
                    end
                    obj.flicker = frequency;
                else
                    obj.flicker = nan;
                end
                obj.needsReconnect = false;
            catch err
                if strcmp(err.identifier, 'PR655:InstrumentError')
                    obj.needsReconnect = false;
                end
                rethrow(err);
            end
        end

        function yes=canRetryConnectionCleanup(obj)
            % Reachability is not closure proof. An unavailable port owner
            % still leaves cleanup unconfirmed until explicitly resolved.
            yes=~isempty(obj.port)&&isvalid(obj.port);
        end

        function closed=Disconnect(obj)
            if ~isempty(obj.port)
                try
                    if ~obj.writeFailed, obj.writeCommand('Q', false); end
                catch
                    % Release the serial connection even if unplugged.
                end
            end
            closed=obj.closePort();
        end

        function delete(obj)
            obj.Disconnect();
        end
    end

    methods (Access = protected)
        % Keep port creation separate so protocol tests never open hardware.
        function connection = openConnection(obj, portID)
            if ~isempty(obj.Transport), connection = obj.Transport; return, end
            connection = serialport(portID, 115200, ...
                'DataBits', 8, 'StopBits', 1, 'Parity', 'none', ...
                'FlowControl', 'none');
        end

        function ports = listPorts(~, mode)
            ports = serialportlist(mode);
        end

        function yes = isMac(~)
            yes = ismac();
        end
    end

    methods (Access = private)
        function report = readSettingsReport(obj, discover)
            capabilities=struct(); numericFields={}; textSetup=struct();
            identity=struct('model',obj.deviceType,'serialNumber','','softwareVersion','');
            responses=repmat(obj.emptySettingsResponse(''),0,1);
            commands={'D601','D602'};
            if discover,commands=[commands {'D110','D114','D112'}];end
            counts=[];
            for index=1:numel(commands)
                command=commands{index}; response=obj.settingsQuery(command,1);
                if strcmp(response.status,'available')
                    try
                        fields=response.fields{1};
                        switch command
                            case 'D601'
                                colormeasure.drivers.pr.settingsValues(fields); % Validate before retaining.
                                numericFields=fields;
                            case 'D602',textSetup=obj.parseMetadata(command,fields);
                            case 'D110',identity.serialNumber=obj.parseMetadata(command,fields);
                            case 'D114',identity.softwareVersion=obj.parseMetadata(command,fields);
                            case 'D112'
                                if numel(fields)~=3,error('PR655:InvalidResponse','D112 requires two counts.');end
                                counts=str2double(fields(2:3));
                                if ~isreal(counts) || any(~isfinite(counts)|counts<0|counts~=fix(counts)|counts>1024)
                                    error('PR655:InvalidResponse','D112 returned invalid or excessive counts.');
                                end
                        end
                    catch problem
                        response.status='error'; response.errorIdentifier=problem.identifier;
                        response.errorMessage=problem.message; obj.needsReconnect=true;
                    end
                end
                responses(end+1,1)=response; %#ok<AGROW>
            end
            if discover && ~isempty(counts) && ~obj.needsReconnect
                listCommands={'D116','D117'}; fields={'accessories','apertures'};
                for index=1:2
                    if index==2 && ~strcmp(obj.deviceType,'PR-670'),continue;end
                    if counts(index)==0,continue;end
                    response=obj.settingsQuery(listCommands{index},counts(index));
                    if strcmp(response.status,'available')
                        try
                            capabilities.(fields{index})=colormeasure.drivers.pr.parseSettingsList(listCommands{index},response.fields);
                        catch problem
                            response.status='error'; response.errorIdentifier=problem.identifier;
                            response.errorMessage=problem.message; obj.needsReconnect=true;
                        end
                    end
                    responses(end+1,1)=response; %#ok<AGROW>
                end
            end
            values=colormeasure.drivers.pr.settingsValues(numericFields,textSetup);
            capabilities.sensitivityMode=values.sensitivityMode;
            report=struct('values',values,'controls',colormeasure.drivers.pr.settingsCatalog(obj.deviceType,capabilities), ...
                'identity',identity,'readAtUTC',colormeasure.session.utcText(datetime('now','TimeZone','UTC')), ...
                'responses',responses);
        end

        function response = settingsQuery(obj, command, rowCount)
            response=obj.emptySettingsResponse(command);
            if obj.needsReconnect,return;end
            obj.needsReconnect=true;
            lines=cell(1,rowCount); fields=cell(1,rowCount);
            try
                obj.resetInput(); obj.writeCommand(command);
                started=obj.clock.now();
                for index=1:rowCount
                    if index==1
                        lines{index}=obj.readReply(command,started,obj.commandTimeout());
                    else
                        lines{index}=obj.readLine(started,obj.commandTimeout(),command);
                    end
                    response.rawReply=strjoin(lines(1:index),newline);
                    fields{index}=obj.checkedFields(lines{index},command);
                end
                % Check data already received beyond the declared row count.
                % This is not an idle-gap completion rule; delayed surplus
                % bytes still require physical protocol validation.
                obj.checkSurplus(command,'PR655:InvalidResponse', ...
                    sprintf('%s returned extra data beyond its expected rows.',command));
                response.fields=fields; response.status='available';
                obj.needsReconnect=false;
            catch problem
                response.status='error'; response.errorIdentifier=problem.identifier;
                response.errorMessage=problem.message;
                if any(strcmp(problem.identifier,{'PR655:Timeout','PR655:Framing'})) && isempty(response.rawReply)
                    response.rawReply=obj.receiveBuffer; % Bounded incomplete prefix, not parsed.
                end
                if strcmp(problem.identifier,'PR655:InstrumentError') && index==1
                    obj.needsReconnect=false;
                end
            end
        end

        function response = emptySettingsResponse(~, command)
            response=struct('command',command,'status','notQueried','rawReply','', ...
                'fields',{{}},'errorIdentifier','','errorMessage','');
        end

        function requireReady(obj)
            if obj.needsReconnect
                error('PR655:ReconnectRequired', ...
                    ['A previous exchange did not finish cleanly. Wait for the meter to finish, ' ...
                     'delete this object, and reconnect before requesting more data.']);
            end
        end

        function timeout = commandTimeout(obj)
            timeout = min(5, obj.Timeout);
        end

        function resetInput(obj)
            flush(obj.port, 'input');
            obj.receiveBuffer = '';
        end

        function writeCommand(obj, command, appendCR)
            if obj.writeFailed
                error('PR655:ReconnectRequired', ...
                    'A serial write failed. Establish instrument idle, delete this object and reconnect.');
            end
            if nargin < 3 || appendCR
                command = [command char(13)];
            end
            % Manual p. 102 requires individual characters, including M5.
            % Use the 50 ms pacing from Psychtoolbox PR670write.
            try
                colormeasure.drivers.configureSerialWrites(obj.port, obj.commandTimeout());
                for index = 1:numel(command)
                    write(obj.port, command(index), 'char');
                    obj.clock.sleep(0.05);
                end
            catch problem
                % The instrument may have received a command prefix, or
                % deadlines could not be configured. No cleanup or retry
                % command is safe on this connection.
                obj.writeFailed = true;
                obj.needsReconnect = true;
                rethrow(problem);
            end
        end

        function reply = requestLine(obj, command)
            obj.resetInput();
            obj.writeCommand(command);
            reply = obj.readReply(command, obj.clock.now(), obj.commandTimeout());
        end

        function reply = readReply(obj, command, started, timeout)
            reply = obj.readLine(started, timeout, command);
            % E toggles echo. Ignore only the exact echo of this command.
            while strcmp(reply, command)
                reply = obj.readLine(started, timeout, command);
            end
        end

        function line = readLine(obj, started, timeout, command)
            % Lines already received are returned first. Once the deadline has
            % passed the port is read one final time, so a reply that arrived
            % during the last 10 ms poll is returned rather than timed out.
            final = false;
            while true
                delimiter = obj.lineDelimiter(command);
                if ~isempty(delimiter)
                    line = strtrim(obj.receiveBuffer(1:delimiter-1));
                    obj.receiveBuffer = obj.receiveBuffer(delimiter+1:end);
                    if ~isempty(line)
                        return
                    end
                    continue
                end
                if final
                    error('PR655:Timeout', ...
                        'Timed out reading %s after %g seconds. Check the instrument and reconnect before retrying.', ...
                        command, timeout);
                end
                final = obj.clock.now() - started >= timeout;
                available = obj.port.NumBytesAvailable;
                if available > 0
                    obj.collectBytes(available);
                elseif ~final
                    obj.clock.sleep(0.01);
                end
            end
        end

        function delimiter = lineDelimiter(obj, command)
            delimiter = find(obj.receiveBuffer == char(13) | obj.receiveBuffer == newline, 1);
            bytes = numel(obj.receiveBuffer);
            if ~isempty(delimiter), bytes = delimiter - 1; end
            if bytes > obj.MaxReplyLineBytes
                error('PR655:Framing', ...
                    ['%s exceeds the %d-byte reply-line resource limit before CR/LF. ' ...
                     'Reconnect before requesting more data.'],command,obj.MaxReplyLineBytes);
            end
        end

        function count = collectBytes(obj, available)
            % Read only enough to complete a bounded line or prove oversize.
            % Remaining valid lines stay in the port for the next iteration.
            count = min(available,obj.MaxReplyLineBytes + 1 - numel(obj.receiveBuffer));
            bytes = read(obj.port,count,'uint8');
            obj.receiveBuffer = [obj.receiveBuffer char(bytes(:)')];
        end

        function checkSurplus(obj, command, identifier, message)
            % Inspect only bytes available now, without an idle-gap wait or an
            % unbounded allocation. New arrivals do not extend this snapshot.
            remaining = obj.port.NumBytesAvailable;
            while true
                delimiter = obj.lineDelimiter(command);
                if ~isempty(delimiter)
                    if ~isempty(strtrim(obj.receiveBuffer(1:delimiter-1)))
                        error(identifier,'%s',message);
                    end
                    obj.receiveBuffer = obj.receiveBuffer(delimiter+1:end);
                    continue
                end
                if ~isempty(strtrim(obj.receiveBuffer))
                    error(identifier,'%s',message);
                end
                if remaining == 0, return; end
                remaining = remaining - obj.collectBytes(remaining);
            end
        end

        function values = checkedNumbers(~, payload, count, identifier, message)
            % Keep family response identifiers while sharing lexical, finite
            % and underflow validation with the other native transports.
            try
                values=colormeasure.drivers.decimalValues(payload,count,'PR655');
            catch problem
                if ~strcmp(problem.identifier,'PR655:NumericPayload'),rethrow(problem);end
                throw(addCause(MException(identifier,'%s',message),problem));
            end
        end

        function fields = checkedFields(obj, line, command)
            fields = strsplit(line, ',', 'CollapseDelimiters', false);
            status = obj.checkedNumbers(fields{1},1,'PR655:InvalidResponse', ...
                sprintf('%s returned an invalid status: "%s".',command,line));
            if status ~= fix(status)
                error('PR655:InvalidResponse', '%s returned an invalid status: "%s".', command, line);
            end
            if status ~= 0
                % Manual p. 104: errors are standalone negative codes. A
                % stale spectral row (e.g. 380,1) is not an error reply.
                if numel(fields) ~= 1 || status > 0
                    error('PR655:InvalidResponse', ...
                        '%s returned a malformed error response: "%s".', command, line);
                end
                % Rev B, p. 122. A sync error does not establish whether the
                % source is periodic; never change its setup or retry here.
                switch status
                    case -3
                        detail = ['Cannot synchronize to the source: the manual lists frequency ' ...
                            'below 20 Hz, above 400 Hz, or insufficient signal.'];
                    case -9
                        detail = 'Synchronization error.';
                    case -10
                        detail = 'Cannot automatically synchronize to the source.';
                    otherwise
                        detail = '';
                end
                if ~isempty(detail)
                    detail = [detail ' Check source modulation, signal level, and synchronization settings. '];
                end
                error('PR655:InstrumentError', ...
                    '%s returned instrument error %g. %sSee Remote Control Error Codes in the manual.', ...
                    command, status, detail);
            end
        end

        function metadata = captureMetadata(obj)
            % PR-655/670 manual (Rev B), pp. 118-121. Identity is cached only
            % for this connection. D602 is current setup, not proof of the
            % settings used for M5. In Adaptive mode its exposure is zero;
            % D13 separately describes the last measurement's exposure/gain.
            names = {'serialNumber', 'softwareVersion', 'currentSetup', ...
                'lastMeasurementExposure', 'synchronization'};
            commands = {'D110', 'D114', 'D602', 'D13', 'D14'};
            metadata = struct('serialNumber', '', 'softwareVersion', '', ...
                'currentSetup', obj.emptySetup(), ...
                'lastMeasurementExposure', struct('gain', '', 'exposureMilliseconds', nan), ...
                'synchronization', struct('mode', '', 'frequencyHertz', nan), ...
                'queries', struct(), 'metadataQueriesRequireReconnect', false);
            for index = 1:numel(names)
                name = names{index};
                record = struct('command', commands{index}, 'status', 'notQueried', ...
                    'rawReply', '', 'fields', {{}}, 'errorIdentifier', '', 'errorMessage', '');
                if obj.Metadata && ~obj.needsReconnect
                    if index <= 2 && isfield(obj.identityCache, name)
                        cached = obj.identityCache.(name);
                        record = cached.record;
                        metadata.(name) = cached.value;
                    else
                        [record, value] = obj.queryMetadata(record);
                        if strcmp(record.status, 'available')
                            metadata.(name) = value;
                        end
                        if index <= 2 && any(strcmp(record.status, {'available', 'unsupported'}))
                            obj.identityCache.(name) = struct('record', record, ...
                                'value', metadata.(name));
                        end
                    end
                end
                metadata.queries.(name) = record;
            end
            metadata.metadataQueriesRequireReconnect = obj.needsReconnect;
        end

        function [record, value] = queryMetadata(obj, record)
            value = [];
            obj.needsReconnect = true;
            try
                record.rawReply = obj.requestLine(record.command);
                record.fields = strsplit(record.rawReply, ',', 'CollapseDelimiters', false);
                fields = obj.checkedFields(record.rawReply, record.command);
                value = obj.parseMetadata(record.command, fields);
                record.status = 'available';
                obj.needsReconnect = false;
            catch err
                record.status = 'error';
                record.errorIdentifier = err.identifier;
                record.errorMessage = err.message;
                if any(strcmp(err.identifier, {'PR655:Timeout','PR655:Framing'})) && isempty(record.rawReply)
                    record.rawReply = obj.receiveBuffer; % Incomplete, not parsed.
                end
                if strcmp(err.identifier, 'PR655:InstrumentError')
                    % A standalone negative status is a complete response.
                    obj.needsReconnect = false;
                    if ismember(str2double(record.rawReply), [-1000 -1035 -2000])
                        record.status = 'unsupported';
                    end
                end
                % Timeout/malformed replies leave framing uncertain. The
                % remaining optional queries are skipped, without losing M5.
            end
        end

        function value = parseMetadata(obj, command, fields)
            if strcmp(command, 'D602')
                count = 16;
            elseif any(strcmp(command, {'D13', 'D14'}))
                count = 3;
            else
                count = 2;
            end
            if numel(fields) ~= count
                error('PR655:InvalidResponse', '%s returned an unexpected field count.', command);
            end
            for index = 2:numel(fields)
                text = fields{index};
                if isempty(strtrim(text)) || any(isstrprop(text, 'cntrl'))
                    error('PR655:InvalidResponse', '%s returned empty or nonprintable text.', command);
                end
                fields{index} = strtrim(text);
            end
            switch command
                case {'D110', 'D114'}
                    % Serial/version formats are not constrained beyond the
                    % documented single printable, nonempty text field.
                    value = fields{2};
                case 'D602'
                    value = obj.emptySetup();
                    names = fieldnames(value);
                    for index = 1:numel(names)
                        value.(names{index}) = fields{index+1};
                    end
                case 'D13'
                    value = struct('gain', fields{2}, 'exposureMilliseconds', ...
                        obj.metadataNumber(fields{3}, 'msec', command));
                case 'D14'
                    % Use the detailed p.118 Hertz schema, not the conflicting
                    % summary table's description of a period in milliseconds.
                    value = struct('mode', fields{2}, 'frequencyHertz', ...
                        obj.metadataNumber(fields{3}, 'Hertz', command));
            end
        end

        function value = emptySetup(~)
            value = struct('primaryLens', '', 'addon1', '', 'addon2', '', ...
                'addon3', '', 'aperture', '', 'units', '', 'exposureMode', '', ...
                'exposureTime', '', 'gain', '', 'cycles', '', 'observer', '', ...
                'darkMode', '', 'syncMode', '', 'captureMode', '', 'syncFrequency', '');
        end

        function value = metadataNumber(~, text, unit, command)
            pattern = ['^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s+' unit '$'];
            token = regexpi(text, pattern, 'tokens', 'once');
            if isempty(token)
                error('PR655:InvalidResponse', '%s returned an invalid %s value.', command, unit);
            end
            value = str2double(token{1});
            if ~isfinite(value) || value < 0
                error('PR655:InvalidResponse', '%s returned an invalid %s value.', command, unit);
            end
        end

        function setBacklight(obj, percent)
            command = sprintf('B%02d', percent);
            reply = obj.requestLine(command);
            % The manual's reply is "Backlight set to nn %" (p.104). Compare
            % the reported level, so zero padding and spacing do not matter.
            level = regexpi(reply, '^Backlight set to\s*(\d+)\s*%$', 'tokens', 'once');
            if isempty(level) || str2double(level{1}) ~= percent
                obj.checkedFields(reply, command);
                error('PR655:InvalidResponse', 'Unexpected backlight response: "%s".', reply);
            end
        end

        function restoreBacklight(obj)
            if obj.writeFailed, return; end
            wasUncertain = obj.needsReconnect;
            obj.needsReconnect = true;
            try
                obj.setBacklight(100);
                obj.needsReconnect = wasUncertain;
            catch err
                warning('PR655:BacklightRestore', 'Could not restore backlight: %s', err.message);
            end
        end

        function closed=closePort(obj)
            connection = obj.port;
            closed=obj.connectionCleanupConfirmed;
            if ~isempty(connection)&&isvalid(connection)
                try
                    colormeasure.drivers.closeConnection(connection);
                    closed=true;
                catch err
                    closed=false;
                    warning('PR655:ClosePort', 'Could not close serial port: %s', err.message);
                end
            end
            obj.connectionCleanupConfirmed=closed;
            if closed,obj.port=[];end
        end
    end
end

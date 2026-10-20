classdef Instrument < handle
    %INSTRUMENT Shared CR ASCII transport and transactional measurement history.
    % Based on the original drivers by Luke Hellwig, Tucker Downs and Vlad
    % Simion. Protocol: CR Remote Communication 1.36, sections 2.2, 4.3, 4.5.
    % https://www.colorimetryresearch.com/downloads
    % Fernando Voltolini de Azambuja, 2026.
    properties
        % Advanced direct access. Read every reply before calling Measure.
        port
        repeatOnError (1,1) logical = false
        responseTimeout (1,1) double {mustBePositive,mustBeFinite} = 5
        measurementTimeout (1,1) double {mustBePositive,mustBeFinite} = 120
    end
    properties (SetAccess = private)
        XYZ = zeros(0,3)
        CCT = zeros(0,1)
        Duv = zeros(0,1)
        spectralData = []
        wl = []
        integratedSpectrum = zeros(0,1)
        instrumentXYZ = zeros(0,3)
        metadata = struct([])
        identity = struct()
        segmentId = ''
        errorCode = NaN
        recoveryStatus = struct('attempted',false,'discardedBytes',uint8([]), ...
            'quietPeriod',NaN,'timeout',NaN,'quietObserved',false)
    end
    properties (Access = private)
        spectral
        lastSpectrum = []
        receiver
        clock
        streamSynchronized = true
        settingsUncertain = false
        settingsRecoveryRequested = struct()
        lastExchangeResponse = ''
        connectionCleanupConfirmed = true
    end
    methods
        function obj = Instrument(model, portID, varargin)
            obj.segmentId = char(java.util.UUID.randomUUID());
            p = inputParser;
            p.addParameter('Transport', []); % Isolated simulated transport seam.
            p.addParameter('Clock', []); % Deadline clock seam (now, sleep) for tests.
            p.addParameter('PortList', @() serialportlist("available"), ...
                @(x) isa(x,'function_handle')); % Enumeration seam for tests.
            p.addParameter('ResponseTimeout', 5, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>0);
            p.addParameter('MeasurementTimeout', 120, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>0);
            p.addParameter('DiscardPendingInput', false, @(x) islogical(x) && isscalar(x));
            p.addParameter('DrainQuietPeriod', 0.25, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>0);
            p.addParameter('DrainTimeout', 2, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x>0);
            p.parse(varargin{:});
            if p.Results.DrainTimeout <= p.Results.DrainQuietPeriod
                error('CR:DrainOptions', 'DrainTimeout must be greater than DrainQuietPeriod.');
            end
            obj.clock = p.Results.Clock;
            if isempty(obj.clock), obj.clock = colormeasure.drivers.RealClock(); end
            obj.receiver = colormeasure.drivers.LineReceiver(struct('prefix', 'CR', ...
                'timeout', 'Timed out after %.3g seconds waiting for a complete CR reply.', ...
                'overflow', 'Response line exceeds 4096 bytes.', ...
                'overflowUnterminated', 'Response line exceeds 4096 bytes. Check ECHO is off.'), obj.clock);
            obj.responseTimeout = p.Results.ResponseTimeout;
            obj.measurementTimeout = p.Results.MeasurementTimeout;
            obj.spectral = ~strcmp(model, 'CR-100');
            try
                % A selection refusal happens before this owner acquires any
                % port; the existing cleanup witness can prove that state.
                portID = colormeasure.drivers.cr.selectPort(portID, p.Results.PortList);
                obj.connectionCleanupConfirmed=false;
                if isempty(p.Results.Transport)
                    obj.port = serialport(portID, 115200, 'DataBits', 8, ...
                        'StopBits', 1, 'Parity', 'none', 'FlowControl', 'none', ...
                        'Timeout', obj.responseTimeout);
                else
                    obj.port = p.Results.Transport;
                end
                colormeasure.drivers.configureSerialWrites(obj.port, obj.responseTimeout);
                configureTerminator(obj.port, 'CR/LF');
                if p.Results.DiscardPendingInput
                    obj.drainInput(p.Results.DrainQuietPeriod, p.Results.DrainTimeout);
                end
                [actual, ~] = obj.query('RC Model');
                if ~strcmp(actual, model)
                    error('CR:Identity', 'Expected %s, received %s on the selected port.', model, actual);
                end
                [id, ~] = obj.query('RC ID');
                [firmware, ~] = obj.query('RC Firmware');
                if isempty(strtrim(id)) || isempty(strtrim(firmware)) || ...
                        any(id < 32 | id > 126) || any(firmware < 32 | firmware > 126)
                    error('CR:Identity', 'RC ID and RC Firmware must contain nonempty printable ASCII values.');
                end
                obj.ready(); % Reject extra input after the final identity reply.
                obj.identity = struct('model', actual, 'serialNumber', id, ...
                    'firmware', firmware, 'port', char(portID), 'protocol', 'Remote Communication 1.36');
            catch err
                try
                    if obj.Disconnect(),err=colormeasure.drivers.confirmedConnectionFailure(err);end
                catch cleanupError
                    err=addCause(err,cleanupError);
                end
                rethrow(err);
            end
        end

        function Measure(obj)
            % One retained row per successful transaction. A failed call throws
            % and retains no row. Opt-in retries capture a NEW physical sample.
            if obj.settingsUncertain
                error('CR:SettingsUncertain',['A settings application did not complete. ' ...
                    'Successfully reapply the intended settings or reconstruct the connection before measuring.']);
            end
            attempts = 1 + 2*double(obj.repeatOnError);
            attemptResponses = cell(0,1);
            obj.errorCode = NaN;
            try
                for attempt = 1:attempts
                    [~, code, raw] = obj.exchange('M', obj.measurementTimeout);
                    attemptResponses{end+1,1} = raw; %#ok<AGROW>
                    obj.errorCode = code;
                    if code >= 0
                        break
                    end
                    % Only retry documented recoverable measurement errors.
                    if attempt == attempts || ~ismember(code, -306:-302)
                        error('CR:InstrumentError', 'Measurement failed: %s', raw);
                    end
                    warning('CR:NewMeasurement', 'CR error %d: retry %d captures a new sample.', code, attempt);
                end
                [payload, xyzRaw] = obj.query('RM XYZ');
                originalXYZ = colormeasure.drivers.cr.numbers(payload,3);
                stored = colormeasure.drivers.cr.storedText();
                reading = struct('acquiredAt', datetime('now','TimeZone','UTC'), ...
                    'identity', obj.identity, ...
                    'attempts', attempt, 'measurementResponses', {attemptResponses}, ...
                    'xyzResponse', xyzRaw, 'radiometricResponse', '', ...
                    'spectrumResponse', '', 'spectrumLines', {{}}, ...
                    'radiometricType', NaN, ...
                    'radiometricQuantity', '', 'radiometricUnit', '', ...
                    'spectralDensityUnit', '', 'spectralDensityUnitsConfirmed', false, ...
                    'xyzUnit', stored.colorimeterXYZUnits, 'instrumentRadiometricValue', NaN, ...
                    'instrumentPhotonValue', NaN, ...
                    'xyzSource', stored.native, ...
                    'cctSource', 'MATLAB colormeasure.colorimetry.XYZ2CCT, CIE 1960 UCS, MCSL compatibility table');
                if obj.spectral
                    [payload, reading.radiometricResponse] = obj.query('RM Radiometric');
                    units = colormeasure.drivers.cr.numbers(payload,3);
                    % Remote v1.36 section 4.3.1.36; CRI App 1.5.10 section 6.2.
                    % Type describes geometry, not a verified per-nm denominator.
                    if ~ismember(units(1), 0:3)
                        error('CR:Quantity', 'Unknown RM Radiometric type %g; expected an integer from 0 to 3.', units(1));
                    end
                    radiometricUnits = {'W/(m^2 sr)','W/m^2','W/sr','W'};
                    index = units(1)+1;
                    reading.radiometricType = units(1);
                    reading.radiometricQuantity = stored.radiometricQuantities{index};
                    reading.radiometricUnit = radiometricUnits{index};
                    reading.spectralDensityUnit = [stored.radiometricDensityUnits{index} stored.provisionalSuffix];
                    reading.xyzUnit = [stored.radiometricXYZUnits{index} stored.provisionalSuffix];
                    reading.instrumentRadiometricValue = units(2);
                    reading.instrumentPhotonValue = units(3);
                    [grid, spectrum, header, lines] = obj.readSpectrum();
                    reading.spectrumResponse = header;
                    reading.spectrumLines = lines;
                    if ~isempty(obj.spectralData) && size(obj.spectralData,2) ~= numel(spectrum)
                        error('CR:HistoryGrid', 'Spectrum count changed. Save and EraseAll before starting a new grid.');
                    end
                    [xyz, total] = colormeasure.drivers.cr.spectralValues(spectrum, grid);
                    reading.xyzSource = stored.host;
                else
                    xyz = originalXYZ;
                end
                [reading.captureSettings, reading.metadataResponses] = obj.readMetadata();
                reading.settingsReadAt = datetime('now','TimeZone','UTC');
                obj.ready(); % A complete transaction must not leave extra replies.
                [cct, duv] = colormeasure.drivers.cr.cct(xyz);
                % Retained identity belongs to this acquisition, not its current
                % array position. Erase never makes a later reading reuse it.
                reading.readingId = char(java.util.UUID.randomUUID());
                % Prepare every next array before touching public history.
                nextXYZ = [obj.XYZ; xyz];
                nextOriginal = [obj.instrumentXYZ; originalXYZ];
                nextCCT = [obj.CCT; cct]; nextDuv = [obj.Duv; duv];
                nextMetadata = [obj.metadata; reading];
                if obj.spectral
                    nextSpectrum = [obj.spectralData; spectrum];
                    nextIntegrated = [obj.integratedSpectrum; total];
                    nextWL = [obj.wl; grid];
                    obj.wl = nextWL;
                    obj.spectralData = nextSpectrum; obj.integratedSpectrum = nextIntegrated;
                end
                obj.XYZ = nextXYZ; obj.instrumentXYZ = nextOriginal;
                obj.CCT = nextCCT; obj.Duv = nextDuv; obj.metadata = nextMetadata;
            catch err
                % Host validation does not invalidate a fully consumed exchange.
                % Incomplete/malformed framing and pending input still close it.
                if obj.streamSynchronized
                    try
                        obj.ready();
                    catch
                        obj.streamSynchronized = false;
                    end
                end
                if ~obj.streamSynchronized
                    obj.Disconnect();
                end
                rethrow(err);
            end
        end

        function measurements = snapshot(obj)
            %SNAPSHOT Complete value-only history; no port, file or state change.
            measurements = struct('XYZ', obj.XYZ, 'CCT', obj.CCT, ...
                'Duv', obj.Duv, 'instrumentXYZ', obj.instrumentXYZ, ...
                'metadata', obj.metadata, 'identity', obj.identity, 'segmentId', obj.segmentId, ...
                'repeatOnError', obj.repeatOnError, 'errorCode', obj.errorCode, ...
                'responseTimeout', obj.responseTimeout, ...
                'measurementTimeout', obj.measurementTimeout, 'schemaVersion', 2);
            measurements.recoveryStatus = obj.recoveryStatus;
            if obj.spectral
                measurements.spectralData = obj.spectralData;
                measurements.integratedSpectrum = obj.integratedSpectrum;
                measurements.wl = obj.wl;
            end
        end

        function report = readCapabilities(obj)
            %READCAPABILITIES Read configured choices/limits without acquisition.
            % See docs/drivers/cr/settings.md; unsupported queries remain explicit records.
            [report,problem] = obj.queryCapabilities();
            if ~isempty(problem)
                obj.quarantineSettings();
                rethrow(problem);
            end
        end

        function report = readSettings(obj)
            %READSETTINGS Current RS setup, separate from last-capture RM metadata.
            [report,problem] = obj.querySettings();
            if ~isempty(problem)
                obj.quarantineSettings();
                rethrow(problem);
            end
        end

        function receipt = applySettings(obj, changes)
            %APPLYSETTINGS Apply only named settings; never acquire or retry.
            % A failed receipt can include successful earlier writes. No rollback.
            if nargin<2, changes = struct(); end
            obj.validateSettingsInput(changes);
            receipt = obj.applySettingsTransaction(changes,false);
        end

        function receipt = applyAutomaticSettings(obj, overrides)
            %APPLYAUTOMATICSETTINGS Auto exposure; CR100 Colorimeter/Auto range.
            % Explicit overrides replace that recipe. No accessory, correction,
            % filter, sync, speed or multiplier reset. Measure itself is unchanged.
            if nargin<2, overrides = struct(); end
            obj.validateSettingsInput(overrides);
            receipt = obj.applySettingsTransaction(overrides,true);
        end

        function Save(obj, fileName)
            % Stage the snapshot beside the chosen path, then replace it.
            if ~(ischar(fileName) && isrow(fileName)) && ...
                    ~(isstring(fileName) && isscalar(fileName) && ~ismissing(fileName))
                error('CR:SavePath','Specify one nonempty MAT filename.');
            end
            fileName = char(fileName);
            [~,stem,extension] = fileparts(fileName);
            if isempty(stem), error('CR:SavePath','Specify one nonempty MAT filename.'); end
            if isempty(extension), fileName = [fileName '.mat']; end
            measurements = obj.snapshot();
            try
                colormeasure.session.saveMatFile(fileName,struct('measurements',measurements),true);
            catch problem
                wrapped = MException('CR:SaveFailed','Measurement save failed: %s',problem.message);
                throw(addCause(wrapped,problem));
            end
        end

        function Erase(obj)
            if isempty(obj.XYZ), return; end
            obj.XYZ(end,:) = []; obj.instrumentXYZ(end,:) = [];
            obj.CCT(end,:) = []; obj.Duv(end,:) = []; obj.metadata(end,:) = [];
            if obj.spectral
                obj.wl(end,:) = [];
                obj.spectralData(end,:) = []; obj.integratedSpectrum(end,:) = [];
            end
        end

        function EraseAll(obj)
            obj.XYZ = zeros(0,3); obj.instrumentXYZ = zeros(0,3);
            obj.CCT = zeros(0,1); obj.Duv = zeros(0,1); obj.metadata = struct([]);
            obj.wl = [];
            obj.spectralData = []; obj.integratedSpectrum = zeros(0,1);
        end

        function yes=canRetryConnectionCleanup(obj)
            % This reads ownership only; false is not a cleanup confirmation.
            yes=~isempty(obj.port)&&isvalid(obj.port);
        end

        function closed=Disconnect(obj)
            p = obj.port;
            obj.streamSynchronized = false;
            closed=obj.connectionCleanupConfirmed;
            if ~isempty(p)&&isvalid(p)
                colormeasure.drivers.closeConnection(p);
                closed=true;
            end
            obj.connectionCleanupConfirmed=closed;
            if closed,obj.port=[];end
        end

        function delete(obj)
            obj.Disconnect();
        end
    end
    methods (Access = private)
        function [report, problem] = queryCapabilities(obj)
            % Return completed observations even if a later exchange fails.
            controls = colormeasure.drivers.cr.settingsControls(obj.identity.model);
            specs = colormeasure.drivers.cr.settingsSpecs(obj.identity.model);
            responses = obj.emptySettingsResponses();
            problem = [];
            try
                cache = containers.Map('KeyType','char','ValueType','any');
                for index = 1:numel(specs)
                    spec = specs(index);
                    control = find(strcmp({controls.id},spec.id),1);
                    if ~obj.settingsFirmwareSupports(spec.since), continue; end
                    if ismember(spec.kind,{'choice','index','filter'})
                        token = spec.token; columns = 2;
                        if strcmp(spec.kind,'filter'), token = 'Filter'; end
                        if ismember(token,{'Accessory','Filter'}), columns = 3; end
                        [item, cache, responses, problem] = obj.settingCapability( ...
                            ['RC ' token],columns,cache,responses);
                        if ~isempty(problem), rethrow(problem); end
                        if item.available
                            choices = item.value;
                            % Matrix correction is a colorimeter feature (App p.78).
                            if obj.spectral && strcmp(spec.id,'userCalibrationMode')
                                choices(strcmp({choices.label},'Matrix')) = [];
                            end
                            controls(control).choices = choices;
                            controls(control).available = ~isempty(choices);
                            if strcmp(spec.id,'mode'), controls(control).available = false; end
                        end
                    else
                        token = spec.token;
                        if strcmp(spec.id,'maxAutoExposureMs'), token = 'Exposure'; end
                        [lo, cache, responses, problem] = obj.settingCapability( ...
                            ['RC Min' token],spec.kind,cache,responses);
                        if ~isempty(problem), rethrow(problem); end
                        [hi, cache, responses, problem] = obj.settingCapability( ...
                            ['RC Max' token],spec.kind,cache,responses);
                        if ~isempty(problem), rethrow(problem); end
                        if lo.available && hi.available && lo.value<=hi.value
                            controls(control).minimum = lo.value;
                            controls(control).maximum = hi.value;
                            controls(control).available = true;
                        elseif lo.available && hi.available
                            % Reversed limits leave only this control unavailable,
                            % with unknown bounds; both raw replies stay in the report.
                            pair = ismember({responses.command},{['RC Min' token],['RC Max' token]});
                            [responses(pair).status] = deal('unparsed');
                            [responses(pair).error] = deal(struct('identifier','CR:SettingsPayload', ...
                                'message',sprintf('RC Min%s reports a minimum above RC Max%s.',token,token)));
                        end
                    end
                end
                obj.ready();
            catch problem
                % The caller decides whether to throw or retain a failed receipt.
            end
            report = struct('controls',controls,'identity',obj.identity, ...
                'readAtUTC',obj.settingsTimestamp(),'responses',responses);
        end

        function [report, problem] = querySettings(obj)
            [capabilities,problem] = obj.queryCapabilities();
            report = struct('values',struct(),'controls',capabilities.controls, ...
                'identity',capabilities.identity,'readAtUTC',capabilities.readAtUTC, ...
                'responses',capabilities.responses);
            if ~isempty(problem), return; end
            [report,problem] = obj.readSettingsWithCapabilities(capabilities);
        end

        function responses = emptySettingsResponses(~)
            responses = struct('command',{},'response',{},'lines',{},'code',{},'status',{}, ...
                'partialTail',{},'error',{});
        end

        function value = settingsTimestamp(~)
            value = colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
        end

        function supported = settingsFirmwareSupports(obj, minimum)
            version = regexp(obj.identity.firmware,'^(\d+)\.(\d+)','tokens','once');
            supported = false;
            if isempty(version), return; end
            major = str2double(version{1}); minor = str2double(version{2});
            requiredMajor = floor(minimum); requiredMinor = round(100*(minimum-requiredMajor));
            supported = major>requiredMajor || (major==requiredMajor && minor>=requiredMinor);
        end

        function [payload, record, problem] = settingExchange(obj, command)
            % Keep the failing raw exchange separate from interpreted values.
            record = struct('command',command,'response','','lines',{{}}, ...
                'code',NaN,'status','available','partialTail','', ...
                'error',struct('identifier','','message',''));
            payload = ''; problem = [];
            try
                [payload,record.code,record.response] = obj.exchange(command,obj.responseTimeout);
                if record.code<0, record.status = 'instrumentError'; end
                if record.code==-500, record.status = 'unsupported'; end
            catch problem
                record.response = obj.lastExchangeResponse;
                record = obj.failedSettingsResponse(record,problem);
            end
        end

        function record = failedSettingsResponse(obj, record, problem)
            record.partialTail = obj.receiver.Buffer;
            record.status = 'error';
            if strcmp(problem.identifier,'CR:Timeout') || ~isempty(record.partialTail)
                record.status = 'incomplete';
            end
            record.error = struct('identifier',problem.identifier,'message',problem.message);
        end

        function [item, cache, responses, problem] = settingCapability(obj, command, kind, cache, responses)
            problem = [];
            if isKey(cache,command), item = cache(command); return; end
            item = struct('available',false,'value',[]);
            [payload,record,problem] = obj.settingExchange(command);
            if isempty(problem)
                try
                    if record.code<0
                        % The framed instrument error is already recorded.
                    elseif isnumeric(kind)
                        if strcmp(payload,'None')
                            count = 0;
                        else
                            % Until all declared rows arrive the stream is uncertain.
                            obj.streamSynchronized = false;
                            count = colormeasure.drivers.cr.numbers(payload,1);
                            if count<0 || fix(count)~=count || count>256
                                error('CR:SettingsPayload','Invalid configuration row count.');
                            end
                        end
                        started = obj.clock.now();
                        for row = 1:count
                            line = obj.readLine(started,obj.responseTimeout);
                            record.lines{end+1,1} = line;
                        end
                        obj.ready(); % Includes undeclared/trailing rows, without flushing.
                        obj.streamSynchronized = true;
                        item.value = colormeasure.drivers.cr.settingsChoices(record.lines,kind);
                        item.available = true;
                    else
                        try
                            [item.value,record.status] = colormeasure.drivers.cr.metadataValue(payload,kind);
                            if strcmp(record.status,'available') && item.value<=0
                                error('CR:SettingsPayload','%s must report a positive limit.',command);
                            end
                        catch err
                            if ~ismember(err.identifier,{'CR:Metadata','CR:SettingsPayload'}), rethrow(err); end
                            % A complete framed limit that cannot bound a control
                            % makes only that control unavailable, not the report.
                            item.value = [];
                            record.status = 'unparsed';
                            record.error = struct('identifier',err.identifier,'message',err.message);
                        end
                        item.available = strcmp(record.status,'available');
                    end
                catch problem
                    item = struct('available',false,'value',[]);
                    record = obj.failedSettingsResponse(record,problem);
                end
            end
            responses(end+1,1) = record;
            if isempty(problem), cache(command) = item; end
        end

        function [report, problem] = readSettingsWithCapabilities(obj, capabilities)
            controls = capabilities.controls;
            specs = colormeasure.drivers.cr.settingsSpecs(obj.identity.model);
            values = struct(); responses = capabilities.responses;
            problem = [];
            try
                cache = containers.Map('KeyType','char','ValueType','any');
                for index = 1:numel(specs)
                    spec = specs(index);
                    control = controls(strcmp({controls.id},spec.id));
                    if strcmp(spec.id,'maxAutoExposureMs') || ...
                            (~control.available && ~(strcmp(spec.id,'mode') && ~isempty(control.choices)))
                        continue
                    end
                    token = spec.token;
                    if strcmp(spec.kind,'filter'), token = 'Filter'; end
                    command = ['RS ' token];
                    if isKey(cache,command)
                        response = cache(command);
                    else
                        [payload,record,problem] = obj.settingExchange(command);
                        responses(end+1,1) = record;
                        if ~isempty(problem), rethrow(problem); end
                        response = struct('payload',payload,'code',record.code);
                        cache(command) = response;
                    end
                    if response.code<0, continue; end
                    try
                        value = obj.settingReadback(response.payload,spec,control);
                        if ~isempty(value), values.(spec.id) = value; end
                    catch err
                        if ~ismember(err.identifier,{'CR:Metadata','CR:SettingsPayload','CR:NumericPayload'})
                            rethrow(err);
                        end
                        % Retain a complete framed reply without inventing a value.
                        position = find(strcmp({responses.command},command),1,'last');
                        responses(position).status = 'unparsed';
                    end
                end
                % A physical aperture is an observation, not a writable UI setting.
                % CR250/300 have a fixed aperture selected when ordered.
                if obj.settingsFirmwareSupports(1.04)
                    [payload,record,problem] = obj.settingExchange('RS Aperture');
                    responses(end+1,1) = record;
                    if ~isempty(problem), rethrow(problem); end
                    status = record.status;
                    if record.code>=0
                        try
                            [aperture,status] = colormeasure.drivers.cr.metadataValue(payload,'text');
                            if strcmp(status,'available'), values.aperture = aperture; end
                        catch err
                            if ~strcmp(err.identifier,'CR:Metadata'), rethrow(err); end
                            status = 'unparsed';
                        end
                    end
                    responses(end).status = status;
                end
                obj.ready();
            catch problem
                % Preserve earlier RC/RS results for a failed application receipt.
            end
            report = struct('values',values,'controls',controls,'identity',obj.identity, ...
                'readAtUTC',obj.settingsTimestamp(),'responses',responses);
        end

        function value = settingReadback(~, payload, spec, control)
            if strcmp(spec.kind,'filter')
                filters = strsplit(payload,',','CollapseDelimiters',false);
                if numel(filters)~=3
                    error('CR:SettingsPayload','RS Filter must report three filter slots.');
                end
                payload = filters{str2double(spec.id(end))};
            end
            if ismember(spec.kind,{'choice','filter'})
                % The manual uses Fixed and Manual for the same exposure/range modes.
                if ismember(spec.id,{'exposureMode','rangeMode'}) && strcmp(payload,'Manual')
                    payload = 'Fixed';
                end
                matches = find(strcmp({control.choices.label},payload));
                if numel(matches)~=1
                    error('CR:SettingsPayload','Readback name has no unique configured ID.');
                end
                value = control.choices(matches).value;
            elseif strcmp(spec.kind,'index')
                [value,~] = colormeasure.drivers.cr.metadataValue(payload,'integer');
                if ~ismember(value,[control.choices.value])
                    error('CR:SettingsPayload','Readback profile ID is not configured.');
                end
            else
                [value,status] = colormeasure.drivers.cr.metadataValue(payload,spec.kind);
                if ~strcmp(status,'available'), value = []; end
            end
        end

        function validateSettingsInput(obj, changes)
            if ~isstruct(changes) || ~isscalar(changes)
                error('CR:SettingsArgument','Settings must be a scalar struct of named values.');
            end
            specs = colormeasure.drivers.cr.settingsSpecs(obj.identity.model);
            fields = fieldnames(changes);
            for index = 1:numel(fields)
                id = fields{index}; match = find(strcmp({specs.id},id),1);
                if isempty(match) || strcmp(id,'mode')
                    error('CR:SettingsArgument','Unknown or model-inapplicable setting: %s.',id);
                end
                value = changes.(id);
                if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
                    error('CR:SettingsArgument','%s requires a finite numeric scalar.',id);
                end
                if ismember(specs(match).kind,{'choice','filter','index','positiveInteger'}) && fix(value)~=value
                    error('CR:SettingsArgument','%s requires an integer.',id);
                end
            end
        end

        function receipt = applySettingsTransaction(obj, changes, automatic)
            receipt = struct('requested',changes,'before',[],'after',[], ...
                'commands',struct('id',{},'command',{},'value',{}), ...
                'acknowledgements',struct('id',{},'command',{},'response',{}, ...
                'acknowledged',{},'readbackVerified',{}), ...
                'status','failed','error',struct('identifier','','message',''));
            try
                [before,problem] = obj.querySettings(); receipt.before = before;
                if ~isempty(problem), rethrow(problem); end
                if automatic
                    requested = struct('exposureMode',obj.settingOption(before.controls,'exposureMode','Auto'));
                    if ~obj.spectral
                        requested.mode = obj.settingOption(before.controls,'mode','Colorimeter',true);
                        requested.rangeMode = obj.settingOption(before.controls,'rangeMode','Auto');
                    end
                    fields = fieldnames(changes);
                    for k = 1:numel(fields), requested.(fields{k}) = changes.(fields{k}); end
                else
                    requested = changes;
                end
                receipt.requested = requested;
                colormeasure.drivers.cr.validateSettingsCombination(requested,before,obj.identity.model);
                if obj.settingsUncertain && ~all(ismember(fieldnames(obj.settingsRecoveryRequested),fieldnames(requested)))
                    error('CR:SettingsUncertain','Reapply every attempted setting from the failed receipt, or reconstruct the connection.');
                end
                % No acquisition occurs while this explicitly non-atomic sequence runs.
                order = {'accessory','filter1','filter2','filter3','rangeMode','range', ...
                    'exposureMs','exposureMode','exposureMultiplier','syncFrequencyHz', ...
                    'syncMode','speed','matrixId','matchId','userCalibrationMode','maxAutoExposureMs'};
                if isfield(requested,'exposureMode') && ...
                        strcmp(colormeasure.drivers.cr.settingLabel(before.controls,requested,'exposureMode'),'Auto')
                    order = [{'exposureMode'},order(~strcmp(order,'exposureMode'))];
                end
                if isfield(requested,'userCalibrationMode') && ...
                        strcmp(colormeasure.drivers.cr.settingLabel(before.controls,requested,'userCalibrationMode'),'None')
                    order = [{'userCalibrationMode'},order(~strcmp(order,'userCalibrationMode'))];
                end
                if isfield(requested,'mode'), order = [{'mode'},order]; end
                specs = colormeasure.drivers.cr.settingsSpecs(obj.identity.model);
                for k = 1:numel(order)
                    id = order{k};
                    if ~isfield(requested,id), continue; end
                    value = double(requested.(id));
                    if isfield(before.values,id) && isequal(before.values.(id),value), continue; end
                    spec = specs(strcmp({specs.id},id));
                    command = sprintf('SM %s %.17g',spec.token,value);
                    receipt.commands(end+1,1) = struct('id',id,'command',command,'value',value);
                    receipt.acknowledgements(end+1,1) = struct('id',id,'command',command, ...
                        'response','','acknowledged',false,'readbackVerified',false);
                    obj.settingsUncertain = true;
                    obj.settingsRecoveryRequested.(id) = value;
                    expected = spec.token;
                    if strcmp(id,'mode'), expected = 'SM Mode'; end
                    try
                        [~,code,raw] = obj.exchange(command,obj.responseTimeout,expected);
                    catch err
                        receipt.acknowledgements(end).response = obj.lastExchangeResponse;
                        rethrow(err);
                    end
                    receipt.acknowledgements(end).response = raw;
                    if code<0
                        error('CR:InstrumentError','Setting %s failed: %s',id,raw);
                    end
                    receipt.acknowledgements(end).acknowledged = true;
                end
                if isempty(receipt.commands)
                    receipt.after = before; receipt.status = 'unchanged';
                    if ~isempty(fieldnames(requested))
                        obj.settingsUncertain = false; obj.settingsRecoveryRequested = struct();
                    end
                    return
                end
                % Refresh capabilities too: accessory-specific matrix lists can change.
                [after,problem] = obj.querySettings(); receipt.after = after;
                if ~isempty(problem), rethrow(problem); end
                fields = fieldnames(requested); unverified = {};
                for k = 1:numel(fields)
                    id = fields{k};
                    if strcmp(id,'maxAutoExposureMs'), continue; end % No documented RS query.
                    verified = isfield(after.values,id) && isequal(after.values.(id),double(requested.(id)));
                    ack = find(strcmp({receipt.acknowledgements.id},id),1);
                    if ~isempty(ack), receipt.acknowledgements(ack).readbackVerified = verified; end
                    if ~verified, unverified{end+1} = id; end %#ok<AGROW>
                end
                if ~isempty(unverified)
                    for k = 1:numel(unverified)
                        obj.settingsRecoveryRequested.(unverified{k}) = requested.(unverified{k});
                    end
                    error('CR:SettingsReadback','Final readback did not verify requested settings: %s.',strjoin(unverified,', '));
                end
                receipt.status = 'applied';
                obj.settingsUncertain = false;
                obj.settingsRecoveryRequested = struct();
            catch err
                obj.quarantineSettings();
                receipt.error = struct('identifier',err.identifier,'message',err.message);
            end
        end

        function value = settingOption(obj, controls, id, label, readOnly)
            if nargin<5, readOnly = false; end
            control = controls(strcmp({controls.id},id));
            matches = find(strcmp({control.choices.label},label));
            if (~control.available && ~readOnly) || numel(matches)~=1
                if ~obj.spectral && (strcmp(id,'mode') || ~obj.settingsFirmwareSupports(1.16))
                    error('CR:SettingsUnavailable', ...
                        ['%s option %s is not uniquely reported by the instrument. ' ...
                        'CR-100 automatic Colorimeter acquisition requires firmware 1.16 or newer, ' ...
                        'a uniquely reported Colorimeter option and successful readback. ' ...
                        'Reported firmware: "%s".'],id,label,obj.identity.firmware);
                end
                error('CR:SettingsUnavailable','%s option %s is not uniquely reported by the instrument.',id,label);
            end
            value = control.choices(matches).value;
        end

        function quarantineSettings(obj)
            if obj.streamSynchronized
                try
                    obj.ready();
                catch
                    obj.streamSynchronized = false;
                end
            end
            if ~obj.streamSynchronized, obj.Disconnect(); end
        end

        function [settings, entries] = readMetadata(obj)
            queries = colormeasure.drivers.cr.metadataQueries();
            settings = struct();
            entries = repmat(struct('field','','command','','value',[], ...
                'unit','','status','notApplicable','code',NaN,'response',''),numel(queries),1);
            for index = 1:numel(queries)
                q = queries(index);
                if ismember(q.kind,{'text','syncMode','calibrationMode','legacyMatrixMode'})
                    value = '';
                else
                    value = NaN;
                end
                status = 'notApplicable'; code = NaN; raw = '';
                read = true;
                switch q.condition
                    case 'spectral'
                        read = obj.spectral;
                    case 'sync'
                        % Section 4.3.1.14 forbids SyncFreq when SyncMode=None.
                        read = ~isempty(settings.syncMode) && ~strcmp(settings.syncMode,'None');
                        if isempty(settings.syncMode), status = 'dependencyUnavailable'; end
                    case 'legacy'
                        calibration = entries(strcmp({entries.field},'userCalibrationMode'));
                        read = strcmp(calibration.status,'unsupported');
                    case 'matrix'
                        % Section 4.3.1.17 assigns Matrix->RM Matrix. The .18
                        % warning saying Match conflicts with that description.
                        read = strcmp(settings.userCalibrationMode,'Matrix') || ...
                            strcmp(settings.legacyMatrixMode,'Enabled');
                        if isempty(settings.userCalibrationMode) && isempty(settings.legacyMatrixMode)
                            status = 'dependencyUnavailable';
                        end
                    case 'match'
                        read = strcmp(settings.userCalibrationMode,'Match');
                        if isempty(settings.userCalibrationMode) && isempty(settings.legacyMatrixMode)
                            status = 'dependencyUnavailable';
                        end
                end
                if read
                    [payload, code, raw] = obj.exchange(q.command,obj.responseTimeout);
                    if code == -500
                        status = 'unsupported';
                    elseif code < 0
                        status = 'instrumentError';
                    else
                        try
                            [value, status] = colormeasure.drivers.cr.metadataValue(payload,q.kind);
                        catch err
                            % The framed exchange is complete. Optional payload
                            % interpretation must not discard acquired outputs.
                            if ~strcmp(err.identifier,'CR:Metadata'), rethrow(err); end
                            status = 'unparsed';
                        end
                    end
                end
                settings.(q.field) = value;
                entries(index) = struct('field',q.field,'command',q.command, ...
                    'value',value,'unit',q.unit,'status',status,'code',code,'response',raw);
            end
        end

        function drainInput(obj, quietPeriod, timeout)
            % Explicit abandonment requires the caller to confirm the meter is
            % idle. A quiet interval does not prove that physical M has ended.
            try
                obj.recoveryStatus=obj.receiver.drain(obj.port,quietPeriod,timeout,Inf, ...
                    'Input did not become quiet; no identification command was sent. Confirm the instrument is idle before recovery.');
            catch problem
                obj.recoveryStatus=obj.receiver.RecoveryStatus;
                rethrow(problem);
            end
        end

        function ready(obj)
            if isempty(obj.port) || ~isvalid(obj.port)
                error('CR:Disconnected', 'The instrument is disconnected. Construct a new object.');
            end
            % CR manual p.35: allow command processing to finish after spectrum.
            if ~isempty(obj.lastSpectrum)
                obj.clock.sleep(max(0, 0.2-(obj.clock.now()-obj.lastSpectrum)));
            end
            % Never discard unread bytes: they may be a delayed valid reply.
            obj.receiver.collect(obj.port);
            if ~isempty(obj.receiver.Buffer)
                obj.streamSynchronized = false;
                error('CR:PendingInput', 'Unread serial input. Consume direct-command replies, or confirm the instrument is idle and reconstruct with DiscardPendingInput=true.');
            end
        end

        function line = readLine(obj, started, timeout)
            % One complete reply line; started is a reading of obj.clock.
            line = obj.receiver.readLine(obj.port, started, timeout);
        end

        function [payload, code, raw] = exchange(obj, command, timeout, expectedLabel)
            if nargin<4, expectedLabel = command; end
            obj.lastExchangeResponse = '';
            obj.ready();
            obj.streamSynchronized = false;
            colormeasure.drivers.configureSerialWrites(obj.port, obj.responseTimeout);
            writeline(obj.port, command);
            started = obj.clock.now();
            try
                raw = obj.readLine(started, timeout);
            catch err
                obj.lastExchangeResponse = obj.receiver.Buffer;
                rethrow(err);
            end
            obj.lastExchangeResponse = raw;
            parts = regexp(raw, '^(OK|ER):([+-]?\d+):([^:]+):(.*)$', 'tokens', 'once');
            if isempty(parts)
                error('CR:Framing', 'Malformed CR response (check ECHO is off): %s', raw);
            end
            code = str2double(parts{2});
            if ~isfinite(code) || (strcmp(parts{1}, 'OK') && code < 0) || ...
                    (strcmp(parts{1}, 'ER') && code >= 0)
                error('CR:Framing', 'Inconsistent CR response status: %s', raw);
            end
            % General-command ER replies use description:message, while M uses
            % M:description. Match the command only for successful responses.
            if code >= 0 && ~strcmp(parts{3}, expectedLabel)
                error('CR:Framing', 'Reply does not match command %s: %s', command, raw);
            end
            if strcmp(command, 'M') && code < 0 && code > -500 && ~strcmp(parts{3}, 'M')
                error('CR:Framing', 'Measurement error does not match M: %s', raw);
            end
            payload = parts{4};
            obj.streamSynchronized = code < 0 || ~strcmp(command, 'RM Spectrum');
        end

        function [payload, raw] = query(obj, command)
            [payload, code, raw] = obj.exchange(command, obj.responseTimeout);
            if code < 0
                obj.errorCode = code;
                error('CR:InstrumentError', '%s failed: %s', command, raw);
            end
        end

        function [grid, spectrum, raw, lines] = readSpectrum(obj)
            [payload, raw] = obj.query('RM Spectrum');
            grid = colormeasure.drivers.cr.spectrumHeader(payload);
            spectrum = zeros(1,numel(grid)); lines = cell(numel(grid),1);
            started = obj.clock.now();
            for k = 1:numel(grid)
                lines{k} = obj.readLine(started, obj.responseTimeout);
            end
            obj.lastSpectrum = obj.clock.now();
            obj.clock.sleep(0.2); % Manual p.35 command-processing guard, also catches trailing samples.
            obj.receiver.collect(obj.port);
            if ~isempty(obj.receiver.Buffer)
                error('CR:SpectrumCount', 'Unexpected data after the declared spectrum samples.');
            end
            obj.streamSynchronized = true;
            for k = 1:numel(grid)
                spectrum(k) = colormeasure.drivers.cr.numbers(lines{k},1);
            end
        end
    end
end

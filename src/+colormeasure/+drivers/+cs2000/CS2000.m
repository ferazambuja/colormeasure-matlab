classdef CS2000 < colormeasure.drivers.cs2000.Spectroradiometer
    %CS2000 CS-2000/CS-2000A acquisition without overwriting measurement slot 99.
    % Adapted from the original MCSL driver. Manufacturer protocol:
    % Communication Specifications Rev.7, pp.12-14, 41-46, 63-64, 78-80, 85.
    % https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
    properties (Constant)
        nativeXYZSource = 'instrument MEDR,2,0,01; CIE 1931 2 degree'
    end
    properties (Constant, Access = private)
        % Rev.7 p.29: nonbusy UCPR failures that leave a channel name unavailable.
        ucprUnavailableCodes = {'ER05','ER17','ER30','ER32','ER34'}
    end
    properties (SetAccess = private)
        preMeasurementTimeout = 35
        expectedModel = ''
        cleanupStatus = struct('backlightRestored',true,'remoteReleased',true, ...
            'speedRestored',true,'portClosed',true,'details',{{}})
        % Serial number -> backlight pair an uncertain stop left unrestored.
        % Share this map with the next driver (UnrestoredBacklight option);
        % its next connection to that instrument restores the pair at cleanup.
        unrestoredBacklight
    end
    properties (Access = private)
        remoteModeFlag = false
        remoteRequested = false
        measurementActive = false
        backlightBefore = []
        backlightBeforeResponse = ''
        backlightChanged = false
        manualRestoreCommand = ''
        manualBeforeResponse = ''
        manualRequested = NaN
        manualRestoreFailed = false
        settingsApplicationFailed = false
        settingsRecoveryFields = {}
    end
    methods
        function obj = CS2000(portNumber, varargin)
            if nargin == 0, portNumber = ""; end
            options = inputParser;
            options.KeepUnmatched = true;
            options.addParameter('PreMeasurementTimeout',35,@(x) isnumeric(x) && ...
                isscalar(x) && isreal(x) && isfinite(x) && x >= 35);
            options.addParameter('ExpectedModel','',@(x) ...
                (ischar(x) && (isrow(x) || isempty(x))) || ...
                (isstring(x) && isscalar(x) && ~ismissing(x)));
            options.addParameter('UnrestoredBacklight',[],@(x) (isa(x,'double') && isequal(x,[])) || ...
                (isa(x,'containers.Map') && strcmp(x.KeyType,'char') && ...
                strcmp(x.ValueType,'any')));
            options.parse(varargin{:});
            names = fieldnames(options.Unmatched); values = struct2cell(options.Unmatched);
            transportOptions = reshape([names values].',1,[]);
            obj@colormeasure.drivers.cs2000.Spectroradiometer(portNumber,115200,'none',8,1,true,true,transportOptions{:});
            obj.preMeasurementTimeout = options.Results.PreMeasurementTimeout;
            obj.expectedModel = strtrim(char(options.Results.ExpectedModel));
            % isempty is true for an empty Map, so test for the shared map itself.
            obj.unrestoredBacklight = options.Results.UnrestoredBacklight;
            if ~isa(obj.unrestoredBacklight,'containers.Map')
                obj.unrestoredBacklight = containers.Map('KeyType','char','ValueType','any');
            end
            if numel(obj.expectedModel) > 9 || any(obj.expectedModel < 32 | obj.expectedModel > 126)
                error('CS2000:Identity', 'ExpectedModel must be at most nine printable ASCII characters.');
            end
        end

        function Connect(obj, varargin)
            if obj.isOpened()
                error('CS2000:AlreadyConnected', 'The instrument connection is already open.');
            end
            options = inputParser;
            options.addParameter('DiscardPendingInput',false,@(x) islogical(x) && isscalar(x));
            options.addParameter('DrainQuietPeriod',0.25,@(x) isnumeric(x) && ...
                isscalar(x) && isreal(x) && isfinite(x) && x > 0);
            options.addParameter('DrainTimeout',2,@(x) isnumeric(x) && ...
                isscalar(x) && isreal(x) && isfinite(x) && x > 0);
            options.parse(varargin{:});
            if options.Results.DrainTimeout <= options.Results.DrainQuietPeriod
                error('CS2000:DrainOptions', 'DrainTimeout must be greater than DrainQuietPeriod.');
            end
            obj.backlightBefore = []; obj.backlightBeforeResponse = '';
            obj.backlightChanged = false;
            obj.remoteRequested = false; obj.remoteModeFlag = false;
            obj.measurementActive = false; obj.manualRestoreCommand = '';
            obj.manualBeforeResponse = ''; obj.manualRequested = NaN;
            obj.manualRestoreFailed = false;
            obj.settingsApplicationFailed = false;
            obj.settingsRecoveryFields = {};
            try
                obj.Open();
                if options.Results.DiscardPendingInput
                    % Explicit operator recovery of an abandoned exchange.
                    % A quiet window cannot establish instrument idle state.
                    obj.discardPendingInput(options.Results.DrainQuietPeriod,options.Results.DrainTimeout);
                end
                obj.remoteRequested = true;
                obj.requestNoData('RMTS,1');
                obj.remoteModeFlag = true;
                [payload,raw] = obj.request('IDDR');
                fields = strsplit(payload,',','CollapseDelimiters',false);
                if numel(fields) ~= 3
                    error('CS2000:Identity', 'IDDR must return model, variation and serial number.');
                end
                model = strtrim(fields{1}); serialNumber = strtrim(fields{3});
                variation = strtrim(fields{2});
                standardIdentity = (strcmp(model,'CS-2000') && strcmp(variation,'1')) || ...
                    (strcmp(model,'CS-2000A') && strcmp(variation,'2'));
                % Rev.7 p.14 permits custom names, but undefined variation
                % codes do not establish compatibility with this driver.
                customIdentity = ~isempty(obj.expectedModel) && ...
                    strcmp(model,obj.expectedModel) && any(strcmp(variation,{'1','2'})) && ...
                    ~any(strcmp(model,{'CS-2000','CS-2000A'}));
                expectedMatches = isempty(obj.expectedModel) || strcmp(model,obj.expectedModel);
                if ~(expectedMatches && (standardIdentity || customIdentity)) || ...
                        isempty(regexp(serialNumber,'^\d{7}$','once'))
                    error('CS2000:Identity', 'The selected port did not identify a documented CS-2000/CS-2000A: %s',raw);
                end
                obj.identity = struct('model',model,'variation',str2double(variation), ...
                    'serialNumber',serialNumber,'port',obj.portName,'protocolRevision','7.00', ...
                    'firmware','','response',raw);
                % Rev.7 p.71: factory calibration time has no specified zone.
                % Firmware retrieval is not established by the verified
                % CS-2000 protocol; see docs/drivers/cs2000/metadata.md for the VERR question.
                % No temperature readback was found in that protocol.
                [payload,raw] = obj.request('BALR');
                backlight = colormeasure.drivers.cs2000.numbers(payload,2);
                if any(~ismember(backlight,0:1))
                    error('CS2000:Backlight', 'BALR must return two binary settings.');
                end
                obj.backlightBefore = backlight;
                obj.backlightBeforeResponse = raw;
                if isKey(obj.unrestoredBacklight,serialNumber)
                    % An earlier uncertain stop left its change in place, so
                    % this connection's cleanup restores that original flag.
                    owed = obj.unrestoredBacklight(serialNumber);
                    % The shared map can change after construction. Refuse an
                    % invalid target before consuming it or sending a setting.
                    if ~isnumeric(owed) || ~isreal(owed) || ~isvector(owed) || ...
                            numel(owed) ~= 2 || any(~isfinite(owed)) || ...
                            any(~ismember(owed,0:1))
                        error('CS2000:Backlight', ...
                            ['UnrestoredBacklight for %s must contain two finite binary settings. ' ...
                            'Restore the backlight at the instrument, then correct or remove that entry.'],serialNumber);
                    end
                    remove(obj.unrestoredBacklight,serialNumber);
                    if backlight(2) == 0
                        obj.backlightBefore(2) = owed(2);
                        obj.backlightChanged = owed(2) ~= 0;
                    end
                end
                if backlight(2) ~= 0
                    % Set before sending: a lost acknowledgement may hide a change.
                    obj.backlightChanged = true;
                    obj.requestNoData(sprintf('BALS,%d,0',backlight(1)));
                end
                % Rev.7 pp.85-86: disabled measurement key keeps the complete
                % latest reading available across MEDR requests. No STDS needed.
                obj.requestNoData('MSWE,0');
                obj.identity.factoryCalibration = obj.readOptionalMetadata('DTCR', ...
                    @colormeasure.drivers.cs2000.calibrationDate,struct('date','','time','','dateTime',NaT));
                obj.validateIdleInput();
                obj.cleanupStatus = struct('backlightRestored',~obj.backlightChanged,'remoteReleased',false, ...
                    'speedRestored',true,'portClosed',false,'details',{{}});
            catch err
                try
                    if obj.Disconnect(),err=colormeasure.drivers.confirmedConnectionFailure(err);end
                catch cleanupError
                    err=addCause(err,cleanupError);
                end
                rethrow(err);
            end
        end

        function flag = isConnected(obj)
            flag = obj.isOpened() && obj.remoteModeFlag && obj.streamSynchronized;
        end

        function Measure(obj)
            obj.requireAcquisitionReady();
            try
                configurationBefore = obj.readConfiguration();
                obj.Send('MEAS,1');
                obj.measurementActive = true;
                % Rev.7 pp.8,41: the vendor minimum is 10 seconds for MEAS.
                % This driver's separate 35-second policy avoids that boundary;
                % section 1.6 explicitly permits the longer allowance.
                first = obj.Receive(obj.preMeasurementTimeout);
                [code,payload] = obj.decode(first);
                if ~strcmp(code,'OK00')
                    % Rev.7 pp.41-42 gives ER00/ER17 for commands during
                    % an existing measurement; ER02 also indicates busy.
                    obj.measurementActive = any(strcmp(code,{'ER00','ER02','ER17'}));
                    obj.requireSuccess(code,first);
                end
                % Rev.7 p.41: 002..242 is integer seconds, never 0.002 s.
                duration = str2double(payload);
                if isempty(regexp(payload,'^\d{3}$','once')) || duration < 2 || duration > 242
                    obj.streamSynchronized = false;
                    error('CS2000:Duration', 'Invalid measurement duration response: %s',first);
                end
                completion = obj.Receive(duration + obj.responseTimeout);
                [code,payload] = obj.decode(completion);
                obj.measurementActive = false;
                obj.requireSuccess(code,completion);
                obj.requireEmpty(payload,completion);

                spectrum = zeros(401,1); spectralResponses = cell(4,1);
                counts = [100 100 100 101]; offset = 0;
                for block = 1:4
                    [payload,spectralResponses{block}] = obj.request(sprintf('MEDR,1,0,%d',block));
                    samples = colormeasure.drivers.cs2000.numbers(payload,counts(block));
                    spectrum(offset+(1:counts(block))) = samples(:);
                    offset = offset + counts(block);
                end
                [payload,xyzRaw] = obj.request('MEDR,2,0,01');
                XYZ = colormeasure.drivers.cs2000.numbers(payload,3).';
                [payload,conditionsRaw] = obj.request('MEDR,0,0,1');
                conditions = colormeasure.drivers.cs2000.conditions(payload);
                userCalibration = obj.readCalibrationName(conditions.userCalibrationChannel);
                reading = struct('acquiredAt',datetime('now','TimeZone','UTC'), ...
                    'announcedDurationSeconds',duration,'observer',0, ...
                    'xyzSource',obj.nativeXYZSource, ...
                    'spectralResponse',{spectralResponses},'xyzResponse',xyzRaw, ...
                    'conditionsResponse',conditionsRaw,'measurementResponses',{{first;completion}}, ...
                    'manualIntegrationTimeRequestedSeconds',obj.manualRequested, ...
                    'speedBeforeResponse',obj.manualBeforeResponse,'speedRestoreResponse','', ...
                    'configurationBefore',configurationBefore,'userCalibration',userCalibration, ...
                    'backlight',struct('originalSettings',obj.backlightBefore, ...
                        'originalResponse',obj.backlightBeforeResponse, ...
                        'commandedSettings',[obj.backlightBefore(1) 0]));
                % A manual capture restores its prior configuration BEFORE
                % committing history, so restoration failure retains no row.
                if ~isempty(obj.manualRestoreCommand)
                    reading.speedRestoreResponse = obj.restoreManual();
                end
                obj.validateIdleInput();
                obj.commitReading(spectrum,XYZ,conditions,reading);
                obj.manualRequested = NaN; obj.manualBeforeResponse = '';
            catch err
                obj.handleAcquisitionFailure();
                rethrow(err);
            end
        end

        function conditions = StoreMeasurementConditions(obj)
            % Reads the latest instrument conditions; does not append history.
            obj.requireConnection();
            try
                payload = obj.request('MEDR,0,0,1');
                conditions = colormeasure.drivers.cs2000.conditions(payload);
                obj.validateIdleInput();
                obj.measurementConditions = conditions;
                obj.conditionsSnapshotIndependent = true;
                obj.isSaved = false;
            catch err
                obj.handleAcquisitionFailure();
                rethrow(err);
            end
        end

        function report = readSettings(obj)
            %READSETTINGS Current setup, not the conditions of the last reading.
            % Does not acquire, write settings, or modify retained history.
            obj.requireConnection();
            [report,problem] = obj.querySettings();
            if ~isempty(problem)
                obj.closeUncertainSettingsStream();
                rethrow(problem);
            end
        end

        function receipt = applyAutomaticSettings(obj, overrides)
            %APPLYAUTOMATICSETTINGS Multi-Normal/1 s, internal ND Auto, No Sync.
            % Operating manual pp.26,29 and Rev.7 p.75 describe this recipe.
            % Explicit overrides replace recipe fields. Accessories and existing
            % user correction are inherited. No exposure or automatic rollback.
            if nargin < 2, overrides = struct(); end
            overrides = colormeasure.drivers.cs2000.validateSettingsChanges(overrides);
            changes = struct('speedMode',2,'integrationTimeSeconds',1, ...
                'internalNDMode',2,'syncMode',0);
            names = fieldnames(overrides);
            for k = 1:numel(names), changes.(names{k}) = overrides.(names{k}); end
            if ismember(changes.speedMode,[0 1 3]) && ~isfield(overrides,'integrationTimeSeconds')
                changes = rmfield(changes,'integrationTimeSeconds');
            end
            if changes.speedMode == 3 && ~isfield(overrides,'internalNDMode')
                % Do not silently turn a Multi interval into Manual exposure or
                % choose ND Off. The coupled target must be valid explicitly.
                changes = rmfield(changes,'internalNDMode');
            end
            receipt = obj.applySettings(changes);
        end

        function receipt = applySettings(obj, changes)
            %APPLYSETTINGS Explicit partial configuration under persistent RMTS,1.
            % Validate before writes, skip unchanged values, then verify readback.
            % A failed receipt can include partial application; do not Measure.
            % No retry, firmware probe, calibration authoring or rollback occurs.
            if nargin < 2, changes = struct(); end
            changes = colormeasure.drivers.cs2000.validateSettingsChanges(changes);
            receipt = struct('requested',changes,'before',struct([]),'after',struct([]), ...
                'commands',{{}},'acknowledgements',{{}},'status','failed', ...
                'error',struct('identifier','','message',''), ...
                'persistence',struct('remoteMode',1,'settingsPersist',true,'automaticRestoration',false), ...
                'preflight',struct());
            try
                obj.requireConnection();
                [receipt.before,problem] = obj.querySettings();
                if ~isempty(problem), rethrow(problem); end
                [commands,target] = colormeasure.drivers.cs2000.settingsPlan(changes,receipt.before);
                if obj.settingsApplicationFailed && ...
                        ~all(ismember(obj.settingsRecoveryFields,fieldnames(changes)))
                    error('CS2000:SettingsUnverified', ...
                        'Reapply every requested field from the failed application, or reconnect and inspect the current settings.');
                end
                if target.userCalibrationChannel ~= receipt.before.values.userCalibrationChannel && ...
                        target.userCalibrationChannel ~= 0
                    % Check the requested channel BEFORE any setting write.
                    % UCPR ER05 means that this channel contains no correction.
                    command = sprintf('UCPR,2,%02d',target.userCalibrationChannel);
                    [payload,raw,problem] = obj.settingsExchange(command,false);
                    receipt.preflight = struct('command',command,'response',raw, ...
                        'channel',target.userCalibrationChannel);
                    if ~isempty(problem), rethrow(problem); end
                    calibration = parseCalibrationName(payload);
                    receipt.preflight.name = calibration.name;
                end
                for k = 1:numel(commands)
                    receipt.commands{end+1} = commands{k};
                    % Conservatively record an attempt before sending it.
                    obj.settingsApplicationFailed = true;
                    % A failed recipe may stop before later requested setters.
                    % Recovery must explicitly cover that complete intent.
                    obj.settingsRecoveryFields = union(obj.settingsRecoveryFields,fieldnames(changes));
                    [~,raw,problem] = obj.settingsExchange(commands{k},true);
                    receipt.acknowledgements{end+1} = raw;
                    if ~isempty(problem), rethrow(problem); end
                end
                if isempty(commands)
                    receipt.after = receipt.before;
                    receipt.status = 'unchanged';
                else
                    [receipt.after,problem] = obj.querySettings();
                    if ~isempty(problem), rethrow(problem); end
                    fields = fieldnames(target);
                    for k = 1:numel(fields)
                        field = fields{k};
                        if ~isequaln(target.(field),receipt.after.values.(field))
                            error('CS2000:SettingsReadback','Setting %s did not match the requested complete configuration.',field);
                        end
                    end
                    receipt.status = 'applied';
                end
                if ~isempty(fieldnames(changes))
                    obj.settingsApplicationFailed = false;
                    obj.settingsRecoveryFields = {};
                end
            catch problem
                receipt.error = struct('identifier',problem.identifier,'message',problem.message);
                obj.closeUncertainSettingsStream();
            end
        end

        function closed=Disconnect(obj)
            if ~obj.isOpened()
                closed=obj.Close();
                obj.cleanupStatus.portClosed = closed;
                return
            end
            status = struct('backlightRestored',~obj.backlightChanged, ...
                'remoteReleased',~obj.remoteRequested,'speedRestored', ...
                isempty(obj.manualRestoreCommand) && ~obj.manualRestoreFailed, ...
                'portClosed',false,'details',{{}});
            if obj.manualRestoreFailed
                status.details{end+1} = 'The previous speed configuration was not confirmed restored.';
            end
            if obj.streamSynchronized && ~obj.measurementActive
                if ~isempty(obj.manualRestoreCommand)
                    try
                        obj.restoreManual();
                        status.speedRestored = true;
                    catch err
                        status.details{end+1} = err.message;
                    end
                end
                if obj.streamSynchronized && obj.backlightChanged
                    try
                        obj.requestNoData(sprintf('BALS,%d,%d',obj.backlightBefore));
                        status.backlightRestored = true;
                    catch err
                        status.details{end+1} = err.message;
                    end
                end
                if obj.streamSynchronized && obj.remoteRequested
                    try
                        obj.requestNoData('RMTS,0');
                        status.remoteReleased = true;
                    catch err
                        status.details{end+1} = err.message;
                    end
                end
            else
                status.details{end+1} = 'Response stream or measurement completion is uncertain; settings restoration was not attempted.';
            end
            try
                status.portClosed = obj.Close();
            catch err
                status.details{end+1} = err.message;
            end
            obj.remoteModeFlag = false; obj.remoteRequested = false;
            obj.measurementActive = false;
            if obj.backlightChanged && ~status.backlightRestored
                obj.unrestoredBacklight(obj.identity.serialNumber) = obj.backlightBefore;
            end
            obj.cleanupStatus = status;
            closed=status.portClosed;
            if ~status.backlightRestored || ~status.remoteReleased || ~status.speedRestored || ~status.portClosed
                % Cleanup must not replace the acquisition exception, even if
                % this warning identifier has been configured as an error.
                try
                    warning('CS2000:CleanupUnverified', 'Port cleanup finished with unverified restoration. Inspect cleanupStatus.');
                catch
                end
            end
        end

        function delete(obj)
            obj.Disconnect();
        end
    end
    methods (Access = protected)
        function requireAcquisitionReady(obj)
            % Subclasses must check before exposure or moving external stages.
            obj.requireConnection();
            obj.requireVerifiedSettings();
        end

        function measureWithIntegration(obj, seconds)
            % Manual SPMS configuration is temporary, including internal ND=0.
            % Rev.7 pp.20-22 defines the integration interval in microseconds.
            obj.requireAcquisitionReady();
            if ~isnumeric(seconds) || ~isscalar(seconds) || ~isreal(seconds) || ...
                    ~isfinite(seconds) || seconds < 0.005 || seconds > 120 || ...
                    abs(seconds*1e6-round(seconds*1e6)) > 1e-6
                error('CS2000:IntegrationTime', 'Integration time must be 0.005 to 120 seconds in whole microseconds.');
            end
            try
                [payload,raw] = obj.request('SPMR');
                obj.manualRestoreCommand = colormeasure.drivers.cs2000.speedCommand(payload,obj.identity.variation == 1);
                obj.manualBeforeResponse = raw; obj.manualRequested = seconds;
                obj.manualRestoreFailed = false;
                obj.requestNoData(sprintf('SPMS,3,%09d,0',round(seconds*1e6)));
                obj.Measure();
            catch err
                obj.handleAcquisitionFailure();
                rethrow(err);
            end
        end
    end
    methods (Access = private)
        function requireVerifiedSettings(obj)
            if obj.settingsApplicationFailed
                error('CS2000:SettingsUnverified', ...
                    'A settings application failed after a write attempt. Inspect its receipt and apply verified settings before measuring.');
            end
        end

        function closeUncertainSettingsStream(obj)
            if ~obj.streamSynchronized || obj.measurementActive
                obj.Disconnect();
            end
        end

        function [report,problem] = querySettings(obj)
            % Preserve partial readbacks for an application receipt on failure.
            report = struct('values',struct(),'controls',colormeasure.drivers.cs2000.settingsCatalog(), ...
                'identity',obj.identity,'readAtUTC',colormeasure.session.utcText(datetime('now','TimeZone','UTC')), ...
                'responses',struct(),'speedLayout','unknown','userCalibration',struct());
            problem = [];
            try
                commands = {'SCMR','SPMR','STSR','LNSR','NDFR','UCCR'};
                for k = 1:numel(commands)
                    command = commands{k};
                    [payload,raw,failure] = obj.settingsExchange(command,false);
                    report.responses.(command) = raw;
                    if ~isempty(failure), rethrow(failure); end
                    switch command
                        case 'SCMR'
                            sync = colormeasure.drivers.cs2000.syncSettings(payload);
                            report.values.syncMode = sync.syncMode;
                            report.values.frequencyHz = sync.frequencyHz;
                        case 'SPMR'
                            [~,speed] = colormeasure.drivers.cs2000.speedCommand(payload,obj.identity.variation == 1);
                            report.values.speedMode = speed.speedMode;
                            report.values.integrationTimeSeconds = speed.integrationTimeSeconds;
                            report.values.internalNDMode = speed.internalNDMode;
                            if obj.identity.variation == 2 || speed.speedMode == 4 || ...
                                    (speed.speedMode ~= 3 && strcmp(speed.internalNDModeSource,'reported'))
                                report.speedLayout = 'modern';
                            elseif speed.speedMode ~= 3
                                report.speedLayout = 'legacy';
                            end
                        case 'STSR'
                            angle = parseSettingCode(payload,0:2,command);
                            angles = [1 .2 .1]; report.values.measurementAngleDegrees = angles(angle+1);
                        case 'LNSR'
                            report.values.closeupLens = parseSettingCode(payload,0:1,command);
                        case 'NDFR'
                            report.values.externalNDFilter = parseSettingCode(payload,0:2,command);
                        case 'UCCR'
                            report.values.userCalibrationChannel = parseSettingCode(payload,0:10,command);
                    end
                end
                channel = report.values.userCalibrationChannel;
                report.userCalibration = struct('channel',channel,'name','','status','factory-standard');
                if channel ~= 0
                    [payload,raw,failure] = obj.settingsExchange(sprintf('UCPR,2,%02d',channel),false);
                    report.responses.UCPR = raw;
                    if ~isempty(failure)
                        if any(strcmp(raw,obj.ucprUnavailableCodes)) && obj.streamSynchronized
                            report.userCalibration.status = 'unavailable';
                        else
                            rethrow(failure);
                        end
                    else
                        calibration = parseCalibrationName(payload);
                        report.userCalibration.name = calibration.name;
                        report.userCalibration.status = 'available';
                    end
                end
                report.controls = colormeasure.drivers.cs2000.settingsCatalog(report.values,report.speedLayout,report.userCalibration);
            catch failure
                problem = failure;
            end
        end

        function [payload,raw,problem] = settingsExchange(obj, command, acknowledgementOnly)
            % Unlike request(), returns a failed exchange's raw reply for receipts.
            payload = ''; raw = ''; problem = [];
            try
                obj.Send(command);
                raw = obj.Receive();
                [code,payload] = obj.decode(raw);
                obj.validateIdleInput();
                obj.requireSuccess(code,raw);
                if acknowledgementOnly, obj.requireEmpty(payload,raw); end
            catch failure
                problem = failure;
            end
        end

        function configuration = readConfiguration(obj)
            % Current settings before MEAS are distinct from MEDR's actual
            % exposure conditions. Rev.7 pp.15,17-19,70.
            configuration = struct('queriedAt',datetime('now','TimeZone','UTC'));
            configuration.sync = obj.readOptionalMetadata('SCMR', ...
                @colormeasure.drivers.cs2000.syncSettings,struct('syncMode',NaN,'frequencyHz',NaN));
            configuration.speed = obj.readOptionalMetadata('SPMR', ...
                @(payload)parseSpeed(payload,obj.identity.variation == 1), ...
                struct('speedMode',NaN,'integrationTimeSeconds',NaN, ...
                    'internalNDMode',NaN,'internalNDModeSource','unavailable'));
            observer = obj.readOptionalMetadata('OBSR',@parseObserver,struct('value',NaN));
            configuration.observerMetadata = observer;
        end

        function calibration = readCalibrationName(obj, channel)
            % Rev.7 pp.28-29: channel 00 has no user-calibration name query.
            calibration = struct('channel',channel,'status','factory-standard', ...
                'name','','queriedAt',NaT('TimeZone','UTC'),'response','', ...
                'errorCode','','errorIdentifier','','errorMessage','');
            if channel == 0, return; end
            calibration = obj.readOptionalMetadata(sprintf('UCPR,2,%02d',channel), ...
                @parseCalibrationName,struct('channel',channel,'name',''));
            if strcmp(calibration.errorCode,'ER05')
                calibration.status = 'no-compensation-values';
            end
        end

        function value = readOptionalMetadata(obj, command, parser, value)
            % Only ancillary metadata is optional. Identity, actual MEDR
            % conditions, and manual SPMR needed for restoration stay required.
            % Rev.7 p.41: ER00 may mean measurement is active, not unsupported.
            % Neither ER00/ER02 nor a lost/malformed frame establishes idle.
            value.status = 'available';
            value.queriedAt = datetime('now','TimeZone','UTC');
            value.response = ''; value.errorCode = '';
            value.errorIdentifier = ''; value.errorMessage = '';
            obj.Send(command);
            raw = obj.Receive();
            [code,payload] = obj.decode(raw);
            value.response = raw;
            if ~strcmp(code,'OK00')
                % Only UCPR documents nonbusy failures; the other optional
                % queries document no safe error alternative.
                optionalError = startsWith(command,'UCPR,2,') && ...
                    any(strcmp(code,obj.ucprUnavailableCodes));
                if ~obj.streamSynchronized || ~optionalError
                    obj.requireSuccess(code,raw);
                end
                obj.validateIdleInput();
                value.status = 'unavailable'; value.errorCode = code;
                value.errorIdentifier = 'CS2000:InstrumentError';
                value.errorMessage = ['Metadata query returned ' code '.'];
                return
            end
            % Check framing before softening a payload validation failure.
            obj.validateIdleInput();
            try
                parsed = parser(payload);
            catch err
                if ~any(strcmp(err.identifier,{'CS2000:CalibrationDate', ...
                        'CS2000:SyncMode','CS2000:SpeedMode','CS2000:Observer', ...
                        'CS2000:CalibrationName','CS2000:NumericPayload'}))
                    rethrow(err);
                end
                value.status = 'unparsed';
                value.errorIdentifier = err.identifier; value.errorMessage = err.message;
                return
            end
            names = fieldnames(parsed);
            for k = 1:numel(names), value.(names{k}) = parsed.(names{k}); end
        end

        function handleAcquisitionFailure(obj)
            % A complete ER reply or invalid fully consumed payload does not
            % itself desynchronize the stream. Keep that session usable.
            if obj.measurementActive, obj.streamSynchronized = false; end
            if obj.isOpened() && obj.streamSynchronized && ~obj.manualRestoreFailed
                try
                    obj.validateIdleInput();
                    if ~isempty(obj.manualRestoreCommand)
                        obj.restoreManual();
                        obj.validateIdleInput();
                    end
                    obj.manualRequested = NaN; obj.manualBeforeResponse = '';
                    return
                catch
                    % Preserve the original acquisition exception. Disconnect
                    % reports any restoration uncertainty through cleanupStatus.
                end
            end
            obj.Disconnect();
        end

        function requireConnection(obj)
            if ~obj.isConnected()
                error('CS2000:Disconnected', 'The instrument is not connected. Call Connect first.');
            end
        end

        function [payload,raw] = request(obj, command)
            obj.Send(command);
            raw = obj.Receive();
            [code,payload] = obj.decode(raw);
            % Rev.7 p.45: MEDR ER02 explicitly reports measurement in
            % progress. Do not send restoration commands while it is busy.
            if startsWith(command,'MEDR,') && strcmp(code,'ER02')
                obj.measurementActive = true;
            end
            obj.requireSuccess(code,raw);
        end

        function raw = requestNoData(obj, command)
            [payload,raw] = obj.request(command);
            obj.requireEmpty(payload,raw);
        end

        function [code,payload] = decode(obj, raw)
            if isempty(regexp(raw,'^(OK00|ER\d{2})(,.*)?$','once'))
                obj.streamSynchronized = false;
                error('CS2000:Framing', 'Malformed response: %s',raw);
            end
            code = raw(1:4); payload = '';
            if ~strcmp(code,'OK00') && numel(raw) ~= 4
                obj.streamSynchronized = false;
                error('CS2000:Framing', 'Error replies must not contain a payload: %s',raw);
            end
            % Rev.7 p.41: any command except MEAS,0 can return ER00 while
            % measuring. ER00 also means invalid command, so it cannot
            % establish idle state. Block all subsequent cleanup commands.
            % ER02 explicitly reports measurement in progress, including on
            % metadata queries. Never follow it with restoration commands.
            if any(strcmp(code,{'ER00','ER02'})), obj.streamSynchronized = false; end
            if numel(raw) > 4, payload = raw(6:end); end
        end

        function requireEmpty(obj, payload, raw)
            if ~isempty(payload) || ~strcmp(raw,'OK00')
                obj.streamSynchronized = false;
                error('CS2000:Framing', 'Expected an acknowledgement without data: %s',raw);
            end
        end

        function raw = restoreManual(obj)
            command = obj.manualRestoreCommand;
            obj.manualRestoreCommand = '';
            obj.manualRestoreFailed = true;
            raw = obj.requestNoData(command);
            obj.manualRestoreFailed = false;
        end
    end
    methods (Static, Access = private)
        function requireSuccess(code, raw)
            if ~strcmp(code,'OK00')
                error('CS2000:InstrumentError', 'Instrument error %s: %s',code,raw);
            end
        end
    end
end

function value = parseSettingCode(payload, allowed, command)
value = colormeasure.drivers.cs2000.numbers(payload,1);
if ~ismember(value,allowed)
    error('CS2000:SettingsPayload','%s returned an unsupported setting code.',command);
end
end

function settings = parseSpeed(payload, allowLegacy)
[~,settings] = colormeasure.drivers.cs2000.speedCommand(payload,allowLegacy);
end

function observer = parseObserver(payload)
value = colormeasure.drivers.cs2000.numbers(payload,1);
if ~ismember(value,[0 1])
    error('CS2000:Observer', 'OBSR must return observer code 0 or 1.');
end
observer = struct('value',value);
end

function calibration = parseCalibrationName(payload)
if numel(payload) ~= 10 || any(payload < 32 | payload > 126)
    error('CS2000:CalibrationName', 'UCPR must return a ten-character printable channel name.');
end
calibration = struct('name',strtrim(payload));
end

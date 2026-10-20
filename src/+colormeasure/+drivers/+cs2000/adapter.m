function adapter = adapter(varargin)
%ADAPTER Ordinary CS-2000 acquisition for an instrument-neutral batch session.
% Driver settings are explicit options; no speed/observer normalization, retry,
% pending-input drain, manual exposure, strobe trigger or motion is introduced.
% PortList(mode), DriverFactory and Transport support isolated software tests.
%   Fernando Voltolini de Azambuja, 2026.
options = inputParser;
options.PartialMatching = false;
options.addParameter('BaudRate',115200,@(x) isnumeric(x) && isscalar(x) && ...
    isfinite(x) && ismember(x,[600 1200 2400 4800 9600 19200 38400 57600 115200]));
options.addParameter('FlowControl','none',@(x) (ischar(x) || ...
    (isstring(x) && isscalar(x))) && any(strcmpi(x,{'none','hardware'})));
options.addParameter('ResponseTimeout',10,@(x) isnumeric(x) && isscalar(x) && ...
    isreal(x) && isfinite(x) && x > 0);
options.addParameter('PreMeasurementTimeout',35,@(x) isnumeric(x) && isscalar(x) && ...
    isreal(x) && isfinite(x) && x >= 35);
options.addParameter('ExpectedModel','',@(x) (ischar(x) && (isrow(x) || isempty(x))) || ...
    (isstring(x) && isscalar(x) && ~ismissing(x)));
options.addParameter('PortList',@serialportlist,@(x) isa(x,'function_handle') && isscalar(x));
options.addParameter('DriverFactory',@colormeasure.drivers.cs2000.CS2000,@(x) isa(x,'function_handle') && isscalar(x));
options.addParameter('Transport',[]);
options.parse(varargin{:});
settings = options.Results;
settings.BaudRate = double(settings.BaudRate);
settings.FlowControl = lower(char(settings.FlowControl));
settings.ResponseTimeout = double(settings.ResponseTimeout);
settings.PreMeasurementTimeout = double(settings.PreMeasurementTimeout);
settings.ExpectedModel = strtrim(char(settings.ExpectedModel));
configuration = struct('BaudRate',settings.BaudRate,'FlowControl',settings.FlowControl, ...
    'ResponseTimeout',settings.ResponseTimeout,'PreMeasurementTimeout',settings.PreMeasurementTimeout, ...
    'ExpectedModel',settings.ExpectedModel,'acquisition','ordinary');
summary = sprintf(['Ordinary CS-2000; baud %g; flow %s; response %g s; pre-measurement %g s; ' ...
    'expected model "%s" (empty accepts standard models).'],settings.BaudRate,settings.FlowControl, ...
    settings.ResponseTimeout,settings.PreMeasurementTimeout,settings.ExpectedModel);
adapter = struct('key','CS2000','label','CS-2000 measurements', ...
    'listPorts',settings.PortList,'connect',@connect, ...
    'read',@readMeasurement,'release',@release,'toTable',@colormeasure.drivers.cs2000.batchTable, ...
    'configuration',configuration,'configurationSummary',summary, ...
    'preparation',colormeasure.drivers.cs2000.preparation());
adapter.catalog = struct('model','CS2000','mode','measure');
% Every connection shares one record of backlight changes left unrestored,
% so the next connection to the same instrument restores them.
unrestoredBacklight = containers.Map('KeyType','char','ValueType','any');

    function instrument = connect(port)
        instrument = settings.DriverFactory(port, ...
            'BaudRate',settings.BaudRate,'FlowControl',settings.FlowControl, ...
            'ResponseTimeout',settings.ResponseTimeout, ...
            'PreMeasurementTimeout',settings.PreMeasurementTimeout, ...
            'ExpectedModel',settings.ExpectedModel,'Transport',settings.Transport, ...
            'PortList',@()settings.PortList('available'),'UnrestoredBacklight',unrestoredBacklight);
        try
            instrument.Connect();
        catch problem
            try
                release(instrument);
                problem=colormeasure.drivers.confirmedConnectionFailure(problem);
            catch cleanupError
                problem=addCause(problem,cleanupError);
            end
            rethrow(problem);
        end
    end
end

function reading = readMeasurement(instrument)
before = size(instrument.XYZData,2);
instrument.Measure();
snapshot = instrument.snapshot();
assert(size(snapshot.XYZData,2) == before+1 && ...
    size(snapshot.spectralData,2) == before+1 && numel(snapshot.metadata) == before+1, ...
    'CS2000:AdapterReading','Measure must append exactly one aligned reading.');
reading = colormeasure.drivers.cs2000.reading(snapshot);
% The core releases its instrument after read returns. Capture restoration
% while the handle still exists, without discarding a complete acquisition.
instrument.Disconnect();
reading.cleanupStatus = instrument.cleanupStatus;
status = reading.cleanupStatus;
if ~status.backlightRestored || ~status.remoteReleased || ~status.speedRestored || ~status.portClosed
    messages={};
    if ~status.portClosed
        messages{end+1}='Connection cleanup is unverified; inspect the connection before another measurement.';
    end
    if ~status.backlightRestored || ~status.remoteReleased || ~status.speedRestored
        messages{end+1}='Instrument settings restoration is unverified; inspect the device before another measurement.';
    end
    reading.warnings = [messages reshape(status.details,1,[])];
end
end

function release(instrument)
% Host cleanup must be confirmed before a destructor can hide its error as
% a warning. Session preserves completed readings even when this throws.
assert(~isempty(instrument)&&isvalid(instrument),'Measurement:ConnectionCleanupUnconfirmed', ...
    'The original instrument owner is unavailable; connection cleanup is unconfirmed.');
colormeasure.drivers.releaseInstrument(instrument);
end

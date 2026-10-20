function adapter = adapter(model, varargin)
%ADAPTER CR acquisition and CSV contract for the shared measurement session.
% DriverFactory(model,port,constructorOptions...) and PortList(scope) are test seams.
% No measurement, device setting change, or port listing occurs here.
% Fernando Voltolini de Azambuja, 2026.
[key,label] = colormeasure.drivers.cr.modelInfo(model);
p = inputParser;
p.addParameter('DriverFactory',@construct,@(x) isa(x,'function_handle'));
p.addParameter('PortList',@serialportlist,@(x) isa(x,'function_handle'));
positive = @(x) isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x>0;
p.addParameter('ResponseTimeout',5,positive);
p.addParameter('MeasurementTimeout',120,positive);
p.parse(varargin{:});
responseTimeout = double(p.Results.ResponseTimeout);
measurementTimeout = double(p.Results.MeasurementTimeout);
options = {'ResponseTimeout',responseTimeout,'MeasurementTimeout',measurementTimeout};
factory = p.Results.DriverFactory;
adapter = struct('key',key,'label',[label ' measurements'], ...
    'listPorts',p.Results.PortList,'connect',@(port) factory(key,port,options{:}), ...
    'read',@readMeasurement,'release',@colormeasure.drivers.releaseInstrument, ...
    'toTable',@colormeasure.drivers.cr.batchTable);
adapter.catalog = struct('model',key,'mode','measure');
adapter.configuration = struct('model',key,'ResponseTimeout',responseTimeout, ...
    'MeasurementTimeout',measurementTimeout,'repeatOnError',false,'DiscardPendingInput',false);
adapter.configurationSummary = sprintf( ...
    '%s; response %.6g s; measurement command %.6g s; no retry or input drain', ...
    label,responseTimeout,measurementTimeout);
adapter.preparation = colormeasure.drivers.cr.preparation(key);
end

function instrument = construct(model,port,varargin)
factory = str2func(['colormeasure.drivers.cr.' model]);
instrument = factory(port,varargin{:});
end

function reading = readMeasurement(instrument)
before = size(instrument.XYZ,1);
instrument.Measure();
if size(instrument.XYZ,1) ~= before+1
    error('CR:AdapterReading','Measure must retain exactly one complete new reading.');
end
reading = colormeasure.drivers.cr.reading(instrument.snapshot());
end

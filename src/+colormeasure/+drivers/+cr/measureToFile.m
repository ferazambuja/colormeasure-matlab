function measurements = measureToFile(model, portName, fileName, options)
%MEASURETOFILE One measurement with reliable connection cleanup.
% Run setupColorMeasure once before using this function.
% Empty port selects one available candidate, then verifies model/ID/firmware.
% Multiple candidates require an explicit port; no scan or measurement retry.
% Example: measurements = colormeasure.drivers.cr.measureToFile("CR250", "", "reading.mat");
% Optional ResponseTimeout and MeasurementTimeout values are forwarded to the
% driver, which defines their defaults and validates them before connecting.
% Fernando Voltolini de Azambuja, 2026.
arguments
    model (1,1) string {mustBeMember(model,["CR100","CR250","CR300"])}
    portName (1,1) string
    fileName (1,1) string
    options.ResponseTimeout
    options.MeasurementTimeout
    options.Transport = [] % Optional simulated transport for software tests.
    options.PortList (1,1) function_handle = @() serialportlist("available")
end
factory = str2func("colormeasure.drivers.cr." + model);
% Omitted public options stay omitted; keep their defaults in the real driver.
names = fieldnames(options); values = struct2cell(options);
driverOptions = reshape([names values].',1,[]);
meter = factory(portName,driverOptions{:});
cleanup = onCleanup(@() delete(meter));
meter.Measure();
meter.Save(fileName);
saved = load(fileName, 'measurements');
measurements = saved.measurements;
end

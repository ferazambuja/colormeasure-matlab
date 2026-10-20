function measurements = measureToFile(portName, fileName, options)
%MEASURETOFILE One measurement with cleanup on every exit.
% An empty port selects one available candidate and verifies its identity.
% Example: measurements = colormeasure.drivers.cs2000.measureToFile("", "reading.mat");
% Pass an explicit port when multiple candidates are available.
% Optional BaudRate, FlowControl, ResponseTimeout, PreMeasurementTimeout and
% ExpectedModel values are forwarded to CS2000, which defines their defaults
% and validates them before connecting. For a matching RS-232C setup:
% measurements = colormeasure.drivers.cs2000.measureToFile("COM4", "reading.mat", ...
%     'BaudRate',9600,'FlowControl','hardware');
% Fernando Voltolini de Azambuja, 2026.
arguments
    portName (1,1) string
    fileName (1,1) string
    options.BaudRate
    options.FlowControl
    options.ResponseTimeout
    options.PreMeasurementTimeout
    options.ExpectedModel
    options.Transport = [] % Isolated simulation seam; no device in tests.
    options.PortList (1,1) function_handle = @() serialportlist("available")
end
% Omitted public options stay omitted; keep their defaults in the real driver.
names = fieldnames(options); values = struct2cell(options);
driverOptions = reshape([names values].',1,[]);
meter = colormeasure.drivers.cs2000.CS2000(portName,driverOptions{:});
cleanup = onCleanup(@()delete(meter));
meter.Connect();
meter.Measure();
meter.Save(fileName);
saved = load(fileName,'measurements');
measurements = saved.measurements;
end

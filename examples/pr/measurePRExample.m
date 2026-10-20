function measurement = measurePRExample(portName)
% MEASUREPREXAMPLE Classic scripting example: connect, measure, plot and release.
%   For batch autosaving, see the session commands in docs/session/README.md.
%   Calling this function immediately measures once; it does not save files.
%   A plotting failure warns but still returns the acquired reading.
%   measurement = measurePRExample()                       % Automatic port
%   measurement = measurePRExample('COM3')                 % Windows
%   measurement = measurePRExample('/dev/cu.usbmodem101')   % macOS
%   Replace the example port with the name shown by serialportlist.
%
%   Fernando Voltolini de Azambuja, 2026.
%   Run setupColorMeasure and add this example folder to the MATLAB path.
%   See docs/drivers/pr/README.md for instrument setup and interpretation of units.
%   Color calculations and sources: docs/session/color-science.md.

narginchk(0, 1);
if nargin == 0
    portName = ''; % Use the driver's automatic single-candidate selection.
end

% See the README's final note for partial, tentative PR-670 support.
pr = colormeasure.drivers.pr.PR655(portName, 'Timeout', 300);
cleanup = onCleanup(@() delete(pr)); % Release the meter even if a step fails.

measurement = pr.measure();
disp(measurement.XYZ);

try
    plot(measurement.lambda, measurement.radiance);
    xlabel('Wavelength (nm)');
    ylabel('Spectral reading (instrument units)');
    title(sprintf('%s spectrum', measurement.deviceType));
    grid on
catch err
    warning('PR655:ExamplePlot', ...
        'The reading was acquired, but its plot is unavailable: %s', err.message);
end
end

function lines = drawSpectrum(measurements, ax)
% DRAWSPECTRUM Draw onto supplied axes without clearing their parent window.
%   Manual plotting helper. The shared UI updates its own graphics in place.
%   Fernando Voltolini de Azambuja, 2026.
validateattributes(ax, {'matlab.graphics.axis.Axes'}, {'scalar'});
cla(ax);
lines = gobjects(numel(measurements), 1);
for index = 1:numel(measurements)
    hue = mod(0.58 + (index - 1) * 0.618033988749895, 1);
    lines(index) = line(ax, measurements(index).lambda, colormeasure.drivers.pr.spectrumOf(measurements(index)), ...
        'Color', hsv2rgb([hue 0.7 0.8]), 'LineWidth', 1.5, ...
        'UserData', index, ...
        'DisplayName', sprintf('%d: %s', index, measurements(index).name));
end
xlabel(ax, 'Wavelength (nm)');
ylabel(ax, 'Spectral reading (instrument units)');
title(ax, ['Measurement batch: ' colormeasure.session.counted(numel(measurements), 'reading', 'readings')]);
legend(ax, 'show', 'Interpreter', 'none');
grid(ax, 'on');
end

function [coordinates, valid] = chromaticity(XYZ, mode)
% CHROMATICITY Guarded display coordinates; acquired XYZ is never modified.
%   MODE is 'uv' (CIE 1976 u'v', default) or 'xy'. Undefined, complex,
%   nonfinite, or negative XYZ rows produce NaN coordinates and valid=false.
%   Fernando Voltolini de Azambuja, 2026.
%   Coordinate definitions: https://cie.co.at/eilvterm/17-23-053 (xy),
%   https://cie.co.at/eilvterm/17-23-073 (u'v'). Scaling and nonnegative-input
%   guards are implementation choices; see docs/session/color-science.md.
if nargin < 2, mode = 'uv'; end
mode = validatestring(mode, {'uv', 'xy'});
validateattributes(XYZ, {'numeric'}, {'2d', 'ncols', 3}, mfilename, 'XYZ');
coordinates = NaN(size(XYZ, 1), 2);
values = double(real(XYZ));
valid = all(imag(XYZ) == 0, 2) & all(isfinite(values), 2) & ...
    all(values >= 0, 2) & any(values > 0, 2);
if ~any(valid), return; end
values = values(valid, :);
% The shared converters scale internally before forming ratios, protecting
% very large and very small finite values without a brightness cutoff.
if strcmp(mode, 'uv')
    result = colormeasure.colorimetry.XYZ2uvY(values);
else
    result = colormeasure.colorimetry.XYZ2xyY(values);
end
coordinates(valid, :) = result(:, 1:2);
end

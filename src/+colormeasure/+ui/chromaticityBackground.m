function [rgb, alpha, x, y] = chromaticityBackground(locusXYZ, mode)
% CHROMATICITYBACKGROUND Small, approximate sRGB chromaticity-diagram image.
%   RGB is 240-by-240-by-3; ALPHA masks the supplied spectral locus and its
%   purple boundary. X and Y are ascending pixel-center coordinates. Invalid
%   or degenerate loci return a transparent image. No acquired data is used.
%   Fernando Voltolini de Azambuja, 2026.
%
%   Colors are orientation aids, not a monitor gamut or color-accurate preview.
%   Negative linear sRGB channels are clipped; each pixel is then normalized
%   to its largest channel before encoding. Luminance is deliberately omitted.
%   Sources: CIE 1976 coordinates, https://cie.co.at/eilvterm/17-23-073
%   CIE xy coordinates: https://cie.co.at/eilvterm/17-23-053
%   ICC sRGB matrix/encoding, A.7-A.8, pp. 1-2:
%   https://registry.color.org/rgb-registry/files/sRGB.pdf
%   XYZ inversion at Y=1, clipping, normalization and theme blending are
%   project display choices; see docs/session/color-science.md.
if nargin < 2, mode = 'uv'; end
mode = validatestring(mode, {'uv', 'xy'});
validateattributes(locusXYZ, {'numeric'}, {'2d'}, mfilename, 'locusXYZ');
if ~isempty(locusXYZ)
    validateattributes(locusXYZ, {'numeric'}, {'ncols', 3}, mfilename, 'locusXYZ');
end

% Two bounded slots retain the current locus for each coordinate mode. A new
% observer replaces its slot; measuring another sample does not rebuild it.
persistent cache
if isempty(cache), cache = cell(1, 2); end
slot = 1 + strcmp(mode, 'xy');
entry = cache{slot};
if ~isempty(entry) && isequaln(entry.locusXYZ, locusXYZ)
    rgb = entry.rgb; alpha = entry.alpha; x = entry.x; y = entry.y;
    return
end

if strcmp(mode, 'uv'), bounds = [.7 .6]; else, bounds = [.8 .9]; end
x = linspace(0, bounds(1), 240);
y = linspace(0, bounds(2), 240);
[horizontal, vertical] = meshgrid(x, y);
rgb = zeros(numel(y), numel(x), 3);
alpha = false(numel(y), numel(x));

if ~isempty(locusXYZ)
    [boundary, valid] = colormeasure.analysis.chromaticity(locusXYZ, mode);
    boundary = boundary(valid, :);
    if size(unique(boundary, 'rows'), 1) >= 3 && ...
            polyarea(boundary(:, 1), boundary(:, 2)) > eps
        alpha = inpolygon(horizontal, vertical, boundary(:, 1), boundary(:, 2));
    end
end

% Inverse chromaticity at Y=1. Mask zero denominators and nonphysical XYZ
% before division; the diagram's surrounding rectangle stays transparent.
alpha = alpha & vertical > 0;
indices = find(alpha);
a = horizontal(indices); b = vertical(indices);
if strcmp(mode, 'uv')
    X = 9*a ./ (4*b);
    Z = (12-3*a-20*b) ./ (4*b);
else
    X = a ./ b;
    Z = (1-a-b) ./ b;
end
physical = isfinite(X) & isfinite(Z) & X >= 0 & Z >= 0;
alpha(indices(~physical)) = false;
indices = indices(physical);
XYZ = [X(physical), ones(sum(physical), 1), Z(physical)];

% Use the same preview encoding as the reading swatches. Inversion and the
% spectral-locus mask stay presentation responsibilities.
encoded = colormeasure.colorimetry.previewColor(XYZ);
for channel = 1:3
    plane = rgb(:, :, channel);
    plane(indices) = encoded(:, channel);
    rgb(:, :, channel) = plane;
end
cache{slot} = struct('locusXYZ', locusXYZ, 'rgb', rgb, 'alpha', alpha, 'x', x, 'y', y);
end

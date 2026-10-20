function xyY = XYZ2xyY(XYZ)
% XYZ2XYY CIE xy chromaticity and unchanged Y from tristimulus values.
%   xyY = colormeasure.colorimetry.XYZ2xyY(XYZ) accepts finite real N-by-3 or 3-by-N
%   single/double XYZ. A 3-by-3 array contains row samples. Output is double
%   with the same orientation. XYZ may be signed; no gamut clipping occurs.
%   Zero denominators (including black) give NaN chromaticities. A coordinate
%   outside the representable double range also becomes NaN. Y is preserved.
%   Y is luminance only when the input quantity and units establish that.
%
%   Formula: CIE S 017:2020, term 17-23-053:
%   https://cie.co.at/eilvterm/17-23-053
%   Interface conventions follow MCSL Tools (MIT); see THIRD_PARTY_NOTICES.md.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
[rows, transposed] = orientRows(XYZ, 3, 'XYZ');
if any(~isfinite(rows), 'all')
    error('colormeasure:Colorimetry:InvalidInput', 'XYZ must contain finite values.');
end
% Divide by the largest row magnitude before summing: large finite XYZ must
% not become zero chromaticity merely because its unscaled sum overflows.
scale = max(abs(rows), [], 2);
scale(scale == 0) = 1;
scaled = rows ./ scale;
denominator = sum(scaled, 2);
coordinates = scaled(:, 1:2) ./ denominator;
coordinates(denominator == 0, :) = nan;
coordinates(~isfinite(coordinates)) = nan;
xyY = [coordinates rows(:, 2)];
if transposed, xyY = xyY.'; end
end

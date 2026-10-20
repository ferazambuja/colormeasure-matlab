function uvY = XYZ2uvY(XYZ)
% XYZ2UVY CIE 1976 u',v' chromaticity and unchanged Y from XYZ.
%   Accepts finite real N-by-3 or 3-by-N single/double XYZ; a 3-by-3 array
%   contains row samples. Output is double with the same orientation.
%   Signed values are retained. A zero denominator, including black, gives
%   NaN chromaticities; an unrepresentable coordinate also becomes NaN.
%   These coordinates are not CIE 1960 uv or CIELUV L*u*v*.
%
%   Formula: CIE S 017:2020, term 17-23-073:
%   https://cie.co.at/eilvterm/17-23-073
%   Interface conventions follow MCSL Tools (MIT); see THIRD_PARTY_NOTICES.md.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
[rows, transposed] = orientRows(XYZ, 3, 'XYZ');
if any(~isfinite(rows), 'all')
    error('colormeasure:Colorimetry:InvalidInput', 'XYZ must contain finite values.');
end
scale = max(abs(rows), [], 2);
scale(scale == 0) = 1;
scaled = rows ./ scale;
denominator = scaled(:, 1) + 15 * scaled(:, 2) + 3 * scaled(:, 3);
coordinates = scaled(:, 1:2) .* [4 9] ./ denominator;
coordinates(denominator == 0, :) = nan;
coordinates(~isfinite(coordinates)) = nan;
uvY = [coordinates rows(:, 2)];
if transposed, uvY = uvY.'; end
end

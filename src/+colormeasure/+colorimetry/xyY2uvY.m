function uvY = xyY2uvY(xyY)
% XYY2UVY CIE 1976 u',v' from xy, optionally retaining unchanged Y.
%   Input is real single/double N-by-2, N-by-3, 2-by-N or 3-by-N. A matching
%   column count takes precedence in ambiguous shapes. Output is double with
%   the same orientation and number of channels. Signed coordinates are
%   allowed. Paired NaN x/y values propagate, including XYZ black results;
%   all other input values must be finite. A zero denominator or an
%   unrepresentable output coordinate produces NaN, without changing Y.
%
%   Formula: CIE S 017:2020, term 17-23-073:
%   https://cie.co.at/eilvterm/17-23-073
%   Interface conventions follow MCSL Tools (MIT); see THIRD_PARTY_NOTICES.md.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
[rows, transposed] = orientRows(xyY, [2 3], 'xyY');
missing = all(isnan(rows(:, 1:2)), 2);
badCoordinates = any(~isfinite(rows(:, 1:2)), 2) & ~missing;
if any(badCoordinates) || (size(rows, 2) == 3 && any(~isfinite(rows(:, 3))))
    error('colormeasure:Colorimetry:InvalidInput', 'xy must be finite or a paired NaN; supplied Y must be finite.');
end
coordinates = rows(:, 1:2);
coordinates(missing, :) = 0;
scale = max([abs(coordinates) ones(size(rows, 1), 1)], [], 2);
scaled = coordinates ./ scale;
denominator = -2 * scaled(:, 1) + 12 * scaled(:, 2) + 3 ./ scale;
uvY = scaled .* [4 9] ./ denominator;
uvY(missing | denominator == 0, :) = nan;
uvY(~isfinite(uvY)) = nan;
if size(rows, 2) == 3, uvY(:, 3) = rows(:, 3); end
if transposed, uvY = uvY.'; end
end

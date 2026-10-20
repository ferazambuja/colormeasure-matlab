function Lab = XYZ2Lab(XYZ, whiteXYZ)
% XYZ2LAB CIELAB using one explicit reference white.
%   Lab = colormeasure.colorimetry.XYZ2Lab(XYZ, whiteXYZ) accepts finite real N-by-3 or
%   3-by-N single/double XYZ. A 3-by-3 array contains row samples. whiteXYZ
%   must be one finite, strictly positive 1-by-3 row in the same XYZ scale.
%   Output is double with the XYZ orientation. No adaptation or clipping is
%   performed. Negative ratios use the real linear branch of the formula.
%   Unrepresentable arithmetic raises colormeasure:Colorimetry:NumericRange.
%
%   Formula: CIE S 017:2020, term 17-23-076:
%   https://cie.co.at/eilvterm/17-23-076
%   Interface conventions follow MCSL Tools (MIT); see THIRD_PARTY_NOTICES.md.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
narginchk(2, 2);
[rows, transposed] = orientRows(XYZ, 3, 'XYZ');
if any(~isfinite(rows), 'all')
    error('colormeasure:Colorimetry:InvalidInput', 'XYZ must contain finite values.');
end
if ~(isa(whiteXYZ, 'single') || isa(whiteXYZ, 'double')) || ...
        ~isreal(whiteXYZ) || ~isequal(size(whiteXYZ), [1 3]) || ...
        any(~isfinite(whiteXYZ)) || any(whiteXYZ <= 0)
    error('colormeasure:Colorimetry:InvalidWhite', 'whiteXYZ must be a finite positive 1-by-3 single or double row.');
end
relative = rows ./ double(whiteXYZ);
if any(~isfinite(relative), 'all')
    error('colormeasure:Colorimetry:NumericRange', 'XYZ divided by the reference white exceeds the numeric range.');
end
nonlinear = relative > (6 / 29)^3;
f = zeros(size(relative));
f(nonlinear) = relative(nonlinear).^(1/3);
f(~nonlinear) = (841 / 108) * relative(~nonlinear) + 4 / 29;
Lab = [116 * f(:, 2) - 16, 500 * (f(:, 1) - f(:, 2)), ...
    200 * (f(:, 2) - f(:, 3))];
if any(~isfinite(Lab), 'all')
    error('colormeasure:Colorimetry:NumericRange', 'CIELAB output exceeds the numeric range.');
end
if transposed, Lab = Lab.'; end
end

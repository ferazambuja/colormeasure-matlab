function difference = deltaE00(Lab, referenceLab)
% DELTAE00 CIEDE2000 color difference with kL = kC = kH = 1.
%   difference = colormeasure.colorimetry.deltaE00(Lab, referenceLab) accepts finite real
%   N-by-3 or 3-by-N single/double values computed with one common reference
%   white. A 3-by-3 array contains row samples. referenceLab must contain one
%   sample or the same sample count as Lab; broadcasting is only along rows.
%   Output is double N-by-1 for row samples or 1-by-N for column samples in
%   the first argument. This is a numerical metric, not an accuracy limit or
%   a claim of perceptual validity for arbitrary emissive/HDR conditions.
%   Arithmetic outside the representable range raises colormeasure:Colorimetry:NumericRange.
%
%   Formulas: Sharma, Wu & Dalal (2005), Color Res. Appl. 30(1), 21-30,
%   equations 2-22, https://doi.org/10.1002/col.20070
%   https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/
%   Independent implementation of the published equations; the authors'
%   restricted MATLAB implementation is not used or reproduced.
%   MCSL-compatible array orientation: see THIRD_PARTY_NOTICES.md.
%   Fernando Voltolini de Azambuja, 2026.
[first, transposed] = orientRows(Lab, 3, 'Lab');
[second, ~] = orientRows(referenceLab, 3, 'referenceLab');
if any(~isfinite(first), 'all') || any(~isfinite(second), 'all')
    error('colormeasure:Colorimetry:InvalidInput', 'Both Lab arrays must contain finite values.');
end
if size(second, 1) ~= 1 && size(second, 1) ~= size(first, 1)
    error('colormeasure:Colorimetry:SampleCount', 'The reference must contain one sample or the same number of samples.');
end
if size(second, 1) == 1, second = repmat(second, size(first, 1), 1); end

chroma1 = hypot(first(:, 2), first(:, 3));
chroma2 = hypot(second(:, 2), second(:, 3));
if any(~isfinite(chroma1) | ~isfinite(chroma2))
    error('colormeasure:Colorimetry:NumericRange', 'Lab chroma exceeds the numeric range.');
end
meanChroma = chroma1 / 2 + chroma2 / 2;
gain = 0.5 * (1 - sqrt(chromaFraction(meanChroma)));
a1 = (1 + gain) .* first(:, 2);
a2 = (1 + gain) .* second(:, 2);
prime1 = hypot(a1, first(:, 3));
prime2 = hypot(a2, second(:, 3));
if any(~isfinite(prime1) | ~isfinite(prime2))
    error('colormeasure:Colorimetry:NumericRange', 'Modified Lab chroma exceeds the numeric range.');
end
hue1 = mod(atan2(first(:, 3), a1) * (180 / pi), 360);
hue2 = mod(atan2(second(:, 3), a2) * (180 / pi), 360);
hue1(prime1 == 0) = 0;
hue2(prime2 == 0) = 0;
achromatic = prime1 == 0 | prime2 == 0;

% Equations 10 and 14 require explicit zero-chroma and circular-hue cases.
hueDifference = hue2 - hue1;
hueDifference(hueDifference > 180) = hueDifference(hueDifference > 180) - 360;
hueDifference(hueDifference < -180) = hueDifference(hueDifference < -180) + 360;
hueDifference(achromatic) = 0;
hueSum = hue1 + hue2;
meanHue = hueSum / 2;
acrossSeam = abs(hue1 - hue2) > 180 & ~achromatic;
belowTurn = acrossSeam & hueSum < 360;
aboveTurn = acrossSeam & hueSum >= 360;
meanHue(belowTurn) = (hueSum(belowTurn) + 360) / 2;
meanHue(aboveTurn) = (hueSum(aboveTurn) - 360) / 2;
meanHue(achromatic) = hueSum(achromatic);

meanLightness = first(:, 1) / 2 + second(:, 1) / 2;
meanPrime = prime1 / 2 + prime2 / 2;
T = 1 - 0.17 * cosd(meanHue - 30) + 0.24 * cosd(2 * meanHue) + ...
    0.32 * cosd(3 * meanHue + 6) - 0.20 * cosd(4 * meanHue - 63);
offset = abs(meanLightness - 50);
lightnessScale = 1 + (0.015 * offset) .* (offset ./ hypot(sqrt(20), offset));
chromaScale = 1 + 0.045 * meanPrime;
hueScale = 1 + (0.015 * meanPrime) .* T;
rotation = -2 * sqrt(chromaFraction(meanPrime)) .* ...
    sind(60 * exp(-((meanHue - 275) / 25).^2));

lightnessTerm = (second(:, 1) - first(:, 1)) ./ lightnessScale;
chromaTerm = (prime2 - prime1) ./ chromaScale;
% Normalize before multiplying square roots to avoid the C1'*C2' product.
hueTerm = (2 * sind(hueDifference / 2)) .* ...
    (sqrt(prime1) ./ sqrt(hueScale)) .* (sqrt(prime2) ./ sqrt(hueScale));
% Complete the square in Eq. 22 and use hypot, avoiding unnecessary squares
% of large differences. This is algebraically the same quadratic form.
difference = hypot(hypot(lightnessTerm, chromaTerm + (rotation / 2) .* hueTerm), ...
    sqrt(max(0, 1 - (rotation / 2).^2)) .* hueTerm);
if any(~isfinite(difference))
    error('colormeasure:Colorimetry:NumericRange', 'CIEDE2000 arithmetic exceeds the numeric range.');
end
if transposed, difference = difference.'; end
end

function ratio = chromaFraction(chroma)
% C^7/(C^7 + 25^7), using the smaller ratio to avoid seventh-power overflow.
ratio = zeros(size(chroma));
small = chroma <= 25;
power = (chroma(small) / 25).^7;
ratio(small) = power ./ (1 + power);
ratio(~small) = 1 ./ (1 + (25 ./ chroma(~small)).^7);
end

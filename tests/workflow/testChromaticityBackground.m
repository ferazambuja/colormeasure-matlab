function tests = testChromaticityBackground
% Synthetic diagram checks; no instrument or display calibration required.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testNativeObserverImagesAreFiniteAndMasked(t)
locus = colormeasure.colorimetry.observer();
for mode = {'uv', 'xy'}
    [rgb, alpha, x, y] = colormeasure.ui.chromaticityBackground(locus, mode{1});
    verifySize(t, rgb, [240 240 3]); verifyClass(t, rgb, 'double');
    verifySize(t, alpha, [240 240]); verifyClass(t, alpha, 'logical');
    verifyTrue(t, all(isfinite(rgb(:))));
    verifyGreaterThanOrEqual(t, min(rgb(:)), 0);
    verifyLessThanOrEqual(t, max(rgb(:)), 1);
    verifyGreaterThan(t, nnz(alpha), 1000);
    verifyFalse(t, any(alpha([1 end], :), 'all'));
    verifyFalse(t, any(alpha(:, [1 end]), 'all'));
    verifyEqual(t, rgb(repmat(~alpha, 1, 1, 3)), zeros(3*nnz(~alpha), 1));
    verifyGreaterThan(t, min(diff(x)), 0); verifyGreaterThan(t, min(diff(y)), 0);
end
end

function testIndependentD65AndPrimaryReferencesInBothModes(t)
% ICC sRGB primary/white chromaticities; coordinates below are independent
% of colormeasure.analysis.chromaticity and the production inverse conversion.
locus = colormeasure.colorimetry.observer();
xy = [.3127 .3290; .64 .33; .30 .60; .15 .06];
uv = [4*xy(:,1), 9*xy(:,2)] ./ (-2*xy(:,1)+12*xy(:,2)+3);
for mode = {'uv', 'xy'}
    [rgb, alpha, x, y] = colormeasure.ui.chromaticityBackground(locus, mode{1});
    if strcmp(mode{1}, 'uv'), points = uv; else, points = xy; end
    colors = sampleColors(rgb, x, y, points);
    verifyEqual(t, colors(1, :), [1 1 1], 'AbsTol', .025);
    verifyEqual(t, colors(2:4, :), eye(3), 'AbsTol', .14);
    inside = interp2(x, y, double(alpha), points(:,1), points(:,2), 'nearest');
    verifyEqual(t, inside, ones(4, 1));
end
end

function testMaskClosesPurpleBoundaryAndExcludesUnphysicalCoordinates(t)
% An adapter may supply a smaller boundary. Its polygon, not a hard-coded
% CIE outline or RGB triangle, determines which pixels are visible.
xy = [.64 .33; .30 .60; .15 .06];
locus = [xy, 1-sum(xy, 2)];
[~, alpha, x, y] = colormeasure.ui.chromaticityBackground(locus, 'xy');
points = [.3127 .3290; .1 .8; .7 .7; .02 .02];
verifyEqual(t, interp2(x, y, double(alpha), points(:,1), points(:,2), 'nearest'), ...
    [1; 0; 0; 0]);
% Equal-energy white lies inside the synthetic closing edge (last to first).
verifyEqual(t, interp2(x, y, double(alpha), 1/3, 1/3, 'nearest'), 1);
end

function testInvalidAndDegenerateLociStayTransparent(t)
loci = {[], zeros(0,3), zeros(3,3), [1 1 1; 2 2 2; 3 3 3], ...
    [NaN 1 1; -1 1 1; Inf 1 1; 1+1i 2 3]};
for index = 1:numel(loci)
    [rgb, alpha] = colormeasure.ui.chromaticityBackground(loci{index});
    verifyFalse(t, any(alpha(:))); verifyEqual(t, rgb, zeros(240,240,3));
end
end

function testModeAndLocusChangesDoNotReturnStaleCachedImages(t)
locus = colormeasure.colorimetry.observer();
[uv, uvAlpha, u, v] = colormeasure.ui.chromaticityBackground(locus, 'uv');
[xy, xyAlpha, x, y] = colormeasure.ui.chromaticityBackground(locus, 'xy');
verifyEqual(t, [u([1 end]) v([1 end])], [0 .7 0 .6]);
verifyEqual(t, [x([1 end]) y([1 end])], [0 .8 0 .9]);
verifyNotEqual(t, uvAlpha, xyAlpha);
% Replace the xy slot, then request the original observer again.
[~, empty] = colormeasure.ui.chromaticityBackground(zeros(0,3), 'xy');
verifyFalse(t, any(empty(:)));
[xyAgain, xyAlphaAgain] = colormeasure.ui.chromaticityBackground(locus, 'xy');
[uvAgain, uvAlphaAgain] = colormeasure.ui.chromaticityBackground(locus, 'uv');
verifyEqual(t, xyAgain, xy); verifyEqual(t, xyAlphaAgain, xyAlpha);
verifyEqual(t, uvAgain, uv); verifyEqual(t, uvAlphaAgain, uvAlpha);
end

function colors = sampleColors(rgb, x, y, points)
colors = zeros(size(points,1), 3);
for channel = 1:3
    colors(:,channel) = interp2(x, y, rgb(:,:,channel), points(:,1), points(:,2));
end
end

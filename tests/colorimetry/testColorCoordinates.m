function tests = testColorCoordinates
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end


function testDefinitionsAndOrientation(testCase)
xyz = [4 5 6; 2 4 8; 1 3 5; 6 2 1];
xy = [xyz(:, 1:2) ./ sum(xyz, 2), xyz(:, 2)];
uv = [4 * xyz(:, 1) ./ (xyz * [1; 15; 3]), ...
    9 * xyz(:, 2) ./ (xyz * [1; 15; 3]), xyz(:, 2)];
verifyEqual(testCase, colormeasure.colorimetry.XYZ2xyY(xyz), xy, 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2xyY(xyz.'), xy.', 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2uvY(xyz), uv, 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2uvY(xyz.'), uv.', 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.xyY2uvY(xy), uv, 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.xyY2uvY(xy.'), uv.', 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.xyY2uvY(xy(:, 1:2)), uv(:, 1:2), 'AbsTol', 1e-15);
verifyEqual(testCase, colormeasure.colorimetry.xyY2uvY(xy(:, 1:2).'), uv(:, 1:2).', 'AbsTol', 1e-15);
end

function testAmbiguousShapesUseRowSamples(testCase)
xyz = [4 5 6; 2 4 8; 1 3 5];
for converter = {@colormeasure.colorimetry.XYZ2xyY, @colormeasure.colorimetry.XYZ2uvY}
    combined = converter{1}(xyz);
    for row = 1:3
        verifyEqual(testCase, combined(row, :), converter{1}(xyz(row, :)));
    end
end
xy = [.2 .3; .4 .2; .1 .2];
verifySize(testCase, colormeasure.colorimetry.xyY2uvY(xy), [3 2]);
for shape = {[.2 .3; .4 .2], [.2 .3 20; .4 .2 40]}
    values = shape{1}; result = colormeasure.colorimetry.xyY2uvY(values);
    verifyEqual(testCase, result(1, :), colormeasure.colorimetry.xyY2uvY(values(1, :)));
end
end

function testBlackAndSignedValues(testCase)
xy = colormeasure.colorimetry.XYZ2xyY([0 0 0]);
uv = colormeasure.colorimetry.XYZ2uvY([0 0 0]);
verifyTrue(testCase, all(isnan(xy(1:2))) && all(isnan(uv(1:2))));
verifyEqual(testCase, xy(3), 0); verifyEqual(testCase, uv(3), 0);
verifyEqual(testCase, colormeasure.colorimetry.xyY2uvY(xy), uv);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2xyY([-1 2 3]), [-.25 .5 2]);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2uvY([-1 2 3]), [-4/38 18/38 2], 'AbsTol', 1e-15);
zeroSum = colormeasure.colorimetry.XYZ2xyY([-1 1 0]);
verifyTrue(testCase, all(isnan(zeroSum(1:2))));
verifyEqual(testCase, zeroSum(3), 1);
% A zero XYZ sum makes xy undefined but need not make direct u'v' undefined.
verifyEqual(testCase, colormeasure.colorimetry.XYZ2uvY([-1 1 0]), [-4/14 9/14 1], 'AbsTol', 1e-15);
zeroUcsDenominator = colormeasure.colorimetry.XYZ2uvY([-15 1 0]);
verifyTrue(testCase, all(isnan(zeroUcsDenominator(1:2))));
verifyEqual(testCase, zeroUcsDenominator(3), 1);
uv = colormeasure.colorimetry.xyY2uvY([1.5 0 -2]);
verifyTrue(testCase, all(isnan(uv(1:2)))); verifyEqual(testCase, uv(3), -2);
end

function testLargeAndTinyRatiosAvoidIntermediateOverflow(testCase)
for magnitude = [realmax realmin]
    xy = colormeasure.colorimetry.XYZ2xyY(magnitude * [1 1 1]);
    uv = colormeasure.colorimetry.XYZ2uvY(magnitude * [1 1 1]);
    verifyEqual(testCase, xy(1:2), [1/3 1/3], 'AbsTol', 1e-15);
    verifyEqual(testCase, uv(1:2), [4/19 9/19], 'AbsTol', 1e-15);
    verifyEqual(testCase, xy(3), magnitude); verifyEqual(testCase, uv(3), magnitude);
end
uv = colormeasure.colorimetry.xyY2uvY([realmax realmax -7]);
verifyEqual(testCase, uv, [.4 .9 -7], 'AbsTol', 1e-15);
end

function testSingleAndEmptyInputs(testCase)
for converter = {@colormeasure.colorimetry.XYZ2xyY, @colormeasure.colorimetry.XYZ2uvY}
    verifyClass(testCase, converter{1}(single([1 2 3])), 'double');
    verifySize(testCase, converter{1}(zeros(0, 3)), [0 3]);
    verifySize(testCase, converter{1}(zeros(3, 0)), [3 0]);
end
verifySize(testCase, colormeasure.colorimetry.xyY2uvY(zeros(0, 2)), [0 2]);
verifyClass(testCase, colormeasure.colorimetry.XYZ2Lab(single([1 2 3]), single([1 2 3])), 'double');
end

function testLabReferenceBlackThresholdAndScaling(testCase)
white = [95.047 100 108.883];
verifyEqual(testCase, colormeasure.colorimetry.XYZ2Lab(white, white), [100 0 0], 'AbsTol', 1e-13);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2Lab([0 0 0], white), [0 0 0], 'AbsTol', 1e-13);
threshold = (6 / 29)^3;
verifyEqual(testCase, colormeasure.colorimetry.XYZ2Lab(white * threshold, white), [8 0 0], 'AbsTol', 1e-13);
xyz = [20 30 10; 4 2 8; 1 1 1; 0 0 0];
lab = colormeasure.colorimetry.XYZ2Lab(xyz, white);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2Lab(xyz.', white), lab.', 'AbsTol', 1e-13);
verifyEqual(testCase, colormeasure.colorimetry.XYZ2Lab(10 * xyz, 10 * white), lab, 'AbsTol', 1e-12);
square = colormeasure.colorimetry.XYZ2Lab(xyz(1:3, :), white);
verifyEqual(testCase, square, lab(1:3, :));
end

function testLabNegativeRatiosRemainReal(testCase)
white = [1 1 1];
xyz = [-.01 -.02 .005];
expectedF = (841 / 108) * xyz + 4 / 29;
expected = [116 * expectedF(2) - 16, 500 * (expectedF(1) - expectedF(2)), ...
    200 * (expectedF(2) - expectedF(3))];
result = colormeasure.colorimetry.XYZ2Lab(xyz, white);
verifyTrue(testCase, isreal(result));
verifyEqual(testCase, result, expected, 'AbsTol', 1e-13);
end

function testInvalidInputsAndWhitesFailClearly(testCase)
for converter = {@colormeasure.colorimetry.XYZ2xyY, @colormeasure.colorimetry.XYZ2uvY}
    for invalid = {uint8([1 2 3]), [1 2 3i], ones(2, 3, 2), [1 nan 3], [1 inf 3]}
        verifyError(testCase, @() converter{1}(invalid{1}), 'colormeasure:Colorimetry:InvalidInput');
    end
    verifyError(testCase, @() converter{1}(ones(2, 4)), 'colormeasure:Colorimetry:InvalidShape');
end
for invalid = {[nan .3 0], [inf inf 0], [.2 .3 nan]}
    verifyError(testCase, @() colormeasure.colorimetry.xyY2uvY(invalid{1}), 'colormeasure:Colorimetry:InvalidInput');
end
for invalid = {[1; 1; 1], [1 0 1], [1 -1 1], [1 inf 1], [1 nan 1], [1 1 1i], uint8([1 1 1])}
    verifyError(testCase, @() colormeasure.colorimetry.XYZ2Lab([1 2 3], invalid{1}), 'colormeasure:Colorimetry:InvalidWhite');
end
verifyError(testCase, @() colormeasure.colorimetry.XYZ2Lab([1 nan 3], [1 1 1]), 'colormeasure:Colorimetry:InvalidInput');
verifyError(testCase, @() colormeasure.colorimetry.XYZ2Lab([realmax 1 1], [realmin 1 1]), 'colormeasure:Colorimetry:NumericRange');
verifyError(testCase, @() colormeasure.colorimetry.XYZ2Lab([-realmax 1 1], [1 1 1]), 'colormeasure:Colorimetry:NumericRange');
end

function tests = testDeltaE00
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end


function testPublished34Pairs(testCase)
% Numeric fixture: Sharma, Wu & Dalal (2005), Table 1 / supplemental data.
% https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/dataNprograms/ciede2000testdata.txt
% The expected differences are published to four decimal places. This test
% uses the data only; it does not import the authors' MATLAB implementation.
fixture = readmatrix(fullfile(fileparts(mfilename('fullpath')), 'data', 'ciede2000.txt'));
verifySize(testCase, fixture, [34 7]);
first = fixture(:, 1:3); second = fixture(:, 4:6);
actual = colormeasure.colorimetry.deltaE00(first, second);
verifyEqual(testCase, actual, fixture(:, 7), 'AbsTol', 5e-5);
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(second, first), actual, 'AbsTol', 1e-12);
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(first.', second.'), actual.', 'AbsTol', 1e-12);
end

function testIdenticalAndAchromaticColors(testCase)
colors = [0 0 0; 50 0 0; 100 0 0; 50 20 -30];
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(colors, colors), zeros(4, 1));
% With both colors neutral and their mean L*=50, SL=1 and chroma/hue vanish.
verifyEqual(testCase, colormeasure.colorimetry.deltaE00([40 0 0], [60 0 0]), 20, 'AbsTol', 1e-13);
verifyEqual(testCase, colormeasure.colorimetry.deltaE00([50 0 0], [50 10 0]), ...
    colormeasure.colorimetry.deltaE00([50 10 0], [50 0 0]), 'AbsTol', 1e-13);
verifyTrue(testCase, isfinite(colormeasure.colorimetry.deltaE00([50 0 0], [50 0 -10])));
end

function testOneReferenceBroadcastAndOrientation(testCase)
samples = [50 1 2; 60 -3 4; 70 5 -6; 80 -7 -8];
reference = [55 2 3];
expected = zeros(4, 1);
for row = 1:4
    expected(row) = colormeasure.colorimetry.deltaE00(samples(row, :), reference);
end
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(samples, reference), expected);
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(samples.', reference.'), expected.');
verifyEqual(testCase, colormeasure.colorimetry.deltaE00(samples(1:3, :), reference), expected(1:3));
verifySize(testCase, colormeasure.colorimetry.deltaE00(zeros(0, 3), reference), [0 1]);
verifySize(testCase, colormeasure.colorimetry.deltaE00(zeros(3, 0), reference), [1 0]);
verifyClass(testCase, colormeasure.colorimetry.deltaE00(single(samples), single(reference)), 'double');
end

function testHueSeamAndLargeChromaRemainFinite(testCase)
first = [50 40 .001]; second = [50 40 -.001];
difference = colormeasure.colorimetry.deltaE00(first, second);
verifyLessThan(testCase, difference, .01);
verifyEqual(testCase, difference, colormeasure.colorimetry.deltaE00(second, first), 'AbsTol', 1e-13);
large = colormeasure.colorimetry.deltaE00([50 1e50 1e50], [50 1.01e50 .99e50]);
verifyTrue(testCase, isfinite(large) && large > 0);
end

function testUnequalChromaDetectsAboveTurnMeanHueRegression(testCase)
% Independent 85-digit evaluation of Sharma et al. (2005), equations 2-22.
% For this pair, mean adjusted hue is 0, delta L'=0 and delta H'=80.
% Equal-chroma seam pairs cannot exercise the nonzero rotation cross-term.
first = [50 20 -20]; second = [50 80 80];
expected = 39.01817399392473;
verifyEqual(testCase,colormeasure.colorimetry.deltaE00(first,second),expected,'AbsTol',1e-10);
verifyEqual(testCase,colormeasure.colorimetry.deltaE00(second,first),expected,'AbsTol',1e-10);
end

function testInvalidDataAndBroadcastingFailClearly(testCase)
reference = [50 0 0];
for invalid = {uint8([1 2 3]), [1 2 3i], [nan 2 3], [1 inf 3], ones(2, 3, 2)}
    verifyError(testCase, @() colormeasure.colorimetry.deltaE00(invalid{1}, reference), 'colormeasure:Colorimetry:InvalidInput');
end
verifyError(testCase, @() colormeasure.colorimetry.deltaE00(ones(2, 4), reference), 'colormeasure:Colorimetry:InvalidShape');
verifyError(testCase, @() colormeasure.colorimetry.deltaE00(ones(4, 3), ones(2, 3)), 'colormeasure:Colorimetry:SampleCount');
verifyError(testCase, @() colormeasure.colorimetry.deltaE00(reference, ones(4, 3)), 'colormeasure:Colorimetry:SampleCount');
verifyError(testCase, @() colormeasure.colorimetry.deltaE00([0 realmax realmax], reference), 'colormeasure:Colorimetry:NumericRange');
verifyError(testCase, @() colormeasure.colorimetry.deltaE00([-realmax 0 0], [realmax 0 0]), 'colormeasure:Colorimetry:NumericRange');
end

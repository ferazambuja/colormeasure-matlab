function tests = testCRScience
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testEqualEnergyUsesIndependentCIEReference(testCase)
% Reference: official CIE CSV, DOI 10.25039/CIE.DS.xvudnb9b, evaluated in
% independent Python/NumPy code. SHA256 and reproduction are in the docs.
reference = [72983.81396481987 72984.72987293049 72977.66485260120; ...
             72984.24536081358 72984.75543572048 72979.64793779360];
for step = [1 2]
    wl = 380:step:780;
    [xyz, total] = colormeasure.drivers.cr.spectralValues(ones(size(wl)), wl);
    verifyEqual(testCase, xyz, reference(step,:), 'AbsTol', 2e-8);
    % Deliberately preserves the existing inclusive rectangle sum.
    verifyEqual(testCase, total, numel(wl)*step);
end
end

function testSignedBinsRemainSignedAndCanGiveValidXYZ(testCase)
wl = 380:780;
radiance = zeros(size(wl));
radiance(ismember(wl, [500 555 600])) = [-0.01 1 0.02];
[xyz, total] = colormeasure.drivers.cr.spectralValues(radiance, wl);
reference = [364.2153395468761 689.4302855951630 2.080468362568067];
verifyEqual(testCase, xyz, reference, 'AbsTol', 2e-10);
verifyEqual(testCase, total, 1.01, 'AbsTol', 1e-14);
verifyEqual(testCase, radiance(wl == 500), -0.01);
% A near-white spectrum with one negative bin still has meaningful CCT.
radiance(:) = 1;
radiance(wl == 380) = -0.01;
[xyz, ~] = colormeasure.drivers.cr.spectralValues(radiance, wl);
[temperature, distance] = colormeasure.drivers.cr.cct(xyz);
verifyTrue(testCase, all(xyz > 0));
verifyTrue(testCase, isfinite(temperature) && isfinite(distance));
end

function testNegativeIntegratedXYZIsRetainedButCCTUnavailable(testCase)
wl = (380:2:780)';
[xyz, total] = colormeasure.drivers.cr.spectralValues(-ones(size(wl)), wl);
verifyTrue(testCase, all(xyz < 0));
verifyEqual(testCase, total, -402);
[temperature, distance] = colormeasure.drivers.cr.cct(xyz);
verifyTrue(testCase, isnan(temperature) && isnan(distance));
end

function testIndependentPlanckAndSignedDuvReferences(testCase)
% Independently integrate Planck's law at 1 nm with official CIE CMFs;
% create +/-0.01 normal offsets to the locus in CIE 1960 (u,v).
xyz = [1.098439051948436 1 0.3559805973880579; ...
       0.9687838667891457 1 1.121180717781349; ...
       0.9124003051058321 1 1.020319027113097; ...
       1.027342082754022 1 1.225932537077682];
expected = [2856 0; 6500 0; 6500 0.01; 6500 -0.01];
for k = 1:size(xyz,1)
    [temperature, distance] = colormeasure.drivers.cr.cct(xyz(k,:));
    verifyEqual(testCase, temperature, expected(k,1), 'AbsTol', 0.1);
    verifyEqual(testCase, distance, expected(k,2), 'AbsTol', 5e-7);
end
end

function testRemoteChromaticitiesAndTableLimitsAreUnavailable(testCase)
% +/-0.06 normal offsets at 6500 K; Planck spectra at 800 and 30000 K.
xyz = [0.6592226415509898 1 0.5674223596587425; ...
       1.357626261314179 1 1.816761134207824; ...
       2.143022932191705 1 0.002309707514828069; ...
       1.005139268121361 1 2.014285859586932];
for k = 1:size(xyz,1)
    [temperature, distance] = colormeasure.drivers.cr.cct(xyz(k,:));
    verifyTrue(testCase, isnan(temperature) && isnan(distance));
end
end

function testInvalidXYZCannotGivePlausibleTemperature(testCase)
cases = {[0 0 0], [1 0 1], [-1 1 1], [1 -1 1], [1 1 -1], ...
         [NaN 1 1], [Inf 1 1], [1 1 1i]};
for k = 1:numel(cases)
    [temperature, distance] = colormeasure.drivers.cr.cct(cases{k});
    verifyTrue(testCase, isnan(temperature) && isnan(distance));
end
verifyError(testCase, @() colormeasure.drivers.cr.cct([1 2]), 'CR:InvalidXYZ');
end

function testCctIsScaleInvariantWithoutOverflow(testCase)
xyz = [0.9687838667891457 1 1.121180717781349];
[referenceCCT, referenceDuv] = colormeasure.drivers.cr.cct(xyz);
[temperature, distance] = colormeasure.drivers.cr.cct(xyz * 1e307);
verifyEqual(testCase, temperature, referenceCCT, 'AbsTol', 1e-6);
verifyEqual(testCase, distance, referenceDuv, 'AbsTol', 1e-10);
end

function testInvalidSpectraFailBeforeAnyIntegration(testCase)
cases = {{[1 2], [500 500]}, {[1 2], [500 499]}, ...
         {[1 2 3], [500 501 503]}, {[1 NaN], [500 501]}, ...
         {[1 Inf], [500 501]}, {[1 2], [500 Inf]}, ...
         {[1 2], [0 1]}, {[1 1i], [500 501]}, ...
         {[1 2], [500 501 502]}, {[], []}, {1, 500}};
for k = 1:numel(cases)
    values = cases{k};
    verifyError(testCase, @() colormeasure.drivers.cr.spectralValues(values{:}), 'CR:InvalidSpectrum');
end
verifyError(testCase, @() colormeasure.drivers.cr.spectralValues(realmax*ones(1,401), 380:780), ...
    'CR:DerivedOverflow');
end

function testLibraryGridValidationPreservesCRInterface(testCase)
% CR retains its numeric-vector API even though colormeasure.colorimetry requires doubles.
[reference, integral] = colormeasure.drivers.cr.spectralValues([1 2 3], [500 501 502]);
[xyz, total] = colormeasure.drivers.cr.spectralValues(uint16([1; 2; 3]), uint16([500; 501; 502]));
verifyEqual(testCase,xyz,reference);
verifyEqual(testCase,total,integral);
verifySize(testCase,xyz,[1 3]);
verifySize(testCase,total,[1 1]);
% This grid passes the CR 1e-9 step check but not the library's roundoff-only
% uniform-grid check, so it is refused and never resampled.
verifyError(testCase,@()colormeasure.drivers.cr.spectralValues([1 2 3],[500 501 502+1e-10]), ...
    'CR:InvalidSpectrum');
[xyz,total] = colormeasure.drivers.cr.spectralValues(ones(1,4001),380:0.1:780);
verifySize(testCase,xyz,[1 3]);
verifyEqual(testCase,total,400.1,'AbsTol',1e-9);
end

function testIntegralOverflowKeepsPublicCRError(testCase)
% Outside the CMF support XYZ remains zero, so this reaches the integral's
% own overflow check rather than only exercising the XYZ product check.
verifyError(testCase,@()colormeasure.drivers.cr.spectralValues([realmax realmax],[900 901]), ...
    'CR:DerivedOverflow');
end

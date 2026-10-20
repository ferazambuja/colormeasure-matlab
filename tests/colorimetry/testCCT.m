function tests = testCCT
% Synthetic mathematical checks; no instrument or external repository needed.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end


function testIndependentPlanckAndSignedDistanceReferences(testCase)
% Independent 1 nm Planck integration of official CIE 1931 2-degree CMFs.
% See docs/colorimetry/cct.md for constants, normal-offset construction and provenance.
xyz = [1.098439051948436 1 0.3559805973880579; ...
       0.9687838667891457 1 1.121180717781349; ...
       0.9124003051058321 1 1.020319027113097; ...
       1.027342082754022 1 1.225932537077682];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT(xyz);
verifyEqual(testCase, temperature, [2856; 6500; 6500; 6500], 'AbsTol', 0.1);
verifyEqual(testCase, distance, [0; 0; 0.01; -0.01], 'AbsTol', 5e-7);
end

function testRemoteChromaticitiesAndTableLimitsAreUnavailable(testCase)
% Signed +/-0.06 normal offsets at 6500 K and Planck spectra at 800/30000 K.
xyz = [0.6592226415509898 1 0.5674223596587425; ...
       1.357626261314179 1 1.816761134207824; ...
       2.143022932191705 1 0.002309707514828069; ...
       1.005139268121361 1 2.014285859586932];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT(xyz);
verifyTrue(testCase, all(isnan(temperature)) && all(isnan(distance)));
end

function testExactTableEndpointsAreNotClampedToValidTemperatures(testCase)
root = colormeasuretest.projectRoot();
data = load(fullfile(root,'resources','colorimetry','PlanckLocus.mat'),'uvY1960');
uv = data.uvY1960([1 end],1:2);
xyz = [3*uv(:,1)./(2*uv(:,2)) ones(2,1) ...
    (4-uv(:,1)-10*uv(:,2))./(2*uv(:,2))];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT(xyz);
verifyTrue(testCase, all(isnan(temperature)) && all(isnan(distance)));
end

function testInvalidRowsDoNotHideValidRows(testCase)
valid = [0.9687838667891457 1 1.121180717781349];
invalid = [0 0 0; 1 0 1; -1 1 1; 1 -1 1; 1 1 -1; NaN 1 1; Inf 1 1];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT([invalid; valid]);
verifyTrue(testCase, all(isnan(temperature(1:end-1))) && all(isnan(distance(1:end-1))));
verifyEqual(testCase, temperature(end), 6500, 'AbsTol', 0.1);
verifyEqual(testCase, distance(end), 0, 'AbsTol', 5e-7);
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT([1 1 1i]);
verifyTrue(testCase, isnan(temperature) && isnan(distance));
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT([1 1 1i; valid]);
verifyTrue(testCase, isnan(temperature(1)) && isnan(distance(1)));
verifyEqual(testCase, temperature(2), 6500, 'AbsTol', 0.1);
end

function testPositiveScaleDoesNotChangeChromaticity(testCase)
xyz = [0.9687838667891457 1 1.121180717781349];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT([xyz; xyz*1e307; xyz*1e-300]);
verifyEqual(testCase, temperature, repmat(temperature(1),3,1), 'AbsTol', 1e-6);
verifyEqual(testCase, distance, repmat(distance(1),3,1), 'AbsTol', 1e-10);
end

function testRowsAndOutputColumnsAreExplicit(testCase)
xyz = [1.098439051948436 1 0.3559805973880579; ...
       0.9687838667891457 1 1.121180717781349; ...
       0.9124003051058321 1 1.020319027113097];
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT(xyz);
verifySize(testCase, temperature, [3 1]);
verifySize(testCase, distance, [3 1]);
for k = 1:3
    [rowTemperature, rowDistance] = colormeasure.colorimetry.XYZ2CCT(xyz(k,:));
    verifyEqual(testCase, temperature(k), rowTemperature);
    verifyEqual(testCase, distance(k), rowDistance);
end

[temperature, distance] = colormeasure.colorimetry.XYZ2CCT(zeros(0,3));
verifySize(testCase, temperature, [0 1]);
verifySize(testCase, distance, [0 1]);
verifyError(testCase, @() colormeasure.colorimetry.XYZ2CCT([1; 1; 1]), 'colormeasure:Colorimetry:InvalidXYZ');
verifyError(testCase, @() colormeasure.colorimetry.XYZ2CCT([1 2]), 'colormeasure:Colorimetry:InvalidXYZ');
verifyError(testCase, @() colormeasure.colorimetry.XYZ2CCT('XYZ'), 'colormeasure:Colorimetry:InvalidXYZ');
end

function testInteriorLocusChordMidpointsRemainAvailable(testCase)
root=colormeasuretest.projectRoot();
data=load(fullfile(root,'resources','colorimetry','PlanckLocus.mat'),'uvY1960','cct');
uv=(data.uvY1960(1:end-2,1:2)+data.uvY1960(3:end,1:2))/2;
xyz=[3*uv(:,1)./(2*uv(:,2)) ones(size(uv,1),1) ...
    (4-uv(:,1)-10*uv(:,2))./(2*uv(:,2))];
[temperature,distance]=colormeasure.colorimetry.XYZ2CCT(xyz);
verifyTrue(testCase,all(isfinite(temperature)) && all(isfinite(distance)));
% Each point lies on its local chord; roundoff must not make the distance imaginary.
verifyEqual(testCase,distance,zeros(size(distance)),'AbsTol',1e-10);
verifyGreaterThan(testCase,temperature,data.cct(1));
verifyLessThan(testCase,temperature,data.cct(end));
end

function testTableIsLoadedRelativeToPackageNotCurrentFolder(testCase)
testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
% A same-name table in the current directory must not substitute for the
% package's pinned scientific data, including on the first call after clear.
cct = [1000 6500 25000];
uvY1960 = ones(3,3);
save('PlanckLocus.mat','cct','uvY1960');
clear colormeasure.colorimetry.XYZ2CCT
[temperature, distance] = colormeasure.colorimetry.XYZ2CCT([0.9687838667891457 1 1.121180717781349]);
verifyEqual(testCase, temperature, 6500, 'AbsTol', 0.1);
verifyEqual(testCase, distance, 0, 'AbsTol', 5e-7);
end

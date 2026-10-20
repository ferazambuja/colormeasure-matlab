function tests = testPR655ComparisonEligibility
% Comparison domains for simulated retained PR records; no physical hardware.
% PR manual Rev B p.113 Table 9 and p.116 Data Code 5 define the unit boundary.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testLiveCodeZeroRetainsReadingsAndChromaticityOnly(t)
records = readings(0); data = colormeasure.drivers.pr.viewData(records);
verifyEqual(t,data.XYZ,vertcat(records.XYZ));
verifyEqual(t,data.spectra{2},struct('x',records(2).lambda,'y',records(2).radiance));
verifyEqual(t,data.observerId,'CIE1931_2deg'); verifyNotEmpty(t,data.locusXYZ);
result = colormeasure.analysis.compareReadings(data,1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,all(isnan(result.deltaXYZ)));
verifyTrue(t,isnan(result.spectralRMS)); verifyEmpty(t,result.spectralDifference);
verifyEmpty(t,result.chromaticityReason); verifyTrue(t,all(isfinite(result.deltaUV)));
verifyFalse(t,result.scaleDeclarationEligible);
end

function testEachDocumentedRadiometricCodeHasItsOwnConvention(t)
keys = cell(1,4);
for code = 11:14
    records = readings(code); data = colormeasure.drivers.pr.viewData(records);
    result = colormeasure.analysis.compareReadings(data,1,2,3);
    verifyEmpty(t,result.colorReason); verifyTrue(t,isfinite(result.deltaE00));
    verifyEmpty(t,result.spectralReason); verifyTrue(t,isfinite(result.spectralRMS));
    verifyEmpty(t,result.chromaticityReason);
    verifyEqual(t,result.deltaXYZ,records(2).XYZ-records(1).XYZ);
    verifyEqual(t,result.spectralDifference,records(2).radiance-records(1).radiance);
    keys{code-10} = data.spectralComparisonKeys{1};
end
verifyEqual(t,numel(unique(keys)),4);
end

function testDifferentQuantitiesWithholdMagnitudeButNotChromaticity(t)
records = readings(11); records(2).unitsCode = 12;
result = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(records),1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,isnan(result.spectralRMS));
verifyTrue(t,all(isnan(result.deltaXYZ))); verifyEmpty(t,result.chromaticityReason);
verifyTrue(t,all(isfinite(result.deltaXY))); verifyFalse(t,result.scaleDeclarationEligible);
end

function testUndefinedAndPhotometricOnlyCodesNeverEstablishMagnitude(t)
for code = [0 -1 1 10 11.5 15 111:114 999 NaN Inf]
    data = colormeasure.drivers.pr.viewData(readings(code));
    result = colormeasure.analysis.compareReadings(data,1,2,3);
    verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,isnan(result.spectralRMS));
    verifyFalse(t,result.scaleDeclarationEligible);
    verifyEmpty(t,result.chromaticityReason);
end
records = rmfield(readings(11),'unitsCode');
result = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(records),1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,isnan(result.spectralRMS));
verifyEmpty(t,result.chromaticityReason);
end

function testUnknownDomainKeysWithholdComparisonsAndDeclarations(t)
data = colormeasure.drivers.pr.viewData(readings(0));
result = colormeasure.analysis.compareReadings(data,1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,isnan(result.spectralRMS));
verifyEmpty(t,result.chromaticityReason);
declaration = struct('confirmed',true,'referenceIndex',1,'sampleIndex',2, ...
    'white',3,'declaredAtUTC','2026-09-17T12:00:00.000Z');
result = colormeasure.analysis.compareReadings(data,1,2,3,declaration);
verifyFalse(t,result.scaleDeclarationEligible); verifyEmpty(t,result.scaleDeclaration);
verifyTrue(t,isnan(result.deltaE00));
end

function testCaptureSettingsDifferencesDoNotRedefinePhysicalUnits(t)
records = readings(11);
records(1).instrumentSettings = struct('after',struct('values',struct( ...
    'exposureMilliseconds',0,'syncMode','auto','primaryAccessoryId',0,'addon1Id',0,'apertureId',0)));
records(2).instrumentSettings = struct('after',struct('values',struct( ...
    'exposureMilliseconds',500,'syncMode','none','primaryAccessoryId',2,'addon1Id',3,'apertureId',1)));
result = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(records),1,2,3);
verifyTrue(t,isfinite(result.deltaE00)); verifyTrue(t,isfinite(result.spectralRMS));
end

function testUnknownXYZMethodDoesNotEraseIndependentKnownSpectra(t)
records = readings(11); records(2).xyzMethod = 'Unrecognized XYZ calculation';
data = colormeasure.drivers.pr.viewData(records);
result = colormeasure.analysis.compareReadings(data,1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,all(isnan(result.deltaUV)));
verifyTrue(t,isfinite(result.spectralRMS)); verifyEmpty(t,result.spectralReason);
verifyEqual(t,data.observerIds{1},'CIE1931_2deg'); verifyEmpty(t,data.observerIds{2});
end

function testCurrentXYZMethodSurvivesMatRoundTrip(t)
records = readings(11); before = records;
expected = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(records),1,2,3);
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename = fullfile(folder.Folder,'current-method.mat'); save(filename,'records'); loaded = load(filename);
actual = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(loaded.records),1,2,3);
verifyEqual(t,loaded.records,before); verifyEqual(t,actual,expected);
end

function testSyntheticCodeZeroRetainsDemoComparisons(t)
records = readings(0);
for index = 1:numel(records)
    records(index).deviceType = 'PR-655';
    records(index).isSynthetic = true;
end
data = colormeasure.drivers.pr.viewData(records); result = colormeasure.analysis.compareReadings(data,1,2,3);
verifyTrue(t,isfinite(result.deltaE00)); verifyTrue(t,isfinite(result.spectralRMS));
verifyEqual(t,data.spectralUnits,'synthetic units');
records(2).isSynthetic = false;
result = colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(records),1,2,3);
verifyTrue(t,isnan(result.deltaE00)); verifyTrue(t,isnan(result.spectralRMS));
verifyNotEmpty(t,result.chromaticityReason);
end

function testUnknownScaleStillAllowsBradfordButNotReflectance(t)
data = colormeasure.drivers.pr.viewData(readings(0));
config = struct('mode','adaptation','sourceWhite',1,'destinationWhite','D65');
adapted = colormeasure.analysis.deriveIllumination(data,2,config);
verifyTrue(t,adapted.available,adapted.reason);
config = struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
reflected = colormeasure.analysis.deriveIllumination(data,2,config);
verifyFalse(t,reflected.available);
verifyNotEmpty(t,reflected.reason);
verifyEmpty(t,reflected.spectrum.y);
verifyTrue(t,all(isnan(reflected.XYZ)));

known = colormeasure.analysis.deriveIllumination(colormeasure.drivers.pr.viewData(readings(11)),2,config);
verifyTrue(t,known.available,known.reason);
verifyEqual(t,known.spectrum.y,0.5*ones(101,1),'AbsTol',1e-14);
end

function records = readings(code)
% Simulated live-shaped records, with positive spectra and explicit provenance.
wavelengths = (380:4:780)'; white = 1 + 0.2*cos((wavelengths-550)/100);
factors = [1 0.5 1.2]; records = struct([]);
for index = 1:numel(factors)
    spectrum = factors(index)*white;
    reading = struct('lambda',wavelengths,'radiance',spectrum, ...
        'XYZ',colormeasure.colorimetry.spectra2XYZ(spectrum,wavelengths), ...
        'xyzMethod','colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1', ...
        'deviceType','PR-655','unitsCode',code, ...
        'spectralUnits','Instrument units; raw M5 unitsCode retained','isSynthetic',false);
    if index == 1, records = reading; else, records(index) = reading; end
end
end

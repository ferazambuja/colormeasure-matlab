function tests=testMeasurementComparison
% Scientific references and independent availability, with synthetic data.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testPublishedPairThroughComparisonWhiteAndLabConversion(t)
% The full Sharma/Wu/Dalal reference set is tested in tests/colorimetry.
% One published pair here verifies the comparison API's XYZ/white/Lab wiring.
data=readmatrix(fullfile(colormeasuretest.projectRoot(),'tests','colorimetry','data','ciede2000.txt'));
d=fixture(); lab=[data(1,1:3);data(1,4:6)];
d.XYZ(1:2,:)=referenceLabToXYZ(lab,d.XYZ(3,:));
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.colorReason);
verifyEqual(t,r.Lab,lab,'AbsTol',1e-10);
verifyEqual(t,r.deltaE00,data(1,7),'AbsTol',5e-5);
end
function testWhiteRatiosSignedDifferencesAndCommonScale(t)
d=fixture();
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.colorReason);verifyEmpty(t,r.spectralReason);
verifyEqual(t,r.deltaXYZ,[1 2 3]);
verifyEqual(t,r.spectralRMS,2,'AbsTol',1e-13);
verifyEqual(t,r.spectralRange,[400 700]);verifyEqual(t,r.spectralStep,100);
swapped=colormeasure.analysis.compareReadings(d,2,1,3);
verifyEqual(t,swapped.deltaE00,r.deltaE00,'AbsTol',1e-12);
verifyEqual(t,swapped.deltaLab,-r.deltaLab,'AbsTol',1e-12);
verifyEqual(t,swapped.deltaH,-r.deltaH,'AbsTol',1e-12);
d.XYZ=d.XYZ*1e-7;scaled=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,scaled.deltaE00,r.deltaE00,'AbsTol',1e-12);
end
function testMetricsDoNotDependOnMissingWhiteOrChromaticity(t)
d=fixture();r=colormeasure.analysis.compareReadings(d,1,2);
verifyTrue(t,isnan(r.deltaE00));verifyNotEmpty(t,r.colorReason);
verifyEqual(t,r.spectralRMS,2);verifyEqual(t,r.deltaXYZ,[1 2 3]);
d.XYZ(1,:)=0;r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyTrue(t,isfinite(r.deltaE00));verifyEqual(t,r.Lab(1,:),[0 0 0]);
verifyTrue(t,all(isnan(r.deltaUV)));
d.XYZ(3,1)=0;r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
end
function testSpectraRemainComparableWithoutXYZ(t)
original=fixture();
for xyz={[],zeros(0,3),NaN(2,3),'unavailable',zeros(2,2)}
    d=original;d.XYZ=xyz{1};
    r=colormeasure.analysis.compareReadings(d,1,2);
    verifyEmpty(t,r.pairReason);verifyEmpty(t,r.spectralReason);
    verifyEqual(t,r.spectralRMS,2);verifyTrue(t,isnan(r.deltaE00));
    verifyNotEmpty(t,r.colorReason);
end
d=rmfield(original,'XYZ');
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,r.spectralRMS,2);verifySubstring(t,r.colorReason,'XYZ');
verifyEmpty(t,r.pairReason);verifyTrue(t,all(isnan(r.deltaXYZ)));
% A missing white XYZ row does not prevent a valid pair's other metrics.
d=original;d.XYZ=d.XYZ(1:2,:);
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,r.deltaXYZ,[1 2 3]);verifyEqual(t,r.spectralRMS,2);
verifyTrue(t,isnan(r.deltaE00));verifySubstring(t,r.colorReason,'White XYZ');
end
function testDifferenceVectorsShareRMSValidationAndDirection(t)
d=fixture();
d.spectra{1}.x=uint16(d.spectra{1}.x');
d.spectra{2}.x=uint16(d.spectra{2}.x');
d.spectra{2}.y=d.spectra{1}.y+[1;-2;0;3];

r=colormeasure.analysis.compareReadings(d,1,2);
verifyEqual(t,r.spectralWavelengths,(400:100:700)');
verifyEqual(t,r.spectralDifference,[1;-2;0;3]);
verifyEqual(t,r.spectralRMS,sqrt(14/4),'AbsTol',1e-14);
swapped=colormeasure.analysis.compareReadings(d,2,1);
verifyEqual(t,swapped.spectralWavelengths,r.spectralWavelengths);
verifyEqual(t,swapped.spectralDifference,-r.spectralDifference);
verifyEqual(t,swapped.spectralRMS,r.spectralRMS);
bad={d,d,d,d,d};
bad{1}.spectralComparisonKeys{2}='different';
bad{2}.spectra{2}.x(2)=501;
bad{3}.spectra{1}.x=[400;501;600;700];bad{3}.spectra{2}.x=bad{3}.spectra{1}.x;
bad{4}.spectra{2}.y(2)=Inf;
bad{5}.spectra{1}.y(:)=-realmax;bad{5}.spectra{2}.y(:)=realmax;
for index=1:numel(bad)
    refused=colormeasure.analysis.compareReadings(bad{index},1,2);
    verifyTrue(t,isnan(refused.spectralRMS));
    verifyEmpty(t,refused.spectralWavelengths);verifyEmpty(t,refused.spectralDifference);
end
end
function testRetainedPRObserverMustMatchItsMethod(t)
m=prReadings();before=m;d=colormeasure.drivers.pr.viewData(m);
verifyEqual(t,d.observerId,'CIE1931_2deg');verifyNotEmpty(t,d.locusXYZ);
r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyTrue(t,isfinite(r.deltaE00));
% The adapter must withhold a 1931 observer for another method, irrespective
% of the numerical XYZ values. Keep this an explicit synthetic provenance case.
for index=1:numel(m)
    m(index).xyzMethod='Synthetic test; CIE 1964 10-degree observer';
end
d=colormeasure.drivers.pr.viewData(m);verifyEmpty(t,d.observerId);verifyEmpty(t,d.locusXYZ);
r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyTrue(t,isnan(r.deltaE00));verifySubstring(t,r.colorReason,'CIE 1931');
verifyTrue(t,isfinite(r.spectralRMS));
measured=colormeasure.analysis.compareReadings(d,1,2,3);verifyTrue(t,isfinite(measured.deltaE00));
% Missing/unknown methods and a mixed batch must never assert a 1931 observer.
m=before;m(2).xyzMethod='Other conversion';
mixed=colormeasure.drivers.pr.viewData(m);verifyEmpty(t,mixed.observerId);verifyEmpty(t,mixed.locusXYZ);
unknown=colormeasure.drivers.pr.viewData(rmfield(before,'xyzMethod'));
verifyEmpty(t,unknown.observerId);verifyEmpty(t,unknown.locusXYZ);
end
function testPRSavedMethodRoundTripPreservesEligibility(t)
m=prReadings();
current='colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1';
for index=1:numel(m),m(index).xyzMethod=current;end
expected=colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(m),1,2,3);
before=m;
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
file=fullfile(folder.Folder,'current-method.mat');save(file,'m');loaded=load(file);
d=colormeasure.drivers.pr.viewData(loaded.m);actual=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,actual,expected);verifyEqual(t,d.observerId,'CIE1931_2deg');
verifyEqual(t,loaded.m,before);
m(1).xyzMethod=[current ' unverified'];
verifyEmpty(t,colormeasure.drivers.pr.viewData(m).observerId);
end
function testPRComparisonKeysFollowConventionsNotSerialPort(t)
m=prReadings();m(1).port='COM3';m(2).port='COM17';
d=colormeasure.drivers.pr.viewData(m);r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyTrue(t,isfinite(r.deltaE00));
withoutPort=colormeasure.drivers.pr.viewData(rmfield(m,'port'));
verifyEqual(t,withoutPort.xyzComparisonKeys,d.xyzComparisonKeys);
changes=struct('deviceType','Different model','unitsCode',1, ...
    'xyzMethod','Different method','spectralUnits','Different units','isSynthetic',false);
names=fieldnames(changes);
for index=1:numel(names)
    changed=m;changed(2).(names{index})=changes.(names{index});
    r=colormeasure.analysis.compareReadings(colormeasure.drivers.pr.viewData(changed),1,2,3);
    verifyNotEmpty(t,r.pairReason);verifyTrue(t,isnan(r.spectralRMS));
end
end
function testInvalidXYZAndMismatchedGridsAreIndependent(t)
d=fixture();d.XYZ(1,1)=-1;r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
d=fixture();d.spectra{2}.x(2)=501;r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyTrue(t,isfinite(r.deltaE00));verifyTrue(t,isnan(r.spectralRMS));
verifySubstring(t,r.spectralReason,'grids differ');
d.spectra{1}.x=d.spectra{2}.x;r=colormeasure.analysis.compareReadings(d,1,2,3);
verifySubstring(t,r.spectralReason,'uniform');
d=fixture();d.xyzComparisonKeys{2}='different unit';d.chromaticityComparisonKeys{2}='different unit';d.spectralComparisonKeys{2}='different unit';r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyNotEmpty(t,r.pairReason);verifyTrue(t,isnan(r.spectralRMS));
d=rmfield(d,{'xyzComparisonKeys','chromaticityComparisonKeys','spectralComparisonKeys'});r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyNotEmpty(t,r.pairReason);
end
function testFiniteXYZSubtractionOverflowWithholdsOnlyUnavailableMetrics(t)
d=fixture();d.XYZ(1,:)=[-realmax 1 1];d.XYZ(2,:)=[realmax 1 1];
for pair={[1 2],[2 1]}
    indices=pair{1};r=colormeasure.analysis.compareReadings(d,indices(1),indices(2),3);
    verifyTrue(t,all(isnan(r.deltaXYZ)));
    verifySubstring(t,r.colorReason,'XYZ differences exceed');
    verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
    verifyEmpty(t,r.spectralReason);
end
end
function testColorPreviewPreservesBrightnessPolicyAndRawData(t)
xyz=[.95047 1 1.08883; 95.047 100 108.883; 0 0 0; -1 2 3; 0 1 0];
[rgb,valid,clipped]=colormeasure.colorimetry.previewColor(xyz);
verifyEqual(t,rgb(1,:),rgb(2,:),'AbsTol',1e-14);
verifyEqual(t,rgb(3,:),[0 0 0]);verifyFalse(t,valid(4));verifyTrue(t,clipped(5));
verifyTrue(t,all(rgb(valid,:)>=0 & rgb(valid,:)<=1,'all'));
end
function testOppositeHuesPreserveDirectionAndRMSAvoidsIntermediateOverflow(t)
d=fixture();white=[1 1 1];
d.XYZ=[referenceLabToXYZ([50 20 0;50 -20 0],white);white];
a=colormeasure.analysis.compareReadings(d,1,2,3);b=colormeasure.analysis.compareReadings(d,2,1,3);
verifyEqual(t,a.deltaH,-b.deltaH,'AbsTol',1e-12);
for i=1:2,d.spectra{i}.x=uint16(d.spectra{i}.x);end
d.spectra{1}.y=zeros(4,1);d.spectra{2}.y=repmat(realmax/2,4,1);
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,r.spectralRMS,realmax/2);verifyEmpty(t,r.spectralReason);
end
function testNegativeSpectralBinDoesNotInvalidatePositiveIntegratedXYZ(t)
lambda=(380:4:780)';spectrum=.001*ones(size(lambda));spectrum(lambda==548)=-.001;
xyz=colormeasure.colorimetry.spectra2XYZ(spectrum,lambda);
[~,valid]=colormeasure.analysis.chromaticity(xyz);
verifyTrue(t,valid);verifyGreaterThan(t,min(xyz),0);
end
function testIlluminantWhitesUsePublishedCIEReferenceAndExplicitScale(t)
% Independently integrated CIE 1 nm SPDs/CMFs; see docs/session/illuminant-whites.md.
expected=[96.4240837883785 100 82.5128116837738; ...
    95.0470558654283 100 108.882873639588;109.850315268456 100 35.5849301338885];
names={'D50','D65','A'};
for i=1:numel(names)
    for Y=[1 100 203]
        w=colormeasure.colorimetry.illuminantWhite(names{i},Y);
        verifyEqual(t,w.XYZ,expected(i,:)*(Y/100),'AbsTol',2e-12);
        verifyEqual(t,w.XYZ(2),Y); verifyEqual(t,w.observerId,'CIE1931_2deg');
    end
end
d=fixture();d.observerId='CIE1931_2deg';before=d;
w=colormeasure.colorimetry.illuminantWhite('d65',100);
preset=colormeasure.analysis.compareReadings(d,1,2,w);
verifyEmpty(t,preset.colorReason);verifyEqual(t,preset.whiteIndex,0);
verifyEqual(t,preset.whiteReference.illuminant,'D65');
verifySubstring(t,preset.whiteReference.source,'10.25039');
d.XYZ(3,:)=w.XYZ;measured=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,preset.Lab,measured.Lab);verifyEqual(t,preset.deltaE00,measured.deltaE00);
d.XYZ=d.XYZ*.01;scaled=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',1));
verifyEqual(t,preset.deltaE00,scaled.deltaE00,'AbsTol',1e-12);
changed=colormeasure.analysis.compareReadings(before,1,2,struct('illuminant','D65','Y',50));
verifyGreaterThan(t,abs(changed.deltaE00-preset.deltaE00),.001);
verifyEqual(t,preset.deltaXYZ,changed.deltaXYZ);verifyEqual(t,preset.spectralRMS,changed.spectralRMS);
end
function testPresetFailuresLeaveIndependentMetricsAvailable(t)
d=fixture();d.observerId='CIE1931_2deg';
for Y={0,-1,NaN,Inf,1i,[],[1 2],realmax}
    r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','A','Y',Y{1}));
    verifyNotEmpty(t,r.colorReason);verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
end
for observer={'CIE1964_10deg','LMS',''}
    d.observerId=observer{1};r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D50','Y',100));
    verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
    verifySubstring(t,r.colorReason,'CIE 1931');
end
d=rmfield(d,'observerId');r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.spectralRMS,2);
d.observerId='CIE1931_2deg';r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D55','Y',100));
verifySubstring(t,r.colorReason,'Supported illuminants');
d.xyzComparisonKeys{2}='different';d.chromaticityComparisonKeys{2}='different';d.spectralComparisonKeys{2}='different';r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyNotEmpty(t,r.pairReason);verifyTrue(t,isnan(r.deltaE00));
end
function testColorRangeFailureLeavesRawDataAndSpectrumAvailable(t)
d=fixture();d.XYZ=[realmax*[1 1 1];realmax*[.9 .9 .9];realmin*[1 1 1]];
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyTrue(t,isnan(r.deltaE00));verifyTrue(t,all(isnan(r.Lab),'all'));
verifySubstring(t,r.colorReason,'Sample-to-white ratios');
verifyEqual(t,r.spectralRMS,2);verifyEmpty(t,r.spectralReason);
end
function testInvalidSpectralGridDoesNotHideColorDifference(t)
d=fixture();
for wavelength={[-100;0;100;200],[400;500;600;700+1e-10],[400;400+1e-9;400+2.01e-9;400+3e-9]}
    d.spectra{1}.x=wavelength{1};d.spectra{2}.x=wavelength{1};
    r=colormeasure.analysis.compareReadings(d,1,2,3);
    verifySubstring(t,r.spectralReason,'uniform');verifyTrue(t,isnan(r.spectralRMS));
    verifyTrue(t,isfinite(r.deltaE00));verifyEmpty(t,r.colorReason);
    verifyEmpty(t,r.spectralDifference);
end
end
function testUnknownXYZScaleLeavesChromaticityAndSpectrumAvailable(t)
d=domainFixture();d.xyzComparisonKeys={'','',''};
% Different unconfirmed scales cannot be subtracted as XYZ or used for Lab.
% The normalized coordinates do not depend on these independent scales.
d.XYZ(2,:)=[22 22 33];
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyEmpty(t,r.chromaticityReason);
verifyEmpty(t,r.spectralReason);verifySubstring(t,r.colorReason,'Common numerical scale');
verifyTrue(t,all(isnan(r.deltaXYZ)));verifyTrue(t,isnan(r.deltaE00));
verifyEqual(t,r.deltaXY,[2/7 2/7]-[1/6 1/3],'AbsTol',1e-14);
verifyEqual(t,r.deltaUV,[88/451 198/451]-[40/400 180/400],'AbsTol',1e-14);
verifyEqual(t,r.spectralRMS,2);verifyEqual(t,r.spectralDifference,2*ones(4,1));
verifyEmpty(t,r.xyzComparisonKey);verifyEqual(t,r.chromaticityComparisonKey,'1931 synthetic');
verifyEqual(t,r.spectralComparisonKey,'synthetic native units');
end
function testEachComparisonDomainCanStandAlone(t)
d=domainFixture();d.xyzComparisonKeys={'','',''};d.spectralComparisonKeys={'','',''};
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyEmpty(t,r.chromaticityReason);
verifyTrue(t,all(isfinite(r.deltaXY)));verifyTrue(t,all(isfinite(r.deltaUV)));
verifyTrue(t,isnan(r.deltaE00));verifyTrue(t,isnan(r.spectralRMS));
verifySubstring(t,r.spectralReason,'conventions');
d=domainFixture();d.xyzComparisonKeys={};d.chromaticityComparisonKeys={};
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyEqual(t,r.spectralRMS,2);
verifyTrue(t,all(isnan(r.deltaXYZ)));verifyTrue(t,all(isnan(r.deltaXY)));
verifyNotEmpty(t,r.chromaticityReason);verifyNotEmpty(t,r.colorReason);
% XYZ and the white share a convention even if another domain is unavailable.
d=domainFixture();d.chromaticityComparisonKeys={};d.spectralComparisonKeys={};
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyEmpty(t,r.colorReason);
verifyTrue(t,isfinite(r.deltaE00));verifyEqual(t,r.deltaXYZ,[1 2 3]);
verifyTrue(t,all(isnan(r.deltaUV)));verifyTrue(t,isnan(r.spectralRMS));
end
function testMeasuredWhiteUsesCommonNumericalScaleRatherThanUnitLabel(t)
d=domainFixture();d.xyzUnits='Unknown physical units; common numerical convention';
baseline=colormeasure.analysis.compareReadings(d,1,2,3);
% Keys explicitly declare the shared scale. No absolute-unit claim is needed
% for ratios to a measured white with that same convention.
d.XYZ=d.XYZ*1e-7;
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.colorReason);verifyTrue(t,isfinite(r.deltaE00));
verifyEqual(t,r.deltaE00,baseline.deltaE00,'AbsTol',1e-12);
verifyEqual(t,r.whiteXYZ,d.XYZ(3,:));
% The white's spectrum and chromaticity keys are irrelevant to Lab ratios.
d.chromaticityComparisonKeys{3}='other';d.spectralComparisonKeys{3}='other';
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.colorReason);verifyEqual(t,r.deltaE00,baseline.deltaE00,'AbsTol',1e-12);
end
function testMismatchedXYZWhitePreservesOtherPairMetrics(t)
d=domainFixture();d.xyzComparisonKeys{3}='different numerical scale';
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifySubstring(t,r.colorReason,'White uses different');
verifyTrue(t,isnan(r.deltaE00));verifyEqual(t,r.deltaXYZ,[1 2 3]);
verifyTrue(t,all(isfinite(r.deltaXY)));verifyEqual(t,r.spectralRMS,2);
% A mismatched pair scale also withholds XYZ subtraction, independently.
d.xyzComparisonKeys{2}='other sample scale';
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);verifyTrue(t,all(isnan(r.deltaXYZ)));
verifyTrue(t,isnan(r.deltaE00));verifyTrue(t,all(isfinite(r.deltaUV)));
verifyEqual(t,r.spectralRMS,2);
end
function testPerReadingObserverAndUnitsOverrideBatchMetadata(t)
d=domainFixture();d.observerId='CIE1964_10deg';d.observer='Batch observer';
d.observerIds={'CIE1931_2deg','CIE1931_2deg','CIE1964_10deg'};
d.observerNames={'CIE 1931 2-degree observer','CIE 1931 2-degree observer','Other observer'};
d.spectralUnitsByReading={'W/(sr m^2 nm)','W/(sr m^2 nm)','Other units'};
r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyEmpty(t,r.colorReason);verifyEqual(t,r.observer,'CIE 1931 2-degree observer');
verifyEqual(t,r.spectralUnits,'W/(sr m^2 nm)');
% The selected rows, not unrelated readings or a scalar batch declaration,
% determine whether the CIE 1931 illuminant preset is valid.
d.observerId='CIE1931_2deg';d.observerIds{2}='CIE1964_10deg';
d.observerNames{2}='CIE 1964 10-degree observer';
r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyTrue(t,isnan(r.deltaE00));verifySubstring(t,r.colorReason,'CIE 1931');
verifyEmpty(t,r.observer);verifyEqual(t,r.spectralRMS,2);
d.observerIds{2}='';d.spectralUnitsByReading{2}='';
r=colormeasure.analysis.compareReadings(d,1,2,struct('illuminant','D65','Y',100));
verifyTrue(t,isnan(r.deltaE00));verifyEmpty(t,r.spectralUnits);
verifyEqual(t,r.spectralRMS,2);
end
function testEmptyOrMalformedDomainKeysWithholdEveryDomain(t)
d=fixture();baseline=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEqual(t,fieldnames(baseline),{'referenceIndex';'sampleIndex';'whiteIndex';'whiteReference'; ...
    'whiteXYZ';'observer';'xyzComparisonKey';'chromaticityComparisonKey';'spectralComparisonKey'; ...
    'scaleDeclaration';'scaleDeclarationEligible';'deltaXYZ';'deltaUV';'deltaXY';'Lab';'deltaLab'; ...
    'deltaC';'deltaH';'deltaE00';'spectralRMS';'spectralRange';'spectralWavelengths'; ...
    'spectralDifference';'spectralStep';'spectralUnits';'colorReason';'spectralReason'; ...
    'chromaticityReason';'pairReason'});
verifyEqual(t,baseline.xyzComparisonKey,'same');
verifyEqual(t,baseline.chromaticityComparisonKey,'same');
verifyEqual(t,baseline.spectralComparisonKey,'same');
for value={{},{'',''},{'same'},[],{'same',42}}
    d.xyzComparisonKeys=value{1};d.chromaticityComparisonKeys=value{1};
    d.spectralComparisonKeys=value{1};
    r=colormeasure.analysis.compareReadings(d,1,2,3);
    verifyNotEmpty(t,r.pairReason);verifyNotEmpty(t,r.colorReason);
    verifyNotEmpty(t,r.chromaticityReason);verifyNotEmpty(t,r.spectralReason);
    verifyTrue(t,all(isnan(r.deltaXYZ)));verifyTrue(t,all(isnan(r.deltaXY)));
    verifyTrue(t,isnan(r.deltaE00));verifyTrue(t,isnan(r.spectralRMS));
end
% Explicit domain keys define row identity.
d=domainFixture();
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.pairReason);
verifyEmpty(t,r.colorReason);verifyEqual(t,r.spectralRMS,2);
end
function testOperatorScaleDeclarationWithMeasuredWhite(t)
d=declarationFixture();
confirmation=scaleDeclaration(1,2,3);confirmation.note='Same acquisition scale';
r=colormeasure.analysis.compareReadings(d,1,2,3,confirmation);
verifyEmpty(t,r.colorReason);verifyTrue(t,isfinite(r.deltaE00));
verifyEqual(t,r.deltaXYZ,[1 2 3]);verifyEqual(t,r.spectralRMS,2);
expected=confirmation;expected.source='operator';
verifyEqual(t,r.scaleDeclaration,expected);
verifyTrue(t,r.scaleDeclarationEligible);
verifyEqual(t,r.xyzComparisonKey,'operator-declared:same device XYZ convention');
% Reversing the pair requires a new declaration, not a reused checkbox value.
swapped=colormeasure.analysis.compareReadings(d,2,1,3,scaleDeclaration(2,1,3));
verifyEqual(t,swapped.deltaE00,r.deltaE00,'AbsTol',1e-12);
verifyEqual(t,swapped.deltaXYZ,-r.deltaXYZ);
end
function testOperatorScaleDeclarationWithPresetAndNumericGuards(t)
d=declarationFixture();d.observerId='CIE1931_2deg';
white=struct('illuminant','D65','Y',100);confirmation=scaleDeclaration(1,2,white);
r=colormeasure.analysis.compareReadings(d,1,2,white,confirmation);
verifyEmpty(t,r.colorReason);verifyTrue(t,isfinite(r.deltaE00));
verifyEqual(t,r.scaleDeclaration.declaredAtUTC,confirmation.declaredAtUTC);
verifyEqual(t,r.scaleDeclaration.source,'operator');
d.observerId='CIE1964_10deg';
r=colormeasure.analysis.compareReadings(d,1,2,white,confirmation);
verifySubstring(t,r.colorReason,'CIE 1931');verifyTrue(t,isnan(r.deltaE00));
verifyEqual(t,r.spectralRMS,2);
d.observerId='CIE1931_2deg';d.XYZ(1,1)=-1;
r=colormeasure.analysis.compareReadings(d,1,2,white,confirmation);
verifySubstring(t,r.colorReason,'nonnegative XYZ');verifyTrue(t,isnan(r.deltaE00));
verifyEqual(t,r.spectralRMS,2);
end
function testStaleOrIncompleteScaleDeclarationsCannotEnableXYZ(t)
d=declarationFixture();white=struct('illuminant','D65','Y',100);
valid=scaleDeclaration(1,2,white);
bad={valid,valid,valid,valid,valid,valid,valid,valid,valid,struct([]),false};
bad{1}.referenceIndex=2;bad{2}.sampleIndex=3;
bad{3}.white.Y=50;bad{4}.white=3;bad{5}.confirmed=false;
bad{6}.declaredAtUTC='';bad{7}.declaredAtUTC='  ';bad{8}.declaredAtUTC=NaN;
bad{9}=rmfield(valid,'declaredAtUTC');
for index=1:numel(bad)
    r=colormeasure.analysis.compareReadings(d,1,2,white,bad{index});
    verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
    verifyTrue(t,all(isnan(r.deltaXYZ)));verifyEqual(t,r.spectralRMS,2);
    verifySubstring(t,r.colorReason,'Common numerical scale');
    verifyTrue(t,r.scaleDeclarationEligible);
end
r=colormeasure.analysis.compareReadings(d,1,2,3,scaleDeclaration(1,2,2));
verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
r=colormeasure.analysis.compareReadings(d,1,2,3);
verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
verifyTrue(t,r.scaleDeclarationEligible);
end
function testScaleDeclarationRequiresSeparateMatchingEligibilityKeys(t)
d=declarationFixture();confirmation=scaleDeclaration(1,2,3);
for keys={{},{'','',''},{'same','same','other'},{'same','other','same'},[],{'same','same'}}
    changed=d;changed.xyzScaleDeclarationKeys=keys{1};
    r=colormeasure.analysis.compareReadings(changed,1,2,3,confirmation);
    verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
    verifyEqual(t,r.spectralRMS,2);verifyTrue(t,all(isfinite(r.deltaXY)));
    verifyFalse(t,r.scaleDeclarationEligible);
end
d=rmfield(d,'xyzScaleDeclarationKeys');
r=colormeasure.analysis.compareReadings(d,1,2,3,confirmation);
verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
end
function testScaleDeclarationCannotReplaceKnownXYZConventions(t)
d=declarationFixture();confirmation=scaleDeclaration(1,2,3);
for keys={{'known','',''},{'one','two','one'},{'same','same','other'},42}
    changed=d;changed.xyzComparisonKeys=keys{1};
    r=colormeasure.analysis.compareReadings(changed,1,2,3,confirmation);
    verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
    verifyEqual(t,r.spectralRMS,2);
end
% A valid automatic comparison remains automatic despite a supplied stamp.
d.xyzComparisonKeys=repmat({'known common convention'},3,1);
r=colormeasure.analysis.compareReadings(d,1,2,3,confirmation);
verifyEmpty(t,r.colorReason);verifyTrue(t,isfinite(r.deltaE00));
verifyEmpty(t,r.scaleDeclaration);verifyEqual(t,r.xyzComparisonKey,'known common convention');
verifyFalse(t,r.scaleDeclarationEligible);
% Missing both the XYZ key and the separate scale declaration withholds Lab.
d=rmfield(d,'xyzComparisonKeys');d=rmfield(d,'xyzScaleDeclarationKeys');
r=colormeasure.analysis.compareReadings(d,1,2,3,confirmation);
verifyEmpty(t,r.scaleDeclaration);verifyTrue(t,isnan(r.deltaE00));
end
function d=declarationFixture()
d=domainFixture();d.xyzComparisonKeys={'','',''};
d.xyzScaleDeclarationKeys=repmat({'same device XYZ convention'},3,1);
end
function value=scaleDeclaration(reference,sample,white)
value=struct('confirmed',true,'referenceIndex',reference,'sampleIndex',sample, ...
    'white',white,'declaredAtUTC','2026-09-16T18:25:30.123Z');
end
function d=domainFixture()
d=fixture();
d.xyzComparisonKeys=repmat({'synthetic common numerical scale'},3,1);
d.chromaticityComparisonKeys=repmat({'1931 synthetic'},3,1);
d.spectralComparisonKeys=repmat({'synthetic native units'},3,1);
end
function XYZ=referenceLabToXYZ(Lab,white)
% Independent fixture construction from the inverse CIELAB definition,
% CIE S 017:2020, term 17-23-076. Production only implements the forward map.
fY=(Lab(:,1)+16)/116;
f=[fY+Lab(:,2)/500,fY,fY-Lab(:,3)/200];
relative=f.^3;
linear=f<=6/29;
relative(linear)=(f(linear)-4/29)*(108/841);
XYZ=relative.*white;
end
function d=fixture()
d=struct('XYZ',[10 20 30;11 22 33;95 100 108], ...
    'observer','Test observer','xyzComparisonKeys',{{'same','same','same'}}, ...
    'chromaticityComparisonKeys',{{'same','same','same'}}, ...
    'spectralComparisonKeys',{{'same','same','same'}}, ...
    'spectralUnits','test units','spectra',{{ ...
    struct('x',(400:100:700)','y',[-1;2;3;4]), ...
    struct('x',(400:100:700)','y',[1;4;5;6]), ...
    struct('x',(400:100:700)','y',[4;4;4;4])}});
end
function m=prReadings()
adapter=colormeasure.drivers.pr.adapter();
for index=1:3
    instrument=colormeasure.drivers.pr.DemoInstrument(index,0);
    cleanup=onCleanup(@() delete(instrument));
    reading=adapter.read(instrument);reading.port='DEMO';
    if index==1,m=reading;else,m(index)=reading;end
    clear cleanup
end
end

function tests=testMeasurementIllumination
% Scientific view integration: original readings, references and refusals.
% Fernando Voltolini de Azambuja, 2026.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testAdaptationPreservesMeasurementAndMapsWhite(t)
d=fixture();
c=struct('mode','adaptation','sourceWhite',1,'destinationWhite','D65');
r=colormeasure.analysis.deriveIllumination(d,1,c);
verifyTrue(t,r.available,r.reason); w=colormeasure.colorimetry.illuminantWhite('D65',d.XYZ(1,2));
verifyEqual(t,r.XYZ,w.XYZ,'AbsTol',1e-9);
verifyEqual(t,r.rgb,[1 1 1],'AbsTol',4e-4);
verifyEmpty(t,r.spectrum.x);verifyEqual(t,r.sourceSpectrum,d.spectra{1});
verifyNotEmpty(t,r.createdAtUTC);verifyEqual(t,r.config,c);
verifySubstring(t,r.provenance.whiteXYZConvention,'not a same-scale Lab white');
end
function testXYZOnlyAdaptationDoesNotRequireAbsoluteScale(t)
d=fixture();d.hasSpectra=false;d.spectra={[];[]};d.xyzComparisonKeys={'';''};
c=struct('mode','adaptation','sourceWhite',1,'destinationWhite','D50');
r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyTrue(t,r.available,r.reason);verifyEmpty(t,r.sourceSpectrum);
c=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyFalse(t,r.available);verifySubstring(t,r.reason,'spectrum');
end
function testDisplayPreviewWhiteIsFixedWhileDestinationCoordinatesChange(t)
d=fixture();c=struct('mode','adaptation','sourceWhite','A','destinationWhite','D50');
a=colormeasure.analysis.deriveIllumination(d,2,c);c.destinationWhite='D65';
b=colormeasure.analysis.deriveIllumination(d,2,c);
verifyTrue(t,a.available,a.reason);verifyTrue(t,b.available,b.reason);
verifyGreaterThan(t,norm(a.XYZ-b.XYZ),1);
verifyEqual(t,a.rgb,b.rgb,'AbsTol',1e-12);
end
function testUnknownObserverAndIncompatibleWhiteRefused(t)
d=fixture();d.observerIds{2}='';
c=struct('mode','adaptation','sourceWhite','D50','destinationWhite','D65');
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
d=fixture();d.chromaticityComparisonKeys{1}='other';c.sourceWhite=1;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
end
function testBatchObserverSummaryCannotAuthorizeChromaticAdaptation(t)
d=rmfield(fixture(),'observerIds');d.observerId='CIE1931_2deg';
% Observer fields are optional in viewData. A valid summary-only view does
% not confirm the observer of the selected reading for adaptation.
verifyEqual(t,colormeasure.session.validateViewData(d,2),d);
c=struct('mode','adaptation','sourceWhite','D50','destinationWhite','D65');
r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyFalse(t,r.available);
verifyEqual(t,r.reason,'This view requires confirmed CIE 1931 2-degree coordinates.');
verifyTrue(t,all(isnan(r.XYZ)));verifyEqual(t,r.sourceXYZ,d.XYZ(2,:));
end
function testBatchObserverSummaryCannotOverrideAnIncompatibleReading(t)
d=fixture();d.observerId='CIE1931_2deg';d.observerIds{2}='CIE1964_10deg';
verifyEqual(t,colormeasure.session.validateViewData(d,2),d);
c=struct('mode','adaptation','sourceWhite','D50','destinationWhite','D65');
r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyFalse(t,r.available);
verifyEqual(t,r.reason,'This view requires confirmed CIE 1931 2-degree coordinates.');
verifyTrue(t,all(isnan(r.XYZ)));verifyEqual(t,r.sourceXYZ,d.XYZ(2,:));
end
function testMeasuredSourceWhiteNeedsItsOwnConfirmedObserver(t)
for observer={'CIE1964_10deg',''}
    d=fixture();d.observerIds{1}=observer{1};d.observerId='CIE1931_2deg';
    verifyEqual(t,colormeasure.session.validateViewData(d,2),d);
    c=struct('mode','adaptation','sourceWhite',1,'destinationWhite','D65');
    r=colormeasure.analysis.deriveIllumination(d,2,c);
    verifyFalse(t,r.available);
    verifyEqual(t,r.reason,'This view requires confirmed CIE 1931 2-degree coordinates.');
    verifyTrue(t,all(isnan(r.XYZ)));verifyEqual(t,r.sourceXYZ,d.XYZ(2,:));
end
end
function testMeasuredDestinationWhiteNeedsItsOwnConfirmedObserver(t)
for observer={'CIE1964_10deg',''}
    d=fixture();d.observerIds{1}=observer{1};d.observerId='CIE1931_2deg';
    verifyEqual(t,colormeasure.session.validateViewData(d,2),d);
    c=struct('mode','adaptation','sourceWhite','D50','destinationWhite',1);
    r=colormeasure.analysis.deriveIllumination(d,2,c);
    verifyFalse(t,r.available);
    verifyEqual(t,r.reason,'This view requires confirmed CIE 1931 2-degree coordinates.');
    verifyTrue(t,all(isnan(r.XYZ)));verifyEqual(t,r.sourceXYZ,d.XYZ(2,:));
end
end
function testReflectanceRequiresExplicitAssumptions(t)
d=fixture();c=reflectanceConfig();c.confirmedSetup=false;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
c.confirmedSetup=true;c.assumePerfectReference=false;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
c.assumePerfectReference=true;r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyTrue(t,r.available,r.reason);verifyEqual(t,r.spectrum.y,.5*ones(81,1),'AbsTol',1e-14);
verifyEqual(t,r.XYZ,.5*r.whiteXYZ,'AbsTol',1e-10);
verifyEqual(t,r.whiteXYZ(2),100,'AbsTol',1e-12);
verifySubstring(t,r.label,'Assumed ideal');
end
function testCharacterizedReferenceInterpolationAndProvenance(t)
d=fixture(); c=reflectanceConfig();c.assumePerfectReference=false;
c.referenceReflectance=[380 .6;780 1.0];c.referenceReflectanceFile='white-reference.csv';
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyTrue(t,r.available,r.reason);
expected=.3+.2*((0:80)'/80); % Independent linear reference interpolation, then sample/white ratio.
verifyEqual(t,r.spectrum.y,expected,'AbsTol',1e-14);
verifyEqual(t,r.config.referenceReflectanceFile,'white-reference.csv');
verifyEqual(t,r.referenceSpectrum,d.spectra{1});
c.referenceReflectance=[400 .8;780 .8];
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
end
function testMeasuredTargetIlluminantAndSignedSpectrumRetained(t)
d=fixture();c=reflectanceConfig();c.targetIlluminant=1;
d.spectra{2}.y(1)=-.1;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyTrue(t,r.available,r.reason);
verifyLessThan(t,r.spectrum.y(1),0);
verifyEqual(t,r.provenance.targetSpectrum,d.spectra{1});
verifySubstring(t,r.provenance.targetIlluminant,'Reading 1');
end
function testMismatchedGridWeakReferenceAndUnitsRefused(t)
c=reflectanceConfig();
d=fixture();d.spectra{1}.x=d.spectra{1}.x+1;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
d=fixture();d.spectra{1}.y(30)=0;
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
d=fixture();d.spectralComparisonKeys{1}='unknown';
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyFalse(t,r.available);
end
function testSpectralComparabilityDoesNotAuthorizeReflectanceRatio(t)
c=reflectanceConfig();
for quantity={'reflectance','irradiance','radiant intensity','radiant flux','unknown'}
    d=fixture();
    d.spectralQuantities(:)=quantity;
    % Even a contradictory eligibility flag cannot turn native reflectance
    % or another quantity into radiance. Spectral comparison remains useful.
    pair=colormeasure.analysis.compareReadings(d,1,2);
    verifyEmpty(t,pair.spectralReason);
    r=colormeasure.analysis.deriveIllumination(d,2,c);
    verifyFalse(t,r.available,quantity{1});verifySubstring(t,r.reason,'radiance');
end
end
function testBothRowsNeedExplicitValidEligibility(t)
c=reflectanceConfig();base=fixture();
variants={rmfield(base,'reflectanceRatioEligible'),rmfield(base,'spectralQuantities')};
for flags={true,[true;false],[false;true],[1;1],{true;true},[true;true;true]}
    d=base;d.reflectanceRatioEligible=flags{1};variants{end+1}=d; %#ok<AGROW>
end
for quantities={{'radiance'},'radiance',{42;'radiance'},{'radiance';missing}}
    d=base;d.spectralQuantities=quantities{1};variants{end+1}=d; %#ok<AGROW>
end
for index=1:numel(variants)
    r=colormeasure.analysis.deriveIllumination(variants{index},2,c);
    verifyFalse(t,r.available,sprintf('Variant %d',index));
end
d=base;d.reflectanceRatioEligible(1)=false;
verifySubstring(t,colormeasure.analysis.deriveIllumination(d,2,c).reason,'Reference:');
d=base;d.reflectanceRatioEligible(2)=false;
verifySubstring(t,colormeasure.analysis.deriveIllumination(d,2,c).reason,'Sample:');
end
function testDeclaredRadianceDoesNotRequireAnAbsoluteXYZScale(t)
d=fixture();d.spectralQuantities(:)={'radiance'};
d.xyzComparisonKeys(:)={''};d.XYZ(:)=NaN;
d.spectralUnits='provisional common radiance scale';
r=colormeasure.analysis.deriveIllumination(d,2,reflectanceConfig());
verifyTrue(t,r.available,r.reason);
verifyEqual(t,r.spectrum.y,.5*ones(81,1),'AbsTol',1e-14);
verifyEqual(t,r.provenance.quantityContext.sample.quantity,'radiance');
verifyEqual(t,r.provenance.quantityContext.reference.units,d.spectralUnits);
verifyTrue(t,r.provenance.quantityContext.sample.adapterDeclaredEligible);
verifyEqual(t,r.config.confirmedSetup,true);
verifyEqual(t,r.provenance.setupDeclaredBy,'operator');
end
function testNarrowBandTargetRetainsXYZWhenAdaptedPreviewUnavailable(t)
d=fixture();d.spectra{3}=d.spectra{1};d.spectra{3}.y(:)=0;
d.spectra{3}.y(end)=1;d.XYZ(3,:)=[1 1 0];
d.observerIds{3}='CIE1931_2deg';d.observerNames{3}=d.observerNames{1};
d.xyzComparisonKeys{3}='synthetic';d.chromaticityComparisonKeys{3}='synthetic';
d.spectralComparisonKeys{3}='synthetic';c=reflectanceConfig();c.targetIlluminant=3;
d.reflectanceRatioEligible(3)=true;d.spectralQuantities{3}='synthetic radiance';
r=colormeasure.analysis.deriveIllumination(d,2,c);verifyTrue(t,r.available,r.reason);
verifyEqual(t,r.XYZ(2),50,'AbsTol',1e-12);verifyEqual(t,r.XYZ(3),0);
verifyTrue(t,all(isnan(r.rgb)));verifyFalse(t,isempty(r.spectrum.x));
end
function c=reflectanceConfig()
c=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
end
function d=fixture()
w=(380:5:780)';spd=1+.3*cos((w-550)/100);
white=colormeasure.colorimetry.illuminantWhite('D50',100);
d=struct('XYZ',[white.XYZ;white.XYZ*.5], ...
    'observerIds',{{'CIE1931_2deg';'CIE1931_2deg'}}, ...
    'observerNames',{{'CIE 1931 2-degree observer';'CIE 1931 2-degree observer'}}, ...
    'xyzComparisonKeys',{{'synthetic';'synthetic'}}, ...
    'chromaticityComparisonKeys',{{'synthetic';'synthetic'}}, ...
    'spectralComparisonKeys',{{'synthetic';'synthetic'}}, ...
    'reflectanceRatioEligible',true(2,1), ...
    'spectralQuantities',{{'synthetic radiance';'synthetic radiance'}}, ...
    'spectralUnits','synthetic units','hasSpectra',true, ...
    'spectra',{{struct('x',w,'y',spd);struct('x',w,'y',spd*.5)}});
end

function testZeroCharacterizedReferenceIsRefusedAtTheViewBoundary(t)
d=fixture();c=reflectanceConfig();c.assumePerfectReference=false;
c.referenceReflectance=[380 0;780 .8];
r=colormeasure.analysis.deriveIllumination(d,2,c);
verifyFalse(t,r.available);
verifyEqual(t,r.reason,'White-reference data needs increasing wavelengths and positive fractions (1 = 100%).');
end

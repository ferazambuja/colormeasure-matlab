function tests = testChartContext
% Chart pass semantics use declared acquisition facts without instrument I/O.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testCatalogueCensusIncludesNativeExpertAndPhysicalReadbacks(t)
catalogues = { ...
    'PR',colormeasure.drivers.pr.settingsCatalog('PR-670',struct(),true); ...
    'CS2000',colormeasure.drivers.cs2000.settingsCatalog(); ...
    'CR',colormeasure.drivers.cr.settingsControls('CR-100'); ...
    'CR',colormeasure.drivers.cr.settingsControls('CR-250'); ...
    'CR',colormeasure.drivers.cr.settingsControls('CR-300')};
for row=1:size(catalogues,1)
    value=colormeasure.chart.catalogClassification(catalogues{row,1},catalogues{row,2});
    verifyEqual(t,sort(value.catalogueKeys),sort({catalogues{row,2}.id}));
    catalogue=catalogues{row,2};rogue=[reshape(catalogue,1,[]) catalogue(1)];
    rogue(end).id='newUnclassifiedSetting';
    verifyError(t,@()colormeasure.chart.catalogClassification(catalogues{row,1},rogue), ...
        'Chart:ContextCatalog');
end
end

function testEmptyCataloguesHaveNoKeysAndDoNotRelaxNonemptyValidation(t)
for route={'PR','CR','CS2000'}
    for controls={struct([]),struct('id',{}),{}}
        value=colormeasure.chart.catalogClassification(route{1},controls{1});
        verifyEmpty(t,value.catalogueKeys);verifyEqual(t,value.route,route{1});
    end
    for controls={[], '', struct('label','Missing ID'),struct('id','unclassified')}
        verifyError(t,@()colormeasure.chart.catalogClassification(route{1},controls{1}), ...
            'Chart:ContextCatalog');
    end
end
for controls={struct([]),struct('id',{}),{},[], '',struct('label','Missing ID'),struct('id','unclassified')}
    verifyError(t,@()colormeasure.chart.catalogClassification('ARGYLL',controls{1}), ...
        'Chart:ContextCatalog');
end
duplicate=repmat(struct('id','cycles'),1,2);
verifyError(t,@()colormeasure.chart.catalogClassification('PR',duplicate),'Chart:ContextCatalog');
end

function testNativeContextWithoutSettingsInventsNoAcquisitionControl(t)
facts=struct('catalogIdentity',struct('model','CR250','mode','interactive'), ...
    'configuration',struct('synthetic',true),'settingsCatalog',struct([]));
reading=struct('XYZ',[1 2 3],'isSynthetic',true);
for report={struct(),struct('controls',struct([]))}
    facts.settingsSnapshot=report{1};
    for context={colormeasure.chart.context(facts),colormeasure.chart.context(facts,reading)}
        value=context{1};verifyEqual(t,value.route,'CR');
        verifyEmpty(t,value.requested.exposureMode);
        verifyEqual(t,value.material.exposureMode.certainty,'unknown');
        [eligible,~,kind]=colormeasure.chart.eligibility(value);
        verifyTrue(t,eligible);verifyEqual(t,kind,'naming-only');
    end
end
end

function testRenamesNotesPortsAndRotationAreNotMaterial(t)
facts=directFacts('PR');before=colormeasure.chart.context(facts);
facts.name='Other';facts.notes='New notes';facts.port='/different/locator';facts.rotation=90;
after=colormeasure.chart.context(facts);
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
end

function testPRAveragingCountDoesNotStartPass(t)
facts=directFacts('PR');before=colormeasure.chart.context(facts);
facts.settingsOverrides.cycles=7;after=colormeasure.chart.context(facts);
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
verifyEqual(t,after.counts.cycles.value,7);
end

function testGenuinePRModelChangeRemainsMaterialInSyntheticRecords(t)
first=colormeasure.drivers.pr.DemoInstrument(1,0,'PR-655');
other=colormeasure.drivers.pr.DemoInstrument(1,0,'PR-670');
t.addTeardown(@()delete([first other]));
facts=directFacts('PR');facts.catalogIdentity.mode='interactive';
reading=first.measure();reading.instrumentSettings=struct('after',first.readSettings());
before=colormeasure.chart.context(facts,reading);
reading=other.measure();reading.instrumentSettings=struct('after',other.readSettings());
after=colormeasure.chart.context(facts,reading);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'model','spectralGrid'});
verifyEqual(t,after.material.model.value,'PR-670');
verifyEqual(t,after.material.provenance.value,'simulated');
end

function testPRExposureAndExpertShutterChangePass(t)
facts=directFacts('PR');before=colormeasure.chart.context(facts);
facts.settingsOverrides.exposureMilliseconds=30;
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts));
verifyTrue(t,any(strcmp({difference.key},'exposureMilliseconds')));
facts=directFacts('PR');facts.settingsOverrides.shutterMode='closeAfter';
before=colormeasure.chart.context(facts);facts.settingsOverrides.shutterMode='alwaysOpen';
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts));
verifyEqual(t,{difference.key},{'shutterMode'});
end

function testPRNativeObserverAndReportUnitsAreProvenance(t)
facts=directFacts('PR');facts.settingsOverrides=struct('instrumentObserver',2,'photometricUnits','metric');
before=colormeasure.chart.context(facts);
facts.settingsOverrides=struct('instrumentObserver',10,'photometricUnits','english');
after=colormeasure.chart.context(facts);
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
verifyEqual(t,after.provenance.instrumentObserver.value,10);
end

function testCRAutomaticExposureAndRangeValuesDoNotStartPass(t)
facts=directFacts('CR');report=colormeasure.drivers.cr.demoSettingsReport('CR-100');
facts.settingsCatalog=report.controls;facts.settingsSnapshot=report;
reading=crReading(report,10,0);before=colormeasure.chart.context(facts,reading);
reading=crReading(report,100,3);after=colormeasure.chart.context(facts,reading);
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
verifyEqual(t,after.accepted.exposureMs,100);
verifyEqual(t,after.material.exposureMs.value,'automatic');
verifyEqual(t,after.material.range.value,'automatic');
end

function testCRFixedPolicyAndExposureMultiplierAreMaterial(t)
facts=directFacts('CR');report=colormeasure.drivers.cr.demoSettingsReport('CR-100');
facts.settingsCatalog=report.controls;facts.settingsSnapshot=report;
before=colormeasure.chart.context(facts);
facts.settingsOverrides=struct('exposureMode',1,'exposureMs',40,'rangeMode',1,'range',3);
after=colormeasure.chart.context(facts);
difference=colormeasure.chart.contextDifference(before,after);
verifyTrue(t,all(ismember({'exposureMode','exposureMs','rangeMode','range'},{difference.key})));
facts=directFacts('CR');facts.settingsSnapshot=report;facts.settingsCatalog=report.controls;
before=colormeasure.chart.context(facts);facts.settingsOverrides.exposureMultiplier=3;
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts));
verifyEqual(t,{difference.key},{'exposureMultiplier'});
end

function testCSKnownPhysicalAngleChangeAndLossHoldResult(t)
facts=directFacts('CS2000');report=csReport();facts.settingsSnapshot=report;
reading=csReading(report,1);before=colormeasure.chart.context(facts,reading);
reading=csReading(report,.2);after=colormeasure.chart.context(facts,reading);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'measurementAngleDegrees'});
reading.instrumentMetadata.conditions=rmfield(reading.instrumentMetadata.conditions,'measurementAngleDegrees');
reading.instrumentSettings.after.values.measurementAngleDegrees=NaN;
after=colormeasure.chart.context(facts,reading);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.kind},{'lost'});
end

function testCSAutomaticIntegrationVariesWithinPolicy(t)
facts=directFacts('CS2000');report=csReport();report.values.speedMode=0;
facts.settingsSnapshot=report;facts.settingsOverrides.speedMode=0;
reading=csReading(report,1);reading.instrumentMetadata.conditions.speedMode=0;
reading.instrumentMetadata.conditions.integrationTime=.1;
before=colormeasure.chart.context(facts,reading);
reading.instrumentMetadata.conditions.integrationTime=.9;
after=colormeasure.chart.context(facts,reading);
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
end

function testUnknownFactsStayUnknownWithoutRepeatedDecision(t)
facts=directFacts('PR');before=colormeasure.chart.context(facts);
verifyEqual(t,before.material.serial.certainty,'unknown');
verifyEmpty(t,colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts)));
verifyEqual(t,before.material.apertureId.certainty,'unknown');
end

function testNativeUnknownScaleIsUnavailableWithoutRewritingIdentity(t)
for route={'PR','CR','CS2000'}
    facts=directFacts(route{1});
    for scale={'unknown',' UNSPECIFIED ',"not reported","UNKNOWN"}
        reading=struct('XYZ',[1 2 3],'xyzScale',scale{1}, ...
            'instrumentMetadata',struct('identity',struct('serialNumber','unknown')));
        accepted=colormeasure.chart.context(facts,reading);
        verifyEqual(t,accepted.material.xyzScale.certainty,'unknown');
        verifyEmpty(t,accepted.material.xyzScale.value);
        verifyEqual(t,accepted.material.serial.value,'unknown');
        verifyEqual(t,accepted.material.serial.certainty,'readback');
    end
    reading.xyzScale='relative; white Y=100';
    accepted=colormeasure.chart.context(facts,reading);
    verifyEqual(t,accepted.material.xyzScale.value,reading.xyzScale);
    verifyEqual(t,accepted.material.xyzScale.certainty,'readback');
end
end

function testNewlyKnownFactsEnrichButKnownSerialLossDoesNot(t)
facts=directFacts('CS2000');before=colormeasure.chart.context(facts);
report=csReport();reading=csReading(report,1);
after=colormeasure.chart.context(facts,reading);
% Acquisition defaults and quantities agree; newly observed serial/angle do
% not discard the first result just because no prior readback was available.
verifyEmpty(t,colormeasure.chart.contextDifference(before,after));
reading.instrumentMetadata.identity.serialNumber='';reading.instrumentSettings.after.identity.serialNumber='';
lost=colormeasure.chart.context(facts,reading);
difference=colormeasure.chart.contextDifference(after,lost);
verifyTrue(t,any(strcmp({difference.key},'serial')));
end

function testDirectUnreportedGridIsNotInferred(t)
for route={'PR','CR','CS2000'}
    facts=directFacts(route{1});
    reading=struct('XYZ',[1 2 3], ...
        'instrumentMetadata',struct('identity',struct('serialNumber','unknown')));
    original=reading;accepted=colormeasure.chart.context(facts,reading);
    verifyFalse(t,isfield(accepted.material,'xyzIlluminant'));
    verifyFalse(t,isfield(accepted,'frozenOptions'));
    verifyEqual(t,accepted.material.spectralGrid.certainty,'unknown');
    verifyEmpty(t,accepted.material.spectralGrid.value);
    verifyFalse(t,ismember('spectralGrid',accepted.requiredMaterial));
    verifyEqual(t,accepted.material.serial.value,'unknown');
    verifyEqual(t,accepted.material.serial.certainty,'readback');verifyEqual(t,reading,original);
end
end

function testDirectSpectralGridChangesDoNotPoolChartCoverage(t)
facts=directFacts('CS2000');reading=csReading(csReport(),1);reading.lambda=[400 500 600];
original=reading;before=colormeasure.chart.context(facts,reading);
verifyEqual(t,before.material.spectralGrid.value,[400;500;600]);
verifyEqual(t,before.material.spectralGrid.certainty,'readback');verifyEqual(t,reading,original);
reading.lambda=[400;500;600];
verifyEmpty(t,colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts,reading)));
reading.lambda=[400;501;600];
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts,reading));
verifyEqual(t,{difference.key},{'spectralGrid'});verifyEqual(t,{difference.kind},{'changed'});
verifyEqual(t,{difference.message},{'Spectral wavelength grid (nm): changed.'});
reading.lambda=[];
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts,reading));
verifyEqual(t,{difference.key},{'spectralGrid'});verifyEqual(t,{difference.kind},{'lost'});
verifyEqual(t,{difference.message},{'Spectral wavelength grid (nm): lost.'});
reading=rmfield(reading,'lambda');
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts,reading));
verifyEqual(t,{difference.key},{'spectralGrid'});verifyEqual(t,{difference.kind},{'lost'});
end

function testDirectEstablishedGridConstrainsContinuation(t)
facts=directFacts('CS2000');reading=csReading(csReport(),1);
reading.lambda=[400 500 600];
before=colormeasure.chart.context(facts,reading);
verifyTrue(t,all(ismember({'spectralGrid'},before.requiredMaterial)));
verifyEmpty(t,colormeasure.chart.contextDifference(colormeasure.chart.context(facts),before));
facts.latestReading=reading;intended=colormeasure.chart.context(facts);
verifyEqual(t,intended.phase,'intended');
verifyEmpty(t,colormeasure.chart.contextDifference(before,intended));
reading.lambda=reading.lambda';same=colormeasure.chart.context(facts,reading);
decision=colormeasure.chart.continuity(before,same);
verifyFalse(t,any(ismember({decision.differences.key},{'spectralGrid'})));
verifyFalse(t,any(contains(decision.unknowns,{'spectralGrid'})));
for key={'spectralGrid'}
    changed=reading;
    changed.lambda=[400;501;600];
    decision=colormeasure.chart.continuity(before,colormeasure.chart.context(facts,changed));
    verifyFalse(t,decision.continueEligible);verifyEqual(t,{decision.differences.key},key);
    missing=reading;
    missing.lambda=[];
    decision=colormeasure.chart.continuity(before,colormeasure.chart.context(facts,missing));
    verifyFalse(t,decision.continueEligible);
    verifyTrue(t,any(strcmp(decision.unknowns,[key{1} ': not established.'])));
    verifyFalse(t,any(strcmp({decision.declarableFacts.key},key{1})));
end
end

function testDirectSavedContextRetainsOriginalReadingAndGridEquality(t)
facts=directFacts('CS2000');reading=csReading(csReport(),1);
reading.lambda=[400 500 600];original=reading;
accepted=colormeasure.chart.context(facts,reading);
restored=jsondecode(jsonencode(accepted));
verifyEqual(t,restored.material.spectralGrid.value,[400;500;600]);
verifyEmpty(t,colormeasure.chart.contextDifference(accepted,restored));
colormeasure.chart.validateAcceptedContext(facts,reading,restored,restored);
path=[tempname '.mat'];t.addTeardown(@()delete(path));save(path,'reading','accepted');
saved=load(path);verifyEqual(t,saved.reading,original);verifyEqual(t,saved.accepted,accepted);
verifyEmpty(t,colormeasure.chart.contextDifference(restored,saved.accepted));
for key={'spectralGrid'}
    fabricated=restored;
    fabricated.material.spectralGrid.value=[400;501;600];
    verifyError(t,@()colormeasure.chart.validateAcceptedContext(facts,reading,fabricated,fabricated), ...
        'Measurement:ChartReference');
end
for key={'serial','observer','xyzUnits','spectralGrid'}
    assertNotEqual(t,restored.material.(key{1}).certainty,'unknown');
    erased=struct('value',[],'certainty','unknown','source','removed');
    fabricated=restored;fabricated.material.(key{1})=erased;
    verifyError(t,@()colormeasure.chart.validateAcceptedContext(facts,reading,fabricated,restored), ...
        'Measurement:ChartReference',key{1});
    weakened=restored;weakened.material.(key{1})=erased;
    verifyError(t,@()colormeasure.chart.validateAcceptedContext(facts,reading,restored,weakened), ...
        'Measurement:ChartReference',key{1});
end
unreported=reading;
unreported.instrumentMetadata.identity.serialNumber='';
unreported.instrumentSettings.after.identity.serialNumber='';
unreported=rmfield(unreported,{'observerId','xyzUnits','lambda'});
raw=unreported;unknownAccepted=colormeasure.chart.context(facts,unreported);
verifyEmpty(t,colormeasure.chart.contextDifference(unknownAccepted,restored));
verifyWarningFree(t,@()colormeasure.chart.validateAcceptedContext(facts,unreported,unknownAccepted,restored));
verifyEqual(t,unreported,raw);
verifyEqual(t,reading,original);
end

function testIntentUsesLastReadingWithoutInventingAReadbackLoss(t)
facts=directFacts('CS2000');report=csReport();reading=csReading(report,1);
before=colormeasure.chart.context(facts,reading);
facts.latestReading=reading;facts.settingsOverrides.userCalibrationChannel=1;
after=colormeasure.chart.context(facts);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'userCalibrationChannel'});
verifyEqual(t,after.phase,'intended');
end

function testFreshSettingsReadbackWinsOverPreviousCapture(t)
facts=directFacts('CS2000');report=csReport();reading=csReading(report,1);
before=colormeasure.chart.context(facts,reading);
facts.latestReading=reading;report.values.measurementAngleDegrees=.2;facts.settingsSnapshot=report;
after=colormeasure.chart.context(facts);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'measurementAngleDegrees'});
verifyEqual(t,after.material.measurementAngleDegrees.value,.2);
end

function testAnExplicitPreviouslyUnknownPolicyRequiresNewPass(t)
facts=directFacts('PR');before=colormeasure.chart.context(facts);
facts.settingsOverrides.shutterMode='alwaysOpen';after=colormeasure.chart.context(facts);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'shutterMode'});verifyEqual(t,{difference.kind},{'specified'});
end

function testProvenanceAndIdentityAreMaterialButPortIsNot(t)
facts=directFacts('CS2000');report=csReport();reading=csReading(report,1);
before=colormeasure.chart.context(facts,reading);
reading.instrumentMetadata.identity.serialNumber='OTHER';
after=colormeasure.chart.context(facts,reading);
difference=colormeasure.chart.contextDifference(before,after);
verifyEqual(t,{difference.key},{'serial'});
reading.isSynthetic=true;
difference=colormeasure.chart.contextDifference(before,colormeasure.chart.context(facts,reading));
verifyTrue(t,any(strcmp({difference.key},'provenance')));
end

function testActualQuantityRefusesIrradianceWithoutADeviceWhitelist(t)
facts=directFacts('PR');reading=struct('XYZ',[1 2 3],'unitsCode',12, ...
    'deviceType','PR-655','instrumentSettings',struct([]),'isSynthetic',false);
context=colormeasure.chart.context(facts,reading);
[eligible,reason]=colormeasure.chart.eligibility(context);
verifyFalse(t,eligible);verifySubstring(t,reason,'physical reflective chart');
reading.unitsCode=11;[eligible,~]=colormeasure.chart.eligibility(colormeasure.chart.context(facts,reading));
verifyTrue(t,eligible);
end

function facts=directFacts(route)
model=route;
switch route
    case 'PR',model='PR655';controls=colormeasure.drivers.pr.settingsCatalog('PR-670',struct(),true);
    case 'CR',model='CR100';controls=colormeasure.drivers.cr.settingsControls('CR-100');
    case 'CS2000',controls=colormeasure.drivers.cs2000.settingsCatalog();
end
facts=struct('adapterKey',model,'catalogIdentity',struct('model',model,'mode','measure'), ...
    'configuration',struct(),'settingsCatalog',controls,'settingsOverrides',struct(), ...
    'settingsSnapshot',struct(),'lastSettingsReceipt',struct());
end

function reading=crReading(report,exposure,range)
capture=struct('exposureMode','Auto','exposureMs',exposure,'rangeMode','Auto','range',range);
reading=struct('XYZ',[1 2 3],'deviceType','CR-100','spectralQuantity','', ...
    'xyzUnits','instrument scale','observerId','CIE1931_2deg','isSynthetic',false, ...
    'instrumentMetadata',struct('captureSettings',capture,'identity',report.identity), ...
    'instrumentSettings',struct('status','applied','after',report));
end

function report=csReport()
values=struct('speedMode',2,'integrationTimeSeconds',1,'internalNDMode',2,'syncMode',0, ...
    'frequencyHz',NaN,'measurementAngleDegrees',1,'closeupLens',0,'externalNDFilter',0,'userCalibrationChannel',0);
report=struct('values',values,'controls',colormeasure.drivers.cs2000.settingsCatalog(), ...
    'identity',struct('model','CS-2000','serialNumber','123'));
end

function reading=csReading(report,angle)
conditions=struct('speedMode',report.values.speedMode,'syncMode',0,'measurementAngleDegrees',angle, ...
    'integrationTime',.1,'closeupLens',0,'externalNDFilter',0,'userCalibrationChannel',0);
reading=struct('XYZ',[1 2 3],'deviceType','CS-2000','spectralQuantity','radiance', ...
    'xyzUnits','instrument scale','observerId','CIE1931_2deg','spectralUnits','W/(m^2 sr nm)', ...
    'instrumentMetadata',struct('conditions',conditions,'identity',report.identity), ...
    'instrumentSettings',struct('status','applied','after',report),'isSynthetic',false);
end

function [first,equivalent,changed]=correctionFixtureTexts()
first=sprintf('CCMX\nDESCRIPTOR "First"\nBEGIN_DATA\n1 0 0\n0 1 0\n0 0 1\nEND_DATA\n');
equivalent=sprintf('CCMX\n# Same matrix, different annotation\nDESCRIPTOR "Another label"\nBEGIN_DATA\n1  0 0\n0 1  0\n0 0 1\nEND_DATA\n');
changed=sprintf('CCMX\nDESCRIPTOR "First"\nBEGIN_DATA\n2 0 0\n0 1 0\n0 0 1\nEND_DATA\n');
end

function [first,equivalent]=spectralCorrectionFixtureTexts()
first=sprintf('CCSS\nDESCRIPTOR "First"\nBEGIN_DATA\n.1 .5 .2\nEND_DATA\n');
equivalent=sprintf('CCSS\n# Same sample data\nDESCRIPTOR "Another label"\nBEGIN_DATA\n.1  .5 .2\nEND_DATA\n');
end

function material=correctionFixtureMaterial(text)
% Inert owner stand-in: exact fixture texts map to declared effective facts.
% This is not a MATLAB parser and does not validate a correction file format.
[first,equivalent,changed]=correctionFixtureTexts();
[spectralFirst,spectralEquivalent]=spectralCorrectionFixtureTexts();
if any(strcmp(text,{spectralFirst,spectralEquivalent}))
    material=struct('kind','spectral','bands',3,'start_nm',400,'end_nm',405, ...
        'norm',1,'samples',[.1 .5 .2],'display_technology',0);return
end
if any(strcmp(text,{first,equivalent}))
    matrix=eye(3);
elseif strcmp(text,changed)
    matrix=diag([2 1 1]);
else
    error('ChartTest:CorrectionFixture','Unknown correction fixture text.');
end
material=struct('kind','matrix','matrix',matrix,'display_technology',0,'calibration_base_id',1);
end

function material=emptyCorrectionMaterial(~)
material=struct();
end

function write(path,text)
file=fopen(path,'wb');assert(file>=0);close=onCleanup(@()fclose(file));
fwrite(file,text,'char');
end

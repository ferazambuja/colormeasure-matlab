function tests = testCS2000Presentation
% Read-only view/export data and synthetic headless workflows; no UI windows.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testLiveValuesHaveSeparateComparisonCapabilities(t)
reading = liveReading(t);
reading.XYZ = [-1 0 2]; % Signed values remain data; view math owns validity.
reading.spectralData(1) = -0.2;
data = colormeasure.drivers.cs2000.viewData(reading);
verifyEqual(t,data.XYZ,reading.XYZ);
verifyEqual(t,data.spectra{1}.y,reading.spectralData);
verifyEqual(t,data.observerId,'CIE1931_2deg');
verifyEqual(t,data.xyzUnitsByReading{1},'instrument scale (absolute unit not established)');
verifyEmpty(t,data.xyzComparisonKeys{1});
verifyNotEmpty(t,data.xyzScaleDeclarationKeys{1});
verifyNotEmpty(t,data.chromaticityComparisonKeys{1});
verifyNotEmpty(t,data.spectralComparisonKeys{1});
verifyTrue(t,data.reflectanceRatioEligible);
verifyEqual(t,data.spectralQuantities,{'radiance'});
verifyEmpty(t,data.reflectanceRatioReasons{1});
end

function testRatioUsesSpectralProvenanceWithoutAbsoluteXYZGate(t)
reading=liveReading(t);
reading.xyzUnits='Absolute XYZ unit not specified';
reading.xyzUnitsConfirmed=false;
data=colormeasure.drivers.cs2000.viewData([reading reading]);
verifyEqual(t,data.reflectanceRatioEligible,true(2,1));
verifyEqual(t,data.spectralQuantities,{'radiance';'radiance'});
result=colormeasure.analysis.compareReadings(data,1,2,0);
verifyEqual(t,result.spectralRMS,0); verifyEmpty(t,result.spectralReason);
config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
derived=colormeasure.analysis.deriveIllumination(data,2,config);
verifyTrue(t,derived.available,derived.reason);
verifyEqual(t,derived.spectrum.y,ones(size(reading.spectralData)));
variants=repmat({reading},1,5);
variants{1}.spectralQuantity='reflectance';
variants{2}.spectralUnits='Unverified units';
variants{3}.spectralUnitsConfirmed=false;
variants{4}.observerId='Unverified observer';
variants{5}=rmfield(reading,'spectralQuantity');
for index=1:numel(variants)
    original=variants{index};
    data=colormeasure.drivers.cs2000.viewData(original);
    verifyFalse(t,data.reflectanceRatioEligible);
    verifyNotEmpty(t,data.reflectanceRatioReasons{1});
    verifyEqual(t,data.spectra{1}.y,original.spectralData);
end
end

function testCurrentSyntheticMethodSurvivesMatRoundTrip(t)
current=colormeasure.drivers.cs2000.syntheticReading(1);
% Pins the stored xyzMethod literal that viewData compares; changing it is a deliberate data change.
pinned=current; pinned.xyzMethod='synthetic colormeasure.colorimetry.spectra2XYZ; CIE 1931 2 degree; MCSL-compatible v1';
verifyEqual(t,current.xyzMethod,pinned.xyzMethod);
before=[pinned current];
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
save(fullfile(f.Folder,'current-method.mat'),'before');saved=load(fullfile(f.Folder,'current-method.mat'));
data=colormeasure.drivers.cs2000.viewData(saved.before);
verifyEqual(t,saved.before,before);verifyEqual(t,data.xyzSources{1},pinned.xyzMethod);
verifyEqual(t,data.observerIds,{'CIE1931_2deg';'CIE1931_2deg'});
verifyNotEmpty(t,data.xyzComparisonKeys{1});
verifyEqual(t,data.xyzComparisonKeys{1},data.xyzComparisonKeys{2});
verifyEqual(t,data.spectralComparisonKeys{1},data.spectralComparisonKeys{2});
pinned.xyzMethod=[pinned.xyzMethod ' unverified'];unknown=colormeasure.drivers.cs2000.viewData(pinned);
verifyEmpty(t,unknown.observerIds{1});verifyEmpty(t,unknown.xyzComparisonKeys{1});
verifyFalse(t,unknown.reflectanceRatioEligible);
end

function testUnknownSourcesCannotDeclareComparability(t)
reading = liveReading(t);
reading.xyzMethod = 'Unverified alternative';
data = colormeasure.drivers.cs2000.viewData(reading);
verifyEmpty(t,data.xyzComparisonKeys{1});
verifyEmpty(t,data.xyzScaleDeclarationKeys{1});
verifyEmpty(t,data.chromaticityComparisonKeys{1});
verifyEmpty(t,data.spectralComparisonKeys{1});
verifyEmpty(t,data.observerIds{1});
verifyEqual(t,data.XYZ,reading.XYZ);
verifyFalse(t,data.reflectanceRatioEligible); verifyNotEmpty(t,data.reflectanceRatioReasons{1});
end

function testScaleDeclarationIgnoresExposureButRejectsKnownGeometryDifferences(t)
first = liveReading(t); second = first;
second.instrumentMetadata.conditions.integrationTime = 100;
second.instrumentMetadata.conditions.internalNDFilter = 1;
second.instrumentMetadata.conditions.speedMode = 3;
second.instrumentMetadata.acquisition.configurationBefore.observerMetadata.value = 1;
data = colormeasure.drivers.cs2000.viewData([first second]);
verifyEqual(t,data.xyzScaleDeclarationKeys{1},data.xyzScaleDeclarationKeys{2});
verifyNotEmpty(t,data.xyzScaleDeclarationKeys{1});
for field = {'closeupLens','externalNDFilter','userCalibrationChannel'}
    changed = second;
    changed.instrumentMetadata.conditions.(field{1}) = 1;
    if strcmp(field{1},'userCalibrationChannel')
        changed.instrumentMetadata.acquisition.userCalibration.channel = 1;
        changed.instrumentMetadata.acquisition.userCalibration.status = 'available';
        changed.instrumentMetadata.acquisition.userCalibration.name = 'Custom';
    end
    data = colormeasure.drivers.cs2000.viewData([first changed]);
    verifyNotEqual(t,data.xyzScaleDeclarationKeys{1},data.xyzScaleDeclarationKeys{2});
end
changed = second;
changed.instrumentMetadata.conditions.measurementAngle = 1;
changed.instrumentMetadata.conditions.measurementAngleDegrees = 0.2;
data = colormeasure.drivers.cs2000.viewData([first changed]);
verifyNotEqual(t,data.xyzScaleDeclarationKeys{1},data.xyzScaleDeclarationKeys{2});
verifyEqual(t,data.chromaticityComparisonKeys{1},data.chromaticityComparisonKeys{2});
verifyEqual(t,data.spectralComparisonKeys{1},data.spectralComparisonKeys{2});
end

function testScaleDeclarationRequiresConsistentIdentityAndCalibrationMetadata(t)
reading = liveReading(t);
variants = repmat({reading},1,10);
variants{1}.instrumentMetadata = rmfield(reading.instrumentMetadata,'conditions');
variants{2}.instrumentMetadata.identity = rmfield(reading.instrumentMetadata.identity,'serialNumber');
variants{3}.instrumentMetadata.identity.variation = 2; % Contradicts CS-2000 model.
variants{4}.instrumentMetadata.conditions.measurementAngleDegrees = 0.2; % Code still 0.
variants{5}.instrumentMetadata.acquisition.userCalibration.status = 'unavailable';
variants{6}.instrumentMetadata.acquisition.observer = 1;
variants{7}.xyzUnits = 'cd/m2';
variants{8}.xyzUnitsConfirmed = true;
variants{9}.instrumentMetadata.acquisition.userCalibration = ...
    rmfield(reading.instrumentMetadata.acquisition.userCalibration,'name');
variants{10}.instrumentMetadata.acquisition.userCalibration.name = [];
for index = 1:numel(variants)
    data = colormeasure.drivers.cs2000.viewData(variants{index});
    verifyEmpty(t,data.xyzScaleDeclarationKeys{1});
end
other = reading;
other.instrumentMetadata.identity.serialNumber = '7654321';
data = colormeasure.drivers.cs2000.viewData([reading other]);
verifyNotEqual(t,data.xyzScaleDeclarationKeys{1},data.xyzScaleDeclarationKeys{2});
custom = reading;
custom.instrumentMetadata.conditions.userCalibrationChannel = 1;
custom.instrumentMetadata.acquisition.userCalibration = struct('channel',1,'status','available','name','A');
other = custom; other.instrumentMetadata.acquisition.userCalibration.name = 'B';
data = colormeasure.drivers.cs2000.viewData([custom other]);
verifyNotEqual(t,data.xyzScaleDeclarationKeys{1},data.xyzScaleDeclarationKeys{2});
end

function testSyntheticUnitsAreLabelledButNotConfirmed(t)
% Synthetic unit labels do not establish physical instrument units.
reading=colormeasure.drivers.cs2000.syntheticReading(1);
verifyFalse(t,reading.xyzUnitsConfirmed); verifyFalse(t,reading.spectralUnitsConfirmed);
data=colormeasure.drivers.cs2000.viewData(reading);
verifyNotEmpty(t,data.xyzComparisonKeys{1}); verifyNotEmpty(t,data.spectralComparisonKeys{1});
claims=repmat({reading},1,2);
claims{1}.xyzUnitsConfirmed=true; claims{2}.spectralUnitsConfirmed=true;
data=colormeasure.drivers.cs2000.viewData(claims{1});
verifyEmpty(t,data.xyzComparisonKeys{1}); verifyNotEmpty(t,data.spectralComparisonKeys{1});
data=colormeasure.drivers.cs2000.viewData(claims{2});
verifyNotEmpty(t,data.xyzComparisonKeys{1}); verifyEmpty(t,data.spectralComparisonKeys{1});
verifyFalse(t,data.reflectanceRatioEligible);
end

function testSyntheticProfilesHaveKnownScaleWithoutFabricatedInstrumentMetadata(t)
xyz = zeros(12,3);
for index = 1:12
    reading = colormeasure.drivers.cs2000.syntheticReading(index);
    verifyTrue(t,reading.isSynthetic);
    verifyEqual(t,reading.deviceType,'CS-2000');
    verifyEqual(t,reading.syntheticProfileIndex,index);
    verifyEmpty(t,reading.syntheticAssociation);
    verifyEqual(t,reading.syntheticSeed,index);
    verifyGreaterThanOrEqual(t,reading.syntheticGain,.995);
    verifyLessThanOrEqual(t,reading.syntheticGain,1.005);
    verifySize(t,reading.lambda,[401 1]);
    verifySize(t,reading.spectralData,[401 1]);
    verifyEmpty(t,fieldnames(reading.instrumentMetadata));
    verifyEmpty(t,fieldnames(reading.driverSnapshot));
    verifyTrue(t,startsWith(reading.xyzMethod,'synthetic '));
    verifyEqual(t,reading.XYZ,reshape(colormeasure.colorimetry.spectra2XYZ( ...
        reading.spectralData,reading.lambda),1,3));
    data = colormeasure.drivers.cs2000.viewData(reading);
    verifyNotEmpty(t,data.xyzComparisonKeys{1});
    verifyEmpty(t,data.xyzScaleDeclarationKeys{1});
    verifyEqual(t,data.spectralUnitsByReading{1},'synthetic spectral units');
    verifyTrue(t,data.reflectanceRatioEligible);
    verifyEqual(t,data.spectralQuantities,{'synthetic radiance'});
    verifyEmpty(t,data.reflectanceRatioReasons{1});
    if index==10 % Broadband synthetic reference stays above the ratio floor.
        pair=colormeasure.drivers.cs2000.viewData([reading reading]);
        config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
            'assumePerfectReference',true,'targetIlluminant','D65');
        derived=colormeasure.analysis.deriveIllumination(pair,2,config);
        verifyTrue(t,derived.available,derived.reason);
        verifyEqual(t,derived.spectrum.y,ones(size(reading.spectralData)));
    end
    xyz(index,:) = reading.XYZ;
end
verifyEqual(t,size(unique(round(xyz,9),'rows'),1),12);
first = colormeasure.drivers.cs2000.syntheticReading(1); cycled = colormeasure.drivers.cs2000.syntheticReading(13);
% Each cycle keeps its shape and instrument/science metadata. The saved
% seed and bounded gain describe the independent variation of each reading.
varyingFields={'XYZ','spectralData','syntheticSeed','syntheticGain'};
verifyEqual(t,rmfield(cycled,varyingFields),rmfield(first,varyingFields));
verifyEqual(t,first.syntheticSeed,1); verifyEqual(t,cycled.syntheticSeed,13);
verifyEmpty(t,cycled.syntheticAssociation);
verifyEmpty(t,fieldnames(cycled.instrumentMetadata));
verifyEmpty(t,fieldnames(cycled.driverSnapshot));
verifyGreaterThanOrEqual(t,cycled.syntheticGain,.995);
verifyLessThanOrEqual(t,cycled.syntheticGain,1.005);
verifyEqual(t,cycled,colormeasure.drivers.cs2000.syntheticReading(13));
verifyNotEqual(t,cycled.spectralData,first.spectralData);
ratio=max(cycled.spectralData)/max(first.spectralData);
verifyEqual(t,ratio,cycled.syntheticGain/first.syntheticGain,'RelTol',1e-12);
verifyGreaterThanOrEqual(t,ratio,.995/1.005);
verifyLessThanOrEqual(t,ratio,1.005/.995);
verifyEqual(t,cycled.spectralData,first.spectralData*ratio,'AbsTol',1e-18);
verifyEqual(t,cycled.XYZ,first.XYZ*ratio,'RelTol',1e-12);
neutral = colormeasure.drivers.cs2000.syntheticReading(3); low = colormeasure.drivers.cs2000.syntheticReading(12);
% Low signal starts at 1/100 amplitude before each reading's +/-0.5% gain.
ratio=max(low.spectralData)/max(neutral.spectralData);
verifyGreaterThanOrEqual(t,ratio,.01*.995/1.005);
verifyLessThanOrEqual(t,ratio,.01*1.005/.995);
verifyEqual(t,low.spectralData,neutral.spectralData*ratio,'AbsTol',1e-18);
verifyEqual(t,low.XYZ,neutral.XYZ*ratio,'RelTol',1e-12);
end

function testGuidedDemoKeepsCanonicalModelAcrossAcceptedReadings(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
adapter=colormeasure.drivers.cs2000.demoAdapter('interactive');
session=colormeasure.session.Session(adapter,folder);
t.addTeardown(@()colormeasuretest.disposeSession(session));
session.startChart(colormeasure.chart.definition('custom','CS demo identity',1,2));
verifyTrue(t,session.measure());verifyEmpty(t,session.chart.pendingContext);
verifyTrue(t,session.measure());verifyEmpty(t,session.chart.pendingContext);
verifyEqual(t,session.chart.coverage,2);verifyEqual(t,session.chart.activePass,1);
verifyEqual(t,session.chart.passes.context.material.model.value,'CS-2000');
verifyEqual(t,session.chart.passes.context.material.provenance.value,'simulated');
verifyTrue(t,all([session.measurements.isSynthetic]));
verifyTrue(t,all(cellfun(@(value)isempty(fieldnames(value)),{session.measurements.instrumentMetadata})));
saved=load(session.files.mat);verifyEqual(t,saved.measurements,session.measurements);
end

function testDemoAdaptersHaveSeparateKeysAndNeverConstructDriver(t)
live = colormeasure.drivers.cs2000.uiAdapter('PortList',@colormeasuretest.forbidPorts);
keys = {live.key}; workspaces = {live.workspaceName};
for mode = {'interactive','batch','gallery'}
    adapter = colormeasure.drivers.cs2000.demoAdapter(mode{1});
    keys{end+1} = adapter.key; %#ok<AGROW>
    workspaces{end+1} = adapter.workspaceName; %#ok<AGROW>
    verifyEqual(t,adapter.listPorts('all'),"CS2000_SYNTHETIC_ONLY");
    value = adapter.connect('CS2000_SYNTHETIC_ONLY');
    reading = adapter.read(value); adapter.release(value);
    verifyTrue(t,reading.isSynthetic);
    verifyEqual(t,reading.syntheticProfileIndex,1);
    value = adapter.connect('CS2000_SYNTHETIC_ONLY');
    reading = adapter.read(value); adapter.release(value);
    verifyEqual(t,reading.syntheticProfileIndex,2);
end
verifyEqual(t,numel(unique(keys)),4);
verifyEqual(t,numel(unique(workspaces)),4);
end

function testHeadlessBatchSavesTwoReadingsAndNoFigures(t)
before = findall(groot,'Type','figure');
session = colormeasure.drivers.cs2000.demoCS2000('batch');
t.addTeardown(@()colormeasuretest.disposeBatch(session));
verifyTrue(t,session.finished);
verifyEmpty(t,session.window);
verifyNumElements(t,session.measurements,2);
verifyEqual(t,session.savedCount,2);
verifyTrue(t,all([session.measurements.isSynthetic]));
saved = load(session.files.mat);
verifyEqual(t,saved.measurements,session.measurements);
data = readtable(session.files.csv,'VariableNamingRule','preserve');
verifyEqual(t,height(data),802);
verifyEqual(t,findall(groot,'Type','figure'),before);
end

function testEmptyViewAndCsvHaveUsableSchemas(t)
data = colormeasure.drivers.cs2000.viewData(struct([]));
verifySize(t,data.XYZ,[0 3]);
verifyEmpty(t,data.spectra);
verifyEmpty(t,data.xyzScaleDeclarationKeys);
verifyEqual(t,data.observerId,'CIE1931_2deg');
verifyTrue(t,istable(colormeasure.drivers.cs2000.batchTable(struct([]),struct())));
end

function testHeadlessDemoCannotReportSuccessAfterCsvFailure(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
name = 'colorMeasureCS2000DemoBatch';
colormeasuretest.preserveWorkspace(t,name);

io = colormeasure.session.services(); io.exportCsv = @failCsv;
verifyWarning(t,@()verifyError(t,@()colormeasure.drivers.cs2000.demoSession('batch',io,folder.Folder), ...
    'CS2000:DemoFinish'),'CS2000:DemoBatchRetained');
session = evalin('base',name);
t.addTeardown(@()colormeasuretest.disposeBatch(session));
verifyFalse(t,session.finished);
verifyTrue(t,session.needsRecovery);
verifyNumElements(t,session.measurements,2);
verifyEqual(t,session.savedCount,2);
verifyTrue(t,isfile(session.files.mat));
verifyNotEmpty(t,session.exportError);
end

function testHeadlessDemoRetainsFirstRowWhenNextAttemptFails(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
name = 'colorMeasureCS2000DemoBatch';
colormeasuretest.preserveWorkspace(t,name);
% After the first save, permit its final log timestamp, then fail the next
% attempt's clock once. No instrument or window is involved in this failure.
afterSaveCalls = NaN;
io = colormeasure.session.services(); io.saveMat = @saveAndArm; io.now = @clock;
verifyWarning(t,@()verifyError(t,@()colormeasure.drivers.cs2000.demoSession('batch',io,folder.Folder), ...
    'CS2000:DemoReading'),'CS2000:DemoBatchRetained');
session = evalin('base',name);
t.addTeardown(@()colormeasuretest.disposeBatch(session));
verifyNumElements(t,session.measurements,1);
verifyEqual(t,session.savedCount,1);
verifyFalse(t,session.finished);
verifyTrue(t,isfile(session.files.mat));
verifyTrue(t,any(contains({session.log.message},'cs2000test:ClockFailure')));
    function saveAndArm(varargin)
        colormeasure.session.saveMat(varargin{:});
        afterSaveCalls = 0;
    end
    function value = clock()
        if ~isnan(afterSaveCalls)
            afterSaveCalls = afterSaveCalls+1;
            if afterSaveCalls == 2
                error('cs2000test:ClockFailure','Simulated failure before the next acquisition.');
            end
        end
        value = datetime('now','TimeZone','UTC');
    end
end

function reading = liveReading(t)
peer = colormeasuretest.cs2000.Port();
adapter = colormeasure.drivers.cs2000.adapter('Transport',peer,'PortList',@(~)"SIM_CS2000");
meter = adapter.connect('SIM_CS2000');
t.addTeardown(@()colormeasuretest.dispose(meter));
reading = adapter.read(meter);
adapter.release(meter);
end

function failCsv(varargin)
error('cs2000test:ExportFailure','Simulated CSV failure.');
end

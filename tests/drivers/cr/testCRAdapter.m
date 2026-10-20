function tests = testCRAdapter
% Real CR drivers with injected peers; shared sessions never open a window.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testModelAndDefaultConstructorContract(t)
for model = {'CR100','CR250','CR300'}
    a = colormeasure.drivers.cr.adapter(model{1},'DriverFactory',@capture,'PortList',@(~) "SIM");
    verifyEqual(t,a.key,model{1});
    request = a.connect('SIM');
    verifyEqual(t,request.model,model{1});
    verifyEqual(t,request.options,{'ResponseTimeout',5,'MeasurementTimeout',120});
end
verifyError(t,@() colormeasure.drivers.cr.adapter('CR250-RH'),'CR:AdapterModel');
end

function testPreparationIsModelSpecificAndAvailableWithoutEnumeration(t)
for model = {'CR100','CR250','CR300'}
    a = colormeasure.drivers.cr.adapter(model{1},'PortList',@preparationMustNotEnumerate);
    guide = a.preparation;
    verifyTrue(t,guide.required);
    verifyEqual(t,guide.title,[strrep(model{1},'CR','CR-') ' preparation']);
    verifyTrue(t,iscellstr(guide.details));
    text = strjoin(guide.details,' ');
    verifyFalse(t,contains(lower(text),{'reviewed','cannot certify'}));
    verifyFalse(t,contains(text,'20 minutes'));
    if strcmp(model{1},'CR100')
        verifyTrue(t,contains(text,'spectral reflectance and relighting are unavailable'));
    else
        verifyTrue(t,contains(text,'fixed aperture'));
        verifyTrue(t,contains(text,'white reference'));
    end
end
verifyError(t,@()colormeasure.drivers.cr.preparation('CR250-RH'),'CR:AdapterModel');
end

function testDemoKeepsPreparationHelpWithoutLiveReminder(t)
for model = {'CR100','CR250','CR300'}
    live = colormeasure.drivers.cr.uiAdapter(model{1}); expected = live.preparation; expected.required = false;
    for mode = {'interactive','batch','gallery'}
        a = colormeasure.drivers.cr.demoAdapter(model{1},mode{1});
        verifyEqual(t,a.preparation,expected);
    end
end
end

function names = preparationMustNotEnumerate(varargin) %#ok<STOUT>
error('Test:UnexpectedEnumeration','Reading preparation help must not enumerate ports.');
end

function testConfigurationNormalizesEquivalentPublicOptions(t)
a=colormeasure.drivers.cr.adapter('CR250','ResponseTimeout',7,'MeasurementTimeout',90);
b=colormeasure.drivers.cr.adapter("CR-250",'ResponseTimeout',uint8(7),'MeasurementTimeout',single(90), ...
    'DriverFactory',@capture,'PortList',@(~) "SIM");
verifyEqual(t,a.configuration,b.configuration);
verifyEqual(t,b.configuration.ResponseTimeout,7);
verifyEqual(t,b.configuration.MeasurementTimeout,90);
request=b.connect('SIM');
verifyEqual(t,request.options,{'ResponseTimeout',7,'MeasurementTimeout',90});
verifyFalse(t,isfield(b.configuration,'DriverFactory'));
verifyFalse(t,isfield(b.configuration,'PortList'));
verifyTrue(t,contains(b.configurationSummary,'measurement command 90 s'));
end

function request = capture(model,port,varargin)
request = struct('model',model,'port',port,'options',{varargin});
end

function testEveryModelRetainsNativeSnapshotAndExactlyOneExposure(t)
for model = {'CR100','CR250','CR300'}
    [a,peer] = adapterFor(model{1}); state=peer.State;
    meter = a.connect('SIM'); cleanup=onCleanup(@() a.release(meter));
    r = a.read(meter); native=meter.snapshot();
    verifyEqual(t,r.driverSnapshot,native);
    verifyEqual(t,r.instrumentMetadata,native.metadata(end));
    verifyEqual(t,r.XYZ,native.XYZ(end,:));
    verifyEqual(t,r.instrumentXYZ,native.instrumentXYZ(end,:));
    verifyEqual(t,r.xyzMethod,native.metadata.xyzSource);
    verifyEqual(t,r.CCT,native.CCT); verifyEqual(t,r.Duv,native.Duv);
    verifyEqual(t,nnz(strcmp(state('commands'),'M')),1);
    verifyFalse(t,native.repeatOnError); verifyFalse(t,native.recoveryStatus.attempted);
    verifyFalse(t,any(startsWith(state('commands'),'SC ')));
    verifyFalse(t,isfield(native,'port'));
    if strcmp(model{1},'CR100')
        verifyEmpty(t,r.lambda); verifyEmpty(t,r.spectralData);
        verifyEqual(t,r.XYZ,r.instrumentXYZ);
        verifyFalse(t,isfield(native,'spectralData'));
    else
        verifyEqual(t,r.lambda,native.wl(end,:).');
        verifyEqual(t,r.spectralData,native.spectralData(end,:).');
        verifyNotEqual(t,r.XYZ,r.instrumentXYZ);
    end
    clear cleanup
    verifyTrue(t,state('deleted')); verifyEqual(t,state('deleteCount'),1);
end
end

function testSnapshotAndSaveKeepNativeValuesAndWarningState(t)
[a,~] = adapterFor('CR250'); meter=a.connect('SIM');
t.addTeardown(@() delete(meter)); meter.Measure();
native=meter.snapshot();
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
before=warning;
meter.Save(fullfile(f.Folder,'native.mat'));
stored=load(fullfile(f.Folder,'native.mat'));
verifyEqual(t,fieldnames(stored),{'measurements'});
verifyEqual(t,stored.measurements,native);
verifyEqual(t,meter.snapshot(),native); verifyEqual(t,warning,before);
expected={'XYZ','CCT','Duv','instrumentXYZ','metadata','identity','segmentId','repeatOnError', ...
    'errorCode','responseTimeout','measurementTimeout','schemaVersion','recoveryStatus', ...
    'spectralData','integratedSpectrum','wl'};
verifyEqual(t,fieldnames(native),expected.');
native.XYZ(1)=0; verifyNotEqual(t,meter.XYZ,native.XYZ);
end

function testIndexedProjectionPreservesEveryNativeQuantityAndSource(t)
[a,peer] = adapterFor('CR250'); meter = a.connect('SIM');
t.addTeardown(@()delete(meter));
for type = 0:3
    peer.queue('RM Radiometric',sprintf('OK:0:RM Radiometric:%d,0.402,1e10\r\n',type));
    meter.Measure();
end
native = meter.snapshot(); commands = peer.State('commands');
for index = 1:4
    r = colormeasure.drivers.cr.reading(native,index);
    verifyEqual(t,r.readingId,native.metadata(index).readingId);
    verifyEqual(t,r.XYZ,native.XYZ(index,:));
    verifyEqual(t,r.instrumentXYZ,native.instrumentXYZ(index,:));
    verifyEqual(t,r.instrumentMetadata,native.metadata(index));
    verifyEqual(t,r.xyzUnits,native.metadata(index).xyzUnit);
    verifyEqual(t,r.spectralUnits,native.metadata(index).spectralDensityUnit);
    verifyEqual(t,r.spectralQuantity,native.metadata(index).radiometricQuantity);
    verifyEqual(t,r.lambda,native.wl(index,:).');
    verifyEqual(t,r.spectralData,native.spectralData(index,:).');
    verifyEqual(t,r.radiometricType,index-1);
    verifyFalse(t,r.spectralUnitsConfirmed);
    verifyEqual(t,r.driverSnapshot,native);
end
verifyEqual(t,colormeasure.drivers.cr.reading(native),colormeasure.drivers.cr.reading(native,4));
verifyEqual(t,peer.State('commands'),commands);
verifyEqual(t,meter.snapshot(),native);
% A top-level destination identity must not replace acquired row provenance.
copy = native; copy.identity.model = 'Other destination';
copiedReading = colormeasure.drivers.cr.reading(copy,1);
verifyEqual(t,copiedReading.deviceType,native.metadata(1).identity.model);
for invalid = {0,5,NaN,Inf,-1,1.5,[1 2],1i,'1'}
    verifyError(t,@()colormeasure.drivers.cr.reading(native,invalid{1}),'CR:AdapterReading');
end
end

function testAllQuantitiesPreserveValuesAndDistinctUnitKeys(t)
keys=cell(4,1);
quantities={'radiance','irradiance','radiant intensity','radiant flux'};
config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
for type=0:3
    [a,peer]=adapterFor('CR250');
    peer.queue('RM Radiometric',sprintf('OK:0:RM Radiometric:%d,0.402,1e10\r\n',type));
    meter=a.connect('SIM'); cleanup=onCleanup(@() delete(meter));
    r=a.read(meter); data=colormeasure.drivers.cr.viewData(r,'CR250');
    verifyEqual(t,data.spectra{1}.y,r.spectralData);
    verifyEqual(t,data.XYZ,r.XYZ);
    verifyTrue(t,contains(data.spectralUnitsByReading{1},'provisional'));
    verifyNotEmpty(t,data.xyzComparisonKeys{1});
    keys{type+1}=data.spectralComparisonKeys{1};
    verifyEqual(t,data.spectralQuantities,quantities(type+1));
    verifyEqual(t,data.reflectanceRatioEligible,type==0);
    pair=colormeasure.drivers.cr.viewData([r r],'CR250');
    result=colormeasure.analysis.compareReadings(pair,1,2,0);
    verifyEqual(t,result.spectralRMS,0); verifyEmpty(t,result.spectralReason);
    derived=colormeasure.analysis.deriveIllumination(pair,2,config);
    verifyEqual(t,derived.available,type==0,derived.reason);
    if type>0
        verifyTrue(t,contains(data.reflectanceRatioReasons{1},quantities{type+1}));
        verifyTrue(t,contains(derived.reason,'radiance'));
        verifyFalse(t,isfield(r.driverSnapshot,'radiance'));
        verifyFalse(t,isfield(r.driverSnapshot,'totalRadiance'));
        verifyTrue(t,all(isfinite(r.spectralData)));
    else
        verifyEmpty(t,data.reflectanceRatioReasons{1});
        verifyEqual(t,derived.spectrum.y,ones(size(r.spectralData)));
    end
    clear cleanup
end
verifyEqual(t,numel(unique(keys)),4);
end

function testColorimeterAndUnknownMethodsDoNotClaimAbsoluteComparison(t)
[a,~]=adapterFor('CR100'); meter=a.connect('SIM'); t.addTeardown(@() delete(meter));
r=a.read(meter); data=colormeasure.drivers.cr.viewData(r,'CR100');
verifyFalse(t,data.hasSpectra); verifyNotEmpty(t,data.noSpectrumReason);
verifyEmpty(t,data.spectra{1}); verifyEmpty(t,data.xyzComparisonKeys{1});
verifyNotEmpty(t,data.chromaticityComparisonKeys{1});
verifyFalse(t,data.reflectanceRatioEligible); verifyNotEmpty(t,data.reflectanceRatioReasons{1});
r.xyzMethod='Future unverified method'; data=colormeasure.drivers.cr.viewData(r,'CR100');
verifyEmpty(t,data.xyzComparisonKeys{1}); verifyEmpty(t,data.chromaticityComparisonKeys{1});
verifyEmpty(t,data.spectralComparisonKeys{1}); verifyEmpty(t,data.observerId);
verifyFalse(t,data.reflectanceRatioEligible);
end

function testRatioRequiresConsistentSpectralQuantityProvenance(t)
[a,~]=adapterFor('CR250'); meter=a.connect('SIM'); t.addTeardown(@()delete(meter));
r=a.read(meter);
variants=repmat({r},1,6);
variants{1}.spectralQuantity='reflectance';
variants{2}.radiometricType=1; % Contradicts retained radiance units/quantity.
variants{3}.spectralUnitsConfirmed=true; % Not the driver's provisional convention.
variants{4}.xyzMethod='Unverified method';
variants{5}.observerId='Unverified observer';
variants{6}=rmfield(r,'radiometricType');
for index=1:numel(variants)
    original=variants{index};
    data=colormeasure.drivers.cr.viewData(original,'CR250');
    verifyFalse(t,data.reflectanceRatioEligible);
    verifyNotEmpty(t,data.reflectanceRatioReasons{1});
    verifyEqual(t,data.spectra{1}.y,original.spectralData);
end
end

function testCurrentMethodsRetainComparisonKeysThroughMatRoundTrip(t)
for model={'CR250','CR300'}
    [a,~]=adapterFor(model{1});meter=a.connect('SIM');cleanup=onCleanup(@()delete(meter));
    current=a.read(meter);clear cleanup
    % The host calculation string that cr/viewData.m compares against.
    verifyMethodPair(t,current,model{1},'MATLAB colormeasure.colorimetry.spectra2XYZ, CIE 1931 2 degree');
end
for model={'CR100','CR250','CR300'}
    verifyMethodPair(t,colormeasure.drivers.cr.syntheticReading(model{1},10),model{1}, ...
        'Synthetic colormeasure.colorimetry.spectra2XYZ; CIE 1931 2 degree; no instrument measurement');
end
end

function verifyMethodPair(t,current,model,literal)
% Pins the stored xyzMethod literal that viewData compares; changing it is a deliberate data change.
pinned=current; pinned.xyzMethod=literal;
verifyEqual(t,current.xyzMethod,pinned.xyzMethod);
before=[pinned current];
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
save(fullfile(f.Folder,'current-method.mat'),'before');saved=load(fullfile(f.Folder,'current-method.mat'));
data=colormeasure.drivers.cr.viewData(saved.before,model);
verifyEqual(t,saved.before,before);verifyEqual(t,data.xyzSources{1},pinned.xyzMethod);
verifyEqual(t,data.observerIds,{'CIE1931_2deg';'CIE1931_2deg'});
verifyNotEmpty(t,data.xyzComparisonKeys{1});
verifyEqual(t,data.xyzComparisonKeys{1},data.xyzComparisonKeys{2});
verifyEqual(t,data.spectralComparisonKeys{1},data.spectralComparisonKeys{2});
spectral=~strcmp(model,'CR100');
verifyEqual(t,data.reflectanceRatioEligible,repmat(spectral,2,1));
config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
derived=colormeasure.analysis.deriveIllumination(data,2,config);
verifyEqual(t,derived.available,spectral,derived.reason);
if spectral
    quantity='radiance';
    if current.isSynthetic,quantity='synthetic radiance';end
    verifyEqual(t,data.spectralQuantities,repmat({quantity},2,1));
    verifyEqual(t,data.reflectanceRatioReasons,{'';''});
    verifyEqual(t,derived.spectrum.y,ones(size(current.spectralData)));
else
    verifyNotEmpty(t,data.reflectanceRatioReasons{1});
end
pinned.xyzMethod=[pinned.xyzMethod ' unverified'];unknown=colormeasure.drivers.cr.viewData(pinned,model);
verifyEmpty(t,unknown.observerIds{1});verifyEmpty(t,unknown.xyzComparisonKeys{1});
verifyFalse(t,unknown.reflectanceRatioEligible);
end

function testSessionFailureReleasesWithoutRetryOrPartialReading(t)
[a,peer]=adapterFor('CR250'); state=peer.State;
peer.queue('M',sprintf('ER:-305:M:Light intensity too low\r\n'));
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
s=colormeasure.session.Session(a,f.Folder); t.addTeardown(@() delete(s));
verifyFalse(t,s.measure()); verifyEmpty(t,s.measurements);
verifyTrue(t,state('deleted')); verifyEqual(t,nnz(strcmp(state('commands'),'M')),1);
end

function testTimeoutAndFramedPayloadFailureReleaseWithoutPartialSession(t)
for problem={'timeout','numeric'}
    [a,peer]=adapterFor('CR250'); state=peer.State;
    if strcmp(problem{1},'timeout')
        peer.queue('M','');
    else
        peer.queue('RM XYZ',sprintf('OK:0:RM XYZ:1,2\r\n'));
    end
    f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    s=colormeasure.session.Session(a,f.Folder); cleanup=onCleanup(@() delete(s));
    verifyFalse(t,s.measure()); verifyEmpty(t,s.measurements);
    verifyTrue(t,state('deleted')); verifyEqual(t,state('deleteCount'),1);
    verifyEqual(t,nnz(strcmp(state('commands'),'M')),1);
    clear cleanup
end
end

function testScaleDeclarationRequiresMatchingKnownMetadata(t)
[a,~]=adapterFor('CR100'); meter=a.connect('SIM'); t.addTeardown(@() delete(meter));
r=a.read(meter); data=colormeasure.drivers.cr.viewData([r r],'CR100');
key=data.xyzScaleDeclarationKeys{1}; verifyNotEmpty(t,key);
verifyEqual(t,data.xyzScaleDeclarationKeys{2},key);
verifyEmpty(t,data.xyzComparisonKeys{1});
changed=r;
changed.instrumentMetadata.identity.serialNumber='OTHER-UNIT';
d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyNotEqual(t,d.xyzScaleDeclarationKeys{1},key);
for field={'accessory','aperture','filters'}
    changed=setSetting(r,field{1},'Other known setting','available');
    d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyNotEqual(t,d.xyzScaleDeclarationKeys{1},key);
end
changed=setSetting(r,'userCalibrationMode','Matrix','available');
changed=setSetting(changed,'matrixId','4','available');
d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyNotEmpty(t,d.xyzScaleDeclarationKeys{1});
verifyNotEqual(t,d.xyzScaleDeclarationKeys{1},key);
changed=setSetting(r,'exposureMs',200,'available');
d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyEqual(t,d.xyzScaleDeclarationKeys{1},key);
for status={'unparsed','unsupported','unavailable'}
    changed=setSetting(r,'accessory','Standard',status{1});
    d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyEmpty(t,d.xyzScaleDeclarationKeys{1});
end
changed=r; changed.instrumentMetadata=rmfield(changed.instrumentMetadata,'captureSettings');
d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyEmpty(t,d.xyzScaleDeclarationKeys{1});
changed=r; changed.instrumentMetadata.identity.serialNumber='';
d=colormeasure.drivers.cr.viewData(changed,'CR100'); verifyEmpty(t,d.xyzScaleDeclarationKeys{1});
synthetic=colormeasure.drivers.cr.syntheticReading('CR100',1); d=colormeasure.drivers.cr.viewData(synthetic,'CR100');
verifyNotEmpty(t,d.xyzComparisonKeys{1}); verifyEmpty(t,d.xyzScaleDeclarationKeys{1});
end

function r=setSetting(r,field,value,status)
r.instrumentMetadata.captureSettings.(field)=value;
entries=r.instrumentMetadata.metadataResponses;
index=find(strcmp({entries.field},field));
entries(index).value=value; entries(index).status=status;
r.instrumentMetadata.metadataResponses=entries;
end

function testSessionMatAndCsvRetainColorimeterAndSpectralReadings(t)
for model={'CR100','CR250','CR300'}
    [a,peer]=adapterFor(model{1}); state=peer.State;
    f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    s=colormeasure.session.Session(a,f.Folder); cleanup=onCleanup(@() delete(s));
    verifyTrue(t,s.measure('Sample, one',sprintf('Line one\nLine two')));
    verifyTrue(t,state('deleted'));
    loaded=load(s.files.mat); verifyEqual(t,loaded.measurements,s.measurements);
    s.finish(); exported=readtable(s.files.csv);
    expected=max(1,numel(s.measurements.lambda));
    verifyEqual(t,height(exported),expected);
    % CSV stores the logical flag as numeric 0/1; readtable infers doubles.
    verifyEqual(t,exported.HasSpectrum,repmat(double(~strcmp(model{1},'CR100')),expected,1));
    verifyEqual(t,string(exported.Notes),repmat("Line one"+newline+"Line two",expected,1));
    verifyEqual(t,exported.X,repmat(s.measurements.XYZ(1),expected,1),'RelTol',1e-12);
    clear cleanup
end
end

function testCsvRowsReadTheSessionStamp(t)
% An unstamped reading is refused rather than exported with blank names and times.
reading=colormeasure.drivers.cr.syntheticReading('CR100',1);
verifyError(t,@()colormeasure.drivers.cr.batchTable(reading,colormeasure.session.batchTiming(struct([]))), ...
    'MATLAB:nonExistentField');
end

function [a,peer]=adapterFor(model)
[~,label]=colormeasure.drivers.cr.modelInfo(model);
clock=colormeasuretest.FakeClock(); peer=colormeasuretest.cr.Port(label,clock); % One simulated clock for both.
% The explicit missing-M-reply test retains its short measurement timeout.
a=colormeasure.drivers.cr.adapter(model,'DriverFactory',@construct,'PortList',@(~) "SIM", ...
    'ResponseTimeout',5,'MeasurementTimeout',0.1);
    function meter=construct(key,port,varargin)
        factory=str2func(['colormeasure.drivers.cr.' key]);
        meter=factory(port,'Transport',peer,'Clock',clock,varargin{:});
    end
end

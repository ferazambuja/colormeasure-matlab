function tests = testCS2000Adapter
% Real CS driver plus isolated transport; no windows, ports or motion.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testOrdinaryAdapterRetainsExactReadingAndRestoresConnection(t)
[adapter,peer,state] = simulatedAdapter(t);
peer.State('speedPayload') = '3,120000000,0';
peer.queue('OBSR',sprintf('OK00,1\r\n'));
meter = adapter.connect('SIM_CS2000');
t.addTeardown(@()colormeasuretest.dispose(meter));
reading = adapter.read(meter);
verifyEqual(t,reading.XYZ,[95.047 100 108.883]);
verifyEqual(t,reading.lambda,(380:780)');
verifyEqual(t,reading.spectralData,(380:780)'/1000,'AbsTol',1e-14);
verifyEqual(t,reading.driverSnapshot.XYZData,reading.XYZ.');
verifyEqual(t,reading.driverSnapshot.spectralData,reading.spectralData);
verifyEqual(t,reading.instrumentMetadata,reading.driverSnapshot.metadata(end));
verifyEqual(t,reading.xyzMethod,reading.instrumentMetadata.acquisition.xyzSource);
% Exercise the live producer through the real consumer, rather than repeating
% the provenance literal in the test. Unknown absolute scale stays withheld.
view=colormeasure.drivers.cs2000.viewData(reading);
verifyEqual(t,view.observerIds,{'CIE1931_2deg'});
verifyNotEmpty(t,view.chromaticityComparisonKeys{1});
verifyNotEmpty(t,view.spectralComparisonKeys{1});
verifyTrue(t,view.reflectanceRatioEligible);
verifyEmpty(t,view.xyzComparisonKeys{1});
verifyEqual(t,reading.xyzUnits,'instrument scale (absolute unit not established)');
verifyFalse(t,reading.xyzUnitsConfirmed);
verifyEqual(t,reading.instrumentMetadata.acquisition.configurationBefore.observerMetadata.value,1);
verifyEqual(t,reading.instrumentMetadata.acquisition.configurationBefore.speed.speedMode,3);
verifyNumElements(t,reading.instrumentMetadata.acquisition.spectralResponse,4);
verifyEqual(t,reading.instrumentMetadata.identity.serialNumber,'1234567');
verifyEmpty(t,reading.instrumentMetadata.identity.firmware);
verifyEmpty(t,reading.warnings);
verifyTrue(t,reading.cleanupStatus.remoteReleased);
verifyFalse(t,meter.isConnected());
commands = state('commands');
verifyEqual(t,nnz(strcmp(commands,'MEAS,1')),1);
verifyFalse(t,any(startsWith(commands,{'SPMS,','OBSS,','STDS,','STDR,','VERR'})));
verifyEqual(t,commands(end-1:end),{'BALS,1,1','RMTS,0'});
adapter.release(meter);
verifyError(t,@()adapter.release(meter),'Measurement:ConnectionCleanupUnconfirmed');
verifyEqual(t,state('deleteCount'),1);
end

function testIndexedProjectionKeepsImportedIdentityUnitsAndSourceValues(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t);
meter.Connect(); meter.Measure();
port.queue('MEDR,2,0,01',sprintf('OK00,-1,0,3\r\n'));
port.queue('MEDR,0,0,1',sprintf('OK00,1,1,001000000,1,1,2,2,10\r\n'));
meter.Measure(); native = meter.snapshot(); commands = state('commands');
for index = 1:2
    r = colormeasure.drivers.cs2000.reading(native,index);
    verifyEqual(t,r.readingId,native.metadata(index).readingId);
    verifyEqual(t,r.XYZ,native.XYZData(:,index).');
    verifyEqual(t,r.spectralData,native.spectralData(:,index));
    verifyEqual(t,r.lambda,native.wavelengths);
    verifyEqual(t,r.instrumentMetadata,native.metadata(index));
    verifyEqual(t,r.xyzMethod,native.metadata(index).acquisition.xyzSource);
    verifyEqual(t,r.xyzUnits,'instrument scale (absolute unit not established)');
    verifyEqual(t,r.spectralUnits,'W/(sr m2 nm)');
    verifyFalse(t,r.xyzUnitsConfirmed); verifyTrue(t,r.spectralUnitsConfirmed);
    verifyEqual(t,r.driverSnapshot,native);
end
verifyEqual(t,colormeasure.drivers.cs2000.reading(native),colormeasure.drivers.cs2000.reading(native,2));
verifyEqual(t,state('commands'),commands); verifyEqual(t,meter.snapshot(),native);
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
path = fullfile(folder.Folder,'native.mat'); meter.Save(path);
[archive,~,offline] = colormeasuretest.cs2000.instrument(t); archive.Load(path);
imported = archive.snapshot(); imported.identity.model = 'Other destination';
for index = 1:2
    originalReading = colormeasure.drivers.cs2000.reading(native,index);
    importedReading = colormeasure.drivers.cs2000.reading(imported,index);
    verifyEqual(t,rmfield(importedReading,'driverSnapshot'),rmfield(originalReading,'driverSnapshot'));
end
verifyEmpty(t,offline('commands'));
for invalid = {0,3,NaN,Inf,-1,1.5,[1 2],1i,'1'}
    verifyError(t,@()colormeasure.drivers.cs2000.reading(native,invalid{1}),'CS2000:AdapterReading');
end
end

function testDefaultAndExplicitSerialOptionsReachTheDriverFactory(t)
cases = {{},{'BaudRate',9600,'FlowControl','hardware', ...
    'ResponseTimeout',20,'PreMeasurementTimeout',60,'ExpectedModel','CS-2000'}};
for index = 1:numel(cases)
    peer = colormeasuretest.cs2000.Port(); captured = {};
    t.addTeardown(@()colormeasuretest.dispose(peer));
    adapter = colormeasure.drivers.cs2000.adapter(cases{index}{:},'Transport',peer, ...
        'PortList',@(~)"SIM_CS2000",'DriverFactory',@construct);
    meter = adapter.connect('SIM_CS2000');
    t.addTeardown(@()colormeasuretest.dispose(meter));
    values = struct(captured{:});
    if index == 1
        verifyEqual(t,values.BaudRate,115200); verifyEqual(t,values.FlowControl,'none');
        verifyEqual(t,values.ResponseTimeout,10); verifyEqual(t,values.PreMeasurementTimeout,35);
    else
        verifyEqual(t,values.BaudRate,9600); verifyEqual(t,values.FlowControl,'hardware');
        verifyEqual(t,values.ResponseTimeout,20); verifyEqual(t,values.PreMeasurementTimeout,60);
        verifyEqual(t,values.ExpectedModel,'CS-2000');
    end
    verifyEqual(t,values.Transport,peer);
    verifyEqual(t,values.PortList(),"SIM_CS2000");
    adapter.release(meter);
end
    function meter = construct(port,varargin)
        captured = varargin;
        meter = colormeasure.drivers.cs2000.CS2000(port,varargin{:});
    end
end

function testWrongIdentityConnectFailureReleasesOwnedTransport(t)
[adapter,peer,state] = simulatedAdapter(t);
peer.queue('IDDR',sprintf('OK00,OTHER,1,1234567\r\n'));
verifyError(t,@()adapter.connect('SIM_CS2000'),'CS2000:Identity');
verifyTrue(t,state('deleted'));
verifyEqual(t,nnz(strcmp(state('commands'),'MEAS,1')),0);
end

function testConfigurationNormalizesEquivalentTypesAndExcludesTestHandles(t)
first = colormeasure.drivers.cs2000.adapter('BaudRate',9600,'FlowControl','hardware', ...
    'ResponseTimeout',20,'PreMeasurementTimeout',60,'ExpectedModel','CS-2000');
second = colormeasure.drivers.cs2000.adapter('BaudRate',uint32(9600),'FlowControl',"HARDWARE", ...
    'ResponseTimeout',single(20),'PreMeasurementTimeout',single(60),'ExpectedModel'," CS-2000 ", ...
    'PortList',@colormeasuretest.forbidPorts);
verifyEqual(t,first.configuration,second.configuration);
verifyEqual(t,first.configurationSummary,second.configurationSummary);
verifyFalse(t,any(isfield(first.configuration,{'PortList','Transport','DriverFactory'})));
defaults = colormeasure.drivers.cs2000.adapter();
verifyNotEqual(t,first.configuration,defaults.configuration);
end

function testReadFailureReleasesThroughSessionWithoutRetryOrHistory(t)
[adapter,peer,state] = simulatedAdapter(t);
peer.queue('MEAS,1',sprintf('ER10\r\n'));
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
session = colormeasure.session.Session(adapter,folder.Folder);
t.addTeardown(@()delete(session));
verifyFalse(t,session.measure('over range','simulated'));
verifyEmpty(t,session.measurements);
verifyEqual(t,session.savedCount,0);
verifyTrue(t,state('deleted'));
verifyEqual(t,nnz(strcmp(state('commands'),'MEAS,1')),1);
verifyTrue(t,any(contains({session.log.message},'CS2000:InstrumentError')));
end

function testUnverifiedCleanupRetainsCompleteReadingAndWarning(t)
[adapter,peer,~] = simulatedAdapter(t);
peer.queue('BALS,1,1',sprintf('ER10\r\n'));
meter = adapter.connect('SIM_CS2000');
t.addTeardown(@()colormeasuretest.dispose(meter));
reading = [];
verifyWarning(t,@()readInto(),'CS2000:CleanupUnverified');
    function readInto()
        reading = adapter.read(meter);
    end
verifySize(t,reading.driverSnapshot.XYZData,[3 1]);
verifyFalse(t,reading.cleanupStatus.backlightRestored);
verifyTrue(t,reading.cleanupStatus.portClosed);
% A closed port with an unrestored setting names only settings restoration.
verifyEqual(t,reading.warnings(1), ...
    {'Instrument settings restoration is unverified; inspect the device before another measurement.'});
verifyFalse(t,any(contains(reading.warnings,'Connection cleanup')));
end

function testAdapterCarriesAnUnrestoredBacklightToTheNextConnection(t)
% One adapter serves a session's connections, so the next connection restores
% what an uncertain stop left off. Each connection gets a fresh simulated port;
% its State map outlives the port, which closing the connection deletes.
ports = {}; states = {};
adapter = colormeasure.drivers.cs2000.adapter('PortList',@(~)"SIM_CS2000",'DriverFactory',@construct);
meter = adapter.connect('SIM_CS2000');
ports{1}.queue('MEAS,1',sprintf('ER02\r\n'));
verifyWarning(t,@()verifyError(t,@()adapter.read(meter),'CS2000:InstrumentError'),'CS2000:CleanupUnverified');
adapter.release(meter);
first = states{1}('commands');
verifyEqual(t,nnz(strcmp(first,'BALS,1,0')),1); verifyFalse(t,any(strcmp(first,'BALS,1,1')));
meter = adapter.connect('SIM_CS2000');
t.addTeardown(@()colormeasuretest.dispose(meter));
reading = adapter.read(meter);
commands = states{2}('commands');
verifyFalse(t,any(strcmp(commands,'BALS,1,0')));
verifyEqual(t,commands(end-1:end),{'BALS,1,1','RMTS,0'});
verifyTrue(t,reading.cleanupStatus.backlightRestored);
verifyEqual(t,reading.instrumentMetadata.acquisition.backlight.originalSettings,[1 1]);
verifyEmpty(t,reading.warnings);
adapter.release(meter);
    function meter = construct(port,varargin)
        peer = colormeasuretest.cs2000.Port();
        t.addTeardown(@()colormeasuretest.dispose(peer));
        if ~isempty(ports), peer.queue('BALR',sprintf('OK00,1,0\r\n')); end
        ports{end+1} = peer; states{end+1} = peer.State;
        options = varargin; at = 2*find(strcmp(options(1:2:end),'Transport'));
        options(at-1:at) = [];
        meter = colormeasure.drivers.cs2000.CS2000(port,options{:},'Transport',peer);
    end
end

function testReleaseRefusesAnUnavailableOwnerWithoutAssumingCleanup(t)
% Empty or already destroyed owners cannot attest that this Session's
% outstanding connection has stopped. Native Disconnect is idempotent while
% its actual owner remains alive; destroying that owner is a separate action.
[adapter,~,~] = simulatedAdapter(t);
verifyError(t,@()adapter.release([]),'Measurement:ConnectionCleanupUnconfirmed');
gone = colormeasuretest.cs2000.Port(); delete(gone);
verifyError(t,@()adapter.release(gone),'Measurement:ConnectionCleanupUnconfirmed');
end

function testSnapshotSaveAndReloadPreserveIndependentConditions(t)
[adapter,~,~] = simulatedAdapter(t);
meter = adapter.connect('SIM_CS2000');
t.addTeardown(@()colormeasuretest.dispose(meter));
meter.Measure(); meter.StoreMeasurementConditions();
before = meter.snapshot();
verifyTrue(t,before.measurementConditionsIndependent);
verifyFalse(t,meter.isSaved);
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
file = fullfile(folder.Folder,'native snapshot.mat');
meter.Save(file); saved = load(file);
verifyEqual(t,saved.measurements,before);
verifyEqual(t,saved.measurements.spectralData,before.spectralData);
verifyEqual(t,saved.measurements.XYZData,before.XYZData);
verifyEqual(t,saved.measurements.measurementConditions,before.measurementConditions);
archive = colormeasure.drivers.cs2000.CS2000('UNOPENED','PortList',@colormeasuretest.forbidPorts);
t.addTeardown(@()delete(archive));
archive.Load(file);
loaded = archive.snapshot();
verifyEqual(t,loaded.metadata,before.metadata);
verifyEqual(t,loaded.XYZData,before.XYZData);
verifyTrue(t,loaded.measurementConditionsIndependent);
archive.Erase();
verifyEqual(t,archive.measurementConditions,before.measurementConditions);
end

function testBatchMatRetainsNativeSnapshotAndCsvUsesRawNames(t)
[adapter,~,state] = simulatedAdapter(t);
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
session = colormeasure.session.Session(adapter,folder.Folder);
t.addTeardown(@()delete(session));
verifyTrue(t,session.measure('capture','metadata retained'));
verifyTrue(t,state('deleted'));
saved = load(session.files.mat);
verifyEqual(t,saved.measurements,session.measurements);
reading = session.measurements;
verifyEqual(t,reading.driverSnapshot.metadata,reading.instrumentMetadata);
session.finish();
data = readtable(session.files.csv,'VariableNamingRule','preserve');
verifyEqual(t,height(data),401);
verifyEqual(t,data.Raw_X,repmat(reading.XYZ(1),401,1));
verifyFalse(t,any(startsWith(data.Properties.VariableNames,'Computed_')));
verifyEqual(t,string(data.XYZSource),repmat(string(reading.xyzMethod),401,1));
verifyEqual(t,string(data.XYZUnits),repmat(string(reading.xyzUnits),401,1));
empty = colormeasure.drivers.cs2000.batchTable(struct([]),struct());
verifyEqual(t,height(empty),0);
verifyTrue(t,all(ismember({'Raw_X','Raw_Y','Raw_Z','XYZSource','XYZUnits'},empty.Properties.VariableNames)));
% Rows read the session stamp: an unstamped reading is refused, not written
% with blank names and times.
verifyError(t,@()colormeasure.drivers.cs2000.batchTable(colormeasure.drivers.cs2000.syntheticReading(1), ...
    colormeasure.session.batchTiming(struct([]))),'MATLAB:nonExistentField');
end

function testAdapterRejectsUnsafeOrUnknownOptionsBeforeConstructing(t)
verifyError(t,@()colormeasure.drivers.cs2000.adapter('PreMeasurementTimeout',10),'MATLAB:InputParser:ArgumentFailedValidation');
verifyError(t,@()colormeasure.drivers.cs2000.adapter('DiscardPendingInput',true),'MATLAB:InputParser:UnmatchedParameter');
adapter = colormeasure.drivers.cs2000.adapter('PortList',@colormeasuretest.forbidPorts);
verifyEqual(t,adapter.key,'CS2000'); % Construction does not enumerate.
end

function testPreparationContractAndSessionGetterDoNotAcquireOrSave(t)
info = colormeasure.drivers.cs2000.preparation();
verifyTrue(t,isstruct(info) && isscalar(info));
verifyTrue(t,all(isfield(info,{'title','summary','details','url','required'})));
verifyTrue(t,ischar(info.title) && isrow(info.title) && ~isempty(info.title));
verifyTrue(t,ischar(info.summary) && isrow(info.summary) && ~isempty(info.summary));
verifyTrue(t,iscellstr(info.details) && ~isempty(info.details));
verifyTrue(t,ischar(info.url) && startsWith(info.url,'https://www.konicaminolta.com/'));
verifyEqual(t,info.required,true);
[adapter,~,state] = simulatedAdapter(t);
verifyEqual(t,adapter.preparation,info);
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
session = colormeasure.session.Session(adapter,folder.Folder);
t.addTeardown(@()delete(session));
verifyEqual(t,session.preparation,info);
copy = session.preparation; copy.required = false;
verifyTrue(t,session.preparation.required); % A value copy cannot dismiss the live reminder.
verifyFalse(t,copy.required);
verifyEmpty(t,state('commands'));
verifyEmpty(t,session.measurements);
verifyEmpty(t,session.files.folder);
end

function testSyntheticPreparationKeepsHelpWithoutRequiredLiveReminder(t)
liveAdapter = colormeasure.drivers.cs2000.uiAdapter(); live = liveAdapter.preparation;
verifyEqual(t,liveAdapter.catalog,struct('model','CS2000','mode','measure'));
for mode = {'interactive','batch','gallery'}
    adapter = colormeasure.drivers.cs2000.demoAdapter(mode{1});
    verifyEqual(t,adapter.catalog,struct('model','CS2000','mode',mode{1}));
    verifyEqual(t,adapter.preparation.required,false);
    verifyEqual(t,rmfield(adapter.preparation,'required'),rmfield(live,'required'));
end
end

function [adapter,peer,state] = simulatedAdapter(t)
peer = colormeasuretest.cs2000.Port(); state = peer.State;
t.addTeardown(@()colormeasuretest.dispose(peer));
adapter = colormeasure.drivers.cs2000.adapter('Transport',peer,'PortList',@(~)"SIM_CS2000");
end

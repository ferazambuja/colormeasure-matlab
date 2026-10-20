function tests = testCS2000
% Every acquisition test injects the isolated in-memory peer. Gonio checks
% use recording fake stages; no physical connection or motion.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testConnectMeasureRetainsOrderedDataAndMetadata(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
verifyFalse(testCase,meter.isConnected());
verifyEmpty(testCase,state('commands'));
meter.Connect(); meter.Measure();
verifyTrue(testCase,meter.isConnected());
verifyEqual(testCase,port.Terminator,'CR/LF');
verifyEqual(testCase,meter.spectralData,(380:780)'/1000,'AbsTol',1e-14);
verifyEqual(testCase,meter.XYZData,[95.047;100;108.883]);
verifyEqual(testCase,meter.wavelengths,(380:780)');
verifyAligned(testCase,meter,1);
verifyEqual(testCase,meter.metadata(1).identity,meter.identity);
verifyEqual(testCase,meter.metadata(1).conditions,meter.measurementConditions);
verifyEqual(testCase,meter.metadata(1).acquisition.announcedDurationSeconds,2);
commands = state('commands');
verifyEqual(testCase,commands(1:6),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0','DTCR'});
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
verifyEqual(testCase,commands(7:end),{'SCMR','SPMR','OBSR','MEAS,1','MEDR,1,0,1','MEDR,1,0,2', ...
    'MEDR,1,0,3','MEDR,1,0,4','MEDR,2,0,01','MEDR,0,0,1'});
verifyFalse(testCase,any(startsWith(commands,{'STDS,','STDR,'})));
end

function testDisconnectRestoresPriorBacklightAndReleasesPort(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Disconnect(); meter.Disconnect();
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('deleteCount'),1);
commands = state('commands');
verifyEqual(testCase,commands(end-1:end),{'BALS,1,1','RMTS,0'});
verifyTrue(testCase,meter.cleanupStatus.backlightRestored);
verifyTrue(testCase,meter.cleanupStatus.remoteReleased);
verifyTrue(testCase,meter.cleanupStatus.portClosed);
verifyFalse(testCase,meter.isConnected());
end

function testConnectEnablesFiniteWriteDeadline(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cs2000.Port(clock);
meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'Clock',clock,'ResponseTimeout',0.4);
cleanup = onCleanup(@()delete(meter));
meter.Connect();
verifyTrue(testCase,port.EnableWriteTimeout);
verifyEqual(testCase,port.Timeout,0.4);
verifyEqual(testCase,meter.preMeasurementTimeout,35);
end

function testInitializationWriteTimeoutClosesWithoutCleanupWrites(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cs2000.Port(clock);
state = port.State; port.WriteTimeoutCommand = 'RMTS,1';
meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'Clock',clock,'ResponseTimeout',0.4);
cleanup = onCleanup(@()delete(meter));
verifyError(testCase,@()meter.Connect(),'SerialTest:WriteTimeout');
verifyEqual(testCase,clock.now(),0.4,'AbsTol',1e-12);
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RMTS,1'});
verifyFalse(testCase,meter.isConnected());
end

function testPartialMeasurementWritePreservesHistoryWithoutRetry(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cs2000.Port(clock);
meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'Clock',clock,'ResponseTimeout',0.4);
cleanup = onCleanup(@()delete(meter)); meter.Connect(); meter.Measure();
state = port.State; before = struct('XYZ',meter.XYZData,'spectrum',meter.spectralData,'metadata',meter.metadata);
port.WriteTimeoutCommand = 'MEAS,1'; meter.responseTimeout = 0.25; started = clock.now();
verifyError(testCase,@()meter.Measure(),'SerialTest:WriteTimeout');
verifyEqual(testCase,clock.now()-started,0.25,'AbsTol',1e-12);
verifyEqual(testCase,state('writeTimeout'),0.25);
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),2);
verifyTrue(testCase,state('deleted')); verifyEqual(testCase,state('deleteCount'),1);
commands = state('commands'); verifyEqual(testCase,commands{end},'MEAS,1');
verifyFalse(testCase,meter.cleanupStatus.backlightRestored);
verifyFalse(testCase,meter.cleanupStatus.remoteReleased);
verifyEqual(testCase,meter.XYZData,before.XYZ);
verifyEqual(testCase,meter.spectralData,before.spectrum);
verifyEqual(testCase,meter.metadata,before.metadata);
verifyAligned(testCase,meter,1);
verifyError(testCase,@()meter.Measure(),'CS2000:Disconnected');
end

function testInvalidBacklightRefusesSetupAndReleasesConnection(testCase)
for invalid={[0 2],[-1 1],[0.5 1],[1 -1]}
    [meter,port,state]=colormeasuretest.cs2000.instrument(testCase);
    port.queue('BALR',sprintf('OK00,%g,%g\r\n',invalid{1}));
    verifyError(testCase,@()meter.Connect(),'CS2000:Backlight');
    verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','BALR','RMTS,0'});
    verifyFalse(testCase,meter.isConnected());verifyTrue(testCase,state('deleted'));
    verifyTrue(testCase,meter.cleanupStatus.remoteReleased);
    verifyTrue(testCase,meter.cleanupStatus.portClosed);verifyAligned(testCase,meter,0);
end
end

function testAlreadyOffBacklightDoesNotWriteOrRestore(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('BALR',sprintf('OK00,0,0\r\n'));
meter.Connect(); meter.Disconnect();
commands = state('commands');
verifyFalse(testCase,any(startsWith(commands,'BALS,')));
verifyEqual(testCase,commands{end},'RMTS,0');
verifyTrue(testCase,meter.cleanupStatus.backlightRestored);
end

function testWrongIdentityClosesWithoutAcquisition(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('IDDR',sprintf('OK00,OTHER    ,1,1234567\r\n'));
verifyError(testCase,@()meter.Connect(),'CS2000:Identity');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),0);
verifyFalse(testCase,meter.isConnected());
end

function testInitializationFailureRestoresBacklight(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('MSWE,0',sprintf('ER17\r\n'));
verifyError(testCase,@()meter.Connect(),'CS2000:InstrumentError');
verifyTrue(testCase,state('deleted'));
commands = state('commands');
verifyEqual(testCase,commands(end-1:end),{'BALS,1,1','RMTS,0'});
verifyTrue(testCase,meter.cleanupStatus.backlightRestored);
end

function testInitializationTimeoutDoesNotSendUnsafeCleanup(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('IDDR','');
err = connectFailure(testCase,meter,'CS2000:Timeout');
verifyEqual(testCase,err.message,'Timed out after 0.05 seconds waiting for a complete response.');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR'});
end

function testOverlongReplyFailsFramingWithoutUnsafeCleanup(testCase)
% The shared line receiver carries the CS-2000 wording: more than 4096 bytes
% before a terminator is a framing failure, and nothing further is sent on a
% port whose framing is unknown.
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('IDDR',repmat('x',1,4097));
err = connectFailure(testCase,meter,'CS2000:Framing');
verifyEqual(testCase,err.message,'Response line exceeds 4096 bytes.');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR'});
end

function testAcknowledgementWithTrailingCommaFailsClosed(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('RMTS,1',sprintf('OK00,\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Connect(),'CS2000:Framing');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RMTS,1'});
end

function testBacklightRestorationFailureStillClosesAndReleases(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); port.queue('BALS,1,1',sprintf('ER17\r\n'));
% Restoration failed, so the close is reported as unverified.
verifyWarning(testCase,@()meter.Disconnect(),'CS2000:CleanupUnverified');
verifyTrue(testCase,state('deleted'));
verifyFalse(testCase,meter.cleanupStatus.backlightRestored);
verifyTrue(testCase,meter.cleanupStatus.remoteReleased);
verifyTrue(testCase,meter.cleanupStatus.portClosed);
verifyNotEmpty(testCase,meter.cleanupStatus.details);
end

function testFragmentedDelayedRepliesAndCompletion(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase,'Clock',colormeasuretest.FakeClock());
text = sprintf('OK00,CS-2000  ,1,1234567\r\n');
port.queue('IDDR',text,[3 numel(text)-4 1],[0 0.005 0.02]);
meter.Connect();
text = sprintf('OK00,002\r\nOK00\r\n');
port.queue('MEAS,1',text,[2 8 3 numel(text)-13],[0 0.005 0.075 0.1]);
text = ['OK00' sprintf(',%.4fe+0',(380:479)/1000) sprintf('\r\n')];
port.queue('MEDR,1,0,1',text,[11 117 numel(text)-129 1],[0 0.005 0.012 0.02]);
meter.Measure();
verifyAligned(testCase,meter,1);
verifyEqual(testCase,meter.metadata(1).acquisition.announcedDurationSeconds,2);
verifyEqual(testCase,meter.spectralData,(380:780)'/1000,'AbsTol',1e-14);
end

function testMissingCompletionTimesOutWithoutRetryOrCleanupCommands(testCase)
% The announced 2 s duration elapses on a simulated clock shared with the port.
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cs2000.Port(clock); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'ResponseTimeout',0.05,'Clock',clock);
testCase.addTeardown(@()delete(meter));
meter.Connect();
port.queue('MEAS,1',sprintf('OK00,002\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:Timeout');
verifyTrue(testCase,state('deleted'));
commands = state('commands');
verifyEqual(testCase,commands{end},'MEAS,1');
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
verifyAligned(testCase,meter,0);
end

function testMalformedDurationIsRejectedWithoutAnotherCommand(testCase)
for duration = {'','000','02','2.0','-02','NaN','1e2','002,003'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    meter.Connect(); port.queue('MEAS,1',sprintf('OK00,%s\r\n',duration{1}));
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:Duration');
    commands = state('commands');
    verifyEqual(testCase,commands{end},'MEAS,1');
    verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
    verifyTrue(testCase,state('deleted'));
    verifyAligned(testCase,meter,0);
end
end

function testInstrumentMeasurementErrorKeepsPriorHistory(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); before = snapshot(meter);
port.queue('MEAS,1',sprintf('ER10\r\n'));
verifyError(testCase,@()meter.Measure(),'CS2000:InstrumentError');
verifyEqual(testCase,snapshot(meter),before);
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),2);
verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
meter.Measure();
verifyAligned(testCase,meter,2);
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),3);
end

function testCompletionErrorNeverReadsMeasurement(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); port.queue('MEAS,1',sprintf('OK00,002\r\nER71\r\n'));
verifyError(testCase,@()meter.Measure(),'CS2000:InstrumentError');
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEDR,2,0,01'),0);
verifyAligned(testCase,meter,0);
verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end

function testErrorFramesWithPayloadCloseWithoutCleanupCommands(testCase)
cases={ ...
    'MEAS,1',sprintf('ER10,garbage\r\n'); ...
    'MEAS,1',sprintf('OK00,002\r\nER71,garbage\r\n'); ...
    'MEDR,2,0,01',sprintf('ER10,garbage\r\n'); ...
    'MEDR,2,0,01',sprintf('ER10,\r\n')};
for index=1:size(cases,1)
    [meter,port,state]=colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
    before=snapshot(meter); command=cases{index,1};
    port.queue(command,cases{index,2});
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@() meter.Measure(),'CS2000:Framing');
    verifyEqual(testCase,snapshot(meter),before);
    verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
    commands=state('commands'); verifyEqual(testCase,commands{end},command);
end
end

function testMalformedXYZAndSentinelAreRejected(testCase)
for payload = {'1,2','1,2,3,4','1,,3','NaN,2,3','Inf,2,3','1e999,2,3','sin(1),2,3','1+2i,2,3','-9.9999e9,2,3'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    meter.Connect();
    port.queue('MEDR,2,0,01',sprintf('OK00,%s\r\n',payload{1}));
    identifier = 'CS2000:NumericPayload';
    if startsWith(payload{1},'-9.9999e9'), identifier = 'CS2000:CalculationError'; end
    verifyError(testCase,@()meter.Measure(),identifier);
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end
end

function testIncompleteAndOversizedSpectralBlocksAreRejected(testCase)
for count = [99 101]
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    meter.Connect(); meter.Measure(); before = snapshot(meter);
    text = ['OK00' repmat(',0.001',1,count) sprintf('\r\n')];
    port.queue('MEDR,1,0,2',text);
    verifyError(testCase,@()meter.Measure(),'CS2000:NumericPayload');
    verifyEqual(testCase,snapshot(meter),before);
    verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end
end

function testMalformedSpectrumAndSentinelAreRejected(testCase)
for value = {'NaN','1e999','1+2','-9.9999e9'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    meter.Connect();
    text = ['OK00,' value{1} repmat(',0.001',1,100) sprintf('\r\n')];
    port.queue('MEDR,1,0,4',text);
    identifier = 'CS2000:NumericPayload';
    if strcmp(value{1},'-9.9999e9'), identifier = 'CS2000:CalculationError'; end
    verifyError(testCase,@()meter.Measure(),identifier);
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end
end

function testInstrumentBlockErrorDoesNotPartiallyAppend(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); before = snapshot(meter);
port.queue('MEDR,1,0,4',sprintf('ER20\r\n'));
verifyError(testCase,@()meter.Measure(),'CS2000:InstrumentError');
verifyEqual(testCase,snapshot(meter),before);
verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end

function testConditionsCountAndValuesAreValidated(testCase)
% Seven or nine fields, and NaN, fail the decimal payload parser; values
% outside the documented ranges fail the conditions check.
payloads = {'0,0,2000000,0,0,0,0','0,0,2000000,0,0,0,0,0,0', ...
    '0,0,2000000,0,0,3,0,0','0,0,2000000,0,0,0,3,0','0,0,2000000,0,0,0,0,11','0,0,NaN,0,0,0,0,0'};
expected = {'CS2000:NumericPayload','CS2000:NumericPayload','CS2000:Conditions', ...
    'CS2000:Conditions','CS2000:Conditions','CS2000:NumericPayload'};
for index = 1:numel(payloads)
    payload = payloads(index);
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    meter.Connect();
    port.queue('MEDR,0,0,1',sprintf('OK00,%s\r\n',payload{1}));
    verifyCSFailure(testCase,@()meter.Measure(),expected{index});
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,state('deleted'));
verifyTrue(testCase,meter.isConnected());
end
end

function testExtraFinalResponsePreventsCommitAndCleanupCommands(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect();
port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,00\r\nOK00\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:PendingInput');
verifyAligned(testCase,meter,0);
verifyTrue(testCase,state('deleted'));
commands = state('commands');
verifyEqual(testCase,commands{end},'MEDR,0,0,1');
end

function testPerReadingConditionsDoNotOverwriteOlderMetadata(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); first = meter.metadata(1);
port.queue('MEDR,0,0,1',sprintf('OK00,1,1,001000000,1,1,2,2,10\r\n'));
meter.Measure();
verifyEqual(testCase,meter.metadata(1),first);
verifyNotEqual(testCase,meter.metadata(2).conditions,first.conditions);
verifyEqual(testCase,meter.measurementConditions,meter.metadata(2).conditions);
verifyAligned(testCase,meter,2);
meter.Erase();
verifyEqual(testCase,meter.measurementConditions,first.conditions);
end

function testSignedSpectraAndXYZStayUnchanged(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect();
port.queue('MEDR,2,0,01',sprintf('OK00,-1,0,3\r\n'));
text = ['OK00,-0.001' repmat(',0',1,99) sprintf('\r\n')];
port.queue('MEDR,1,0,1',text); meter.Measure();
verifyEqual(testCase,meter.XYZData,[-1;0;3]);
verifyEqual(testCase,meter.spectralData(1),-0.001);
verifyEqual(testCase,meter.spectralData(2:100),zeros(99,1));
verifyAligned(testCase,meter,1);
end

function testSaveReloadRoundTripAndWarningState(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); meter.Measure();
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
beforeWarnings = warning;
meter.Save(fileName); saved = load(fileName);
verifyEqual(testCase,warning,beforeWarnings);
verifyTrue(testCase,meter.isSaved);
verifyEqual(testCase,saved.measurements.spectralData,meter.spectralData);
verifyEqual(testCase,saved.measurements.XYZData,meter.XYZData);
verifyEqual(testCase,saved.measurements.measurementConditions,meter.measurementConditions);
verifyEqual(testCase,saved.measurements.metadata,meter.metadata);
verifyEqual(testCase,saved.measurements.identity,meter.identity);
verifyEqual(testCase,saved.measurements.wavelengths,(380:780)');
[other,~,state] = colormeasuretest.cs2000.instrument(testCase);
other.Load(fileName); imported = other.snapshot();
verifyError(testCase,@()other.Load(fileName),'CS2000:DuplicateReading');
verifyEqual(testCase,other.snapshot(),imported);
verifyEmpty(testCase,state('commands'));
verifyEqual(testCase,other.spectralData,meter.spectralData);
verifyEqual(testCase,other.XYZData,meter.XYZData);
verifyEqual(testCase,other.metadata,meter.metadata);
verifyFalse(testCase,other.isSaved);
verifyAligned(testCase,other,2);
end

function testStableReadingIdentitySurvivesEraseAndImport(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); segmentId = meter.segmentId;
meter.Measure(); meter.Measure(); original = meter.metadata;
verifyNotEqual(testCase,original(1).readingId,original(2).readingId);
meter.Erase(); verifyEqual(testCase,meter.metadata,original(1));
meter.Measure(); replacementId = meter.metadata(2).readingId;
verifyFalse(testCase,ismember(replacementId,{original.readingId}));
meter.EraseAll(); meter.Measure();
verifyFalse(testCase,ismember(meter.metadata.readingId,[{original.readingId} {replacementId}]));
verifyEqual(testCase,meter.segmentId,segmentId);
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
path = fullfile(folder.Folder,'identity.mat'); meter.Save(path);
native = meter.snapshot();
[archive,~,offline] = colormeasuretest.cs2000.instrument(testCase);
archiveSegmentId = archive.segmentId;
archive.Load(path); retained = archive.snapshot();
verifyEqual(testCase,retained.schemaVersion,2);
verifyEqual(testCase,retained.segmentId,archiveSegmentId);
verifyNotEqual(testCase,retained.segmentId,native.segmentId);
verifyEqual(testCase,retained.metadata,native.metadata);
verifyEmpty(testCase,offline('commands'));
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),4);
end

function testImportRejectsDuplicateConflictingOrMissingReadingIdentityAtomically(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); meter.Measure(); original = meter.snapshot();
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
path = fullfile(folder.Folder,'duplicate.mat');
[archive,~] = colormeasuretest.cs2000.instrument(testCase); before = archive.snapshot();
for invalid = 1:4
    measurements = original;
    switch invalid
        case 1, measurements.metadata(2).readingId = measurements.metadata(1).readingId;
        case 2, measurements.metadata(1).readingId = '';
        case 3, measurements.metadata = rmfield(measurements.metadata,'readingId');
        case 4, measurements.schemaVersion = 1;
    end
    save(path,'measurements');
    expected = 'CS2000:FileFormat'; if invalid == 1, expected = 'CS2000:DuplicateReading'; end
    verifyError(testCase,@()archive.Load(path),expected);
    verifyEqual(testCase,archive.snapshot(),before);
end
measurements = original; save(path,'measurements'); archive.Load(path);
before = archive.snapshot(); measurements.XYZData(1,1) = measurements.XYZData(1,1)+1;
save(path,'measurements');
verifyError(testCase,@()archive.Load(path),'CS2000:DuplicateReading');
verifyEqual(testCase,archive.snapshot(),before);
end

function testDirectSaveRetainsNativeSnapshotWithoutAcquiring(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
meter.Measure();meter.Measure();before=meter.snapshot();commands=state('commands');
path=fullfile(folder.Folder,'durable.mat');meter.Save(path);
verifyEqual(testCase,load(path,'measurements'),struct('measurements',before));
verifyEqual(testCase,meter.snapshot(),before);verifyEqual(testCase,state('commands'),commands);
verifyTrue(testCase,meter.isSaved);
end

function testRepeatedDirectSaveAfterEraseKeepsSnapshotAndDoesNotAcquire(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
meter.Measure();meter.Measure();commands=state('commands');
path=fullfile(folder.Folder,'durable.mat');meter.Save(path);previous=colormeasure.fileDigest(path);
meter.Erase();before=meter.snapshot();
verifyFalse(testCase,meter.isSaved);
meter.Save(path);
verifyEqual(testCase,load(path,'measurements'),struct('measurements',before));
verifyEqual(testCase,meter.snapshot(),before);verifyEqual(testCase,state('commands'),commands);
verifyNotEqual(testCase,colormeasure.fileDigest(path),previous);
verifyTrue(testCase,meter.isSaved);
other=fullfile(folder.Folder,'another.mat');meter.Save(other);
verifyEqual(testCase,load(other,'measurements'),struct('measurements',before));
verifyEqual(testCase,state('commands'),commands);
end

function testQueriedConditionsRoundTripKeepsOriginalReadingProvenance(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure();
originalConditions = meter.metadata(1).conditions;
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
meter.Save(fileName);
verifyTrue(testCase,meter.isSaved);
port.queue('MEDR,0,0,1',sprintf('OK00,1,0,003000000,0,0,0,0,00\r\n'));
queried = meter.StoreMeasurementConditions();
verifyFalse(testCase,meter.isSaved);
verifyEqual(testCase,meter.metadata(1).conditions,originalConditions);
meter.Save(fileName);
[archive,~,state] = colormeasuretest.cs2000.instrument(testCase); archive.Load(fileName);
verifyEqual(testCase,archive.measurementConditions,queried);
verifyEqual(testCase,archive.metadata(1).conditions,originalConditions);
verifyEmpty(testCase,state('commands'));
end

function testQueriedConditionsRoundTripWithoutReadings(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
port.queue('MEDR,0,0,1',sprintf('OK00,1,0,003000000,0,0,0,0,00\r\n'));
queried = meter.StoreMeasurementConditions();
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
meter.Save(fileName);
[archive,~] = colormeasuretest.cs2000.instrument(testCase); archive.Load(fileName);
verifyEqual(testCase,archive.measurementConditions,queried);
verifyAligned(testCase,archive,0);
% Validate the separately saved state before changing any history or query.
saved = load(fileName); measurements = saved.measurements;
measurements.measurementConditions = 42;
save(fileName,'measurements');
verifyError(testCase,@()archive.Load(fileName),'CS2000:FileFormat');
verifyEqual(testCase,archive.measurementConditions,queried);
verifyAligned(testCase,archive,0);
end

function testMalformedLoadIsAtomic(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
before = snapshot(meter);
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
for badCase = 1:5
    spectralData = ones(401,1); XYZData = [1;2;3];
    switch badCase
        case 1, spectralData = ones(400,1);
        case 2, XYZData = ones(3,2);
        case 3, spectralData(1) = NaN;
        case 4, XYZData(2) = Inf;
        case 5, spectralData(1) = -9.9999e9;
    end
    measurements=meter.snapshot();
    measurements.spectralData=spectralData;measurements.XYZData=XYZData;
    measurements.metadata=repmat(meter.metadata,size(XYZData,2),1);
    save(fileName,'measurements');
    expected = 'CS2000:Reading'; if badCase == 5, expected = 'CS2000:Unavailable'; end % The sentinel value.
    verifyCSFailure(testCase,@()meter.Load(fileName),expected);
    verifyEqual(testCase,snapshot(meter),before);
end
end


function testIncompleteSnapshotAndPreviousFormatAreRefusedAtomically(testCase)
[meter,~]=colormeasuretest.cs2000.instrument(testCase);before=meter.snapshot();
fileName=[tempname '.mat'];cleanup=onCleanup(@()delete(fileName));
spectralData=ones(401,1);XYZData=[1;2;3];save(fileName,'spectralData','XYZData');
verifyError(testCase,@()meter.Load(fileName),'CS2000:FileFormat');
verifyEqual(testCase,meter.snapshot(),before);
for field={'metadata','measurementConditionsIndependent'}
    measurements=rmfield(before,field{1});save(fileName,'measurements');
    verifyError(testCase,@()meter.Load(fileName),'CS2000:FileFormat');
    verifyEqual(testCase,meter.snapshot(),before);
end
for field={'identity','measurementConditions','measurementConditionsIndependent'}
    measurements=before;measurements.(field{1})=42;save(fileName,'measurements');
    verifyError(testCase,@()meter.Load(fileName),'CS2000:FileFormat');
    verifyEqual(testCase,meter.snapshot(),before);
end
end

function testFailedSaveLeavesWarningsAndDataUnchanged(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
before = snapshot(meter); beforeWarnings = warning; caught = false;
try
    meter.Save(fullfile(tempname,'missing','capture.mat'));
catch problem
    caught = true; verifyEqual(testCase,problem.identifier,'CS2000:SavePath');
end
verifyTrue(testCase,caught); verifyEqual(testCase,warning,beforeWarnings);
verifyEqual(testCase,snapshot(meter),before); verifyFalse(testCase,meter.isSaved);
end

function testSaveRefusesUnusableDestinationsWithSavePath(testCase)
% An empty name, a missing folder and a directory are refused before staging.
[meter,~] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
verifyError(testCase,@()meter.Save(''),'CS2000:SavePath');
verifyError(testCase,@()meter.Save(fullfile(folder.Folder,'missing','capture.mat')),'CS2000:SavePath');
mkdir(fullfile(folder.Folder,'taken.mat'));
verifyError(testCase,@()meter.Save(fullfile(folder.Folder,'taken.mat')),'CS2000:SavePath');
mats = dir(fullfile(folder.Folder,'*.mat')); % taken.mat is the refused directory.
verifyFalse(testCase,meter.isSaved); verifyEmpty(testCase,mats(~[mats.isdir]));
end

function testEmptyHistoryEraseSaveAndReload(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase);
meter.Erase(); meter.EraseAll(); meter.Erase(); verifyAligned(testCase,meter,0);
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
meter.Save(fileName); meter.Load(fileName); verifyAligned(testCase,meter,0);
meter.Connect(); meter.Measure(); meter.Measure(); meter.Erase();
verifyAligned(testCase,meter,1);
meter.EraseAll(); verifyAligned(testCase,meter,0);
verifyEqual(testCase,meter.measurementConditions,struct());
end

function testManualIntegrationTimeIsCheckedAfterPreflightAndBeforeAnyCommand(testCase)
% Rev.7 pp.20-22: 0.005 to 120 s in whole microseconds. The value check
% follows the connection preflight and precedes the SPMR readback, so a
% refused value changes neither the instrument nor the history.
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.integrationTime = 0.004;
verifyError(testCase,@()meter.MeasureManual(),'CS2000:Disconnected');
meter.Connect(); commands = state('commands');
for seconds = [0.004 120.5 0.5000005]
    meter.integrationTime = seconds;
    verifyError(testCase,@()meter.MeasureManual(),'CS2000:IntegrationTime');
end
verifyEqual(testCase,state('commands'),commands);
verifyTrue(testCase,meter.isConnected()); verifyAligned(testCase,meter,0);
meter.integrationTime = 0.005; meter.MeasureManual();
verifyTrue(testCase,any(strcmp(state('commands'),'SPMS,3,000005000,0')));
verifyAligned(testCase,meter,1);
end

function testManualVariantRestoresPreviousSpeedSettings(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.Connect(); meter.MeasureManual();
commands = state('commands');
verifyTrue(testCase,any(strcmp(commands,'SPMS,3,002000000,0')));
verifyEqual(testCase,commands{end},'SPMS,0,2');
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
verifyAligned(testCase,meter,1);
end

function testManualRestoreFailureDoesNotCommitReading(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.Connect(); port.queue('SPMS,0,2',sprintf('ER17\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
verifyAligned(testCase,meter,0);
verifyFalse(testCase,meter.cleanupStatus.speedRestored);
verifyTrue(testCase,meter.cleanupStatus.backlightRestored);
verifyTrue(testCase,meter.cleanupStatus.remoteReleased);
verifyTrue(testCase,state('deleted'));
end

function testWorkingExampleSavesAndDisconnects(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
measurements = colormeasure.drivers.cs2000.measureToFile('SIM',fileName,'Transport',port);
verifyTrue(testCase,state('deleted'));
verifySize(testCase,measurements.spectralData,[401 1]);
verifySize(testCase,measurements.XYZData,[3 1]);
saved = load(fileName); verifyEqual(testCase,saved.measurements,measurements);
end

function testExampleFailureClosesWithoutSaving(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'reading.mat');
for alreadySaved = [false true]
    if alreadySaved
        previousReading = struct('name','retained earlier measurement','XYZ',[1 2 3]);
        save(fileName,'previousReading');
    end
    port = colormeasuretest.cs2000.Port(); state = port.State;
    port.queue('MEAS,1',sprintf('ER10\r\n'));
    verifyError(testCase,@()colormeasure.drivers.cs2000.measureToFile('SIM',fileName, ...
        'Transport',port,'ResponseTimeout',0.05,'ExpectedModel','CS-2000'), ...
        'CS2000:InstrumentError');
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('deleteCount'),1);
    verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
    if alreadySaved
        verifyEqual(testCase,load(fileName),struct('previousReading',previousReading));
    else
        verifyFalse(testCase,isfile(fileName));
    end
end
end

function testExampleForwardsPublicOptionsAndCustomIdentity(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'custom reading.mat');
port = colormeasuretest.cs2000.Port(); state = port.State;
port.queue('IDDR',sprintf('OK00,CUSTOM200,1,1234567\r\n'));
measurements = colormeasure.drivers.cs2000.measureToFile('SIM',fileName,'Transport',port, ...
    'BaudRate',9600,'FlowControl','hardware','ResponseTimeout',0.05, ...
    'PreMeasurementTimeout',60,'ExpectedModel'," CUSTOM200 ");
verifyEqual(testCase,measurements.identity.model,'CUSTOM200');
verifySize(testCase,measurements.spectralData,[401 1]);
verifySize(testCase,measurements.XYZData,[3 1]);
verifyEqual(testCase,numel(measurements.metadata),1);
verifyEqual(testCase,colormeasuretest.countCommands(state,'MEAS,1'),1);
verifyFalse(testCase,any(startsWith(state('commands'),{'SPMS,','OBSS,','STDS,','STDR,'})));
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('deleteCount'),1);
saved = load(fileName);
verifyEqual(testCase,saved.measurements,measurements);
end

function testExampleDelegatesPublicOptionValidationWithoutCommandsOrSave(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'invalid options.mat');
cases = {'BaudRate',12345; 'BaudRate',[]; 'FlowControl','software'; ...
    'ResponseTimeout',0; 'PreMeasurementTimeout',34; 'ExpectedModel','TENLETTERS'};
for index = 1:size(cases,1)
    port = colormeasuretest.cs2000.Port(); state = port.State;
    cleanup = onCleanup(@()colormeasuretest.dispose(port));
    identifier = 'MATLAB:InputParser:ArgumentFailedValidation';
    if strcmp(cases{index,1},'ExpectedModel'), identifier = 'CS2000:Identity'; end
    verifyError(testCase,@()colormeasure.drivers.cs2000.measureToFile('SIM',fileName, ...
        'Transport',port,cases{index,:}),identifier);
    verifyEmpty(testCase,state('commands'));
    verifyFalse(testCase,isfile(fileName));
    clear cleanup
end
end

function testExampleResponseTimeoutClosesWithoutSaving(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'timed out reading.mat');
port = colormeasuretest.cs2000.Port(); state = port.State;
port.queue('IDDR','');
elapsed = tic;
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()colormeasure.drivers.cs2000.measureToFile('SIM',fileName, ...
    'Transport',port,'ResponseTimeout',0.05),'CS2000:Timeout');
% A dropped ResponseTimeout would use ten seconds; leave ample scheduler margin.
verifyLessThan(testCase,toc(elapsed),5);
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR'});
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('deleteCount'),1);
verifyFalse(testCase,isfile(fileName));
end

function testGonioConstructorKeepsConnectionAndMotionDeferred(testCase)
meter = colormeasure.drivers.cs2000.CS2000Gonio('SIM',[],0,[]);
cleanup = onCleanup(@()delete(meter));
verifyFalse(testCase,meter.isConnected());
verifyEmpty(testCase,meter.serialPort);
verifyEmpty(testCase,meter.stage);
verifyAligned(testCase,meter,0);
end

function testGonioPreflightRefusesBeforeStageMotion(testCase)
moves=0; stage=struct('PanTilt',@move,'Wait',@() []);
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',[],0,stage);
cleanup=onCleanup(@()delete(meter));
verifyError(testCase,@() meter.Measure({[0 10],[0 20]}),'CS2000:Disconnected');
verifyEqual(testCase,moves,0);
invalid={ {[0 10],0}, {NaN,0}, {1i,0}, {'a',0}, {[],[]}, ...
    {ones(2),ones(2)}, cell(2,2) };
for index=1:numel(invalid)
    verifyError(testCase,@() meter.Measure(invalid{index}),'CS2000:GonioDirections');
    verifyEqual(testCase,moves,0);
end
    function move(varargin)
        moves=moves+1;
    end
end

function testGonioPreflightRejectsUnverifiedSettingsBeforeMotion(testCase)
moves=0; stage=struct('PanTilt',@move,'Wait',@() []);
port=colormeasuretest.cs2000.Port();
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',[],0,stage,'Transport',port, ...
    'PortList',@() "SIM",'ResponseTimeout',0.05);
cleanup=onCleanup(@()delete(meter));
meter.Connect();port.queue('SPMS,2,1,2',sprintf('ER17\r\n'));
receipt=meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');verifyTrue(testCase,meter.isConnected());
commands=port.State('commands');
verifyError(testCase,@() meter.Measure({[0 10],[0 20]}),'CS2000:SettingsUnverified');
verifyEqual(testCase,moves,0);verifyEqual(testCase,port.State('commands'),commands);
    function move(varargin)
        moves=moves+1;
    end
end


function testGonioFailureRetainsPartialReadingsWithoutFurtherMotion(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(folder.Folder));
stage=colormeasuretest.cs2000.Stage();port=colormeasuretest.cs2000.Port();
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',stage,0,stage,'Transport',port, ...
    'PortList',@() "SIM",'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.Connect();
port.queue('MEAS,1',sprintf('OK00,002\r\nOK00\r\n'));
port.queue('MEAS,1',sprintf('ER10\r\n'));
verifyError(testCase,@()meter.Measure({[0 10 20],[0 5 10]}),'CS2000:InstrumentError');
verifyEqual(testCase,stage.Calls,{{'PanTilt',0,0},{'Wait'},{'PanTilt',10,5},{'Wait'}});
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'MEAS,1'),2);
verifyAligned(testCase,meter,1);
verifyFalse(testCase,meter.isSaved);
verifyFalse(testCase,isfile(fullfile(folder.Folder,'cs1.mat')));
commands=port.State('commands');
fileName=fullfile(folder.Folder,'partial.mat');
meter.Save(fileName);saved=load(fileName);
verifyEqual(testCase,saved.measurements.spectralData,meter.spectralData);
verifyEqual(testCase,saved.measurements.XYZData,meter.XYZData);
verifyEqual(testCase,saved.measurements.metadata,meter.metadata);
verifyEqual(testCase,port.State('commands'),commands);
verifyEqual(testCase,numel(stage.Calls),4);
meter.EraseAll();verifyAligned(testCase,meter,0);
end

function testGonioNewInstanceSkipsExistingSequenceAndKeepsItsBytes(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(folder.Folder));
sentinelFile=fullfile(folder.Folder,'cs1.mat');sentinel=uint8([17 23 41]);save(sentinelFile,'sentinel');
before=colormeasuretest.readBytes(sentinelFile);
stage=colormeasuretest.cs2000.Stage();port=colormeasuretest.cs2000.Port();
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',stage,0,stage,'Transport',port, ...
    'PortList',@() "SIM",'ResponseTimeout',0.05);testCase.addTeardown(@()delete(meter));
meter.Connect();names=meter.Measure({[0 10],[0 5]});
verifyEqual(testCase,names,{'cs2'});verifyEqual(testCase,colormeasuretest.readBytes(sentinelFile),before);
saved=load('cs2.mat');verifySize(testCase,saved.measurements.XYZData,[3 2]);
verifyEqual(testCase,numel(saved.measurements.metadata),2);
verifyAligned(testCase,meter,0);verifyEqual(testCase,meter.measurementTime,3);
verifyEmpty(testCase,dir(fullfile(folder.Folder,'*.part.mat')));
end

function testExclusivePublicationRefusesAnOccupiedPathAndRetainsHistory(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName=fullfile(folder.Folder,'cs1.mat');sentinel=uint8([13 29 47]);save(fileName,'sentinel');
before=colormeasuretest.readBytes(fileName);port=colormeasuretest.cs2000.Port();
meter=colormeasuretest.cs2000.ExclusiveSave('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));meter.Connect();meter.Measure();snapshot=meter.snapshot();
verifyError(testCase,@()meter.saveIfUnused(fileName),'CS2000:SaveFailed');
verifyEqual(testCase,colormeasuretest.readBytes(fileName),before);verifyEqual(testCase,meter.snapshot(),snapshot);
verifyFalse(testCase,meter.isSaved);verifyEmpty(testCase,dir(fullfile(folder.Folder,'*.part.mat')));
fresh=fullfile(folder.Folder,'cs2.mat');meter.saveIfUnused(fresh);
saved=load(fresh);verifyEqual(testCase,saved.measurements,snapshot);
verifyTrue(testCase,meter.isSaved);verifyEqual(testCase,colormeasuretest.readBytes(fileName),before);
verifyEqual(testCase,meter.snapshot(),snapshot);
verifyEmpty(testCase,dir(fullfile(folder.Folder,'*.part.mat')));
end

function testGonioSaveFailureKeepsCompleteHistoryAndCounter(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(folder.Folder));
stage=colormeasuretest.cs2000.Stage();port=colormeasuretest.cs2000.Port();
meter=colormeasuretest.cs2000.FailingGonioSave('SIM',stage,0,stage,'Transport',port, ...
    'PortList',@() "SIM",'ResponseTimeout',0.05);testCase.addTeardown(@()delete(meter));
meter.Connect();verifyError(testCase,@()meter.Measure({[0 10],[0 5]}),'cs2000test:SaveFailure');
verifyAligned(testCase,meter,2);verifyEqual(testCase,numel(meter.metadata),2);
verifyEqual(testCase,meter.measurementTime,1);verifyFalse(testCase,meter.isSaved);
verifyFalse(testCase,isfile('cs1.mat'));
verifyEqual(testCase,stage.Calls,{{'PanTilt',0,0},{'Wait'},{'PanTilt',10,5},{'Wait'}});
end

function testGonioSequenceMeasuresEachDirectionThenSavesAndClears(testCase)
% The success path: one reading per direction, the batch saved as cs<N> in
% the current folder with N counting up, and the history cleared for the
% next sequence. Homing moves the stage's first axis to the home position.
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(folder.Folder));
stage=colormeasuretest.cs2000.Stage();port=colormeasuretest.cs2000.Port();
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',stage,7,stage,'Transport',port, ...
    'PortList',@() "SIM",'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
verifyEqual(testCase,meter.measurementTime,1);verifyEqual(testCase,meter.homePosition,7);
meter.Connect();
names=meter.Measure({[0 10],[0 5]});
verifyEqual(testCase,names,{'cs1'});
verifyEqual(testCase,stage.Calls,{{'PanTilt',0,0},{'Wait'},{'PanTilt',10,5},{'Wait'}});
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'MEAS,1'),2);
saved=load(fullfile(folder.Folder,'cs1.mat'));
verifySize(testCase,saved.measurements.XYZData,[3 2]);verifySize(testCase,saved.measurements.spectralData,[401 2]);
verifyEqual(testCase,numel(saved.measurements.metadata),2);
verifyAligned(testCase,meter,0);verifyEqual(testCase,meter.measurementTime,2);
names=meter.Measure({20,15});
verifyEqual(testCase,names,{'cs2'});verifyTrue(testCase,isfile(fullfile(folder.Folder,'cs2.mat')));
verifyEqual(testCase,stage.Calls(5:6),{{'PanTilt',20,15},{'Wait'}});
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'MEAS,1'),3);
meter.MoveToHome();
verifyEqual(testCase,stage.Calls{end},{'Move',1,7});
verifyEqual(testCase,numel(stage.Calls),7);
end

function testGonioHomeRequiresAStageAndANumericHomePosition(testCase)
stage=colormeasuretest.cs2000.Stage();
meter=colormeasure.drivers.cs2000.CS2000Gonio('SIM',[],0,stage);
cleanup=onCleanup(@()delete(meter));
verifyError(testCase,@()meter.MoveToHome(),'CS2000:GonioStage');
verifyEmpty(testCase,stage.Calls);
verifyError(testCase,@()colormeasure.drivers.cs2000.CS2000Gonio('SIM',stage,'home',stage), ...
    'CS2000:GonioHome');
end

function testPreMeasurementDeadlineIsIndependentOfResponseTimeout(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase);
verifyEqual(testCase,meter.preMeasurementTimeout,35);
meter.Connect();
reply = sprintf('OK00,002\r\nOK00\r\n');
port.queue('MEAS,1',reply,numel(reply),0.15); % Exceeds ordinary 0.05 s timeout.
meter.Measure(); verifyAligned(testCase,meter,1);
verifyTrue(testCase,meter.isConnected());
other = colormeasure.drivers.cs2000.CS2000('SIM','PreMeasurementTimeout',45);
cleanup = onCleanup(@()delete(other));
verifyEqual(testCase,other.preMeasurementTimeout,45);
caught = false;
try
    colormeasure.drivers.cs2000.CS2000('SIM','PreMeasurementTimeout',34);
catch
    caught = true;
end
verifyTrue(testCase,caught);
end

function testDefaultConnectRejectsStaleInputWithoutCommands(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.inject(sprintf('OK00\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Connect(),'CS2000:PendingInput');
verifyEmpty(testCase,state('commands'));
verifyTrue(testCase,state('deleted'));
verifyFalse(testCase,meter.recoveryStatus.attempted);
end

function testOptInConnectDrainsAbandonedInputAndRecordsBytes(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Clock',colormeasuretest.FakeClock());
port.inject(sprintf('OK00,002\r\n'));
port.injectLater(sprintf('OK00\r\n'),0.01);
meter.Connect('DiscardPendingInput',true,'DrainQuietPeriod',0.03,'DrainTimeout',0.2);
verifyTrue(testCase,meter.recoveryStatus.attempted);
verifyTrue(testCase,meter.recoveryStatus.quietObserved);
verifyEqual(testCase,meter.recoveryStatus.discardedBytes,uint8(sprintf('OK00,002\r\nOK00\r\n')));
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0','DTCR'});
meter.Measure(); verifyAligned(testCase,meter,1);
end

function testOptInDrainCannotRunOnConnectedInstrument(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
port.inject(sprintf('OK00\r\n')); before = state('commands');
verifyError(testCase,@()meter.Connect('DiscardPendingInput',true),'CS2000:AlreadyConnected');
verifyEqual(testCase,state('commands'),before);
verifyFalse(testCase,meter.recoveryStatus.attempted);
verifyGreaterThan(testCase,port.NumBytesAvailable,0);
end

function testDrainDeadlineAndSizeLimitCloseWithoutCommands(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Clock',colormeasuretest.FakeClock());
for delay = 0:0.01:0.1, port.injectLater('x',delay); end
verifyError(testCase,@()meter.Connect('DiscardPendingInput',true, ...
    'DrainQuietPeriod',0.04,'DrainTimeout',0.06),'CS2000:DrainTimeout');
verifyEmpty(testCase,state('commands')); verifyTrue(testCase,state('deleted'));
verifyFalse(testCase,meter.recoveryStatus.quietObserved);
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase); port.inject(repmat('x',1,65537));
verifyError(testCase,@()meter.Connect('DiscardPendingInput',true),'CS2000:DrainLimit');
verifyEmpty(testCase,state('commands')); verifyTrue(testCase,state('deleted'));
end

function testDrainOptionsRejectImpossibleQuietWindowBeforeOpening(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
verifyError(testCase,@()meter.Connect('DiscardPendingInput',true, ...
    'DrainQuietPeriod',0.1,'DrainTimeout',0.1),'CS2000:DrainOptions');
verifyEmpty(testCase,state('commands')); verifyFalse(testCase,state('deleted'));
verifyFalse(testCase,meter.isConnected());
end

function testExtraInitializationReplyRejectsConnectedState(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('MSWE,0',sprintf('OK00\r\nOK00\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Connect(),'CS2000:PendingInput');
verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
end

function testCustomIdentityRequiresExplicitNameAndKnownVariation(testCase)
for variation = {'1','2'}
    port = colormeasuretest.cs2000.Port();
    meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'ExpectedModel','CUSTOM200');
    testCase.addTeardown(@()delete(meter));
    port.queue('IDDR',sprintf('OK00,CUSTOM200,%s,1234567\r\n',variation{1}));
    meter.Connect(); meter.Measure(); verifyAligned(testCase,meter,1);
    verifyEqual(testCase,meter.identity.model,'CUSTOM200');
end
for payload = {'CUSTOM200,9,1234567','CS-2000  ,2,1234567','CUSTOM201,1,1234567'}
    port = colormeasuretest.cs2000.Port(); state = port.State;
    meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',port,'ExpectedModel','CUSTOM200');
    testCase.addTeardown(@()delete(meter));
    port.queue('IDDR',sprintf('OK00,%s\r\n',payload{1}));
    verifyError(testCase,@()meter.Connect(),'CS2000:Identity');
    verifyTrue(testCase,state('deleted'));
end
end

function testRecoverablePayloadAndConditionsErrorsAllowNextReading(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
before = snapshot(meter);
port.queue('MEDR,1,0,2',sprintf('OK00,NaN\r\n'));
verifyError(testCase,@()meter.Measure(),'CS2000:NumericPayload');
verifyEqual(testCase,snapshot(meter),before);
verifyTrue(testCase,meter.isConnected());
for code = {'ER17','ER20'}
    port.queue('MEDR,0,0,1',sprintf('%s\r\n',code{1}));
    verifyError(testCase,@()meter.StoreMeasurementConditions(),'CS2000:InstrumentError');
    verifyEqual(testCase,snapshot(meter),before);
    verifyTrue(testCase,meter.isConnected());
end
meter.Measure(); verifyAligned(testCase,meter,2);
verifyFalse(testCase,state('deleted'));
end

function testExtraReplyAfterRecoverableErrorStillDisconnects(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
port.queue('MEAS,1',sprintf('ER10\r\nOK00\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:InstrumentError');
verifyTrue(testCase,state('deleted')); verifyAligned(testCase,meter,0);
end

function testAmbiguousBusyMeasurementErrorDisconnects(testCase)
for code = {'ER00','ER02','ER17'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
    port.queue('MEAS,1',sprintf('%s\r\n',code{1}));
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:InstrumentError');
    verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},'MEAS,1');
end
end

function testBacklightRecoveryMapTypesAreCheckedBeforeConnection(testCase)
invalid = {containers.Map('KeyType','double','ValueType','any'), ...
    containers.Map('KeyType','char','ValueType','double'), ...
    containers.Map(1234567,{[1 1]}),containers.Map({'1234567'},1),{},''};
for k = 1:numel(invalid)
    port = colormeasuretest.cs2000.Port();
    testCase.addTeardown(@()delete(port));
    verifyError(testCase,@()colormeasure.drivers.cs2000.CS2000('SIM', ...
        'Transport',port,'UnrestoredBacklight',invalid{k}), ...
        'MATLAB:InputParser:ArgumentFailedValidation');
    verifyEmpty(testCase,port.State('commands'));
end
end

function testMutatedBacklightRecoveryTargetIsRetainedAndRefused(testCase)
invalid = {[1 9],[1 NaN],[1 Inf],[1 1i],1,[1 1 1],'11',{1 1},[],struct()};
for k = 1:numel(invalid)
    owed = containers.Map('KeyType','char','ValueType','any');
    owed('1234567') = [1 1];
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'UnrestoredBacklight',owed);
    owed('1234567') = invalid{k}; % Mutable shared state changes after construction.
    port.queue('BALR',sprintf('OK00,1,0\r\n'));
    err = caughtConnect(meter);
    assertNotEmpty(testCase,err,'Connect must fail.');
    verifyEqual(testCase,err.identifier,'CS2000:Backlight');
    verifySubstring(testCase,err.message,'correct or remove that entry');
    verifyTrue(testCase,isKey(owed,'1234567'));
    verifyTrue(testCase,isequaln(owed('1234567'),invalid{k}));
    verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','BALR','RMTS,0'});
    verifyTrue(testCase,state('deleted'));
    verifyFalse(testCase,meter.isConnected());
    verifyAligned(testCase,meter,0);
end
end

function testBacklightRecoveryPreservesTheCurrentFirstSetting(testCase)
owed = containers.Map('KeyType','char','ValueType','any'); owed('1234567') = [1 1];
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'UnrestoredBacklight',owed);
port.queue('BALR',sprintf('OK00,0,0\r\n'));
meter.Connect(); meter.Disconnect();
commands = state('commands');
verifyEqual(testCase,commands(end-1:end),{'BALS,0,1','RMTS,0'});
verifyTrue(testCase,meter.cleanupStatus.backlightRestored);
verifyEmpty(testCase,owed.keys);
end

function testUncertainStopBacklightIsRestoredByTheNextConnection(testCase)
% ER02 leaves the during-measurement flag off. The next driver for the same
% instrument restores the earlier original instead of adopting that leftover.
[meter,port,~] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
port.queue('MEAS,1',sprintf('ER02\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),'CS2000:InstrumentError');
owed = meter.unrestoredBacklight;
verifyEqual(testCase,owed.keys,{'1234567'}); verifyEqual(testCase,owed('1234567'),[1 1]);
[next,port,state] = colormeasuretest.cs2000.instrument(testCase,'UnrestoredBacklight',owed);
port.queue('BALR',sprintf('OK00,1,0\r\n'));
next.Connect(); next.Measure();
verifyFalse(testCase,any(startsWith(state('commands'),'BALS,')));
backlight = next.metadata(1).acquisition.backlight;
verifyEqual(testCase,backlight.originalSettings,[1 1]);
verifyEqual(testCase,backlight.originalResponse,'OK00,1,0');
next.Disconnect();
commands = state('commands'); verifyEqual(testCase,commands(end-1:end),{'BALS,1,1','RMTS,0'});
verifyTrue(testCase,next.cleanupStatus.backlightRestored);
verifyEmpty(testCase,owed.keys);
end

function testOwedBacklightWaitsForItsOwnInstrument(testCase)
owed = containers.Map('KeyType','char','ValueType','any'); owed('7654321') = [1 1];
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'UnrestoredBacklight',owed);
port.queue('BALR',sprintf('OK00,1,0\r\n'));
meter.Connect(); meter.Disconnect();
verifyFalse(testCase,any(startsWith(state('commands'),'BALS,')));
verifyEqual(testCase,owed.keys,{'7654321'});
% Switched back on at the instrument meanwhile: the ordinary change and restore.
owed('1234567') = [1 1];
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase,'UnrestoredBacklight',owed);
meter.Connect(); meter.Disconnect();
commands = state('commands');
verifyEqual(testCase,nnz(strcmp(commands,'BALS,1,0')),1);
verifyEqual(testCase,commands(end-1:end),{'BALS,1,1','RMTS,0'});
verifyEqual(testCase,owed.keys,{'7654321'});
end

function testBusyConditionsQueryDisconnectsWithoutSettingCommands(testCase)
for code = {'ER00','ER02'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
    before = snapshot(meter);
    port.queue('MEDR,0,0,1',sprintf('%s\r\n',code{1}));
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.StoreMeasurementConditions(),'CS2000:InstrumentError');
    verifyEqual(testCase,snapshot(meter),before);
    verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},'MEDR,0,0,1');
    verifyFalse(testCase,meter.cleanupStatus.backlightRestored);
    verifyFalse(testCase,meter.cleanupStatus.remoteReleased);
end
end

function testBusyManualSpectrumDoesNotSendSpeedRestoration(testCase)
for code = {'ER00','ER02'}
    port = colormeasuretest.cs2000.Port(); state = port.State;
    meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
    testCase.addTeardown(@()delete(meter)); meter.Connect();
    port.queue('MEDR,1,0,1',sprintf('%s\r\n',code{1}));
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
    verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},'MEDR,1,0,1');
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,meter.cleanupStatus.speedRestored);
end
end

function testAmbiguousManualMEASDoesNotSendSpeedRestoration(testCase)
for reply = {sprintf('ER00\r\n'),sprintf('OK00,002\r\nER00\r\n')}
    port = colormeasuretest.cs2000.Port(); state = port.State;
    meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
    testCase.addTeardown(@()delete(meter)); meter.Connect();
    port.queue('MEAS,1',reply{1});
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
    verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},'MEAS,1');
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,meter.cleanupStatus.speedRestored);
end
end

function testAmbiguousManualSpeedCommandsDoNotSendRestoration(testCase)
for command = {'SPMR','SPMS,3,002000000,0'}
    port = colormeasuretest.cs2000.Port(); state = port.State;
    meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
    testCase.addTeardown(@()delete(meter)); meter.Connect();
    port.queue(command{1},sprintf('ER00\r\n'));
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
    verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},command{1});
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,meter.cleanupStatus.backlightRestored);
    verifyFalse(testCase,meter.cleanupStatus.remoteReleased);
end
end

function testManualRecoverableErrorRestoresSpeedWithoutDisconnect(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.Connect(); port.queue('MEAS,1',sprintf('ER10\r\n'));
verifyError(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
verifyTrue(testCase,meter.isConnected()); verifyFalse(testCase,state('deleted'));
commands = state('commands'); verifyEqual(testCase,commands{end},'SPMS,0,2');
verifyAligned(testCase,meter,0);
meter.MeasureManual(); verifyAligned(testCase,meter,1);
end

function testExtraManualRestoreReplyAfterErrorDisconnects(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000manual('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(meter));
meter.Connect(); port.queue('MEAS,1',sprintf('ER10\r\n'));
port.queue('SPMS,0,2',sprintf('OK00\r\nOK00\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
verifyFalse(testCase,meter.isConnected()); verifyTrue(testCase,state('deleted'));
verifyAligned(testCase,meter,0);
end

function testErasePreservesExplicitConditionsQueryIncludingRoundTrip(testCase)
[meter,~] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
% Even an equal-valued query has a separate provenance from the retained row.
queried = meter.StoreMeasurementConditions();
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
meter.Save(fileName);
[archive,~] = colormeasuretest.cs2000.instrument(testCase); archive.Load(fileName);
archive.Erase(); meter.Erase();
verifyEqual(testCase,meter.measurementConditions,queried);
verifyEqual(testCase,archive.measurementConditions,queried);
verifyAligned(testCase,meter,0); verifyAligned(testCase,archive,0);
meter.EraseAll(); verifyEqual(testCase,meter.measurementConditions,struct());
end

function testPublicSnapshotIsOfflineValueOnlyAndKeepsSaveState(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
before = meter.snapshot();
verifySize(testCase,before.spectralData,[401 0]);
verifySize(testCase,before.XYZData,[3 0]);
verifyEmpty(testCase,before.metadata);
verifyFalse(testCase,before.measurementConditionsIndependent);
verifyFalse(testCase,meter.isSaved);
copy = before; copy.identity = struct('model','local copy only');
verifyNotEqual(testCase,copy.identity,before.identity);
verifyEqual(testCase,meter.snapshot(),before);
verifyFalse(testCase,meter.isConnected());
verifyEmpty(testCase,state('commands'));
end

function testPublicSnapshotMatchesSaveLoadAndIndependentConditions(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); meter.StoreMeasurementConditions();
commands = state('commands'); before = meter.snapshot();
verifyTrue(testCase,before.measurementConditionsIndependent);
verifyFalse(testCase,meter.isSaved);
verifyEqual(testCase,state('commands'),commands);
copy = before; copy.spectralData(1,1) = copy.spectralData(1,1)+1;
verifyNotEqual(testCase,copy.spectralData,before.spectralData);
verifyEqual(testCase,meter.snapshot(),before);
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'native snapshot.mat');
meter.Save(fileName);
verifyTrue(testCase,meter.isSaved);
verifyEqual(testCase,meter.snapshot(),before);
verifyTrue(testCase,meter.isSaved);
saved = load(fileName);
verifyEqual(testCase,sort(fieldnames(saved)),{'measurements'});
verifyEqual(testCase,saved.measurements,before);
verifyEqual(testCase,saved.measurements.spectralData,before.spectralData);
verifyEqual(testCase,saved.measurements.XYZData,before.XYZData);
verifyEqual(testCase,saved.measurements.measurementConditions,before.measurementConditions);
[archive,~,offline] = colormeasuretest.cs2000.instrument(testCase);
archive.Load(fileName); loaded = archive.snapshot();
verifyEqual(testCase,loaded.spectralData,before.spectralData);
verifyEqual(testCase,loaded.XYZData,before.XYZData);
verifyEqual(testCase,loaded.metadata,before.metadata);
verifyTrue(testCase,loaded.measurementConditionsIndependent);
archive.Erase();
verifyEqual(testCase,archive.measurementConditions,before.measurementConditions);
verifyAligned(testCase,archive,0);
verifyFalse(testCase,archive.isConnected());
verifyEmpty(testCase,offline('commands'));
end

function testSaveOnDeleteWritesAnUnsavedHistoryOrWarns(testCase)
% Off by default. On, an unsaved history is written to a temporary MAT when
% the driver is deleted and the path is printed; nothing is written for a
% saved or empty history; a failed write becomes CS2000:AutoSave.
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[meter,~,~] = colormeasuretest.cs2000.instrument(testCase);
verifyFalse(testCase,meter.saveOnDelete);
meter.Connect(); meter.Measure(); verifyFalse(testCase,meter.isSaved);
meter.saveOnDelete = true; expected = snapshot(meter);
output = evalc('delete(meter)');
fileName = regexp(output,'Measurements saved to (.+?\.mat)\s*$','tokens','once','lineanchors');
assertNotEmpty(testCase,fileName,'The automatic save must announce its file.');
testCase.addTeardown(@()delete(fileName{1}));
saved = load(fileName{1});
verifyEqual(testCase,saved.measurements.XYZData,expected.XYZData);
verifyEqual(testCase,saved.measurements.spectralData,expected.spectralData);
verifyEqual(testCase,saved.measurements.metadata,expected.metadata);
[meter,~,~] = colormeasuretest.cs2000.instrument(testCase);
meter.Connect(); meter.Measure(); meter.Save(fullfile(folder.Folder,'kept.mat'));
meter.saveOnDelete = true;
verifyEmpty(testCase,evalc('delete(meter)'));
[meter,~,~] = colormeasuretest.cs2000.instrument(testCase); meter.saveOnDelete = true;
verifyEmpty(testCase,evalc('delete(meter)'));
port = colormeasuretest.cs2000.Port();
failing = colormeasuretest.cs2000.FailingSave('SIM','Transport',port,'ResponseTimeout',0.05);
testCase.addTeardown(@()delete(failing));
failing.Connect(); failing.Measure(); failing.saveOnDelete = true;
verifyWarning(testCase,@()delete(failing),'CS2000:AutoSave');
end

function testPreparationIsStandaloneReadOnlyGuidance(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase);
before = meter.snapshot();
info = colormeasure.drivers.cs2000.preparation();
verifyTrue(testCase,isstruct(info) && isscalar(info));
verifyTrue(testCase,all(isfield(info,{'title','summary','details','url','required'})));
verifyTrue(testCase,ischar(info.title) && isrow(info.title) && ~isempty(info.title));
verifyTrue(testCase,ischar(info.summary) && isrow(info.summary) && ~isempty(info.summary));
verifyTrue(testCase,iscellstr(info.details) && ~isempty(info.details));
verifyTrue(testCase,iscellstr(info.headings));
verifyEqual(testCase,numel(info.headings),numel(info.details));
verifyTrue(testCase,all(~cellfun(@isempty,info.headings)));
verifyTrue(testCase,ischar(info.url) && startsWith(info.url,'https://www.konicaminolta.com/'));
verifyEqual(testCase,info.required,true);
info.required = false;
fresh = colormeasure.drivers.cs2000.preparation(); verifyTrue(testCase,fresh.required);
verifyFalse(testCase,info.required);
info.headings{1} = 'Changed copy';
verifyNotEqual(testCase,fresh.headings{1},info.headings{1});
verifyEqual(testCase,meter.snapshot(),before);
verifyFalse(testCase,meter.isConnected());
verifyFalse(testCase,meter.isSaved);
verifyEmpty(testCase,state('commands'));
end

function err = connectFailure(testCase,meter,identifier)
% Connect must fail with the identifier and, having closed the port before
% restoration could be confirmed, warn CS2000:CleanupUnverified; the
% exception comes back so the message text is pinned as well.
err = verifyWarning(testCase,@() caughtConnect(meter),'CS2000:CleanupUnverified');
assertNotEmpty(testCase,err,'Connect must fail.');
verifyEqual(testCase,err.identifier,identifier);
end

function err = caughtConnect(meter)
err = [];
try
    meter.Connect();
catch err
end
end




function verifyCSFailure(testCase,action,expected)
% The action must fail with the named driver identifier; in particular,
% unexpected-command failures from the fake are not accepted.
identifier = '';
try
    action();
catch err
    identifier = err.identifier;
end
verifyEqual(testCase,identifier,expected);
end

function data = snapshot(meter)
data = struct('spectralData',meter.spectralData,'XYZData',meter.XYZData, ...
    'metadata',meter.metadata,'measurementConditions',meter.measurementConditions);
end

function verifyAligned(testCase,meter,count)
verifySize(testCase,meter.spectralData,[401 count]);
verifySize(testCase,meter.XYZData,[3 count]);
verifyEqual(testCase,numel(meter.metadata),count);
end



function testDecimalUnderflowDoesNotBecomeAMeasuredZero(testCase)
colormeasuretest.verifyDecimalValues(testCase,@colormeasure.drivers.cs2000.numbers,'CS2000');
end

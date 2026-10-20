function tests = testCS2000Metadata
% Metadata protocol fixtures only; no enumeration or real serial transport.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testIdentityCalibrationAndBacklightAreRetained(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('IDDR',sprintf('OK00,CS-2000  ,1,0000042\r\n'));
port.queue('DTCR',sprintf('OK00,20240229,010203\r\n'));
port.queue('BALR',sprintf('OK00,0,1\r\n'));
meter.Connect(); meter.Measure(); meter.Measure();
verifyEqual(testCase,meter.identity.serialNumber,'0000042');
verifyEmpty(testCase,meter.identity.firmware);
calibration = meter.metadata(1).identity.factoryCalibration;
verifyEqual(testCase,calibration.date,'20240229');
verifyEqual(testCase,calibration.status,'available');
verifyEqual(testCase,calibration.time,'010203');
verifyEqual(testCase,calibration.dateTime,datetime(2024,2,29,1,2,3));
verifyEmpty(testCase,calibration.dateTime.TimeZone);
verifyEqual(testCase,calibration.queriedAt.TimeZone,'UTC');
verifyEqual(testCase,calibration.response,'OK00,20240229,010203');
verifyEqual(testCase,sum(strcmp(state('commands'),'DTCR')),1);
backlight = meter.metadata(1).acquisition.backlight;
verifyEqual(testCase,backlight.originalSettings,[0 1]);
verifyEqual(testCase,backlight.originalResponse,'OK00,0,1');
verifyEqual(testCase,backlight.commandedSettings,[0 0]);
verifyEqual(testCase,meter.metadata(2).identity.factoryCalibration,calibration);
end

function testCalibrationDateRejectsImpossibleCalendarAndTime(testCase)
for payload = {'20230229,120000','19000229,120000','20241301,120000', ...
        '20240001,120000','20240431,120000','20240100,120000', ...
        '20240101,240000','20240101,126000','20240101,120060', ...
        '00000101,120000','20240101,12000','20240101,120000,0','NaN,120000'}
    verifyError(testCase,@()colormeasure.drivers.cs2000.calibrationDate(payload{1}),'CS2000:CalibrationDate');
end
value = colormeasure.drivers.cs2000.calibrationDate('20000229,235959');
verifyEqual(testCase,value.dateTime,datetime(2000,2,29,23,59,59));
end

function testInvalidCalibrationIsUnparsedAndConnectRemainsUsable(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
port.queue('DTCR',sprintf('OK00,20230229,120000\r\n'));
meter.Connect();
value = meter.identity.factoryCalibration;
verifyEqual(testCase,value.status,'unparsed');
verifyEqual(testCase,value.response,'OK00,20230229,120000');
verifyEqual(testCase,value.errorIdentifier,'CS2000:CalibrationDate');
verifyEmpty(testCase,value.date); verifyEmpty(testCase,value.time);
verifyTrue(testCase,isnat(value.dateTime));
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0','DTCR'});
meter.Measure(); verifyEqual(testCase,meter.metadata(1).identity.factoryCalibration,value);
verifyTrue(testCase,meter.isConnected());
end

function testCalibrationBusyAndTimeoutDoNotSendCleanup(testCase)
for reply = {sprintf('ER00\r\n'),sprintf('ER02\r\n'),''}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    port.queue('DTCR',reply{1});
    identifier = 'CS2000:InstrumentError';
    if isempty(reply{1}), identifier = 'CS2000:Timeout'; end
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Connect(),identifier);
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0','DTCR'});
end
end

function testPreMeasurementSettingsRemainDistinctFromExposure(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
port.queue('SCMR',sprintf('OK00,1,05994\r\n'));
port.queue('SPMR',sprintf('OK00,4,16,2\r\n'));
port.queue('OBSR',sprintf('OK00,1\r\n'));
port.queue('MEDR,0,0,1',sprintf('OK00,4,1,001234567,1,1,2,1,00\r\n'));
meter.Measure(); acquisition = meter.metadata(1).acquisition;
settings = acquisition.configurationBefore;
verifyEqual(testCase,settings.sync.syncMode,1);
verifyEqual(testCase,settings.sync.frequencyHz,59.94,'AbsTol',1e-12);
verifyEqual(testCase,settings.sync.response,'OK00,1,05994');
verifyEqual(testCase,settings.speed.integrationTimeSeconds,16);
verifyEqual(testCase,settings.speed.internalNDMode,2);
verifyEqual(testCase,settings.observerMetadata.value,1);
verifyFalse(testCase,any(isfield(settings,{'instrumentObserverSetting','observerResponse'})));
verifyFalse(testCase,isfield(acquisition,'identity'));
verifyEqual(testCase,meter.metadata.identity,meter.identity);
verifyEqual(testCase,acquisition.observer,0);
verifyEqual(testCase,meter.measurementConditions.observer,0);
verifyEqual(testCase,meter.measurementConditions.integrationTime,1.234567,'AbsTol',1e-12);
verifyEqual(testCase,meter.measurementConditions.internalNDFilter,1);
verifyEqual(testCase,meter.measurementConditions.measurementAngle,1);
verifyEqual(testCase,meter.measurementConditions.measurementAngleDegrees,0.2);
verifyEqual(testCase,settings.queriedAt.TimeZone,'UTC');
commands = state('commands'); begin = find(strcmp(commands,'MEAS,1'));
verifyEqual(testCase,commands(begin-3:begin-1),{'SCMR','SPMR','OBSR'});
end

function testSyncModesAndBoundaryFrequencies(testCase)
for mode = [0 2]
    value = colormeasure.drivers.cs2000.syncSettings(sprintf('%d',mode));
    verifyEqual(testCase,value.syncMode,mode); verifyTrue(testCase,isnan(value.frequencyHz));
end
for frequency = [2000 20000]
    value = colormeasure.drivers.cs2000.syncSettings(sprintf('1,%05d',frequency));
    verifyEqual(testCase,value.frequencyHz,frequency/100);
end
for payload = {'0,6000','2,6000','1','1,1999','1,20001','1,6000,0','1,6000.5','3','-1'}
    verifyError(testCase,@()colormeasure.drivers.cs2000.syncSettings(payload{1}),'CS2000:SyncMode');
end
verifyError(testCase,@()colormeasure.drivers.cs2000.syncSettings('1,NaN'),'CS2000:NumericPayload');
end

function testSpeedMetadataHandlesLegacyAndCurrentLayouts(testCase)
payloads = {'0','1','2,01','0,0','1,2','2,16,1','4,01,2','3,000005000,0','3,120000000,1'};
times = [NaN NaN 1 NaN NaN 16 1 0.005 120];
nd = [2 2 2 0 2 1 2 0 1];
for k = 1:numel(payloads)
    [command,value] = colormeasure.drivers.cs2000.speedCommand(payloads{k});
    verifyTrue(testCase,startsWith(command,'SPMS,'));
    verifyEqual(testCase,value.integrationTimeSeconds,times(k));
    verifyEqual(testCase,value.internalNDMode,nd(k));
    source = 'reported'; if k <= 3, source = 'protocol-fixed-auto'; end
    verifyEqual(testCase,value.internalNDModeSource,source);
end
end

function testModernModeFourRequiresNDAndManualBounds(testCase)
for payload = {'4,1','4,16','4,0,2','4,17,2','4,1,3','3,4999,0','3,120000001,0','3,5000,2'}
    verifyError(testCase,@()colormeasure.drivers.cs2000.speedCommand(payload{1}),'CS2000:SpeedMode');
end
end

function testCS2000AShortOptionalSpeedSnapshotIsUnparsed(testCase)
for payload = {'0','1','2,01'}
    [meter,port,state] = instrumentForVariationTwo(testCase,false,false);
    meter.Connect(); port.queue('SPMR',sprintf('OK00,%s\r\n',payload{1}));
    meter.Measure();
    value = meter.metadata(1).acquisition.configurationBefore.speed;
    verifyEqual(testCase,value.status,'unparsed');
    verifyEqual(testCase,value.errorIdentifier,'CS2000:SpeedMode');
    verifyTrue(testCase,isnan(value.speedMode));
    verifyEqual(testCase,sum(strcmp(state('commands'),'MEAS,1')),1);
    verifyTrue(testCase,meter.isConnected());
end
end

function testCS2000AShortManualRestoreSettingsAreRejected(testCase)
for payload = {'0','1','2,01'}
    [meter,port,state] = instrumentForVariationTwo(testCase,true,false);
    meter.Connect(); port.queue('SPMR',sprintf('OK00,%s\r\n',payload{1}));
    verifyError(testCase,@()meter.MeasureManual(),'CS2000:SpeedMode');
    verifyTrue(testCase,meter.isConnected()); verifyEmpty(testCase,meter.metadata);
    verifyFalse(testCase,any(startsWith(state('commands'),{'SPMS,','MEAS,'})));
    meter.MeasureManual(); verifyEqual(testCase,numel(meter.metadata),1);
end
end

function testCustomVariationTwoKeepsManualRestoreStrict(testCase)
[meter,port,state] = instrumentForVariationTwo(testCase,true,true);
meter.Connect(); port.queue('SPMR',sprintf('OK00,2,01\r\n'));
verifyError(testCase,@()meter.MeasureManual(),'CS2000:SpeedMode');
verifyEmpty(testCase,meter.metadata);
verifyFalse(testCase,any(startsWith(state('commands'),{'SPMS,','MEAS,'})));
port.queue('SPMR',sprintf('OK00,2,01\r\n')); meter.Measure();
verifyEqual(testCase,meter.metadata(1).acquisition.configurationBefore.speed.status,'unparsed');
end

function testCS2000AModernSettingsSupportNormalAndManualCapture(testCase)
[meter,port,~] = instrumentForVariationTwo(testCase,true,false);
meter.Connect(); port.queue('SPMR',sprintf('OK00,2,01,2\r\n'));
meter.Measure(); meter.MeasureManual();
verifyEqual(testCase,numel(meter.metadata),2);
first = meter.metadata(1).acquisition.configurationBefore.speed;
verifyEqual(testCase,first.speedMode,2); verifyEqual(testCase,first.internalNDMode,2);
verifyEqual(testCase,first.internalNDModeSource,'reported');
second = meter.metadata(2).acquisition.configurationBefore.speed;
verifyEqual(testCase,second.speedMode,3);
verifyEqual(testCase,second.internalNDModeSource,'reported');
end

function testSettingsSnapshotsDoNotOverwriteOlderRows(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = meter.metadata(1);
port.queue('SCMR',sprintf('OK00,2\r\n'));
port.queue('SPMR',sprintf('OK00,1,1\r\n'));
meter.Measure();
verifyEqual(testCase,meter.metadata(1),before);
verifyEqual(testCase,meter.metadata(2).acquisition.configurationBefore.sync.syncMode,2);
verifyEqual(testCase,meter.metadata(2).acquisition.configurationBefore.speed.speedMode,1);
end

function testMalformedOptionalSettingsRetainReadingAndRawDiagnostics(testCase)
commands = {'SCMR','SPMR','OBSR'};
payloads = {'1,1999','4,01','2'};
fields = {'sync','speed','observerMetadata'};
identifiers = {'CS2000:SyncMode','CS2000:SpeedMode','CS2000:Observer'};
for k = 1:numel(commands)
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = meter.metadata(1);
    port.queue(commands{k},sprintf('OK00,%s\r\n',payloads{k}));
    meter.Measure(); value = meter.metadata(2).acquisition.configurationBefore.(fields{k});
    verifyEqual(testCase,meter.metadata(1),before);
    verifyEqual(testCase,value.status,'unparsed');
    verifyEqual(testCase,value.response,['OK00,' payloads{k}]);
    verifyEqual(testCase,value.errorIdentifier,identifiers{k});
    verifyNotEmpty(testCase,value.errorMessage);
    verifyEqual(testCase,sum(strcmp(state('commands'),'MEAS,1')),2);
    verifyTrue(testCase,meter.isConnected());
end
end

function testUndocumentedOptionalQueryErrorsAreNotSwallowed(testCase)
for command = {'DTCR','SCMR','SPMR','OBSR'}
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
    if ~strcmp(command{1},'DTCR'), meter.Connect(); end
    port.queue(command{1},sprintf('ER17\r\n'));
    action = @()meter.Measure(); if strcmp(command{1},'DTCR'), action = @()meter.Connect(); end
    verifyError(testCase,action,'CS2000:InstrumentError');
    verifyEmpty(testCase,meter.metadata);
    verifyFalse(testCase,any(strcmp(state('commands'),'MEAS,1')));
end
end

function testOptionalMalformedFramesAndPendingInputRemainFatal(testCase)
for command = {'DTCR','SCMR','SPMR','OBSR'}
    for reply = {sprintf('broken\r\n'),sprintf('ER17,extra\r\n'),sprintf('OK00,9\r\nOK00\r\n')}
        [meter,port,state] = colormeasuretest.cs2000.instrument(testCase);
        if ~strcmp(command{1},'DTCR'), meter.Connect(); end
        port.queue(command{1},reply{1});
        action = @()meter.Measure(); if strcmp(command{1},'DTCR'), action = @()meter.Connect(); end
        identifier = 'CS2000:Framing';
        if startsWith(reply{1},'OK00'), identifier = 'CS2000:PendingInput'; end
        colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,action,identifier);
        verifyEmpty(testCase,meter.metadata); verifyTrue(testCase,state('deleted'));
        commands = state('commands'); verifyEqual(testCase,commands{end},command{1});
    end
end
end

function testSettingsBusyAndTimeoutStopAllCommands(testCase)
for command = {'SCMR','SPMR','OBSR'}
    for reply = {sprintf('ER00\r\n'),sprintf('ER02\r\n'),''}
        [meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = snapshot(meter);
        port.queue(command{1},reply{1});
        identifier = 'CS2000:InstrumentError';
        if isempty(reply{1}), identifier = 'CS2000:Timeout'; end
        colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),identifier);
        verifyEqual(testCase,snapshot(meter),before);
        verifyTrue(testCase,state('deleted'));
        commands = state('commands'); verifyEqual(testCase,commands{end},command{1});
        verifyEqual(testCase,sum(strcmp(commands,'MEAS,1')),1);
    end
end
end

function testMetadataFragmentationAndDelayedReplies(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase,'Clock',colormeasuretest.FakeClock());
reply = sprintf('OK00,20000229,235959\r\n');
port.queue('DTCR',reply,[3 numel(reply)-4 1],[0 0.01 0.02]);
meter.Connect();
reply = sprintf('OK00,1,20000\r\n');
port.queue('SCMR',reply,[1 numel(reply)-2 1],[0 0.01 0.02]);
port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,01\r\n'));
reply = sprintf('OK00,Monitor A \r\n');
port.queue('UCPR,2,01',reply,[5 numel(reply)-6 1],[0 0.01 0.02]);
meter.Measure();
verifyEqual(testCase,meter.metadata(1).acquisition.configurationBefore.sync.frequencyHz,200);
verifyEqual(testCase,meter.metadata(1).acquisition.userCalibration.name,'Monitor A');
end

function testFactoryChannelDoesNotQueryUserName(testCase)
[meter,~,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure();
value = meter.metadata(1).acquisition.userCalibration;
verifyEqual(testCase,value.channel,0); verifyEqual(testCase,value.status,'factory-standard');
verifyEmpty(testCase,value.name); verifyEmpty(testCase,value.response);
verifyTrue(testCase,isnat(value.queriedAt));
verifyFalse(testCase,any(startsWith(state('commands'),'UCPR,')));
end

function testSelectedChannelNameAndMissingValuesAreRetained(testCase)
for reply = {sprintf('OK00,Monitor A \r\n'),sprintf('ER05\r\n')}
    [meter,port] = colormeasuretest.cs2000.instrument(testCase); meter.Connect();
    port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,2,10\r\n'));
    port.queue('UCPR,2,10',reply{1}); meter.Measure();
    value = meter.metadata(1).acquisition.userCalibration;
    verifyEqual(testCase,value.channel,10);
    verifyEqual(testCase,value.queriedAt.TimeZone,'UTC');
    if startsWith(reply{1},'OK00')
        verifyEqual(testCase,value.status,'available'); verifyEqual(testCase,value.name,'Monitor A');
        verifyEqual(testCase,value.response,'OK00,Monitor A ');
    else
        verifyEqual(testCase,value.status,'no-compensation-values'); verifyEmpty(testCase,value.name);
        verifyEqual(testCase,value.response,'ER05');
    end
    verifyTrue(testCase,meter.isConnected());
    verifyEqual(testCase,meter.measurementConditions.measurementAngleDegrees,0.1);
end
end

function testUserNameParseAndDocumentedErrorsRetainCompletedReading(testCase)
for reply = {sprintf('OK00,short\r\n'),sprintf('ER17\r\n'), ...
        sprintf('ER30\r\n'),sprintf('ER32\r\n'),sprintf('ER34\r\n')}
    [meter,port] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = meter.metadata(1);
    port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,01\r\n'));
    port.queue('UCPR,2,01',reply{1}); meter.Measure();
    value = meter.metadata(2).acquisition.userCalibration;
    if startsWith(reply{1},'OK00')
        verifyEqual(testCase,value.status,'unparsed');
        verifyEqual(testCase,value.errorIdentifier,'CS2000:CalibrationName');
    else
        verifyEqual(testCase,value.status,'unavailable');
        verifyEqual(testCase,value.errorCode,strtrim(reply{1}));
    end
    verifyEqual(testCase,value.response,strtrim(reply{1})); verifyEmpty(testCase,value.name);
    verifyEqual(testCase,meter.metadata(1),before); verifyTrue(testCase,meter.isConnected());
end
end

function testUserNameUnknownErrorStillRejectsReading(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = snapshot(meter);
port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,01\r\n'));
port.queue('UCPR,2,01',sprintf('ER99\r\n'));
verifyError(testCase,@()meter.Measure(),'CS2000:InstrumentError');
verifyEqual(testCase,snapshot(meter),before); verifyTrue(testCase,meter.isConnected());
end

function testUserNameBusyTimeoutAndExtraErrorPayloadStopCleanup(testCase)
replies = {sprintf('ER00\r\n'),sprintf('ER02\r\n'),'', ...
    sprintf('ER05,unexpected\r\n'),sprintf('ER05\r\nOK00\r\n')};
identifiers = {'CS2000:InstrumentError','CS2000:InstrumentError','CS2000:Timeout', ...
    'CS2000:Framing','CS2000:PendingInput'};
for k = 1:numel(replies)
    [meter,port,state] = colormeasuretest.cs2000.instrument(testCase); meter.Connect(); meter.Measure(); before = snapshot(meter);
    port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,01\r\n'));
    port.queue('UCPR,2,01',replies{k});
    colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.Measure(),identifiers{k});
    verifyEqual(testCase,snapshot(meter),before); verifyTrue(testCase,state('deleted'));
    commands = state('commands'); verifyEqual(testCase,commands{end},'UCPR,2,01');
end
end

function testManualSnapshotUsesTemporaryModeAndRestoresOriginal(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Manual',true); meter.integrationTime = 0.025;
port.queue('MEDR,0,0,1',sprintf('OK00,3,0,000025000,0,0,0,0,00\r\n'));
meter.Connect(); meter.MeasureManual();
value = meter.metadata(1).acquisition;
verifyEqual(testCase,value.manualIntegrationTimeRequestedSeconds,0.025);
verifyFalse(testCase,isfield(value,'integrationTimeRequestedSeconds'));
verifyEqual(testCase,value.configurationBefore.speed.speedMode,3);
verifyEqual(testCase,value.configurationBefore.speed.integrationTimeSeconds,0.025);
verifyEqual(testCase,meter.metadata(1).conditions.integrationTime,0.025);
verifyEqual(testCase,value.conditionsResponse,'OK00,3,0,000025000,0,0,0,0,00');
verifyEqual(testCase,value.configurationBefore.speed.internalNDMode,0);
verifyEqual(testCase,value.speedBeforeResponse,'OK00,0,2');
verifyEqual(testCase,value.speedRestoreResponse,'OK00');
commands = state('commands'); verifyEqual(testCase,commands{end},'SPMS,0,2');
end

function testOrdinaryManualModeHasNoTemporaryManualRequest(testCase)
clock=colormeasuretest.FakeClock();
[meter,port]=colormeasuretest.cs2000.instrument(testCase,'Clock',clock);
meter.Connect();port.State('speedPayload')='3,25000,0';
port.queue('MEDR,0,0,1',sprintf('OK00,3,0,000025000,0,0,0,0,00\r\n'));
meter.Measure();
value=meter.metadata(1);
verifyTrue(testCase,isnan(value.acquisition.manualIntegrationTimeRequestedSeconds));
verifyEqual(testCase,value.acquisition.configurationBefore.speed.integrationTimeSeconds,0.025);
verifyEqual(testCase,value.conditions.integrationTime,0.025);
verifyEmpty(testCase,value.acquisition.speedBeforeResponse);
verifyEmpty(testCase,value.acquisition.speedRestoreResponse);
end

function testManualOptionalMetadataParseFailureStillRestoresAndCommits(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Manual',true); meter.Connect();
port.queue('SCMR',sprintf('OK00,9\r\n'));
meter.MeasureManual();
verifyTrue(testCase,meter.isConnected()); verifyEqual(testCase,numel(meter.metadata),1);
verifyEqual(testCase,meter.metadata(1).acquisition.configurationBefore.sync.status,'unparsed');
commands = state('commands'); verifyEqual(testCase,commands{end},'SPMS,0,2');
verifyEqual(testCase,sum(strcmp(commands,'MEAS,1')),1);
end

function testManualMetadataBusySkipsSpeedAndBacklightRestoration(testCase)
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Manual',true); meter.Connect();
port.queue('SCMR',sprintf('ER02\r\n'));
colormeasuretest.cs2000.failsAndLeavesCleanupUnverified(testCase,@()meter.MeasureManual(),'CS2000:InstrumentError');
verifyTrue(testCase,state('deleted')); verifyEmpty(testCase,meter.metadata);
commands = state('commands'); verifyEqual(testCase,commands{end},'SCMR');
verifyFalse(testCase,meter.cleanupStatus.speedRestored);
verifyFalse(testCase,meter.cleanupStatus.backlightRestored);
end

function testMetadataRoundTripPreservesValuesAndIndependentConditions(testCase)
[meter,port] = colormeasuretest.cs2000.instrument(testCase);
port.queue('DTCR',sprintf('OK00,bad\r\n')); meter.Connect();
port.queue('SCMR',sprintf('OK00,9\r\n'));
port.queue('MEDR,0,0,1',sprintf('OK00,0,0,002000000,0,0,0,0,03\r\n'));
port.queue('UCPR,2,03',sprintf('ER30\r\n'));
meter.Measure(); meter.Measure();
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
meter.Save(fileName); saved = load(fileName);
verifyEqual(testCase,saved.measurements.identity,meter.identity);
verifyEqual(testCase,saved.measurements.metadata,meter.metadata);
verifyFalse(testCase,saved.measurements.measurementConditionsIndependent);
[other,~,state] = colormeasuretest.cs2000.instrument(testCase); other.Load(fileName);
verifyEqual(testCase,other.metadata,meter.metadata); verifyEmpty(testCase,state('commands'));
verifyEqual(testCase,other.measurementConditions,meter.measurementConditions);
verifyEqual(testCase,other.spectralData,meter.spectralData);
verifyEqual(testCase,other.XYZData,meter.XYZData);
% Dependent conditions follow the remaining reading when the latest is erased.
other.Erase(); verifyEqual(testCase,other.metadata,meter.metadata(1));
verifyEqual(testCase,other.measurementConditions,meter.metadata(1).conditions);
end

function [meter,port,state] = instrumentForVariationTwo(testCase,manual,custom)
port = colormeasuretest.cs2000.Port(); state = port.State;
factory = @colormeasure.drivers.cs2000.CS2000; if manual, factory = @colormeasure.drivers.cs2000.CS2000manual; end
model = 'CS-2000A'; if custom, model = 'CUSTOM200'; end
meter = factory('SIM','Transport',port,'ResponseTimeout',0.05,'ExpectedModel',model);
port.queue('IDDR',sprintf('OK00,%s,2,1234567\r\n',model));
testCase.addTeardown(@()delete(meter));
end

function values = snapshot(meter)
values = struct('metadata',meter.metadata,'spectralData',meter.spectralData, ...
    'XYZData',meter.XYZData,'measurementConditions',meter.measurementConditions);
end

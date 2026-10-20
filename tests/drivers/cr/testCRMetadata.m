function tests = testCRMetadata
% Last-capture provenance and conditional queries, using no physical transport.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testAllModelsRetainCaptureSettingsAndIdentity(testCase)
for model = {'CR-100','CR-250','CR-300'}
    [meter,port,state] = instrument(testCase,model{1});
    reply(port,'RM Filter','ND-100-1,ND-100-3');
    meter.Measure();
    row = meter.metadata;
    verifyEqual(testCase,row.identity,meter.identity);
    verifyEqual(testCase,row.identity.serialNumber,'0000123');
    verifyEqual(testCase,row.identity.firmware,'1.34.0-S28');
    verifyEqual(testCase,row.captureSettings.filters,'ND-100-1,ND-100-3');
    verifyEqual(testCase,row.captureSettings.exposureMs,111.622,'AbsTol',1e-12);
    verifyEqual(testCase,row.captureSettings.maxAutoExposureMs,449.999,'AbsTol',1e-12);
    verifyEqual(testCase,row.captureSettings.exposureMultiplier,1);
    verifyEqual(testCase,row.captureSettings.warnings,'0');
    verifyEqual(testCase,entry(row,'deviceTime').status,'unavailable');
    verifyEmpty(testCase,row.captureSettings.deviceTime);
    verifyEqual(testCase,row.settingsReadAt.TimeZone,'UTC');
    verifyGreaterThanOrEqual(testCase,row.settingsReadAt,row.acquiredAt);
    commands = state('commands');
    verifyFalse(testCase,any(strcmp(commands,'RM SyncFreq')));
    verifyFalse(testCase,any(strcmp(commands,'RM Matrix')));
    verifyFalse(testCase,any(strcmp(commands,'RM Match')));
    verifyFalse(testCase,any(startsWith(commands,{'RS ','SC '})));
    verifyFalse(testCase,any(contains(lower(string(commands)),'temperature')));
    if strcmp(model{1},'CR-100')
        verifyEqual(testCase,row.captureSettings.aperture,'5 deg');
        verifyEqual(testCase,entry(row,'cmfIndex').status,'notApplicable');
        verifyFalse(testCase,any(strcmp(commands,'RM Speed')));
    else
        verifyEqual(testCase,row.captureSettings.aperture,'1 deg');
        verifyEqual(testCase,row.captureSettings.cmfIndex,0);
        verifyEqual(testCase,row.captureSettings.speed,'Normal');
    end
end
end

function testSyncFrequencyUsesDocumentedUnitAndCaptureTimeIsRaw(testCase)
[meter,port] = instrument(testCase,'CR-100');
reply(port,'RM SyncMode','Manual'); reply(port,'RM SyncFreq','59.94 Hz');
reply(port,'RM Time','2018-01-02 03:04:05');
meter.Measure();
verifyEqual(testCase,meter.metadata.captureSettings.syncFrequencyHz,59.94,'AbsTol',1e-12);
verifyEqual(testCase,meter.metadata.captureSettings.deviceTime,'2018-01-02 03:04:05');
verifyEqual(testCase,entry(meter.metadata,'syncFrequencyHz').unit,'Hz');
end

function testCalibrationQueriesFollowTheSelectedMode(testCase)
for mode = {'Matrix','Match'}
    [meter,port,state] = instrument(testCase,'CR-100');
    reply(port,'RM UserCalibMode',mode{1});
    reply(port,'RM Matrix','N'); reply(port,'RM Match','0');
    meter.Measure(); commands = state('commands');
    if strcmp(mode{1},'Matrix')
        verifyEqual(testCase,meter.metadata.captureSettings.matrixId,'N');
        verifyFalse(testCase,any(strcmp(commands,'RM Match')));
    else
        verifyEqual(testCase,meter.metadata.captureSettings.matchId,'0');
        verifyFalse(testCase,any(strcmp(commands,'RM Matrix')));
    end
    verifyFalse(testCase,any(strcmp(commands,'RM MatrixMode')));
end
end

function testLegacyCalibrationFallbackOnlyForUnsupportedCommand(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RM UserCalibMode',sprintf('ER:-500:Invalid command:UserCalibMode\r\n'));
reply(port,'RM MatrixMode','Enabled'); reply(port,'RM Matrix','N');
meter.Measure();
verifyEqual(testCase,meter.metadata.captureSettings.matrixId,'N');
verifyEqual(testCase,entry(meter.metadata,'userCalibrationMode').status,'unsupported');
verifyTrue(testCase,any(strcmp(state('commands'),'RM MatrixMode')));
end

function testOptionalErrorsAreDistinguishedAndDoNotRecapture(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RM Exposure',sprintf('ER:-500:Invalid command:Exposure\r\n'));
port.queue('RM UserCalibMode',sprintf('ER:-502:Unavailable:No calibration\r\n'));
port.queue('RM SyncMode',sprintf('ER:-500:Invalid command:SyncMode\r\n'));
meter.Measure();
verifyTrue(testCase,isnan(meter.metadata.captureSettings.exposureMs));
verifyEqual(testCase,entry(meter.metadata,'exposureMs').status,'unsupported');
verifyEqual(testCase,entry(meter.metadata,'userCalibrationMode').status,'instrumentError');
verifyEqual(testCase,entry(meter.metadata,'userCalibrationMode').code,-502);
verifyEqual(testCase,entry(meter.metadata,'syncFrequencyHz').status,'dependencyUnavailable');
commands = state('commands');
verifyFalse(testCase,any(strcmp(commands,'RM MatrixMode')));
verifyFalse(testCase,any(strcmp(commands,'RM SyncFreq')));
verifyEqual(testCase,sum(strcmp(commands,'M')),1);
verifyFalse(testCase,state('deleted'));
end

function testMalformedMetadataKeepsCompletedReadingsAndUsableSession(testCase)
for model = {'CR-100','CR-250','CR-300'}
    for payload = {'1 sec','NaN msec','Inf msec','1e999 msec','-1 msec','1;system(''x'') msec'}
        [meter,port,state] = instrument(testCase,model{1});
        meter.Measure(); original = meter.metadata;
        reply(port,'RM Exposure',payload{1});
        meter.Measure();
        verifyEqual(testCase,meter.metadata(1),original);
        verifySize(testCase,meter.XYZ,[2 3]);
        result = entry(meter.metadata(2),'exposureMs');
        verifyEqual(testCase,result.status,'unparsed');
        verifyTrue(testCase,isnan(result.value));
        verifyTrue(testCase,isnan(meter.metadata(2).captureSettings.exposureMs));
        verifyEqual(testCase,result.code,0);
        verifyEqual(testCase,result.response,['OK:0:RM Exposure:' payload{1}]);
        verifyFalse(testCase,state('deleted'));
        meter.Measure();
        verifySize(testCase,meter.XYZ,[3 3]);
        verifySize(testCase,meter.instrumentXYZ,[3 3]);
        verifySize(testCase,meter.CCT,[3 1]);
        verifySize(testCase,meter.Duv,[3 1]);
        verifySize(testCase,meter.metadata,[3 1]);
        verifyEqual(testCase,meter.metadata(3).captureSettings.exposureMs,111.622);
        verifyEqual(testCase,sum(strcmp(state('commands'),'M')),3);
        if ~strcmp(model{1},'CR-100')
            verifyEqual(testCase,size(meter.spectralData,1),3);
            verifyEqual(testCase,size(meter.wl,1),3);
            verifySize(testCase,meter.integratedSpectrum,[3 1]);
        end
    end
end
end

function testUnparsedIntegerMetadataRetainsNoInventedValue(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
for value = {'1.5','0'}
    reply(port,'RM ExposureX',value{1});
    meter.Measure();
    verifyTrue(testCase,isnan(meter.metadata(end).captureSettings.exposureMultiplier));
    verifyEqual(testCase,entry(meter.metadata(end),'exposureMultiplier').status,'unparsed');
end
verifyNumElements(testCase,meter.metadata,2);
verifyFalse(testCase,state('deleted'));
end

function testUnparsedModesDoNotEnableDependentQueries(testCase)
for payload = {'Unexpected Mode','',char(1)}
    [meter,port,state] = instrument(testCase,'CR-100');
    reply(port,'RM SyncMode',payload{1});
    reply(port,'RM UserCalibMode',payload{1});
    meter.Measure();
    verifyEmpty(testCase,meter.metadata.captureSettings.syncMode);
    verifyEmpty(testCase,meter.metadata.captureSettings.userCalibrationMode);
    verifyEqual(testCase,entry(meter.metadata,'syncMode').status,'unparsed');
    verifyEqual(testCase,entry(meter.metadata,'userCalibrationMode').status,'unparsed');
    for field = {'syncFrequencyHz','matrixId','matchId'}
        verifyEqual(testCase,entry(meter.metadata,field{1}).status,'dependencyUnavailable');
    end
    verifyFalse(testCase,any(ismember(state('commands'), ...
        {'RM SyncFreq','RM MatrixMode','RM Matrix','RM Match'})));
end
end

function testUnparsedLegacyCalibrationDoesNotEnableMatrix(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RM UserCalibMode',sprintf('ER:-500:Invalid command:UserCalibMode\r\n'));
reply(port,'RM MatrixMode','Unknown');
meter.Measure();
verifyEmpty(testCase,meter.metadata.captureSettings.legacyMatrixMode);
verifyEqual(testCase,entry(meter.metadata,'legacyMatrixMode').status,'unparsed');
verifyEqual(testCase,entry(meter.metadata,'matrixId').status,'dependencyUnavailable');
verifyFalse(testCase,any(ismember(state('commands'),{'RM Matrix','RM Match'})));
end

function testEveryDocumentedSyncModeControlsFrequencyQuery(testCase)
for mode = {'None','Auto','Manual','NTSC','PAL','CINEMA'}
    [meter,port,state] = instrument(testCase,'CR-100');
    reply(port,'RM SyncMode',mode{1}); reply(port,'RM SyncFreq','59.94 Hz');
    meter.Measure();
    verifyEqual(testCase,meter.metadata.captureSettings.syncMode,mode{1});
    verifyEqual(testCase,any(strcmp(state('commands'),'RM SyncFreq')),~strcmp(mode{1},'None'));
end
end

function testMetadataFramingFailuresStillRejectTheTransaction(testCase)
for raw = {sprintf('OK:0:RM Range:1 msec\r\n'), ...
        sprintf('not a framed response\r\n'), 'OK:0:RM Exposure:111.622 msec'}
    [meter,port,state] = instrument(testCase,'CR-100');
    meter.Measure(); original = meter.metadata;
    port.queue('RM Exposure',raw{1});
    if endsWith(raw{1},newline), identifier = 'CR:Framing'; else, identifier = 'CR:Timeout'; end
    verifyError(testCase,@()meter.Measure(),identifier);
    verifyEqual(testCase,meter.metadata,original);
    verifySize(testCase,meter.XYZ,[1 3]);
    verifyTrue(testCase,state('deleted'));
end
end

function testFragmentedMetadataAndMissingReply(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
text = sprintf('OK:0:RM Exposure:111.622 msec\r\n');
port.queue('RM Exposure',text,[10 numel(text)-10],[0 0.02]);
meter.Measure(); original = meter.metadata;
port.queue('RM Exposure','');
verifyError(testCase,@()meter.Measure(),'CR:Timeout');
verifyEqual(testCase,meter.metadata,original);
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,sum(strcmp(state('commands'),'M')),2);
end

function testSavedRowsKeepTheirOwnSettingsAndEraseRemainsAligned(testCase)
[meter,port] = instrument(testCase,'CR-250');
meter.Measure(); reply(port,'RM Exposure','200.5 seconds'); meter.Measure();
reply(port,'RM Exposure','200.5 msec'); meter.Measure();
fileName = [tempname '.mat']; testCase.addTeardown(@()delete(fileName));
meter.Disconnect(); meter.Save(fileName); saved = load(fileName,'measurements');
verifyEqual(testCase,saved.measurements.metadata,meter.metadata);
verifyEqual(testCase,saved.measurements.metadata(1).captureSettings.exposureMs,111.622);
verifyTrue(testCase,isnan(saved.measurements.metadata(2).captureSettings.exposureMs));
verifyEqual(testCase,entry(saved.measurements.metadata(2),'exposureMs').status,'unparsed');
verifyEqual(testCase,entry(saved.measurements.metadata(2),'exposureMs').response, ...
    'OK:0:RM Exposure:200.5 seconds');
verifyEqual(testCase,saved.measurements.metadata(3).captureSettings.exposureMs,200.5);
verifyEqual(testCase,saved.measurements.spectralData,meter.spectralData);
verifyEqual(testCase,saved.measurements.XYZ,meter.XYZ);
meter.Erase(); meter.Erase(); verifyNumElements(testCase,meter.metadata,1);
verifySize(testCase,meter.spectralData,[1 201]);
meter.EraseAll(); verifyEmpty(testCase,meter.metadata);
end

function result = entry(row,field)
result = row.metadataResponses(strcmp({row.metadataResponses.field},field));
end

function reply(port,command,payload)
port.queue(command,sprintf('OK:0:%s:%s\r\n',command,payload));
end

function [meter,port,state] = instrument(testCase,model)
clock = colormeasuretest.FakeClock(); % Shared with the port: no wall-clock waits.
port = colormeasuretest.cr.Port(model,clock); state = port.State;
reply(port,'RC ID','0000123'); reply(port,'RC Firmware','1.34.0-S28');
meter = colormeasuretest.cr.attach(testCase,model,port,clock,'ResponseTimeout',0.08);
end

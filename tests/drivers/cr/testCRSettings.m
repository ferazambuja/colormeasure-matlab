function tests = testCRSettings
% Native settings behavior with injected serial peers; no hardware or windows.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testStaticControlsRequireNoTransportAndKeepModelMeaning(testCase)
for model = {'CR100','CR250','CR300'}
    controls = colormeasure.drivers.cr.settingsControls(model{1});
    verifyFalse(testCase,any([controls.available]));
    verifyTrue(testCase,all(cellfun(@isempty,{controls.choices})));
    verifyTrue(testCase,all(isnan([controls.minimum])));
    verifyEqual(testCase,numel(unique({controls.id})),numel(controls));
    for k=1:numel(controls)
        verifyTrue(testCase,all(structfun(@(x)ischar(x)&&~isempty(x),controls(k).help)));
    end
    multiplier = controls(strcmp({controls.id},'exposureMultiplier'));
    if strcmp(model{1},'CR250')
        verifyEqual(testCase,multiplier.label,'Averages');
    else
        verifyEqual(testCase,multiplier.label,'Exposure multiplier');
    end
    verifyEqual(testCase,any(strcmp({controls.id},'speed')),~strcmp(model{1},'CR100'));
    verifyEqual(testCase,any(strcmp({controls.id},'range')),strcmp(model{1},'CR100'));
end
end

function testReadSettingsUsesCurrentSetupAndNeverMeasures(testCase)
for model = {'CR-100','CR-250','CR-300'}
    [meter,~,state] = instrument(testCase,model{1});
    report = meter.readSettings();
    verifyEqual(testCase,report.values.exposureMode,1);
    verifyEqual(testCase,report.values.exposureMs,25);
    verifyEqual(testCase,report.values.exposureMultiplier,4);
    verifyEqual(testCase,report.values.aperture,'0.5 deg');
    verifyFalse(testCase,report.controls(strcmp({report.controls.id},'aperture')).available);
    verifyFalse(testCase,isfield(report.values,'maxAutoExposureMs'));
    verifyFalse(testCase,isfield(report.values,'filter1')); % None has no established ID.
    verifyEqual(testCase,report.identity,meter.identity);
    verifyNotEmpty(testCase,regexp(report.readAtUTC,'^\d{4}-\d\d-\d\dT.*Z$','once'));
    commands = state('commands');
    verifyFalse(testCase,any(startsWith(commands,{'SM ','RM '})));
    verifyFalse(testCase,any(strcmp(commands,'M')));
    verifyEqual(testCase,sum(strcmp(commands,'RC Filter')),1);
    verifyEqual(testCase,sum(strcmp(commands,'RS Filter')),1);
    verifyEmpty(testCase,meter.XYZ);
end
end

function testAutomaticLeavesManualSafelyAndPreservesOtherSettings(testCase)
for model = {'CR-100','CR-250','CR-300'}
    [meter,port,state] = instrument(testCase,model{1});
    port.Setup('UserCalibMode') = 2;
    port.Setup('Filter1') = 3;
    receipt = meter.applyAutomaticSettings();
    verifyEqual(testCase,receipt.status,'applied');
    verifyTrue(testCase,all([receipt.acknowledgements.acknowledged]));
    verifyTrue(testCase,all([receipt.acknowledgements.readbackVerified]));
    expected = {'SM ExposureMode 0'};
    if strcmp(model{1},'CR-100'), expected{end+1} = 'SM RangeMode 0'; end
    verifyEqual(testCase,setters(state),expected);
    verifyEqual(testCase,port.Setup('ExposureX'),4);
    verifyEqual(testCase,port.Setup('UserCalibMode'),2);
    verifyEqual(testCase,port.Setup('Filter1'),3);
    verifyEqual(testCase,port.Setup('Accessory'),0);
    verifyEqual(testCase,port.Setup('SyncMode'),0);
    verifyEqual(testCase,port.Setup('Speed'),1);
    verifyEmpty(testCase,meter.metadata);
end
end

function testAutomaticUsesReportedIdsRatherThanAssumingZero(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.Configuration('ExposureMode') = {'7,Auto','1,Fixed'};
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'applied');
verifyEqual(testCase,receipt.requested.exposureMode,7);
verifyEqual(testCase,setters(state),{'SM ExposureMode 7'});
end

function testCR100AutomaticReturnsTemporalModeToColorimeterFirst(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.Setup('Mode') = 1;
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'applied');
verifyEqual(testCase,setters(state),{'SM Mode 0','SM ExposureMode 0','SM RangeMode 0'});
verifyEqual(testCase,receipt.after.values.mode,0);
verifyFalse(testCase,receipt.after.controls(strcmp({receipt.after.controls.id},'mode')).available);
verifyEqual(testCase,receipt.acknowledgements(1).response,'OK:0:SM Mode:No errors');
verifyTrue(testCase,receipt.acknowledgements(1).readbackVerified);
verifyFalse(testCase,any(strcmp(state('commands'),'M')));
end

function testCR100AutomaticRequiresUnambiguousReportedColorimeterMode(testCase)
for choices = {{'1,Flicker'},{'0,Colorimeter','3,Colorimeter'}}
    [meter,port] = instrument(testCase,'CR-100');
    port.Configuration('Mode') = choices{1};
    receipt = meter.applyAutomaticSettings();
    verifyAutomaticFirmwareRefusal(testCase,meter,port,receipt,'1.36');
end
end

function testPureCombinationValidatorRequiresNoInstrument(testCase)
controls = colormeasure.drivers.cr.settingsControls('CR250');
index = find(strcmp({controls.id},'exposureMultiplier'));
controls(index).available = true; controls(index).minimum = 1; controls(index).maximum = 50;
before = struct('values',struct(),'controls',controls);
colormeasure.drivers.cr.validateSettingsCombination(struct('exposureMultiplier',3),before,'CR250');
verifyError(testCase,@()colormeasure.drivers.cr.validateSettingsCombination(struct('exposureMultiplier',1.5),before,'CR250'),'CR:SettingsArgument');
verifyError(testCase,@()colormeasure.drivers.cr.validateSettingsCombination(struct('exposureMultiplier','3'),before,'CR250'),'CR:SettingsArgument');
end

function testEnterFixedSetsRangeBeforeExposureAndOverridesAutoRecipe(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.Setup('ExposureMode') = 0; port.Setup('RangeMode') = 0; port.Setup('Range') = 0;
receipt = meter.applyAutomaticSettings(struct('rangeMode',1,'range',3,'exposureMode',1,'exposureMs',12));
verifyEqual(testCase,receipt.status,'applied');
verifyEqual(testCase,setters(state),{'SM RangeMode 1','SM Range 3','SM Exposure 12','SM ExposureMode 1'});
verifyEqual(testCase,receipt.after.values.exposureMs,12);
end

function testDirectMeasurePreservesNativeSetup(testCase)
[meter,~,state] = instrument(testCase,'CR-100');
meter.Measure();
verifyEmpty(testCase,setters(state));
verifyEqual(testCase,size(meter.XYZ,1),1);
end

function testUnchangedApplicationSendsNoSetters(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.Setup('ExposureMode') = 0; port.Setup('RangeMode') = 0;
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'unchanged');
verifyEmpty(testCase,receipt.commands);
verifyEmpty(testCase,receipt.acknowledgements);
verifyEmpty(testCase,setters(state));
end

function testInvalidArgumentsThrowBeforeAnyQuery(testCase)
[meter,~,state] = instrument(testCase,'CR-100'); before = state('commands');
for changes = {struct('exposureMs',NaN),struct('unknown',1),struct('speed',1), ...
    struct('exposureMultiplier',1.5),struct('exposureMode','Auto'),struct('aperture',0),struct('mode',1)}
    verifyError(testCase,@()meter.applySettings(changes{1}),'CR:SettingsArgument');
end
verifyEqual(testCase,state('commands'),before);
end

function testInvalidWholeCombinationSendsNoSetter(testCase)
[meter,~,state] = instrument(testCase,'CR-100');
cases = {struct('rangeMode',0),struct('exposureMs',40000), ...
    struct('syncFrequencyHz',50),struct('filter1',0), ...
    struct('exposureMode',0,'exposureMs',12),struct('maxAutoExposureMs',50)};
for k=1:numel(cases)
    receipt = meter.applySettings(cases{k});
    verifyEqual(testCase,receipt.status,'failed');
    verifyTrue(testCase,startsWith(receipt.error.identifier,'CR:Settings'),receipt.error.identifier);
    verifyEmpty(testCase,receipt.commands);
end
verifyEmpty(testCase,setters(state));
meter.Measure(); % Pre-write validation failures do not invalidate acquisition.
verifyEqual(testCase,size(meter.XYZ,1),1);
end

function testFragmentedDelayedCapabilityList(testCase)
[meter,port] = instrument(testCase,'CR-100');
raw = sprintf('OK:0:RC ExposureMode:2\r\n0,Auto\r\n1,Fixed\r\n');
port.queue('RC ExposureMode',raw,[5 21 numel(raw)-26],[0 0.01 0.025]);
report = meter.readCapabilities();
control = report.controls(strcmp({report.controls.id},'exposureMode'));
verifyEqual(testCase,[control.choices.value],[0 1]);
record = report.responses(strcmp({report.responses.command},'RC ExposureMode'));
verifyEqual(testCase,record.lines,{'0,Auto';'1,Fixed'});
end

function testIncompleteCapabilityListTimesOutAndCloses(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RC ExposureMode',sprintf('OK:0:RC ExposureMode:2\r\n0,Auto\r\n'));
verifyError(testCase,@()meter.readCapabilities(),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
verifyEmpty(testCase,meter.XYZ);
end

function testExcessiveCapabilityRowCountIsRefusedBeforeReadingRows(testCase)
% A declared row count above 256 is refused at once, not awaited row by row.
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RC ExposureMode',sprintf('OK:0:RC ExposureMode:257\r\n'));
verifyError(testCase,@()meter.readCapabilities(),'CR:SettingsPayload');
verifyEmpty(testCase,setters(state));
end

function testDuplicateCapabilityIdsFailWithoutClosingCompleteStream(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.Configuration('ExposureMode') = {'0,Auto','0,Fixed'};
verifyError(testCase,@()meter.readCapabilities(),'CR:SettingsPayload');
verifyFalse(testCase,state('deleted'));
verifyEmpty(testCase,setters(state));
end

function testTrailingCapabilityRowQuarantines(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RC ExposureMode',sprintf('OK:0:RC ExposureMode:1\r\n0,Auto\r\n1,Fixed\r\n'));
verifyError(testCase,@()meter.readCapabilities(),'CR:PendingInput');
verifyTrue(testCase,state('deleted'));
end

function testMalformedNumericLimitNeverEvaluated(testCase)
% The text is kept, never evaluated as 2, and disables only the exposure controls.
[meter,port,state] = instrument(testCase,'CR-100');
replies = {'RC MinExposure','1+1 msec'};
queueLimits(port,replies);
report = meter.readCapabilities();
verifyUnusableLimits(testCase,report,{'exposureMs','maxAutoExposureMs'},replies,{'CR:Metadata'});
verifyFalse(testCase,state('deleted'));
verifyEmpty(testCase,setters(state));
end

function testZeroAndReversedLimitsDisableOnlyTheirControls(testCase)
% Each row: complete framed replies, the controls they bound, each reply's diagnostic.
exposure = {'exposureMs','maxAutoExposureMs'};
cases = {
    {'RC MinExposure','0.0 msec'},exposure,{'CR:SettingsPayload'}
    {'RC MinExposure','500.0 msec','RC MaxExposure','100.0 msec'},exposure,{'CR:SettingsPayload','CR:SettingsPayload'}
    {'RC MinSyncFreq','0.0 Hz'},{'syncFrequencyHz'},{'CR:SettingsPayload'}
    {'RC MinSyncFreq','500.0 Hz','RC MaxSyncFreq','100.0 Hz'},{'syncFrequencyHz'},{'CR:SettingsPayload','CR:SettingsPayload'}
    {'RC MinExposureX','0'},{'exposureMultiplier'},{'CR:Metadata'}
    {'RC MinExposureX','10','RC MaxExposureX','2'},{'exposureMultiplier'},{'CR:SettingsPayload','CR:SettingsPayload'}};
for k = 1:size(cases,1)
    [meter,port,state] = instrument(testCase,'CR-100');
    queueLimits(port,cases{k,1});
    report = meter.readCapabilities();
    verifyUnusableLimits(testCase,report,cases{k,2},cases{k,1},cases{k,3});
    verifyFalse(testCase,state('deleted'));
    verifyEmpty(testCase,setters(state));
end
end

function testUnusableLimitsRefuseOverridesBeforeAnySetter(testCase)
% Joint and automatic requests keep every field and fail before the first setter.
[meter,port,state] = instrument(testCase,'CR-100');
cases = {
    struct('exposureMode',1,'rangeMode',1,'range',3,'exposureMs',10),false,{'RC MinExposure','0.0 msec'}
    struct('maxAutoExposureMs',500),true,{'RC MinExposure','0.0 msec'}
    struct('syncMode',2,'syncFrequencyHz',50),false,{'RC MinSyncFreq','500.0 Hz','RC MaxSyncFreq','100.0 Hz'}
    struct('exposureMultiplier',2),true,{'RC MinExposureX','0'}};
for k = 1:size(cases,1)
    queueLimits(port,cases{k,3});
    if cases{k,2}
        receipt = meter.applyAutomaticSettings(cases{k,1});
    else
        receipt = meter.applySettings(cases{k,1});
    end
    verifyEqual(testCase,receipt.status,'failed');
    verifyEqual(testCase,receipt.error.identifier,'CR:SettingsUnavailable');
    verifyTrue(testCase,all(isfield(receipt.requested,fieldnames(cases{k,1}))));
    verifyEmpty(testCase,receipt.commands);
end
verifyEmpty(testCase,setters(state));
verifyFalse(testCase,any(strcmp(state('commands'),'M')));
verifyEmpty(testCase,meter.XYZ);
verifyFalse(testCase,state('deleted'));
end

function testManualModeOnlyRequestsRefuseUnavailableNumericControls(testCase)
% Selecting a manual mode cannot bypass the unavailable numeric editor.
cases = {struct('exposureMode',1),'RC MinExposure','0.0 msec'; ...
    struct('syncMode',2),'RC MinSyncFreq','0.0 Hz'};
for model = {'CR-100','CR-250','CR-300'}
    for automatic = [false,true]
        for k = 1:size(cases,1)
            [meter,port,state] = instrument(testCase,model{1});
            port.Setup('ExposureMode') = 0;
            requested = cases{k,1};
            if automatic && strcmp(model{1},'CR-100') && isfield(requested,'exposureMode')
                requested.rangeMode = 1; requested.range = 3;
            end
            queueLimits(port,cases(k,2:3));
            if automatic, receipt = meter.applyAutomaticSettings(requested);
            else, receipt = meter.applySettings(requested); end
            verifyEqual(testCase,receipt.status,'failed');
            verifyEqual(testCase,receipt.error.identifier,'CR:SettingsUnavailable');
            verifyEmpty(testCase,receipt.commands); verifyEmpty(testCase,setters(state));
            verifyFalse(testCase,any(strcmp(state('commands'),'M')));
            verifyEmpty(testCase,meter.XYZ); verifyFalse(testCase,state('deleted'));
        end
    end
end
end

function testManualModeOnlyRequestsRequireKnownNumericTargets(testCase)
% Valid capability limits do not establish a missing or out-of-range readback.
cases = {struct('exposureMode',1),'RS Exposure','NA'; ...
    struct('exposureMode',1),'RS Exposure','0.0 msec'; ...
    struct('exposureMode',1),'RS Exposure','80000.0 msec'; ...
    struct('syncMode',2),'RS SyncFreq','NA'; ...
    struct('syncMode',2),'RS SyncFreq','0.0 Hz'; ...
    struct('syncMode',2),'RS SyncFreq','60000.0 Hz'};
for model = {'CR-100','CR-250','CR-300'}
    for k = 1:size(cases,1)
        [meter,port,state] = instrument(testCase,model{1});
        port.Setup('ExposureMode') = 0;
        port.queue(cases{k,2},sprintf('OK:0:%s:%s\r\n',cases{k,2},cases{k,3}));
        receipt = meter.applySettings(cases{k,1});
        verifyEqual(testCase,receipt.status,'failed');
        verifyEqual(testCase,receipt.error.identifier,'CR:SettingsDependency');
        verifyEmpty(testCase,receipt.commands); verifyEmpty(testCase,setters(state));
        verifyFalse(testCase,any(strcmp(state('commands'),'M')));
        verifyEmpty(testCase,meter.XYZ); verifyFalse(testCase,state('deleted'));
    end
end
end

function testAutomaticAcquisitionProceedsWithUnusableLimits(testCase)
ids = {'exposureMs','maxAutoExposureMs','syncFrequencyHz','exposureMultiplier'};
replies = {'RC MinExposure','0.0 msec','RC MinSyncFreq','500.0 Hz', ...
    'RC MaxSyncFreq','100.0 Hz','RC MinExposureX','0'};
identifiers = {'CR:SettingsPayload','CR:SettingsPayload','CR:SettingsPayload','CR:Metadata'};
for model = {'CR-100','CR-250'}
    [meter,port,state] = instrument(testCase,model{1});
    queueLimits(port,replies); queueLimits(port,replies); % Before and after reports.
    receipt = meter.applyAutomaticSettings();
    verifyEqual(testCase,receipt.status,'applied');
    verifyTrue(testCase,all([receipt.acknowledgements.readbackVerified]));
    verifyUnusableLimits(testCase,receipt.before,ids,replies,identifiers);
    verifyUnusableLimits(testCase,receipt.after,ids,replies,identifiers);
    meter.Measure();
    verifyEqual(testCase,size(meter.XYZ,1),1);
    verifyEqual(testCase,port.Setup('ExposureX'),4);
    verifyEqual(testCase,port.Setup('SyncMode'),0);
    verifyFalse(testCase,state('deleted'));
end
end

function testUnsupportedAutomaticModeReturnsFailedReceiptWithoutWrites(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RC ExposureMode',sprintf('ER:-500:Invalid command:ExposureMode\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:SettingsUnavailable');
verifyEmpty(testCase,setters(state));
verifyFalse(testCase,state('deleted'));
end

function testOlderFirmwareDoesNotProbeNewerSettings(testCase)
for firmware = {'1.9','1.15'}
    port = colormeasuretest.cr.SettingsPort('CR-100');
    port.queue('RC Firmware',sprintf('OK:0:RC Firmware:%s\r\n',firmware{1}));
    meter = attach(testCase,'CR-100',port);
    report = meter.readSettings(); commands = port.State('commands');
    verifyFalse(testCase,any(ismember(commands,{'RC Mode','RS Mode', ...
        'RC UserCalibMode','RS UserCalibMode','RC Match','RS Match','RS MaxAutoExposure'})));
    verifyFalse(testCase,report.controls(strcmp({report.controls.id},'maxAutoExposureMs')).available);
    receipt = meter.applyAutomaticSettings();
    verifyAutomaticFirmwareRefusal(testCase,meter,port,receipt,firmware{1});
end
end

function testUnparseableFirmwareNamesReportedValueInAutomaticRefusal(testCase)
for firmware = {'unreported','v1.36'}
    port = colormeasuretest.cr.SettingsPort('CR-100');
    port.queue('RC Firmware',sprintf('OK:0:RC Firmware:%s\r\n',firmware{1}));
    meter = attach(testCase,'CR-100',port);
    receipt = meter.applyAutomaticSettings();
    verifyAutomaticFirmwareRefusal(testCase,meter,port,receipt,firmware{1});
end
end

function testPartialSetterFailureRetainsReceiptAndBlocksMeasure(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('SM RangeMode 0',sprintf('ER:-512:RangeMode:Invalid Range mode\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,{receipt.commands.command},{'SM ExposureMode 0','SM RangeMode 0'});
verifyEqual(testCase,[receipt.acknowledgements.acknowledged],[true false]);
verifyFalse(testCase,state('deleted'));
verifyError(testCase,@()meter.Measure(),'CR:SettingsUncertain');
verifyEmpty(testCase,meter.XYZ);
empty = meter.applySettings(struct());
verifyEqual(testCase,empty.status,'failed');
verifyError(testCase,@()meter.Measure(),'CR:SettingsUncertain');
recovered = meter.applyAutomaticSettings();
verifyEqual(testCase,recovered.status,'applied');
meter.Measure();
verifyEqual(testCase,size(meter.XYZ,1),1);
end

function testSetterTimeoutRetainsAttemptAndCloses(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('SM ExposureMode 0','');
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:Timeout');
verifyEqual(testCase,{receipt.commands.command},{'SM ExposureMode 0'});
verifyFalse(testCase,receipt.acknowledgements.acknowledged);
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,sum(strcmp(state('commands'),'SM ExposureMode 0')),1);
end

function testLateInitialSettingsTimeoutRetainsPartialBeforeWithoutWrites(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('RS Aperture','');
prior = meter.snapshot(); receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:Timeout');
verifyEqual(testCase,receipt.before.values.exposureMode,1);
verifyEqual(testCase,receipt.before.values.exposureMultiplier,4);
verifyFalse(testCase,isfield(receipt.before.values,'aperture'));
verifyEqual(testCase,receipt.before.identity,meter.identity);
responses = receipt.before.responses;
verifyTrue(testCase,any(strcmp({responses.command},'RC ExposureMode')));
readback = responses(strcmp({responses.command},'RS ExposureMode'));
verifyEqual(testCase,readback.response,'OK:0:RS ExposureMode:Fixed');
verifyEmpty(testCase,receipt.commands);
verifyEmpty(testCase,receipt.after);
verifyEmpty(testCase,setters(state));
verifyEqual(testCase,meter.snapshot(),prior);
verifyTrue(testCase,state('deleted'));
end

function testLateFinalSettingsTimeoutRetainsPartialAfterAndAcknowledgement(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('RS Aperture',sprintf('OK:0:RS Aperture:0.5 deg\r\n'));
port.queue('RS Aperture','');
prior = meter.snapshot(); receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:Timeout');
verifyEqual(testCase,receipt.before.values.aperture,'0.5 deg');
verifyEqual(testCase,receipt.before.values.exposureMode,1);
verifyEqual(testCase,receipt.after.values.exposureMode,0);
verifyEqual(testCase,receipt.after.values.exposureMultiplier,4);
verifyFalse(testCase,isfield(receipt.after.values,'aperture'));
verifyEqual(testCase,receipt.after.identity,meter.identity);
responses = receipt.after.responses;
verifyTrue(testCase,any(strcmp({responses.command},'RC ExposureMode')));
readback = responses(strcmp({responses.command},'RS ExposureMode'));
verifyEqual(testCase,readback.response,'OK:0:RS ExposureMode:Auto');
verifyEqual(testCase,{receipt.commands.command},{'SM ExposureMode 0'});
verifyTrue(testCase,receipt.acknowledgements.acknowledged);
verifyFalse(testCase,receipt.acknowledgements.readbackVerified);
verifyEqual(testCase,meter.snapshot(),prior);
verifyTrue(testCase,state('deleted'));
verifyFalse(testCase,any(strcmp(state('commands'),'M')));
end

function testCapabilityTimeoutRetainsEarlierReportsAndPublicReadsStillThrow(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('RC MaxExposureX','');
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:Timeout');
verifyEmpty(testCase,fieldnames(receipt.before.values));
responses = receipt.before.responses;
verifyTrue(testCase,any(strcmp({responses.command},'RC ExposureMode')));
verifyTrue(testCase,any(strcmp({responses.command},'RC MinExposureX')));
control = receipt.before.controls(strcmp({receipt.before.controls.id},'exposureMode'));
verifyTrue(testCase,control.available);
verifyEmpty(testCase,receipt.commands);
verifyTrue(testCase,state('deleted'));

[meter,port,state] = instrument(testCase,'CR-250');
port.queue('RS Aperture','');
verifyError(testCase,@()meter.readSettings(),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('RC MaxExposureX','');
verifyError(testCase,@()meter.readCapabilities(),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
end

function testIncompleteCapabilityRetainsHeaderRowsAndTailBeforeOrAfter(testCase)
for afterWrite = [false true]
    for tail = {'','1,Fi'}
        [meter,port,state] = instrument(testCase,'CR-250');
        if afterWrite
            port.queue('RC ExposureMode',sprintf('OK:0:RC ExposureMode:2\r\n0,Auto\r\n1,Fixed\r\n'));
        end
        port.queue('RC ExposureMode',[sprintf('OK:0:RC ExposureMode:2\r\n0,Auto\r\n') tail{1}]);
        prior = meter.snapshot(); receipt = meter.applyAutomaticSettings();
        verifyEqual(testCase,receipt.status,'failed');
        verifyEqual(testCase,receipt.error.identifier,'CR:Timeout');
        if afterWrite
            report = receipt.after;
            verifyEqual(testCase,{receipt.commands.command},{'SM ExposureMode 0'});
            verifyTrue(testCase,receipt.acknowledgements.acknowledged);
        else
            report = receipt.before;
            verifyEmpty(testCase,receipt.commands);
        end
        record = report.responses(strcmp({report.responses.command},'RC ExposureMode'));
        verifyEqual(testCase,record.response,'OK:0:RC ExposureMode:2');
        verifyEqual(testCase,record.lines,{'0,Auto'});
        if isempty(tail{1})
            verifyEmpty(testCase,record.partialTail);
        else
            verifyEqual(testCase,record.partialTail,tail{1});
        end
        verifyEqual(testCase,record.code,0); % Header status is not a complete list.
        verifyEqual(testCase,record.status,'incomplete');
        verifyEqual(testCase,record.error.identifier,'CR:Timeout');
        control = report.controls(strcmp({report.controls.id},'exposureMode'));
        verifyFalse(testCase,control.available);
        verifyEmpty(testCase,control.choices);
        verifyEmpty(testCase,fieldnames(report.values));
        verifyEqual(testCase,meter.snapshot(),prior);
        verifyTrue(testCase,state('deleted'));
        verifyFalse(testCase,any(strcmp(state('commands'),'M')));
    end
end
end

function testFailingSetupExchangeRetainsRawBeforeOrAfter(testCase)
fixtures = { ...
    'OK:0:RS Aperture:0.','OK:0:RS Aperture:0.','OK:0:RS Aperture:0.','incomplete','CR:Timeout'; ...
    sprintf('not a CR response\r\n'),'not a CR response','','error','CR:Framing'};
for afterWrite = [false true]
    for k = 1:size(fixtures,1)
        [meter,port,state] = instrument(testCase,'CR-250');
        if afterWrite
            port.queue('RS Aperture',sprintf('OK:0:RS Aperture:0.5 deg\r\n'));
        end
        port.queue('RS Aperture',fixtures{k,1});
        prior = meter.snapshot(); receipt = meter.applyAutomaticSettings();
        verifyEqual(testCase,receipt.status,'failed');
        verifyEqual(testCase,receipt.error.identifier,fixtures{k,5});
        if afterWrite
            report = receipt.after; expectedMode = 0;
            verifyEqual(testCase,{receipt.commands.command},{'SM ExposureMode 0'});
            verifyTrue(testCase,receipt.acknowledgements.acknowledged);
        else
            report = receipt.before; expectedMode = 1;
            verifyEmpty(testCase,receipt.commands);
        end
        verifyEqual(testCase,report.values.exposureMode,expectedMode);
        verifyFalse(testCase,isfield(report.values,'aperture'));
        record = report.responses(strcmp({report.responses.command},'RS Aperture'));
        verifyEqual(testCase,record.response,fixtures{k,2});
        if isempty(fixtures{k,3})
            verifyEmpty(testCase,record.partialTail);
        else
            verifyEqual(testCase,record.partialTail,fixtures{k,3});
        end
        verifyEqual(testCase,record.status,fixtures{k,4});
        verifyEqual(testCase,record.error.identifier,fixtures{k,5});
        verifyTrue(testCase,isnan(record.code));
        verifyEqual(testCase,meter.snapshot(),prior);
        verifyTrue(testCase,state('deleted'));
        verifyFalse(testCase,any(strcmp(state('commands'),'M')));
    end
end
end

function testSetterAcknowledgementMustMatchLabel(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.queue('SM ExposureMode 0',sprintf('OK:0:Speed:No errors\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:Framing');
verifyEqual(testCase,receipt.acknowledgements.response,'OK:0:Speed:No errors');
verifyTrue(testCase,state('deleted'));
end

function testAcknowledgedButUnchangedReadbackBlocksAcquisition(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
port.IgnoreWrites = {'SM ExposureMode 0'};
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:SettingsReadback');
verifyTrue(testCase,receipt.acknowledgements.acknowledged);
verifyFalse(testCase,receipt.acknowledgements.readbackVerified);
verifyEqual(testCase,receipt.after.values.exposureMode,1);
verifyFalse(testCase,state('deleted'));
verifyError(testCase,@()meter.Measure(),'CR:SettingsUncertain');
port.IgnoreWrites = {};
recovered = meter.applyAutomaticSettings();
verifyEqual(testCase,recovered.status,'applied');
end

function testFinalVerificationIncludesRequestedFieldSkippedBeforeWrites(testCase)
[meter,port] = instrument(testCase,'CR-100');
port.Setup('ExposureMode') = 0;
port.SideEffects('SM RangeMode 0') = struct('ExposureMode',1);
receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,{receipt.commands.command},{'SM RangeMode 0'});
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:SettingsReadback');
verifyEqual(testCase,receipt.after.values.exposureMode,1);
verifyError(testCase,@()meter.Measure(),'CR:SettingsUncertain');
end

function testMaximumAutoExposureIsAcknowledgedOnly(testCase)
[meter,~,state] = instrument(testCase,'CR-100');
receipt = meter.applyAutomaticSettings(struct('maxAutoExposureMs',500));
verifyEqual(testCase,receipt.status,'applied');
ack = receipt.acknowledgements(strcmp({receipt.acknowledgements.id},'maxAutoExposureMs'));
verifyTrue(testCase,ack.acknowledged);
verifyFalse(testCase,ack.readbackVerified);
verifyFalse(testCase,isfield(receipt.after.values,'maxAutoExposureMs'));
verifyFalse(testCase,any(strcmp(state('commands'),'RS MaxAutoExposure')));
verifyFalse(testCase,any(startsWith(state('commands'),'RM ')));
end

function testAccessoryRefreshesMatricesAndJointMatrixChangeRejected(testCase)
[meter,~,state] = instrument(testCase,'CR-100');
invalid = meter.applySettings(struct('accessory',5,'userCalibrationMode',1,'matrixId',7));
verifyEqual(testCase,invalid.status,'failed');
verifyEmpty(testCase,setters(state));
changed = meter.applySettings(struct('accessory',5));
verifyEqual(testCase,changed.status,'applied');
matrices = changed.after.controls(strcmp({changed.after.controls.id},'matrixId'));
verifyEqual(testCase,[matrices.choices.value],8);
corrected = meter.applySettings(struct('userCalibrationMode',1,'matrixId',8));
verifyEqual(testCase,corrected.status,'applied');
verifyEqual(testCase,corrected.after.values.matrixId,8);
end

function testReadOnlyApertureUnavailableStaysUnknown(testCase)
[meter,port] = instrument(testCase,'CR-250');
port.queue('RS Aperture',sprintf('ER:-500:Invalid command:Aperture\r\n'));
report = meter.readSettings();
verifyFalse(testCase,isfield(report.values,'aperture'));
record = report.responses(strcmp({report.responses.command},'RS Aperture'));
verifyEqual(testCase,record.status,'unsupported');
end

function testManualReadbackIsTheFixedExposureAndRangeChoice(testCase)
% The CR manual also calls the Fixed exposure and range modes Manual, so RS may
% report either name for the configured Fixed ID. A genuine Manual choice, as
% for synchronization, keeps its own ID.
[meter,port] = instrument(testCase,'CR-100');
port.queue('RS ExposureMode',sprintf('OK:0:RS ExposureMode:Manual\r\n'));
port.queue('RS RangeMode',sprintf('OK:0:RS RangeMode:Manual\r\n'));
port.queue('RS SyncMode',sprintf('OK:0:RS SyncMode:Manual\r\n'));
report = meter.readSettings();
verifyEqual(testCase,report.values.exposureMode,1);
verifyEqual(testCase,report.values.rangeMode,1);
verifyEqual(testCase,report.values.syncMode,2);
end

function testReceiptCanBeSavedWithoutDeviceAndHistoryIsUntouched(testCase)
[meter,~,~] = instrument(testCase,'CR-100');
before = meter.snapshot(); receipt = meter.applyAutomaticSettings();
verifyEqual(testCase,meter.snapshot(),before);
file = [tempname '.mat']; testCase.addTeardown(@()delete(file));
save(file,'receipt'); saved = load(file,'receipt');
verifyEqual(testCase,saved.receipt,receipt);
end

function [meter,port,state] = instrument(testCase,model)
% The settings-capable port, with this suite's short deadlines.
[meter,port,state] = colormeasuretest.cr.instrument(testCase,model,'Settings',true,'ResponseTimeout',0.08,'MeasurementTimeout',0.15);
end

function meter = attach(testCase,model,port)
meter = colormeasuretest.cr.attach(testCase,model,port,[],'ResponseTimeout',0.08,'MeasurementTimeout',0.15);
end

function commands = setters(state)
commands = state('commands'); commands = commands(startsWith(commands,'SM '));
end

function queueLimits(port,replies)
% replies alternates complete RC commands and their framed payloads.
for k = 1:2:numel(replies)
    port.queue(replies{k},sprintf('OK:0:%s:%s\r\n',replies{k},replies{k+1}));
end
end

function verifyUnusableLimits(testCase,report,ids,replies,identifiers)
% Unusable limits disable only the controls they bound and keep each raw reply.
controls = report.controls;
for k = 1:numel(ids)
    control = controls(strcmp({controls.id},ids{k}));
    verifyFalse(testCase,control.available,ids{k});
    verifyTrue(testCase,isnan(control.minimum) && isnan(control.maximum),ids{k});
end
for k = 1:2:numel(replies)
    record = report.responses(strcmp({report.responses.command},replies{k}));
    verifyNumElements(testCase,record,1,replies{k});
    verifyEqual(testCase,record.status,'unparsed',replies{k});
    verifyEqual(testCase,record.error.identifier,identifiers{(k+1)/2},replies{k});
    verifyEqual(testCase,record.response,sprintf('OK:0:%s:%s',replies{k},replies{k+1}));
end
others = controls(strcmp({controls.type},'number') & ~ismember({controls.id},ids));
verifyTrue(testCase,all([others.available]));
end

function verifyAutomaticFirmwareRefusal(testCase,meter,port,receipt,firmware)
verifyEqual(testCase,receipt.status,'failed');
verifyEqual(testCase,receipt.error.identifier,'CR:SettingsUnavailable');
verifyTrue(testCase,contains(receipt.error.message,['Reported firmware: "' firmware '"']));
verifyTrue(testCase,contains(receipt.error.message,'1.16 or newer'));
verifyTrue(testCase,contains(receipt.error.message,'uniquely reported Colorimeter'));
verifyTrue(testCase,contains(receipt.error.message,'successful readback'));
verifyEmpty(testCase,setters(port.State));
verifyFalse(testCase,any(strcmp(port.State('commands'),'M')));
verifyEmpty(testCase,meter.XYZ);
verifyFalse(testCase,port.State('deleted'));
end

function testSettingsSpecsNormalizeEveryModelKey(t)
for pair={{'CR100','CR-100'},{'CR250','CR-250'},{'CR300','CR-300'}}
    verifyEqual(t,colormeasure.drivers.cr.settingsSpecs(pair{1}{1}), ...
        colormeasure.drivers.cr.settingsSpecs(pair{1}{2}));
end
end

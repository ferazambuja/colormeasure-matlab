function tests = testCS2000Settings
% Current-settings operations through the real driver and an isolated peer.
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.path = path;
colormeasuretest.setupPaths(t);
end


function teardownOnce(t)
path(t.TestData.path);
end

function testCatalogIsPlainOfflineHelpAndCoupledFieldsRemainStageable(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t);
catalog = colormeasure.drivers.cs2000.settingsCatalog();
verifyEmpty(t,state('commands'));
verifyEqual(t,numel(catalog),9);
verifyFalse(t,catalog(strcmp({catalog.id},'measurementAngleDegrees')).available);
for k = 1:numel(catalog)
    help = catalog(k).help;
    verifyTrue(t,all(isfield(help,{'meaning','whenToUse','tradeoff','normal','source'})));
    verifyTrue(t,all(structfun(@(value)ischar(value) && ~isempty(value),help)));
    verifyTrue(t,contains(help.source,'konicaminolta'));
end
meter.Connect(); report = meter.readSettings();
for name = {'integrationTimeSeconds','frequencyHz','internalNDMode'}
    verifyTrue(t,report.controls(strcmp({report.controls.id},name{1})).available);
end
verifyEqual(t,numel(report.controls(strcmp({report.controls.id},'internalNDMode')).choices),3);
end

function testReadSettingsUsesCurrentQueriesAndKeepsHistoryAndSaveState(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t);
state('speedPayload') = '3,012345678,1'; state('syncPayload') = '1,05994';
state('angleCode') = 2; state('lensCode') = 1; state('channelCode') = 3;
meter.Connect(); before = meter.snapshot(); saved = meter.isSaved;
report = meter.readSettings();
verifyEqual(t,report.values.integrationTimeSeconds,12.345678,'AbsTol',1e-12);
verifyEqual(t,report.values.frequencyHz,59.94,'AbsTol',1e-12);
verifyEqual(t,report.values.measurementAngleDegrees,.1);
verifyEqual(t,report.values.closeupLens,1);
verifyEqual(t,report.values.userCalibrationChannel,3);
verifyEqual(t,report.userCalibration.name,'User Cal');
verifyEqual(t,report.responses.UCPR,'OK00,User Cal  ');
verifyEqual(t,report.speedLayout,'unknown');
verifyTrue(t,ischar(report.readAtUTC) && endsWith(report.readAtUTC,'Z'));
verifyEqual(t,report.identity,meter.identity);
verifyEqual(t,meter.snapshot(),before); verifyEqual(t,meter.isSaved,saved);
verifyFalse(t,any(startsWith(state('commands'),{'MEAS,','MEDR,'})));
verifyEmpty(t,setters(state));
end

function testAutomaticRecipeLeavesManualOnBothCS2000Layouts(t)
for generation = {'legacy','modern'}
    [meter,~,state] = colormeasuretest.cs2000.instrument(t);
    state('speedGeneration') = generation{1}; state('speedPayload') = '3,120000000,1';
    state('syncPayload') = '2'; state('externalNDCode') = 2; state('channelCode') = 4;
    meter.Connect(); before = meter.snapshot();
    receipt = meter.applyAutomaticSettings();
    verifyEqual(t,receipt.status,'applied');
    verifyEqual(t,receipt.commands,{'SPMS,2,1','SCMS,0'});
    verifyEqual(t,receipt.acknowledgements,{'OK00','OK00'});
    verifyEqual(t,receipt.before.speedLayout,'unknown');
    verifyEqual(t,receipt.after.speedLayout,generation{1});
    verifyEqual(t,receipt.after.values.speedMode,2);
    verifyEqual(t,receipt.after.values.integrationTimeSeconds,1);
    verifyEqual(t,receipt.after.values.internalNDMode,2);
    verifyEqual(t,receipt.after.values.syncMode,0);
    verifyEqual(t,receipt.after.values.externalNDFilter,2);
    verifyEqual(t,receipt.after.values.userCalibrationChannel,4);
    verifyTrue(t,receipt.persistence.settingsPersist);
    verifyEqual(t,receipt.persistence.remoteMode,1);
    verifyFalse(t,receipt.persistence.automaticRestoration);
    verifyEqual(t,meter.snapshot(),before);
    verifyFalse(t,any(startsWith(state('commands'),{'MEAS,','RMTS,2','VERR'})));
end
end

function testCS2000AAutomaticUsesModernLayout(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t);
port.queue('IDDR',sprintf('OK00,CS-2000A ,2,1234567\r\n'));
state('speedGeneration') = 'modern'; state('speedPayload') = '3,002000000,0';
meter.Connect(); receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SPMS,2,1,2'});
verifyEqual(t,receipt.before.speedLayout,'modern');
end

function testUnchangedRecipeSkipsAllSettersAndDisconnectKeepsNewSettings(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); state('speedPayload') = '2,1,2';
meter.Connect(); receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'unchanged'); verifyEmpty(t,receipt.commands);
verifyEqual(t,receipt.after,receipt.before);
verifyEmpty(t,setters(state));
receipt = meter.applySettings(struct('speedMode',1));
verifyEqual(t,receipt.commands,{'SPMS,1,2'});
meter.Disconnect();
verifyEqual(t,state('speedPayload'),'1,2');
verifyEqual(t,setters(state),{'SPMS,1,2'});
end

function testExplicitOverridesManualNDAndInternalFrequency(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
receipt = meter.applyAutomaticSettings(struct('speedMode',3, ...
    'integrationTimeSeconds',.005,'internalNDMode',1, ...
    'syncMode',1,'frequencyHz',59.94));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SPMS,3,000005000,1','SCMS,1,05994'});
verifyEqual(t,receipt.after.values.integrationTimeSeconds,.005);
verifyEqual(t,receipt.after.values.internalNDMode,1);
verifyFalse(t,any(strcmp(state('commands'),'MEAS,1')));
end

function testAutomaticNormalOverrideDoesNotSupplyMultiInterval(t)
[meter,~,~] = colormeasuretest.cs2000.instrument(t); meter.Connect();
receipt = meter.applyAutomaticSettings(struct('speedMode',1));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SPMS,1,2'});
verifyTrue(t,isnan(receipt.after.values.integrationTimeSeconds));
end

function testManualOverrideNeverSilentlyChoosesNDOffOrExposure(t)
for override = {struct('speedMode',3),struct('speedMode',3,'integrationTimeSeconds',2), ...
        struct('speedMode',3,'internalNDMode',0)}
    [meter,~,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
    receipt = meter.applyAutomaticSettings(override{1});
    verifyEqual(t,receipt.status,'failed');
    verifyEqual(t,receipt.error.identifier,'CS2000:SettingsCombination');
    verifyEmpty(t,receipt.commands); verifyEmpty(t,setters(state));
end
end

function testModernOnlyOverridesRejectAmbiguousOrLegacyBeforeWrites(t)
for payload = {'0','3,002000000,0'}
    for changes = {struct('speedMode',4,'integrationTimeSeconds',1), ...
            struct('speedMode',0,'internalNDMode',1)}
        [meter,~,state] = colormeasuretest.cs2000.instrument(t); state('speedPayload') = payload{1};
        meter.Connect(); receipt = meter.applySettings(changes{1});
        verifyEqual(t,receipt.status,'failed');
        verifyEqual(t,receipt.error.identifier,'CS2000:SettingsCapability');
        verifyEmpty(t,setters(state));
        catalog = receipt.before.controls;
        verifyFalse(t,any([catalog(strcmp({catalog.id},'speedMode')).choices.value] == 4));
    end
end
end

function testModernReadbackPermitsMultiFastAndFixedND(t)
[meter,~,~] = colormeasuretest.cs2000.instrument(t); meter.Connect();
receipt = meter.applySettings(struct('speedMode',4,'integrationTimeSeconds',16,'internalNDMode',1));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SPMS,4,16,1'});
end

function testRequestedAccessoryConflictFailsBeforeAnySetter(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); state('externalNDCode') = 1; meter.Connect();
receipt = meter.applyAutomaticSettings(struct('closeupLens',1));
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.error.identifier,'CS2000:SettingsCombination');
verifyEmpty(t,receipt.commands); verifyEmpty(t,setters(state));
end

function testInheritedAccessoryConflictIsReportedAndPreserved(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); state('externalNDCode') = 1; state('lensCode') = 1;
meter.Connect(); receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.after.values.closeupLens,1);
verifyEqual(t,receipt.after.values.externalNDFilter,1);
verifyFalse(t,any(startsWith(setters(state),{'LNSS,','NDFS,'})));
end

function testAccessoryReplacementDisablesOldCompensationFirst(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); state('externalNDCode') = 2; meter.Connect();
receipt = meter.applySettings(struct('externalNDFilter',0,'closeupLens',1));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'NDFS,0','LNSS,1'});
receipt = meter.applySettings(struct('externalNDFilter',1,'closeupLens',0));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'LNSS,0','NDFS,1'});
end

function testEmptyRequestedChannelStopsBeforeAutomaticChanges(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
port.queue('UCPR,2,03',sprintf('ER05\r\n'));
receipt = meter.applyAutomaticSettings(struct('userCalibrationChannel',3));
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.preflight.response,'ER05');
verifyEqual(t,receipt.error.identifier,'CS2000:InstrumentError');
verifyEmpty(t,receipt.commands); verifyEmpty(t,setters(state));
verifyTrue(t,meter.isConnected());
meter.Measure(); verifySize(t,meter.XYZData,[3 1]); % No write attempt, no quarantine.
end

function testExistingChannelSelectionPreflightAndFactoryChannel(t)
[meter,~,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
receipt = meter.applySettings(struct('userCalibrationChannel',3));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.preflight.name,'User Cal');
verifyEqual(t,receipt.commands,{'UCCS,03'});
verifyEqual(t,receipt.after.userCalibration.name,'User Cal');
receipt = meter.applySettings(struct('userCalibrationChannel',0));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'UCCS,00'});
verifyEqual(t,receipt.after.userCalibration.status,'factory-standard');
verifyFalse(t,any(strcmp(state('commands'),'UCPR,2,00')));
end

function testWholeCoupledTargetInvalidBeforeAnySettingWrite(t)
cases = {struct('syncMode',1),struct('syncMode',0,'frequencyHz',60), ...
    struct('speedMode',2,'integrationTimeSeconds',1.5), ...
    struct('speedMode',3,'integrationTimeSeconds',2,'internalNDMode',2), ...
    struct('speedMode',0,'integrationTimeSeconds',1)};
for k = 1:numel(cases)
    [meter,~,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
    receipt = meter.applySettings(cases{k});
    verifyEqual(t,receipt.status,'failed');
    verifyEqual(t,receipt.error.identifier,'CS2000:SettingsCombination');
    verifyEmpty(t,receipt.commands); verifyEmpty(t,setters(state));
    meter.Measure(); verifySize(t,meter.XYZData,[3 1]);
end
end

function testArgumentValidationSendsNothing(t)
cases = {[],struct('firmware',1),struct('measurementAngleDegrees',1), ...
    struct('speedMode','Normal'),struct('internalNDMode',NaN), ...
    struct('frequencyHz',60.001),struct('frequencyHz',201), ...
    struct('integrationTimeSeconds',.0050001),struct('integrationTimeSeconds',0), ...
    struct('userCalibrationChannel',11)};
[meter,~,state] = colormeasuretest.cs2000.instrument(t);
for k = 1:numel(cases)
    verifyError(t,@()meter.applySettings(cases{k}),'CS2000:SettingsArguments');
    verifyError(t,@()meter.applyAutomaticSettings(cases{k}),'CS2000:SettingsArguments');
end
verifyEmpty(t,state('commands'));
end

function testReadbackMismatchRetainsAfterAndBlocksBothNativeMeasurements(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t,'Manual',true); meter.Connect();
port.queue('SPMR',sprintf('OK00,0,2\r\n'));
port.queue('SPMR',sprintf('OK00,0,2\r\n')); % Setting acknowledged, wrong readback.
before = meter.snapshot(); receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.error.identifier,'CS2000:SettingsReadback');
verifyEqual(t,receipt.acknowledgements,{'OK00'});
verifyEqual(t,receipt.after.values.speedMode,0);
verifyEqual(t,meter.snapshot(),before);
verifyError(t,@()meter.Measure(),'CS2000:SettingsUnverified');
verifyError(t,@()meter.MeasureManual(),'CS2000:SettingsUnverified');
receipt = meter.applySettings(struct());
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.error.identifier,'CS2000:SettingsUnverified');
verifyError(t,@()meter.Measure(),'CS2000:SettingsUnverified');
receipt = meter.applySettings(struct('speedMode',2,'integrationTimeSeconds',1, ...
    'internalNDMode',2,'syncMode',0));
verifyEqual(t,receipt.status,'unchanged');
verifyFalse(t,any(strcmp(state('commands'),'MEAS,1')));
meter.Measure(); verifySize(t,meter.XYZData,[3 1]);
end

function testPartialInstrumentErrorStopsAndRetainsAttemptedCommands(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); state('syncPayload') = '2'; meter.Connect();
port.queue('SCMS,0',sprintf('ER17\r\n'));
before = meter.snapshot(); receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.commands,{'SPMS,2,1,2','SCMS,0'});
verifyEqual(t,receipt.acknowledgements,{'OK00','ER17'});
verifyEmpty(t,receipt.after);
verifyEqual(t,state('speedPayload'),'2,1,2'); verifyEqual(t,state('syncPayload'),'2');
verifyEqual(t,meter.snapshot(),before);
verifyError(t,@()meter.Measure(),'CS2000:SettingsUnverified');
commands = state('commands'); verifyEqual(t,commands{end},'SCMS,0');
verifyTrue(t,meter.isConnected());
end

function testUnrelatedNoOpCannotClearFailedRecipeAndCompleteReapplicationRecovers(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); state('syncPayload') = '2'; meter.Connect();
port.queue('SCMS,0',sprintf('ER17\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'failed');
before = meter.snapshot(); attempted = setters(state);
for changes = {struct('externalNDFilter',0),struct(), ...
        struct('speedMode',2,'integrationTimeSeconds',1,'internalNDMode',2)}
    receipt = meter.applySettings(changes{1});
    verifyEqual(t,receipt.status,'failed');
    verifyEqual(t,receipt.error.identifier,'CS2000:SettingsUnverified');
    verifyEmpty(t,receipt.commands);
    verifyEqual(t,setters(state),attempted);
    verifyError(t,@()meter.Measure(),'CS2000:SettingsUnverified');
end
verifyEqual(t,meter.snapshot(),before);
verifyFalse(t,any(strcmp(state('commands'),'MEAS,1')));
receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SCMS,0'});
verifyEqual(t,receipt.after.values.syncMode,0);
meter.Measure(); verifySize(t,meter.XYZData,[3 1]);
end

function testRecoveryMayExplicitlyChooseDifferentCompleteIntent(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); state('syncPayload') = '2'; meter.Connect();
port.queue('SCMS,0',sprintf('ER17\r\n'));
receipt = meter.applyAutomaticSettings(); verifyEqual(t,receipt.status,'failed');
receipt = meter.applySettings(struct('speedMode',2,'integrationTimeSeconds',1, ...
    'internalNDMode',2,'syncMode',2));
verifyEqual(t,receipt.status,'unchanged');
verifyEmpty(t,receipt.commands);
verifyFalse(t,any(strcmp(state('commands'),'MEAS,1')));
meter.Measure(); verifySize(t,meter.XYZData,[3 1]);
end

function testAmbiguousOrLostSettingReplyQuarantinesWithoutFurtherCommands(t)
for reply = {'',sprintf('ER00\r\n'),sprintf('ER02\r\n'), ...
        sprintf('ER17,extra\r\n'),sprintf('OK00\r\nOK00\r\n')}
    [meter,port,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
    port.queue('SPMS,2,1,2',reply{1});
    % Restoration cannot be confirmed on the quarantined port; the driver warns.
    receipt = verifyWarning(t,@()meter.applyAutomaticSettings(),'CS2000:CleanupUnverified');
    verifyEqual(t,receipt.status,'failed');
    verifyEqual(t,receipt.commands,{'SPMS,2,1,2'});
    verifyEqual(t,numel(receipt.acknowledgements),1);
    verifyTrue(t,state('deleted')); verifyFalse(t,meter.isConnected());
    commands = state('commands'); verifyEqual(t,commands{end},'SPMS,2,1,2');
    verifyEmpty(t,meter.XYZData);
end
end

function testPartialRequiredReadbackIsRetainedWithoutWrites(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
port.queue('NDFR',sprintf('OK00,nonsense\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.before.responses.NDFR,'OK00,nonsense');
verifyTrue(t,isfield(receipt.before.values,'closeupLens'));
verifyFalse(t,isfield(receipt.before.values,'externalNDFilter'));
verifyEmpty(t,setters(state)); verifyTrue(t,meter.isConnected());
end

function testPartialAfterReportDoesNotTreatAcknowledgementAsVerification(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t); meter.Connect();
port.queue('NDFR',sprintf('OK00,0\r\n'));
port.queue('NDFR',sprintf('OK00,invalid\r\n'));
receipt = meter.applyAutomaticSettings();
verifyEqual(t,receipt.status,'failed');
verifyEqual(t,receipt.acknowledgements,{'OK00'});
verifyEqual(t,receipt.after.values.speedMode,2);
verifyEqual(t,receipt.after.responses.NDFR,'OK00,invalid');
verifyFalse(t,isfield(receipt.after.values,'externalNDFilter'));
verifyError(t,@()meter.Measure(),'CS2000:SettingsUnverified');
commands = state('commands'); verifyEqual(t,commands{end},'NDFR');
end

function testManualAndFrequencyUpperAndLowerBounds(t)
for frequency = [20 200]
    [meter,~,~] = colormeasuretest.cs2000.instrument(t); meter.Connect();
    receipt = meter.applySettings(struct('speedMode',3,'integrationTimeSeconds',120, ...
        'internalNDMode',1,'syncMode',1,'frequencyHz',frequency));
    verifyEqual(t,receipt.status,'applied');
    verifyEqual(t,receipt.after.values.integrationTimeSeconds,120);
    verifyEqual(t,receipt.after.values.frequencyHz,frequency);
end
end

function testReadSettingsFragmentationAndLateTimeout(t)
[meter,port,state] = colormeasuretest.cs2000.instrument(t,'Clock',colormeasuretest.FakeClock()); meter.Connect();
reply = sprintf('OK00,1,06000\r\n');
port.queue('SCMR',reply,[2 3 numel(reply)-5],[0 .01 .02]);
report = meter.readSettings(); verifyEqual(t,report.values.frequencyHz,60);
port.queue('SPMR','');
% The late timeout closes the port before restoration can be confirmed.
verifyWarning(t,@() verifyError(t,@()meter.readSettings(),'CS2000:Timeout'),'CS2000:CleanupUnverified');
verifyTrue(t,state('deleted'));
commands = state('commands'); verifyEqual(t,commands{end},'SPMR');
end

function testBacklightAlreadyOffSkipsPersistentWritesAndStillRestoresChangedCase(t)
for normal = 0:1
    [meter,port,state] = colormeasuretest.cs2000.instrument(t);
    port.queue('BALR',sprintf('OK00,%d,0\r\n',normal));
    meter.Connect(); verifyTrue(t,meter.cleanupStatus.backlightRestored);
    meter.Disconnect();
    verifyFalse(t,any(startsWith(state('commands'),'BALS,')));
    verifyTrue(t,meter.cleanupStatus.backlightRestored);
end
[meter,~,state] = colormeasuretest.cs2000.instrument(t); meter.Connect(); meter.Disconnect();
commands = state('commands');
verifyEqual(t,commands(startsWith(commands,'BALS,')),{'BALS,1,0','BALS,1,1'});
verifyTrue(t,meter.cleanupStatus.backlightRestored);
end

function testSettingsReceiptAndReadingRoundTripRemainSeparate(t)
[meter,port,~] = colormeasuretest.cs2000.instrument(t); meter.Connect();
receipt = meter.applyAutomaticSettings();
port.queue('MEDR,0,0,1',sprintf('OK00,2,0,003000000,1,0,0,0,00\r\n'));
meter.Measure();
verifyEqual(t,meter.metadata(end).conditions.integrationTime,3);
verifyEqual(t,receipt.after.values.integrationTimeSeconds,1);
folder = tempname; mkdir(folder); t.addTeardown(@()rmdir(folder,'s'));
file = fullfile(folder,'settings-and-reading.mat');
measurements = meter.snapshot(); save(file,'measurements','receipt');
loaded = load(file);
verifyEqual(t,loaded.measurements,measurements); verifyEqual(t,loaded.receipt,receipt);
end

function commands = setters(state)
commands = state('commands');
commands = commands(startsWith(commands,{'SPMS,','SCMS,','LNSS,','NDFS,','UCCS,'}));
end

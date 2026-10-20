function tests = testMeasurementSettings
% Settings lifecycle with simulated adapters; no physical instrument access.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = fixture.Folder;
end

function testAutomaticProfileAppliedBeforeEveryReadingWithEmptyOverrides(t)
[s,e] = makeSession(t);
verifyTrue(t,s.measure()); verifyTrue(t,s.measure());
verifyEqual(t,e('order'),{'connect','apply','read','release','connect','apply','read','release'});
verifyEqual(t,e('overrides'),struct());
verifyEqual(t,e('applies'),2); verifyEqual(t,e('settingsReads'),0);
verifyEqual(t,s.measurements(1).instrumentSettings.policy,'automatic-with-overrides');
verifyEqual(t,s.measurements(1).instrumentSettings.overrides,struct());
verifyEqual(t,s.configuration,struct('timeout',30));
end

function testAdapterWithoutSettingsHookNeverReceivesSettingsOperations(t)
[s,e] = makeSession(t,false);
verifyEmpty(t,s.settingsCatalog); verifyEmpty(t,s.settingsSnapshot);
verifyTrue(t,s.setInstrumentSettings(struct()));
verifyError(t,@() s.refreshInstrumentSettings(),'Measurement:SettingsUnavailable');
verifyTrue(t,s.measure()); verifyEqual(t,e('applies'),0);
verifyEqual(t,e('settingsReads'),0); verifyTrue(t,isfield(s.measurements,'instrumentSettings'));
verifyEmpty(t,s.measurements.instrumentSettings);
end

function testChoiceMatchingTreatsCharAndStringTextAlike(t)
% Empty char and empty string are the same text, so each selects the other's
% choice; text still never selects a numeric instrument ID.
verifyEqual(t,colormeasure.session.settingsChoiceIndex(struct('value',{''}),""),1);
verifyEqual(t,colormeasure.session.settingsChoiceIndex(struct('value',{""}),''),1);
verifyEqual(t,colormeasure.session.settingsChoiceIndex(struct('value',{'Auto'}),"Auto"),1);
verifyEmpty(t,colormeasure.session.settingsChoiceIndex(struct('value',{0}),'0'));
end

function testCatalogAndStagingDoNotConnectOrRead(t)
[s,e] = makeSession(t);
before = e('order');
verifyEqual(t,s.settingsCatalog,catalog());
verifyTrue(t,s.setInstrumentSettings(struct('integration',0.5,'mode','Manual')));
verifyEqual(t,s.settingsOverrides,struct('integration',0.5,'mode','Manual'));
verifyEmpty(t,s.settingsSnapshot); verifyEqual(t,e('order'),before);
verifyEqual(t,e('connections'),0); verifyEqual(t,e('settingsReads'),0);
end

function testStagingRejectsUnknownUnavailableAndInvalidValuesAtomically(t)
[s,e] = makeSession(t);
valid = struct('integration',0.5); s.setInstrumentSettings(valid);
verifyError(t,@() s.setInstrumentSettings(struct('unknown',1)),'Measurement:UnknownSetting');
verifyError(t,@() s.setInstrumentSettings(struct('blocked',1)),'Measurement:SettingUnavailable');
for value = {0,3,NaN,Inf,[0.5 1],0.5+1i,'0.5',@() 1}
    verifyError(t,@() s.setInstrumentSettings(struct('integration',value{1})), ...
        'Measurement:InvalidSetting');
end
verifyError(t,@() s.setInstrumentSettings(struct('mode','Invalid')),'Measurement:InvalidSetting');
verifyError(t,@() s.setInstrumentSettings(struct([])),'Measurement:InvalidSettings');
verifyEqual(t,s.settingsOverrides,valid); verifyEqual(t,e('connections'),0);
end

function testExplicitReadReleasesWithoutMeasuringOrSaving(t)
[s,e] = makeSession(t);
verifyTrue(t,s.refreshInstrumentSettings());
verifyEqual(t,e('order'),{'connect','settings-read','release'});
verifyEqual(t,s.settingsSnapshot,report());
verifyEqual(t,e('reads'),0); verifyEqual(t,e('applies'),0);
verifyEmpty(t,s.files.folder); verifyEmpty(t,s.measurements); verifyFalse(t,s.busy);
verifyEmpty(t,dir(fullfile(t.TestData.folder,'batch_*')));
end

function testReadCatalogSuppliesActualCapabilitiesAndBounds(t)
[s,e] = makeSession(t); observed = report();
observed.controls(1).maximum = 0.75;
observed.controls(3).available = true;
e('report') = observed;
verifyTrue(t,s.refreshInstrumentSettings()); verifyEqual(t,s.settingsCatalog,observed.controls);
verifyError(t,@() s.setInstrumentSettings(struct('integration',1)),'Measurement:InvalidSetting');
verifyTrue(t,s.setInstrumentSettings(struct('integration',0.7,'blocked',1)));
verifyEqual(t,e('settingsReads'),1); verifyEqual(t,e('applies'),0);
end

function testPortChangeInvalidatesObservationAndReceipt(t)
[s,e] = makeSession(t); s.measure();
verifyNotEmpty(t,s.settingsSnapshot); verifyNotEmpty(t,s.lastSettingsReceipt);
same = s.settingsSnapshot; s.selectPort('VIRTUAL'); verifyEqual(t,s.settingsSnapshot,same);
s.selectPort('OTHER'); verifyEmpty(t,s.settingsSnapshot); verifyEmpty(t,s.lastSettingsReceipt);
verifyEqual(t,s.settingsCatalog,catalog()); verifyEqual(t,e('connections'),1);
end

function testDiscoveryPortChangeInvalidatesObservation(t)
[s,e] = makeSession(t); s.refreshInstrumentSettings();
e('ports') = "OTHER"; s.refreshPorts();
verifyEqual(t,s.port,'OTHER'); verifyEmpty(t,s.settingsSnapshot);
verifyEqual(t,e('settingsReads'),1);
end

function testDisconnectedPortRefusesReadAndInvalidatesObservation(t)
[s,e] = makeSession(t); s.refreshInstrumentSettings(); e('ports') = strings(0,1);
verifyFalse(t,s.refreshInstrumentSettings()); verifyEmpty(t,s.settingsSnapshot);
verifyEqual(t,e('connections'),1); verifyEqual(t,e('reads'),0); verifyFalse(t,s.busy);
end

function testSettingsReadFailureDoesNotReusePreviousObservation(t)
[s,e] = makeSession(t); s.refreshInstrumentSettings(); e('readSettingsError') = true;
verifyFalse(t,s.refreshInstrumentSettings()); verifyEmpty(t,s.settingsSnapshot);
verifyEqual(t,e('releases'),2); verifyEqual(t,e('reads'),0);
verifyTrue(t,any(contains({s.log.message},'Settings read failed')));
end

function testMalformedReportAndNonDataValuesAreRejected(t)
[s,e] = makeSession(t);
e('report') = struct('values',struct());
verifyFalse(t,s.refreshInstrumentSettings()); verifyEmpty(t,s.settingsSnapshot);
observed = report(); observed.responses = {@() 1}; e('report') = observed;
verifyFalse(t,s.refreshInstrumentSettings()); verifyEqual(t,e('releases'),2);
verifyEmpty(t,s.settingsSnapshot);
end

function testStagedOverridesAndSuccessfulReceiptAreSavedExactly(t)
[s,e] = makeSession(t); overrides = struct('integration',0.5,'mode','Manual');
s.setInstrumentSettings(overrides); verifyTrue(t,s.measure('Sample A','pending note'));
verifyEqual(t,e('overrides'),overrides);
verifyEqual(t,s.measurements.instrumentSettings,s.lastSettingsReceipt);
verifyEqual(t,s.lastSettingsReceipt.overrides,overrides);
saved = load(s.files.mat);
verifyEqual(t,saved.measurements.instrumentSettings,s.lastSettingsReceipt);
verifyEqual(t,saved.batchInfo.configuration,struct('timeout',30));
verifyEqual(t,s.settingsSnapshot,s.lastSettingsReceipt.after);
end

function testBuiltInDateAndDurationMetadataRoundTripWithoutHandles(t)
[s,e] = makeSession(t); value = receipt('applied');
identity = struct('factoryCalibration',struct( ...
    'dateTime',datetime(2025,4,3,12,0,0,'TimeZone','UTC'), ...
    'unreportedDateTime',NaT('TimeZone','UTC')), ...
    'warmupElapsed',minutes(30));
value.before.identity = identity; value.after.identity = identity;
e('receipt') = value;
verifyTrue(t,s.measure());
saved = load(s.files.mat); actual = saved.measurements.instrumentSettings;
verifyTrue(t,isequaln(actual.after.identity,identity));
verifyTrue(t,isnat(actual.after.identity.factoryCalibration.unreportedDateTime));
verifyClass(t,actual.after.identity.factoryCalibration.dateTime,'datetime');
verifyClass(t,actual.after.identity.warmupElapsed,'duration');
observed = report(); observed.readAtUTC = datetime('now','TimeZone','UTC');
e('report') = observed;
verifyFalse(t,s.refreshInstrumentSettings()); % The report timestamp stays text.
verifyEmpty(t,s.settingsSnapshot);
end

function testMalformedProducerTimestampIsRefusedBeforePublication(t)
[s,e]=makeSession(t);observed=report();observed.readAtUTC='not an instant';
e('report')=observed;
verifyFalse(t,s.refreshInstrumentSettings());verifyEmpty(t,s.settingsSnapshot);
verifyEqual(t,e('releases'),1);verifyEqual(t,e('reads'),0);
verifyTrue(t,any(contains({s.log.message},'InvalidSettingsReport')));
value=receipt('applied');value.after.readAtUTC='not an instant';e('receipt')=value;
verifyFalse(t,s.measure());verifyEmpty(t,s.measurements);verifyEqual(t,e('reads'),0);
verifyTrue(t,any(contains({s.log.message},'InvalidSettingsReport')));
end

function testMalformedReadCatalogDoesNotReachSessionListeners(t)
[s,e] = makeSession(t); invalid = cell(1,6);
invalid{1} = rmfield(catalog(),'label');
invalid{2} = catalog(); invalid{2}(2).id = invalid{2}(1).id;
invalid{3} = catalog(); invalid{3}(1).minimum = [0 1];
invalid{4} = catalog(); invalid{4}(1).available = [true false];
invalid{5} = catalog(); invalid{5}(1).help = rmfield(invalid{5}(1).help,'normal');
invalid{6} = catalog(); invalid{6}(2).choices = struct('value','Auto');
observedMalformed = false;
listener = addlistener(s,'Changed',@observe);
t.addTeardown(@() delete(listener));
for index = 1:numel(invalid)
    observed = report(); observed.controls = invalid{index}; e('report') = observed;
    verifyFalse(t,s.refreshInstrumentSettings());
    verifyEmpty(t,s.settingsSnapshot);
    verifyEqual(t,s.settingsCatalog,catalog());
end
verifyFalse(t,observedMalformed); verifyEqual(t,e('releases'),numel(invalid));
verifyEqual(t,e('reads'),0);
    function observe(~,~)
        if ~isempty(s.settingsSnapshot)
            observedMalformed = true;
        end
    end
end

function testClearingOverridesStagesAutomaticProfileWithoutIO(t)
[s,e] = makeSession(t); s.setInstrumentSettings(struct('mode','Manual'));
s.setInstrumentSettings(struct()); verifyEqual(t,e('connections'),0);
verifyTrue(t,s.measure()); verifyEqual(t,e('overrides'),struct());
verifyEqual(t,e('applies'),1);
end

function testFailedPartialReceiptPreventsExposureAndSurvivesExplicitRetry(t)
[s,e] = makeSession(t); failed = receipt('failed');
failed.commands = {'SET_A','SET_B'}; failed.acknowledgements = {'ACK','ERROR'};
failed.error = struct('identifier','Test:Partial','message','Second setting refused');
e('receipt') = failed; s.setSample('Keep sample','Keep notes');
verifyFalse(t,s.measure()); verifyEqual(t,e('reads'),0); verifyEqual(t,e('releases'),1);
verifyEqual(t,s.lastSettingsReceipt.commands,failed.commands);
verifyEqual(t,s.lastSettingsReceipt.acknowledgements,failed.acknowledgements);
verifyEqual(t,s.settingsSnapshot,failed.after); verifyFalse(t,s.busy);
verifyEqual(t,s.name,'Keep sample'); verifyEqual(t,s.notes,'Keep notes');
verifyEmpty(t,s.measurements); verifyEmpty(t,s.files.mat);
verifyEqual(t,e('applies'),1); % No automatic retry.
e('receipt') = receipt('applied'); verifyTrue(t,s.measure());
verifyEqual(t,e('applies'),2); verifyEqual(t,e('reads'),1);
verifyEqual(t,s.measurements.name,'Keep sample');
verifyEqual(t,s.lastSettingsReceipt.status,'applied');
end

function testUnknownAfterReportInvalidatesEarlierObservation(t)
[s,e] = makeSession(t); s.refreshInstrumentSettings();
value = receipt('failed'); value.after = struct([]); e('receipt') = value;
verifyFalse(t,s.measure()); verifyEmpty(t,s.settingsSnapshot);
verifyEqual(t,s.lastSettingsReceipt.status,'failed'); verifyEqual(t,e('reads'),0);
end

function testApplyExceptionOrMalformedReceiptPreventsExposure(t)
[s,e] = makeSession(t); s.refreshInstrumentSettings(); e('applyError') = true;
verifyFalse(t,s.measure()); verifyEmpty(t,s.settingsSnapshot); verifyEmpty(t,s.lastSettingsReceipt);
verifyEqual(t,e('reads'),0); verifyEqual(t,e('releases'),2);
e('applyError') = false; invalid = receipt('applied'); invalid.commands = {@() 1};
e('receipt') = invalid; verifyFalse(t,s.measure());
verifyEqual(t,e('reads'),0); verifyEqual(t,e('releases'),3);
verifyTrue(t,any(contains({s.log.message},'InvalidSettingsReceipt')));
end

function testUnchangedReceiptStillPermitsAcquisition(t)
[s,e] = makeSession(t); e('receipt') = receipt('unchanged');
verifyTrue(t,s.measure()); verifyEqual(t,s.lastSettingsReceipt.status,'unchanged');
verifyEqual(t,e('reads'),1);
end

function testBusyActionsCannotChangeOverridesOrReenterDuringApply(t)
[s,e] = makeSession(t); s.setInstrumentSettings(struct('integration',0.5));
e('applyHook') = @() nestedActions(s); verifyTrue(t,s.measure());
verifyEqual(t,s.settingsOverrides,struct('integration',0.5));
verifyEqual(t,e('connections'),1); verifyEqual(t,e('reads'),1);
verifyEqual(t,e('applies'),1); verifyEqual(t,e('settingsReads'),0);
verifyEqual(t,s.port,'VIRTUAL'); verifyFalse(t,s.busy);
end

function testBusyActionsCannotReenterDuringExplicitRead(t)
[s,e] = makeSession(t); e('settingsReadHook') = @() nestedActions(s);
verifyTrue(t,s.refreshInstrumentSettings());
verifyEqual(t,e('connections'),1); verifyEqual(t,e('settingsReads'),1);
verifyEqual(t,e('reads'),0); verifyEqual(t,e('applies'),0);
end

function testFinishDuringApplyCompletesCurrentActionThenFinalizes(t)
[s,e] = makeSession(t); e('applyHook') = @() s.finish();
verifyTrue(t,s.measure()); verifyTrue(t,s.finished);
verifyEqual(t,e('reads'),1); verifyEqual(t,e('releases'),1);
saved = load(s.files.mat); verifyTrue(t,saved.batchInfo.acquisitionComplete);
verifyEqual(t,saved.measurements.instrumentSettings,s.lastSettingsReceipt);
end

function testFinishDuringFailedApplyAcquiresNothingAndFinalizes(t)
[s,e] = makeSession(t); e('applyHook') = @() s.finish(); e('receipt') = receipt('failed');
verifyFalse(t,s.measure()); verifyTrue(t,s.finished); verifyEqual(t,e('reads'),0);
verifyEqual(t,e('releases'),1); verifyEqual(t,s.lastSettingsReceipt.status,'failed');
verifyFalse(t,isfolder(s.files.folder));
end

function testFinishDuringReadbackFinalizesWithoutExposure(t)
[s,e] = makeSession(t); e('settingsReadHook') = @() s.finish();
verifyTrue(t,s.refreshInstrumentSettings()); verifyTrue(t,s.finished);
verifyEqual(t,e('reads'),0); verifyEqual(t,e('releases'),1);
end

function testFinishedSessionRejectsSettingsActionsWithoutIO(t)
[s,e] = makeSession(t); s.finish();
verifyFalse(t,s.setInstrumentSettings(struct('mode','Manual')));
verifyFalse(t,s.refreshInstrumentSettings()); verifyFalse(t,s.measure());
verifyEqual(t,e('connections'),0); verifyEqual(t,s.settingsOverrides,struct());
end

function testSessionOwnsSettingsReceiptsEvenWhenAnAdapterReturnsOne(t)
[s,e] = makeSession(t,false); verifyTrue(t,s.measure());
newReading = struct('XYZ',[1 2 3],'instrumentSettings',receipt('applied'));
e('reading') = newReading; verifyTrue(t,s.measure());
verifyEmpty(t,s.measurements(1).instrumentSettings);
verifyEmpty(t,s.measurements(2).instrumentSettings);
e('reading') = struct('XYZ',[1 2 3]); verifyTrue(t,s.measure());
verifyEmpty(t,s.measurements(3).instrumentSettings);
saved = load(s.files.mat); verifyEqual(t,saved.measurements,s.measurements);
end

function nestedActions(s)
s.setInstrumentSettings(struct('mode','Manual'));
s.refreshInstrumentSettings(); s.measure(); s.selectPort('OTHER');
end

function [s,e] = makeSession(t,withSettings)
if nargin < 2, withSettings = true; end
e = containers.Map('KeyType','char','ValueType','any');
for name = {'connections','releases','reads','settingsReads','applies'}, e(name{1}) = 0; end
e('ports') = "VIRTUAL"; e('order') = {}; e('applyError') = false;
e('readSettingsError') = false; e('receipt') = receipt('applied'); e('report') = report();
e('applyHook') = []; e('settingsReadHook') = [];
e('reading') = struct('XYZ',[1 2 3]);
a = struct('key','settings-test','label','Settings test meter','configuration',struct('timeout',30), ...
    'listPorts',@(~) e('ports'),'connect',@(~) connect(e), ...
    'release',@(~) release(e),'read',@(~) read(e),'toTable',@toTable);
if withSettings
    a.settings = struct('catalog',catalog(),'read',@(~) readSettings(e), ...
        'apply',@(~,overrides) applySettings(e,overrides));
end
s = colormeasure.session.Session(a,t.TestData.folder);
t.addTeardown(@() delete(s));
end

function instrument = connect(e)
e('connections') = e('connections') + 1; event(e,'connect'); instrument = struct();
end
function release(e)
e('releases') = e('releases') + 1; event(e,'release');
end
function reading = read(e)
e('reads') = e('reads') + 1; event(e,'read'); reading = e('reading');
end
function value = readSettings(e)
e('settingsReads') = e('settingsReads') + 1; event(e,'settings-read');
hook = e('settingsReadHook'); if ~isempty(hook), hook(); end
if e('readSettingsError'), error('Test:SettingsRead','Injected readback failure.'); end
value = e('report');
end
function value = applySettings(e,overrides)
e('applies') = e('applies') + 1; e('overrides') = overrides; event(e,'apply');
hook = e('applyHook'); if ~isempty(hook), hook(); end
if e('applyError'), error('Test:SettingsApply','Injected application failure.'); end
value = e('receipt');
end
function event(e,name)
events = e('order'); events{end+1} = name; e('order') = events;
end
function value = report()
value = struct('values',struct('mode','Auto','integration',0.5), ...
    'controls',catalog(),'identity','Virtual settings meter', ...
    'readAtUTC','2026-09-17T12:00:00.000Z','responses',{{'SIMULATED'}});
end
function value = receipt(status)
value = struct('requested',struct('mode','Auto'),'before',report(),'after',report(), ...
    'commands',{{'AUTO'}},'acknowledgements',{{'ACK'}},'status',status, ...
    'error',struct('identifier','','message',''));
end
function value = catalog()
help = struct('meaning','Exposure duration.','whenToUse','Manual exposure.', ...
    'tradeoff','Longer readings.','normal','Automatic acquisition.','source','Simulated adapter.');
value = struct('id','integration','label','Integration','type','number', ...
    'choices',struct('value',{},'label',{}),'minimum',0.1,'maximum',2, ...
    'available',true,'help',help);
value(2) = value; value(2).id = 'mode'; value(2).label = 'Exposure mode';
value(2).type = 'choice'; value(2).minimum = NaN; value(2).maximum = NaN;
value(2).choices = struct('value',{'Auto','Manual'},'label',{'Automatic','Manual'});
value(3) = value(1); value(3).id = 'blocked'; value(3).available = false;
end
function value = toTable(readings,~)
value = table((1:numel(readings))',vertcat(readings.XYZ),'VariableNames',{'Index','XYZ'});
end

function testMalformedSettingsTimestampsAreRefusedBeforeAcquisition(t)
for timestamp={'not a UTC instant','2026-09-17T12:00:00.000',string(missing)}
    [s,e]=makeSession(t);
    bad=report();bad.readAtUTC=timestamp{1};e('report')=bad;
    verifyFalse(t,s.refreshInstrumentSettings());verifyEmpty(t,s.settingsSnapshot);
    applied=receipt('applied');applied.after=bad;e('receipt')=applied;
    verifyFalse(t,s.measure());verifyEmpty(t,s.measurements);verifyEqual(t,e('reads'),0);
    verifyEqual(t,e('releases'),2);verifyFalse(t,s.busy);
end
end

function testEmptySettingsTimestampIsAValidUnobservedSnapshot(t)
[s,e]=makeSession(t);unobserved=report();unobserved.readAtUTC='';e('report')=unobserved;
verifyTrue(t,s.refreshInstrumentSettings());verifyEqual(t,s.settingsSnapshot,unobserved);
end

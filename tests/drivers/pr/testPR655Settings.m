function tests = testPR655Settings
% Native settings contracts using the real parser and a virtual serial port.
% Fernando Voltolini de Azambuja, 2026. No physical instrument is accessed.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(~)
configure('PR-655');
end
function testCatalogIsLocalAndSeparatesExpertSettings(t)
before=colormeasuretest.pr.state(); c=colormeasure.drivers.pr.settingsCatalog(); after=colormeasuretest.pr.state();
verifyEqual(t,before,after);
verifyFalse(t,any(ismember({c.id},{'photometricUnits','instrumentObserver','shutterMode'})));
verifyFalse(t,c(strcmp({c.id},'apertureId')).available);
for control=c'
    verifyTrue(t,isvarname(control.id));
    verifyTrue(t,all(structfun(@(value) ~isempty(value),control.help)));
end
expert=colormeasure.drivers.pr.settingsCatalog('PR-670',struct(),true);
verifyTrue(t,all(ismember({'photometricUnits','instrumentObserver','shutterMode'},{expert.id})));
end
function testEmptyOverridesDoNotSendAnyCommand(t)
p=connect(t); before=colormeasuretest.pr.state(); receipt=p.applySettings(struct()); after=colormeasuretest.pr.state();
verifyEqual(t,receipt.status,'unchanged'); verifyEmpty(t,receipt.commands);
verifyEqual(t,before.commands,after.commands);
end
function testInvalidArgumentsFailBeforeAnyReadOrWrite(t)
p=connect(t); before=colormeasuretest.pr.state();
bad={struct('cycles',100),struct('cycles',1.5),struct('exposureMilliseconds',2), ...
    struct('unknown',1),struct('addon1Id',-1),struct('syncMode','guess')};
for index=1:numel(bad)
    verifyError(t,@() p.applySettings(bad{index}),'PR655:InvalidSettings');
end
verifyError(t,@() p.applySettings(struct('apertureId',0)),'PR655:UnsupportedSetting');
verifyError(t,@() p.applySettings(struct('smartDark',1)),'PR655:UnsupportedSetting');
after=colormeasuretest.pr.state();verifyEqual(t,before.commands,after.commands);
end
function testAutomaticRecipeResetsAcquisitionAndPreservesOptics(t)
state=colormeasuretest.pr.state();state.settingsNumeric=[9 7 -1 -1 0 1 1 100 0 3 10 0 0 0 60];colormeasuretest.pr.state(state);
p=connect(t); receipt=p.applyAutomaticSettings(struct());
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SE0','SN1','SS1'});
verifyEqual(t,receipt.after.values.exposureMilliseconds,0);
verifyEqual(t,receipt.after.values.cycles,1);verifyEqual(t,receipt.after.values.syncMode,'auto');
verifyEqual(t,receipt.after.values.primaryAccessoryId,9);verifyEqual(t,receipt.after.values.addon1Id,7);
verifyEqual(t,receipt.after.values.photometricUnits,'metric');verifyEqual(t,receipt.after.values.instrumentObserver,10);
state=colormeasuretest.pr.state();verifyFalse(t,any(strcmp(state.commands,'M5')));
verifyEqual(t,{receipt.acknowledgements.rawReply},{'0000','0000','0000'});
end
function testReadbackConfirmedSettingsAreNotWrittenAgain(t)
state=colormeasuretest.pr.state();state.settingsNumeric=[0 -1 -1 -1 0 0 0 0 0 1 2 0 1 0 60];colormeasuretest.pr.state(state);
p=connect(t); receipt=p.applyAutomaticSettings(struct());
verifyEqual(t,receipt.status,'unchanged');verifyEmpty(t,receipt.commands);
verifyEqual(t,receipt.before,receipt.after);
end
function testExplicitSyncOverrideAfterCompleteSyncError(t)
p=connect(t); initial=p.applyAutomaticSettings();
verifyNotEqual(t,initial.status,'failed');
state=colormeasuretest.pr.state(); frame=state.chunks;
state.chunks={sprintf('-10\r\n')}; colormeasuretest.pr.state(state);
verifyError(t,@() p.measure(),'PR655:InstrumentError');
verifyEmpty(t,p.radiance);
% Changing conditions and measuring again are separate explicit requests.
receipt=p.applyAutomaticSettings(struct('syncMode','none'));
verifyEqual(t,receipt.status,'applied');
verifyEqual(t,receipt.commands,{'SS0'});
verifyEqual(t,receipt.after.values.syncMode,'none');
state=colormeasuretest.pr.state(); verifyEqual(t,nnz(strcmp(state.commands,'M5')),1);
state.chunks=frame; colormeasuretest.pr.state(state);
p.measure();
verifySize(t,p.radiance,[101 1]);
state=colormeasuretest.pr.state(); verifyEqual(t,nnz(strcmp(state.commands,'M5')),2);
end
function testReadSettingsDiscoversReturnedIdsWithoutMeasuring(t)
p=connect(t); report=p.readSettings();
primary=report.controls(strcmp({report.controls.id},'primaryAccessoryId'));
addon=report.controls(strcmp({report.controls.id},'addon1Id'));
verifyEqual(t,[primary.choices.value],[0 9]);verifyEqual(t,[addon.choices.value],7);
verifyFalse(t,report.controls(strcmp({report.controls.id},'apertureId')).available);
verifyEqual(t,report.identity.model,'PR-655');verifyEqual(t,report.identity.softwareVersion,'2.22D');
verifyEmpty(t,report.values.shutterMode);verifyNotEmpty(t,report.readAtUTC);
state=colormeasuretest.pr.state();verifyFalse(t,any(strcmp(state.commands,'M5')));
end
function testUnknownReadbackDoesNotBecomeZero(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('D601',sprintf('-1000\r\n'));colormeasuretest.pr.state(state);
p=connect(t); report=p.readSettings();
verifyTrue(t,isnan(report.values.exposureMilliseconds));verifyTrue(t,isnan(report.values.primaryAccessoryId));
verifyEmpty(t,report.values.syncMode);verifyEqual(t,report.responses(1).status,'error');
end
function testDynamicSelectionsUseCalibrationIds(t)
p=connect(t); receipt=p.applySettings(struct('primaryAccessoryId',9,'addon1Id',7));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SP9','SA7'});
verifyEqual(t,receipt.after.values.primaryAccessoryId,9);verifyEqual(t,receipt.after.values.addon1Id,7);
end
function testUnknownDynamicIdRejectsBeforeAnySetter(t)
p=connect(t); receipt=p.applySettings(struct('cycles',3,'primaryAccessoryId',1));
verifyEqual(t,receipt.status,'failed');verifyEmpty(t,receipt.commands);
verifyEqual(t,receipt.error.identifier,'PR655:InvalidSettings');
state=colormeasuretest.pr.state();verifyFalse(t,any(startsWith(state.commands,'S')));
end
function testPR670ExtendedExposureAndReportedAperture(t)
configure('PR-670');p=connect(t);
receipt=p.applySettings(struct('sensitivityMode','extended','exposureMilliseconds',25000,'apertureId',2,'smartDark',1));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SH1','SE25000','SF2','SD1'});
verifyEqual(t,receipt.after.values.exposureMilliseconds,25000);verifyEqual(t,receipt.after.values.apertureId,2);
verifyEqual(t,receipt.after.controls(strcmp({receipt.after.controls.id},'exposureMilliseconds')).maximum,30000);
end
function testLowerExposureBeforeReturningToStandardSensitivity(t)
configure('PR-670');state=colormeasuretest.pr.state();state.settingsNumeric=[0 -1 -1 -1 0 0 1 25000 0 1 2 0 0 1 60];colormeasuretest.pr.state(state);
p=connect(t);receipt=p.applySettings(struct('sensitivityMode','standard','exposureMilliseconds',3000));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SE3000','SH0'});
end
function testPR670CapabilityAllowsStagingExtendedExposureFromStandard(t)
catalog=colormeasure.drivers.pr.settingsCatalog('PR-670',struct('sensitivityMode','standard'));
exposure=catalog(strcmp({catalog.id},'exposureMilliseconds'));
verifyEqual(t,exposure.maximum,30000);
verifyGreaterThanOrEqual(t,10000,exposure.minimum);verifyLessThanOrEqual(t,10000,exposure.maximum);
configure('PR-670');p=connect(t);
refused=p.applySettings(struct('exposureMilliseconds',10000));
verifyEqual(t,refused.status,'failed');verifyEmpty(t,refused.commands);
receipt=p.applySettings(struct('exposureMilliseconds',10000,'sensitivityMode','extended'));
verifyEqual(t,receipt.before.values.sensitivityMode,'standard');
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SH1','SE10000'});
verifyEqual(t,receipt.after.values.exposureMilliseconds,10000);
verifyEqual(t,receipt.after.values.sensitivityMode,'extended');
end
function testCoupledRequestValidatedBeforeFirstSetter(t)
configure('PR-670');p=connect(t);
receipt=p.applySettings(struct('cycles',2,'exposureMilliseconds',20000));
verifyEqual(t,receipt.status,'failed');verifyEmpty(t,receipt.commands);
receipt=p.applySettings(struct('syncFrequencyHz',120));
verifyEqual(t,receipt.status,'failed');verifyEmpty(t,receipt.commands);
receipt=p.applySettings(struct('syncMode','user','syncFrequencyHz',120));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SS3','SK120'});
end
function testPartialFailureReturnsReceiptAndBlocksExposure(t)
state=colormeasuretest.pr.state();state.settingsNumeric=[0 -1 -1 -1 0 0 1 100 0 3 2 0 0 0 60];
state.settingsFailureCommand='SN1';colormeasuretest.pr.state(state);p=connect(t);
receipt=p.applyAutomaticSettings(struct());
verifyEqual(t,receipt.status,'failed');verifyEqual(t,receipt.commands,{'SE0','SN1'});
verifyEqual(t,{receipt.acknowledgements.status},{'available','error'});
verifyEqual(t,receipt.error.identifier,'PR655:InstrumentError');verifyNotEmpty(t,receipt.before);
verifyError(t,@() p.measure(),'PR655:ReconnectRequired');
state=colormeasuretest.pr.state();verifyFalse(t,any(strcmp(state.commands,'M5')));
end
function testMalformedAcknowledgementBlocksExposure(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('SN3',sprintf('0000,extra\r\n'));colormeasuretest.pr.state(state);p=connect(t);
receipt=p.applySettings(struct('cycles',3));
verifyEqual(t,receipt.status,'failed');verifyEqual(t,receipt.error.identifier,'PR655:InvalidResponse');
verifyError(t,@() p.measure(),'PR655:ReconnectRequired');
end
function testAcknowledgementDoesNotHideContradictoryReadback(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('SE123',sprintf('0000\r\n'));colormeasuretest.pr.state(state);p=connect(t);
receipt=p.applySettings(struct('exposureMilliseconds',123));
verifyEqual(t,receipt.status,'failed');verifyEqual(t,receipt.error.identifier,'PR655:SettingsMismatch');
verifyEqual(t,receipt.after.values.exposureMilliseconds,0);
end
function testShutterAcknowledgementIsNotClaimedAsReadback(t)
p=connect(t);receipt=p.applySettings(struct('shutterMode','closeAfter'));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SZ0'});
verifyEmpty(t,receipt.after.values.shutterMode);
end
function testFinalReadbackAlsoChecksRequestedButInitiallyUnchangedFields(t)
state=colormeasuretest.pr.state();state.settingsAfterNumeric=[0 -1 -1 -1 0 0 1 100 0 3 2 0 0 0 60];
colormeasuretest.pr.state(state);p=connect(t);
receipt=p.applySettings(struct('exposureMilliseconds',100,'cycles',1));
verifyEqual(t,receipt.status,'failed');verifyEqual(t,receipt.commands,{'SE100'});
verifyEqual(t,receipt.error.identifier,'PR655:SettingsMismatch');
verifyEqual(t,receipt.after.values.cycles,3);
verifyError(t,@()p.measure(),'PR655:ReconnectRequired');
end
function testDuplicateAddonsRejectedAcrossRequestedAndInheritedSlots(t)
p=connect(t);receipt=p.applySettings(struct('cycles',3,'addon1Id',7,'addon2Id',7));
verifyEqual(t,receipt.status,'failed');verifyEmpty(t,receipt.commands);
verifySubstring(t,receipt.error.message,'more than one slot');
state=colormeasuretest.pr.state();state.settingsNumeric(2)=7;colormeasuretest.pr.state(state);
receipt=p.applySettings(struct('cycles',3,'addon2Id',7));
verifyEqual(t,receipt.status,'failed');verifyEmpty(t,receipt.commands);
verifySubstring(t,receipt.error.message,'more than one slot');
end
function testASecondAddonSlotAcceptsAReportedId(t)
% The positive control for the duplicate refusals: slot 2 takes the reported add-on.
p=connect(t);receipt=p.applySettings(struct('addon2Id',7));
verifyEqual(t,receipt.status,'applied');verifyEqual(t,receipt.commands,{'SB7'});
verifyEqual(t,receipt.after.values.addon2Id,7);
end
function testExtraDiscoveryRowsInvalidateTheReportedList(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('D112',sprintf('00000,2,4\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
verifyEqual(t,report.responses(end).command,'D116');verifyEqual(t,report.responses(end).status,'error');
verifyFalse(t,report.controls(strcmp({report.controls.id},'primaryAccessoryId')).available);
verifyError(t,@()p.measure(),'PR655:ReconnectRequired');
end
function testExcessiveDiscoveryCountsAreRefusedBeforeListing(t)
% D112 declares how many accessory rows D116 will return. Above 1024 it is
% refused at D112, so a corrupt count never drives a list request.
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('D112',sprintf('00000,1025,0\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
counts=report.responses(strcmp({report.responses.command},'D112'));
verifyEqual(t,counts.status,'error');verifyEqual(t,counts.errorIdentifier,'PR655:InvalidResponse');
verifyFalse(t,any(strcmp({report.responses.command},'D116')));
verifyError(t,@()p.measure(),'PR655:ReconnectRequired');
end
function testDuplicateDiscoveryIdsRequireReconnect(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct('D116',sprintf( ...
    '00000,0,Lens,Primary,Luminance,Radiance\r\n00000,0,Lens2,Primary,Luminance,Radiance\r\n00000,7,Filter,Addon,Luminance,Radiance\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
verifyEqual(t,report.responses(end).status,'error');
verifyFalse(t,report.controls(strcmp({report.controls.id},'primaryAccessoryId')).available);
verifyError(t,@() p.measure(),'PR655:ReconnectRequired');
end
function testComplexSetupFieldsAreRejected(t)
fields=[{'00000'} arrayfun(@num2str,[0 -1 -1 -1 0 0 0 0 0 1 2 0 0 0 60], ...
    'UniformOutput',false)];
for index=2:numel(fields)
    malformed=fields; malformed{index}='2+3i';
    verifyError(t,@()colormeasure.drivers.pr.settingsValues(malformed),'PR655:InvalidResponse');
end
end
function testComplexSetupReadbackIsReportedWithoutNormalizedValues(t)
state=colormeasuretest.pr.state();
state.settingsReplyOverrides=struct('D601',sprintf( ...
    '00000,0,-1,-1,-1,0,0,0,2+3i,0,1,2,0,0,0,60\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
assertMalformedSettingsReport(t,p,report,'D601');
verifyTrue(t,isnan(report.values.exposureMilliseconds));
verifyTrue(t,isnan(report.values.primaryAccessoryId));
verifyEqual(t,{report.responses(2:end).status},repmat({'notQueried'},1,4));
end
function testComplexCapabilityCountsStopDiscovery(t)
for counts={'1+2i,4','3,1+2i'}
    configure('PR-670');state=colormeasuretest.pr.state();
    state.settingsReplyOverrides=struct('D112',sprintf('00000,%s\r\n',counts{1}));
    colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
    assertMalformedSettingsReport(t,p,report,'D112');
    state=colormeasuretest.pr.state();
    verifyFalse(t,any(ismember(state.commands,{'D116','D117'})));
    verifyFalse(t,report.controls(strcmp({report.controls.id},'primaryAccessoryId')).available);
    verifyFalse(t,report.controls(strcmp({report.controls.id},'apertureId')).available);
    delete(p);
end
end
function testComplexAccessoryIdInvalidatesDiscovery(t)
state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct( ...
    'D112',sprintf('00000,1,0\r\n'), ...
    'D116',sprintf('00000,1+2i,Lens,Primary,Luminance,Radiance\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
assertMalformedSettingsReport(t,p,report,'D116');
verifyFalse(t,report.controls(strcmp({report.controls.id},'primaryAccessoryId')).available);
end
function testComplexApertureIdInvalidatesDiscovery(t)
configure('PR-670');state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct( ...
    'D112',sprintf('00000,0,1\r\n'), ...
    'D117',sprintf('00000,1+2i,1 deg,4\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
assertMalformedSettingsReport(t,p,report,'D117');
verifyFalse(t,report.controls(strcmp({report.controls.id},'apertureId')).available);
end
function testComplexApertureBandwidthInvalidatesDiscovery(t)
configure('PR-670');state=colormeasuretest.pr.state();state.settingsReplyOverrides=struct( ...
    'D112',sprintf('00000,0,1\r\n'), ...
    'D117',sprintf('00000,0,1 deg,2+3i\r\n'));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
assertMalformedSettingsReport(t,p,report,'D117');
verifyFalse(t,report.controls(strcmp({report.controls.id},'apertureId')).available);
end
function testOverflowTextFrequencyRemainsUnknownInSettingsReport(t)
state=colormeasuretest.pr.state();
reply=strrep(state.metadataReplies.D602,'60 Hertz',[repmat('9',1,400) ' Hertz']);
state.settingsReplyOverrides=struct('D602',sprintf('%s\r\n',reply));
colormeasuretest.pr.state(state);p=connect(t);report=p.readSettings();
verifyTrue(t,isnan(report.values.syncFrequencyHz));
% D602 retains descriptive text even when no finite frequency can be read.
response=report.responses(strcmp({report.responses.command},'D602'));
verifyEqual(t,response.status,'available');
verifySubstring(t,response.rawReply,repmat('9',1,400));
state=colormeasuretest.pr.state();verifyFalse(t,any(strcmp(state.commands,'M5')));
end
function assertMalformedSettingsReport(t,p,report,command)
response=report.responses(strcmp({report.responses.command},command));
verifyEqual(t,response.status,'error');
verifyEqual(t,response.errorIdentifier,'PR655:InvalidResponse');
values=struct2cell(report.values);
verifyTrue(t,all(cellfun(@(value)~isnumeric(value)||isreal(value),values)));
verifyError(t,@()p.measure(),'PR655:ReconnectRequired');
state=colormeasuretest.pr.state();verifyFalse(t,any(strcmp(state.commands,'M5')));
end
function testDemoModesUseSameValidationAndReceiptContract(t)
for model={'PR-655','PR-670'}
    p=colormeasure.drivers.pr.DemoInstrument(1,0,model{1});cleanup=onCleanup(@()delete(p));
    requests={struct('exposureMilliseconds',20),struct('cycles',3),struct('syncMode','none'), ...
        struct('syncMode','user','syncFrequencyHz',120),struct('addon1Id',7)};
    if strcmp(model{1},'PR-670')
        requests=[requests {struct('sensitivityMode','extended','exposureMilliseconds',8000), ...
            struct('smartDark',1),struct('apertureId',2)}]; %#ok<AGROW>
    end
    for index=1:numel(requests)
        receipt=p.applySettings(requests{index});verifyEqual(t,receipt.status,'applied');
        names=fieldnames(requests{index});
        for field=1:numel(names),verifyEqual(t,receipt.after.values.(names{field}),requests{index}.(names{field}));end
        verifyTrue(t,receipt.after.identity.isSynthetic);
    end
    receipt=p.applyAutomaticSettings(struct());verifyEqual(t,receipt.after.values.exposureMilliseconds,0);
    verifyEqual(t,receipt.after.values.cycles,1);verifyEqual(t,receipt.after.values.syncMode,'auto');
    reading=p.measure();verifyTrue(t,reading.isSynthetic);
    clear cleanup
end
end
function testDemoReadbackAndSettingsDoNotAdvanceSpectra(t)
p=colormeasure.drivers.pr.DemoInstrument(1,0);cleanup=onCleanup(@()delete(p));
p.readSettings();p.applyAutomaticSettings(struct());first=p.measure();
p.readSettings();p.applySettings(struct('cycles',3));p.readSettings();second=p.measure();
verifyEqual(t,first.syntheticProfileIndex,1);verifyEqual(t,second.syntheticProfileIndex,2);
verifyNotEqual(t,first.radiance,second.radiance);
end
function p=connect(t)
p=colormeasuretest.pr.Driver('VIRTUAL','Timeout',1,'Clock',colormeasuretest.FakeClock());t.addTeardown(@()delete(p));
end
function configure(model)
step=4;if strcmp(model,'PR-670'),step=2;end
frame=[sprintf('00000,0,0,1,1\r\n') sprintf('%d,1\r\n',380:step:780)];
colormeasuretest.pr.configure('Model',model,'D110','00000,SYNTHETIC-SETTINGS', ...
    'D13','00000,Normal,10 msec','Hertz','60 Hertz','Frame',frame);
end

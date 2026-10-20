function tests=testCS2000UISettings
% UI policy and synthetic settings; no ports or figures.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testUnknownChannelDoesNotAssignARetainedCorrectionName(t)
baseline=colormeasure.drivers.cs2000.settingsCatalog(struct(),'modern');
channel=strcmp({baseline.id},'userCalibrationChannel');
for value={NaN,Inf,-1,11,2.5,[],[1 2],1+1i,'3',"3",true}
    values=struct('userCalibrationChannel',value{1});
    actual=colormeasure.drivers.cs2000.settingsCatalog(values,'modern',struct('name','Retained name'));
    verifyEqual(t,actual(channel).choices,baseline(channel).choices);
end
end

function testKnownChannelOnlyLabelsItsOwnChoice(t)
for value=[0 1 10]
    values=struct('userCalibrationChannel',value);
    baseline=colormeasure.drivers.cs2000.settingsCatalog(values,'modern');
    channel=strcmp({baseline.id},'userCalibrationChannel');
    expected=baseline(channel).choices;
    if value>0,expected(value+1).label=sprintf('Ch%02d: Reference tile',value);end
    actual=colormeasure.drivers.cs2000.settingsCatalog(values,'modern',struct('name','Reference tile'));
    verifyEqual(t,actual(channel).choices,expected);
end
end


function testOnlyUIAdapterInstallsAutomaticPolicy(t)
plain=colormeasure.drivers.cs2000.adapter('PortList',@colormeasuretest.forbidPorts);
ui=colormeasure.drivers.cs2000.uiAdapter('PortList',@colormeasuretest.forbidPorts);
verifyFalse(t,isfield(plain,'settings')); verifyNotEmpty(t,ui.settings.catalog);
meter=struct('readSettings',@()struct('marker','current'), ...
    'applyAutomaticSettings',@(overrides)struct('marker','automatic','overrides',overrides));
observed=ui.settings.read(meter); verifyEqual(t,observed.marker,'current');
receipt=ui.settings.apply(meter,struct('speedMode',1));
verifyEqual(t,receipt.marker,'automatic'); verifyEqual(t,receipt.overrides.speedMode,1);
end

function testReadDoesNotConsumeProfileAndManualReturnsToAutomatic(t)
a=colormeasure.drivers.cs2000.demoAdapter();
a.settings.read(a.connect('CS2000_SYNTHETIC_ONLY'));
a.settings.read(a.connect('CS2000_SYNTHETIC_ONLY'));
first=a.read(a.connect('CS2000_SYNTHETIC_ONLY'));
verifyEqual(t,first.syntheticProfileIndex,1);
receipt=a.settings.apply([],struct('speedMode',3,'integrationTimeSeconds',.05, ...
    'internalNDMode',0,'closeupLens',1));
verifyEqual(t,receipt.status,'applied'); verifyTrue(t,receipt.synthetic);
observed=a.settings.read(a.connect('CS2000_SYNTHETIC_ONLY'));
verifyEqual(t,observed.values.speedMode,3); verifyEqual(t,observed.values.closeupLens,1);
automatic=a.settings.apply([],struct());
verifyEqual(t,automatic.after.values.speedMode,2);
verifyEqual(t,automatic.after.values.integrationTimeSeconds,1);
verifyEqual(t,automatic.after.values.internalNDMode,2);
verifyEqual(t,automatic.after.values.syncMode,0);
verifyEqual(t,automatic.after.values.closeupLens,1);
second=a.read([]); verifyEqual(t,second.syntheticProfileIndex,2);
verifyEmpty(t,fieldnames(second.instrumentMetadata));
end

function testCoupledInvalidDraftDoesNotChangeVirtualState(t)
a=colormeasure.drivers.cs2000.demoAdapter(); before=a.settings.read([]);
receipt=a.settings.apply([],struct('speedMode',3,'integrationTimeSeconds',.05));
verifyEqual(t,receipt.status,'failed'); verifyEmpty(t,receipt.commands);
after=a.settings.read([]); verifyEqual(t,after.values,before.values);
receipt=a.settings.apply([],struct('closeupLens',1,'externalNDFilter',1));
verifyEqual(t,receipt.status,'failed'); verifyEmpty(t,receipt.commands);
end

function testSessionSavesSettingsReadDoesNotAcquireAndConfigurationStaysFixed(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
s=colormeasure.session.Session(colormeasure.drivers.cs2000.demoAdapter(),folder.Folder); cleanup=onCleanup(@()delete(s));
configuration=s.configuration;
verifyTrue(t,s.refreshInstrumentSettings()); verifyEmpty(t,s.measurements);
verifyTrue(t,s.setInstrumentSettings(struct('syncMode',1,'frequencyHz',60)));
verifyEqual(t,s.configuration,configuration);
verifyTrue(t,s.measure('Periodic source','Synthetic settings demonstration'));
verifyEqual(t,s.measurements.syntheticProfileIndex,1);
verifyTrue(t,s.measurements.instrumentSettings.synthetic);
verifyEqual(t,s.measurements.instrumentSettings.after.values.frequencyHz,60);
stored=load(s.files.mat); verifyEqual(t,stored.measurements,s.measurements);
clear cleanup
end

function testRealNativeSettingsApplyBeforeOneSimulatedUIReading(t)
port=colormeasuretest.cs2000.Port(); state=port.State;
state('speedPayload')='3,120000000,0';
adapter=colormeasure.drivers.cs2000.uiAdapter('Transport',port,'PortList',@(~)"SIM_CS2000", ...
    'ResponseTimeout',.1);
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
s=colormeasure.session.Session(adapter,folder.Folder); cleanup=onCleanup(@()delete(s));
verifyTrue(t,s.measure('Radiance sample','Injected transport'));
verifyNumElements(t,s.measurements,1);
verifyEqual(t,s.measurements.instrumentSettings.after.values.speedMode,2);
verifyEqual(t,s.measurements.instrumentMetadata.acquisition.configurationBefore.speed.speedMode,2);
commands=state('commands');
verifyLessThan(t,find(strcmp(commands,'SPMS,2,1'),1),find(strcmp(commands,'MEAS,1'),1));
verifyEqual(t,nnz(strcmp(commands,'MEAS,1')),1); verifyTrue(t,state('deleted'));
stored=load(s.files.mat); verifyEqual(t,stored.measurements,s.measurements);
clear cleanup
end

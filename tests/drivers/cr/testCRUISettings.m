function tests=testCRUISettings
% Settings hooks and persistent virtual setup; no ports or figures.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testOnlyUIAdapterInstallsAutomaticPolicy(t)
for model={'CR100','CR250','CR300'}
    plain=colormeasure.drivers.cr.adapter(model{1},'PortList',@colormeasuretest.forbidPorts);
    ui=colormeasure.drivers.cr.uiAdapter(model{1},'PortList',@colormeasuretest.forbidPorts);
    verifyFalse(t,isfield(plain,'settings'));
    verifyNotEmpty(t,ui.settings.catalog);
    meter=struct('readSettings',@()struct('marker','current'), ...
        'applyAutomaticSettings',@(overrides)struct('marker','automatic','overrides',overrides));
    observed=ui.settings.read(meter); verifyEqual(t,observed.marker,'current');
    receipt=ui.settings.apply(meter,struct('exposureMultiplier',3));
    verifyEqual(t,receipt.marker,'automatic');
    verifyEqual(t,receipt.overrides.exposureMultiplier,3);
end
end

function testSettingsReadDoesNotConsumeProfilesAndOverridesSurviveReconnect(t)
for model={'CR100','CR250','CR300'}
    a=colormeasure.drivers.cr.demoAdapter(model{1});
    a.settings.read(a.connect('CR_SYNTHETIC_ONLY'));
    a.settings.read(a.connect('CR_SYNTHETIC_ONLY'));
    first=a.read(a.connect('CR_SYNTHETIC_ONLY'));
    verifyEqual(t,first.syntheticProfileIndex,1);
    overrides=struct('exposureMode',1,'exposureMs',25,'accessory',1);
    if strcmp(model{1},'CR100'), overrides.rangeMode=1; overrides.range=3; end
    receipt=a.settings.apply([],overrides);
    verifyEqual(t,receipt.status,'applied'); verifyTrue(t,receipt.synthetic);
    current=a.settings.read(a.connect('CR_SYNTHETIC_ONLY'));
    verifyEqual(t,current.values.exposureMode,1); verifyEqual(t,current.values.exposureMs,25);
    restored=a.settings.apply([],struct());
    verifyEqual(t,restored.after.values.exposureMode,0);
    verifyEqual(t,restored.after.values.accessory,1);
    if strcmp(model{1},'CR100')
        verifyEqual(t,restored.after.values.rangeMode,0); verifyEqual(t,restored.after.values.mode,0);
    end
    second=a.read([]); verifyEqual(t,second.syntheticProfileIndex,2);
    verifyEmpty(t,fieldnames(second.instrumentMetadata));
end
end

function testInvalidCoupledDraftDoesNotChangeVirtualSettings(t)
a=colormeasure.drivers.cr.demoAdapter('CR100'); before=a.settings.read([]);
receipt=a.settings.apply([],struct('exposureMode',1,'exposureMs',20));
verifyEqual(t,receipt.status,'failed'); verifyEmpty(t,receipt.commands);
after=a.settings.read([]); verifyEqual(t,after.values,before.values);
verifyError(t,@()a.settings.apply([],struct('mode',1)),'CR:SettingsArgument');
end

function testSessionSavesSettingsAndReadDoesNotAcquire(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250'),folder.Folder);
cleanup=onCleanup(@()delete(s));
configuration=s.configuration;
verifyTrue(t,s.refreshInstrumentSettings()); verifyEmpty(t,s.measurements);
verifyTrue(t,s.setInstrumentSettings(struct('speed',0)));
verifyEqual(t,s.configuration,configuration);
verifyTrue(t,s.measure('Low light example','Synthetic settings demonstration'));
verifyEqual(t,s.measurements.syntheticProfileIndex,1);
verifyTrue(t,s.measurements.instrumentSettings.synthetic);
verifyEqual(t,s.measurements.instrumentSettings.after.values.speed,0);
stored=load(s.files.mat); verifyEqual(t,stored.measurements,s.measurements);
clear cleanup
end

function testRealNativeSettingsApplyBeforeOneSimulatedUIReading(t)
port=colormeasuretest.cr.SettingsPort('CR-100'); state=port.State;
port.Setup('Mode')=1;
adapter=colormeasure.drivers.cr.uiAdapter('CR100','DriverFactory',@construct,'PortList',@(~)"SIM", ...
    'ResponseTimeout',.1,'MeasurementTimeout',.2);
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
s=colormeasure.session.Session(adapter,folder.Folder); cleanup=onCleanup(@()delete(s));
verifyTrue(t,s.measure('XYZ sample','Injected transport'));
verifyNumElements(t,s.measurements,1);
verifyEqual(t,s.measurements.instrumentSettings.after.values.mode,0);
verifyEqual(t,s.measurements.instrumentSettings.after.values.exposureMode,0);
commands=state('commands');
verifyLessThan(t,find(strcmp(commands,'SM Mode 0'),1),find(strcmp(commands,'M'),1));
verifyEqual(t,nnz(strcmp(commands,'M')),1); verifyTrue(t,state('deleted'));
stored=load(s.files.mat); verifyEqual(t,stored.measurements,s.measurements);
clear cleanup
    function meter=construct(model,name,varargin)
        constructor=str2func(['colormeasure.drivers.cr.' model]);
        meter=constructor(name,varargin{:},'Transport',port);
    end
end

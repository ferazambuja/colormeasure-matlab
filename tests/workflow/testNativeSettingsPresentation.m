function tests=testNativeSettingsPresentation
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testCSOnlyNamesTheChannelActuallyRead(t)
values=struct('speedMode',2,'userCalibrationChannel',3);
controls=colormeasure.drivers.cs2000.settingsCatalog(values,'modern',struct('name','Lab tile'));
channel=controls(strcmp({controls.id},'userCalibrationChannel'));
verifyEqual(t,channel.choices(4).label,'Ch03: Lab tile');
verifyEqual(t,channel.choices(2).label,'Ch01: name not read');
verifySubstring(t,channel.choices(1).label,'manufacturer calibration');
verifyEqual(t,[channel.choices.value],0:10);
end
function testPRFixedRangesPreserveAdaptiveZero(t)
for entry={{'PR-655',3,6000},{'PR-670',6,30000}}
    values=entry{1};controls=colormeasure.drivers.pr.settingsCatalog(values{1},struct('sensitivityMode','extended'));
    for duration=[0 values{2} values{3}]
        colormeasure.session.validateSettingsOverrides(struct('exposureMilliseconds',duration),controls);
    end
    for duration=[1 values{2}-1 values{3}+1 values{2}+0.5 NaN]
        verifyError(t,@()colormeasure.session.validateSettingsOverrides( ...
            struct('exposureMilliseconds',duration),controls),'Measurement:InvalidSetting');
    end
end
end
function testPR670CanStageExtendedWithItsLongerExposure(t)
controls=colormeasure.drivers.pr.settingsCatalog('PR-670',struct('sensitivityMode','standard'));
verifyError(t,@()colormeasure.session.validateSettingsOverrides(struct('exposureMilliseconds',6001),controls), ...
    'Measurement:InvalidSetting');
colormeasure.session.validateSettingsOverrides(struct('exposureMilliseconds',30000,'sensitivityMode','extended'),controls);
end
function testCSContextUsesTargetRecipeUnlessSpeedWasExplicitlyOverridden(t)
controls=colormeasure.drivers.cs2000.settingsCatalog(struct('speedMode',3),'modern');
interval=controls(strcmp({controls.id},'integrationTimeSeconds'));
target=colormeasure.session.settingsControlForValues(interval,struct());
verifyEqual(t,target.label,'Multi averaging interval (s)');verifyEqual(t,target.minimum,1);
colormeasure.session.validateSettingsOverrides(struct('speedMode',3,'integrationTimeSeconds',0.005),controls);
verifyError(t,@()colormeasure.session.validateSettingsOverrides(struct('speedMode',3,'integrationTimeSeconds',0.0050001),controls), ...
    'Measurement:InvalidSetting');
verifyError(t,@()colormeasure.session.validateSettingsOverrides(struct('integrationTimeSeconds',0.5),controls), ...
    'Measurement:InvalidSetting');
verifyError(t,@()colormeasure.session.validateSettingsOverrides(struct('speedMode',2,'integrationTimeSeconds',1.5),controls), ...
    'Measurement:InvalidSetting');
verifyError(t,@()colormeasure.session.validateSettingsOverrides(struct('speedMode',0,'integrationTimeSeconds',1),controls), ...
    'Measurement:SettingUnavailable');
% The refusal names the staged context, not a missing readback.
try
    colormeasure.session.validateSettingsOverrides(struct('speedMode',1,'integrationTimeSeconds',1),controls);
    verifyFail(t,'An interval under Fast must be refused.');
catch problem
    verifySubstring(t,problem.message,'Fast determines exposure automatically; clear the interval override.');
    verifyFalse(t,contains(problem.message,'Read the instrument settings'));
end
[observed,name]=colormeasure.session.settingsControlForValues(interval,struct(),false);
verifyEqual(t,observed.label,interval.label);verifyEqual(t,name,'speed not read');
verifyEqual(t,interval,controls(strcmp({controls.id},'integrationTimeSeconds')));
end

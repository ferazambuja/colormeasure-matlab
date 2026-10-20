function tests=testCRLaunchers
% Public output/workspace semantics with a scoped shared-launch stub; no UI.
tests=functiontests(localfunctions);
end

function setup(t)
previousPath=path; t.addTeardown(@() path(previousPath));
colormeasuretest.setupPaths(t);
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
mkdir(fullfile(f.Folder,'+colormeasure','+ui'));
file=fopen(fullfile(f.Folder,'+colormeasure','+ui','launchSession.m'),'w');
assert(file>=0); cleanup=onCleanup(@() fclose(file));
fprintf(file,['function s=launchSession(a,varargin)\n' ...
    's=struct(''key'',a.key,''workspaceName'',a.workspaceName,''configuration'',a.configuration);\nend\n']);
clear cleanup
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(f.Folder));
clear colormeasure.ui.launchSession
t.addTeardown(@clearLaunch);
end

function testLiveLaunchersReturnAndPublishSeparateHandles(t)
for model={'CR100','CR250','CR300'}
    name=['colorMeasure' model{1} 'Session']; colormeasuretest.preserveWorkspace(t,name);
    launch=str2func(['colormeasure.drivers.cr.measure' model{1}]); session=launch();
    verifyEqual(t,session.key,model{1}); verifyEqual(t,session.workspaceName,name);
    launch(); verifyEqual(t,evalin('base',name),session);
end
end

function testPublicLauncherForwardsExplicitDeadlineOptions(t)
session=colormeasure.drivers.cr.measureCR250('ResponseTimeout',uint8(7),'MeasurementTimeout',single(90));
verifyEqual(t,session.configuration.ResponseTimeout,7);
verifyEqual(t,session.configuration.MeasurementTimeout,90);
verifyEqual(t,session.configuration.model,'CR250');
end

function testInteractiveDemoLaunchersReturnAndPublishTheirSession(t)
for model={'CR100','CR250','CR300'}
    name=['colorMeasure' model{1} 'DemoSession']; colormeasuretest.preserveWorkspace(t,name);
    launch=str2func(['colormeasure.drivers.cr.demo' model{1}]); session=launch();
    verifyEqual(t,session.key,[model{1} 'Demo']);
    verifyEqual(t,session.workspaceName,name);
    launch(); verifyEqual(t,evalin('base',name),session);
end
end

function clearLaunch
clear colormeasure.ui.launchSession
end

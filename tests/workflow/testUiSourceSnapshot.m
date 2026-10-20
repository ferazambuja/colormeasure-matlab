function tests=testUiSourceSnapshot
% Source lifetime is independent of timestamps and does not alter source.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testPresentationAndRuntimeAreDistinguishedByExactBytes(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
mkdir(fullfile(f.Folder,'+ui'));ui=fullfile(f.Folder,'+ui','View.m');runtime=fullfile(f.Folder,'Session.m');
write(ui,'before');write(runtime,'core');a=colormeasure.ui.sourceSnapshot(f.Folder);
verifyEqual(t,a,colormeasure.ui.sourceSnapshot(f.Folder));
write(ui,'after');b=colormeasure.ui.sourceSnapshot(f.Folder);
verifyNotEqual(t,a.presentation,b.presentation);verifyEqual(t,a.runtime,b.runtime);
write(runtime,'next');c=colormeasure.ui.sourceSnapshot(f.Folder);
verifyEqual(t,b.presentation,c.presentation);verifyNotEqual(t,b.runtime,c.runtime);
end
function testDirectDemoOpensOnlyItsPracticeWindowByDefault(t)
s=fileread(fullfile(colormeasure.root(),'demoDirectInstruments.m'));
verifySubstring(t,s,"directShowGallery = false;");
end
function write(file,value)
fid=fopen(file,'w');cleanup=onCleanup(@()fclose(fid));fwrite(fid,value);
end

function testSourceEditLifecycleInIsolatedInstallation(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root=fullfile(f.Folder,'installation');mkdir(root);
for name={'src','resources','tests'}
    copyfile(fullfile(colormeasure.root(),name{1}),fullfile(root,name{1}));
end
for name={'startup','finish'},write(fullfile(f.Folder,[name{1} '.m']),'% Isolated reload check.');end
guards=fullfile(f.Folder,'hardware-guards');mkdir(guards);
for name=colormeasuretest.serialGuardNames()
    write(fullfile(guards,[name{1} '.m']),sprintf([ ...
        'function varargout=%s(varargin)\n' ...
        'error(''measurement:HardwareForbidden'',''Source reload checks cannot call %s.'');\nend\n'],name{1},name{1}));
end
processArguments=java.util.ArrayList;processArguments.add(fullfile(matlabroot,'bin','matlab'));
if ispc,processArguments.set(0,fullfile(matlabroot,'bin','matlab.exe'));processArguments.add('-wait');end
processArguments.add('-noFigureWindows');processArguments.add('-batch');
processArguments.add(['restoredefaultpath; r=getenv(''COLORMEASURE_RELOAD_ROOT''); ' ...
    'o=getenv(''COLORMEASURE_RELOAD_OUTPUT''); addpath(fullfile(r,''src'')); ' ...
    'addpath(fullfile(r,''tests'')); ' ...
    'addpath(fullfile(o,''hardware-guards'')); colormeasuretest.uiReloadChecks(o);']);
builder=java.lang.ProcessBuilder(processArguments);builder.directory(java.io.File(f.Folder));
builder.environment().put('COLORMEASURE_RELOAD_ROOT',root);
builder.environment().put('COLORMEASURE_RELOAD_OUTPUT',f.Folder);
process=colormeasuretest.startWorkerProcess(builder,f.Folder,'');
cleanup=onCleanup(@()colormeasuretest.finishWorkers({process},{''}));
% Include process startup and shutdown as well as the reload checks. Under
% concurrent gates, all checks can finish before the process exits.
finished=process.waitFor(180,java.util.concurrent.TimeUnit.SECONDS);
childLog=fileread(fullfile(f.Folder,'matlab.log'));
fprintf('%s',childLog); % Retain named subchecks in the parent run's log.
assertTrue(t,finished,'Isolated source-reload check exceeded 180 seconds.');
verifyEqual(t,process.exitValue(),0,childLog);
verifyFalse(t,contains(childLog,{'Error while evaluating TimerFcn','Error while evaluating ErrorFcn', ...
    'Unable to find function','error was caught while executing','Error executing listener callback'}),childLog);
checks=jsondecode(fileread(fullfile(f.Folder,'reload-checks.json')));
verifyNumElements(t,checks,15);verifyTrue(t,all([checks.passed]));
end

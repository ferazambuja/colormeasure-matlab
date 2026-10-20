function tests = testMeasurementLifecycle
% Session ownership and explicit finalization, using a virtual colorimeter.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
state = warning('error','Measurement:Display');
t.addTeardown(@() warning(state));
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = fixture.Folder;
visibility = get(groot, 'DefaultFigureVisible');
t.addTeardown(@() set(groot, 'DefaultFigureVisible', visibility));
set(groot, 'DefaultFigureVisible', 'off');
end

function testClearingFunctionsAndThenEverythingKeepsTheSameSession(t)
% Root appdata survives both `clear functions` and `clear all`; each is
% followed by a relaunch that finds the same batch, window and readings.
[a,io,e] = adapter(t);
s = open(t,a,io); s.measure('Retained sample','before clearing');
original = s.window; snapshot = s.measurements;
evalin('base', 'clear functions');
restored = colormeasure.ui.launchSession(a,io);
verifyEqual(t, restored,s,'after clear functions');
verifyEqual(t, restored.window,original);
verifyEqual(t, restored.measurements,snapshot);
verifyEqual(t, e('folderCalls'),1);
printed = evalc('colormeasure.ui.launchSession(a,io);');
verifySubstring(t, printed, ' | 1 reading.');
assignin('base','measurementLifecycleClearProbe',true);
evalin('base','clear all');
verifyFalse(t,evalin('base','exist(''measurementLifecycleClearProbe'',''var'') == 1'));
restored = colormeasure.ui.launchSession(a,io);
verifyEqual(t, restored,s,'after clear all');
verifyEqual(t, restored.measurements,snapshot);
verifyEqual(t, e('folderCalls'),1);
end

function testHideAndClosePreserveUnfinishedBatchAndRestoreWindow(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.measure();
original = s.window; before = dir(s.files.mat);
set(original,'Visible','on'); close(original);
verifyTrue(t,isgraphics(original)); verifyEqual(t,char(get(original,'Visible')),'off');
verifyFalse(t,s.finishing); verifyFalse(t,s.finished); verifyEmpty(t,s.files.csv);
verifyEqual(t,dir(s.files.mat),before);
restored = colormeasure.ui.launchSession(a,io);
verifyEqual(t,restored,s); verifyEqual(t,restored.window,original);
verifyEqual(t,char(get(original,'Visible')),'on'); verifyEqual(t,e('folderCalls'),1);
end

function testForceDeletedWindowRecreatedForSameBatch(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.measure();
original = s.window; delete(original);
restored = colormeasure.ui.launchSession(a,io);
verifyEqual(t,restored,s); verifyTrue(t,isgraphics(restored.window));
verifyNotEqual(t,restored.window,original); verifyNumElements(t,restored.measurements,1);
verifyEqual(t,e('folderCalls'),1);
end

function testFinishKeepsViewAndRelaunchRestoresFinishedResults(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.measure();
original = s.window; s.finish();
verifyTrue(t,s.finished); verifyEqual(t,s.window,original);
verifyTrue(t,isgraphics(original)); verifyTrue(t,isfile(s.files.csv));
s.hide(); restored = colormeasure.ui.launchSession(a,io);
verifyEqual(t,restored,s); verifyEqual(t,char(get(original,'Visible')),'on');
verifyEqual(t,e('folderCalls'),1);
verifyFalse(t,s.measure()); verifyNumElements(t,s.measurements,1);
end

function testEmptyFinishKeepsReviewView(t)
[a,io,~] = adapter(t); s = open(t,a,io); original = s.window;
s.finish();
verifyTrue(t,s.finished); verifyEqual(t,s.window,original);
verifyTrue(t,isgraphics(original)); verifyEmpty(t,s.files.folder);
end

function testCancelledNewBatchKeepsFinishedViewAndData(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.measure(); s.finish();
original = s.window; snapshot = s.measurements; files = s.files;
e('cancel') = true;
replacement = s.newBatch();
verifyEmpty(t,replacement); verifyEqual(t,s.window,original);
verifyEqual(t,s.measurements,snapshot); verifyEqual(t,s.files,files);
verifyEqual(t,colormeasure.ui.launchSession(a,io),s); verifyEqual(t,e('folderCalls'),2);
end

function testNewBatchReplacesViewButKeepsOldHandleReadable(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.measure(); s.finish();
snapshot = s.measurements; files = s.files; original = s.window;
replacement = s.newBatch(); t.addTeardown(@() colormeasuretest.dispose(replacement));
verifyNotEqual(t,replacement,s); verifyTrue(t,isgraphics(replacement.window));
verifyEmpty(t,replacement.measurements); verifyFalse(t,replacement.finished);
verifyTrue(t,isvalid(s)); verifyEqual(t,s.measurements,snapshot); verifyEqual(t,s.files,files);
verifyFalse(t,isgraphics(original)); verifyEmpty(t,s.window);
verifyEqual(t,colormeasure.ui.launchSession(a,io),replacement); verifyEqual(t,e('folderCalls'),2);
s.show(); verifyTrue(t,isgraphics(s.window)); % An explicit old handle can reopen its review.
end

function testFailedNewBatchConstructionKeepsPriorRegistryAndView(t)
[a,io,e] = adapter(t); s = open(t,a,io); s.finish(); original = s.window;
e('failClock') = true;
verifyError(t,@() s.newBatch(),'Test:Clock');
verifyEqual(t,s.window,original); verifyTrue(t,isgraphics(original));
verifyEqual(t,colormeasure.ui.launchSession(a,io),s);
end

function testNewBatchBlockedBeforeFinishAndWhileBusy(t)
[a,io,e] = adapter(t); s = open(t,a,io);
verifyEmpty(t,s.newBatch()); verifyEqual(t,e('folderCalls'),1);
e('readHook') = @() verifyEmpty(t,s.newBatch());
s.measure(); verifyEqual(t,e('folderCalls'),1); verifyNumElements(t,s.measurements,1);
end

function testExplicitDeletionPrunedBeforeRelaunch(t)
[a,io,e] = adapter(t); s = open(t,a,io); delete(s);
replacement = open(t,a,io);
verifyTrue(t,isvalid(replacement)); verifyTrue(t,isgraphics(replacement.window));
verifyEqual(t,e('folderCalls'),2);
end

function testNewBatchPublishesOptionalWorkspaceHandle(t)
[a,io,~] = adapter(t); a.workspaceName = 'measurementLifecyclePublished';
t.addTeardown(@() evalin('base','clear measurementLifecyclePublished'));
s = open(t,a,io); s.finish(); replacement = s.newBatch();
t.addTeardown(@() colormeasuretest.dispose(replacement));
verifyEqual(t,evalin('base',a.workspaceName),replacement);
end

function testIdentityAndRestorationSummary(t)
[a,io,~] = adapter(t); s = open(t,a,io); s.measure();
verifyEqual(t,s.startedAtUTC,'2026-09-16T12:00:00.000Z');
verifyEqual(t,s.info.sessionStartedAtUTC,s.startedAtUTC);
verifyEqual(t,s.destination,s.files.folder);
output = evalc('colormeasure.ui.launchSession(a,io);');
verifyTrue(t,contains(output,s.startedAtUTC)); verifyTrue(t,contains(output,'1 reading'));
verifyTrue(t,contains(output,s.files.folder)); verifyTrue(t,contains(output,'no automatic expiry'));
end

function testRestoringCannotSilentlyIgnoreChangedConnectionSettings(t)
[a,io,e]=adapter(t);
a.configuration=struct('BaudRate',115200,'FlowControl','none');
a.configurationSummary='USB: 115200 baud, no flow control';
s=open(t,a,io);s.measure();saved=s.measurements;
verifyEqual(t,s.configuration,a.configuration);
onDisk=load(s.files.mat);verifyEqual(t,onDisk.batchInfo.configuration,a.configuration);
verifyTrue(t,any(contains({s.log.message},a.configurationSummary)));
changed=a;changed.configuration.BaudRate=9600;changed.configuration.FlowControl='hardware';
verifyError(t,@() colormeasure.ui.launchSession(changed,io),'Measurement:SessionConfiguration');
verifyEqual(t,s.measurements,saved);verifyEqual(t,e('folderCalls'),1);
verifyEqual(t,colormeasure.ui.launchSession(a,io),s);
s.finish();verifyError(t,@() colormeasure.ui.launchSession(changed,io),'Measurement:SessionConfiguration');
delete(s);next=open(t,changed,io);
verifyEqual(t,next.configuration,changed.configuration);verifyEmpty(t,next.measurements);
end

function testCurrentSessionRuntimeCheckDoesNotOpenABatch(t)
before = getappdata(groot,'ColorMeasureSessions');
colormeasure.session.assertSessionCompatible();
verifyEqual(t,getappdata(groot,'ColorMeasureSessions'),before);
end

function testLegacySessionMetaclassIsRefusedWithoutTouchingTheRegistry(t)
% The check takes a metaclass, so it cannot reach the session's data; what
% it must not do is register, prune or finish anything.
legacy = colormeasuretest.session.LegacySession();
t.addTeardown(@() delete(legacy));
before = getappdata(groot,'ColorMeasureSessions');
verifyError(t,@() colormeasure.session.assertSessionCompatible(metaclass(legacy)), ...
    'Measurement:SessionCompatibility');
verifyTrue(t,isvalid(legacy));
verifyFalse(t,legacy.finished);
verifyEqual(t,getappdata(groot,'ColorMeasureSessions'),before);
end

function s = open(t,a,io)
s = colormeasure.ui.launchSession(a,io);
t.addTeardown(@() colormeasuretest.dispose(s));
end

function [a,io,e] = adapter(t)
e = containers.Map('KeyType','char','ValueType','any');
e('folderCalls') = 0; e('cancel') = false; e('failClock') = false; e('readHook') = [];
a = struct('key',t.TestData.folder,'label','Lifecycle test colorimeter', ...
    'listPorts',@(~) "VIRTUAL",'connect',@(~) colormeasuretest.session.Instrument(@() reading(e),@() []), ...
    'read',@(instrument) instrument.Read(),'release',@(instrument) delete(instrument), ...
    'toTable',@toTable);
io = colormeasure.session.services(); io.isMac = false;
io.chooseFolder = @(~) chooseFolder(t.TestData.folder,e);
io.now = @() clock(e);
end

function folder = chooseFolder(destination,e)
e('folderCalls') = e('folderCalls') + 1;
if e('cancel'), folder = ''; else, folder = destination; end
end

function value = clock(e)
if e('failClock'), error('Test:Clock','Injected clock failure.'); end
value = datetime(2026,9,16,12,0,0,'TimeZone','UTC');
end

function value = reading(e)
hook = e('readHook'); if ~isempty(hook), hook(); end
value = struct('XYZ',[1 2 3]);
end

function value = toTable(m,~)
value = table((1:numel(m))',{m.name}',vertcat(m.XYZ),'VariableNames',{'Index','Name','XYZ'});
end

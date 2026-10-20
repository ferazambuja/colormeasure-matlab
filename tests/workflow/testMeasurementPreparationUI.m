function tests = testMeasurementPreparationUI
% Exercise the real modal help with virtual instruments and native actions.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = folder.Folder;
visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',visibility));
end

function testNativeCancelPreservesDraftAndDoesNotConnect(t)
[s,calls] = session(t); s.show();
set(colormeasuretest.control(s.window,'SampleName'),'String','Pending sample');
runDialog(t,s,'MeasureButton','PreparationCancel',true);
verifyEqual(t,calls('connect'),0); verifyEqual(t,calls('read'),0);
verifyEmpty(t,s.measurements);
verifyEqual(t,get(colormeasuretest.control(s.window,'SampleName'),'String'),'Pending sample');
end

function testNativeReadyContinuesOneExplicitMeasurement(t)
[s,calls] = session(t); s.show();
runDialog(t,s,'MeasureButton','PreparationReady',true);
% A failed measure action is only logged, so show the log if nothing ran.
journal = strjoin(string({s.log.message}),newline);
verifyEqual(t,calls('connect'),1,journal); verifyEqual(t,calls('read'),1,journal);
verifyNumElements(t,s.measurements,1);
verifyEqual(t,calls('release'),1);
end

function testReadyDuringDialogShowKeepsTheFirstResponseAndMeasuresOnce(t)
[s,calls]=session(t);s.show();
runEarlyDialog(t,s,'PreparationReady','PreparationCancel');
journal=strjoin(string({s.log.message}),newline);
verifyEqual(t,calls('connect'),1,journal);verifyEqual(t,calls('read'),1,journal);
verifyNumElements(t,s.measurements,1);verifyEqual(t,calls('release'),1);
end

function testCancelDuringDialogShowKeepsTheDraftAndDoesNotMeasure(t)
[s,calls]=session(t);s.show();
set(colormeasuretest.control(s.window,'SampleName'),'String','Pending sample');
runEarlyDialog(t,s,'PreparationCancel','PreparationReady');
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('read'),0);
verifyEmpty(t,s.measurements);verifyEqual(t,calls('release'),0);
verifyEqual(t,get(colormeasuretest.control(s.window,'SampleName'),'String'),'Pending sample');
end

function testConstructionFailureKeepsItsErrorAndDeletesOnlyTheOwnedDialog(t)
details=struct('unsupportedText',true);expected=[];
try
    string(details);
catch problem
    expected=problem;
end
assertNotEmpty(t,expected,'The plain-data fixture must refuse text conversion.');
[s,calls]=session(t,details);s.show();
[foreign,rescued]=dialogGuard(t);before=findall(groot,'Type','figure');
colormeasuretest.click(colormeasuretest.control(s.window,'MeasureButton'));
journal=strjoin(string({s.log.message}),newline);
verifySubstring(t,journal,expected.identifier);verifySubstring(t,journal,expected.message);
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('read'),0);
verifyEqual(t,calls('release'),0);verifyEmpty(t,s.measurements);
remaining=findall(groot,'Tag','PreparationDialog');
verifyEmpty(t,remaining(~ismember(remaining,before)));
verifyTrue(t,isgraphics(foreign));verifyFalse(t,rescued());
end

function testHelpSetupErrorSurfacesWithoutFallbackOrAcquisition(t)
[s,calls]=session(t);s.show();
shadow=fullfile(t.TestData.folder,'help-setup-failure');
package=fullfile(shadow,'+colormeasure','+ui');mkdir(package);
file=fullfile(package,'setDialogHelp.m');
writelines(["function setDialogHelp(varargin)"; ...
    "error('Test:HelpSetup','Controlled help callback setup failure.');"; ...
    "end"],file);
t.applyFixture(matlab.unittest.fixtures.PathFixture(shadow));
assertEqual(t,which('colormeasure.ui.setDialogHelp'),file);
[foreign,rescued]=dialogGuard(t);before=findall(groot,'Type','figure');
colormeasuretest.click(colormeasuretest.control(s.window,'MeasureButton'));
journal=strjoin(string({s.log.message}),newline);
verifySubstring(t,journal,'Test:HelpSetup');
verifySubstring(t,journal,'Controlled help callback setup failure.');
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('read'),0);
verifyEqual(t,calls('release'),0);verifyEmpty(t,s.measurements);
remaining=findall(groot,'Tag','PreparationDialog');
verifyEmpty(t,remaining(~ismember(remaining,before)));
verifyTrue(t,isgraphics(foreign));verifyFalse(t,rescued());
end

function testInformationalHelpHasCloseAndNoReadyOrAcquisition(t)
[s,calls] = session(t); s.show();
runDialog(t,s,'InstrumentHelpButton','PreparationCancel',false);
verifyEqual(t,calls('connect'),0); verifyEqual(t,calls('read'),0);
end

function testCloseKeyFromHtmlCancelsPreparationWithoutAcquiring(t)
[s,calls]=session(t);s.show();
runDialog(t,s,'MeasureButton','PreparationCancel',true,3,@fromHtml);
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('read'),0);
verifyEmpty(t,s.measurements);
    function fromHtml(button)
        pane=findall(ancestor(button,'figure'),'Tag','PreparationDetails');
        pane.HTMLEventReceivedFcn(pane,struct('HTMLEventName','dialogCloseKey'));
    end
end

function testUnrelatedDialogDoesNotBlockNativeAction(t)
[s,calls] = session(t); s.show();
[foreign,rescued] = dialogGuard(t);
runDialog(t,s,'MeasureButton','PreparationCancel',true,3);
verifyFalse(t,rescued()); verifyTrue(t,isgraphics(foreign));
verifyEqual(t,calls('connect'),0);
end

function testTimeoutReleasesOnlyTestCreatedDialogs(t)
[s,calls] = session(t); s.show();
[foreign,rescued] = dialogGuard(t);
verifyError(t,@()runDialog(t,s,'MeasureButton','MissingTestAction',true,0.5), ...
    'Test:PreparationTimeout');
verifyFalse(t,rescued(),'The fallback watchdog was needed to release uiwait.');
verifyTrue(t,isgraphics(foreign),'The timeout deleted an unrelated dialog.');
verifyEqual(t,calls('connect'),0);
end

function testNoOpActionCannotDisableDialogTimeout(t)
[s,calls] = session(t); s.show();
[foreign,rescued] = dialogGuard(t); invoked=0;
verifyError(t,@()runDialog(t,s,'MeasureButton','PreparationCancel',true,3,@attempt), ...
    'Test:PreparationTimeout');
verifyFalse(t,rescued(),'The attempted action disabled timeout monitoring.');
verifyTrue(t,isgraphics(foreign)); verifyEqual(t,calls('connect'),0);
verifyEqual(t,invoked,1,'The no-op action must run once before timeout.');
    function attempt(~)
        invoked=invoked+1;
    end
end

function testVisibleDialogGetsItsWholeActionLimit(t)
% A dialog that appears at 29 s keeps all of a 3 s action limit; before it
% appears, construction has 30 s.
verifyEmpty(t,dialogDeadline(31,2,3));
verifyEmpty(t,dialogDeadline(32,3,3));
verifySubstring(t,dialogDeadline(32.1,3.1,3),'not completed');
verifyEmpty(t,dialogDeadline(30,[],3));
verifySubstring(t,dialogDeadline(30.1,[],3),'not constructed');
end

function late = dialogDeadline(constructing,responding,timeout)
% Construction has its own limit of at least 30 s. Once the new dialog is
% visible (responding is set), only the action's limit applies, counted from
% then, so slow construction on a loaded machine cannot use it up.
late = '';
if isempty(responding)
    if constructing > max(timeout,30), late = 'Preparation controls were not constructed.'; end
elseif responding > timeout
    late = 'The preparation dialog was not completed in time.';
end
end

function [foreign,rescued] = dialogGuard(t)
foreign=uifigure('Visible','off','Tag','PreparationDialog');
t.addTeardown(@() colormeasuretest.dispose(foreign));
before=findall(groot,'Type','figure'); didRescue=false;
worker=timer('StartDelay',60,'TimerFcn',@rescue);
t.addTeardown(@()stopTimer(worker)); rescued=@wasRescued; start(worker);
    function value=wasRescued()
        value=didRescue;
    end
    function rescue(~,~)
        didRescue=true;
        figures=findall(groot,'Type','figure');
        delete(figures(~ismember(figures,before)));
    end
end


function runEarlyDialog(t,s,action,secondAction)
% Invoke the real response synchronously on visibility, before focus/uiwait.
% A second response checks that reentrancy cannot reverse the first choice.
[foreign,rescued]=dialogGuard(t);
before=findall(groot,'Type','figure');invoked=false;
listener=addlistener(groot,'ObjectChildAdded',@attach);
t.addTeardown(@()delete(listener));
colormeasuretest.click(colormeasuretest.control(s.window,'MeasureButton'));
delete(listener);
verifyTrue(t,invoked,'The visibility hook must exercise the early-response path.');
verifyFalse(t,rescued(),'The watchdog must not complete the early-response case.');
verifyTrue(t,isgraphics(foreign),'An unrelated dialog must remain intact.');
remaining=findall(groot,'Tag','PreparationDialog');
verifyEmpty(t,remaining(~ismember(remaining,before)));
% Show the journal when an early response fails.
verifyFalse(t,any(contains(string({s.log.message}),'Action failed')), ...
    strjoin(string({s.log.message}),newline));
    function attach(~,event)
        dialog=event.Child;
        if ~isa(dialog,'matlab.ui.Figure')||ismember(dialog,before),return;end
        shown=addlistener(dialog,'Visible','PostSet',@(~,~)respond(dialog));
        t.addTeardown(@()delete(shown));
    end
    function respond(dialog)
        if invoked||~isgraphics(dialog)||~strcmp(dialog.Tag,'PreparationDialog')|| ...
                ~strcmp(char(dialog.Visible),'on'),return;end
        invoked=true;
        first=colormeasuretest.control(dialog,action);
        second=colormeasuretest.control(dialog,secondAction);
        colormeasuretest.click(first);
        if isgraphics(second),colormeasuretest.click(second);end
    end
end

function runDialog(t,s,trigger,action,confirmation,timeout,invoke)
if nargin<6, timeout=30; end
if nargin<7, invoke=@colormeasuretest.click; end
finished = false; problem = []; started = tic; shown = [];
before = findall(groot,'Type','figure');
worker = timer('ExecutionMode','fixedSpacing','Period',0.1,'StartDelay',0.1, ...
    'BusyMode','drop','TimerFcn',@inspect);
t.addTeardown(@() stopTimer(worker));
start(worker);
colormeasuretest.click(colormeasuretest.control(s.window,trigger));
stopTimer(worker);
verifyTrue(t,finished,'The native dialog action was not exercised.');
if ~isempty(problem), rethrow(problem); end
remaining=findall(groot,'Tag','PreparationDialog');
verifyEmpty(t,remaining(~ismember(remaining,before)));
    function inspect(timerObject,~)
        dialog = findall(groot,'Tag','PreparationDialog');
        dialog = dialog(~ismember(dialog,before));
        try
            if isempty(shown) && isscalar(dialog) && strcmp(char(dialog.Visible),'on'), shown = tic; end
            responding = []; if ~isempty(shown), responding = toc(shown); end
            late = dialogDeadline(toc(started),responding,timeout);
            if ~isempty(late), error('Test:PreparationTimeout','%s',late); end
            if finished, return; end % Keep timeout monitoring without repeating the action.
            if ~isscalar(dialog) || ~strcmp(char(dialog.Visible),'on') || ...
                    isempty(findall(dialog,'Tag',action)), return; end
            details = colormeasuretest.control(dialog,'PreparationDetails');
            assert(isprop(details,'HTMLSource'),'Expected HTML presentation.');
            assert(contains(details.Data,'<h2>Target</h2>'));
            assert(contains(details.Data,'Angle &lt; 1 &amp; stable.'));
            assert(contains(details.Data,'Additional workflow paragraph.'));
            assert(strcmp(colormeasuretest.control(dialog,'PreparationSummary').Text,'Virtual fixture only.'));
            manual = colormeasuretest.control(dialog,'PreparationManual');
            assert(isa(manual.ButtonPushedFcn,'function_handle') && strcmp(char(manual.Enable),'on'));
            cancel = colormeasuretest.control(dialog,'PreparationCancel');
            if confirmation
                assert(strcmp(cancel.Text,'Cancel'));
                assert(strcmp(colormeasuretest.control(dialog,'PreparationReady').Text,'Ready'));
            else
                assert(strcmp(cancel.Text,'Close'));
                assert(isempty(findall(dialog,'Tag','PreparationReady')));
            end
            dialog.Theme = 'dark'; drawnow;
            assert(contains(details.Data,'color-scheme:dark'));
            dialog.Theme = 'light'; drawnow;
            assert(contains(details.Data,'color-scheme:light'));
            finished = true;
            invoke(colormeasuretest.control(dialog,action));
        catch err
            problem = err; finished = true;
            stop(timerObject);
            % Release uiwait even when the new dialog has a wrong or duplicate tag.
            created=findall(groot,'Type','figure');
            delete(created(~ismember(created,before)));
        end
    end
end

function [s,calls] = session(t,details)
calls = containers.Map({'connect','read','release'},{0,0,0});
guide = struct('title','Fixture preparation','summary','Virtual fixture only.', ...
    'details',{{'Angle < 1 & stable.','Additional workflow paragraph.'}}, ...
    'headings',{{'Target'}},'url','https://example.invalid/manual','required',true);
if nargin>1
    % Ordinary metadata reaches the inner constructor but cannot become text.
    guide=rmfield(guide,'headings');guide.details=details;
end
adapter = struct('key','html-preparation-test','label','Virtual preparation', ...
    'listPorts',@(~) "VIRTUAL_ONLY",'connect',@connect,'release',@release, ...
    'read',@read,'preparation',guide, ...
    'toTable',@(rows,~) table(reshape([rows.XYZ],3,[])'));
s = colormeasure.session.Session(adapter,t.TestData.folder,colormeasure.ui.services());
t.addTeardown(@() colormeasuretest.dispose(s));
    function value = connect(~)
        calls('connect') = calls('connect')+1; value = struct();
    end
    function value = read(~)
        calls('read') = calls('read')+1; value = struct('XYZ',[1 2 3]);
    end
    function release(~), calls('release') = calls('release')+1; end
end
function stopTimer(value)
if isvalid(value), stop(value); delete(value); end
end

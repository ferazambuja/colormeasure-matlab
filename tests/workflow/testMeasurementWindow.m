function tests = testMeasurementWindow
% Direct GUI callbacks and layout checks. Figures are hidden by default;
% focus/lifecycle cases show them. Preparation-dialog checks use a timer.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); t.TestData.folder=f.Folder;
v=get(groot,'DefaultFigureVisible'); set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',v));
end
function testCompactLayoutHasRefreshBelowPortAndNoOverlaps(t)
s=makeSession(t); s.show(); fig=s.window; pos=get(fig,'Position');
verifyGreaterThanOrEqual(t,pos(3),960);
verifyNumElements(t,colormeasuretest.field(fig,'SpectrumAxes'),1);
verifyNumElements(t,colormeasuretest.field(fig,'ChromaticityAxes'),1);
label=colormeasuretest.field(fig,'InstrumentLabel');
verifyEqual(t,label.String,'Instrument');
verifyLessThanOrEqual(t,label.Extent(3),label.Position(3), ...
    'The instrument selector label must fit without clipping.');
p=get(colormeasuretest.field(fig,'SerialPort'),'Position'); r=get(colormeasuretest.field(fig,'RefreshPortsButton'),'Position');
verifyLessThanOrEqual(t,r(2)+r(4),p(2));
controls=visibleControls(fig);
for i=1:numel(controls)
    a=getpixelposition(controls(i),true);
    verifyGreaterThanOrEqual(t,a(1:2),[0 0]);
    verifyLessThanOrEqual(t,a(1:2)+a(3:4),pos(3:4));
    for j=i+1:numel(controls)
        b=getpixelposition(controls(j),true);
        intersect=min(a(1:2)+a(3:4),b(1:2)+b(3:4))-max(a(1:2),b(1:2));
        verifyFalse(t,all(intersect>0),sprintf('Overlap: %s / %s',get(controls(i),'Tag'),get(controls(j),'Tag')));
    end
end
verifyEqual(t,char(get(colormeasuretest.field(fig,'RetrySaveButton'),'Visible')),'off');
verifyEqual(t,char(get(colormeasuretest.field(fig,'SaveElsewhereButton'),'Visible')),'off');
end
function testVisibleWindowStartsMaximizedAndKeepsRestoredSize(t)
set(groot,'DefaultFigureVisible','on');
s=makeSession(t);s.show();fig=s.window;
verifyEqual(t,string(fig.WindowState),"maximized");
fig.WindowState='normal';fig.Position=[30 30 960 650];
s.hide();s.show();
verifyEqual(t,string(fig.WindowState),"normal");
verifyEqual(t,fig.Position(3:4),[960 650]);
end
function testHiddenWindowKeepsNormalGeometry(t)
s=makeSession(t);s.show();
verifyEqual(t,string(s.window.Visible),"off");
verifyEqual(t,string(s.window.WindowState),"normal");
end
function testButtonAndCommandUseSameLiveSession(t)
s=makeSession(t); s.show(); fig=s.window;
set(colormeasuretest.field(fig,'SampleName'),'String','Tile A');
set(colormeasuretest.field(fig,'SampleNotes'),'Value',{'line 1';'line 2'});
colormeasuretest.click(colormeasuretest.field(fig,'MeasureButton'));
verifyEqual(t,s.measurements.name,'Tile A');
verifyEqual(t,s.measurements.notes,sprintf('line 1\nline 2'));
s.measure('Tile B','');
verifyNumElements(t,s.measurements,2);
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Sample 003');
% This is a scientific unavailability response, not a malformed publisher.

end

function testReadingEditorCancelSaveAndCommandConflict(t)
s=makeSession(t);s.measure('Before','old note');s.show();fig=s.window;
edit=colormeasuretest.field(fig,'EditReadingAnnotations');verifyEqual(t,char(edit.Enable),'on');
colormeasuretest.click(edit);dialog=findall(groot,'Tag','ReadingAnnotationWindow');
name=colormeasuretest.field(dialog,'ReadingAnnotationName');name.Value='Cancelled';
colormeasuretest.click(colormeasuretest.field(dialog,'CancelReadingAnnotations'));
verifyEqual(t,s.measurements.name,'Before');verifyEmpty(t,s.readingAnnotations);
colormeasuretest.click(edit);dialog=findall(groot,'Tag','ReadingAnnotationWindow');
name=colormeasuretest.field(dialog,'ReadingAnnotationName');name.Value='Corrected';
notes=colormeasuretest.field(dialog,'ReadingAnnotationNotes');notes.Value={'line 1';'line 2'};
colormeasuretest.click(colormeasuretest.field(dialog,'SaveReadingAnnotations'));
verifyFalse(t,isgraphics(dialog));verifyEqual(t,s.measurements.name,'Corrected');
verifyEqual(t,s.measurements.notes,sprintf('line 1\nline 2'));
table=colormeasuretest.field(fig,'ResultsTable');verifyEqual(t,table.Data{1,3},'Corrected');
colormeasuretest.click(edit);dialog=findall(groot,'Tag','ReadingAnnotationWindow');
name=colormeasuretest.field(dialog,'ReadingAnnotationName');name.Value='Old draft';
s.editReading(1,'From MATLAB','');
verifyEqual(t,char(colormeasuretest.field(dialog,'SaveReadingAnnotations').Enable),'off');
verifySubstring(t,colormeasuretest.field(dialog,'ReadingAnnotationMessage').Text,'changed in MATLAB');
colormeasuretest.click(colormeasuretest.field(dialog,'CancelReadingAnnotations'));
verifyEqual(t,s.measurements.name,'From MATLAB');
end

function testReadingEditorValidationAndOwnerCleanup(t)
s=makeSession(t);s.measure('Before','note');s.show();fig=s.window;fig.Visible='on';
colormeasuretest.click(colormeasuretest.field(fig,'EditReadingAnnotations'));
dialog=findall(groot,'Tag','ReadingAnnotationWindow');
name=colormeasuretest.field(dialog,'ReadingAnnotationName');name.Value='';
colormeasuretest.click(colormeasuretest.field(dialog,'SaveReadingAnnotations'));
verifyTrue(t,isgraphics(dialog));verifyEqual(t,s.measurements.name,'Before');
verifySubstring(t,colormeasuretest.field(dialog,'ReadingAnnotationMessage').Text,'nonempty');
s.hide();verifyFalse(t,isgraphics(dialog));verifyEmpty(t,s.readingAnnotations);
s.show();colormeasuretest.click(colormeasuretest.field(fig,'EditReadingAnnotations'));
dialog=findall(groot,'Tag','ReadingAnnotationWindow');delete(s);verifyFalse(t,isgraphics(dialog));
end
function testMeasureShortcutRequiresIdleMeasureTabAndRelease(t)
s=makeSession(t);s.show();fig=s.window;fig.Visible='on';
[~,modifiers]=colormeasure.ui.measureShortcut();event=struct('Key','m','Modifier',{modifiers});
press=fig.WindowKeyPressFcn;release=fig.WindowKeyReleaseFcn;
plain=struct('Key','return','Modifier',{{}});press(fig,plain);
verifyEmpty(t,s.measurements);
tabs=colormeasuretest.field(fig,'MeasurementSidebar');tabs.SelectedTab=colormeasuretest.field(fig,'ReadingTab');
press(fig,event);verifyEmpty(t,s.measurements); % Ignored keys must not latch.
tabs.SelectedTab=colormeasuretest.field(fig,'MeasureTab');
set(colormeasuretest.field(fig,'SampleName'),'String','Shortcut sample');
press(fig,event);press(fig,event);
verifyNumElements(t,s.measurements,1);verifyEqual(t,s.measurements.name,'Shortcut sample');
release(fig,event);press(fig,event);release(fig,event);
verifyNumElements(t,s.measurements,2);
s.hide();press(fig,event);release(fig,event);verifyNumElements(t,s.measurements,2);
end
function testShortcutInsideATextFieldExplainsInsteadOfMeasuring(t)
s=makeSession(t);s.show();fig=s.window;fig.Visible='on';
[label,modifiers]=colormeasure.ui.measureShortcut();event=struct('Key','m','Modifier',{modifiers});
name=colormeasuretest.field(fig,'SampleName');fig.CurrentObject=name;
name.KeyPressFcn(name,struct('Key','a','Modifier',{{}}));
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyEmpty(t,s.measurements);
status=get(colormeasuretest.field(fig,'CurrentStatus'),'String');
verifySubstring(t,status,'Finish editing');verifySubstring(t,status,label);
% Tab commits the field without changing the last mouse-clicked object.
set(name,'String','Committed sample');name.Callback(name,[]);
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,1);
verifyEqual(t,s.measurements(1).name,'Committed sample');
% Keyboard navigation never sets CurrentObject: a keystroke in the field is
% the draft signal, and the field's commit callback clears it.
fig.CurrentObject=colormeasuretest.field(fig,'MeasureButton');
name.KeyPressFcn(name,struct('Key','a','Modifier',{{}}));
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,1);
verifySubstring(t,get(colormeasuretest.field(fig,'CurrentStatus'),'String'),'Finish editing');
set(name,'String','Committed sample');name.Callback(name,[]);
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,2);verifyEqual(t,s.measurements(2).name,'Committed sample');
end

function testBlockedMeasureShortcutExplainsPendingDeviceAndDoesNotLatch(t)
% Declare a public switching identity on the existing inert XYZ adapter.
io=colormeasure.ui.services();
a=adapter();a.catalog=struct('model','PR655','mode','interactive');
s=colormeasure.session.Session(a,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));s.show();fig=s.window;fig.Visible='on';
selector=colormeasuretest.field(fig,'InstrumentSelector');original=selector.Value;
other=find((1:numel(selector.String))~=original,1);assertNotEmpty(t,other);
selector.Value=other;colormeasuretest.click(selector);files=s.files;
[~,modifiers]=colormeasure.ui.measureShortcut();event=struct('Key','m','Modifier',{modifiers});
status=colormeasuretest.field(fig,'CurrentStatus');
set(status,'String','Shortcut feedback sentinel','TooltipString','Shortcut tooltip sentinel');
fig.WindowKeyPressFcn(fig,event);
verifySubstring(t,status.String,'Select Open to switch instruments');
verifySubstring(t,status.TooltipString,'did not measure');
verifyEmpty(t,s.measurements);verifyEqual(t,s.files,files);verifyFalse(t,s.busy);
selector.Value=original;colormeasuretest.click(selector);
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,1); % The blocked chord did not latch.
end

function testNavigationKeysDoNotInventAnUncommittedEdit(t)
s=makeSession(t);s.show();fig=s.window;fig.Visible='on';
name=colormeasuretest.field(fig,'SampleName');fig.CurrentObject=name;
for key={'tab','leftarrow','shift'}
    name.KeyPressFcn(name,struct('Key',key{1},'Modifier',{{}}));
end
[~,modifiers]=colormeasure.ui.measureShortcut();event=struct('Key','m','Modifier',{modifiers});
name.KeyPressFcn(name,event); % The chord itself is not a text edit.
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,1);
end

function testQueuedTypingAfterWindowDeletionIsHarmless(t)
s=makeSession(t);s.show();fig=s.window;
name=colormeasuretest.field(fig,'SampleName');notes=colormeasuretest.field(fig,'SampleNotes');
typeName=name.KeyPressFcn;typeNotes=notes.ValueChangingFcn;commit=name.Callback;
press=fig.WindowKeyPressFcn;delete(s);
verifyWarningFree(t,@()typeName([],struct('Key','a','Modifier',{{}})));
verifyWarningFree(t,@()typeNotes([],[]));verifyWarningFree(t,@()commit([],[]));
[~,modifiers]=colormeasure.ui.measureShortcut();
verifyWarningFree(t,@()press([],struct('Key','m','Modifier',{modifiers})));
end

function testShortcutReleaseInPreparationDialogAllowsNextReading(t)
a=adapter();a.preparation=struct('title','Synthetic preparation','summary','Fixture only.', ...
    'details',{{'No instrument is connected.'}},'url','','required',true);
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services());
t.addTeardown(@()colormeasuretest.disposeSession(s));s.show();fig=s.window;fig.Visible='on';
[~,modifiers]=colormeasure.ui.measureShortcut();event=struct('Key','m','Modifier',{modifiers});
[released,problem]=runWithPreparationKeyRelease(@()fig.WindowKeyPressFcn(fig,event),event);
if ~isempty(problem),rethrow(problem);end
verifyTrue(t,released);verifyNumElements(t,s.measurements,1);
% No main-figure release was delivered. The modal must have relayed it.
fig.WindowKeyPressFcn(fig,event);fig.WindowKeyReleaseFcn(fig,event);
verifyNumElements(t,s.measurements,2);
end
function testPreparationWatchdogIsDeletedWhenTheGuardedActionThrows(t)
before=timerfindall;worker=[];
verifyError(t,@()runWithPreparationKeyRelease(@failWhileRunning,struct()),'Fixture:PreparationAction');
verifyTrue(t,~isempty(worker)&&~isvalid(worker), ...
    'The actual preparation watchdog must be deleted when its guarded action unwinds.');
    function failWhileRunning()
        candidates=timerfindall('Tag','PreparationShortcutKeyRelease');
        worker=candidates(~ismember(candidates,before));
        assert(isscalar(worker),'Fixture:PreparationTimer','Expected only the newly owned watchdog.');
        % Also remove the owned survivor in the baseline negative control.
        t.addTeardown(@()stopTimer(worker));
        assert(strcmp(worker.Running,'on'),'Fixture:PreparationTimer','The guard must be armed around a running timer.');
        error('Fixture:PreparationAction','Injected failure while the actual preparation watchdog is armed.');
    end
end
function testNestedSessionChangeRendersLatestSampleWithoutAnotherAction(t)
s=makeSession(t);s.show();fig=s.window;
name=colormeasuretest.field(fig,'SampleName');triggered=false;
listener=addlistener(name,'String','PostSet',@changeDuringRender);
t.addTeardown(@()delete(listener));
s.setSample('First draft','Initial notes');
verifyTrue(t,triggered);
verifyEqual(t,s.name,'Updated during rendering');
verifyEqual(t,get(name,'String'),s.name);
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{'Latest notes'});
verifyEqual(t,get(colormeasuretest.field(fig,'FinishButton'),'Enable'),'on');
    function changeDuringRender(~,~)
        if triggered,return;end
        triggered=true;
        s.setSample('Updated during rendering','Latest notes');
    end
end
function testLogRetainsHistoryAndRemainsScrollable(t)
s=makeSession(t); s.show(); fig=s.window;
s.measure(); messages={s.log.message};
for i=1:20, s.refreshPorts(); end
verifyEqual(t,{s.log(1:numel(messages)).message},messages);
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
logField=colormeasuretest.field(fig,'SessionLog');
verifyEqual(t,get(logField,'Style'),'listbox');
verifyEqual(t,char(get(logField,'Enable')),'on');
lines=get(logField,'String'); verifyGreaterThan(t,numel(lines),20);
verifyTrue(t,any(contains(lines,'MAT saved')));
ruler=uicontrol(fig,'Style','text','Visible','off','Units','pixels', ...
    'FontName',get(logField,'FontName'),'FontSize',get(logField,'FontSize'),'String',lines);
extent=get(ruler,'Extent'); position=get(logField,'Position');
verifyLessThanOrEqual(t,extent(3),position(3)-20); % No horizontal scrolling for paths.
verifyGreaterThan(t,extent(4),position(4),'the history overflows the visible height, so it scrolls');
delete(ruler);
set(logField,'ListboxTop',1); verifyEqual(t,get(logField,'ListboxTop'),1);
end
function testCloseHidesWithoutFinishingAndFinishKeepsReview(t)
s=makeSession(t); s.show(); s.measure(); fig=s.window; close(fig);
verifyTrue(t,isvalid(s)); verifyFalse(t,s.finished);
verifyTrue(t,isgraphics(fig)); verifyNumElements(t,s.measurements,1);
verifyEqual(t,char(get(fig,'Visible')),'off'); verifyEmpty(t,s.files.csv);
s.finish(); verifyTrue(t,s.finished); verifyTrue(t,isgraphics(fig));
verifyTrue(t,isfile(s.files.csv));
end
function testLogActionsPreserveBatchAndPendingInputs(t)
io=colormeasure.ui.services(); saveMat=io.saveMat; saveCount=0; readCount=0;
io.saveMat=@countSave; a=adapter(); a.read=@countRead;
s=colormeasure.session.Session(a,t.TestData.folder,io); t.addTeardown(@() colormeasuretest.disposeSession(s));
s.show(); s.measure(); fig=s.window;
assertEqual(t,s.savedCount,1); assertFalse(t,s.needsRecovery);
assertTrue(t,isfile(s.files.mat));
before=struct('measurements',s.measurements,'files',s.files,'info',s.info,'log',s.log);
set(colormeasuretest.field(fig,'SampleName'),'String','Pending sample');
set(colormeasuretest.field(fig,'SampleNotes'),'Value','Do not discard these notes');
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
set(colormeasuretest.field(fig,'SessionLog'),'Value',1); colormeasuretest.click(colormeasuretest.field(fig,'SessionLog'));
set(colormeasuretest.field(fig,'LogFilter'),'Value',2); colormeasuretest.click(colormeasuretest.field(fig,'LogFilter'));
colormeasuretest.click(colormeasuretest.field(fig,'JumpToLatest'));
set(colormeasuretest.field(fig,'LogFilter'),'Value',1); colormeasuretest.click(colormeasuretest.field(fig,'LogFilter'));
set(colormeasuretest.field(fig,'FollowLatest'),'Value',0); colormeasuretest.click(colormeasuretest.field(fig,'FollowLatest'));
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
verifyEqual(t,struct('measurements',s.measurements,'files',s.files,'info',s.info,'log',s.log),before);
verifyEqual(t,saveCount,1); verifyEqual(t,readCount,1);
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending sample');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{'Do not discard these notes'});
    function countSave(varargin)
        saveCount=saveCount+1; saveMat(varargin{:});
    end
    function reading=countRead(~)
        readCount=readCount+1; reading=struct('XYZ',[1 2 3]);
    end
end
function testInspectionAndRecoveryFitSmallestWindow(t)
io=colormeasure.ui.services(); io.saveMat=@(~,~,~) error('Test:Save','Disk unavailable');
s=makeSession(t,io); s.show(); drawnow; s.measure(); fig=s.window;
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
set(colormeasuretest.field(fig,'SessionLog'),'Value',numel(s.log)); colormeasuretest.click(colormeasuretest.field(fig,'SessionLog'));
% Realize native tabs at the initial size before exercising a resize. The
% first capture of a hidden figure can otherwise restore stale parent bounds.
drawnow;
pos=get(fig,'Position'); pos(3:4)=[960 650]; set(fig,'Position',pos);
callback=get(fig,'SizeChangedFcn'); callback(fig,[]); drawnow;
controls=visibleControls(fig);
for i=1:numel(controls)
    a=getpixelposition(controls(i),true);
    verifyGreaterThan(t,a(3:4),[0 0]);
    verifyGreaterThanOrEqual(t,a(1:2),[0 0]);
    verifyLessThanOrEqual(t,a(1:2)+a(3:4),pos(3:4));
    for j=i+1:numel(controls)
        b=getpixelposition(controls(j),true);
        overlap=min(a(1:2)+a(3:4),b(1:2)+b(3:4))-max(a(1:2),b(1:2));
        verifyFalse(t,all(overlap>0),sprintf('Overlap: %s / %s',get(controls(i),'Tag'),get(controls(j),'Tag')));
    end
end
verifyEqual(t,char(get(colormeasuretest.field(fig,'LogDetails'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'RetrySaveButton'),'Visible')),'on');
verifyEqual(t,colormeasuretest.field(fig,'RecoveryMessage').Parent,fig);
verifyEqual(t,colormeasuretest.field(fig,'RetrySaveButton').Parent,fig);
verifyEqual(t,colormeasuretest.field(fig,'SaveElsewhereButton').Parent,fig);
recovery=getpixelposition(colormeasuretest.field(fig,'RecoveryMessage'),true);
logPanel=getpixelposition(colormeasuretest.field(fig,'SessionLogPanel'),true);
verifyGreaterThanOrEqual(t,logPanel(2),recovery(2)+recovery(4));
end
function testFailedSaveRevealsRecoveryAndKeepsLog(t)
io=colormeasure.ui.services(); io.saveMat=@(~,~,~) error('Test:Save','Disk unavailable');
s=makeSession(t,io); s.show(); s.measure(); fig=s.window;
verifyEqual(t,char(get(colormeasuretest.field(fig,'RetrySaveButton'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'SaveElsewhereButton'),'Visible')),'on');
verifyTrue(t,contains(get(colormeasuretest.field(fig,'CurrentStatus'),'String'),'Save needs attention'));
verifyTrue(t,contains(get(colormeasuretest.field(fig,'CurrentStatus'),'TooltipString'),'Disk unavailable'));
sidebar=colormeasuretest.field(fig,'MeasurementSidebar');sidebar.SelectedTab=colormeasuretest.field(fig,'CompareTab');
status=colormeasuretest.field(fig,'CurrentStatus');verifyEqual(t,status.Parent,fig);
verifyEqual(t,char(status.Visible),'on');
message=colormeasuretest.field(fig,'RecoveryMessage');
verifyEqual(t,char(message.Visible),'on');
verifySubstring(t,string(message.String),'MAT save failed');
verifyEqual(t,char(colormeasuretest.field(fig,'RetrySaveButton').Visible),'on');
verifyLessThanOrEqual(t,status.Position(2)+status.Position(4),sidebar.Position(2));
verifyTrue(t,contains(get(colormeasuretest.field(fig,'ToggleLogButton'),'String'),'issue'));
verifyEqual(t,char(get(colormeasuretest.field(fig,'SessionLogPanel'),'Visible')),'off');
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
verifyTrue(t,any(contains(get(colormeasuretest.field(fig,'SessionLog'),'String'),'Disk unavailable')));
end
function testRecoveryRetryFromDataTabDoesNotAcquireAgain(t)
io=colormeasure.ui.services();save=io.saveMat;attempts=0;io.saveMat=@saveOnce;
s=makeSession(t,io);s.show();s.measure();fig=s.window;
verifyTrue(t,s.needsRecovery);before=s.measurements;
sidebar=colormeasuretest.field(fig,'MeasurementSidebar');
sidebar.SelectedTab=colormeasuretest.field(fig,'ReadingTab');
colormeasuretest.click(colormeasuretest.field(fig,'RetrySaveButton'));
verifyEqual(t,s.measurements,before);verifyEqual(t,attempts,2);
verifyFalse(t,s.needsRecovery);verifyTrue(t,isfile(s.files.mat));
verifyEqual(t,char(colormeasuretest.field(fig,'RecoveryMessage').Visible),'off');
    function saveOnce(varargin)
        attempts=attempts+1;
        if attempts==1,error('Test:Save','Disk unavailable');end
        save(varargin{:});
    end
end
function testIssueCountFitsLogButtonWithoutOverlappingActions(t)
s=makeSession(t);s.show();fig=s.window;
button=colormeasuretest.field(fig,'ToggleLogButton');
for index=1:10
    s.reportError(MException('Test:Issue','Retained issue %d',index));
    if index==1,expected='Show log (1 issue)';
    else,expected=sprintf('Show log (%d issues)',index);end
    verifyEqual(t,button.String,expected);
    verifyGreaterThanOrEqual(t,button.Position(3),button.Extent(3)+16);
    next=colormeasuretest.field(fig,'ExpandReadingsButton');
    verifyLessThan(t,button.Position(1)+button.Position(3),next.Position(1));
end
end
function testFolderReturnKeepsCancelErrorAndSuccessData(t)
% Substituted chooser proves callback/lifecycle behavior, not native focus.
io=colormeasure.ui.services();io.chooseFolder=@choose;selection='';calls=0;
save=io.saveMat;attempts=0;io.saveMat=@saveOnce;
s=makeSession(t,io);s.show();s.measure();fig=s.window;
fig.Visible='on';figure(fig);
draft=colormeasuretest.field(fig,'SampleName');draft.String='Pending name';
before=s.measurements;files=s.files;
button=colormeasuretest.field(fig,'SaveElsewhereButton');
colormeasuretest.click(button);
verifyEqual(t,s.measurements,before);verifyEqual(t,s.files,files);
verifyEqual(t,draft.String,'Pending name');verifyEqual(t,calls,1);
verifyEqual(t,colormeasure.ui.currentFigure(),fig);
selection=fullfile(t.TestData.folder,'missing','destination');
colormeasuretest.click(button);
verifyEqual(t,s.measurements,before);verifyEqual(t,s.files,files);
verifyEqual(t,draft.String,'Pending name');verifyEqual(t,calls,2);
selection=t.TestData.folder;colormeasuretest.click(button);
verifyEqual(t,s.measurements,before);verifyNotEqual(t,s.files.folder,files.folder);
verifyEqual(t,draft.String,'Pending name');verifyEqual(t,calls,3);
verifyEqual(t,colormeasure.ui.currentFigure(),fig);
verifyFalse(t,s.needsRecovery);saved=load(s.files.mat);
verifyEqual(t,saved.measurements,before);verifyEqual(t,attempts,2);
    function folder=choose(~)
        calls=calls+1;folder=selection;
        set(groot,'CurrentFigure',[]); % Simulate a chooser releasing graphics focus.
    end
    function saveOnce(varargin)
        attempts=attempts+1;
        if attempts==1,error('Test:Save','Disk unavailable');end
        save(varargin{:});
    end
end
function testFolderCancelDuringSaveFinalizationRestoresRecoveryWindow(t)
io=colormeasure.ui.services();io.chooseFolder=@choose;
io.exportCsv=@refuseCsv;
s=makeSession(t,io);s.show();s.measure();s.finish();fig=s.window;
verifyTrue(t,s.finishing);verifyTrue(t,s.needsRecovery);
verifySubstring(t,s.exportError,'CSV unavailable');
fig.Visible='on';figure(fig);before=s.measurements;
colormeasuretest.click(colormeasuretest.field(fig,'SaveElsewhereButton'));
verifyEqual(t,colormeasure.ui.currentFigure(),fig);
verifyEqual(t,s.measurements,before);verifyTrue(t,s.finishing);
verifyEqual(t,char(colormeasuretest.field(fig,'SampleName').Enable),'off');
verifyEqual(t,char(colormeasuretest.field(fig,'SaveElsewhereButton').Enable),'on');
    function folder=choose(~)
        set(groot,'CurrentFigure',[]);folder='';
    end
    function digest=refuseCsv(varargin) %#ok<STOUT>
        error('Test:Export','CSV unavailable');
    end
end
function testFolderReturnDoesNotRaiseHiddenOrReplacedWindow(t)
io=colormeasure.ui.services();io.chooseFolder=@choose;action='hide';replacement=[];
io.saveMat=@(~,~,~) error('Test:Save','Disk unavailable');
s=makeSession(t,io);s.show();s.measure();fig=s.window;
fig.Visible='on';figure(fig);
colormeasuretest.click(colormeasuretest.field(fig,'SaveElsewhereButton'));
verifyEqual(t,char(fig.Visible),'off');
fig.Visible='on';figure(fig);action='replace';
colormeasuretest.click(colormeasuretest.field(fig,'SaveElsewhereButton'));
verifyFalse(t,isgraphics(fig));verifyEqual(t,s.window,replacement);
verifyEqual(t,colormeasure.ui.currentFigure(),replacement);
verifyFalse(t,s.busy);verifyTrue(t,s.needsRecovery);
verifyEqual(t,char(colormeasuretest.field(replacement,'SaveElsewhereButton').Enable),'on');
verifyEqual(t,char(colormeasuretest.field(replacement,'MeasureButton').Enable),'on');
    function folder=choose(~)
        if strcmp(action,'hide'),s.hide();
        else
            readings=s.measurements;files=s.files;
            delete(fig);s.show();replacement=s.window;
            verifyTrue(t,s.busy);verifyEqual(t,s.activity,'Choosing save folder');
            for tag={'MeasureButton','InstrumentSettingsButton','SaveElsewhereButton','RetrySaveButton'}
                verifyEqual(t,char(colormeasuretest.field(replacement,tag{1}).Enable),'off');
            end
            verifyEqual(t,s.measurements,readings);verifyEqual(t,s.files,files);
            replacement.Visible='on';figure(replacement);
        end
        folder='';
    end
end
function testFolderReturnDoesNotStealAnotherWindowOrChangeTab(t)
io=colormeasure.ui.services();io.chooseFolder=@choose;other=[];
io.saveMat=@(~,~,~) error('Test:Save','Disk unavailable');
s=makeSession(t,io);s.show();s.measure();fig=s.window;
fig.Visible='on';figure(fig);
sidebar=colormeasuretest.field(fig,'MeasurementSidebar');
tab=colormeasuretest.field(fig,'ReadingTab');sidebar.SelectedTab=tab;
colormeasuretest.click(colormeasuretest.field(fig,'SaveElsewhereButton'));
verifyEqual(t,colormeasure.ui.currentFigure(),other);
verifyEqual(t,sidebar.SelectedTab,tab);
    function folder=choose(~)
        other=figure('Visible','on');t.addTeardown(@()delete(other));folder='';
    end
end
function testCsvExportRecoveryAfterFinishKeepsMatAndReading(t)
io=colormeasure.ui.services();export=io.exportCsv;attempts=0;io.exportCsv=@exportOnce;
s=makeSession(t,io);s.show();s.measure();before=s.measurements;s.finish();fig=s.window;
verifyTrue(t,s.finishing);verifyFalse(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyTrue(t,isfile(s.files.mat));verifyEmpty(t,s.files.csv);
message=colormeasuretest.field(fig,'RecoveryMessage');
verifySubstring(t,string(message.String),'CSV export failed');
sidebar=colormeasuretest.field(fig,'MeasurementSidebar');
sidebar.SelectedTab=colormeasuretest.field(fig,'CompareTab');
colormeasuretest.click(colormeasuretest.field(fig,'RetrySaveButton'));
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyEqual(t,attempts,2);
verifyEqual(t,s.measurements,before);verifyTrue(t,isfile(s.files.mat));
verifyTrue(t,isfile(s.files.csv));
    function digest=exportOnce(varargin)
        attempts=attempts+1;
        if attempts==1,error('Test:Export','CSV destination unavailable');end
        digest=export(varargin{:});
    end
end
function testButtonsAreProtectedAndDisabledDuringRead(t)
a=adapter(); a.read=@duringRead;
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services()); t.addTeardown(@() colormeasuretest.disposeSession(s));
s.show(); fig=s.window;
verifyEqual(t,char(get(colormeasuretest.field(fig,'MeasureButton'),'Interruptible')),'on');
for tag={'RefreshPortsButton','RetrySaveButton','SaveElsewhereButton'}
    control=colormeasuretest.field(fig,tag{1});
    verifyEqual(t,char(get(control,'Interruptible')),'off'); verifyEqual(t,get(control,'BusyAction'),'cancel');
end
verifyEmpty(t,get(fig,'KeyPressFcn')); % Escape is not an implicit Finish action.
s.measure();
verifyNumElements(t,s.measurements,1);
verifyEqual(t,char(get(colormeasuretest.field(fig,'MeasureButton'),'Enable')),'on');
    function reading=duringRead(~)
        verifyTrue(t,s.busy);
        for name={'MeasureButton','RefreshPortsButton','SampleName','SampleNotes','SerialPort','FinishButton'}
            verifyEqual(t,char(get(colormeasuretest.field(fig,name{1}),'Enable')),'off');
        end
        colormeasuretest.click(colormeasuretest.field(fig,'MeasureButton')); % A manually invoked callback is guarded too.
        verifyFalse(t,s.measure('Nested',''));
        reading=struct('XYZ',[1 2 3]);
    end
end
function testMissingDestinationOffersFolderRecoveryBeforeFirstReading(t)
destination=fullfile(t.TestData.folder,'removed');
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
s=colormeasure.session.Session(adapter(),destination,io); t.addTeardown(@() colormeasuretest.disposeSession(s));
s.show(); verifyFalse(t,s.measure()); fig=s.window;
verifyEqual(t,char(get(colormeasuretest.field(fig,'RetrySaveButton'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'RetrySaveButton'),'Enable')),'off');
verifyEqual(t,char(get(colormeasuretest.field(fig,'SaveElsewhereButton'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'SaveElsewhereButton'),'Enable')),'on');
verifySubstring(t,string(colormeasuretest.field(fig,'RecoveryMessage').String),'Save needs attention');
sidebar=colormeasuretest.field(fig,'MeasurementSidebar');
sidebar.SelectedTab=colormeasuretest.field(fig,'ReadingTab');
colormeasuretest.click(colormeasuretest.field(fig,'SaveElsewhereButton'));
verifyFalse(t,s.needsRecovery);verifyTrue(t,s.measure());
end
function testLauncherReusesActiveHandleAndStartsFreshAfterFinish(t)
io=colormeasure.ui.services(); io.chooseFolder=@(~) t.TestData.folder;
a=adapter(); a.key=t.TestData.folder;
first=colormeasure.ui.launchSession(a,io); t.addTeardown(@() colormeasuretest.disposeSession(first));
second=colormeasure.ui.launchSession(a,io); verifyEqual(t,first,second);
first.measure(); old=first.files.mat; first.finish();
verifyEqual(t,colormeasure.ui.launchSession(a,io),first);
third=first.newBatch(); t.addTeardown(@() colormeasuretest.disposeSession(third));
verifyNotEqual(t,first,third); third.measure();
verifyNotEqual(t,third.files.mat,old); verifyTrue(t,isfile(old));
end
function testCancelledLaunchReturnsEmptyWithoutWindow(t)
a=adapter(); a.key=t.TestData.folder; io=colormeasure.ui.services(); io.chooseFolder=@(~) '';
s=colormeasure.ui.launchSession(a,io); verifyEmpty(t,s);
end
function testDraftSurvivesResizeNotificationsAndReachesSavedRecord(t)
s=makeSession(t); s.show(); fig=s.window;
set(colormeasuretest.field(fig,'SampleName'),'String','Pending tile');
set(colormeasuretest.field(fig,'SampleNotes'),'Value','Keep these notes');
p=get(fig,'Position'); p(3:4)=[960 650]; set(fig,'Position',p);
callback=get(fig,'SizeChangedFcn'); callback(fig,[]);
s.refreshPorts();
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending tile');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{'Keep these notes'});
colormeasuretest.click(colormeasuretest.field(fig,'MeasureButton'));
saved=load(s.files.mat);
verifyEqual(t,saved.measurements.name,'Pending tile');
verifyEqual(t,saved.measurements.notes,'Keep these notes');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Sample 002');
s.setSample('Command sample','Command notes');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Command sample');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{'Command notes'});
end
function testExplicitSetSampleResetsBothDraftFields(t)
s=makeSession(t); s.show(); fig=s.window;
set(colormeasuretest.field(fig,'SampleName'),'String','Uncommitted name');
set(colormeasuretest.field(fig,'SampleNotes'),'Value','Uncommitted notes');
s.setSample('Command sample','');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Command sample');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{''});
set(colormeasuretest.field(fig,'SampleName'),'String','Another draft');
s.setSample('Command sample','');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Command sample');
end
function testNoPortDisablesMeasure(t)
a=adapter(); a.listPorts=@(~) strings(0,1);
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services()); t.addTeardown(@() colormeasuretest.disposeSession(s)); s.show();
verifyEqual(t,char(get(colormeasuretest.field(s.window,'MeasureButton'),'Enable')),'off');
verifyTrue(t,contains(get(colormeasuretest.field(s.window,'CurrentStatus'),'String'),'No port'));
end
function testSidebarUsesFullHeightBesideTableAndLog(t)
s=makeSession(t); s.show(); fig=s.window;
for dimensions={[960 650],[1280 880],[1728 1056],[1120 760]}
p=get(fig,'Position'); p(3:4)=dimensions{1}; set(fig,'Position',p);
cb=get(fig,'SizeChangedFcn'); cb(fig,[]);drawnow;
verifyFalse(t,contains(get(colormeasuretest.field(fig,'CurrentStatus'),'String'),'Display unavailable'));
verifyEqual(t,char(get(colormeasuretest.field(fig,'SessionLogPanel'),'Visible')),'off');
sidebar=getpixelposition(colormeasuretest.field(fig,'MeasurementSidebar'),true);
tablePanel=getpixelposition(colormeasuretest.field(fig,'ResultsTablePanel'),true);
logPanel=getpixelposition(colormeasuretest.field(fig,'SessionLogPanel'),true);
verifyGreaterThanOrEqual(t,sidebar(2),tablePanel(2));
verifyGreaterThan(t,sidebar(4),tablePanel(4));
verifyGreaterThanOrEqual(t,tablePanel(1),sidebar(1)+sidebar(3));
verifyEqual(t,logPanel,tablePanel);
columns=cell2mat(get(colormeasuretest.field(fig,'ResultsTable'),'ColumnWidth'));
verifyGreaterThanOrEqual(t,columns(3),120);
verifyLessThanOrEqual(t,sum(columns)+18,tablePanel(3));
table=colormeasuretest.field(fig,'ResultsTable');
numeric=ismember(string(table.ColumnName),["X","Y","Z","u'","v'","x","y"]);
verifyGreaterThanOrEqual(t,columns(numeric),50*ones(1,5));
verifyLessThanOrEqual(t,columns(numeric),80*ones(1,5));
verifyLessThanOrEqual(t,columns(3),220);
details=getpixelposition(colormeasuretest.field(fig,'ReadingDetails'),true);
verifyGreaterThanOrEqual(t,details(4),colormeasuretest.field(fig,'ReadingDetails').FontSize+12);
end
verifyEqual(t,ancestor(colormeasuretest.field(fig,'FinishButton'),'uitab'),colormeasuretest.field(fig,'MeasureTab'));
verifyEqual(t,ancestor(colormeasuretest.field(fig,'ReadingDetails'),'uitab'),colormeasuretest.field(fig,'ReadingTab'));
verifyNotEqual(t,colormeasuretest.field(fig,'ReadingTab'),colormeasuretest.field(fig,'MeasureTab'));
end
function testTogglePreservesInspectedLogAndDoesNotAcquire(t)
s=makeSession(t); s.show(); fig=s.window;
for k=1:40, s.refreshPorts(); end
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
logControl=colormeasuretest.field(fig,'SessionLog'); set(logControl,'Value',10); colormeasuretest.click(logControl);
set(logControl,'ListboxTop',5); top=get(logControl,'ListboxTop');
set(colormeasuretest.field(fig,'SampleName'),'String','Pending next sample');
colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
verifyEqual(t,char(get(colormeasuretest.field(fig,'SessionLogPanel'),'Visible')),'off');
s.refreshPorts(); colormeasuretest.click(colormeasuretest.field(fig,'ToggleLogButton'));
verifyEqual(t,get(logControl,'Value'),10);
verifyEqual(t,get(logControl,'ListboxTop'),top);
verifyEqual(t,get(colormeasuretest.field(fig,'FollowLatest'),'Value'),0);
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending next sample');
verifyEmpty(t,s.measurements); verifyEmpty(t,s.files.mat);
end
function testReadFailureRemainsVisibleWithLogClosed(t)
a=adapter(); a.read=@failedRead;
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services()); t.addTeardown(@() colormeasuretest.disposeSession(s)); s.show();
verifyFalse(t,s.measure()); fig=s.window;
verifyEqual(t,char(get(colormeasuretest.field(fig,'SessionLogPanel'),'Visible')),'off');
verifyTrue(t,contains(get(colormeasuretest.field(fig,'CurrentStatus'),'TooltipString'),'Synthetic target unavailable'));
verifyTrue(t,contains(get(colormeasuretest.field(fig,'ToggleLogButton'),'String'),'issue'));
end
function testThemeChangeOnlyUpdatesPresentationContrast(t)
a=adapter();
a.viewData=@themeViewData;
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services()); t.addTeardown(@() colormeasuretest.disposeSession(s));
s.show(); s.measure(); fig=s.window;
set(colormeasuretest.field(fig,'SampleName'),'String','Pending name');
set(colormeasuretest.field(fig,'SampleNotes'),'Value',{'Uncommitted notes';'Second paragraph'});
figureState=struct('measurements',s.measurements,'files',s.files,'log',s.log);
background=colormeasuretest.field(fig,'ChromaticityBackground');
point=colormeasuretest.field(fig,'ReadingChromaticity');
fig.Theme='dark'; drawnow;
verifyEqual(t,max(background.AlphaData(:)),.42,'AbsTol',1e-12);
verifyEqual(t,point.MarkerEdgeColor,[.9 .9 .9]);
fig.Theme='light'; drawnow;
verifyEqual(t,max(background.AlphaData(:)),.28,'AbsTol',1e-12);
verifyEqual(t,point.MarkerEdgeColor,[.16 .16 .16]);
verifyEqual(t,struct('measurements',s.measurements,'files',s.files,'log',s.log),figureState);
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending name');
verifyEqual(t,colormeasuretest.field(fig,'SampleNotes').Value,{'Uncommitted notes';'Second paragraph'});
verifyEqual(t,colormeasuretest.field(fig,'ResultsTable').UserData,1);
end

function reading=failedRead(~) %#ok<STOUT>
error('Test:Read','Synthetic target unavailable');
end
function controls=visibleControls(fig)
controls=findall(fig,'Visible','on','-and', ...
    {'Type','uicontrol','-or','Type','uitextarea','-or','Type','uilabel'}); keep=true(size(controls));
for k=1:numel(controls)
    parent=get(controls(k),'Parent');
    while parent~=fig
        if isprop(parent,'Visible') && strcmp(char(get(parent,'Visible')),'off')
            keep(k)=false; break
        end
        if isa(parent,'matlab.ui.container.Tab') && parent.Parent.SelectedTab~=parent
            keep(k)=false;break
        end
        parent=get(parent,'Parent');
    end
end
controls=controls(keep);
end
function s=makeSession(t,io)
if nargin<2, io=colormeasure.ui.services(); end
% These generic XYZ fixtures have no representable units/scale. Keep their
s=colormeasure.session.Session(adapter(),t.TestData.folder,io); t.addTeardown(@() colormeasuretest.disposeSession(s));
end
function a=adapter()
a=struct('key','TEST_UI','label','Test measurements','listPorts',@(~) "VIRTUAL", ...
    'connect',@(~) colormeasuretest.session.Instrument(@() struct('XYZ',[1 2 3]),@() []), ...
    'read',@(i) i.Read(), 'release',@(i) delete(i), ...
    'toTable',@(m,~) table((1:numel(m))','VariableNames',{'Index'}));
end
function data=themeViewData(m)
xyz=zeros(0,3); if ~isempty(m), xyz=vertcat(m.XYZ); end
 data=struct('XYZ',xyz, ...
    'locusXYZ',[.1741 .0050 .8209; .0039 .6548 .3413; .7347 .2653 0]);
end

function stopTimer(worker)
if isvalid(worker),stop(worker);delete(worker);end
end

function [released,problem]=runWithPreparationKeyRelease(action,event)
% Both normal shortcut handling and the failure control use this timer guard.
released=false;problem=[];started=tic;before=findall(groot,'Type','figure');
worker=timer('ExecutionMode','fixedSpacing','Period',.1,'StartDelay',.1, ...
    'BusyMode','drop','Tag','PreparationShortcutKeyRelease','TimerFcn',@releaseInDialog);
% The timer's nested callback retains this workspace. Release the timer before
% propagating an action/start error rather than waiting for onCleanup to die.
try
    start(worker);
    action();
catch failure
    stopTimer(worker);
    rethrow(failure);
end
stopTimer(worker);
    function releaseInDialog(~,~)
        % After release, the reading and save run inside the same keypress.
        if released,return;end
        try
            assert(toc(started)<30,'Test:DialogTimeout','The preparation dialog did not appear.');
            dialog=findall(groot,'Tag','PreparationDialog');dialog=dialog(~ismember(dialog,before));
            if ~isscalar(dialog)||~strcmp(dialog.Visible,'on'),return;end
            ready=findall(dialog,'Tag','PreparationReady');if isempty(ready),return;end
            assert(~isempty(dialog.WindowKeyReleaseFcn),'Test:KeyRelease','The dialog must relay key releases.');
            dialog.WindowKeyReleaseFcn(dialog,event);released=true;colormeasuretest.click(ready);
        catch err
            problem=err;created=findall(groot,'Type','figure');delete(created(~ismember(created,before)));
        end
    end
end

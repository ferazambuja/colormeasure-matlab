function tests=testChartCleanupWindow
% Authored callbacks only: operator declarations never validate hardware.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@()set(groot,'DefaultFigureVisible',visible));
end
function testCancelAndUncheckedDeclarationNeverClearTheStopOrAcquire(t)
[s,counts]=session(t);s.show();before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);
colormeasuretest.click(field(s.window,'ConfirmChartCleanupButton'));
f=findall(groot,'Tag','ChartCleanupConfirmationDialog');verifyNumElements(t,f,1);
verifySubstring(t,field(s.window,'RecoveryMessage').String,'Connection cleanup unconfirmed');
verifySubstring(t,field(s.window,'RecoveryMessage').TooltipString,'The app can no longer reach the instrument connection');
verifySubstring(t,field(s.window,'RecoveryMessage').TooltipString,'no MATLAB batch or other program still uses the instrument port');
intro=field(f,'ChartCleanupIntroduction').Text;
verifySubstring(t,intro,'can no longer reach this batch''s instrument connection');
verifySubstring(t,intro,'unplugging and reconnecting the instrument cable');
verifyFalse(t,field(f,'ChartCleanupConnectionClosed').Value);verifyFalse(t,field(f,'ChartCleanupInstrumentIdle').Value);
explain(f);verifyEqual(t,char(field(f,'ChartCleanupConfirm').Enable),'off');
colormeasuretest.click(field(f,'ChartCleanupConfirm'));verifyTrue(t,s.chartIoUnconfirmed);
key=f.WindowKeyPressFcn;key(f,struct('Key','escape','Modifier',{{}}));verifyFalse(t,isgraphics(f));
verifyEqual(t,s.info,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyEqual(t,counts('reads'),0);
end
function testTwoChecksAndExplanationRetainOneDeclarationWithoutReading(t)
[s,counts]=session(t);s.show();colormeasuretest.click(field(s.window,'ConfirmChartCleanupButton'));
f=findall(groot,'Tag','ChartCleanupConfirmationDialog');explain(f);
check(f,'ChartCleanupConnectionClosed');verifyEqual(t,char(field(f,'ChartCleanupConfirm').Enable),'off');
check(f,'ChartCleanupInstrumentIdle');verifyEqual(t,char(field(f,'ChartCleanupConfirm').Enable),'on');
colormeasuretest.click(field(f,'ChartCleanupConfirm'));verifyFalse(t,isgraphics(f));verifyFalse(t,s.chartIoUnconfirmed);
verifyEqual(t,counts('reads'),0);verifyEqual(t,counts('releases'),0);verifyEmpty(t,s.measurements);
saved=load(s.files.mat);verifyFalse(t,saved.batchInfo.continuationGuard.operationActive);
verifySubstring(t,jsonencode(saved.batchInfo),'Controlled operator cleanup check');
verifyEqual(t,char(field(s.window,'ConfirmChartCleanupButton').Visible),'off');
verifyEqual(t,char(field(s.window,'MeasureButton').Enable),'on');
end
function testConfirmationSaveFailureAndRetryTakeNoNewReading(t)
for chart=[true false]
    [s,counts]=session(t,true,chart);s.show();colormeasuretest.click(field(s.window,'ConfirmChartCleanupButton'));
    f=findall(groot,'Tag','ChartCleanupConfirmationDialog');explain(f);
    check(f,'ChartCleanupConnectionClosed');check(f,'ChartCleanupInstrumentIdle');counts('failSave')=true;
    before=s.measurements;colormeasuretest.click(field(f,'ChartCleanupConfirm'));
    verifyTrue(t,isgraphics(f));verifyTrue(t,s.needsRecovery);verifyNotEmpty(t,s.saveError);
    verifySubstring(t,field(f,'ChartCleanupMessage').Text,'saving needs attention');
    verifyEqual(t,field(f,'ChartCleanupMessage').Tooltip,field(f,'ChartCleanupMessage').Text);
    colormeasuretest.click(field(f,'ChartCleanupCancel'));counts('failSave')=false;
    colormeasuretest.click(field(s.window,'RetrySaveButton'));
    verifyEmpty(t,s.saveError);verifyFalse(t,s.needsRecovery);verifyEqual(t,s.measurements,before);
    verifyEqual(t,counts('reads'),0);verifyEqual(t,counts('releases'),0);
end
end
function testRecoveryActionsFitTheMinimumWidthWithoutOverlap(t)
[s,counts]=session(t);s.show();counts('failSave')=true;s.retrySave();
s.window.Position=[30 30 960 750];s.window.SizeChangedFcn(s.window,[]);
message=field(s.window,'RecoveryMessage');verifyEqual(t,char(message.Visible),'on');
right=message.Position(1)+message.Position(3);
for tag={'ConfirmChartCleanupButton','RetrySaveButton','SaveElsewhereButton'}
    button=field(s.window,tag{1});verifyEqual(t,char(button.Visible),'on');
    verifyGreaterThanOrEqual(t,button.Position(1),right+8);
    verifyLessThanOrEqual(t,button.Position(1)+button.Position(3),944);
    right=button.Position(1)+button.Position(3);
end
verifyGreaterThanOrEqual(t,message.Position(3),200);verifyEqual(t,counts('reads'),0);
end
function testReachableOwnerRefusesDeclarationAndFailedRetryRetainsIt(t)
[s,counts]=session(t,false);s.show();before=s.measurements;
verifyTrue(t,s.directCleanupCanRetry);verifyEqual(t,counts('releases'),1);
verifyEqual(t,char(field(s.window,'ConfirmChartCleanupButton').Visible),'off');
verifyEqual(t,char(field(s.window,'RetryChartCleanupButton').Visible),'on');
verifyError(t,@()s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='Cannot bypass the retained owner.'),'Measurement:ConnectionCleanup');
colormeasuretest.click(field(s.window,'ConfirmChartCleanupButton'));
verifyEmpty(t,findall(groot,'Tag','ChartCleanupConfirmationDialog'));
colormeasuretest.click(field(s.window,'RetryChartCleanupButton'));
verifyEqual(t,counts('releases'),2);verifyTrue(t,s.chartIoUnconfirmed);verifyTrue(t,s.directCleanupCanRetry);
verifyEqual(t,s.measurements,before);verifyEqual(t,counts('reads'),1);verifyEqual(t,counts('connects'),1);
verifyEqual(t,char(field(s.window,'MeasureButton').Enable),'off');
verifySubstring(t,field(s.window,'RecoveryMessage').TooltipString,'Retry cleanup');
end
function testSuccessfulOwnedCleanupClosesOnlyThatOwnerAndTakesNoReading(t)
[s,counts]=session(t,false);s.show();before=s.measurements;counts('failRelease')=false;
colormeasuretest.click(field(s.window,'RetryChartCleanupButton'));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);verifyFalse(t,s.needsRecovery);
verifyEqual(t,counts('releases'),2);verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('reads'),1);
verifyEqual(t,s.measurements,before);verifyEqual(t,char(field(s.window,'RetryChartCleanupButton').Visible),'off');
verifyEqual(t,char(field(s.window,'ConfirmChartCleanupButton').Visible),'off');
verifyEqual(t,char(field(s.window,'MeasureButton').Enable),'on');
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
end
function testOwnedCleanupSaveFailureUsesSaveRecoveryWithoutRepeatingRelease(t)
[s,counts]=session(t,false);s.show();before=s.measurements;counts('failRelease')=false;counts('failSave')=true;
colormeasuretest.click(field(s.window,'RetryChartCleanupButton'));
verifyFalse(t,s.directCleanupCanRetry);verifyFalse(t,s.chartIoUnconfirmed);verifyTrue(t,s.needsRecovery);
verifyEqual(t,char(field(s.window,'RetrySaveButton').Visible),'on');verifyNotEmpty(t,s.saveError);
counts('failSave')=false;colormeasuretest.click(field(s.window,'RetrySaveButton'));
verifyFalse(t,s.needsRecovery);verifyEqual(t,s.measurements,before);verifyEqual(t,counts('releases'),2);
verifyEqual(t,counts('reads'),1);verifyEqual(t,counts('connects'),1);
end
function testOrdinarySettingsCannotReplaceARetainedConnectionOwner(t)
[s,counts]=session(t,false,false);s.show();before=s.measurements;verifyEmpty(t,s.chart);
verifyEqual(t,char(field(s.window,'RetryChartCleanupButton').Visible),'on');
measure=field(s.window,'MeasureButton');verifyEqual(t,char(measure.Enable),'off');
verifySubstring(t,measure.TooltipString,'cleanup');
name=field(s.window,'SampleName');name.String='Pending after cleanup';beforeInfo=s.info;
colormeasuretest.click(measure);verifyEqual(t,s.info,beforeInfo);verifyEqual(t,name.String,'Pending after cleanup');
verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('reads'),1);
[~,modifiers]=colormeasure.ui.measureShortcut();
press=s.window.WindowKeyPressFcn;release=s.window.WindowKeyReleaseFcn;
s.window.Visible='on';
status=field(s.window,'CurrentStatus');
set(status,'String','Shortcut feedback sentinel','TooltipString','Shortcut feedback sentinel');
press(s.window,struct('Key','m','Modifier',{modifiers}));
release(s.window,struct('Key','m','Modifier',{modifiers}));
verifySubstring(t,status.String,'Connection cleanup is unconfirmed');verifySubstring(t,status.TooltipString,'cleanup');
verifyEqual(t,s.info,beforeInfo);verifyEqual(t,s.measurements,before);
verifyEqual(t,name.String,'Pending after cleanup');
verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('reads'),1);
colormeasuretest.click(field(s.window,'InstrumentSettingsButton'));f=findall(groot,'Tag','InstrumentSettingsWindow');
read=field(f,'ReadInstrumentSettings');verifyEqual(t,char(read.Enable),'off');
verifySubstring(t,read.Tooltip,'cleanup');colormeasuretest.click(read);
verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('releases'),1);verifyEqual(t,s.measurements,before);
f.CloseRequestFcn(f,[]);counts('failRelease')=false;
colormeasuretest.click(field(s.window,'RetryChartCleanupButton'));
verifyFalse(t,s.directCleanupCanRetry);verifyFalse(t,s.chartIoUnconfirmed);verifyEqual(t,counts('releases'),2);
verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('reads'),1);verifyEqual(t,s.measurements,before);
colormeasuretest.click(field(s.window,'InstrumentSettingsButton'));f=findall(groot,'Tag','InstrumentSettingsWindow');
verifyEqual(t,char(field(f,'ReadInstrumentSettings').Enable),'on');
end
function testOrdinaryInaccessibleReturnedOwnerOffersExplicitConfirmation(t)
[s,counts]=session(t,false,false,true);s.show();before=s.measurements;
verifyEmpty(t,s.chart);verifyTrue(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);
verifyEqual(t,char(field(s.window,'RetryChartCleanupButton').Visible),'off');
verifyEqual(t,char(field(s.window,'ConfirmChartCleanupButton').Visible),'on');
colormeasuretest.click(field(s.window,'ConfirmChartCleanupButton'));f=findall(groot,'Tag','ChartCleanupConfirmationDialog');
explain(f);check(f,'ChartCleanupConnectionClosed');check(f,'ChartCleanupInstrumentIdle');
colormeasuretest.click(field(f,'ChartCleanupConfirm'));verifyFalse(t,isgraphics(f));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.needsRecovery);verifyEqual(t,s.measurements,before);
verifyEqual(t,counts('reads'),1);verifyEqual(t,counts('connects'),1);verifyEqual(t,counts('releases'),1);
saved=load(s.files.mat);verifyEqual(t,saved.batchInfo.chartIoConfirmations.runId,'');
verifySubstring(t,saved.batchInfo.chartIoConfirmations.declaration,'Controlled operator cleanup check');
end
function testChartFooterNamesTheActualRecoveryAfterFinish(t)
% The footer says what is pending: cleanup, saving, both, or nothing.
[s,counts]=session(t);s.show();detail=@()field(s.window,'GuidedChartPatchDetail').Text;
verifySubstring(t,detail(),'Connection cleanup is unconfirmed. Resolve it before another measurement.');
s.finish(AllowIncompleteChart=true);verifyTrue(t,s.finished);
verifyEqual(t,s.status,'Cleanup unconfirmed | Finished | 0 readings saved');
verifySubstring(t,detail(),'Batch closed and saved. Connection cleanup is unconfirmed. Resolve it before another batch.');
verifyFalse(t,contains(detail(),'save retained output'));
verifySubstring(t,field(s.window,'NewBatchButton').TooltipString, ...
    'Connection cleanup is unconfirmed. Resolve it before starting a new batch.');
counts('failSave')=true;folder=fullfile(t.TestData.folder,'another');mkdir(folder);s.saveElsewhere(folder);
verifySubstring(t,detail(),'save retained output and resolve connection cleanup');
counts('failSave')=false;s.retrySave();verifyEmpty(t,s.saveError);
s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true,Declaration='Checked.');
verifySubstring(t,detail(),'Batch closed. Retained chart inspection only.');
counts('failSave')=true;second=fullfile(t.TestData.folder,'second');mkdir(second);s.saveElsewhere(second);
verifySubstring(t,detail(),'Batch closed. Use the recovery controls to save retained output.');
verifyEqual(t,counts('reads'),0);
end
function [s,counts]=session(t,noOwner,chart,invalidOwner)
if nargin<2,noOwner=true;end
if nargin<3,chart=true;end
if nargin<4,invalidOwner=false;end
counts=containers.Map('KeyType','char','ValueType','any');
counts('reads')=0;counts('releases')=0;counts('connects')=0;counts('failSave')=false;counts('failRelease')=true;peer=[];
a=colormeasure.drivers.cr.demoAdapter('CR250','interactive');read=a.read;a.read=@acquire;a.release=@release;a.connect=@connect;
io=colormeasure.ui.services();io.createView=@(value)colormeasure.ui.Window(value,@(~,~)true);io.saveMat=@persist;
s=colormeasure.session.Session(a,t.TestData.folder,io);t.addTeardown(@()colormeasuretest.disposeSession(s));
t.addTeardown(@disposePeer);
if chart,s.startChart(colormeasure.chart.definition('custom','Unconfirmed cleanup',1,2));end
completed=s.measure();
assert(completed==~noOwner&&s.chartIoUnconfirmed,'Fixture:Cleanup','The controlled failure must retain its stop guard.');
    function value=acquire(instrument),counts('reads')=counts('reads')+1;value=read(instrument);end
    function value=connect(~)
        counts('connects')=counts('connects')+1;
        if noOwner,error('Fixture:Connect','Controlled connection failure with no returned owner.');end
        peer=colormeasuretest.session.Instrument([],@()[]);value=peer;
    end
    function release(value)
        counts('releases')=counts('releases')+1;
        if counts('failRelease')
            if invalidOwner,delete(value);end
            error('Fixture:Release','Controlled unconfirmed release.');
        end
        delete(value);
    end
    function persist(varargin)
        if counts('failSave'),error('Fixture:Save','Controlled cleanup declaration save failure.');end
        colormeasure.session.saveMat(varargin{:});
    end
    function disposePeer()
        colormeasuretest.dispose(peer);
    end
end
function explain(f)
control=field(f,'ChartCleanupDeclaration');control.Value={'Controlled operator cleanup check'};
control.ValueChangedFcn(control,[]);
end
function check(f,tag)
control=field(f,tag);control.Value=true;control.ValueChangedFcn(control,[]);
end
function control=field(parent,tag)
control=findobj(parent,'Tag',tag);assert(isscalar(control),'Fixture:Control','Expected one control: %s.',tag);
end

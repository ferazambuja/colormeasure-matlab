function tests=testChartContinuationWindow
% Core-validated virtual facts exercise the public continuation UI path.
% Callback checks prove action routing and retention, not physical hardware,
% native keyboard focus, screen-reader announcements or OS picker behavior.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@()set(groot,'DefaultFigureVisible',visible));
registry=getappdata(groot,'ColorMeasureSessions');setappdata(groot,'ColorMeasureSessions',[]);
t.addTeardown(@()setappdata(groot,'ColorMeasureSessions',registry));
names=evalin('base','who(''chartContinuation_*'',''colorMeasureCR250DemoSession'')');
values=cellfun(@(name)evalin('base',name),names,'UniformOutput',false);
t.addTeardown(@()restoreWorkspace(names,values));
end
function testNativePreviewCancelAndPassSelectionAreReadOnly(t)
[s,e]=source(t);first=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();s.measure();
before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);calls=0;
p=s.prepareChartContinuation(s);s.show();
view=colormeasure.ui.ChartContinuationView(s.window,p,'Retained batch',@unexpected, ...
    @(declarations,passId)s.prepareChartContinuation(s,Declarations=declarations,PassId=passId),@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
pass=field(dialog,'ChartContinuationPass');verifyNumElements(t,pass.Items,2);
verifyEqual(t,field(dialog,'ChartContinuationSummary').Text, ...
    '1 row × 2 columns · 2 of 2 patches measured in the selected pass · 2 retained attempts.');
pass.Value=first;pass.ValueChangedFcn(pass,[]);
verifyEqual(t,field(dialog,'ChartContinuationSummary').Text, ...
    '1 row × 2 columns · 1 of 2 patches measured in the selected pass · 1 retained attempt.');
verifyEqual(t,s.info,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifyEqual(t,e('reads'),3);verifyEqual(t,calls,0);
verifyNotEmpty(t,field(dialog,'ChartContinuationDifferences').Data);
dialog.WindowKeyPressFcn(dialog,struct('Key','escape','Modifier',{{}}));
verifyFalse(t,isgraphics(dialog));verifyFalse(t,s.finished);verifyEqual(t,s.info,before);
    function accepted=unexpected(varargin),calls=calls+1;accepted=false;end
end
function testNestedMaterialFactsUseSharedLabelsWithoutChangingSource(t)
[s,e]=source(t,services(),colormeasure.chart.definition('custom','One patch',1,1));
s.show();before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);
p=s.prepareChartContinuation(s);
% Presentation-only facts exercise recursive struct and cell formatting.
fact=struct('value',struct('measurementAngleDegrees',45,'captureFilters', ...
    {{struct('filter1','clear')}}),'certainty','readback');
p.sourceContext.material.nativeSettings=fact;p.currentContext.material.nativeSettings=fact;
p.sourceContext.requiredMaterial{end+1}='nativeSettings';
p.currentContext.requiredMaterial{end+1}='nativeSettings';
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@(~,~,~,~,~)false,@(~,~)p,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));rows=field(view.Figure,'ChartContinuationDifferences').Data;
verifyEqual(t,field(view.Figure,'ChartContinuationSummary').Text, ...
    '1 row × 1 column · 1 of 1 patch measured in the selected pass · 1 retained attempt.');
verifySubstring(t,field(view.Figure,'ChartContinuationPass').Items{1},'1 of 1 patch measured');
verifyTrue(t,any(contains(string(rows(:,2)),'Measurement angle (degrees): 45')));
verifyTrue(t,any(contains(string(rows(:,2)),'Filter 1: clear')));
verifyEqual(t,s.info,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifyEqual(t,e('reads'),1);verifyFalse(t,s.finished);
end
function testUnestablishedAndVersionConditionsDisableContinuation(t)
[s,e]=source(t);s.show();p=s.prepareChartContinuation(s);before=s.info;
bytes=colormeasuretest.readBytes(s.files.mat);
% Presentation-only mutation tests Core's reported decision, not continuity.
p.continueEligible=false;p.unknowns={'Unobserved fitted accessory'};
p.requiredAcknowledgment=true;p.versionNotes={'Reported capabilities changed'};
applied={};view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@apply,@refresh,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
verifySubstring(t,field(dialog,'ChartContinuationDecision').Value{1},'Use a new pass');
verifyTrue(t,any(contains(field(dialog,'ChartContinuationDecision').Value,'Unobserved fitted accessory')));
% Core can block both routes independently of reported unknown conditions.
% The preview must lead with that reason without recommending either action.
allowed=p;p.newPassEligible=false;
p.blockedReason='Recover saving in the open source batch before continuing this earlier copy.';
colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEqual(t,field(dialog,'ChartContinuationDecision').Value{1},p.blockedReason);
verifyFalse(t,any(contains(field(dialog,'ChartContinuationDecision').Value,'Use a new pass')));
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
colormeasuretest.click(field(dialog,'ChartContinuationContinue'));
colormeasuretest.click(field(dialog,'ChartContinuationNewPass'));verifyEmpty(t,applied);
verifyEqual(t,s.info,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifyEqual(t,e('reads'),1);
p=allowed;
p.continueEligible=true;p.unknowns={};colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
ack=field(dialog,'ChartContinuationAcknowledgment');ack.Value=true;ack.ValueChangedFcn(ack,[]);
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
ack.Value=false;ack.ValueChangedFcn(ack,[]);
colormeasuretest.click(field(dialog,'ChartContinuationNewPass'));
verifyEqual(t,applied,{'new-pass',false});verifyFalse(t,isgraphics(dialog));
    function accepted=apply(~,action,~,acknowledged,~),applied={action,acknowledged};accepted=true;end
    function value=refresh(varargin),value=p;end
end
function testFailedRefreshDisablesStaleActionsUntilSuccessfulRecovery(t)
[s,~]=source(t);s.show();p=s.prepareChartContinuation(s);failed=true;before=s.info;
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@(~,~,~,~,~)false,@refresh,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationCancel').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationRefresh').Enable),'on');
verifySubstring(t,field(dialog,'ChartContinuationError').Text,'Cannot read source');
failed=false;colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
verifyEmpty(t,field(dialog,'ChartContinuationError').Text);verifyEqual(t,s.info,before);verifyFalse(t,s.finished);
    function value=refresh(varargin)
        if failed,error('Measurement:ChartContinuationSource','Cannot read source.');end
        value=p;
    end
end
function testFailedPassRefreshRollsBackTheDisplayedPassWithoutAcquisition(t)
[s,e]=source(t);first=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();s.show();
p=s.prepareChartContinuation(s);before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@(~,~,~,~,~)false,@refuse,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
pass=field(dialog,'ChartContinuationPass');pass.Value=first;pass.ValueChangedFcn(pass,[]);
verifyEqual(t,pass.Value,p.source.passId);verifyEqual(t,s.info,before);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyEqual(t,e('reads'),2);
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifySubstring(t,field(dialog,'ChartContinuationError').Text,'Controlled pass refusal');
dialog.WindowKeyPressFcn(dialog,struct('Key','period','Modifier',{{'command'}}));verifyFalse(t,isgraphics(dialog));
    function result=refuse(varargin) %#ok<STOUT>
        error('Fixture:Pass','Controlled pass refusal.');
    end
end
function testInvalidDeclarationsRemainVisibleAcrossChoiceChanges(t)
[s,~]=source(t);s.show();p=s.prepareChartContinuation(s);
% Authored presentation packet exercises all three editor types. The Core
% integration checks below separately validate actual allowed declarations.
p.declarableFacts=struct('key',{'measurementAngleDegrees','serial','externalNDFilter'}, ...
    'label',{'Measurement angle (degrees)','Instrument serial number','External ND filter'}, ...
    'valueType',{'number','text','logical'},'sourceValue',{[],[],[]},'targetValue',{[],[],[]});
refreshes=0;accepted=false;
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@apply,@refresh,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
colormeasuretest.click(field(dialog,'ChartContinuationDeclarations'));
enabled=field(dialog,'ChartContinuationDeclarationEnabled');enabled.Value=true;enabled.ValueChangedFcn(enabled,[]);
value=field(dialog,'ChartContinuationDeclarationValue');value.Value='0,5';value.ValueChangedFcn(value,[]);
verifyEqual(t,value.Value,'0,5');verifySubstring(t,field(dialog,'ChartContinuationError').Text,'without commas');
choice=field(dialog,'ChartContinuationDeclarationChoice');choice.Value='serial';choice.ValueChangedFcn(choice,[]);
verifySubstring(t,field(dialog,'ChartContinuationError').Text,'Measurement angle');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
choice.Value='measurementAngleDegrees';choice.ValueChangedFcn(choice,[]);verifyEqual(t,value.Value,'0,5');
value.Value='0.5';value.ValueChangedFcn(value,[]);verifyEqual(t,refreshes,1);
choice.Value='externalNDFilter';choice.ValueChangedFcn(choice,[]);
enabled.Value=true;enabled.ValueChangedFcn(enabled,[]);
boolean=field(dialog,'ChartContinuationDeclarationBoolean');verifyEmpty(t,boolean.Value);
verifySubstring(t,field(dialog,'ChartContinuationError').Text,'choose Yes');
boolean.Value='no';boolean.ValueChangedFcn(boolean,[]);verifyEqual(t,refreshes,2);
colormeasuretest.click(field(dialog,'ChartContinuationContinue'));verifyTrue(t,accepted);
    function result=refresh(declarations,passId)
        refreshes=refreshes+1;result=p;result.declarationValues=declarations;
        verifyEqual(t,passId,p.source.passId);
        if isfield(declarations,'measurementAngleDegrees'),verifyEqual(t,declarations.measurementAngleDegrees,0.5);end
        if isfield(declarations,'externalNDFilter'),verifyEqual(t,declarations.externalNDFilter,false);end
    end
    function result=apply(~,~,declarations,~,~)
        verifyEqual(t,declarations.measurementAngleDegrees,0.5);verifyEqual(t,declarations.externalNDFilter,false);
        accepted=true;result=true;
    end
end
function testAcceptanceErrorKeepsThePreviewAndSource(t)
[s,~]=source(t);s.show();p=s.prepareChartContinuation(s);before=s.info;
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@refuse, ...
    @(declarations,passId)s.prepareChartContinuation(s,Declarations=declarations,PassId=passId),@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
colormeasuretest.click(field(dialog,'ChartContinuationContinue'));
verifyTrue(t,isgraphics(dialog));verifySubstring(t,field(dialog,'ChartContinuationError').Text,'Source changed');
verifyEqual(t,s.info,before);verifyFalse(t,s.finished);
verifyEqual(t,char(field(dialog,'ChartContinuationCancel').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
    function accepted=refuse(varargin) %#ok<STOUT>
        error('Measurement:ChartContinuationStale','Source changed. Preview again.');
    end
end
function testClosedPreviewIgnoresQueuedFigureAndAcknowledgmentCallbacks(t)
[s,~]=source(t);s.show();p=s.prepareChartContinuation(s);before=s.info;
view=colormeasure.ui.ChartContinuationView(s.window,p,'Source',@(~,~,~,~,~)false,@(~,~)p,@()[]);
dialog=view.Figure;key=dialog.WindowKeyPressFcn;ack=field(dialog,'ChartContinuationAcknowledgment');
changed=ack.ValueChangedFcn;colormeasuretest.click(field(dialog,'ChartContinuationCancel'));
verifyWarningFree(t,@()key(dialog,struct('Key','escape','Modifier',{{}})));
verifyWarningFree(t,@()changed(ack,[]));verifyEqual(t,s.info,before);verifyFalse(t,s.finished);
end
function testCancelPublicFlowKeepsReadingsAndSavedBytes(t)
io=services();io.chooseChartContinuation=@(~)[];[s,e]=source(t,io);s.show();
before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);saves=e('saves');
[r,action]=colormeasure.ui.continueChart(s,s);
verifyEmpty(t,r);verifyEmpty(t,action);verifyFalse(t,s.finished);verifyEqual(t,s.info,before);
verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),1);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
end
function testPublicFlowLinksWithoutReadingAndShowsInheritedProvenance(t)
io=services();io.chooseChartContinuation=@(~)struct('action','continue','declarations',struct());
[s,e]=source(t,io);s.show();s.finish(AllowIncompleteChart=true);
% Restoring a window shows it even when its original creation was hidden.
s.show();verifyEqual(t,char(s.window.Visible),'on');
bytes=colormeasuretest.readBytes(s.files.mat);[r,action]=colormeasure.ui.continueChart(s,s.files.mat);
t.addTeardown(@()colormeasuretest.disposeSession(r));
verifyEqual(t,char(r.window.Visible),'on');verifyEqual(t,char(s.window.Visible),'off');
verifyEqual(t,action,'continue');verifyEmpty(t,r.measurements);verifyEqual(t,e('reads'),1);
verifyEqual(t,r.chart.coverage,1);verifyEqual(t,r.chart.runId,s.chart.runId);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Text,'Earlier batch reading #1');
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Tooltip,s.chart.segmentId);
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Tooltip,'1 earlier-batch attempt; 0 new attempts');
registry=colormeasure.session.sessionRegistry('get');verifyEqual(t,registry.sessions{1},r);
% Explicit readings exercise per-cell ordinals after the linked history.
% B1 is the pass's second attempt, but its own first attempt.
r.measure();grid=field(r.window,'GuidedChartGrid');
grid.CellSelectionCallback(grid,struct('Indices',[1 2]));
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Text,'attempt 1/1.');
verifyEqual(t,r.chart.passes(1).cells(2).selectedAttempt,2);
r.selectChartCell(1,1);r.measure();
grid.CellSelectionCallback(grid,struct('Indices',[1 1]));
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Text,'attempt 2/2.');
verifyEqual(t,r.chart.passes(1).cells(1).selectedAttempt,3);
verifySubstring(t,field(r.window,'GuidedChartPatchDetail').Tooltip,'1 earlier-batch attempt; 1 new attempt');
verifyEqual(t,e('reads'),3);verifyNumElements(t,r.measurements,2);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
end
function testNewPassDoesNotBorrowCoverageAndLiveFinishWaitsForConsent(t)
io=services();io.chooseChartContinuation=@(~)struct('action','new-pass','declarations',struct());
[s,e]=source(t,io);[target,state]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));state('serial')='ANOTHER-VIRTUAL-UNIT';target.measure();target.show();
verifyFalse(t,s.finished);[r,action]=colormeasure.ui.continueChart(target,s);
t.addTeardown(@()colormeasuretest.disposeSession(r));verifyEqual(t,action,'new-pass');
verifyTrue(t,s.finished);verifyTrue(t,target.finished);verifyEqual(t,r.chart.activePass,2);
verifyEqual(t,r.chart.coverage,0);verifyEqual(t,r.chart.passes(1).coverage,1);
verifyEmpty(t,r.measurements);verifyEqual(t,e('reads'),1);verifyEqual(t,state('reads'),1);
end
function testChoiceDeclarationsAreRecheckedThroughCoreBeforeAcceptance(t)
io=services();io.chooseChartContinuation=@choose;
[s,~]=source(t);[target,state]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));
% The placeholder leaves identity unestablished but preserves the native
% parsed-text encoding. An unknown encoding cannot be declared or waived.
state('serial')='unknown';target.measure();target.show();
[r,~]=colormeasure.ui.continueChart(target,s);t.addTeardown(@()colormeasuretest.disposeSession(r));
verifyEqual(t,r.chart.coverage,1);verifyEmpty(t,r.measurements);
verifyEqual(t,r.chart.continuation.declarations.serial,'VIRTUAL-CR250-001');
verifyEqual(t,state('reads'),1); % The declaration itself must not acquire another reading.
    function choice=choose(preview)
        verifyFalse(t,preview.continueEligible);
        choice=struct('action','continue','declarations',struct('serial','VIRTUAL-CR250-001'));
    end
end
function testPublicFlowReopensChosenOlderPassAndKeepsNewerHistory(t)
io=services();io.chooseChartContinuation=@choose;
[s,e]=source(t,io);first=s.chart.passes.id;s.setInstrumentSettings(struct('speed',2));
s.acceptChartContext();s.measure();s.show();before=s.chart;
% The source's adapter keeps observed speed=2. A separate current owner
% establishes its own speed=1 and quantities with one explicit fixture read;
% preview and acceptance must not acquire anything further or reuse that row.
[target,current]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));target.measure();target.show();
[r,~]=colormeasure.ui.continueChart(target,s);t.addTeardown(@()colormeasuretest.disposeSession(r));
verifyEqual(t,r.chart.activePass,1);verifyEqual(t,r.chart.passes(1).id,first);
verifyEqual(t,r.chart.sources.batchInfo.chart.activePass,2);
verifyEqual(t,r.chart.sources.batchInfo.chart.passes(2).attempts,before.passes(2).attempts);
verifyEqual(t,r.chart.currentCell,[1 2]);verifyEmpty(t,r.measurements);verifyEqual(t,e('reads'),2);
verifyEqual(t,current('reads'),1);
    function choice=choose(preview)
        verifyFalse(t,preview.continueEligible); % The newer speed=2 pass does not match the target.
        choice=struct('action','continue','declarations',struct(),'passId',first);
    end
end
function testInheritedSaveFailureUsesRetryWithoutReattachmentOrExposure(t)
io=services();io.chooseChartContinuation=@(~)struct('action','continue','declarations',struct());
[s,e]=source(t,io);s.show();s.finish(AllowIncompleteChart=true);s.show();e('failSave')=true;
[r,~]=colormeasure.ui.continueChart(s,s);t.addTeardown(@()colormeasuretest.disposeSession(r));
verifyTrue(t,r.needsRecovery);verifyTrue(t,r.chart.unsaved);verifyEqual(t,char(s.window.Visible),'off');
verifyEqual(t,char(field(r.window,'NewBatchButton').Enable),'off');
segment=r.chart.segmentId;e('failSave')=false;r.retrySave();
verifyFalse(t,r.needsRecovery);verifyEqual(t,r.chart.segmentId,segment);
verifyNumElements(t,r.chart.sources,1);verifyEqual(t,e('reads'),1);verifyEmpty(t,r.measurements);
end
function testWindowContinuationFirstSaveFailureDoesNotRestoreOldSetupOverRecovery(t)
[savedSource,sourceState]=source(t);savedSource.finish(AllowIncompleteChart=true);
bytes=colormeasuretest.readBytes(savedSource.files.mat);
io=services();io.pickChartContinuation=@pick;
choices=0;io.chooseChartContinuation=@choose;
[target,state]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));target.show();target.window.Visible='on';
colormeasuretest.click(field(target.window,'ChartButton'));
setup=findall(groot,'Tag','GuidedChartSetup');verifyNumElements(t,setup,1);state('failSave')=true;
colormeasuretest.click(field(setup,'GuidedChartOpenSaved'));
registry=colormeasure.session.sessionRegistry('get');index=find(strcmp(registry.keys,target.adapterKey),1);
assertNotEmpty(t,index,strjoin({target.log.message},newline));
receiver=registry.sessions{index};t.addTeardown(@()colormeasuretest.disposeSession(receiver));verifyEqual(t,choices,1);
verifyNotEqual(t,receiver,target);verifyTrue(t,target.finished);verifyEqual(t,char(target.window.Visible),'off');
verifyFalse(t,isgraphics(setup));verifyTrue(t,receiver.needsRecovery);verifyTrue(t,receiver.chart.unsaved);
verifyEqual(t,receiver.chart.activePass,2);verifyEqual(t,receiver.chart.coverage,0);
verifyEqual(t,char(field(receiver.window,'RetrySaveButton').Visible),'on');
verifyEqual(t,char(receiver.window.Visible),'on');verifyEqual(t,state('reads'),0);
state('failSave')=false;colormeasuretest.click(field(receiver.window,'RetrySaveButton'));
verifyFalse(t,receiver.needsRecovery);verifyEqual(t,state('reads'),0);verifyEqual(t,sourceState('reads'),1);
verifyEqual(t,colormeasuretest.readBytes(savedSource.files.mat),bytes);
    function [name,folder]=pick(varargin)
        [folder,stem,extension]=fileparts(savedSource.files.mat);name=[stem extension];
    end
    function choice=choose(preview)
        % This empty target has no observed capture identity. The recovery
        % test starts a separate pass rather than assuming comparability.
        assertTrue(t,preview.newPassEligible);choices=choices+1;
        choice=struct('action','new-pass','declarations',struct());
    end
end
function testRefusedWindowContinuationShowsTheErrorInsideItsExistingSetup(t)
io=services();io.pickChartContinuation=@pick;
[target,state]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));target.show();
colormeasuretest.click(field(target.window,'ChartButton'));
setup=findall(groot,'Tag','GuidedChartSetup');before=target.info;
colormeasuretest.click(field(setup,'GuidedChartOpenSaved'));
verifyTrue(t,isgraphics(setup));verifyNotEmpty(t,field(setup,'GuidedChartSetupError').Text);
verifyEqual(t,field(setup,'GuidedChartSetupError').Tooltip,field(setup,'GuidedChartSetupError').Text);
verifyEqual(t,target.info,before);verifyFalse(t,target.finished);verifyEmpty(t,target.chart);verifyEqual(t,state('reads'),0);
    function [name,folder]=pick(varargin),name='missing-chart.mat';folder=t.TestData.folder;end
end
function testDiskPickerCancelPreservesDraftAndCurrentBatch(t)
calls=0;io=services();io.pickChartContinuation=@cancel;
% Changing an existing chart remains guarded. A fresh draft owner exercises
% the actual saved-chart button without bypassing that retained boundary.
[target,~]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));target.show();before=target.info;
colormeasuretest.click(field(target.window,'ChartButton'));
dialog=findall(groot,'Tag','GuidedChartSetup');
colormeasuretest.click(field(dialog,'GuidedChartOpenSaved'));
verifyTrue(t,isgraphics(dialog));verifyEqual(t,target.info,before);verifyEmpty(t,target.chart);
verifyEqual(t,calls,1);verifyFalse(t,target.finished);colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
    function [name,folder]=cancel(varargin),calls=calls+1;name=0;folder=0;end
end
function testFinishedContinuationButtonRequiresSavedSourceWithoutReacquisition(t)
[s,e]=source(t);s.show();s.finish(AllowIncompleteChart=true);
button=field(s.window,'GuidedChartChange');verifyEqual(t,button.Text,'Continue chart…');
verifyEqual(t,char(button.Enable),'on');before=s.measurements;bytes=colormeasuretest.readBytes(s.files.mat);
previous=s.files.mat;e('failSave')=true;
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;s.saveElsewhere(folder);
verifyTrue(t,s.needsRecovery);verifyEqual(t,char(field(s.window,'GuidedChartChange').Enable),'off');
verifyEqual(t,colormeasuretest.readBytes(previous),bytes);verifyEqual(t,s.measurements,before);
e('failSave')=false;s.retrySave();verifyFalse(t,s.needsRecovery);
verifyEqual(t,char(field(s.window,'GuidedChartChange').Enable),'on');verifyEqual(t,e('reads'),1);
end
function testRetainedSourceChoiceCancelDoesNotHideOrFinishEitherBatch(t)
io=services();io.chooseChartContinuationSource=@(~)2;io.chooseChartContinuation=@(~)[];
[s,~]=source(t);s.show();s.show();colormeasure.session.sessionRegistry('put',s.adapterKey,s,s.saveParent);
[target,~]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(target));target.show();before=target.info;old=s.info;
colormeasuretest.click(field(target.window,'ChartButton'));
dialog=findall(groot,'Tag','GuidedChartSetup');
colormeasuretest.click(field(dialog,'GuidedChartOpenSaved'));
verifyTrue(t,isgraphics(dialog));verifyFalse(t,target.finished);verifyFalse(t,s.finished);
verifyEqual(t,target.info,before);verifyEqual(t,s.info,old);verifyEqual(t,char(s.window.Visible),'on');
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
end
function testCurrentUnfinishedBatchOffersItsLiveSourceWithoutDiskReload(t)
calls=0;io=services();io.chooseChartContinuationSource=@(~)2;io.chooseChartContinuation=@inspect;
io.pickChartContinuation=@unexpectedPicker;[s,e]=source(t,io);s.show();before=s.info;
bytes=colormeasuretest.readBytes(s.files.mat);colormeasuretest.click(field(s.window,'GuidedChartChange'));
dialog=findall(groot,'Tag','GuidedChartSetup');colormeasuretest.click(field(dialog,'GuidedChartOpenSaved'));
verifyEqual(t,calls,1);verifyEqual(t,s.info,before);verifyFalse(t,s.finished);verifyEqual(t,e('reads'),1);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyTrue(t,isgraphics(dialog));
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
    function choice=inspect(preview)
        calls=calls+1;verifyEqual(t,preview.sourceInput,s);choice=[];
    end
    function [name,folder]=unexpectedPicker(varargin) %#ok<STOUT>
        error('Test:UnexpectedPicker','A current live batch must not reload its unfinished MAT.');
    end
end
function testForeignRegistryOwnerRefusesBeforeFinishOrAttachment(t)
io=services();io.chooseChartContinuation=@(~)struct('action','continue','declarations',struct());
[s,e]=source(t,io);[foreign,~]=colormeasuretest.continuationBatch(t.TestData.folder,services());
t.addTeardown(@()colormeasuretest.disposeSession(foreign));s.show();
colormeasure.session.sessionRegistry('put',s.adapterKey,foreign,s.saveParent);before=s.info;saves=e('saves');
verifyError(t,@()colormeasure.ui.continueChart(s,s),'Measurement:ChartContinuationOwnership');
verifyEqual(t,s.info,before);verifyFalse(t,s.finished);verifyFalse(t,foreign.finished);verifyEqual(t,e('saves'),saves);
registry=colormeasure.session.sessionRegistry('get');verifyEqual(t,registry.sessions{1},foreign);
end
function testEndedSourceCleanupDeclarationGatesBothActions(t)
% A saved chart whose batch ended with unconfirmed cleanup needs the
% operator's two checks before either action; they reach acceptance only.
[s,e]=source(t);firstPass=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();
e('failRelease')=true;s.measure();assertTrue(t,s.chartIoUnconfirmed);
s.finish(AllowIncompleteChart=true);path=s.files.mat;
savedSource=load(path,'batchInfo');assertTrue(t,savedSource.batchInfo.continuationGuard.cleanupPending);
originalBytes=colormeasuretest.readBytes(path);sourceReads=e('reads');
colormeasuretest.disposeSession(s);
[target,targetEvents]=colormeasuretest.continuationBatch(t.TestData.folder,services());
t.addTeardown(@()colormeasuretest.disposeSession(target));verifyTrue(t,target.measure());target.show();
before=target.info;targetBytes=colormeasuretest.readBytes(target.files.mat);
targetReads=targetEvents('reads');targetSaves=targetEvents('saves');
p=target.prepareChartContinuation(path);verifyTrue(t,p.cleanupDeclarationRequired);verifyTrue(t,p.newPassEligible);
applied={};view=colormeasure.ui.ChartContinuationView(target.window,p,'Source',@apply,@refresh,@()[]);
t.addTeardown(@()colormeasuretest.dispose(view));dialog=view.Figure;
button=field(dialog,'ChartContinuationCleanup');verifyEqual(t,char(button.Visible),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
verifyTrue(t,any(contains(field(dialog,'ChartContinuationDecision').Value,'Select Confirm cleanup...')));
colormeasuretest.click(button);f=findall(groot,'Tag','ChartCleanupConfirmationDialog');verifyNumElements(t,f,1);
intro=field(f,'ChartCleanupIntroduction').Text;
verifySubstring(t,intro,'no longer open');verifySubstring(t,intro,'unplugging and reconnecting');
note=field(f,'ChartCleanupDeclaration');note.Value={'Unplugged the cable; display idle.'};note.ValueChangedFcn(note,[]);
for tag={'ChartCleanupConnectionClosed','ChartCleanupInstrumentIdle'}
    box=field(f,tag{1});box.Value=true;box.ValueChangedFcn(box,[]);
end
colormeasuretest.click(field(f,'ChartCleanupConfirm'));verifyFalse(t,isgraphics(f));
verifyEqual(t,button.Text,'Cleanup checks recorded');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),char(colormeasure.ui.onOff(p.continueEligible)));
% The same saved witness keeps its checks across refresh and pass selection.
colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEmpty(t,field(dialog,'ChartContinuationError').Text);
verifyEqual(t,button.Text,'Cleanup checks recorded');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
pass=field(dialog,'ChartContinuationPass');pass.Value=firstPass;pass.ValueChangedFcn(pass,[]);
verifyEqual(t,pass.Value,firstPass);verifyEqual(t,button.Text,'Cleanup checks recorded');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),char(colormeasure.ui.onOff(p.continueEligible)));
verifyEqual(t,colormeasuretest.readBytes(path),originalBytes);
% Re-saving a valid chart changes its consumed bytes, even if its run and
% uncertainty owner remain the same. An open old dialog must also retire.
oldDigest=p.source.sourceSha256;colormeasuretest.click(button);
oldDialog=findall(groot,'Tag','ChartCleanupConfirmationDialog');assertNumElements(t,oldDialog,1);
oldRecord=cleanupRecord(oldDialog);
loaded=load(path,'measurements','batchInfo');measurements=loaded.measurements;batchInfo=loaded.batchInfo;
batchInfo.chart.revision=batchInfo.chart.revision+1;batchInfo.chart.savedRevision=batchInfo.chart.revision;
save(path,'measurements','batchInfo');rewrittenBytes=colormeasuretest.readBytes(path);
verifyNotEqual(t,rewrittenBytes,originalBytes);
colormeasuretest.click(field(dialog,'ChartContinuationRefresh'));
verifyEmpty(t,field(dialog,'ChartContinuationError').Text);verifyNotEqual(t,p.source.sourceSha256,oldDigest);
verifyFalse(t,isgraphics(oldDialog));verifyEqual(t,button.Text,'Confirm cleanup...');
verifyError(t,@()oldRecord('Queued checks for the previous source.'),'Measurement:ChartContinuationSource');
verifyEqual(t,button.Text,'Confirm cleanup...');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'off');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),'off');
colormeasuretest.click(field(dialog,'ChartContinuationNewPass'));assertEmpty(t,applied);
colormeasuretest.click(field(dialog,'ChartContinuationContinue'));assertEmpty(t,applied);
% Fresh checks belong to the refreshed source, not the previous MAT bytes.
colormeasuretest.click(button);f=findall(groot,'Tag','ChartCleanupConfirmationDialog');assertNumElements(t,f,1);
note=field(f,'ChartCleanupDeclaration');note.Value={'Rechecked the current saved source; cable closed and instrument idle.'};
note.ValueChangedFcn(note,[]);
for tag={'ChartCleanupConnectionClosed','ChartCleanupInstrumentIdle'}
    box=field(f,tag{1});box.Value=true;box.ValueChangedFcn(box,[]);
end
colormeasuretest.click(field(f,'ChartCleanupConfirm'));verifyFalse(t,isgraphics(f));
verifyEqual(t,button.Text,'Cleanup checks recorded');
verifyEqual(t,char(field(dialog,'ChartContinuationNewPass').Enable),'on');
verifyEqual(t,char(field(dialog,'ChartContinuationContinue').Enable),char(colormeasure.ui.onOff(p.continueEligible)));
colormeasuretest.click(field(dialog,'ChartContinuationNewPass'));
verifyEqual(t,applied,{'new-pass','Rechecked the current saved source; cable closed and instrument idle.',p.source.sourceSha256});
verifyFalse(t,isgraphics(dialog));verifyEqual(t,colormeasuretest.readBytes(path),rewrittenBytes);
verifyEqual(t,target.info,before);verifyFalse(t,target.finished);
verifyEqual(t,colormeasuretest.readBytes(target.files.mat),targetBytes);
verifyEqual(t,targetEvents('reads'),targetReads);verifyEqual(t,targetEvents('saves'),targetSaves);
verifyEqual(t,e('reads'),sourceReads);
    function accepted=apply(preview,action,~,~,cleanup)
        applied={action,cleanup,preview.source.sourceSha256};accepted=true;
    end
    function value=refresh(declarations,passId)
        value=target.prepareChartContinuation(path,Declarations=declarations,PassId=passId);p=value;
    end
end
function record=cleanupRecord(dialog)
% Retain the actual queued callback without adding a production test API.
state=warning('off','MATLAB:structOnObject');restore=onCleanup(@()warning(state));
snapshot=struct(dialog.UserData);record=snapshot.Record;
end
function [s,e]=source(t,io,definition)
if nargin<2,io=services();end
if nargin<3,definition=colormeasure.chart.definition('custom','Linked grid',1,2);end
[s,e]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(definition);s.measure();
end
function io=services()
io=colormeasure.ui.services();io.createView=@(s)colormeasure.ui.Window(s,@(~,~)true);
end
function result=field(parent,tag)
result=colormeasuretest.field(parent,tag);
end
function restoreWorkspace(names,values)
current=evalin('base','who(''chartContinuation_*'',''colorMeasureCR250DemoSession'')');
added=setdiff(current,names);
if ~isempty(added),evalin('base',['clear ' strjoin(added,' ')]);end
for n=1:numel(names),assignin('base',names{n},values{n});end
end

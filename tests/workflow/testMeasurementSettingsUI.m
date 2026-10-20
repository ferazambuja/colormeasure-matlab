function tests = testMeasurementSettingsUI
% Advanced settings drafts and explicit actions; virtual instruments only.
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

function testOpeningAndInspectingSettingsLeavesSampleDraftAndInstrumentAlone(t)
[s,calls] = session(t); s.show();
name = colormeasuretest.control(s.window,'SampleName'); set(name,'String','Uncommitted sample');
colormeasuretest.click(colormeasuretest.control(s.window,'InstrumentSettingsButton'));
fig = settingsFigure(); t.addTeardown(@() closeFigure(fig));
select(fig,2);
verifyEqual(t,calls('connect'),0); verifyEqual(t,calls('readSettings'),0);
verifyEqual(t,calls('apply'),0); verifyEqual(t,calls('measure'),0);
verifyEqual(t,get(name,'String'),'Uncommitted sample');
verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyNotEmpty(t,colormeasuretest.control(fig,'SettingsExplanation').Data);
end

function testSelectedHelpUpdatesWithoutIOAndUnrelatedChangesKeepContent(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
details = colormeasuretest.control(fig,'SettingsExplanation');
original = details.Data;
s.setSample('Sample draft changed','Preserve reading position');
verifyEqual(t,details.Data,original);
select(fig,2);
verifyNotEqual(t,details.Data,original);
verifyTrue(t,contains(details.Data,'<h1>Synchronization</h1>'));
verifyTrue(t,contains(details.Data,'<h2>When to use</h2>'));
verifyTrue(t,contains(details.Data,'<li>Virtual test fixture</li>'));
selected = details.Data;
select(fig,2); verifyEqual(t,details.Data,selected);
verifyEqual(t,calls('connect'),0); verifyEqual(t,calls('readSettings'),0);
verifyEqual(t,calls('measure'),0); verifyEqual(t,calls('apply'),0);
end

function testThemeRefreshesHelpWithoutChangingSettingsOrIO(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
details = colormeasuretest.control(fig,'SettingsExplanation');
fig.Theme = 'dark'; drawnow;
verifyTrue(t,contains(details.Data,'color-scheme:dark'));
verifyTrue(t,contains(details.Data,'background:#242424;color:#eeeeee'));
fig.Theme = 'light'; drawnow;
verifyTrue(t,contains(details.Data,'color-scheme:light'));
verifyTrue(t,contains(details.Data,'background:#ffffff;color:#202020'));
verifyEmpty(t,fieldnames(s.settingsOverrides)); verifyEqual(t,calls('connect'),0);
end

function testEmptyCatalogClearsPreviouslySelectedHelp(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
details = colormeasuretest.control(fig,'SettingsExplanation');
verifyTrue(t,contains(details.Data,'Exposure duration in milliseconds.'));
calls('controls') = struct([]);
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifyTrue(t,contains(details.Data,'Settings are unavailable for this adapter.'));
verifyFalse(t,contains(details.Data,'Exposure duration in milliseconds.'));
verifyEmpty(t,colormeasuretest.control(fig,'InstrumentSettingsTable').Data);
verifyEqual(t,calls('measure'),0);
end

function testReplacementCatalogCannotRetainUnknownSettingHelp(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
select(fig,2);
c = controls(); calls('controls') = c(1); %#ok<NASGU> Read callback shares this map.
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
html = colormeasuretest.control(fig,'SettingsExplanation').Data;
verifyTrue(t,contains(html,'<h1>Exposure (ms)</h1>'));
verifyFalse(t,contains(html,'<h1>Synchronization</h1>'));
end

function testCancelDiscardsDraftAndUseStagesWithoutCommands(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
stageNumber(fig,120);
colormeasuretest.click(colormeasuretest.control(fig,'CancelInstrumentSettings'));
verifyFalse(t,isgraphics(fig)); verifyEmpty(t,fieldnames(s.settingsOverrides));
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
stageNumber(fig,240);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyFalse(t,isgraphics(fig));
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',240));
verifyEqual(t,calls('connect'),0); verifyEqual(t,calls('apply'),0);
verifyTrue(t,s.measure());
verifyEqual(t,calls('apply'),1); verifyEqual(t,calls('measure'),1);
verifyEqual(t,s.measurements.instrumentSettings.overrides,struct('exposureMilliseconds',240));
end

function testReadUpdatesObservedValuesAndPreservesDraft(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
stageNumber(fig,240);
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifyEqual(t,calls('readSettings'),1); verifyEqual(t,calls('measure'),0);
verifyEqual(t,calls('release'),1);
verifyEqual(t,colormeasuretest.control(fig,'SettingsNumber').Value,'240');
data = colormeasuretest.control(fig,'InstrumentSettingsTable').Data;
verifyEqual(t,data{1,2},'60'); verifyEqual(t,data{1,3},'240');
verifyEmpty(t,fieldnames(s.settingsOverrides));
end

function testPortChangeInvalidatesObservationAndKeepsDraftRequest(t)
[s,~] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings')); stageNumber(fig,240);
s.selectPort('VIRTUAL2');
verifyEmpty(t,s.settingsSnapshot);
data = colormeasuretest.control(fig,'InstrumentSettingsTable').Data;
verifyEqual(t,data{1,2},'Not read'); verifyEqual(t,data{1,3},'240');
end

function testEmptyNumericOverrideIsNotInventedAndCannotBeStaged(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
verifyEqual(t,colormeasuretest.control(fig,'SettingsNumber').Value,'');
check = colormeasuretest.control(fig,'SettingsOverride'); check.Value = true; colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig)); verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyNotEmpty(t,colormeasuretest.control(fig,'SettingsMessage').Text);
verifyEqual(t,calls('connect'),0);
end

function testClearIsDraftOnlyAndCloseMainDiscardsOpenEditor(t)
[s,calls] = session(t); s.setInstrumentSettings(struct('exposureMilliseconds',240)); s.show();
colormeasuretest.click(colormeasuretest.control(s.window,'InstrumentSettingsButton')); fig = settingsFigure();
colormeasuretest.click(colormeasuretest.control(fig,'ClearInstrumentOverrides'));
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',240));
close(s.window);
verifyFalse(t,isgraphics(fig)); verifyFalse(t,s.finished);
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',240));
verifyEqual(t,calls('connect'),0);
end
function testInvalidNumericTextSurvivesSelectionAndCanBeCorrected(t)
[s,calls]=session(t);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
number=colormeasuretest.control(fig,'SettingsNumber');
for text={'abc','Inf','1+2i'}
    number.Value=text{1};colormeasuretest.change(number);
    verifyEqual(t,number.Value,text{1});
    verifySubstring(t,colormeasuretest.control(fig,'SettingsAvailability').Text,'finite real number');
    select(fig,2);select(fig,1);verifyEqual(t,number.Value,text{1});
    colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
    verifyTrue(t,isgraphics(fig));verifyEqual(t,number.Value,text{1});
    verifyEmpty(t,fieldnames(s.settingsOverrides));
end
number.Value='240';colormeasuretest.change(number);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyFalse(t,isgraphics(fig));verifyEqual(t,s.settingsOverrides.exposureMilliseconds,240);
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('apply'),0);
end

function testCloseKeyFromHtmlDiscardsNativeSettingsDraftWithoutIO(t)
[s,calls]=session(t);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
stageNumber(fig,240);
pane=colormeasuretest.control(fig,'SettingsExplanation');
pane.HTMLEventReceivedFcn(pane,struct('HTMLEventName','dialogCloseKey'));
verifyFalse(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('apply'),0);
end

function testShortSettingsWindowKeepsTableAndCommitActionsUsable(t)
[s,~]=session(t);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
% uigridlayout defers pixel geometry for an invisible figure. The guarded
% worker uses -noFigureWindows; enabling this figure does not open a desktop.
fig.Visible='on';drawnow;
for height=[504 690]
    fig.Position=[50 50 640 height];drawnow;
    table=colormeasuretest.control(fig,'InstrumentSettingsTable');
    % Grid pixels arrive asynchronously from the UI client after the real
    % resize callback. Height alone can already match the 120-pixel minimum
    % while the buttons still retain the previous window width.
    expected=max(120,height-518);started=tic;
    tags={'UseInstrumentSettings','CancelInstrumentSettings','SettingsMessage'};
    while toc(started)<30
        settled=abs(table.Position(4)-expected)<=1;
        for tag=tags
            bounds=getpixelposition(colormeasuretest.control(fig,tag{1}),true);
            settled=settled&&all(bounds(1:2)>=0)&& ...
                all(bounds(1:2)+bounds(3:4)<=fig.Position(3:4));
        end
        if settled,break;end
        drawnow;pause(0.02);
    end
    verifyGreaterThanOrEqual(t,table.Position(4),120);
    verifyEqual(t,table.Position(4),expected,'AbsTol',1);
    verifyEqual(t,char(table.Parent.Scrollable),'on');
    for tag=tags
        bounds=getpixelposition(colormeasuretest.control(fig,tag{1}),true);
        verifyGreaterThanOrEqual(t,bounds(1:2),[0 0]);
        verifyLessThanOrEqual(t,bounds(1:2)+bounds(3:4),fig.Position(3:4));
    end
end
end

function testCloseDuringExplicitReadKeepsSessionAndReleasesInstrument(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); fig = view.Figure;
t.addTeardown(@() colormeasuretest.dispose(view));
calls('readHook') = @() close(fig);
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifyFalse(t,isgraphics(fig)); verifyTrue(t,isvalid(s));
verifyEqual(t,calls('release'),1); verifyEqual(t,calls('measure'),0);
verifyNotEmpty(t,s.settingsSnapshot);
end

function testUntouchedDraftTracksCommandWindowChanges(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
s.setInstrumentSettings(struct('exposureMilliseconds',120));
verifyEqual(t,colormeasuretest.control(fig,'SettingsNumber').Value,'120');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',120));
verifyEqual(t,calls('connect'),0);
end

function testEditedDraftCannotOverwriteNewCommandWindowSettings(t)
[s,calls] = session(t);
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
stageNumber(fig,240);
s.setInstrumentSettings(struct('exposureMilliseconds',120));
verifyEqual(t,char(colormeasuretest.control(fig,'UseInstrumentSettings').Enable),'off');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings')); % Guard also applies to a direct callback.
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',120));
colormeasuretest.click(colormeasuretest.control(fig,'ClearInstrumentOverrides')); % Conflict action reloads the committed values.
verifyEqual(t,colormeasuretest.control(fig,'SettingsNumber').Value,'120');
verifyEqual(t,char(colormeasuretest.control(fig,'UseInstrumentSettings').Enable),'on');
verifyEqual(t,calls('connect'),0);
end

function testUnknownReadbacksAreNotRequestsOrInventedDefaults(t)
[s,calls] = session(t);
calls('values') = struct('exposureMilliseconds',NaN,'syncMode','unrecognized-mode');
view = colormeasure.ui.SettingsView(s); t.addTeardown(@() colormeasuretest.dispose(view)); fig = view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
data = colormeasuretest.control(fig,'InstrumentSettingsTable').Data;
verifyEqual(t,data{1,2},'Unavailable');
verifyEqual(t,data{2,2},'Unknown (unrecognized-mode)');
verifyEqual(t,colormeasuretest.control(fig,'SettingsNumber').Value,'');
verifyEmpty(t,fieldnames(s.settingsOverrides));
end

function testFinishedBatchAllowsSettingsInspectionWithoutEdits(t)
[s,calls] = session(t); s.show(); s.measure(); s.finish();
colormeasuretest.click(colormeasuretest.control(s.window,'InstrumentSettingsButton')); fig = settingsFigure();
verifyEqual(t,char(colormeasuretest.control(fig,'UseInstrumentSettings').Enable),'off');
verifyEqual(t,char(colormeasuretest.control(fig,'ReadInstrumentSettings').Enable),'off');
select(fig,2); before=calls('connect');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings')); colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifyEqual(t,calls('connect'),before); verifyTrue(t,isgraphics(fig));
end

function testUnreadChoiceNeedsExplicitSelectionBeforeUse(t)
[s,calls]=session(t);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
verifyEqual(t,choice.Value,0);
verifyEqual(t,choice.Items{1},'Choose a value');
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
verifyTrue(t,check.Value);verifyEqual(t,choice.Value,0);
verifyEqual(t,char(choice.Enable),'on');
select(fig,1);select(fig,2);verifyEqual(t,choice.Value,0);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'Choose a value');
choice.Value=2;colormeasuretest.change(choice); % Off, whose actual request is 'none'.
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.syncMode,'none');
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testUnrecognizedReadbackStaysSeparateFromExplicitChoice(t)
[s,calls]=session(t);
calls('values')=struct('exposureMilliseconds',60,'syncMode','unrecognized-mode');
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
verifyEqual(t,choice.Value,0);
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');
verifyEqual(t,tab.Data{2,2},'Unknown (unrecognized-mode)');
verifyEqual(t,tab.Data{2,3},'Choose a value');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
choice.Value=1;colormeasuretest.change(choice);
verifyEqual(t,tab.Data{2,2},'Unknown (unrecognized-mode)');
verifyEqual(t,tab.Data{2,3},'Automatic');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.syncMode,'auto');
verifyEqual(t,s.settingsSnapshot.values.syncMode,'unrecognized-mode');
verifyEqual(t,calls('readSettings'),1);verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testMissingReadbackCannotAdoptLaterObservationAsDraft(t)
[s,calls]=session(t);calls('values')=struct('exposureMilliseconds',60);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
verifyEqual(t,choice.Value,0);
calls('values')=struct('exposureMilliseconds',60,'syncMode','none');
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifyEqual(t,choice.Value,0);verifyTrue(t,check.Value);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
% Removing the pending override restores the observation; enabling it now
% deliberately keeps that known value, not the first entry in the list.
check.Value=false;colormeasuretest.change(check);verifyEqual(t,choice.Value,2);
check.Value=true;colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.syncMode,'none');verifyEqual(t,calls('apply'),0);
end

function testDuplicateChoiceNamesPreserveReportedIdAndExplicitZero(t)
[s,calls]=session(t);catalog=controls();
catalog(2).choices=struct('value',{0,7,9},'label',{'Shared name','Shared name','Unique name'});
calls('controls')=catalog;calls('values')=struct('exposureMilliseconds',60,'syncMode',7);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
verifyEqual(t,choice.Items,{'Choose a value','Shared name (ID 0)','Shared name (ID 7)','Unique name'});
verifyEqual(t,choice.Value,2);
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');
verifyEqual(t,tab.Data{2,2},'Shared name (ID 7)');verifyEqual(t,tab.Data{2,3},'Shared name (ID 7)');
choice.Value=1;colormeasuretest.change(choice);verifyEqual(t,tab.Data{2,3},'Shared name (ID 0)');
select(fig,1);select(fig,2);verifyEqual(t,choice.Value,1);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.syncMode,0);verifyEqual(t,s.settingsSnapshot.values.syncMode,7);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));
select(view.Figure,2);verifyEqual(t,colormeasuretest.control(view.Figure,'SettingsChoice').Value,1);
verifyEqual(t,calls('connect'),1);verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testPendingChoiceCanBeCancelledClearedOrExplicitlyReset(t)
[s,calls]=session(t);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
select(fig,2);check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'CancelInstrumentSettings'));
verifyEmpty(t,fieldnames(s.settingsOverrides));
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
select(fig,2);check=colormeasuretest.control(fig,'SettingsOverride');verifyFalse(t,check.Value);
check.Value=true;colormeasuretest.change(check);choice=colormeasuretest.control(fig,'SettingsChoice');
choice.Value=2;colormeasuretest.change(choice);choice.Value=0;colormeasuretest.change(choice);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
colormeasuretest.click(colormeasuretest.control(fig,'ClearInstrumentOverrides'));
verifyFalse(t,check.Value);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyFalse(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('apply'),0);
end

function testCommittedStringChoiceSurvivesInspectionAndUse(t)
[s,calls]=session(t);s.setInstrumentSettings(struct('syncMode',"none"));
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
verifyEqual(t,choice.Value,2);
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');verifyEqual(t,tab.Data{2,3},'Off');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyFalse(t,isgraphics(fig));verifyEqual(t,s.settingsOverrides.syncMode,"none");
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('apply'),0);
end

function testStringReadbackMatchesTextChoiceWithoutCoercingNumericIds(t)
[s,calls]=session(t);calls('values')=struct('exposureMilliseconds',60,'syncMode',"none");
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
select(fig,2);choice=colormeasuretest.control(fig,'SettingsChoice');
verifyEqual(t,choice.Value,2);
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');verifyEqual(t,tab.Data{2,2},'Off');
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
verifyEqual(t,tab.Data{2,3},'Off');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.syncMode,'none');verifyEqual(t,s.settingsSnapshot.values.syncMode,"none");
s.setInstrumentSettings(struct());
catalog=controls();catalog(2).choices=struct('value',{0,7},'label',{'Zero','Seven'});
calls('controls')=catalog;calls('values')=struct('exposureMilliseconds',60,'syncMode',"7");
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
select(fig,2);verifyEqual(t,colormeasuretest.control(fig,'SettingsChoice').Value,0);
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');verifyEqual(t,tab.Data{2,2},'Unknown (7)');
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testFixedZeroCannotSilentlyBecomeAdaptive(t)
for model={'PR-655','PR-670'}
    [s,calls]=session(t);catalog=colormeasure.drivers.pr.settingsCatalog(model{1});calls('controls')=catalog;
    calls('values')=struct('exposureMilliseconds',0);
    view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
    colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
    check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
    mode=colormeasuretest.control(fig,'SettingsNumberMode');mode.Value=2;colormeasuretest.change(mode);
    number=colormeasuretest.control(fig,'SettingsNumber');number.Value='0';colormeasuretest.change(number);
    tab=colormeasuretest.control(fig,'InstrumentSettingsTable');verifyEqual(t,tab.Data{1,3},'Fixed: 0 ms');
    select(fig,2);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
    verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
    verifyEqual(t,mode.Value,2);verifyEqual(t,number.Value,'0');
    verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'Fixed requires at least');
    mode.Value=1;colormeasuretest.change(mode);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
    verifyFalse(t,isgraphics(fig));verifyEqual(t,s.settingsOverrides.exposureMilliseconds,0);
    verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end
end

function testAdaptiveAndFixedExposureNeverGuessUnreadValues(t)
[s,calls]=session(t);calls('controls')=colormeasure.drivers.pr.settingsCatalog('PR-655');
calls('values')=struct('exposureMilliseconds',NaN);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
mode=colormeasuretest.control(fig,'SettingsNumberMode');number=colormeasuretest.control(fig,'SettingsNumber');
verifyEqual(t,mode.Value,0);check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
mode.Value=1;colormeasuretest.change(mode);verifyEqual(t,string(number.Visible),"off");
mode.Value=2;colormeasuretest.change(mode);verifyEmpty(t,number.Value);
number.Value='0,5';colormeasuretest.change(number);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
assertTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyEqual(t,number.Value,'0,5');
verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'without commas');
number.Value='2';colormeasuretest.change(number);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifySubstring(t,colormeasuretest.control(fig,'SettingsAvailability').Text,'3 to 6000 ms');
number.Value='3';colormeasuretest.change(number);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides,struct('exposureMilliseconds',3));
verifyEqual(t,calls('readSettings'),1);verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testAdaptiveChoiceRetainsWireZeroAndDiscardKeepsOldOverride(t)
[s,calls]=session(t);calls('controls')=colormeasure.drivers.pr.settingsCatalog('PR-670',struct('sensitivityMode','extended'));
calls('values')=struct('exposureMilliseconds',0);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
mode=colormeasuretest.control(fig,'SettingsNumberMode');verifyEqual(t,mode.Value,1);
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.exposureMilliseconds,0);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
mode=colormeasuretest.control(fig,'SettingsNumberMode');mode.Value=2;colormeasuretest.change(mode);
number=colormeasuretest.control(fig,'SettingsNumber');number.Value='5';colormeasuretest.change(number);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));verifyTrue(t,isgraphics(fig));
verifySubstring(t,colormeasuretest.control(fig,'SettingsAvailability').Text,'6 to 30000 ms');
colormeasuretest.click(colormeasuretest.control(fig,'CancelInstrumentSettings'));
verifyEqual(t,s.settingsOverrides.exposureMilliseconds,0);verifyEqual(t,calls('apply'),0);
end

function testAutomaticNumberEditorUsesCatalogLabelsAndFractionalLimits(t)
[s,calls]=session(t);catalog=colormeasure.drivers.pr.settingsCatalog('PR-655');
catalog=catalog(1);catalog.maximum=120;catalog.id='virtualDurationSeconds';catalog.label='Duration (s)';
catalog.editor.automaticLabel='Automatic';catalog.editor.fixedLabel='Manual';
% The catalog's integer hint is optional; omitting it permits fractions.
catalog.editor=rmfield(catalog.editor,'integer');
catalog.editor.fixedMinimum=0.005;catalog.editor.unit='s';
calls('controls')=catalog;calls('values')=struct('virtualDurationSeconds',NaN);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
mode=colormeasuretest.control(fig,'SettingsNumberMode');
verifyEqual(t,mode.Items,{'Choose a mode','Automatic','Manual'});
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'Choose Automatic or Manual');
mode.Value=2;colormeasuretest.change(mode);number=colormeasuretest.control(fig,'SettingsNumber');
guidance=colormeasuretest.control(fig,'SettingsAvailability').Text;
verifySubstring(t,guidance,'Manual: 0.005 to 120 s');verifyFalse(t,contains(guidance,'whole numbers'));
verifyFalse(t,contains(lower(guidance),'exposure'));
number.Value='0';colormeasuretest.change(number);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'Choose Automatic');
number.Value='0.5';colormeasuretest.change(number);colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyFalse(t,isgraphics(fig));verifyEqual(t,s.settingsOverrides.virtualDurationSeconds,0.5);
verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function testPR670ExtendedDraftUpdatesTheFixedEditorCeiling(t)
[s,calls]=session(t);catalog=colormeasure.drivers.pr.settingsCatalog('PR-670',struct('sensitivityMode','standard'));
calls('controls')=catalog;calls('values')=struct('exposureMilliseconds',0,'sensitivityMode','standard');
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
verifySubstring(t,colormeasuretest.control(fig,'SettingsAvailability').Text,'6 to 6000 ms');
select(fig,find(strcmp({catalog.id},'sensitivityMode')));
check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
choice=colormeasuretest.control(fig,'SettingsChoice');choice.Value=2;colormeasuretest.change(choice);
select(fig,1);verifySubstring(t,colormeasuretest.control(fig,'SettingsAvailability').Text,'6 to 30000 ms');
check.Value=true;colormeasuretest.change(check);mode=colormeasuretest.control(fig,'SettingsNumberMode');mode.Value=2;colormeasuretest.change(mode);
number=colormeasuretest.control(fig,'SettingsNumber');number.Value='10000';colormeasuretest.change(number);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides,struct('sensitivityMode','extended','exposureMilliseconds',10000));
verifyEqual(t,calls('readSettings'),1);verifyEqual(t,calls('apply'),0);
end

function testCSIntervalFollowsDraftSpeedWithoutRelabelingObservedExposure(t)
[s,calls]=session(t);catalog=colormeasure.drivers.cs2000.settingsCatalog();
calls('controls')=catalog;calls('values')=struct('speedMode',3,'integrationTimeSeconds',0.1);
view=colormeasure.ui.SettingsView(s);t.addTeardown(@()colormeasuretest.dispose(view));fig=view.Figure;
colormeasuretest.click(colormeasuretest.control(fig,'ReadInstrumentSettings'));
ids={catalog.id};interval=find(strcmp(ids,'integrationTimeSeconds'));speed=find(strcmp(ids,'speedMode'));
select(fig,interval);html=colormeasuretest.control(fig,'SettingsExplanation').Data;
verifySubstring(t,html,'Multi averaging interval (s)');
tab=colormeasuretest.control(fig,'InstrumentSettingsTable');verifyEqual(t,tab.Data{interval,2},'0.1 (Manual)');
select(fig,speed);check=colormeasuretest.control(fig,'SettingsOverride');check.Value=true;colormeasuretest.change(check);
choice=colormeasuretest.control(fig,'SettingsChoice');choice.Value=4;colormeasuretest.change(choice); % wire mode 3, Manual
select(fig,interval);html=colormeasuretest.control(fig,'SettingsExplanation').Data;
verifySubstring(t,html,'Manual exposure (s)');check.Value=true;colormeasuretest.change(check);
number=colormeasuretest.control(fig,'SettingsNumber');number.Value='0,5';colormeasuretest.change(number);
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
assertTrue(t,isgraphics(fig));verifyEmpty(t,fieldnames(s.settingsOverrides));
verifyEqual(t,number.Value,'0,5');
verifySubstring(t,colormeasuretest.control(fig,'SettingsMessage').Text,'without commas');
number.Value='0.1';colormeasuretest.change(number);
verifyEqual(t,tab.Data{interval,2},'0.1 (Manual)');
colormeasuretest.click(colormeasuretest.control(fig,'UseInstrumentSettings'));
verifyEqual(t,s.settingsOverrides,struct('speedMode',3,'integrationTimeSeconds',0.1));
verifyEqual(t,calls('readSettings'),1);verifyEqual(t,calls('apply'),0);verifyEqual(t,calls('measure'),0);
end

function [s,calls] = session(t)
calls = containers.Map('KeyType','char','ValueType','any');
for name = {'connect','readSettings','apply','measure','release'}, calls(name{1}) = 0; end
calls('values') = struct('exposureMilliseconds',60,'syncMode','auto');
calls('readHook') = [];
catalog = controls();
calls('controls') = catalog;
a = struct('key','settings-ui-test','label','Virtual settings', ...
    'listPorts',@(~) ["VIRTUAL1";"VIRTUAL2"], ...
    'connect',@connect,'release',@release,'read',@measure, ...
    'toTable',@(rows,~) table(reshape([rows.XYZ],3,[])'));
a.settings = struct('catalog',catalog,'read',@readSettings,'apply',@apply);
s = colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services());
s.selectPort('VIRTUAL1'); t.addTeardown(@() disposeWithWindow(s));
    function instrument = connect(~)
        calls('connect') = calls('connect')+1; instrument = struct();
    end
    function release(~)
        calls('release') = calls('release')+1;
    end
    function report = readSettings(~)
        calls('readSettings') = calls('readSettings')+1;
        callback = calls('readHook'); if ~isempty(callback), callback(); end
        report = snapshot();
    end
    function receipt = apply(~,overrides)
        calls('apply') = calls('apply')+1;
        receipt = struct('requested',overrides,'before',snapshot(),'after',snapshot(), ...
            'commands',{{}},'acknowledgements',{{}},'status','applied', ...
            'error',struct('identifier','','message',''));
    end
    function reading = measure(~)
        calls('measure') = calls('measure')+1; reading = struct('XYZ',[1 2 3]);
    end
    function report = snapshot()
        report = struct('values',calls('values'), ...
            'controls',calls('controls'),'identity',struct('model','Virtual settings'), ...
            'readAtUTC','2026-09-17T12:00:00.000Z','responses',{{}});
    end
end

function c = controls()
help = struct('meaning','Exposure duration in milliseconds.', ...
    'whenToUse','Use a fixed duration for repeatable timing.', ...
    'tradeoff','A fixed duration may saturate a bright source.', ...
    'normal','Automatic exposure is restored when this override is cleared.', ...
    'source','Virtual test fixture');
c = struct('id','exposureMilliseconds','label','Exposure (ms)','type','number', ...
    'choices',struct('value',{},'label',{}),'minimum',0,'maximum',1000, ...
    'available',true,'help',help);
c(2) = c; c(2).id = 'syncMode'; c(2).label = 'Synchronization'; c(2).type = 'choice';
c(2).choices = struct('value',{'auto','none'},'label',{'Automatic','Off'});
c(2).minimum = NaN; c(2).maximum = NaN;
end

function stageNumber(fig,value)
select(fig,1);
check = colormeasuretest.control(fig,'SettingsOverride'); check.Value = true; colormeasuretest.change(check);
input = colormeasuretest.control(fig,'SettingsNumber'); input.Value = sprintf('%g',value); colormeasuretest.change(input);
end
function select(fig,row)
tab = colormeasuretest.control(fig,'InstrumentSettingsTable'); tab.CellSelectionCallback(tab,struct('Indices',[row 1]));
end
function fig = settingsFigure()
fig = findall(groot,'Tag','InstrumentSettingsWindow'); assert(isscalar(fig));
end
function closeFigure(fig)
if isgraphics(fig), close(fig); end
end
function disposeWithWindow(s)
if ~isvalid(s), return; end
fig=s.window; delete(s); if isgraphics(fig), delete(fig); end
end

function testSettingsCloseDoesNotRaiseAnOwnerInAnUnselectedTab(t)
[s,calls]=session(t);s.show();owner=colormeasuretest.control(s.window,'InstrumentSettingsButton');
view=colormeasure.ui.SettingsView(s,[],owner);t.addTeardown(@()colormeasuretest.dispose(view));
tab=ancestor(owner,'uitab');group=tab.Parent;other=uitab(group,'Title','Other workflow');
group.SelectedTab=other;
sentinel=figure('Visible','off');t.addTeardown(@()closeFigure(sentinel));set(groot,'CurrentFigure',sentinel);
fig=view.Figure;fig.CloseRequestFcn(fig,[]);
verifyFalse(t,isgraphics(fig));verifyEqual(t,group.SelectedTab,other);
verifyEqual(t,get(groot,'CurrentFigure'),sentinel);
verifyEqual(t,calls('connect'),0);verifyEqual(t,calls('readSettings'),0);verifyEqual(t,calls('apply'),0);
end

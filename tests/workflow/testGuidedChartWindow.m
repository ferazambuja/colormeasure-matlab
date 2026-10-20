function tests=testGuidedChartWindow
% Guided-chart presentation on the existing synthetic direct acquisition path.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);t.TestData.folder=folder.Folder;
visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@()set(groot,'DefaultFigureVisible',visible));
end
function testSetupCancelPreservesFreeSampleAndDestination(t)
s=session(t);s.setSample('Free name','Free note');s.show();before=s.destination;
colormeasuretest.click(field(s.window,'ChartButton'));dialog=field(groot,'GuidedChartSetup');
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
verifyFalse(t,isgraphics(dialog));verifyEmpty(t,s.chart);verifyEmpty(t,s.measurements);
verifyEqual(t,s.name,'Free name');verifyEqual(t,s.notes,'Free note');verifyEqual(t,s.destination,before);
verifyEqual(t,field(s.window,'ChartButton').String,'Chart / ColorChecker…');
end
function testSgUsesPrimaryWorkspaceAtMinimumSize(t)
s=session(t);s.show();colormeasuretest.click(field(s.window,'ChartButton'));dialog=field(groot,'GuidedChartSetup');
preset=field(dialog,'GuidedChartPreset');preset.Value='sg';preset.ValueChangedFcn(preset,[]);
colormeasuretest.click(field(dialog,'GuidedChartSetupStart'));
verifyFalse(t,isgraphics(dialog));verifyEmpty(t,s.measurements);verifyEqual(t,s.chart.total,140);
s.window.Position=[30 30 960 750];s.window.SizeChangedFcn(s.window,[]);
grid=field(s.window,'GuidedChartGrid');panel=field(s.window,'GuidedChartWorkspace');
verifySize(t,grid.Data,[10 14]);verifyEqual(t,char(panel.Visible),'on');
verifyLessThanOrEqual(t,sum(cell2mat(grid.ColumnWidth))+12,grid.Position(3));
verifyGreaterThan(t,panel.Position(4),350);
verifyEqual(t,char(field(s.window,'ReadingPlotSurface').Visible),'off');
verifyEqual(t,field(s.window,'SampleName').String,'A1');verifyEqual(t,field(s.window,'SampleName').Enable,'off');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'A1');
verifyEqual(t,field(s.window,'ChartButton').String,'Samples');
verifyEmpty(t,findobj(s.window,'Tag','TaskSelector'));
verifySubstring(t,field(s.window,'GuidedChartNotice').Text,'✓ Measured');
verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'off');
verifyEqual(t,grid.FontUnits,'pixels');verifyGreaterThanOrEqual(t,grid.Position(4),350);
end
function testPresetsShowActualDimensionsAndKeepCustomDraft(t)
s=session(t);s.show();colormeasuretest.click(field(s.window,'ChartButton'));dialog=field(groot,'GuidedChartSetup');
preset=field(dialog,'GuidedChartPreset');
verifyEqual(t,field(dialog,'GuidedChartRows').Value,'4');verifyEqual(t,field(dialog,'GuidedChartColumns').Value,'6');
preset.Value='sg';preset.ValueChangedFcn(preset,[]);
verifyEqual(t,field(dialog,'GuidedChartRows').Value,'10');verifyEqual(t,field(dialog,'GuidedChartColumns').Value,'14');
verifyEqual(t,field(dialog,'GuidedChartName').Value,colormeasure.chart.definition('sg').name);
preset.Value='custom';preset.ValueChangedFcn(preset,[]);
name=field(dialog,'GuidedChartName');row=field(dialog,'GuidedChartRows');column=field(dialog,'GuidedChartColumns');
name.Value='My grid';row.Value='7';column.Value='8';
preset.Value='classic';preset.ValueChangedFcn(preset,[]);preset.Value='custom';preset.ValueChangedFcn(preset,[]);
verifyEqual(t,field(dialog,'GuidedChartName').Value,'My grid');verifyEqual(t,field(dialog,'GuidedChartRows').Value,'7');
verifyEqual(t,field(dialog,'GuidedChartColumns').Value,'8');verifyEmpty(t,s.chart);
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
end
function testStartChartOnOpenWindowUsesOnePrimaryLayoutTransition(t)
s=session(t);s.show();verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'on');
s.startChart(colormeasure.chart.definition('sg'));
s.window.Position=[30 30 960 750];s.window.SizeChangedFcn(s.window,[]);
verifyEqual(t,char(field(s.window,'GuidedChartWorkspace').Visible),'on');
verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'off');
verifyGreaterThanOrEqual(t,field(s.window,'GuidedChartGrid').Position(4),350);
colormeasuretest.click(field(s.window,'ToggleReadingsButton'));verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'on');
s.setSample(s.name,'Retained chart notes');verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'on');
s.startChart(colormeasure.chart.definition('classic'));verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'off');
verifyEmpty(t,s.measurements);
end
function testCustomInvalidDimensionsRetainDraftAndNoChart(t)
s=session(t);s.show();colormeasuretest.click(field(s.window,'ChartButton'));dialog=field(groot,'GuidedChartSetup');
preset=field(dialog,'GuidedChartPreset');preset.Value='custom';preset.ValueChangedFcn(preset,[]);
row=field(dialog,'GuidedChartRows');column=field(dialog,'GuidedChartColumns');
for pair={'0,5','2';'11','14';'0','1';'Inf','1'}.'
    row.Value=pair{1};column.Value=pair{2};colormeasuretest.click(field(dialog,'GuidedChartSetupStart'));
    verifyEmpty(t,s.chart);verifyEqual(t,row.Value,pair{1});verifyNotEmpty(t,field(dialog,'GuidedChartSetupError').Text);
end
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
end
function testExtremeGridHasScrollableReadableColumns(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Wide',1,140));s.show();
s.window.Position=[30 30 960 750];s.window.SizeChangedFcn(s.window,[]);
grid=field(s.window,'GuidedChartGrid');verifySize(t,grid.Data,[1 140]);
verifyGreaterThan(t,sum(cell2mat(grid.ColumnWidth)),grid.Position(3));
verifyGreaterThanOrEqual(t,min(cell2mat(grid.ColumnWidth)),44);
verifySubstring(t,grid.Data{1,27},'AA1');
colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));
verifySize(t,grid.Data,[140 1]);verifyEqual(t,s.chart.currentCell,[1 1]);
verifyEqual(t,s.chart.orientation,90);
end
function testArrowInspectionPreservesTargetReadingsAndSavedMat(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,3));s.measure();s.show();
before=s.chart;readings=s.measurements;saved=colormeasuretest.readBytes(s.files.mat);
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 3]));
verifyEqual(t,s.chart,before);verifyEqual(t,s.measurements,readings);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);verifyEqual(t,grid.Selection,[1 3]);
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting C1');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure B1');
verifySubstring(t,grid.Tooltip,'Space or Enter');
end
function testKeyboardActivationUsesInspectedCellWithoutAcquisition(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,3));s.show();
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[2 3]));
key=grid.KeyPressFcn;key(grid,struct('Key','return','Modifier',{{}}));
verifyEqual(t,s.chart.currentCell,[2 3]);verifyEqual(t,s.name,'C2');verifyEmpty(t,s.measurements);
grid.CellSelectionCallback(grid,struct('Indices',[1 2]));key(grid,struct('Key','space','Modifier',{{}}));
verifyEqual(t,s.chart.currentCell,[1 2]);verifyEqual(t,s.name,'B1');verifyEmpty(t,s.measurements);
end
function testModifiedAndUnrelatedGridKeysDoNotActivate(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,3));s.show();
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 3]));
before=s.chart;saved=colormeasuretest.readBytes(s.files.mat);key=grid.KeyPressFcn;
key(grid,struct('Key','return','Modifier',{{'control'}}));
key(grid,struct('Key','space','Modifier',{{'shift'}}));
key(grid,struct('Key','rightarrow','Modifier',{{}}));
verifyEqual(t,s.chart,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);verifyEmpty(t,s.measurements);
end
function testClickActivatesAlreadyInspectedCellAndIgnoresBlankArea(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,3));s.show();
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 3]));
clickGrid(grid,[1 3]);verifyEqual(t,s.chart.currentCell,[1 3]);verifyEmpty(t,s.measurements);
before=s.chart;clickGrid(grid,[]);verifyEqual(t,s.chart,before);
end
function testClickAndKeyboardOnActivePatchPreserveSavedChartAndFreeDraft(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,3));s.show();
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 1]));
for paused=[false true]
    if paused,s.pauseChart();s.setSample('Free draft','free notes');end
    before=s.chart;files=s.files;name=s.name;notes=s.notes;revision=s.sampleRevision;
    saved=colormeasuretest.readBytes(s.files.mat);
    clickGrid(grid,[1 1]);clickGrid(grid,[1 1]);
    for key={'return','space'},grid.KeyPressFcn(grid,struct('Key',key{1},'Modifier',{{}}));end
    verifyEqual(t,s.chart,before);verifyEqual(t,s.files,files);verifyEqual(t,s.sampleRevision,revision);
    verifyEqual(t,s.name,name);verifyEqual(t,s.notes,notes);
    verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);verifyEmpty(t,s.measurements);
end
end
function testBusyChartAllowsInspectionButRefusesActivation(t)
a=colormeasure.drivers.cr.demoAdapter('CR250','interactive');read=a.read;a.read=@duringRead;
io=colormeasure.ui.services();io.createView=@(s)colormeasure.ui.Window(s,@(~,~)true);
s=colormeasure.session.Session(a,t.TestData.folder,io);t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(colormeasure.chart.definition('custom','Small',1,3));s.show();s.measure();
verifyEqual(t,s.chart.currentCell,[1 2]);verifyEqual(t,s.measurements.name,'A1');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting C1');
    function reading=duringRead(instrument)
        verifyTrue(t,s.busy);before=s.chart;saved=colormeasuretest.readBytes(s.files.mat);
        verifyFalse(t,s.chart.unsaved);verifyEqual(t,s.activity,'Measuring');
        retained=colormeasure.chart.continuationSource(s.files.mat);
        verifyNotEmpty(t,retained.blockedReason); % Committed intent still blocks reuse during capture.
        verifyFalse(t,s.saving);
        grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 3]));
        verifyFalse(t,any(contains(grid.Data,'*'),'all'));
        verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Measurement in progress');
        verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'measurement in progress');
        verifyFalse(t,contains(field(s.window,'GuidedChartProgress').Text,'saving chart progress'));
        grid.KeyPressFcn(grid,struct('Key','space','Modifier',{{}}));clickGrid(grid,[1 3]);
        verifyEqual(t,s.chart,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);
        reading=read(instrument);
    end
end
function testRotationMapsNativeSelectionToImmutableCell(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Rotation',2,3));s.show();
colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));
grid=field(s.window,'GuidedChartGrid');clickGrid(grid,[1 1]);
verifyEqual(t,s.chart.currentCell,[2 1]);verifyEqual(t,s.name,'A2');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure A2');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'A2');
verifyEmpty(t,s.measurements);
end
function testMeasureAdvancesAndRereadPreservesHistory(t)
io=colormeasure.ui.services();io.createView=@(s)colormeasure.ui.Window(s,@(~,~)true);
[s,events]=colormeasuretest.continuationBatch(t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();
colormeasuretest.click(field(s.window,'MeasureButton'));
verifyEqual(t,s.chart.coverage,1);verifyEqual(t,s.chart.currentCell,[1 2]);verifyEqual(t,s.measurements(1).name,'A1');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure B1');
grid=field(s.window,'GuidedChartGrid');
verifyEqual(t,grid.Selection,[1 1]);
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting A1');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Active patch B1');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'reading #1');
verifyFalse(t,contains(grid.Data{1,1},'*'));verifySubstring(t,grid.Data{1,2},'*');
clickGrid(grid,[1 1]);
colormeasuretest.click(field(s.window,'MeasureButton'));
verifyNumElements(t,s.measurements,2);verifyEqual(t,s.chart.coverage,1);
verifyEqual(t,s.chart.cells(1).attemptCount,2);verifyEqual(t,s.chart.cells(1).readingIndex,2);
verifySubstring(t,grid.Data{1,1},'✓');
% A failed retake reports its latest outcome while retaining the selected
% successful reading, its numeric data and measured coverage.
before=s.measurements;clickGrid(grid,[1 1]);events('duringRead')=@failRead;
colormeasuretest.click(field(s.window,'MeasureButton'));
verifyEqual(t,s.measurements,before);verifyEqual(t,s.chart.coverage,1);
verifyEqual(t,s.chart.currentCell,[1 1]);verifyEqual(t,s.chart.cells(1).attemptCount,3);
verifyEqual(t,s.chart.cells(1).status,'measured');verifyEqual(t,s.chart.cells(1).readingIndex,2);
verifyEqual(t,s.chart.cells(1).latestAttemptStatus,'failed');
verifySubstring(t,grid.Data{1,1},'✓!');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Retry issue.');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'Controlled retake failure');
events('duringRead')=@()[];colormeasuretest.click(field(s.window,'MeasureButton'));
verifyNumElements(t,s.measurements,3);verifyEqual(t,s.chart.coverage,1);
verifyEqual(t,s.chart.cells(1).readingIndex,3);verifyEqual(t,s.chart.cells(1).latestAttemptStatus,'completed');
verifyFalse(t,contains(grid.Data{1,1},'!'));
verifyFalse(t,contains(field(s.window,'GuidedChartPatchDetail').Text,'Retry issue.'));
    function failRead(),error('Fixture:Read','Controlled retake failure.');end
end
function testFigureKeyReleaseRearmsExistingMeasureShortcut(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,3));s.show();
grid=field(s.window,'GuidedChartGrid');fig=s.window;fig.Visible='on';[~,modifiers]=colormeasure.ui.measureShortcut();
event=struct('Key','m','Modifier',{modifiers});press=fig.WindowKeyPressFcn;release=fig.WindowKeyReleaseFcn;
press(fig,struct('Key','m','Modifier',{{'command';'shift'}}));verifyEmpty(t,s.measurements);
press(fig,event);press(fig,event);verifyNumElements(t,s.measurements,1);
release(fig,struct('Key','right'));press(fig,event);verifyNumElements(t,s.measurements,1);
release(fig,event);press(fig,event);verifyEqual(t,{s.measurements.name},{'A1','B1'});
verifyEqual(t,s.chart.currentCell,[1 3]);verifyEqual(t,grid.Selection,[1 1]);
delete(s);verifyWarningFree(t,@()release(fig,event));
end
function testChartButtonRestoresSampleDraftAndResumesWithoutMeasuring(t)
s=session(t);s.setSample('Free','note');s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();
verifyEqual(t,field(s.window,'ChartButton').String,'Samples');
% A custom grid has no chart color: no swatch, and the tooltip says why.
verifyEqual(t,char(field(s.window,'GuidedChartReferencePreview').Visible),'off');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'Chart color unavailable');
colormeasuretest.click(field(s.window,'ChartButton'));
verifyTrue(t,s.chart.paused);verifyEqual(t,s.name,'Free');verifyEqual(t,s.notes,'note');
verifyFalse(t,contains(field(s.window,'MeasureButton').String,'Measure A1'));
verifyEqual(t,field(s.window,'ChartButton').String,'Resume chart');verifyEqual(t,field(s.window,'SampleName').Enable,'on');
colormeasuretest.click(field(s.window,'ChartButton'));verifyFalse(t,s.chart.paused);verifyEqual(t,s.name,'A1');
verifyEmpty(t,s.measurements);verifyEqual(t,field(s.window,'ChartButton').String,'Samples');
end
function testPausedChangedSettingsNamesReviewAndBlocksResume(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Paused',1,2));s.measure();s.pauseChart();s.show();
s.setInstrumentSettings(struct('speed',2));
verifyNotEmpty(t,s.chart.pendingContext);before=s.chart;readings=s.measurements;
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Review changed settings');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'another chart reading');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Measure takes free samples');
verifyEqual(t,field(s.window,'MeasureButton').Enable,'on');
verifyEqual(t,char(field(s.window,'GuidedChartPause').Enable),'off');
verifyEqual(t,char(field(s.window,'GuidedChartReviewContext').Enable),'on');
verifyEqual(t,field(s.window,'ChartButton').Enable,'off');
colormeasuretest.click(field(s.window,'ChartButton'));verifyEqual(t,s.chart,before);verifyEqual(t,s.measurements,readings);
verifyEqual(t,field(s.window,'ChartButton').String,'Resume chart');
s.acceptChartContext();verifyEqual(t,char(field(s.window,'GuidedChartPause').Enable),'on');
colormeasuretest.click(field(s.window,'ChartButton'));verifyFalse(t,s.chart.paused);verifyEqual(t,s.chart.activePass,2);
verifyEqual(t,s.measurements,readings);
end
function testRotationKeepsVisibleInspectionAndImmutableActiveCell(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,3));s.show();
grid=field(s.window,'GuidedChartGrid');clickGrid(grid,[1 2]);
colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));
verifyEqual(t,s.chart.currentCell,[1 2]);verifyEqual(t,grid.Selection,[1 2]);
verifySubstring(t,grid.Data{1,2},'A1');verifySubstring(t,grid.Data{2,2},'B1');verifySubstring(t,grid.Data{2,2},'*');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting A1');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure B1');
verifyEmpty(t,s.measurements);
end
function testRotationRecreatesCursorWhenOldPositionIsOutsideNewGrid(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,3));s.show();
grid=field(s.window,'GuidedChartGrid');clickGrid(grid,[2 3]);
colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));replacement=field(s.window,'GuidedChartGrid');
verifyFalse(t,isgraphics(grid));verifyEqual(t,replacement.Selection,[1 1]);
verifyEqual(t,s.chart.currentCell,[2 3]);verifySubstring(t,replacement.Data{1,1},'A2');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure C2');verifyEmpty(t,s.measurements);
end
function testRotationWithoutNativeSelectionKeepsActiveTarget(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,3));s.show();
grid=field(s.window,'GuidedChartGrid');clickGrid(grid,[1 2]);grid.Selection=[];
grid.CellSelectionCallback(grid,struct('Indices',[]));
colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));replacement=field(s.window,'GuidedChartGrid');
verifyFalse(t,isgraphics(grid));verifyEqual(t,replacement.Selection,[1 1]);
verifyEqual(t,s.chart.currentCell,[1 2]);verifySubstring(t,replacement.Data{1,1},'A2');
verifySubstring(t,field(s.window,'MeasureButton').String,'Measure B1');verifyEmpty(t,s.measurements);
end
function testPausedAndFinishedInspectionDoesNotAdvertiseChartAcquisition(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();
colormeasuretest.click(field(s.window,'GuidedChartPause'));grid=field(s.window,'GuidedChartGrid');
grid.CellSelectionCallback(grid,struct('Indices',[1 2]));
grid.KeyPressFcn(grid,struct('Key','return','Modifier',{{}}));clickGrid(grid,[1 2]);
verifyEqual(t,s.chart.currentCell,[1 1]);verifyFalse(t,any(contains(grid.Data,'*'),'all'));
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Paused chart patch A1');
verifySubstring(t,grid.Tooltip,'Measure takes free samples');
verifyFalse(t,contains(field(s.window,'MeasureButton').String,'Measure A1'));
s.finish(AllowIncompleteChart=true);
verifyTrue(t,s.finished);verifyFalse(t,any(contains(grid.Data,'*'),'all'));
verifySubstring(t,grid.Tooltip,'Acquisition is closed');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Retained chart patch A1');
verifyEmpty(t,s.measurements);
end
function testEmptyChartEditSaveFailureOffersRetryWithoutAcquisition(t)
fail=true;io=colormeasure.ui.services();io.saveMat=@save;s=session(t,io);
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();
verifyEmpty(t,s.measurements);verifyTrue(t,s.chart.unsaved);
verifyEqual(t,field(s.window,'RetrySaveButton').Enable,'on');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Use Retry save before continuing.');
fail=false;colormeasuretest.click(field(s.window,'RetrySaveButton'));
verifyFalse(t,s.chart.unsaved);verifyEmpty(t,s.measurements);
fail=true;colormeasuretest.click(field(s.window,'GuidedChartRotateRight'));
verifyTrue(t,s.chart.unsaved);verifyEqual(t,field(s.window,'RetrySaveButton').Enable,'on');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Use Retry save before continuing.');
fail=false;colormeasuretest.click(field(s.window,'RetrySaveButton'));
verifyFalse(t,s.chart.unsaved);verifyEqual(t,s.chart.orientation,90);verifyEmpty(t,s.measurements);
    function save(varargin)
        if fail,error('ChartTest:Save','Synthetic chart edit save failure');end
        colormeasure.session.saveMat(varargin{:});
    end
end
function testContextReviewAndPriorPassInspectionRetainActiveAssociation(t)
decisions=0;io=colormeasure.ui.services();io.confirmChartContext=@confirm;s=session(t,io);
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.measure();s.show();
s.setInstrumentSettings(struct('speed',2));verifyNotEmpty(t,s.chart.pendingContext);
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Review changed settings before another chart reading.');
retained=s.measurements;review=field(s.window,'GuidedChartReviewContext');
assertEqual(t,char(review.Enable),'on');
verifyFalse(t,any(contains(field(s.window,'GuidedChartGrid').Data,'*'),'all'));
colormeasuretest.click(review);
assertEqual(t,decisions,1);assertEqual(t,s.chart.activePass,2);verifyEqual(t,s.chart.coverage,0);
verifyEqual(t,s.measurements,retained);
verifyNumElements(t,s.chart.passes(1).attempts,1);verifyEqual(t,s.chart.passes(1).coverage,1);
before=s.chart;chooser=field(s.window,'GuidedChartPass');chooser.Value=1;chooser.ValueChangedFcn(chooser,[]);
grid=field(s.window,'GuidedChartGrid');verifySubstring(t,grid.Data{1,1},'✓');
grid.CellSelectionCallback(grid,struct('Indices',[1 2]));
grid.KeyPressFcn(grid,struct('Key','space','Modifier',{{}}));clickGrid(grid,[1 2]);
verifyEqual(t,s.chart,before);verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting B1');
verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'read only');
verifySubstring(t,grid.Tooltip,'Earlier pass: inspection only');verifyFalse(t,any(contains(grid.Data,'*'),'all'));
verifyEqual(t,char(field(s.window,'GuidedChartRotateRight').Enable),'off');
chooser.Value=2;chooser.ValueChangedFcn(chooser,[]);
verifyFalse(t,contains(grid.Data{1,1},'✓'));verifyEqual(t,s.chart,before);
    function accepted=confirm(~,~),decisions=decisions+1;accepted=true;end
end
function testSelectedAnnotationAppearsBesideFixedCoordinate(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',2,2));s.selectChartCell(2,2);s.measure();s.show();
verifyTrue(t,s.editReading(1,'Foo','annotation'));
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[2 2]));
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'B2');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'Name: Foo');
verifyEqual(t,s.chart.passes.attempts.name,'B2');verifyEqual(t,s.chart.cells(4).readingIndex,1);
end
function testSaveFailureAllowsInspectionWithoutRetargeting(t)
fail=false;io=colormeasure.ui.services();io.saveMat=@save; s=session(t,io);
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();fail=true;
colormeasuretest.click(field(s.window,'MeasureButton'));
verifyTrue(t,s.chart.unsaved);before=s.chart.currentCell;
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 1]));
saved=colormeasuretest.readBytes(s.files.mat);chart=s.chart;
grid.KeyPressFcn(grid,struct('Key','return','Modifier',{{}}));clickGrid(grid,[1 1]);
verifyEqual(t,s.chart,chart);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);
verifyEqual(t,s.chart.currentCell,before);verifyEqual(t,field(s.window,'MeasureButton').Enable,'off');
verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'NOT SAVED');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Use Retry save before continuing.');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Inspecting A1');
verifySubstring(t,grid.Tooltip,'Use Retry save before continuing');
fail=false;colormeasuretest.click(field(s.window,'RetrySaveButton'));
verifyFalse(t,s.chart.unsaved);verifyNumElements(t,s.measurements,1);
    function save(varargin)
        if fail&&~isempty(varargin{1}),error('ChartTest:Save','Synthetic save failure');end
        colormeasure.session.saveMat(varargin{:});
    end
end
function testCompleteActivePassFinishesWithoutAnEarlierPassPrompt(t)
decisions=0;io=colormeasure.ui.services();io.confirmChartFinish=@confirm;s=session(t,io);
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.measure();
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();s.measure();s.show();
verifyEqual(t,s.chart.coverage,2);verifyEqual(t,s.chart.passes(1).coverage,1);
colormeasuretest.click(field(s.window,'FinishButton'));verifyTrue(t,s.finished);verifyEqual(t,decisions,0);
verifyEqual(t,s.chart.passes(1).coverage,1);verifyEqual(t,s.chart.coverage,2);
    function result=confirm(~),decisions=decisions+1;result=false;end
end
function testPlotsAndOtherTabsPreserveChartAssociation(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();before=s.chart;
chooser=field(s.window,'ChartWorkspaceSelector');chooser.Value=2;chooser.Callback(chooser,[]);
verifyEqual(t,char(field(s.window,'GuidedChartWorkspace').Visible),'off');verifyEqual(t,char(field(s.window,'ReadingPlotSurface').Visible),'on');
sidebar=field(s.window,'MeasurementSidebar');sidebar.SelectedTab=field(s.window,'ReadingTab');sidebar.SelectionChangedFcn(sidebar,[]);
verifyEqual(t,char(chooser.Visible),'off');verifyEqual(t,s.chart,before);verifyEmpty(t,s.measurements);
end
function testIncompleteFinishHasOneDecisionAndKeepsReview(t)
decisions=0;accept=false;io=colormeasure.ui.services();io.confirmChartFinish=@confirm;s=session(t,io);
s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.show();
colormeasuretest.click(field(s.window,'FinishButton'));verifyFalse(t,s.finished);verifyEqual(t,decisions,1);
accept=true;colormeasuretest.click(field(s.window,'FinishButton'));verifyTrue(t,s.finished,s.log(end).message);verifyEqual(t,decisions,2);
verifyEqual(t,s.chart.coverage,0);verifyEqual(t,char(field(s.window,'GuidedChartWorkspace').Visible),'on');
verifyEqual(t,char(field(s.window,'GuidedChartPause').Enable),'off');
    function result=confirm(~),decisions=decisions+1;result=accept;end
end
function testClassicDiagramSeparatesChartColorFromMeasurementProgress(t)
s=session(t);s.startChart(colormeasure.chart.definition('classic'));s.show();
grid=field(s.window,'GuidedChartGrid');verifySize(t,grid.Data,[4 6]);
verifyEqual(t,height(grid.StyleConfigurations),24);
verifyEmpty(t,grid.ColumnName);verifyEmpty(t,grid.RowName);
reference=field(s.window,'GuidedChartReferencePreview');
verifyEmpty(t,findobj(s.window,'Tag','GuidedChartMeasuredPreview'));
verifyEmpty(t,findobj(s.window,'Tag','GuidedChartPositionStatus'));
verifyEqual(t,reference.Units,'pixels');
verifyGreaterThanOrEqual(t,reference.Position(1),0);
verifyLessThanOrEqual(t,reference.Position(1)+reference.Position(3),grid.Position(3));
verifyTrue(t,reference.UserData.available);
verifySubstring(t,grid.Data{1,1},'○');
s.measure();
verifySubstring(t,grid.Data{1,1},'✓');
verifyGreaterThan(t,s.chart.cells(1).selectedAttempt,0);
styles=grid.StyleConfigurations;
index=find(arrayfun(@(n)strcmp(string(styles.Target(n)),'cell')&& ...
    isequal(styles.TargetIndex{n},[1 1]),1:height(styles)));
assertNumElements(t,index,1);
style=styles.Style(index);if iscell(style),style=style{1};end
verifyFalse(t,contains(grid.Data{1,1},'—'));
verifyEqual(t,style.BackgroundColor,[.12 .12 .12]);
verifyEqual(t,char(reference.Visible),'on');
verifyFalse(t,isequal(style.BackgroundColor,.55*reference.UserData.rgb+.45*[.18 .18 .18]));
verifyEqual(t,reference.Title,'Chart color');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'Open Data');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'physical chart edition and specimen conditions unverified');
verifyFalse(t,contains(field(s.window,'GuidedChartPatchDetail').Text,'unavailable'));
verifyEqual(t,field(s.window,'GuidedChartNotice').Text, ...
    '○ To measure   ✓ Measured   * Next patch   ! Check reading');
verifyNumElements(t,splitlines(field(s.window,'GuidedChartPatchDetail').Text),2);
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'then Measure');
verifyEqual(t,reference.BackgroundColor,reference.UserData.rgb);
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'CIE1931_2deg');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'D50');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'perfect-diffuser Y=100');
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Tooltip,'gamut');
end

function testHostAcquisitionBlockSuppressesActiveAndRefusesActivation(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Blocked',1,3));
fig=figure('Visible','off');t.addTeardown(@()colormeasuretest.dispose(fig));
view=colormeasure.ui.ChartView(fig,s,@()'Instrument connection cleanup is unresolved.');
t.addTeardown(@()colormeasuretest.dispose(view));view.update(s.chart);view.layout([0 0 640 480]);
grid=view.Grid;before=s.chart;saved=colormeasuretest.readBytes(s.files.mat);
verifyFalse(t,any(contains(grid.Data,'*'),'all'));
verifySubstring(t,field(fig,'GuidedChartActivePatch').Text,'Blocked chart target');
grid.CellSelectionCallback(grid,struct('Indices',[1 3]));clickGrid(grid,[1 3]);
grid.KeyPressFcn(grid,struct('Key','space','Modifier',{{}}));
verifyEqual(t,s.chart,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);
verifyEmpty(t,s.measurements);verifySubstring(t,grid.Tooltip,'Instrument connection cleanup');
end

function testAcquisitionSetupBlockAllowsPauseWithoutRetargeting(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Blocked setup',1,3));
fig=figure('Visible','off');t.addTeardown(@()colormeasuretest.dispose(fig));
view=colormeasure.ui.ChartView(fig,s,@()'', ...
    @()'Review changed settings in Chart before another reading.');
t.addTeardown(@()colormeasuretest.dispose(view));view.update(s.chart);view.layout([0 0 640 480]);
grid=view.Grid;before=s.chart;saved=colormeasuretest.readBytes(s.files.mat);
verifyFalse(t,any(contains(grid.Data,'*'),'all'));
verifyEqual(t,char(field(fig,'GuidedChartPause').Enable),'on');
verifySubstring(t,grid.Tooltip,'Review changed settings in Chart');
grid.CellSelectionCallback(grid,struct('Indices',[1 3]));clickGrid(grid,[1 3]);
grid.KeyPressFcn(grid,struct('Key','space','Modifier',{{}}));
verifyEqual(t,s.chart,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),saved);
colormeasuretest.click(field(fig,'GuidedChartPause'));
verifyTrue(t,s.chart.paused);verifyEqual(t,s.chart.currentCell,before.currentCell);
verifyEmpty(t,s.measurements);
end

function testOrdinarySavingAndFinishedStatesUseDistinctChartWording(t)
savingText='';retainedSave=false;io=colormeasure.ui.services();io.saveMat=@save;
s=session(t,io);s.show();s.startChart(colormeasure.chart.definition('custom','Saving',1,2));
verifySubstring(t,savingText,'Saving chart progress');verifyFalse(t,contains(savingText,'Retry save'));
s.finish(AllowIncompleteChart=true);verifyTrue(t,s.finished);
verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Batch closed');
verifySubstring(t,field(s.window,'GuidedChartActivePatch').Text,'Retained chart patch');
destination=fullfile(t.TestData.folder,'finished-relocation');mkdir(destination);
before=s.measurements;s.saveElsewhere(destination);
verifyTrue(t,retainedSave);verifyEqual(t,s.measurements,before);verifyTrue(t,s.finished);
verifyEmpty(t,s.saveError);verifyTrue(t,isfile(s.files.mat));
    function save(varargin)
        if isgraphics(s.window)
            verifyEqual(t,s.activity,'Saving MAT');
            verifyTrue(t,s.saving);
            if s.finished
                retainedSave=true;
                verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'saving retained output');
                verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Saving retained output');
                verifyFalse(t,contains(field(s.window,'GuidedChartProgress').Text,'saving chart progress'));
            else
                verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'saving chart progress');
            end
            savingText=field(s.window,'GuidedChartPatchDetail').Text;
        end
        colormeasure.session.saveMat(varargin{:});
    end
end
function s=session(t,io)
if nargin<2,io=colormeasure.ui.services();end
io.createView=@(s)colormeasure.ui.Window(s,@(~,~)true);
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
end
function control=field(parent,tag)
if isequal(parent,groot),control=findall(parent,'Tag',tag);else,control=colormeasuretest.field(parent,tag);end
end
function clickGrid(grid,rc)
row=[];column=[];if ~isempty(rc),row=rc(1);column=rc(2);end
grid.ClickedFcn(grid,struct('InteractionInformation',struct('Row',row,'Column',column)));
end

function testFinishedAuthoritativeRecoveryBlocksReplacementUntilRetry(t)
previous=getappdata(groot,'ColorMeasureSessions');
if isappdata(groot,'ColorMeasureSessions'),rmappdata(groot,'ColorMeasureSessions');end
t.addTeardown(@()restoreRegistry(previous));
for kind={'mat','csv'}
    [s,counts,setFailure]=saveRecoverySession(t);s.show();s.measure();s.finish();
    before=s.measurements;setFailure(kind{1});parent=fullfile(t.TestData.folder,kind{1});mkdir(parent);
    s.saveElsewhere(parent);fig=s.window;
    verifyTrue(t,s.finished);verifyTrue(t,s.needsRecovery);
    attention='Save needs attention';if strcmp(kind{1},'csv'),attention='CSV export needs attention';end
    verifySubstring(t,field(fig,'CurrentStatus').String,'Finished');
    verifySubstring(t,field(fig,'CurrentStatus').String,attention);
    verifySubstring(t,field(fig,'CurrentStatus').TooltipString,attention);
    verifyEqual(t,char(field(fig,'RecoveryMessage').Visible),'on');
    verifyEqual(t,char(field(fig,'RetrySaveButton').Visible),'on');
    verifyEqual(t,char(field(fig,'SaveElsewhereButton').Visible),'on');
    verifyEqual(t,field(fig,'RetrySaveButton').Enable,'on');
    verifyEqual(t,field(fig,'SaveElsewhereButton').Enable,'on');
    verifyEqual(t,field(fig,'NewBatchButton').Enable,'off');
    verifyEqual(t,field(fig,'MeasureButton').Enable,'off');
    verifySubstring(t,field(fig,'NewBatchButton').TooltipString,'Save needs attention');
    if strcmp(kind{1},'mat'),prefix='MAT save failed.';else,prefix='CSV export failed. MAT saved.';end
    verifySubstring(t,field(fig,'RecoveryMessage').String,prefix);
    colormeasure.session.sessionRegistry('put',s.adapterKey,s,s.destination);
    io=colormeasure.ui.services();io.chooseFolder=@(~)error('Test:UnexpectedFolder','Recovery must precede choosing another batch folder.');
    adapter=colormeasure.drivers.cr.demoAdapter('CR250','interactive');
    verifyError(t,@()colormeasure.ui.launchSession(adapter,io,t.TestData.folder,true),'Measurement:SaveRecovery');
    registry=colormeasure.session.sessionRegistry('get');index=strcmp(registry.keys,s.adapterKey);
    assertEqual(t,nnz(index),1);
    verifyEqual(t,registry.sessions{index},s);verifyEqual(t,s.measurements,before);
    calls=counts();setFailure('');colormeasuretest.click(field(fig,'RetrySaveButton'));
    after=counts();verifyEqual(t,after.reads,calls.reads);verifyEqual(t,s.measurements,before);
    verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);
    verifyEqual(t,field(fig,'MeasureButton').Enable,'off');
    verifyEqual(t,field(fig,'NewBatchButton').Enable,'on');
    saved=load(s.files.mat);verifyEqual(t,saved.measurements,before);
end
end
function testFinishedChartCsvOnlyRetryPreservesMatAndEnablesNewBatch(t)
[s,counts,setFailure]=saveRecoverySession(t);s.startChart(colormeasure.chart.definition('custom','Two patches',1,2));
s.measure();s.show();lastGood=colormeasuretest.readBytes(s.files.chartCsv);
setFailure('chart');s.measure();s.finish();
verifyTrue(t,s.finished);verifyTrue(t,s.chartCsvNeedsRetry);verifyFalse(t,s.needsRecovery);

verifyEqual(t,colormeasuretest.readBytes(s.files.chartCsv),lastGood);
verifySubstring(t,field(s.window,'RecoveryMessage').String,'Chart CSV is stale. MAT saved.');
verifyEqual(t,field(s.window,'RetrySaveButton').String,'Retry CSV');
verifyEqual(t,field(s.window,'RetrySaveButton').Enable,'on');
verifyEqual(t,field(s.window,'NewBatchButton').Enable,'on');
verifyEqual(t,field(s.window,'MeasureButton').Enable,'off');
s.window.Position=[30 30 960 750];s.window.SizeChangedFcn(s.window,[]);
colormeasuretest.click(field(s.window,'ToggleReadingsButton'));
recovery=getpixelposition(field(s.window,'RecoveryMessage'),true);
tablePanel=getpixelposition(field(s.window,'ResultsTablePanel'),true);
verifyEqual(t,char(field(s.window,'RecoveryMessage').Visible),'on');
verifyEqual(t,char(field(s.window,'ResultsTablePanel').Visible),'on');
verifyGreaterThanOrEqual(t,tablePanel(2),recovery(2)+recovery(4));
before=s.measurements;calls=counts();mat=colormeasuretest.readBytes(s.files.mat);
setFailure('observeChartRetry');colormeasuretest.click(field(s.window,'RetrySaveButton'));
after=counts();verifyEqual(t,after.reads,calls.reads);verifyEqual(t,after.mat,calls.mat);
verifyTrue(t,after.chartRetryObserved);
verifyEqual(t,s.measurements,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),mat);
verifyFalse(t,s.chartCsvNeedsRetry);verifyTrue(t,s.chart.csvCurrent);
verifyEqual(t,field(s.window,'NewBatchButton').Enable,'on');verifyTrue(t,s.finished);
end
function testUnavailablePlacementHasNoConfigurationAndInspectionDoesNotWrite(t)
[s,counts,~]=saveRecoverySession(t);s.startChart(colormeasure.chart.definition('custom','Native only',1,2));s.show();
before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);calls=counts();
verifyEmpty(t,findobj(s.window,'Tag','GuidedChartPlacement'));
verifyEmpty(t,findobj(s.window,'Tag','GuidedChartPositionStatus'));
verifyEmpty(t,findobj(s.window,'Tag','GuidedChartMeasuredPreview'));
grid=field(s.window,'GuidedChartGrid');grid.CellSelectionCallback(grid,struct('Indices',[1 2]));
verifyEqual(t,s.info,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifyEqual(t,counts(),calls);verifyEqual(t,s.chart.currentCell,[1 1]);
end
function testExistingAttemptRejectsReplacementWithoutChangingAssociation(t)
s=session(t);s.startChart(colormeasure.chart.definition('custom','Original',1,2));s.measure();s.show();
before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);readings=s.measurements;
colormeasuretest.click(field(s.window,'GuidedChartChange'));dialog=field(groot,'GuidedChartSetup');
colormeasuretest.click(field(dialog,'GuidedChartSetupStart'));
verifySubstring(t,field(dialog,'GuidedChartSetupError').Text,'replace a chart');
verifyEqual(t,s.info,before);verifyEqual(t,s.measurements,readings);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyTrue(t,isgraphics(dialog));
colormeasuretest.click(field(dialog,'GuidedChartSetupCancel'));
end
function testChangedChartCsvOffersRelocationWithoutRetryOrReacquisition(t)
[s,counts,~]=saveRecoverySession(t);s.startChart(colormeasure.chart.definition('custom','Two patches',1,2));s.measure();
path=s.files.chartCsv;file=fopen(path,'a');assert(file>=0);fwrite(file,'external edit');fclose(file);
external=colormeasuretest.readBytes(path);s.measure();s.finish();s.show();
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyFalse(t,s.chartCsvNeedsRetry);
verifyTrue(t,s.companionRecoveryAvailable);fig=s.window;
verifyEqual(t,char(field(fig,'RetrySaveButton').Visible),'off');
verifyEqual(t,char(field(fig,'SaveElsewhereButton').Visible),'on');
verifyEqual(t,field(fig,'SaveElsewhereButton').Enable,'on');verifyEqual(t,field(fig,'NewBatchButton').Enable,'on');
verifySubstring(t,field(fig,'RecoveryMessage').String,'MAT saved.');
verifySubstring(t,field(fig,'RecoveryMessage').TooltipString,'Repeating Retry cannot resolve');
verifySubstring(t,field(fig,'RecoveryMessage').TooltipString,'Chart CSV:');
verifySubstring(t,field(fig,'RecoveryMessage').TooltipString,'Another folder');
fig.Position=[30 30 960 750];fig.SizeChangedFcn(fig,[]);
colormeasuretest.click(field(fig,'ToggleReadingsButton'));
message=getpixelposition(field(fig,'RecoveryMessage'),true);tablePanel=getpixelposition(field(fig,'ResultsTablePanel'),true);
verifyGreaterThanOrEqual(t,tablePanel(2),message(2)+message(4));
before=s.measurements;mat=colormeasuretest.readBytes(s.files.mat);calls=counts();s.retrySave();
verifyEqual(t,counts(),calls);verifyEqual(t,s.measurements,before);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),mat);verifyEqual(t,colormeasuretest.readBytes(path),external);
end
function [s,counts,setFailure]=saveRecoverySession(t)
failure='';reads=0;matWrites=0;chartWrites=0;chartRetryObserved=false;
io=colormeasure.ui.services();save=io.saveMat;csv=io.exportCsv;
io.saveMat=@saveMat;io.exportCsv=@exportCsv;
io.createView=@(owner)colormeasure.ui.Window(owner,@(~,~)true);
adapter=colormeasure.drivers.cr.demoAdapter('CR250','interactive');read=adapter.read;adapter.read=@readSample;
s=colormeasure.session.Session(adapter,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));counts=@readCounts;setFailure=@failPersistence;
    function value=readCounts()
        value=struct('reads',reads,'mat',matWrites,'chartCsv',chartWrites, ...
            'chartRetryObserved',chartRetryObserved);
    end
    function failPersistence(value)
        failure=value;
    end
    function value=readSample(instrument)
        reads=reads+1;value=read(instrument);
    end
    function saveMat(varargin)
        matWrites=matWrites+1;
        if strcmp(failure,'mat'),error('Test:MatWrite','Authoritative MAT write failed.');end
        save(varargin{:});
    end
    function digest=exportCsv(varargin)
        if endsWith(varargin{3},'chart-selected.csv'),chartWrites=chartWrites+1;end
        if strcmp(failure,'csv'),error('Test:CsvWrite','CSV publication failed.');end
        if strcmp(failure,'chart')&&endsWith(varargin{3},'chart-selected.csv')
            error('Test:ChartCsvWrite','Chart CSV publication failed.');
        end
        if strcmp(failure,'observeChartRetry')&&endsWith(varargin{3},'chart-selected.csv')
            chartRetryObserved=true;verifyTrue(t,s.busy);verifyFalse(t,s.saving);verifyTrue(t,s.finished);
            verifySubstring(t,field(s.window,'GuidedChartProgress').Text,'updating csv');
            verifySubstring(t,field(s.window,'GuidedChartPatchDetail').Text,'Updating CSV');
            verifyFalse(t,contains(field(s.window,'GuidedChartProgress').Text,'measurement in progress'));
        end
        digest=csv(varargin{:});
    end
end
function restoreRegistry(previous)
if isempty(previous)
    if isappdata(groot,'ColorMeasureSessions'),rmappdata(groot,'ColorMeasureSessions');end
else
    setappdata(groot,'ColorMeasureSessions',previous);
end
end

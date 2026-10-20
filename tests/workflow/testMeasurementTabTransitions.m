function tests = testMeasurementTabTransitions
% Sidebar inspection must not alter acquisition, drafts or comparison choices.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder=fixture.Folder;
previous=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',previous));
end

function testMeasureRestoresOrdinaryModeAndCompareRestoresPair(t)
for ordinaryMode=[1 2]
    s=makeSession(t);s.show();for k=1:3,s.measure();end
    fig=s.window;mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=ordinaryMode;colormeasuretest.click(mode);
    choosePair(fig,1,2);white=colormeasuretest.field(fig,'CompareWhite');white.Value=3;colormeasuretest.change(white);
    set(colormeasuretest.field(fig,'SampleName'),'String','Pending sample');
    notes=colormeasuretest.field(fig,'SampleNotes');notes.Value={'Keep this draft'};
    before=snapshot(s);table=colormeasuretest.field(fig,'ResultsTable');tableBefore=table.Data;
    selected=table.UserData;selection=table.Selection;
    comparison=colormeasuretest.field(fig,'ComparisonResults').UserData;
    verifyPair(t,fig,[1 2]);
    selectTab(fig,'MeasureTab');
    verifyOrdinary(t,fig,ordinaryMode,selected);
    verifyEqual(t,table.Data,tableBefore);verifyEqual(t,table.Selection,selection);
    verifyEqual(t,snapshot(s),before);
    verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending sample');
    verifyEqual(t,colormeasuretest.field(fig,'SampleNotes').Value,{'Keep this draft'});
    selectTab(fig,'CompareTab');verifyPair(t,fig,[1 2]);
    verifyEqual(t,colormeasuretest.field(fig,'ComparisonResults').UserData,comparison);
    verifyEqual(t,colormeasuretest.field(fig,'CompareWhite').Value,3);
    verifyEqual(t,table.UserData,selected);verifyEqual(t,snapshot(s),before);
    % An appended reading refreshes comparison results, but must not put the
    % measurement tab back in pair mode or reset its ordinary spectrum choice.
    selectTab(fig,'MeasureTab');s.measure('Next sample','');
    verifyOrdinary(t,fig,ordinaryMode,table.UserData);
    verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
    verifyEqual(t,colormeasuretest.field(fig,'CompareSample').Value,2);
    verifyEqual(t,colormeasuretest.field(fig,'CompareWhite').Value,3);
    selectTab(fig,'CompareTab');verifyPair(t,fig,[1 2]);
end
end

function testFirstCompareVisitAndIncompletePairKeepOrdinaryPlots(t)
s=makeSession(t);s.show();fig=s.window;
selectTab(fig,'CompareTab');verifyEmpty(t,colormeasuretest.field(fig,'DifferenceAxes'));
selectTab(fig,'MeasureTab');s.measure();s.measure();
mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=2;colormeasuretest.click(mode);
selectTab(fig,'CompareTab');verifyOrdinary(t,fig,2,2);
reference=colormeasuretest.field(fig,'CompareReference');reference.Value=1;colormeasuretest.change(reference);
selectTab(fig,'MeasureTab');selectTab(fig,'CompareTab');
verifyOrdinary(t,fig,2,2);verifyEqual(t,reference.Value,1);
sample=colormeasuretest.field(fig,'CompareSample');sample.Value=1;colormeasuretest.change(sample);
selectTab(fig,'MeasureTab');selectTab(fig,'CompareTab');
verifyOrdinary(t,fig,2,2);
end

function testXYZOnlyTabsKeepChromaticityWithoutResidualAxes(t)
a=adapter();a.viewData=@xyzOnlyData;s=makeSession(t,a);s.show();
s.measure();s.measure();fig=s.window;choosePair(fig,1,2);
for tag={'MeasureTab','CompareTab'}
    selectTab(fig,tag{1});
    verifyEmpty(t,colormeasuretest.field(fig,'DifferenceAxes'));
    verifyEqual(t,char(colormeasuretest.field(fig,'SpectrumAxes').Visible),'off');
    verifyEqual(t,char(colormeasuretest.field(fig,'ChromaticityAxes').Visible),'on');
    verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
    verifyEqual(t,colormeasuretest.field(fig,'CompareSample').Value,2);
end
end

function testFinishedBatchTabChangesOnlyAffectPresentation(t)
s=makeSession(t);s.show();for k=1:3,s.measure();end
fig=s.window;choosePair(fig,1,2);s.finish();before=snapshot(s);
selectTab(fig,'MeasureTab');verifyOrdinary(t,fig,1,colormeasuretest.field(fig,'ResultsTable').UserData);
selectTab(fig,'CompareTab');verifyPair(t,fig,[1 2]);
verifyEqual(t,snapshot(s),before);verifyTrue(t,s.finished);
end

function testTablePairSelectionKeepsInspectedReadingOnReturn(t)
s=makeSession(t);s.show();for k=1:3,s.measure();end
fig=s.window;mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=2;colormeasuretest.click(mode);
table=colormeasuretest.field(fig,'ResultsTable');callback=table.CellSelectionCallback;
callback(table,struct('Indices',[1 3;2 3]));
verifyEqual(t,colormeasuretest.field(fig,'MeasurementSidebar').SelectedTab,colormeasuretest.field(fig,'CompareTab'));
verifyPair(t,fig,[1 2]);verifyEqual(t,table.UserData,2);
selection=table.Selection;before=snapshot(s);
selectTab(fig,'MeasureTab');verifyOrdinary(t,fig,2,2);
verifyEqual(t,table.Selection,selection);verifyEqual(t,table.UserData,2);
selectTab(fig,'CompareTab');verifyPair(t,fig,[1 2]);
verifyEqual(t,snapshot(s),before);
end

function testDataAndColorTabsKeepDerivedViewUntilExplicitMeasureReturn(t)
s=makeSession(t);s.show();for k=1:3,s.measure();end
fig=s.window;selectTab(fig,'IlluminationTab');
source=colormeasuretest.field(fig,'IlluminationSourceWhite');source.Value=-1;colormeasuretest.change(source);
apply=colormeasuretest.field(fig,'IlluminationApply');callback=apply.ButtonPushedFcn;callback(apply,[]);
analysis=getappdata(fig,'IlluminationResult');assertTrue(t,analysis.available,analysis.reason);
derived=colormeasuretest.field(fig,'IlluminationChromaticity');verifyEqual(t,char(derived.Visible),'on');
before=snapshot(s);
selectTab(fig,'ReadingTab');verifyEqual(t,char(derived.Visible),'on');
selectTab(fig,'IlluminationTab');verifyEqual(t,char(derived.Visible),'on');
selectTab(fig,'MeasureTab');verifyEqual(t,char(derived.Visible),'off');
verifyOrdinary(t,fig,1,colormeasuretest.field(fig,'ResultsTable').UserData);
verifyEqual(t,source.Value,-1);verifyEqual(t,getappdata(fig,'IlluminationResult'),analysis);
verifyEqual(t,char(colormeasuretest.field(fig,'IlluminationExport').Enable),'on');
verifyEqual(t,snapshot(s),before);
end

function testCompareRestoresMeasuredPlotsForOutputAndPairStates(t)
for spectral=[true false]
    for completePair=[true false]
        a=adapter(); if ~spectral,a.viewData=@xyzOnlyData;end
        s=makeSession(t,a);s.show();for k=1:3,s.measure();end
        fig=s.window;if completePair,choosePair(fig,1,2);end
        selectTab(fig,'IlluminationTab');
        source=colormeasuretest.field(fig,'IlluminationSourceWhite');source.Value=-1;colormeasuretest.change(source);
        apply=colormeasuretest.field(fig,'IlluminationApply');callback=apply.ButtonPushedFcn;callback(apply,[]);
        analysis=getappdata(fig,'IlluminationResult');assertTrue(t,analysis.available,analysis.reason);
        derived=colormeasuretest.field(fig,'IlluminationChromaticity');verifyEqual(t,char(derived.Visible),'on');
        before=snapshot(s);selectTab(fig,'CompareTab');
        verifyEqual(t,char(derived.Visible),'off');
        verifyEqual(t,getappdata(fig,'IlluminationResult'),analysis);
        verifyEqual(t,char(colormeasuretest.field(fig,'IlluminationExport').Enable),'on');
        verifyEqual(t,snapshot(s),before);
        if spectral && completePair,verifyPair(t,fig,[1 2]);end
        delete(s);
    end
end
end

function testDerivedAnnotationTracksThemeWithoutChangingAnalysis(t)
s=makeSession(t);s.show();s.measure();fig=s.window;fig.Theme='light';drawnow;
selectTab(fig,'IlluminationTab');
source=colormeasuretest.field(fig,'IlluminationSourceWhite');source.Value=-1;colormeasuretest.change(source);
apply=colormeasuretest.field(fig,'IlluminationApply');callback=apply.ButtonPushedFcn;callback(apply,[]);
analysis=getappdata(fig,'IlluminationResult');assertTrue(t,analysis.available,analysis.reason);
label=colormeasuretest.field(fig,'IlluminationChromaticityLabel');before=snapshot(s);
fig.Theme='dark';drawnow;verifyEqual(t,label.Color,[.9 .9 .9]);
fig.Theme='light';drawnow;verifyEqual(t,label.Color,[.16 .16 .16]);
verifyEqual(t,getappdata(fig,'IlluminationResult'),analysis);
verifyEqual(t,snapshot(s),before);
end

function testTabInspectionDuringReadDoesNotAcquireOrSave(t)
readCount=0;a=adapter();a.read=@duringRead;s=makeSession(t,a);s.show();
for k=1:3,s.measure();end
fig=s.window;mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=2;colormeasuretest.click(mode);
choosePair(fig,1,2);before=snapshot(s);s.measure();
verifyEqual(t,readCount,4);verifyNumElements(t,s.measurements,4);
    function reading=duringRead(~)
        readCount=readCount+1;
        if readCount==4
            verifyTrue(t,s.busy);saved=s.savedCount;
            selectTab(fig,'MeasureTab');verifyOrdinary(t,fig,2,colormeasuretest.field(fig,'ResultsTable').UserData);
            selectTab(fig,'CompareTab');verifyPair(t,fig,[1 2]);
            verifyEqual(t,s.measurements,before.measurements);
            verifyEqual(t,s.files,before.files);verifyEqual(t,s.savedCount,saved);
        end
        reading=struct('XYZ',[1 2 3]);
    end
end

function verifyPair(t,fig,ids)
verifyEqual(t,colormeasuretest.field(fig,'SpectraMode').Value,3);
verifyEqual(t,visibleSpectra(fig),ids);
verifyEqual(t,char(colormeasuretest.field(fig,'DifferenceAxes').Visible),'on');
verifyEqual(t,colormeasuretest.field(fig,'SpectralDifference').YData,ones(1,3));
verifyEqual(t,char(colormeasuretest.field(fig,'SpectrumAxes').XLabel.Visible),'off');
end

function verifyOrdinary(t,fig,mode,selected)
verifyEqual(t,colormeasuretest.field(fig,'SpectraMode').Value,mode);
if mode==2,expected=selected;else,expected=1:numel(colormeasuretest.field(fig,'ReadingSpectrum'));end
verifyEqual(t,visibleSpectra(fig),expected);
residual=colormeasuretest.field(fig,'DifferenceAxes');
if ~isempty(residual)
    verifyEqual(t,char(residual.Visible),'off');
    verifyEqual(t,char(colormeasuretest.field(fig,'SpectralDifference').Visible),'off');
end
verifyEqual(t,char(colormeasuretest.field(fig,'SpectrumAxes').XLabel.Visible),'on');
end

function ids=visibleSpectra(fig)
lines=findobj(fig,'Tag','ReadingSpectrum','Visible','on');
ids=sort(arrayfun(@(line) line.UserData,lines)).';
end

function choosePair(fig,a,b)
selectTab(fig,'CompareTab');
control=colormeasuretest.field(fig,'CompareReference');control.Value=a;colormeasuretest.change(control);
control=colormeasuretest.field(fig,'CompareSample');control.Value=b;colormeasuretest.change(control);
end

function selectTab(fig,tag)
group=colormeasuretest.field(fig,'MeasurementSidebar');old=group.SelectedTab;
group.SelectedTab=colormeasuretest.field(fig,tag);
% Programmatic property assignment does not dispatch the native user event.
callback=group.SelectionChangedFcn;
if ~isempty(callback),callback(group,struct('OldValue',old,'NewValue',group.SelectedTab));end
end

function value=snapshot(s)
value=struct('measurements',s.measurements,'files',s.files,'info',s.info,'log',s.log);
end

function s=makeSession(t,a)
if nargin<2,a=adapter();end
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services());
t.addTeardown(@() delete(s));
end

function a=adapter()
a=struct('key','TEST_TABS','label','Tab transition checks', ...
    'listPorts',@(~) "VIRTUAL", ...
    'connect',@(~) colormeasuretest.session.Instrument(@() struct('XYZ',[1 2 3]),@() []), ...
    'read',@(instrument) instrument.Read(),'release',@(instrument) delete(instrument), ...
    'viewData',@plotData,'toTable',@(m,~) table((1:numel(m))','VariableNames',{'Index'}));
end

function data=plotData(m)
count=numel(m);xyz=zeros(0,3);if count>0,xyz=vertcat(m.XYZ);end
spectra=arrayfun(@(k) struct('x',[400 500 600],'y',[k k+1 k+2]), ...
    (1:count)','UniformOutput',false);
data=struct('XYZ',xyz,'spectra',{spectra},'hasSpectra',true, ...
    'xyzComparisonKeys',{repmat({'Synthetic tab fixture'},count,1)}, ...
    'chromaticityComparisonKeys',{repmat({'Synthetic tab fixture'},count,1)}, ...
    'spectralComparisonKeys',{repmat({'Synthetic tab fixture'},count,1)}, ...
    'observerIds',{repmat({'CIE1931_2deg'},count,1)}, ...
    'observer','CIE 1931 2-degree observer (synthetic fixture)', ...
    'spectralUnits','Synthetic units');
end

function data=xyzOnlyData(m)
data=plotData(m);data.hasSpectra=false;data.spectra=repmat({[]},numel(m),1);
end

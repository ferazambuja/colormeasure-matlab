function tests = testMeasurementIlluminationUI
% Explicit derived views, source preservation and compact layouts; no devices.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function setup(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder=f.Folder;
visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',visible));
state=warning('error','Measurement:Display');t.addTeardown(@() warning(state));
end

function testInputsDoNotCalculateAndAppliedAnalysisCapturesSources(t)
[fig,tab]=container(t); calls=0;
view=colormeasure.ui.IlluminationView(tab,[],[],@derive);
t.addTeardown(@() colormeasuretest.dispose(view));[m,d]=readings();
view.update(m,d,1);
choose(fig,'IlluminationSourceWhite',2);
verifyEqual(t,calls,0);
verifyEmpty(t,getappdata(fig,'IlluminationResult'));
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
verifyEqual(t,calls,1);
r=getappdata(fig,'IlluminationResult');
verifyEqual(t,r.sourceIndices,[1 2]);
verifyEqual(t,r.sourceMeasurements,m([1 2]));
verifyEqual(t,r.config.sourceWhite,2);

choose(fig,'IlluminationDestinationWhite',-1);
verifyEqual(t,calls,1);
verifyEmpty(t,getappdata(fig,'IlluminationResult'));
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationExport').Enable),'off');
    function r=derive(data,index,config)
        calls=calls+1;r=derivedFixture(data,index,config);
    end
end

function testXYZOnlyOffersAdaptationAndExplainsUnavailableReflectance(t)
[fig,tab]=container(t);
view=colormeasure.ui.IlluminationView(tab,[],[],@derivedFixture);
t.addTeardown(@() colormeasuretest.dispose(view));[m,d]=readings();
d.hasSpectra=false;d.spectra={[];[];[]};view.update(m,d,1);
choose(fig,'IlluminationMode','reflectance');
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationApply').Enable),'off');
verifySubstring(t,colormeasuretest.control(fig,'IlluminationReason').Text,'no spectrum');
verifyFalse(t,colormeasuretest.control(fig,'IlluminationPerfectReference').Value);
verifyFalse(t,colormeasuretest.control(fig,'IlluminationConfirmedSetup').Value);
choose(fig,'IlluminationMode','adaptation');
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationApply').Enable),'on');
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationReference').Visible),'off');
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationSourceWhite').Visible),'on');
end

function testReferenceCSVAndExportPreserveDataAndNeverOverwrite(t)
[fig,tab]=container(t);
view=colormeasure.ui.IlluminationView(tab,[],[],@derivedFixture);
t.addTeardown(@() colormeasuretest.dispose(view));[m,d]=readings();view.update(m,d,1);
choose(fig,'IlluminationMode','reflectance');
choose(fig,'IlluminationReference',3);
reference=[400 .96;550 .97;700 .95];
filename=fullfile(t.TestData.folder,'reference.csv');writematrix(reference,filename);
view.loadReference(filename);
choose(fig,'IlluminationConfirmedSetup',true);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
result=getappdata(fig,'IlluminationResult');
verifyEqual(t,result.config.referenceReflectance,reference);
verifyEqual(t,result.config.referenceReflectanceFile,filename);
verifyEqual(t,result.sourceMeasurements,m([1 3]));
output=fullfile(t.TestData.folder,'derived.mat');view.exportAnalysis(output);
saved=load(output,'analysis');verifyEqual(t,saved.analysis,result);
verifyError(t,@() view.exportAnalysis(output),'Measurement:AnalysisFile');
after=load(output,'analysis');verifyEqual(t,after,saved);
bad=fullfile(t.TestData.folder,'invalid.csv');writematrix(ones(3,3),bad);
verifyError(t,@() view.loadReference(bad),'Measurement:ReferenceCSV');
choose(fig,'IlluminationReference',2);
verifyFalse(t,colormeasuretest.control(fig,'IlluminationConfirmedSetup').Value);
verifyEmpty(t,getappdata(fig,'IlluminationResult'));
end

function testExportKeepsANameTakenByADanglingLink(t)
% A dangling link passes the existence check. Exclusive publication must keep
% it rather than write through it to its target or replace it.
[~,tab]=container(t);view=colormeasure.ui.IlluminationView(tab,[],[],@derivedFixture);
t.addTeardown(@()colormeasuretest.dispose(view));[m,d]=readings();view.update(m,d,1);view.apply();
target=fullfile(t.TestData.folder,'link-target.mat');link=fullfile(t.TestData.folder,'dangling.mat');
[status,~]=system(sprintf('ln -s ''%s'' ''%s''',target,link));
assumeEqual(t,status,0,'This system cannot create a test symbolic link.');
verifyError(t,@() view.exportAnalysis(link),'Measurement:AnalysisFile');
verifyTrue(t,java.nio.file.Files.isSymbolicLink(java.io.File(link).toPath()));
verifyFalse(t,isfile(target));verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.mat')));
end

function testExclusivePublicationFailureNamesTheCauseAndRemovesTheStage(t)
% A NUL is not a native pathname. MAT staging uses a separate valid name,
% then Java refuses the destination inside the publication boundary. This
% exercises error wrapping and cleanup, not an unsupported-filesystem test.
filename=fullfile(t.TestData.folder,['invalid' char(0) '.mat']);
try
    colormeasure.session.saveMatFile(filename,struct('analysis',42),false);
    verifyFail(t,'An invalid publication path must be refused.');
catch problem
    verifyEqual(t,problem.identifier,'Measurement:SaveLinkFailed');
    verifySubstring(t,problem.message,'Cause:');
end
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.mat')));
valid=fullfile(t.TestData.folder,'valid.mat');
colormeasure.session.saveMatFile(valid,struct('analysis',42),false);
saved=load(valid);verifyEqual(t,saved.analysis,42);
end

function testExportDialogsCancelRefuseExistingAndSaveASeparateResult(t)
% Only chooser return values are substituted. This does not qualify the
% operating system's dialogs or keyboard focus.
[fig,tab]=container(t);view=colormeasure.ui.IlluminationView(tab,[],[],@derivedFixture);
t.addTeardown(@()colormeasuretest.dispose(view));[m,d]=readings();view.update(m,d,1);
view.apply();result=getappdata(fig,'IlluminationResult');
installExportDialogs(t);
button=colormeasuretest.control(fig,'IlluminationExport');
state=struct('folder',0,'answer',{{'cancelled.mat'}},'calls',{{}});
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
verifyEqual(t,getappdata(groot,'TestAnalysisExportDialogs').calls,{'folder'});
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.mat')));

state.folder=t.TestData.folder;state.answer={};state.calls={};
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
verifyEqual(t,getappdata(groot,'TestAnalysisExportDialogs').calls,{'folder','name'});
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.mat')));

output=fullfile(t.TestData.folder,'existing.mat');view.exportAnalysis(output);
before=load(output);state.answer={'existing.mat'};state.calls={};
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
verifyEqual(t,load(output),before);
verifySubstring(t,colormeasuretest.control(fig,'IlluminationReason').Text,'existing files are kept');

state.answer={fullfile('child','analysis.mat')};
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
verifySubstring(t,colormeasuretest.control(fig,'IlluminationReason').Text,'without a folder path');
verifyFalse(t,isfolder(fullfile(t.TestData.folder,'child')));

state.answer={'wrong-extension.txt'};
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
verifySubstring(t,colormeasuretest.control(fig,'IlluminationReason').Text,'Enter a new MAT filename.');
verifyFalse(t,isfile(fullfile(t.TestData.folder,'wrong-extension.txt')));
verifyEqual(t,getappdata(fig,'IlluminationResult'),result);

state.answer={'new-analysis.mat'};
setappdata(groot,'TestAnalysisExportDialogs',state);colormeasuretest.click(button);
saved=load(fullfile(t.TestData.folder,'new-analysis.mat'),'analysis');
verifyEqual(t,saved.analysis,result);verifyEqual(t,result.sourceMeasurements,m(1));
verifyEqual(t,getappdata(fig,'IlluminationResult'),result);
verifyEqual(t,char(button.Enable),'on');verifyEqual(t,load(output),before);
end

function testReflectancePlotAndMeasuredRestoreKeepRawValuesAndPairLabels(t)
[view,fig]=resultsView(t);[m,d]=readings();
view.update(m,d,positions(960,650));
choose(fig,'CompareReference',1);choose(fig,'CompareSample',2);
choose(fig,'IlluminationSample',1);
rawTable=colormeasuretest.control(fig,'ResultsTable').Data;
choose(fig,'IlluminationMode','reflectance');
choose(fig,'IlluminationReference',3);
choose(fig,'IlluminationPerfectReference',true);
choose(fig,'IlluminationConfirmedSetup',true);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
r=getappdata(fig,'IlluminationResult');
verifyTrue(t,r.available,r.reason);
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationSpectrumAxes').Visible),'on');
verifyEqual(t,char(colormeasuretest.control(fig,'SpectrumAxes').Visible),'off');
verifyEqual(t,char(colormeasuretest.control(fig,'DifferenceAxes').Visible),'off');
verifySubstring(t,colormeasuretest.control(fig,'IlluminationSpectrumAxes').YLabel.String,'Relative');
verifyEqual(t,colormeasuretest.control(fig,'ResultsTable').Data,rawTable);
derivedAxes=colormeasuretest.control(fig,'IlluminationSpectrumAxes');
note=colormeasuretest.control(fig,'IlluminationSpectrumNote');
drawnow;note.Units='pixels';
verifyGreaterThanOrEqual(t,note.Extent(2),derivedAxes.Position(4), ...
    'The derived-spectrum note must stay outside the curve area.');
observer=colormeasuretest.control(fig,'ResultObserver');
verifyLessThanOrEqual(t,derivedAxes.Position(2)+derivedAxes.Position(4)+ ...
    derivedAxes.TightInset(4),observer.Position(2)-4);
verifyEqual(t,colormeasuretest.control(fig,'IlluminationReflectance').YData,reshape(r.spectrum.y,1,[]));

choose(fig,'CoordinateMode',2);
point=colormeasuretest.control(fig,'IlluminationChromaticity');
xy=colormeasure.analysis.chromaticity(r.XYZ,'xy');
verifyEqual(t,[point.XData point.YData],xy,'AbsTol',1e-14);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationMeasured'));
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationSpectrumAxes').Visible),'off');
verifyEqual(t,char(colormeasuretest.control(fig,'SpectrumAxes').Visible),'on');
verifyEqual(t,char(colormeasuretest.control(fig,'DifferenceAxes').Visible),'on');
verifyEqual(t,char(colormeasuretest.control(fig,'DifferenceAxes').XLabel.Visible),'on');
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationChromaticity').Visible),'off');
verifyEqual(t,getappdata(fig,'IlluminationResult'),r);
verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationExport').Enable),'on');
choose(fig,'IlluminationTarget',-1);
verifyEmpty(t,getappdata(fig,'IlluminationResult'));
verifyTrue(t,colormeasuretest.control(fig,'IlluminationConfirmedSetup').Value);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
reapplied=getappdata(fig,'IlluminationResult');
verifyTrue(t,reapplied.available,reapplied.reason);
verifyEqual(t,reapplied.config.targetIlluminant,'D50');
end

function testQuantityGateMatchesDirectCalculationAndCannotBeBypassed(t)
[fig,tab]=container(t);calls=0;
view=colormeasure.ui.IlluminationView(tab,[],[],@derive);
t.addTeardown(@()colormeasuretest.dispose(view));[m,base]=readings();
choose(fig,'IlluminationMode','reflectance');
for row=[1 3]
    d=base;d.spectralQuantities{row}='reflectance';
    view.update(m,d,1);choose(fig,'IlluminationReference',3);
    choose(fig,'IlluminationPerfectReference',true);
    choose(fig,'IlluminationConfirmedSetup',true);
    config=struct('mode','reflectance','reference',3,'confirmedSetup',true, ...
        'assumePerfectReference',true,'targetIlluminant','D65');
    direct=colormeasure.analysis.deriveIllumination(d,1,config);
    verifyFalse(t,direct.available);
    verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationApply').Enable),'off');
    verifyEqual(t,colormeasuretest.control(fig,'IlluminationReason').Text,direct.reason);
    view.apply(); % A direct controller call must also enforce eligibility.
    verifyEqual(t,calls,0);verifyEmpty(t,getappdata(fig,'IlluminationResult'));
    verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationExport').Enable),'off');
end
    function r=derive(data,index,config)
        calls=calls+1;r=derivedFixture(data,index,config);
    end
end

function testReflectanceExportRetainsSourcesQuantityAndOperatorDeclaration(t)
[fig,tab]=container(t);view=colormeasure.ui.IlluminationView(tab);
t.addTeardown(@()colormeasuretest.dispose(view));[m,d]=readings();
view.update(m,d,1);choose(fig,'IlluminationMode','reflectance');
choose(fig,'IlluminationReference',3);choose(fig,'IlluminationPerfectReference',true);
choose(fig,'IlluminationConfirmedSetup',true);view.apply();
r=getappdata(fig,'IlluminationResult');verifyTrue(t,r.available,r.reason);
output=fullfile(t.TestData.folder,'quantity-analysis.mat');view.exportAnalysis(output);
saved=load(output,'analysis');verifyEqual(t,saved.analysis,r);
verifyEqual(t,r.sourceMeasurements,m([1 3]));
verifyEqual(t,r.provenance.quantityContext.sample.quantity,'synthetic radiance');
verifyEqual(t,r.provenance.quantityContext.reference.units,'synthetic units');
verifyTrue(t,r.config.confirmedSetup);verifyEqual(t,r.provenance.setupDeclaredBy,'operator');
end

function testXYZOnlyLayoutUsesFullPlotWidthAtBothWindowSizes(t)
[view,fig]=resultsView(t);[m,d]=readings();
d.hasSpectra=false;d.spectra={[];[];[]};
d.noSpectrumReason='CR-100 reports XYZ; no spectrum.';
for dimensions=[960 1120;650 760]
    fig.Position=[20 20 dimensions(1) dimensions(2)];
    p=positions(dimensions(1),dimensions(2));
    view.update(m,d,p);view.layout(p);drawnow;
    chroma=colormeasuretest.control(fig,'ChromaticityAxes');
    verifyGreaterThan(t,chroma.Position(3),p.plots(3)*.8);
    note=colormeasuretest.control(fig,'SpectrumUnavailable');
    verifyLessThanOrEqual(t,note.Position(4),24);
    verifyEqual(t,note.Text,d.noSpectrumReason);
    verifyEqual(t,char(colormeasuretest.control(fig,'SpectrumAxes').Visible),'off');
end
end

function testReflectancePlotFollowsLaterResizes(t)
[view,fig]=resultsView(t);[m,d]=readings();
view.update(m,d,positions(960,650));
choose(fig,'IlluminationSample',1);
choose(fig,'IlluminationMode','reflectance');
choose(fig,'IlluminationReference',3);
choose(fig,'IlluminationPerfectReference',true);
choose(fig,'IlluminationConfirmedSetup',true);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
r=getappdata(fig,'IlluminationResult');verifyTrue(t,r.available,r.reason);
derivedAxes=colormeasuretest.control(fig,'IlluminationSpectrumAxes');
acquiredAxes=colormeasuretest.control(fig,'SpectrumAxes');
chroma=colormeasuretest.control(fig,'ChromaticityAxes');
for dimensions=[1280 960;840 650]
    fig.Position=[20 20 dimensions(1) dimensions(2)];
    view.layout(positions(dimensions(1),dimensions(2)));drawnow;
    verifyEqual(t,derivedAxes.Position,acquiredAxes.Position, ...
        'The derived spectrum must take the acquired spectrum''s place after a resize.');
    verifyLessThan(t,derivedAxes.Position(1)+derivedAxes.Position(3),chroma.Position(1));
    verifyEqual(t,char(derivedAxes.Visible),'on');
end
verifyEqual(t,colormeasuretest.control(fig,'IlluminationReflectance').YData,reshape(r.spectrum.y,1,[]));
end

function testWindowActionsStayVisibleAndApplyingDoesNotAcquireOrSave(t)
[m,~]=readings(); count=0;
adapter=struct('key','IlluminationUITest','label','Synthetic analysis test', ...
    'listPorts',@(~) "TEST_ONLY",'connect',@(~) struct(), ...
    'read',@read,'release',@(~) [],'viewData',@presentation, ...
    'toTable',@(rows,~) table((1:numel(rows))','VariableNames',{'Index'}));
session=colormeasure.session.Session(adapter,t.TestData.folder,colormeasure.ui.services());
t.addTeardown(@() colormeasuretest.dispose(session));session.show();session.measure();
fig=session.window;
snapshot=struct('measurements',session.measurements,'info',session.info,'files',session.files,'log',session.log);
saved=load(session.files.mat);
tab=colormeasuretest.control(fig,'IlluminationTab');tab.Parent.SelectedTab=tab;
choose(fig,'IlluminationSourceWhite',-1);
colormeasuretest.click(colormeasuretest.control(fig,'IlluminationApply'));
r=getappdata(fig,'IlluminationResult');verifyTrue(t,r.available,r.reason);
verifyEqual(t,count,1);
verifyEqual(t,struct('measurements',session.measurements,'info',session.info,'files',session.files,'log',session.log),snapshot);
verifyEqual(t,load(session.files.mat),saved);
% Grid geometry arrives asynchronously from the UI client. This test needs
% layout bounds, not raster output: realize the owned figure and wait for
% the resized controls, as in the existing Analysis Help layout test.
% The isolated -noFigureWindows worker does not open a measurement desktop.
fig.Visible='on';drawnow;
for dimensions=[960 1120;650 760]
    fig.Position=[20 20 dimensions(1) dimensions(2)];
    callback=fig.SizeChangedFcn;callback(fig,[]);
    tags={'IlluminationApply','IlluminationMeasured','IlluminationExport'};
    started=tic;settled=false;boxes=zeros(numel(tags),4);
    while toc(started)<30
        drawnow;bounds=getpixelposition(tab,true);settled=true;
        for n=1:numel(tags)
            boxes(n,:)=getpixelposition(colormeasuretest.control(fig,tags{n}),true);
            box=boxes(n,:);
            settled=settled&&all(isfinite(box))&&box(3)>0&&box(4)>=24&& ...
                all(box(1:2)>=bounds(1:2))&& ...
                all(box(1:2)+box(3:4)<=bounds(1:2)+bounds(3:4)+1);
        end
        % Primary actions occupy separate columns; Export is in the next row.
        settled=settled&&boxes(1,1)+boxes(1,3)<=boxes(2,1)+1&& ...
            boxes(3,2)+boxes(3,4)<=boxes(1,2)+1;
        if settled,break;end
        pause(0.02);
    end
    verifyTrue(t,settled,sprintf('Color actions did not settle after resize. Tab=%s; Actions=%s.', ...
        mat2str(bounds),mat2str(boxes)));
    for n=1:numel(tags)
        box=boxes(n,:);
        verifyGreaterThanOrEqual(t,box(1:2),bounds(1:2));
        verifyLessThanOrEqual(t,box(1:2)+box(3:4),bounds(1:2)+bounds(3:4)+1);
        verifyGreaterThanOrEqual(t,box(4),24);
    end
    verifyEqual(t,char(colormeasuretest.control(fig,'IlluminationControls').Scrollable),'on');
end
    function value=read(~)
        count=count+1;value=m(1);
    end
end

function testPreparationCancelPreservesDraftAndReadyIsRemembered(t)
[m,~]=readings();reads=0;prompts=false(1,0);ready=false;
adapter=preparedAdapter(true);adapter.read=@read;
io=colormeasure.ui.services();io.createView=@(s) colormeasure.ui.Window(s,@prompt);
session=colormeasure.session.Session(adapter,t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.dispose(session));session.show();fig=session.window;
verifyEmpty(t,prompts);verifyEqual(t,reads,0);
set(colormeasuretest.control(fig,'SampleName'),'String','Pending reflective sample');
before=struct('name',session.name,'sampleRevision',session.sampleRevision,'log',session.log);
colormeasuretest.click(colormeasuretest.control(fig,'InstrumentHelpButton'));
verifyEqual(t,prompts,false);verifyEqual(t,reads,0);
colormeasuretest.click(colormeasuretest.control(fig,'MeasureButton'));
verifyEqual(t,prompts,[false true]);verifyEqual(t,reads,0);
verifyEqual(t,struct('name',session.name,'sampleRevision',session.sampleRevision,'log',session.log),before);
verifyEqual(t,get(colormeasuretest.control(fig,'SampleName'),'String'),'Pending reflective sample');
ready=true;colormeasuretest.click(colormeasuretest.control(fig,'MeasureButton'));colormeasuretest.click(colormeasuretest.control(fig,'MeasureButton'));
verifyEqual(t,prompts,[false true true]);verifyEqual(t,reads,2);
verifyEqual(t,session.measurements(1).name,'Pending reflective sample');
    function answer=prompt(preparation,confirmation)
        verifyEqual(t,preparation.title,'Synthetic preparation fixture');
        prompts(end+1)=confirmation;answer=ready;
    end
    function value=read(~)
        reads=reads+1;value=m(1);
    end
end

function testPreparationRemainsOptionalAndNewWindowRequiresFreshChoice(t)
[m,~]=readings();prompts=0;
adapter=preparedAdapter(false);adapter.read=@(~) m(1);
io=colormeasure.ui.services();io.createView=@(s) colormeasure.ui.Window(s,@prompt);
demo=colormeasure.session.Session(adapter,t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.dispose(demo));demo.show();colormeasuretest.click(colormeasuretest.control(demo.window,'MeasureButton'));
verifyEqual(t,prompts,0);verifyNumElements(t,demo.measurements,1);
adapter.preparation.required=true;
for batch=1:2
    session=colormeasure.session.Session(adapter,t.TestData.folder,io);
    t.addTeardown(@() colormeasuretest.dispose(session));session.show();colormeasuretest.click(colormeasuretest.control(session.window,'MeasureButton'));
    verifyEqual(t,prompts,batch);verifyNumElements(t,session.measurements,1);
end
    function answer=prompt(~,confirmation)
        verifyTrue(t,confirmation);prompts=prompts+1;answer=true;
    end
end

function adapter=preparedAdapter(required)
adapter=struct('key','PreparationUITest','label','Synthetic preparation test', ...
    'listPorts',@(~) "TEST_ONLY",'connect',@(~) struct(), ...
    'release',@(~) [],'viewData',@presentation, ...
    'toTable',@(rows,~) table((1:numel(rows))','VariableNames',{'Index'}), ...
    'preparation',struct('title','Synthetic preparation fixture', ...
        'summary','Fixture only; no instrument operation.', ...
        'details',{{'Follow the appropriate manual for real hardware.'}}, ...
        'url','https://example.invalid/fixture-manual','required',required));
end

function installExportDialogs(t)
folder=fullfile(t.TestData.folder,'chooser-return-values');mkdir(folder);
key='TestAnalysisExportDialogs';colormeasuretest.preserveAppdata(t,key);
writelines(["function folder=uigetdir(varargin)"; ...
    "state=getappdata(groot,'TestAnalysisExportDialogs');"; ...
    "state.calls{end+1}='folder';setappdata(groot,'TestAnalysisExportDialogs',state);"; ...
    "folder=state.folder;";"end"],fullfile(folder,'uigetdir.m'));
writelines(["function answer=inputdlg(varargin)"; ...
    "state=getappdata(groot,'TestAnalysisExportDialogs');"; ...
    "state.calls{end+1}='name';setappdata(groot,'TestAnalysisExportDialogs',state);"; ...
    "answer=state.answer;";"end"],fullfile(folder,'inputdlg.m'));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
assertEqual(t,which('uigetdir'),fullfile(folder,'uigetdir.m'));
assertEqual(t,which('inputdlg'),fullfile(folder,'inputdlg.m'));
end

function [fig,tab]=container(t)
fig=figure('Visible','off','Position',[20 20 960 650]);t.addTeardown(@() colormeasuretest.dispose(fig));
group=uitabgroup(fig,'Units','pixels','Position',[16 254 272 336]);
tab=uitab(group,'Title','Color view');
end

function [view,fig]=resultsView(t)
[fig,tab]=container(t);group=tab.Parent;
reading=uitab(group,'Title','Reading');comparison=uitab(group,'Title','Compare');
view=colormeasure.ui.ResultsView(fig,reading,comparison,tab);
t.addTeardown(@() colormeasuretest.dispose(view));
end

function [m,d]=readings()
w=(400:10:700)';spectra=[.04+.025*exp(-((w-540)/45).^2), ...
    .03+.03*exp(-((w-600)/60).^2),.1*ones(size(w))];
template=struct('name','','notes','','lambda',[],'radiance',[],'XYZ',[], ...
    'deviceType','SYNTHETIC UI TEST','completedAtUTC','2026-09-17T12:00:00.000Z');
m=repmat(template,1,3);
for index=1:3
    m(index).name=sprintf('Sample %03d',index);m(index).notes='Synthetic UI test record';
    m(index).lambda=w;m(index).radiance=spectra(:,index);
    m(index).XYZ=colormeasure.colorimetry.spectra2XYZ(spectra(:,index),w);
end
d=presentation(m);
end

function d=presentation(m)
n=numel(m);xyz=zeros(n,3);
if n>0,xyz=reshape([m.XYZ],3,[])';end
d=struct('XYZ',xyz,'observer','CIE 1931 2-degree observer', ...
    'observerId','CIE1931_2deg','observerIds',{repmat({'CIE1931_2deg'},n,1)}, ...
    'spectra',{cell(n,1)},'hasSpectra',true,'spectralLabel','Synthetic spectral reading', ...
    'spectralUnits','synthetic units','locusXYZ',colormeasure.colorimetry.observer(), ...
    'xyzComparisonKeys',{repmat({'synthetic-ui-test'},n,1)}, ...
    'chromaticityComparisonKeys',{repmat({'synthetic-ui-test'},n,1)}, ...
    'spectralComparisonKeys',{repmat({'synthetic-ui-test'},n,1)});
d.reflectanceRatioEligible=true(n,1);
d.spectralQuantities=repmat({'synthetic radiance'},n,1);
for index=1:n,d.spectra{index}=struct('x',m(index).lambda,'y',m(index).radiance);end
end

function r=derivedFixture(data,index,config)
r=struct('available',true,'reason','','mode',config.mode,'label','Derived test view', ...
    'XYZ',[10 12 8],'whiteXYZ',[1 1 1],'rgb',[.5 .6 .4],'coordinates',[.2 .45], ...
    'spectrum',struct('x',[400;550;700],'y',[.4;.5;.3]), ...
    'details',{{'Synthetic controller fixture, not a color calculation.'}}, ...
    'provenance',struct('fixture',true),'sourceXYZ',data.XYZ(index,:), ...
    'sourceSpectrum',data.spectra{index},'referenceSpectrum',[], ...
    'createdAtUTC','2026-09-17T12:01:00.000Z','config',config);
end

function p=positions(width,height)
lower=min(290,200+floor((height-650)*.65));bottom=54+lower;top=height-60;
p=struct('plots',[308 bottom width-324 top-bottom], ...
    'table',[16 16 width-32 lower],'details',[8 8 252 top-bottom-42]);
end
function choose(fig,tag,value)
control=colormeasuretest.control(fig,tag);control.Value=value;
colormeasuretest.change(control);
end

function testAnalysisTextFormattingPreservesSignAndUnavailableValues(t)
for pair={{0,'0'},{-0.1234567,'-0.123457'},{1.234567,'1.23457'},{true,'1'}, ...
        {NaN,'Unavailable'},{Inf,'Unavailable'},{-Inf,'Unavailable'},{[], 'Unavailable'}, ...
        {[1 2],'Unavailable'},{1+1i,'Unavailable'}}
    entry=pair{1};verifyEqual(t,colormeasure.ui.displayNumber(entry{1}),entry{2});
end
end

function tests = testMeasurementResults
% Numerical references and linked native views; synthetic readings only.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testIndependentCoordinateReferences(t)
XYZ = [1 1 1; 95.047 100 108.883; 2 3 4];
[uv,valid] = colormeasure.analysis.chromaticity(XYZ);
verifyTrue(t,all(valid));
verifyEqual(t,uv(1,:),[4/19 9/19],'AbsTol',1e-14);
verifyEqual(t,uv(2,:),[.1978398248214078 .4683363029324097],'AbsTol',1e-13);
verifyEqual(t,uv(3,:),[8/59 27/59],'AbsTol',1e-14);
xy = colormeasure.analysis.chromaticity(XYZ,'xy');
verifyEqual(t,xy(1,:),[1/3 1/3],'AbsTol',1e-14);
verifyEqual(t,xy(2,:),[.3127266146810121 .3290231303260619],'AbsTol',1e-13);
verifyEqual(t,xy(3,:),[2/9 3/9],'AbsTol',1e-14);
end

function testXYZOnlyDeviceExplainsSpectrumAndKeepsColorComparison(t)
fig=figure('Visible','off');t.addTeardown(@() delete(fig));
group=uitabgroup(fig);reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(2);d=syntheticComparisonData(m);d.spectra={[];[]};
d.hasSpectra=false;d.noSpectrumReason='The adapter reports XYZ only.';
view.update(m,d,positions(650,400));
verifyEqual(t,char(colormeasuretest.field(fig,'SpectraMode').Enable),'off');
verifyEqual(t,colormeasuretest.field(fig,'SpectrumUnavailable').Text,d.noSpectrumReason);
verifyEqual(t,char(colormeasuretest.field(fig,'SpectrumUnavailable').WordWrap),'on');
verifyEqual(t,char(colormeasuretest.field(fig,'SpectrumAxes').Visible),'off');
table=colormeasuretest.field(fig,'ResultsTable');cb=table.CellSelectionCallback;
cb(table,struct('Indices',[1 3;2 3]));
verifyEqual(t,group.SelectedTab,compare);
verifyEmpty(t,findobj(fig,'Tag','DifferenceAxes'));
result=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyTrue(t,all(isfinite(result.deltaXYZ)));
verifyTrue(t,isnan(result.spectralRMS));
verifyEmpty(t,result.spectralComparisonKey);
verifySubstring(t,result.spectralReason,'does not report a spectrum');
end

function testReadingPageUsesStandaloneRowOrHostReservation(t)
[view,fig]=makeView(t);p=positions(650,400);view.layout(p);
page=colormeasuretest.field(fig,'ReadingPage');
verifyEqual(t,page.Position,[p.table(1) p.table(2)+p.table(4)+5 p.table(3) 20]);
p.pageLabel=[500 210 150 20];view.layout(p);
verifyEqual(t,page.Position,p.pageLabel);
end

function testMixedQuantityLabelsAndDetailsFollowTheSelectedReading(t)
[view,fig]=makeView(t);m=readings(2); d=colormeasure.drivers.pr.viewData(m);
d.spectralLabels={'Radiance (provisional per nm)';'Irradiance (provisional per nm)'};
d.spectralUnitsByReading={'W/(m^2 sr nm), provisional';'W/(m^2 nm), provisional'};
d.xyzSources={'Host spectrum integration';'Instrument XYZ'};
d.xyzUnitsByReading={'provisional photometric scale';'instrument scale'};
d.observerNames={'CIE 1931 2-degree observer';'Observer not confirmed'};
d.observerIds={'CIE1931_2deg';''};
view.update(m,d,positions(650,400));
verifySubstring(t,colormeasuretest.field(fig,'SpectrumAxes').YLabel.String,'Mixed quantities');
copy=colormeasuretest.field(fig,'CopyReadingDetails');
verifySubstring(t,copy.UserData,'XYZ source: Instrument XYZ');
verifySubstring(t,copy.UserData,'XYZ units: instrument scale');
verifySubstring(t,copy.UserData,'Observer: Observer not confirmed');
mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=2;colormeasuretest.click(mode);
verifyEqual(t,colormeasuretest.field(fig,'SpectrumAxes').YLabel.String,d.spectralLabels{2});
point=readingGraphic(fig,'ReadingChromaticity',1);cb=point.ButtonDownFcn;cb(point,[]);
verifyEqual(t,colormeasuretest.field(fig,'SpectrumAxes').YLabel.String,d.spectralLabels{1});
verifySubstring(t,copy.UserData,'XYZ source: Host spectrum integration');
verifySubstring(t,copy.UserData,d.spectralUnitsByReading{1});
verifyEqual(t,height(colormeasuretest.field(fig,'ResultsTable').StyleConfigurations),1);
end

function testUndefinedAndExtremeInputDoesNotCorruptRecord(t)
XYZ = [0 0 0; -1 2 3; NaN 1 1; Inf 1 1; 1+1i 2 3; ...
    realmax*[1 1 1]; realmin*[1 1 1]];

[uv,valid] = colormeasure.analysis.chromaticity(XYZ);
verifyEqual(t,valid,[false(5,1);true(2,1)]);
verifyTrue(t,all(all(isnan(uv(1:5,:)))));
verifyEqual(t,uv(6:7,:),repmat([4/19 9/19],2,1),'AbsTol',1e-14);

verifyError(t,@() colormeasure.analysis.chromaticity([1 2]),'MATLAB:chromaticity:incorrectNumcols');
end

function testDisplayGuardKeepsSignedAndBlackRowsUnavailableInBothModes(t)
XYZ=[0 0 0;-1 2 3;1 1 1];
for mode={'xy','uv'}
    [coordinates,valid]=colormeasure.analysis.chromaticity(XYZ,mode{1});
    verifyEqual(t,valid,[false;false;true]);
    verifyTrue(t,all(isnan(coordinates(1:2,:)),'all'));
    verifyTrue(t,all(isfinite(coordinates(3,:))));
end

% Exactly three valid rows use the documented row-sample convention.
[coordinates,valid]=colormeasure.analysis.chromaticity(eye(3),'xy');
verifyTrue(t,all(valid));verifyEqual(t,coordinates,[1 0;0 1;0 0]);
end

function testBothPlotsStayVisibleAndIdentityUsesIndex(t)
[view,fig] = makeView(t); m = readings(3); m(3).XYZ = [0 0 0];
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340)); drawnow;
verifyEqual(t,numel(findobj(fig,'Type','axes')),2);
verifyEqual(t,char(get(colormeasuretest.field(fig,'SpectrumAxes'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'ChromaticityAxes'),'Visible')),'on');
tableData = get(colormeasuretest.field(fig,'ResultsTable'),'Data');
verifySize(t,tableData,[3 11]); verifyEqual(t,tableData(:,3),{'Duplicate';'Duplicate';'Duplicate'});
verifyEqual(t,tableData(3,9:10),{'Unavailable','Unavailable'});
for index = 1:3
    spectrum = readingGraphic(fig,'ReadingSpectrum',index);
    point = readingGraphic(fig,'ReadingChromaticity',index);
    verifyEqual(t,get(spectrum,'Color'),get(point,'Color'));
    verifyEqual(t,get(spectrum,'UserData'),index);
end

verifyTrue(t,isnan(get(readingGraphic(fig,'ReadingChromaticity',3),'XData')));
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'DataAspectRatio'),[1 1 1]);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[0 .7]);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'YLim'),[0 .6]);
end

function testNotesAndModeUseRetainedRowsWithBoundedWidths(t)
[view,fig]=makeView(t);m=readings(2);m(1).notes=sprintf('first line\nsecond line');
d=colormeasure.drivers.pr.viewData(m);d.measurementModes={'First captured mode';'Second captured mode'};
p=positions(650,400);p.table(3)=636;view.update(m,d,p);
control=colormeasuretest.field(fig,'ResultsTable');headers=containers.Map();
listener=addlistener(control,'Data','PostSet',@(~,~)captureTableHeaders(control,headers));
t.addTeardown(@()delete(listener));
p.table(3)=1400;view.update(m,d,p);
observed=headers('columns');verifyEqual(t,observed(3:5),{'Sample';'Notes';'Mode'}, ...
    'The new headings must be published when native Data commits the expanded schema.');
verifyEqual(t,control.ColumnName(3:5),{'Sample';'Notes';'Mode'});
verifyEqual(t,control.Data{1,4},'first line second line');
verifyEqual(t,control.Data(:,5),d.measurementModes);
verifyLessThanOrEqual(t,control.ColumnWidth{3},220);
heading=uicontrol(fig,'Style','text','String',control.ColumnName{end}, ...
    'FontName',control.FontName,'FontSize',control.FontSize,'FontWeight','bold','Visible','off');
verifyGreaterThanOrEqual(t,control.ColumnWidth{end},ceil(heading.Extent(3))+12, ...
    'The duration heading needs room for its text and cell padding.');delete(heading);
callback=control.CellSelectionCallback;callback(control,struct('Indices',[1 3]));
verifySubstring(t,colormeasuretest.field(fig,'CopyReadingDetails').UserData,'First captured mode');
mode=colormeasuretest.field(fig,'CoordinateMode');mode.Value=2;colormeasuretest.click(mode);
verifyEqual(t,control.Data(:,strcmp(control.ColumnName,'Mode')),d.measurementModes);
p.table(3)=636;view.layout(p);
heading=uicontrol(fig,'Style','text','String',control.ColumnName{3}, ...
    'FontName',control.FontName,'FontSize',control.FontSize,'FontWeight','bold','Visible','off');
verifyGreaterThanOrEqual(t,control.ColumnWidth{3},ceil(heading.Extent(3))+12);delete(heading);
verifySubstring(t,control.Tooltip,'approximate sRGB');
verifyLessThanOrEqual(t,sum(cell2mat(control.ColumnWidth))+18,p.table(3), ...
    'The supported compact window must fit the numeric columns without horizontal scrolling.');
p.table(3)=630;view.layout(p);
verifyFalse(t,ismember('Notes',control.ColumnName));
verifyEqual(t,control.Data(:,strcmp(control.ColumnName,'Mode')),d.measurementModes);
verifyEqual(t,colormeasuretest.field(fig,'ReadingDetails').Value,{'first line';'second line'});
end

function testAnnotationRefreshPreservesSelectionZoomAndRefreshesLabels(t)
[view,fig]=makeView(t);m=readings(2);d=syntheticComparisonData(m);
view.update(m,d,positions(650,400));table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3]));
axes=colormeasuretest.field(fig,'SpectrumAxes');axes.XLim=[450 600];
m(1).name='Corrected';m(1).notes='New note';view.update(m,d,positions(650,400));
verifyEqual(t,table.UserData,1);verifyEqual(t,axes.XLim,[450 600]);
verifyEqual(t,readingGraphic(fig,'ReadingSpectrum',1).DisplayName,'Corrected');
verifyEqual(t,colormeasuretest.field(fig,'ReadingDetails').Value,{'New note'});
verifySubstring(t,colormeasuretest.field(fig,'CopyReadingDetails').UserData,'Corrected');
end


function testAnnotationRefreshUpdatesAnalysisChoicesWithoutChangingIdentity(t)
fig=figure('Visible','off');t.addTeardown(@()delete(fig));
tabs=uitabgroup(fig);comparison=uitab(tabs);colour=uitab(tabs);
compare=colormeasure.ui.ComparisonView(comparison);t.addTeardown(@()colormeasuretest.dispose(compare));
color=colormeasure.ui.IlluminationView(colour,@(~)[]);t.addTeardown(@()colormeasuretest.dispose(color));
m=readings(2);d=syntheticComparisonData(m);
compare.update(m,d);compare.choosePair([1 2]);
white=colormeasuretest.field(fig,'CompareWhite');white.Value=1;white.ValueChangedFcn(white,[]);
before=colormeasuretest.field(fig,'ComparisonResults').UserData;
color.update(m,d,1);
m(1).name='Renamed white';compare.update(m,d);color.update(m,d,1);
for tag={'CompareReference','CompareSample','CompareWhite','IlluminationSample', ...
        'IlluminationReference','IlluminationSourceWhite','IlluminationDestinationWhite','IlluminationTarget'}
    field=colormeasuretest.field(fig,tag{1});
    verifyTrue(t,any(contains(field.Items,'Renamed white')),tag{1});
end
verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
verifyEqual(t,colormeasuretest.field(fig,'CompareSample').Value,2);verifyEqual(t,white.Value,1);
after=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyEqual(t,after.deltaXYZ,before.deltaXYZ);verifyEqual(t,after.deltaE00,before.deltaE00);
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'Renamed white');
verifyEqual(t,colormeasuretest.field(fig,'IlluminationSample').Value,1);
end
function testTableSpectrumAndPointSelectTheSameUnmodifiedRecord(t)
[view,fig] = makeView(t); m = readings(3);
view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
point = readingGraphic(fig,'ReadingChromaticity',2); callback = get(point,'ButtonDownFcn'); callback(point,[]);
assertSelected(t,fig,2);
spectrum = readingGraphic(fig,'ReadingSpectrum',1); callback = get(spectrum,'ButtonDownFcn'); callback(spectrum,[]);
assertSelected(t,fig,1);
control = colormeasuretest.field(fig,'ResultsTable'); callback = get(control,'CellSelectionCallback');
callback(control,struct('Indices',[3 2])); assertSelected(t,fig,3);
details = colormeasuretest.field(fig,'CopyReadingDetails').UserData;
verifyTrue(t,contains(details,'Notes: Note 3'));
verifyTrue(t,contains(details,'Duration: 3 s'));
end

function testSelectionAndZoomSurviveAppendAndResize(t)
[view,fig] = makeView(t); m = readings(2); view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
control = colormeasuretest.field(fig,'ResultsTable'); callback = get(control,'CellSelectionCallback');
callback(control,struct('Indices',[2 2]));
set(colormeasuretest.field(fig,'SpectrumAxes'),'XLim',[450 600],'YLim',[0 .3]);
set(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim',[.15 .3],'YLim',[.4 .55]);
oldLine = readingGraphic(fig,'ReadingSpectrum',2);
detail=colormeasuretest.field(fig,'ReadingDetails'); scroll(detail,'bottom');
detailValue=detail.Value;
m = readings(3); view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
verifyEqual(t,readingGraphic(fig,'ReadingSpectrum',2),oldLine);
verifyEqual(t,detail.Value,detailValue);
view.layout(positions(610,340)); drawnow;
assertSelected(t,fig,2);
verifyEqual(t,detail.Value,detailValue);
verifyEqual(t,get(colormeasuretest.field(fig,'SpectrumAxes'),'XLim'),[450 600]);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[.15 .3]);
colormeasuretest.click(colormeasuretest.field(fig,'ResetView'));
verifyEqual(t,get(colormeasuretest.field(fig,'SpectrumAxes'),'XLimMode'),'auto');
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[0 .7]);
end

function testCoordinateChoiceUpdatesPointsAndTableWithSeparateZoom(t)
[view,fig] = makeView(t); m = readings(1); m.XYZ = [1 1 1];
view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
set(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim',[.1 .3]);
control = colormeasuretest.field(fig,'CoordinateMode'); set(control,'Value',2); colormeasuretest.click(control);
tableData = get(colormeasuretest.field(fig,'ResultsTable'),'Data');
verifyEqual(t,cell2mat(tableData(:,9:10)),[1/3 1/3],'AbsTol',1e-14);
point = readingGraphic(fig,'ReadingChromaticity',1);
verifyEqual(t,[get(point,'XData') get(point,'YData')],[1/3 1/3],'AbsTol',1e-14);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[0 .8]);
set(control,'Value',1); colormeasuretest.click(control);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[.1 .3]);
assertSelected(t,fig,1);
end

function testXYZOnlyAndNoAdapterPresentationHaveHonestEmptyViews(t)
[view,fig] = makeView(t); m = struct('name','XYZ-only','notes','No spectrum','XYZ',[1 1 1]);
view.update(m,struct('XYZ',[1 1 1],'observer','Test observer'),positions(650,400));
verifyEmpty(t,findobj(fig,'Tag','ReadingSpectrum'));
verifyEqual(t,char(get(colormeasuretest.field(fig,'SpectrumUnavailable'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'ChromaticityUnavailable'),'Visible')),'off');
verifyEqual(t,get(colormeasuretest.field(fig,'ResultObserver'),'String'),'Test observer');
delete(view); view = colormeasure.ui.ResultsView(fig); t.addTeardown(@() colormeasuretest.dispose(view));
view.update(m,[],positions(650,400));
control=colormeasuretest.field(fig,'ResultsTable');data=control.Data;
verifyEqual(t,data{1,3},'XYZ-only');
numeric=ismember(string(control.ColumnName),["X","Y","Z","u'","v'"]);
verifyEqual(t,data(1,numeric),repmat({'Unavailable'},1,5));
verifyEqual(t,char(get(colormeasuretest.field(fig,'ChromaticityUnavailable'),'Visible')),'on');
end

function testFullNativeLocusFitsBothCoordinateViews(t)
[view,fig] = makeView(t); data = colormeasure.drivers.pr.viewData(struct([]));
[observer,wavelengths] = colormeasure.colorimetry.observer();
verifyEqual(t,data.locusXYZ,observer);
verifyEqual(t,[wavelengths(1) wavelengths(end)],[360 830]);
verifyEqual(t,unique(diff(wavelengths)),1);
% Published CIE 1931 2-degree value at 555 nm (CIE 018:2019 Table 6).
verifyEqual(t,observer(wavelengths==555,:),[.5120501 1 .005749999],'AbsTol',1e-8);
view.update(struct([]),data,positions(650,400));
for mode = 1:2
    control = colormeasuretest.field(fig,'CoordinateMode'); set(control,'Value',mode); colormeasuretest.click(control);
    ax = colormeasuretest.field(fig,'ChromaticityAxes'); locus = colormeasuretest.field(fig,'SpectralLocus');
    x = get(locus,'XData'); y = get(locus,'YData');
    verifyGreaterThanOrEqual(t,min(x),ax.XLim(1)); verifyLessThanOrEqual(t,max(x),ax.XLim(2));
    verifyGreaterThanOrEqual(t,min(y),ax.YLim(1)); verifyLessThanOrEqual(t,max(y),ax.YLim(2));
    boundary = colormeasuretest.field(fig,'PurpleBoundary');
    verifyEqual(t,get(boundary,'XData'),x([end 1]));
end
end

function testAxesTargetPlotPreservesParentControls(t)
fig = figure('Visible','off'); t.addTeardown(@() delete(fig));
button = uicontrol(fig,'String','Keep me'); ax = axes(fig);
m = readings(2); lines = colormeasure.drivers.pr.drawSpectrum(m,ax);
verifyTrue(t,isgraphics(button)); verifyNumElements(t,lines,2);
verifyEqual(t,ax.Title.String,'Measurement batch: 2 readings');
colormeasure.drivers.pr.drawSpectrum(m(1),ax);
verifyEqual(t,ax.Title.String,'Measurement batch: 1 reading');
fig = colormeasure.drivers.pr.plotBatch(m,fig); verifyTrue(t,isgraphics(button));
ax = colormeasuretest.field(fig,'PR655BatchSpectrum');
verifyNumElements(t,findobj(ax,'Type','line'),2);
colormeasure.drivers.pr.plotBatch(m,fig); verifyNumElements(t,findobj(fig,'Tag','PR655BatchSpectrum'),1);
end

function testTwelveReadingBatchRetainsEveryScrollableRow(t)
[view,fig]=makeView(t); m=readings(12);
p=positions(636,340); p.table(4)=180;
for count=1:12
    view.update(m(1:count),colormeasure.drivers.pr.viewData(m(1:count)),p);
    assertSelected(t,fig,count);
    data=get(colormeasuretest.field(fig,'ResultsTable'),'Data');
    verifyEqual(t,cell2mat(data(:,2)),(1:count)');
    verifyEqual(t,data{end,2},count);
end
verifyTrue(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));

verifyTrue(t,contains(get(colormeasuretest.field(fig,'ReadingPage'),'String'),'of 12'));
end

function testThirtyReadingRowsKeepStableIdsDuringInspection(t)
[view,fig]=makeView(t); m=readings(30); p=positions(636,340);
view.update(m,colormeasure.drivers.pr.viewData(m),p); assertSelected(t,fig,30);
control=colormeasuretest.field(fig,'ResultsTable'); data=get(control,'Data');
verifyEqual(t,cell2mat(data(:,2)),(1:30)');
callback=get(control,'CellSelectionCallback');
callback(control,struct('Indices',[12 3])); assertSelected(t,fig,12);
verifyFalse(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
point=readingGraphic(fig,'ReadingChromaticity',3);
callback=get(point,'ButtonDownFcn'); callback(point,[]); assertSelected(t,fig,3);
data=get(control,'Data'); verifyEqual(t,cell2mat(data(:,2)),(1:30)');
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading')); assertSelected(t,fig,30);
verifyTrue(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
end

function testHundredReadingInspectionStaysInFrontAndLatestResumes(t)
[view,fig]=makeView(t); m=readings(100); p=positions(636,340);
view.update(m(1:30),colormeasure.drivers.pr.viewData(m(1:30)),p);
point=readingGraphic(fig,'ReadingChromaticity',3);
callback=get(point,'ButtonDownFcn'); callback(point,[]);
set(colormeasuretest.field(fig,'SpectrumAxes'),'XLim',[450 600],'YLim',[0 .3]);
set(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim',[.15 .3],'YLim',[.4 .55]);
view.update(m,colormeasure.drivers.pr.viewData(m),p); assertSelected(t,fig,3);
verifyEqual(t,numel(findobj(fig,'Tag','ReadingSpectrum')),100);
verifyEqual(t,numel(findobj(fig,'Tag','ReadingChromaticity')),100);
children=get(colormeasuretest.field(fig,'SpectrumAxes'),'Children');
verifyEqual(t,children(1),readingGraphic(fig,'ReadingSpectrum',3));
children=get(colormeasuretest.field(fig,'ChromaticityAxes'),'Children'); verifyEqual(t,children(1),point);
verifyEqual(t,get(colormeasuretest.field(fig,'SpectrumAxes'),'XLim'),[450 600]);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[.15 .3]);
p.table(4)=250; view.layout(p); assertSelected(t,fig,3);
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading')); assertSelected(t,fig,100);
verifyEqual(t,get(colormeasuretest.field(fig,'SpectrumAxes'),'XLim'),[450 600]);
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'XLim'),[.15 .3]);
end

function testSpectrumFilterPreservesAllReadingsAndChromaticities(t)
[view,fig]=makeView(t); m=readings(12);
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
control=colormeasuretest.field(fig,'SpectraMode'); set(control,'Value',2); colormeasuretest.click(control);
verifyNumElements(t,findobj(fig,'Tag','ReadingSpectrum','Visible','on'),1);
verifyEqual(t,get(findobj(fig,'Tag','ReadingSpectrum','Visible','on'),'UserData'),12);
verifyNumElements(t,findobj(fig,'Tag','ReadingChromaticity','Visible','on'),12);
point=readingGraphic(fig,'ReadingChromaticity',2); callback=get(point,'ButtonDownFcn'); callback(point,[]);
verifyEqual(t,get(findobj(fig,'Tag','ReadingSpectrum','Visible','on'),'UserData'),2);
m=readings(30); view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
verifyEqual(t,get(findobj(fig,'Tag','ReadingSpectrum','Visible','on'),'UserData'),2);
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading'));
verifyEqual(t,get(findobj(fig,'Tag','ReadingSpectrum','Visible','on'),'UserData'),30);
set(control,'Value',1); colormeasuretest.click(control);
verifyNumElements(t,findobj(fig,'Tag','ReadingSpectrum','Visible','on'),30);
end

function testTableTogglePreservesPlotsDetailsAndAllRows(t)
[view,fig]=makeView(t); m=readings(30); p=positions(636,340);
view.update(m,colormeasure.drivers.pr.viewData(m),p);
control=colormeasuretest.field(fig,'ResultsTable'); callback=get(control,'CellSelectionCallback');
callback(control,struct('Indices',[4 3]));
data=get(colormeasuretest.field(fig,'ResultsTable'),'Data');
view.showTable(false);
verifyEqual(t,char(get(colormeasuretest.field(fig,'ResultsTablePanel'),'Visible')),'off');
verifyEqual(t,char(get(colormeasuretest.field(fig,'SpectrumAxes'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'ChromaticityAxes'),'Visible')),'on');
verifyEqual(t,char(get(colormeasuretest.field(fig,'ReadingDetails'),'Visible')),'on');
view.showTable(true);
verifyEqual(t,get(colormeasuretest.field(fig,'ResultsTable'),'Data'),data);
verifyFalse(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
end

function testPendingTableSelectionUsesDisplayedRecordIds(t)
[view,fig]=makeView(t); m=readings(11); p=positions(636,340);
view.update(m(1:10),colormeasure.drivers.pr.viewData(m(1:10)),p);
control=colormeasuretest.field(fig,'ResultsTable'); oldData=get(control,'Data');
callback=get(control,'CellSelectionCallback'); clickedId=oldData{1,2};
view.update(m,colormeasure.drivers.pr.viewData(m),p);
verifyNotEqual(t,get(control,'Data'),oldData);
callback(control,struct('Indices',[1 3])); assertSelected(t,fig,clickedId);
verifyFalse(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
end

function testSelectedReadingWithoutSpectrumHasExplicitPlaceholder(t)
[view,fig]=makeView(t); m=readings(2); data=colormeasure.drivers.pr.viewData(m);
data.spectra{2}=[]; view.update(m,data,positions(636,340));
control=colormeasuretest.field(fig,'SpectraMode'); set(control,'Value',2); colormeasuretest.click(control);
verifyEmpty(t,findobj(fig,'Tag','ReadingSpectrum','Visible','on'));
verifyEqual(t,char(get(colormeasuretest.field(fig,'SpectrumUnavailable'),'Visible')),'on');
verifyEqual(t,get(colormeasuretest.field(fig,'SpectrumUnavailable'),'Text'),'No spectrum for this reading');
set(control,'Value',1); colormeasuretest.click(control);
verifyNumElements(t,findobj(fig,'Tag','ReadingSpectrum','Visible','on'),1);
verifyEqual(t,char(get(colormeasuretest.field(fig,'SpectrumUnavailable'),'Visible')),'off');
end

function testUnchangedLayoutKeepsNativeTableCallbackAndDetails(t)
[view,fig]=makeView(t); m=readings(30); p=positions(636,340);
view.update(m,colormeasure.drivers.pr.viewData(m),p);
control=colormeasuretest.field(fig,'ResultsTable'); callback=get(control,'CellSelectionCallback');
detail=colormeasuretest.field(fig,'ReadingDetails'); scroll(detail,'bottom');
detailValue=detail.Value;
view.layout(p);
verifyEqual(t,get(control,'CellSelectionCallback'),callback);
verifyEqual(t,detail.Value,detailValue);
end

function testResizeAndAppendNeverRemoveScrollableRows(t)
[view,fig]=makeView(t); m=readings(100); p=positions(636,340);
view.update(m(1:12),colormeasure.drivers.pr.viewData(m(1:12)),p);
control=colormeasuretest.field(fig,'ResultsTable'); callback=get(control,'CellSelectionCallback');
callback(control,struct('Indices',[4 3]));
p.table(4)=120; view.layout(p); data=get(control,'Data');
verifyEqual(t,cell2mat(data(:,2)),(1:12)');
view.update(m,colormeasure.drivers.pr.viewData(m),p); data=get(control,'Data');
verifyEqual(t,cell2mat(data(:,2)),(1:100)'); assertSelected(t,fig,4);
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading')); assertSelected(t,fig,100);
end

function testNativeSelectionFollowsReadingIdentityAndClickedColumn(t)
[view,fig]=makeView(t); control=colormeasuretest.field(fig,'ResultsTable');
m=readings(17); p=positions(636,340); p.table(4)=271;
view.update(m(1:16),colormeasure.drivers.pr.viewData(m(1:16)),p);
set(control,'Selection',[2 5]); callback=get(control,'CellSelectionCallback');
callback(control,struct('Indices',[2 5])); assertSelected(t,fig,2);
verifyEqual(t,get(control,'Selection'),[2 5]);
view.update(m,colormeasure.drivers.pr.viewData(m),p);
verifyEqual(t,get(control,'Selection'),[2 5]);
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading')); assertSelected(t,fig,17);
verifyEqual(t,get(control,'Selection'),[17 5]);
verifyTrue(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
% Programmatic focus synchronization must not dispatch the inspection callback.
drawnow;
verifyTrue(t,get(colormeasuretest.field(fig,'LatestReading'),'UserData'));
data=get(control,'Data'); verifyEqual(t,cell2mat(data(:,2)),(1:17)');
end

function testNarrowTableKeepsReadableColumnsAndSelectedData(t)
[view,fig]=makeView(t);m=readings(12);p=positions(636,340);
view.update(m,colormeasure.drivers.pr.viewData(m),p);
control=colormeasuretest.field(fig,'ResultsTable');set(control,'Selection',[4 3]);
callback=control.CellSelectionCallback;callback(control,struct('Indices',[4 3]));
before=control.Data;
for width=[400 1400 500]
    p.table(3)=width;view.layout(p);
    columns=cell2mat(control.ColumnWidth);
    verifyGreaterThanOrEqual(t,columns(3),120);
    numeric=ismember(string(control.ColumnName),["X","Y","Z","u'","v'","x","y"]);
    verifyGreaterThanOrEqual(t,columns(numeric),50*ones(1,5));
    verifyLessThanOrEqual(t,columns(3),220);
    if width<600
        verifyGreaterThan(t,sum(columns),width); % Native horizontal scrolling.
    else
        verifyLessThanOrEqual(t,sum(columns)+18,width);
    end
    verifyEqual(t,control.Selection,[4 3]);
    verifyEqual(t,control.Data(:,3),before(:,3));
    verifyEqual(t,control.Data(:,strcmp(control.ColumnName,'X')),before(:,strcmp({'','','Sample','Notes','Mode','X','Y','Z',"u'","v'",'Duration'},'X')));
end
end

function testNativeKeyboardColumnAndPendingInputSurviveUnchangedLayout(t)
[view,fig]=makeView(t); control=colormeasuretest.field(fig,'ResultsTable');
m=readings(12); p=positions(636,340); view.update(m,colormeasure.drivers.pr.viewData(m),p);
% Model a native selection already painted before its callback is delivered.
set(control,'Selection',[2 7]); callback=get(control,'CellSelectionCallback');
view.layout(p); verifyEqual(t,get(control,'Selection'),[2 7]);
callback(control,struct('Indices',[2 7])); assertSelected(t,fig,2);
verifyEqual(t,get(control,'Selection'),[2 7]);
set(control,'Selection',[2 8]); callback=get(control,'CellSelectionCallback');
callback(control,struct('Indices',[2 8]));
verifyEqual(t,get(control,'Selection'),[2 8]);
point=readingGraphic(fig,'ReadingChromaticity',3);
callback=get(point,'ButtonDownFcn'); callback(point,[]); assertSelected(t,fig,3);
data=get(control,'Data'); row=find(cell2mat(data(:,2))==3,1);
verifyEqual(t,get(control,'Selection'),[row 8]);
end

function testApproximateBackgroundTracksModeWithoutChangingReadings(t)
[view,fig]=makeView(t); m=readings(12);
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
background=colormeasuretest.field(fig,'ChromaticityBackground');
verifyEqual(t,char(get(background,'HitTest')),'off');
verifyEqual(t,get(background,'PickableParts'),'none');
verifyEqual(t,get(colormeasuretest.field(fig,'ChromaticityAxes'),'YDir'),'normal');
alpha=get(background,'AlphaData'); verifyGreaterThan(t,nnz(alpha),1000);
verifyLessThan(t,max(alpha(:)),.5);
children=get(colormeasuretest.field(fig,'ChromaticityAxes'),'Children');
verifyEqual(t,children(end),background);
set(colormeasuretest.field(fig,'CoordinateMode'),'Value',2); colormeasuretest.click(colormeasuretest.field(fig,'CoordinateMode'));
verifyEqual(t,get(background,'XData'),[0 .8]);
verifyEqual(t,get(background,'YData'),[0 .9]);
verifyNotEqual(t,get(background,'AlphaData'),alpha);
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
verifyEqual(t,colormeasuretest.field(fig,'ChromaticityBackground'),background);
end

function testBackgroundWithoutObserverBoundaryStaysTransparent(t)
[view,fig]=makeView(t); m=readings(1);
view.update(m,struct('XYZ',m.XYZ),positions(636,340));
alpha=get(colormeasuretest.field(fig,'ChromaticityBackground'),'AlphaData');
verifyFalse(t,any(alpha(:)));
verifyEqual(t,char(get(colormeasuretest.field(fig,'ChromaticityColorNote'),'Visible')),'off');
end

function testNativeDetailsKeepTextAcrossResizeAndInspectionUpdates(t)
[view,fig]=makeView(t); m=readings(3);
m(2).notes=sprintf('First paragraph\n\n%s',repmat('Long path/ ',1,70));
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
point=readingGraphic(fig,'ReadingChromaticity',2); cb=point.ButtonDownFcn; cb(point,[]);
detail=colormeasuretest.field(fig,'ReadingDetails');
verifyEqual(t,char(detail.Editable),'off'); verifyEqual(t,char(detail.WordWrap),'on');
verifyTrue(t,contains(strjoin(detail.Value,newline),m(2).notes));
before=detail.Value;
scroll(detail,'bottom');
view.layout(positions(620,400));
view.update(m,colormeasure.drivers.pr.viewData(m),positions(620,400));
verifyEqual(t,detail.Value,before);
point=readingGraphic(fig,'ReadingChromaticity',1); cb=point.ButtonDownFcn; cb(point,[]);
verifyNotEqual(t,detail.Value,before);
verifyEqual(t,detail.UserData,1);
end

function testReadingSummaryKeepsUsefulContextAndLeavesRawDataIntact(t)
[view,fig]=makeView(t); m=readings(1);
m.notes=sprintf('Reference sample\nSecond position');
m.completedAtUTC='2026-09-16T08:16:29.812Z';
m.durationSeconds=.030898; m.deviceType='PR-655';
m.port='RAW_PORT_VALUE'; m.matlabVersion='RAW_VERSION_VALUE';
m.unitsCode=0; m.integratedPhotonRadiance=NaN;
m.rawDiagnostic='RAW_DIAGNOSTIC_VALUE'; m.isSynthetic=true;
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
text=colormeasuretest.field(fig,'CopyReadingDetails').UserData;
verifyTrue(t,contains(text,m.notes));
verifyTrue(t,contains(text,'XYZ: 1, 2, 3'));
verifyTrue(t,contains(text,'Duration: 0.0309 s'));
verifyTrue(t,contains(text,['Completed: ' colormeasure.session.displayTime(m.completedAtUTC)]));
verifyTrue(t,contains(text,'Instrument: PR-655'));
verifyTrue(t,contains(text,'Source: Synthetic demo'));
verifyTrue(t,contains(text,'CIE 1931 2-degree observer'));
% Known sentinel fields prove the complete record is not dumped to the view.
verifyFalse(t,any(contains(text,{'RAW_PORT_VALUE','RAW_VERSION_VALUE', ...
    'RAW_DIAGNOSTIC_VALUE','unitsCode','integratedPhotonRadiance','NaN'})));

copy=colormeasuretest.field(fig,'CopyReadingDetails');
verifyEqual(t,char(copy.Enable),'on'); verifyEqual(t,copy.UserData,text);
end

function testCopiedSummaryTracksSelectionAndCoordinateMode(t)
[view,fig]=makeView(t); m=readings(2);
view.update(m,colormeasure.drivers.pr.viewData(m),positions(636,340));
copy=colormeasuretest.field(fig,'CopyReadingDetails'); uv=copy.UserData;
verifyTrue(t,contains(uv,'Reading 2: Duplicate'));
verifyTrue(t,contains(uv,'u'' = '));
mode=colormeasuretest.field(fig,'CoordinateMode'); mode.Value=2; colormeasuretest.click(mode);
verifyTrue(t,contains(copy.UserData,'x = '));
verifyFalse(t,contains(copy.UserData,'u'' = '));
verifyTrue(t,contains(copy.UserData,strjoin(colormeasuretest.field(fig,'ReadingDetails').Value,newline)));
verifyNotEmpty(t,colormeasuretest.field(fig,'ReadingProperties').Data);
point=readingGraphic(fig,'ReadingChromaticity',1); cb=point.ButtonDownFcn; cb(point,[]);
verifyTrue(t,contains(copy.UserData,'Reading 1: Duplicate'));
verifyTrue(t,contains(copy.UserData,'Note 1'));
view.update(struct([]),struct(),positions(636,340));
verifyEqual(t,char(copy.Enable),'off'); verifyEmpty(t,copy.UserData);
verifyFalse(t,contains(strjoin(colormeasuretest.field(fig,'ReadingDetails').Value),'Note 1'));
end

function testPairSelectionUsesStableIdsAndKeepsWhiteExplicit(t)
fig=figure('Visible','off','Position',[20 20 1120 760]);t.addTeardown(@() delete(fig));
group=uitabgroup(fig,'Position',[0 0 .28 1]);
reading=uitab(group,'Title','Reading');compare=uitab(group,'Title','Compare');
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(3);data=syntheticComparisonData(m);
data.spectralUnits='test units';
view.update(m,data,positions(650,400));
table=colormeasuretest.field(fig,'ResultsTable');cb=table.CellSelectionCallback;
cb(table,struct('Indices',[1 3;2 3]));
verifyEqual(t,table.Selection,[1 3;2 3]);
verifyEqual(t,group.SelectedTab,compare);
verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
verifyEqual(t,colormeasuretest.field(fig,'CompareSample').Value,2);
verifyEqual(t,colormeasuretest.field(fig,'CompareWhite').Value,0);
verifyEqual(t,colormeasuretest.field(fig,'CompareWhiteY').Value,100);
result=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyTrue(t,isnan(result.deltaE00));verifyTrue(t,isfinite(result.spectralRMS));
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'test units');
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'400–700 nm');
white=colormeasuretest.field(fig,'CompareWhite');white.Value=3;cb=white.ValueChangedFcn;cb(white,[]);
result=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyTrue(t,isfinite(result.deltaE00));
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'Lab white: #3');
m=readings(4);data=syntheticComparisonData(m);
view.update(m,data,positions(650,400));
verifyEqual(t,table.Selection,[1 3;2 3]);
verifyEqual(t,colormeasuretest.field(fig,'CompareWhite').Value,3);
verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
verifyEqual(t,height(table.StyleConfigurations),4);
end

function testIlluminantSelectionAndWhiteYSurviveAppend(t)
fig=figure('Visible','off','Position',[20 20 960 650]);t.addTeardown(@() delete(fig));
group=uitabgroup(fig,'Position',[0 0 .28 .52]);tab=uitab(group);
v=colormeasure.ui.ComparisonView(tab);t.addTeardown(@() colormeasuretest.dispose(v));
m=readings(3);d=syntheticComparisonData(m);
v.update(m,d);v.choosePair([1 2]);
v.choosePair([0 0]);v.choosePair([1 NaN]);
verifyEqual(t,colormeasuretest.field(fig,'CompareReference').Value,1);
verifyEqual(t,colormeasuretest.field(fig,'CompareSample').Value,2);
w=colormeasuretest.field(fig,'CompareWhite');Y=colormeasuretest.field(fig,'CompareWhiteY');
verifyEqual(t,char(Y.Visible),'off');verifyEqual(t,Y.Value,100);
w.Value=-2;cb=w.ValueChangedFcn;cb(w,[]);
verifyEqual(t,char(Y.Visible),'on');
drawnow;drawnow;drawnow;
metrics=colormeasuretest.field(fig,'ComparisonResults');box=getpixelposition(metrics,true);
% Keep a header plus the two primary metric rows visible in a compact tab.
verifyGreaterThanOrEqual(t,box(4),3*(metrics.FontSize+12));
r=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyTrue(t,isfinite(r.deltaE00));
verifyTrue(t,isfinite(r.spectralRMS));
verifyEqual(t,r.whiteReference.Y,100);verifyEqual(t,r.whiteXYZ(2),100);
verifyEqual(t,r.deltaXYZ,d.XYZ(2,:)-d.XYZ(1,:));
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'White Y: 100');
Y.Value=203;cb=Y.ValueChangedFcn;cb(Y,[]);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyTrue(t,isfinite(r.deltaE00));
verifyEqual(t,r.whiteReference.illuminant,'D65');
copy=colormeasuretest.field(fig,'CopyComparison');verifySubstring(t,copy.UserData,'White Y: 203');
verifySubstring(t,copy.UserData,'White source: CIE');
m=readings(4);d=syntheticComparisonData(m);v.update(m,d);
verifyEqual(t,w.Value,-2);verifyEqual(t,Y.Value,203);
verifyEqual(t,colormeasuretest.field(fig,'ComparisonResults').UserData.whiteXYZ(2),203);
w.Value=3;cb=w.ValueChangedFcn;cb(w,[]);
verifyEqual(t,char(Y.Visible),'off');
r=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyEqual(t,r.whiteIndex,3);verifyEqual(t,r.whiteXYZ,d.XYZ(3,:));
w.Value=-1;cb(w,[]);verifyEqual(t,Y.Value,203);
verifyEqual(t,colormeasuretest.field(fig,'ComparisonResults').UserData.whiteReference.illuminant,'D50');
end

function testPairSpectraAndSignedDifferenceTrackChoices(t)
fig=figure('Visible','off','Position',[20 20 960 650]);t.addTeardown(@() delete(fig));
group=uitabgroup(fig,'Position',[0 0 .28 .52]);
reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(48); data=syntheticComparisonData(m);
view.update(m,data,positions(636,336));
set(colormeasuretest.field(fig,'SpectrumAxes'),'XLim',[450 600]);
table=colormeasuretest.field(fig,'ResultsTable');cb=table.CellSelectionCallback;
cb(table,struct('Indices',[45 3;46 3]));
verifyEqual(t,colormeasuretest.field(fig,'SpectraMode').Value,3);
verifyEqual(t,colormeasuretest.field(fig,'SpectrumAxes').XLim,[450 600]);
visible=findobj(fig,'Tag','ReadingSpectrum','Visible','on');
verifyEqual(t,sort(cell2mat(get(visible,'UserData'))),[45;46]);
line=colormeasuretest.field(fig,'SpectralDifference');
verifyEqual(t,line.XData,m(45).lambda');
verifyEqual(t,line.YData,(m(46).radiance-m(45).radiance)');
verifyEqual(t,char(colormeasuretest.field(fig,'ChromaticityAxes').Visible),'on');
set(colormeasuretest.field(fig,'SpectrumAxes'),'XLim',[450 600]);drawnow;
verifyEqual(t,colormeasuretest.field(fig,'DifferenceAxes').XLim,[450 600]);
sample=colormeasuretest.field(fig,'CompareSample');sample.Value=47;cb=sample.ValueChangedFcn;cb(sample,[]);
verifyEqual(t,line.YData,(m(47).radiance-m(45).radiance)');
verifyEqual(t,colormeasuretest.field(fig,'SpectrumAxes').XLim,[450 600]);
mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=1;colormeasuretest.click(mode);
verifyEqual(t,char(colormeasuretest.field(fig,'DifferenceAxes').Visible),'off');
verifyNumElements(t,findobj(fig,'Tag','ReadingSpectrum','Visible','on'),48);
% An explicit two-row selection reopens its pair even after an All override.
cb=table.CellSelectionCallback;cb(table,struct('Indices',[45 3;47 3]));
verifyEqual(t,mode.Value,3);
verifyEqual(t,char(colormeasuretest.field(fig,'DifferenceAxes').Visible),'on');
end

function testComparisonHighlightsBothPointsAndRetiresOldPair(t)
fig=figure('Visible','off');t.addTeardown(@() delete(fig));
group=uitabgroup(fig);reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(4);view.update(m,syntheticComparisonData(m));
table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3;3 3]));
verifyPointSelection(t,fig,4,[1 3]);
point=readingGraphic(fig,'ReadingChromaticity',4);point.ButtonDownFcn(point,[]);
verifyEqual(t,table.UserData,4);verifyPointSelection(t,fig,4,[1 3]);
sample=colormeasuretest.field(fig,'CompareSample');
sample.Value=2;sample.ValueChangedFcn(sample,[]);
verifyPointSelection(t,fig,4,[1 2]);
m=readings(5);view.update(m,syntheticComparisonData(m));
verifyEqual(t,table.UserData,4);verifyPointSelection(t,fig,5,[1 2]);
mode=colormeasuretest.field(fig,'CoordinateMode');mode.Value=2;colormeasuretest.click(mode);
verifyPointSelection(t,fig,5,[1 2]);
xy=colormeasure.analysis.chromaticity(m(1).XYZ,'xy');
verifyEqual(t,readingGraphic(fig,'ReadingChromaticity',1).XData,xy(1),'AbsTol',1e-14);
view.showContext('MeasureTab');verifyPointSelection(t,fig,5,4);
view.showContext('CompareTab');verifyPointSelection(t,fig,5,[1 2]);
mode=colormeasuretest.field(fig,'SpectraMode');mode.Value=1;colormeasuretest.click(mode);
verifyPointSelection(t,fig,5,4);
view.showContext('CompareTab');
reference=colormeasuretest.field(fig,'CompareReference');
reference.Value=2;reference.ValueChangedFcn(reference,[]);
verifyPointSelection(t,fig,5,2);
end

function testXYZOnlyComparisonHighlightsPairWithoutSpectralControls(t)
fig=figure('Visible','off');t.addTeardown(@() delete(fig));
group=uitabgroup(fig);reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(3);d=syntheticComparisonData(m);d.hasSpectra=false;d.spectra={[];[];[]};
view.update(m,d);table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3;2 3]));
view.showContext('CompareTab');verifyPointSelection(t,fig,3,[1 2]);
reference=colormeasuretest.field(fig,'CompareReference');
reference.Value=3;reference.ValueChangedFcn(reference,[]);
verifyPointSelection(t,fig,3,[2 3]);
verifyEqual(t,colormeasuretest.field(fig,'SpectraMode').Enable,'off');
verifyEmpty(t,findobj(fig,'Tag','DifferenceAxes'));
view.showContext('MeasureTab');verifyPointSelection(t,fig,3,2);
view.showContext('CompareTab');verifyPointSelection(t,fig,3,[2 3]);
view.showContext('ColorTab');verifyPointSelection(t,fig,3,2);
end

function verifyPointSelection(t,fig,count,selected)
for index=1:count
    point=readingGraphic(fig,'ReadingChromaticity',index);
    chosen=any(index==selected);
    verifyEqual(t,point.MarkerSize,5+4*chosen);
    verifyEqual(t,point.LineWidth,1+chosen);
end
end

function testDefaultWhiteYIsEditableClearableAndHighLightnessIsVisible(t)
fig=figure('Visible','off');t.addTeardown(@() delete(fig));
v=colormeasure.ui.ComparisonView(fig);t.addTeardown(@() colormeasuretest.dispose(v));
m=readings(2);m(2).XYZ=[180 200 210];d=syntheticComparisonData(m);
v.update(m,d);v.choosePair([1 2]);
w=colormeasuretest.field(fig,'CompareWhite');w.Value=-2;cb=w.ValueChangedFcn;cb(w,[]);
Y=colormeasuretest.field(fig,'CompareWhiteY');verifyEqual(t,Y.Value,100);cb=Y.ValueChangedFcn;
verifyEqual(t,Y.Limits,[0 Inf]);verifyEqual(t,char(Y.LowerLimitInclusive),'off');
r=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyGreaterThan(t,r.Lab(2,1),100);
rows=colormeasuretest.field(fig,'ComparisonResults').Data;
verifyTrue(t,all(ismember({'L* (A)','L* (B)','a* (A)','b* (B)'},rows(:,1))));
verifySubstring(t,colormeasuretest.field(fig,'ComparisonAvailability').Text,'Sample Y exceeds white Y');
Y.Value=[];cb(Y,[]);r=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyTrue(t,isnan(r.deltaE00));verifyTrue(t,isfinite(r.spectralRMS));
verifyTrue(t,all(isnan(r.Lab),'all'));
verifySubstring(t,colormeasuretest.field(fig,'ComparisonAvailability').Text,'Enter White Y');
v.update(m,d);verifyEmpty(t,Y.Value);
verifyTrue(t,isnan(colormeasuretest.field(fig,'ComparisonResults').UserData.deltaE00));
end

function testOperatorScaleConfirmationIsBoundToPairAndWhite(t)
fig=figure('Visible','off');t.addTeardown(@() delete(fig));
view=colormeasure.ui.ComparisonView(fig);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(3); d=colormeasure.drivers.pr.viewData(m);
d.xyzComparisonKeys={'';'';''};d.xyzScaleDeclarationKeys={'known';'known';'known'};
d.chromaticityComparisonKeys={'observer';'observer';'observer'};
d.spectralComparisonKeys={'spectrum';'spectrum';'spectrum'};
view.update(m,d);view.choosePair([1 2]);
white=colormeasuretest.field(fig,'CompareWhite');white.Value=3;cb=white.ValueChangedFcn;cb(white,[]);
confirmation=colormeasuretest.field(fig,'ConfirmXYZScale');
verifyEqual(t,char(confirmation.Visible),'on');verifyFalse(t,confirmation.Value);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyTrue(t,isnan(r.deltaE00));
confirmation.Value=true;cb=confirmation.ValueChangedFcn;cb(confirmation,[]);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyTrue(t,isfinite(r.deltaE00));verifyNotEmpty(t,r.scaleDeclaration);
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,'operator declared');
verifySubstring(t,colormeasuretest.field(fig,'CopyComparison').UserData,r.scaleDeclaration.declaredAtUTC);
view.update(m,d);r2=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyEqual(t,r2.scaleDeclaration,r.scaleDeclaration);
white.Value=-2;cb=white.ValueChangedFcn;cb(white,[]);
verifyFalse(t,confirmation.Value);
Y=colormeasuretest.field(fig,'CompareWhiteY');verifyEqual(t,Y.Value,100);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyTrue(t,isnan(r.deltaE00));verifyEmpty(t,r.scaleDeclaration);
verifyTrue(t,r.scaleDeclarationEligible);
confirmation.Value=true;cb=confirmation.ValueChangedFcn;cb(confirmation,[]);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;verifyTrue(t,isfinite(r.deltaE00));
verifyEqual(t,r.scaleDeclaration.white.Y,100);verifyEqual(t,r.whiteReference.Y,100);
Y.Value=50;cb=Y.ValueChangedFcn;cb(Y,[]);verifyFalse(t,confirmation.Value);
verifyEmpty(t,colormeasuretest.field(fig,'ComparisonResults').UserData.scaleDeclaration);
confirmation.Value=true;cb=confirmation.ValueChangedFcn;cb(confirmation,[]);
r=colormeasuretest.field(fig,'ComparisonResults').UserData;
verifyEqual(t,r.scaleDeclaration.white.Y,50);verifyEqual(t,r.whiteReference.Y,50);
view.choosePair([2 1]);verifyFalse(t,confirmation.Value);
end

function p=positions(width,height)
p=struct('plots',[308 244 width height], ...
    'table',[16 16 928 200],'details',[16 244 272 120]);
end

function [view,fig] = makeView(t)
fig = figure('Visible','off','Position',[20 20 1000 720]);
t.addTeardown(@() delete(fig)); view = colormeasure.ui.ResultsView(fig);
t.addTeardown(@() colormeasuretest.dispose(view));
end

function m = readings(count)
m = repmat(struct('name','Duplicate','notes','','XYZ',[1 1 1], ...
    'xyzMethod','colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1', ...
    'durationSeconds',0,'lambda',(400:20:700)','radiance',zeros(16,1)),count,1);
for index = 1:count
    m(index).notes = sprintf('Note %d',index); m(index).XYZ = [index index+1 index+2];
    m(index).durationSeconds = index;
    m(index).radiance = exp(-.5*((m(index).lambda-500-10*index)/30).^2);
end
end

function data = syntheticComparisonData(m)
% These UI-control fixtures deliberately share synthetic numerical conventions.
% They do not establish PR instrument units: eligibility/refusal is tested in
% testPR655ComparisonEligibility. Each calculation uses its explicitly
% declared numerical convention.
data = colormeasure.drivers.pr.viewData(m);
count = numel(m);
data.xyzComparisonKeys = repmat({'Synthetic UI fixture XYZ scale'},count,1);
data.chromaticityComparisonKeys = repmat({'Synthetic UI fixture chromaticity'},count,1);
data.spectralComparisonKeys = repmat({'Synthetic UI fixture spectral scale'},count,1);
end

function assertSelected(t,fig,index)
verifyEqual(t,get(colormeasuretest.field(fig,'ResultsTable'),'UserData'),index);
verifyEqual(t,get(colormeasuretest.field(fig,'ReadingDetails'),'UserData'),index);
verifyEqual(t,get(readingGraphic(fig,'ReadingSpectrum',index),'LineWidth'),2.6,'AbsTol',1e-14);
verifyEqual(t,get(readingGraphic(fig,'ReadingChromaticity',index),'MarkerSize'),9);
data = get(colormeasuretest.field(fig,'ResultsTable'),'Data');
row=find(cell2mat(data(:,2))==index,1); verifyNotEmpty(t,row); verifyEqual(t,data{row,1},'>');
verifyEqual(t,sum(strcmp(data(:,1),'>')),1);
end

function value = readingGraphic(fig,tag,index)
value = findobj(fig,'Tag',tag,'UserData',index);
end

function testLatestSummaryUsesLatestValuesWhileAnotherRowIsInspected(t)
[view,fig]=makeView(t);m=readings(3);d=colormeasure.drivers.pr.viewData(m);
d.xyzUnitsByReading={'unit one';'unit two';'unit three'};
view.update(m,d,positions(650,400));
table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3]));
summary=colormeasuretest.field(fig,'LatestReadingSummary').String;
text=strjoin(cellstr(summary),newline);
verifySubstring(t,text,'Latest #3');verifySubstring(t,text,'unit three');
verifySubstring(t,text,'XYZ: 3, 4, 5 unit three');verifyFalse(t,contains(text,'XYZ: 1, 2, 3'));
verifyFalse(t,contains(text,newline));verifySubstring(t,text," | u' = ");
verifyEqual(t,colormeasuretest.field(fig,'LatestReadingSummary').Position(4),20);
verifyEqual(t,colormeasuretest.field(fig,'LatestReadingSummary').TooltipString,text);
verifyEqual(t,table.UserData,1);
view.showTable(false);
verifyEqual(t,char(colormeasuretest.field(fig,'SpectraMode').Visible),'on');
verifyEqual(t,colormeasuretest.field(fig,'LatestReading').Parent,fig);
verifyEqual(t,colormeasuretest.field(fig,'LatestReadingSummary').String,summary);
selected=colormeasuretest.field(fig,'ReadingPage');
verifyEqual(t,char(selected.Visible),'on');verifySubstring(t,selected.String,'Inspecting 1 of 3');
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading'));
verifySubstring(t,selected.String,'Following 3 of 3');
end

function testLatestSummaryNamesUnavailableBlackChromaticity(t)
[view,fig]=makeView(t);m=readings(1);d=colormeasure.drivers.pr.viewData(m);
d.XYZ(1,:)=[0 0 0];view.update(m,d,positions(650,400));
table=colormeasuretest.field(fig,'ResultsTable');verifyEqual(t,table.Data{1,strcmp(table.ColumnName,"u'")},'Unavailable');
text=strjoin(cellstr(colormeasuretest.field(fig,'LatestReadingSummary').String),newline);
verifySubstring(t,text,"u' = Unavailable");verifySubstring(t,text,"v' = Unavailable");
verifyFalse(t,contains(text,'NaN'));
end

function testSelectedPreviewMatchesTableIconAndKeepsLatestSummary(t)
[view,fig]=makeView(t);m=readings(2);m(1).XYZ=[1 0 0];m(2).XYZ=[0 1 0];
d=colormeasure.drivers.pr.viewData(m);p=positions(650,400);p.table(3)=1400;
view.update(m,d,p);table=colormeasuretest.field(fig,'ResultsTable');
preview=colormeasuretest.field(fig,'SelectedColorPreview');
verifyEqual(t,char(preview.Visible),'on');
swatch=colormeasuretest.field(fig,'SelectedColorSwatch');
verifyEqual(t,char(swatch.Visible),'on');
table.CellSelectionCallback(table,struct('Indices',[1 3]));
[expected,valid]=colormeasure.colorimetry.previewColor(d.XYZ(1,:));verifyTrue(t,valid);
verifyEqual(t,swatch.BackgroundColor,expected);
styles=table.StyleConfigurations.Style;
verifyEqual(t,squeeze(styles(1).Icon(8,8,:))',swatch.BackgroundColor);
verifyEqual(t,height(table.StyleConfigurations),2);
verifySubstring(t,colormeasuretest.field(fig,'SelectedColorName').Text,'Selected #1');
verifySubstring(t,colormeasuretest.field(fig,'LatestReadingSummary').String,'Latest #2');
verifySubstring(t,colormeasuretest.field(fig,'SelectedColorNote').Tooltip,'clipped');
m(1).name='Renamed sample';view.update(m,d,p);
verifySubstring(t,colormeasuretest.field(fig,'SelectedColorName').Text,'Renamed sample');
verifyEqual(t,table.UserData,1);verifyEqual(t,swatch.BackgroundColor,expected);
colormeasuretest.click(colormeasuretest.field(fig,'LatestReading'));
verifySubstring(t,colormeasuretest.field(fig,'SelectedColorName').Text,'Selected #2');
verifyEqual(t,swatch.BackgroundColor,colormeasure.colorimetry.previewColor(d.XYZ(2,:)));
verifyEqual(t,table.Data{1,3},'Renamed sample');verifyEqual(t,d.XYZ,[1 0 0;0 1 0]);
end

function testNativePreviewNormalizesBrightnessWithoutInferringAWhite(t)
[view,fig]=makeView(t);m=readings(2);
white=colormeasure.colorimetry.illuminantWhite('D50',100).XYZ;
m(1).XYZ=.18*white;m(2).XYZ=.7*white;d=colormeasure.drivers.pr.viewData(m);
% CIE D50 XYZ through the ICC sRGB matrix and peak-channel normalization,
% without Bradford adaptation: a D50 chromaticity is not inferred as white.
expected=[1 .921010310826129 .805836700164279];
p=positions(650,400);p.table(3)=1400;view.update(m,d,p);
swatch=colormeasuretest.field(fig,'SelectedColorSwatch');
verifyEqual(t,swatch.BackgroundColor,expected,'AbsTol',2e-7);
note=colormeasuretest.field(fig,'SelectedColorNote').Tooltip;
verifySubstring(t,note,'brightness normalized');verifyFalse(t,contains(note,'Adapted'));
verifyFalse(t,contains(note,'declared XYZ white'));
table=colormeasuretest.field(fig,'ResultsTable');table.CellSelectionCallback(table,struct('Indices',[1 3]));
styles=table.StyleConfigurations.Style;
verifyEqual(t,squeeze(styles(1).Icon(8,8,:))',swatch.BackgroundColor);
verifyEqual(t,swatch.BackgroundColor,expected,'AbsTol',2e-7);
verifyEqual(t,table.UserData,1);verifyFalse(t,isfield(d,'previewWhiteXYZ'));
verifyEqual(t,d.XYZ,[.18*white;.7*white]);
verifyEqual(t,vertcat(m.XYZ),d.XYZ);
end
function testLabWhiteChangesComparisonWithoutRecoloringNativePreview(t)
fig=figure('Visible','off');t.addTeardown(@()delete(fig));
group=uitabgroup(fig);reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@()colormeasuretest.dispose(view));
m=readings(2);D50=colormeasure.colorimetry.illuminantWhite('D50',100).XYZ;
m(1).XYZ=.18*D50;m(2).XYZ=.7*D50;d=syntheticComparisonData(m);
p=positions(650,400);p.table(3)=1400;view.update(m,d,p);
table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3;2 3]));
swatch=colormeasuretest.field(fig,'SelectedColorSwatch');
before=swatch.BackgroundColor;rawTable=table.Data;
white=colormeasuretest.field(fig,'CompareWhite');Y=colormeasuretest.field(fig,'CompareWhiteY');
for choice=[-1 -2]
    white.Value=choice;white.ValueChangedFcn(white,[]);
    result=colormeasuretest.field(fig,'ComparisonResults').UserData;
    verifyTrue(t,isfinite(result.deltaE00));
    if choice==-1
        verifyEqual(t,result.whiteXYZ,D50);
        verifyEqual(t,result.Lab(:,2:3),zeros(2),'AbsTol',1e-12);
    else
        verifyEqual(t,result.whiteReference.illuminant,'D65');
        verifyGreaterThan(t,max(abs(result.Lab(:,2:3)),[],'all'),1);
    end
    verifyEqual(t,result.deltaXYZ,d.XYZ(2,:)-d.XYZ(1,:));
    verifyEqual(t,swatch.BackgroundColor,before);verifyEqual(t,table.Data,rawTable);
    styles=table.StyleConfigurations.Style;
    verifyEqual(t,squeeze(styles(2).Icon(8,8,:))',swatch.BackgroundColor);
end
for whiteY={[],100}
    Y.Value=whiteY{1};Y.ValueChangedFcn(Y,[]);
    result=colormeasuretest.field(fig,'ComparisonResults').UserData;
    verifyEqual(t,isfinite(result.deltaE00),~isempty(whiteY{1}));
    if isempty(whiteY{1})
        verifyTrue(t,all(isnan(result.Lab),'all'));
        verifySubstring(t,result.colorReason,'Enter White Y');
    end
    verifyEqual(t,swatch.BackgroundColor,before);verifyEqual(t,table.Data,rawTable);
    styles=table.StyleConfigurations.Style;
    verifyEqual(t,squeeze(styles(2).Icon(8,8,:))',swatch.BackgroundColor);
    verifyEqual(t,table.UserData,2);
    verifyFalse(t,contains(colormeasuretest.field(fig,'SelectedColorNote').Tooltip,'Adapted'));
end
verifyEqual(t,d.XYZ,[.18*D50;.7*D50]);verifyEqual(t,vertcat(m.XYZ),d.XYZ);
end
function testSelectedPreviewHidesInvalidAndUnknownObserverRows(t)
[view,fig]=makeView(t);m=readings(3);d=colormeasure.drivers.pr.viewData(m);
d.XYZ=[1 1 1;NaN 1 1;0 0 0];d.observerIds={'CIE1931_2deg';'CIE1931_2deg';'CIE1931_2deg'};
p=positions(650,400);p.table(3)=1400;view.update(m,d,p);
swatch=colormeasuretest.field(fig,'SelectedColorSwatch');
verifyEqual(t,char(swatch.Visible),'on');verifyEqual(t,swatch.BackgroundColor,[0 0 0]);
table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[2 3]));
verifyEqual(t,char(swatch.Visible),'off');
message=colormeasuretest.field(fig,'SelectedColorUnavailable');
verifyEqual(t,char(message.Visible),'on');verifyEqual(t,message.Text,'Color preview unavailable');
table.CellSelectionCallback(table,struct('Indices',[1 3]));
verifyEqual(t,char(swatch.Visible),'on');
d.observerIds{1}='';view.update(m,d,p);verifyEqual(t,char(swatch.Visible),'off');
view.update(readings(0),colormeasure.drivers.pr.viewData(readings(0)),p);
verifyEqual(t,char(swatch.Visible),'off');verifyEqual(t,message.Text,'No readings yet');
verifyEqual(t,colormeasuretest.field(fig,'SelectedColorName').Text,'No reading selected');
end

function testSelectedPreviewUsesOnlySpareWidthAndSurvivesCompactResize(t)
[view,fig]=makeView(t);m=readings(2);p=positions(650,400);p.table(3)=1400;
view.update(m,colormeasure.drivers.pr.viewData(m),p);
table=colormeasuretest.field(fig,'ResultsTable');preview=colormeasuretest.field(fig,'SelectedColorPreview');
verifyEqual(t,char(preview.Visible),'on');
verifyLessThanOrEqual(t,sum(cell2mat(table.ColumnWidth))+20,table.Position(3));
verifyLessThanOrEqual(t,table.Position(1)+table.Position(3),preview.Position(1)-12);
verifyEqual(t,preview.Position(1)+preview.Position(3),p.table(3));
table.CellSelectionCallback(table,struct('Indices',[1 3]));
for width=[636 928 1400]
    p.table(3)=width;view.layout(p);
    verifyEqual(t,table.UserData,1);
    verifyEqual(t,height(table.StyleConfigurations),2);
    verifyEqual(t,char(preview.Visible),colormeasure.ui.onOff(width==1400));
    if width<1400,verifyEqual(t,table.Position(3),width);end
end
view.showTable(false);verifyEqual(t,char(preview.Parent.Visible),'off');
view.showTable(true);verifyEqual(t,char(preview.Parent.Visible),'on');
end

function testEmptySpectrumHasNoInventedNumericalGrid(t)
[view,fig]=makeView(t);m=readings(0);d=colormeasure.drivers.pr.viewData(m);
view.update(m,d,positions(650,400));
axes=colormeasuretest.field(fig,'SpectrumAxes');
verifyEmpty(t,axes.XTick);verifyEmpty(t,axes.YTick);
verifyEqual(t,axes.XLabel.String,'Wavelength (nm)');
m=readings(1);view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
verifyEqual(t,axes.XTickMode,'auto');verifyEqual(t,axes.YTickMode,'auto');
verifyNotEmpty(t,axes.XTick);verifyNotEmpty(t,axes.YTick);
line=readingGraphic(fig,'ReadingSpectrum',1);
verifyEqual(t,line.XData,m.lambda');verifyEqual(t,line.YData,m.radiance');
end

function testSpectrumScaleAnnotationClearsObserverAfterResize(t)
[view,fig]=makeView(t);m=readings(2);
for index=1:2,m(index).radiance=m(index).radiance*1e-3;end
view.update(m,colormeasure.drivers.pr.viewData(m),positions(650,400));
spectrumAxes=colormeasuretest.field(fig,'SpectrumAxes');
drawnow;verifyLessThan(t,spectrumAxes.YAxis.Exponent,0);
observer=colormeasuretest.field(fig,'ResultObserver');
decoratedTop=spectrumAxes.Position(2)+spectrumAxes.Position(4)+spectrumAxes.TightInset(4);
verifyLessThanOrEqual(t,decoratedTop,observer.Position(2)-4, ...
    'The first reading must fit before any resize or explicit layout.');
for dimensions={[650 400],[900 500]}
    plotSize=dimensions{1};view.layout(positions(plotSize(1),plotSize(2)));drawnow;
    observer=colormeasuretest.field(fig,'ResultObserver');
    decoratedTop=spectrumAxes.Position(2)+spectrumAxes.Position(4)+spectrumAxes.TightInset(4);
    verifyLessThanOrEqual(t,decoratedTop,observer.Position(2)-4);
    spectrumLine=readingGraphic(fig,'ReadingSpectrum',1);
    verifyEqual(t,spectrumLine.YData,m(1).radiance');
end
end

function testComparisonSpectrumScaleAnnotationClearsObserver(t)
fig=figure('Visible','off','Position',[20 20 1280 840]);t.addTeardown(@() delete(fig));
group=uitabgroup(fig,'Position',[0 0 .28 .52]);reading=uitab(group);compare=uitab(group);
view=colormeasure.ui.ResultsView(fig,reading,compare);t.addTeardown(@() colormeasuretest.dispose(view));
m=readings(2);for index=1:2,m(index).radiance=m(index).radiance*1e-3;end
view.update(m,syntheticComparisonData(m),positions(900,500));
table=colormeasuretest.field(fig,'ResultsTable');
table.CellSelectionCallback(table,struct('Indices',[1 3;2 3]));
drawnow;view.layout(positions(900,500));drawnow;
axes=colormeasuretest.field(fig,'SpectrumAxes');
verifyLessThan(t,axes.YAxis.Exponent,0);
observer=colormeasuretest.field(fig,'ResultObserver');
decoratedTop=axes.Position(2)+axes.Position(4)+axes.TightInset(4);
verifyLessThanOrEqual(t,decoratedTop,observer.Position(2)-4);
difference=colormeasuretest.field(fig,'DifferenceAxes');
verifyEqual(t,char(difference.Visible),'on');
verifyGreaterThan(t,axes.Position(2),difference.Position(2)+difference.Position(4));
verifyEqual(t,colormeasuretest.field(fig,'SpectralDifference').YData, ...
    (m(2).radiance-m(1).radiance)');
end

function captureTableHeaders(control,headers)
headers('columns')=control.ColumnName; %#ok<NASGU> Mutate the shared map read by the listener test.
end

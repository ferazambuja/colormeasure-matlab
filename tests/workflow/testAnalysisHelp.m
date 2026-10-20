function tests=testAnalysisHelp
% White-role guidance and help ownership; callback checks, no instrument I/O.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testHelpExplainsDistinctWhiteRolesAndScale(t)
compare=colormeasure.ui.analysisHelpText('compare');
text=strjoin([compare.paragraphs compare.details],newline);
verifySubstring(t,text,'A (ref.) and B (test)');
verifySubstring(t,text,'separate white');
verifySubstring(t,text,'300 cd/m²');
verifySubstring(t,text,'editable for presets only');
verifySubstring(t,text,'uses its full XYZ directly');
verifySubstring(t,text,'surface samples under a lamp');
verifySubstring(t,text,'same illumination, geometry and settings');
verifySubstring(t,text,'leaves Lab unchanged');
verifySubstring(t,text,'https://cie.co.at/eilvterm/17-23-076');
color=colormeasure.ui.analysisHelpText('color');
text=strjoin([color.headings color.paragraphs color.details],newline);
verifySubstring(t,text,'Source white');verifySubstring(t,text,'To white');
verifySubstring(t,text,'relative spectral ratio');
verifySubstring(t,text,'illuminant spectral power distribution');
verifySubstring(t,text,'Instrument');
verifySubstring(t,text,'directional spectral reflectance factor');
verifyError(t,@()colormeasure.ui.analysisHelpText('unknown'),'Measurement:AnalysisHelp');
end
function testReachableActionsReuseHelpAndPreserveInputs(t)
[owner,parent]=container(t);
compare=colormeasure.ui.ComparisonView(parent);t.addTeardown(@()delete(compare));
white=findall(owner,'Tag','CompareWhiteY');verifyEqual(t,white.Value,100);white.Value=250;
button=findall(owner,'Tag','ComparisonHelp');colormeasuretest.click(button);
window=getappdata(owner,'colormeasureAnalysisHelp');
verifyEqual(t,window.Name,'Whites for comparison');
pane=findall(window,'Tag','AnalysisHelpText');
verifySubstring(t,pane.Data,'White Y');
verifySubstring(t,pane.Data,'<details><summary>Technical details</summary>');
verifyEqual(t,white.Value,250);
color=colormeasure.ui.IlluminationView(parent);t.addTeardown(@()delete(color));
source=findall(owner,'Tag','IlluminationSourceWhite');source.Value=-2;
colormeasuretest.click(findall(owner,'Tag','IlluminationHelp'));
verifyEqual(t,getappdata(owner,'colormeasureAnalysisHelp'),window);
verifyEqual(t,window.Name,'Whites and light in Color views');
verifySubstring(t,pane.Data,'Relight with');verifyEqual(t,source.Value,-2);
verifyEmpty(t,getappdata(owner,'IlluminationResult'));
verifyEqual(t,char(findall(owner,'Tag','IlluminationApply').Enable),'off');
end
function testCloseKeysAndExplicitCloseReleaseTheWindow(t)
[owner,parent]=container(t);button=uibutton(parent,'Text','Help');
window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
pane=findall(window,'Tag','AnalysisHelpText');
pane.HTMLEventReceivedFcn(pane,struct('HTMLEventName','dialogCloseKey'));
verifyFalse(t,isgraphics(window));verifyEmpty(t,getappdata(owner,'colormeasureAnalysisHelp'));
window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
window.WindowKeyPressFcn(window,struct('Key','escape','Modifier',{{}}));
verifyFalse(t,isgraphics(window));
window=colormeasure.ui.showAnalysisHelp(owner,'color',button);
window.WindowKeyPressFcn(window,struct('Key','period','Modifier',{{'command'}}));
verifyFalse(t,isgraphics(window));
window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
owner.Visible='on';
lastwarn('');
colormeasuretest.click(findall(window,'Tag','AnalysisHelpClose'));
verifyEmpty(t,lastwarn,'Closing Help must not warn when its return button is available.');
verifyFalse(t,isgraphics(window));
window=colormeasure.ui.showAnalysisHelp(owner,'compare');
colormeasuretest.click(findall(window,'Tag','AnalysisHelpClose'));
verifyFalse(t,isgraphics(window));
end
function testOwnerHideAndDeleteLeaveNoHelpWindow(t)
[owner,parent]=container(t);button=uibutton(parent,'Text','Help');
window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
owner.Visible='on';owner.Visible='off';
verifyFalse(t,isgraphics(window));verifyEmpty(t,getappdata(owner,'colormeasureAnalysisHelp'));
window=colormeasure.ui.showAnalysisHelp(owner,'color',button);
delete(owner);verifyFalse(t,isgraphics(window));
end
function testConstructionFailureDisposesOnlyTheUnpublishedHelpWindow(t)
[owner,~]=container(t);
previous=findall(groot,'Type','figure','Tag','AnalysisHelpWindow');
t.addTeardown(@()disposeNewHelpWindows(previous));
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
mkdir(fullfile(folder.Folder,'+colormeasure','+ui'));
file=fopen(fullfile(folder.Folder,'+colormeasure','+ui','createHelpPane.m'),'w');
assert(file>=0);cleanup=onCleanup(@()fclose(file));
fprintf(file,['function pane=createHelpPane(varargin)\n' ...
    'pane=[];error(''Fixture:AnalysisHelpConstruction'',''Injected help construction failure.'');\nend\n']);
clear cleanup
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(folder.Folder));
clear colormeasure.ui.createHelpPane
t.addTeardown(@clearHelpPane);
verifyError(t,@()colormeasure.ui.showAnalysisHelp(owner,'compare'),'Fixture:AnalysisHelpConstruction');
verifyEmpty(t,newHelpWindows(previous),'A failed help constructor must not leave an unpublished window.');
verifyFalse(t,isappdata(owner,'colormeasureAnalysisHelp'));
end
function testSameTopicPreservesHelpDataAndPosition(t)
[owner,parent]=container(t);button=uibutton(parent,'Text','Help');
window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
pane=findall(window,'Tag','AnalysisHelpText');data=pane.Data;
window.Position=[20 20 440 360];
again=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
verifyEqual(t,again,window);verifyEqual(t,window.Position,[20 20 440 360]);
verifyEqual(t,pane.Data,data);
verifyEqual(t,pane.HTMLSource,fullfile(colormeasure.root(),'src','+colormeasure','+ui','dialogHelp.html'));
window.Theme='dark';window.ThemeChangedFcn(window,[]);
verifySubstring(t,pane.Data,'color-scheme:dark');
window.Theme='light';window.ThemeChangedFcn(window,[]);
verifySubstring(t,pane.Data,'color-scheme:light');
end
function testChangedReturnTargetsCloseWithoutChangingTheCurrentTab(t)
[owner,~]=container(t);owner.Visible='on';
group=uitabgroup(owner);analysis=uitab(group,'Title','Compare');current=uitab(group,'Title','Data');
grid=uigridlayout(analysis,[1 1]);button=uibutton(grid,'Text','Help');
for state={'unselected','hidden','disabled','deleted','reparented'}
    group.SelectedTab=analysis;
    window=colormeasure.ui.showAnalysisHelp(owner,'compare',button);
    group.SelectedTab=current;
    switch state{1}
        case 'hidden',button.Visible='off';
        case 'disabled',button.Enable='off';
        case 'deleted',delete(button);
        case 'reparented'
            hidden=uitabgroup(owner,'Visible','off');analysis.Parent=hidden;
    end
    lastwarn('');
    colormeasuretest.click(findall(window,'Tag','AnalysisHelpClose'));
    verifyEmpty(t,lastwarn,'Closing Help must not try to focus an unavailable return button.');
    verifyFalse(t,isgraphics(window));
    verifyEqual(t,group.SelectedTab,current);
    verifyEmpty(t,getappdata(owner,'colormeasureAnalysisHelp'));
    if ~isgraphics(button),button=uibutton(grid,'Text','Help');end
    button.Visible='on';button.Enable='on';
end
end
function testHelpAndPrimaryActionsFitTheProductSidebar(t)
owner=figure('Visible','off','Position',[20 20 960 650]);
t.addTeardown(@()colormeasuretest.dispose(owner));
group=uitabgroup(owner,'Units','pixels','Position',[16 58 272 532]);
compare=uitab(group,'Title','Compare');color=uitab(group,'Title','Color');
views={colormeasure.ui.ComparisonView(compare),colormeasure.ui.IlluminationView(color)};
for k=1:2,t.addTeardown(@()colormeasuretest.dispose(views{k}));end
% Show this fixture before checking the grids' rendered control bounds.
owner.Visible='on';drawnow;
for item={{compare,'CopyComparison','ComparisonHelp'},{color,'IlluminationExport','IlluminationHelp'}}
    row=item{1};group.SelectedTab=row{1};
    primary=findall(owner,'Tag',row{2});help=findall(owner,'Tag',row{3});
    deadline=tic;settled=false;
    while toc(deadline)<30
        drawnow;
        a=getpixelposition(primary,true);b=getpixelposition(help,true);bounds=getpixelposition(row{1},true);
        settled=all(a(1:2)>=bounds(1:2))&&all(b(1:2)>=bounds(1:2))&& ...
            all(a(1:2)+a(3:4)<=bounds(1:2)+bounds(3:4))&& ...
            all(b(1:2)+b(3:4)<=bounds(1:2)+bounds(3:4))&&a(1)+a(3)<=b(1)&& ...
            a(3)>=150&&b(3)>=64;
        if settled,break;end
    end
    diagnostic=sprintf(['%s: Help and the primary action must fit the sidebar and keep ' ...
        'their minimum widths. Primary=%s; Help=%s; Tab=%s.'], ...
        row{1}.Title,mat2str(a),mat2str(b),mat2str(bounds));
    verifyTrue(t,settled,diagnostic);
end
end
function testVisibilityAndFocusHelpersAdmitOnlySingleLiveComponents(t)
[owner,parent]=container(t);owner.Visible='on';
button=uibutton(parent,'Text','Help');other=uibutton(parent,'Text','Other');
verifyTrue(t,colormeasure.ui.isShown(button));
verifyTrue(t,colormeasure.ui.canFocus(button,owner));
% Successful traversal reaches groot.Parent=[]; it must finish without a
% nonscalar logical operand. Invalid controls and owners must still refuse.
for invalid={gobjects(0),[button other],NaN}
    verifyFalse(t,colormeasure.ui.isShown(invalid{1}));
    verifyFalse(t,colormeasure.ui.canFocus(invalid{1},owner));
end
second=figure('Visible','off');t.addTeardown(@()colormeasuretest.dispose(second));
for invalid={gobjects(0),[owner second],NaN,second}
    verifyFalse(t,colormeasure.ui.canFocus(button,invalid{1}));
end
delete(other);verifyFalse(t,colormeasure.ui.isShown(other));
verifyFalse(t,colormeasure.ui.canFocus(other,owner));
delete(second);verifyFalse(t,colormeasure.ui.canFocus(button,second));
end

function testVisibilityAndFocusRespectAncestorsSelectedTabsAndEnable(t)
[owner,~]=container(t);owner.Visible='on';
group=uitabgroup(owner);selected=uitab(group,'Title','Current');other=uitab(group,'Title','Other');
grid=uigridlayout(selected,[1 1]);button=uibutton(grid,'Text','Help');
group.SelectedTab=selected;
verifyTrue(t,colormeasure.ui.isShown(button));verifyTrue(t,colormeasure.ui.canFocus(button,owner));
button.Enable='off';verifyTrue(t,colormeasure.ui.isShown(button));
verifyFalse(t,colormeasure.ui.canFocus(button,owner));button.Enable='on';
group.SelectedTab=other;verifyFalse(t,colormeasure.ui.isShown(button));
verifyFalse(t,colormeasure.ui.canFocus(button,owner));group.SelectedTab=selected;
group.Visible='off';verifyFalse(t,colormeasure.ui.isShown(button));
verifyFalse(t,colormeasure.ui.canFocus(button,owner));group.Visible='on';
owner.Visible='off';verifyFalse(t,colormeasure.ui.isShown(button));
verifyFalse(t,colormeasure.ui.canFocus(button,owner));
end

function [owner,parent]=container(t)
owner=figure('Visible','off','Position',[20 20 360 620]);
t.addTeardown(@()colormeasuretest.dispose(owner));
parent=uigridlayout(owner,[1 1]);
end
function windows=newHelpWindows(previous)
windows=findall(groot,'Type','figure','Tag','AnalysisHelpWindow');
owned=arrayfun(@(window)~any(previous(:)==window),windows);
windows=windows(owned);
end
function disposeNewHelpWindows(previous)
delete(newHelpWindows(previous));
end
function clearHelpPane
clear colormeasure.ui.createHelpPane
end

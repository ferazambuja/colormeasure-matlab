function tests = testMeasurementHelpHtml
% Help text remains plain data; only escaped static markup reaches the UI.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testEscapesContentAndAttributeValues(t)
text = '<script>alert("A&B'');</script>';
[html,plain] = colormeasure.ui.helpHtml(text,{text},{text},'light');
escaped = '&lt;script&gt;alert(&quot;A&amp;B&#39;);&lt;/script&gt;';
verifyTrue(t,contains(html,['aria-label="' escaped '"']));
verifyTrue(t,contains(html,['<h1>' escaped '</h1>']));
verifyTrue(t,contains(html,['<h2>' escaped '</h2>']));
verifyTrue(t,contains(html,['<p>' escaped '</p>']));
verifyFalse(t,contains(html,'<script>'));
verifyTrue(t,any(strcmp(plain,text)));
end

function testParagraphsListsAndMissingHeadingsPreserveAllText(t)
[html,plain] = colormeasure.ui.helpHtml('Help',{'First';{'One','Two & three'};'Extra'}, ...
    {'Start';'Sources'},'dark');
verifyTrue(t,contains(html,'<h2>Start</h2><p>First</p>'));
verifyTrue(t,contains(html,'<ul><li>One</li><li>Two &amp; three</li></ul><p>Extra</p>'));
verifyTrue(t,any(strcmp(plain,'Extra')));
verifyTrue(t,any(strcmp(plain,'- Two & three')));
end

function testStaticSelectableDocumentHasNoExternalResources(t)
html = colormeasure.ui.helpHtml('Help',{'Text'},{});
verifyTrue(t,contains(html,'user-select:text'));
verifyTrue(t,contains(html,'tabindex="0"'));
verifyFalse(t,contains(html,{'<script','<link','src=','onload='}));
verifyEqual(t,html,colormeasure.ui.helpHtml('Help',{'Text'},{}));
end

function testDialogCloseBridgePreservesEscapedContentAndFiltersEvents(t)
fig=uifigure('Visible','off');t.addTeardown(@()delete(fig));
pane=uihtml(fig);closed=0;
html=colormeasure.ui.helpHtml('Help',{'<script>Do not execute</script>'});
colormeasure.ui.setDialogHelp(pane,html,@closedDialog);
verifyTrue(t,isfile(pane.HTMLSource));
bridge=fileread(pane.HTMLSource);verifySubstring(t,bridge,'function setup(htmlComponent)');
% The page side of the close key, which the injected event below stands in for.
verifySubstring(t,bridge,'event.key !== "Escape" && !(event.metaKey && event.key === ".")');
verifySubstring(t,bridge,'htmlComponent.sendEventToMATLAB("dialogCloseKey", null)');
rendered=pane.Data;
verifySubstring(t,rendered,'&lt;script&gt;Do not execute&lt;/script&gt;');
verifyFalse(t,contains(rendered,'<script>Do not execute'));
pane.HTMLEventReceivedFcn(pane,struct('HTMLEventName','unrelated'));
verifyEqual(t,closed,0);
pane.HTMLEventReceivedFcn(pane,struct('HTMLEventName','dialogCloseKey'));
verifyEqual(t,closed,1);
colormeasure.ui.setDialogHelp(pane,html,@closedDialog);
verifyEqual(t,pane.Data,rendered);
    function closedDialog()
        closed=closed+1;
    end
end

function testThemeInputsCannotIntroduceMarkup(t)
dark = colormeasure.ui.helpHtml('Help',{'Text'},{},'dark');
light = colormeasure.ui.helpHtml('Help',{'Text'},{},'light');
verifyTrue(t,contains(dark,'color-scheme:dark'));
verifyTrue(t,contains(light,'color-scheme:light'));
verifyEqual(t,colormeasure.ui.helpHtml('Help',{'Text'},{},'</style><script>'),light);
end

function testTechnicalDetailsAreCollapsedEscapedAndIncludedInPlainText(t)
detail='Native <stage> & "code"';
[html,plain]=colormeasure.ui.helpHtml('Outcome',{'Warning remains visible'}, {},'light',{detail});
verifySubstring(t,html,'<details><summary>Technical details</summary>');
verifySubstring(t,html,'<p>Native &lt;stage&gt; &amp; &quot;code&quot;</p></details>');
verifyFalse(t,contains(html,'<details open'));
warningPosition=strfind(html,'Warning remains visible');detailsPosition=strfind(html,'<details>');
assertNumElements(t,warningPosition,1);assertNumElements(t,detailsPosition,1);
verifyLessThan(t,warningPosition,detailsPosition);
verifyTrue(t,any(strcmp(plain,detail)));
verifyFalse(t,contains(html,{'<script','onclick=','src='}));
verifySubstring(t,html,'summary:focus-visible');
verifyFalse(t,contains(colormeasure.ui.helpHtml('Outcome',{'Text'}),'<details>'));
end

function testModelParagraphsAndAppendedWorkflowHelpRemainPresent(t)
for model = {'CR100','CR250','CR300','CS2000'}
    if strcmp(model{1},'CS2000')
        adapter = colormeasure.drivers.cs2000.uiAdapter();
        core = colormeasure.drivers.cs2000.preparation();
    else
        adapter = colormeasure.drivers.cr.uiAdapter(model{1});
        core = colormeasure.drivers.cr.preparation(model{1});
    end
    guide = adapter.preparation;
    verifyEqual(t,guide.headings(1:numel(core.headings)),core.headings);
    verifyEqual(t,guide.details(1:numel(core.details)),core.details);
    % A manufacturer's operating section may share a heading with the
    % appended window instructions. Check the appended section explicitly.
    appendedHeadings=guide.headings(numel(core.headings)+1:end);
    appendedDetails=guide.details(numel(core.details)+1:end);
    [html,plain] = colormeasure.ui.helpHtml(guide.title,guide.details,guide.headings);
    verifyEqual(t,numel(guide.details),numel(guide.headings));
    acquisition=find(strcmp(appendedHeadings,'Acquisition settings'));
    assertNumElements(t,acquisition,1);
    verifySubstring(t,appendedDetails{acquisition},'Read settings');
    verifySubstring(t,appendedDetails{acquisition},'Use for next readings');
    objectColor=find(strcmp(appendedHeadings,'Object color view'));
    if strcmp(model{1},'CR100')
        verifyEmpty(t,objectColor);
    else
        assertNumElements(t,objectColor,1);
        verifySubstring(t,appendedDetails{objectColor},'Reflectance / relight');
        verifySubstring(t,appendedDetails{objectColor},'measured white reference');
        verifySubstring(t,appendedDetails{objectColor},'Lab comparison white alone does not perform this step');
    end
    for k = 1:numel(guide.details)
        verifyTrue(t,any(strcmp(plain,guide.details{k})));
    end
    for k = 1:numel(guide.headings)
        verifyTrue(t,contains(html,['<h2>' guide.headings{k} '</h2>']));
    end
end
end

function testHelpPaneCreatesHtmlWithoutInstallingContentOrCallbacks(t)
fig=uifigure('Visible','off');t.addTeardown(@()delete(fig));
grid=uigridlayout(fig,[1 1]);
pane=colormeasure.ui.createHelpPane(grid,'OwnedHelp');
verifyClass(t,pane,'matlab.ui.control.HTML');
verifyEqual(t,pane.Parent,grid);verifyEqual(t,pane.Tag,'OwnedHelp');
verifyEmpty(t,pane.HTMLEventReceivedFcn);
html=colormeasure.ui.helpHtml('Help',{'All help stays selectable.'});
colormeasure.ui.setDialogHelp(pane,html,@()[]);
verifyEqual(t,pane.Data,html);
end

function testPRPreparationAndWindowRecipeDoNotContradictEachOther(t)
core=colormeasure.drivers.pr.adapter();
window=colormeasure.drivers.pr.uiAdapter();
verifyEqual(t,window.preparation.details(1:numel(core.preparation.details)),core.preparation.details);
text=strjoin(window.preparation.details,' ');
verifySubstring(t,text,'adaptive exposure, one cycle, automatic synchronization');
verifySubstring(t,text,'deliberate overrides');
verifyFalse(t,contains(text,'existing measurement settings'));
verifySubstring(t,strjoin(core.preparation.details,' '),'target geometry consistent');
end

function testHelpPaneFallsBackToReadOnlyWrappedTextArea(t)
fig=uifigure('Visible','off');t.addTeardown(@()delete(fig));
grid=uigridlayout(fig,[1 1]);
pane=colormeasure.ui.createHelpPane(grid,'OwnedHelp',@htmlFailure);
verifyClass(t,pane,'matlab.ui.control.TextArea');
verifyEqual(t,pane.Parent,grid);verifyEqual(t,pane.Tag,'OwnedHelp');
verifyEqual(t,char(pane.Editable),'off');verifyEqual(t,char(pane.WordWrap),'on');
verifyEqual(t,pane.FontSize,12);
verifyNumElements(t,grid.Children,1);
end

function testHelpPaneRethrowsUnexpectedConstructorErrors(t)
fig=uifigure('Visible','off');t.addTeardown(@()delete(fig));
grid=uigridlayout(fig,[1 1]);
verifyError(t,@()colormeasure.ui.createHelpPane(grid,'OwnedHelp',@unexpectedFailure), ...
    'Test:UnexpectedHelpError');
verifyEmpty(t,grid.Children);
end

function testHelpPaneRejectsDestroyedParentBeforeConstruction(t)
fig=uifigure('Visible','off');t.addTeardown(@()delete(fig));
grid=uigridlayout(fig,[1 1]);delete(grid);
verifyError(t,@()colormeasure.ui.createHelpPane(grid,'OwnedHelp',@unexpectedFailure), ...
    'Measurement:HelpParent');
end

% These constructor doubles always throw; keep the caller's one-output signature.
function pane=htmlFailure(varargin) %#ok<STOUT>
error('MATLAB:ui:HTML:unknownInput','Controlled HTML component creation failure.');
end

function pane=unexpectedFailure(varargin) %#ok<STOUT>
error('Test:UnexpectedHelpError','This is not an HTML component creation failure.');
end

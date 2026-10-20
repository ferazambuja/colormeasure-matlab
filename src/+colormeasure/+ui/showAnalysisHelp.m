function window=showAnalysisHelp(owner,topic,returnControl)
%SHOWANALYSISHELP Reuse selectable analysis help without touching a session.
% One nonmodal window belongs to each host. Hide/delete of the host closes it;
% HTML focus keeps Escape/Command-period, scrolling and copying available.
% Fernando Voltolini de Azambuja, 2026.
help=colormeasure.ui.analysisHelpText(topic);
if ~isgraphics(owner,'figure'),owner=ancestor(owner,'figure');end
assert(isgraphics(owner,'figure'),'Measurement:AnalysisHelp','Help needs a live host window.');
if nargin<3,returnControl=[];end
key='colormeasureAnalysisHelp';window=getappdata(owner,key);
if isempty(window)||~isgraphics(window)
    window=uifigure('Name',help.title,'Visible','off','Tag','AnalysisHelpWindow', ...
        'Position',colormeasure.ui.dialogPosition(owner,[560 470]), ...
        'CloseRequestFcn',@(~,~) closeHelp(true), ...
        'WindowKeyPressFcn',@(~,event) closeKey(event));
    candidate=window;
    listeners={};
    % The window's nested callbacks retain this workspace. Dispose failed
    % construction explicitly instead of waiting for an onCleanup to die.
    try
        grid=uigridlayout(window,[2 1],'RowHeight',{'1x',32},'Padding',[12 12 12 12]);
        pane=colormeasure.ui.createHelpPane(grid,'AnalysisHelpText');
        uibutton(grid,'Text','Close','Tag','AnalysisHelpClose', ...
            'ButtonPushedFcn',@(~,~) closeHelp(true));
        if ~isgraphics(owner),discardCandidate(candidate,owner,key,listeners);return;end
        setappdata(window,'HelpPane',pane);
        % Retain each listener immediately so partial setup owns its cleanup.
        listeners{1}=addlistener(owner,'ObjectBeingDestroyed',@(~,~) closeHelp(false));
        listeners{2}=addlistener(owner,'Visible','PostSet',@(~,~) ownerVisibility());
        setappdata(window,'OwnerListeners',listeners);
        window.DeleteFcn=@(~,~) release();
        window.ThemeChangedFcn=@(~,~) render();
        setappdata(owner,key,window);
    catch failure
        discardCandidate(candidate,owner,key,listeners);
        rethrow(failure);
    end
end
setappdata(window,'Topic',topic);setappdata(window,'ReturnControl',returnControl);
render();
if strcmp(owner.Visible,'on'),figure(window);end

    function render()
        if ~isgraphics(window),return;end
        value=getappdata(window,'Topic');if isempty(value),return;end
        content=colormeasure.ui.analysisHelpText(value);
        [html,plain]=colormeasure.ui.helpHtml(content.title,content.paragraphs, ...
            content.headings,window.Theme.BaseColorStyle,content.details);
        control=getappdata(window,'HelpPane');window.Name=content.title;
        if isa(control,'matlab.ui.control.HTML')
            colormeasure.ui.setDialogHelp(control,html,@()closeHelp(true));
        else
            control.Value=plain;
        end
    end
    function closeKey(event)
        if colormeasure.ui.isCloseKey(event)
            closeHelp(true);
        end
    end
    function ownerVisibility()
        if isgraphics(owner)&&strcmp(owner.Visible,'off'),closeHelp(false);end
    end
    function closeHelp(restoreFocus)
        target=[];
        if isgraphics(window),target=getappdata(window,'ReturnControl');delete(window);end
        if restoreFocus&&isgraphics(owner)&&strcmp(owner.Visible,'on')&&colormeasure.ui.canFocus(target,owner)
            focus(target);
        end
    end
    function release()
        if isgraphics(owner)&&isequal(getappdata(owner,key),window),rmappdata(owner,key);end
        owned=getappdata(window,'OwnerListeners');
        for n=1:numel(owned)
            if isvalid(owned{n}),delete(owned{n});end
        end
    end
end

function discardCandidate(candidate,owner,key,listeners)
% Release only this construction's window, binding and partial listeners.
for n=1:numel(listeners)
    if isvalid(listeners{n}),delete(listeners{n});end
end
if isgraphics(candidate),delete(candidate);end
if isgraphics(owner)&&isequal(getappdata(owner,key),candidate),rmappdata(owner,key);end
end

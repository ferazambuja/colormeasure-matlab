function pane=createHelpPane(parent,tag,createHtml)
%CREATEHELPPANE Create selectable help, with plain text if HTML cannot open.
% Content, layout and callbacks belong to the caller, outside this catch.
% The optional constructor permits isolated component-failure tests.
% https://www.mathworks.com/help/matlab/ref/uihtml.html
arguments
    parent (1,1) matlab.ui.container.GridLayout
    tag (1,:) char
    createHtml (1,1) function_handle = @uihtml
end
assert(isvalid(parent),'Measurement:HelpParent','Help needs a live layout.');
try
    pane=createHtml(parent,'Tag',tag);
catch problem
    % R2026b uihtml wraps every creation failure, including invalid component
    % arguments, in this identifier. Fixed arguments and a live parent are
    % supplied above. A constructor with another identifier is rethrown.
    if ~strcmp(problem.identifier,'MATLAB:ui:HTML:unknownInput')
        rethrow(problem);
    end
    pane=uitextarea(parent,'Editable','off','WordWrap','on', ...
        'FontSize',12,'Tag',tag);
end
end

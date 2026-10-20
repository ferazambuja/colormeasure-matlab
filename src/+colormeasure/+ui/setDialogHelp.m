function setDialogHelp(component,html,onClose)
%SETDIALOGHELP Keep dialog close keys usable while HTML help has focus.
% HTML is escaped by helpHtml. Only Escape and Command-period cross this
% bridge; text selection, Tab, scrolling and other keys stay in the browser.
% https://www.mathworks.com/help/matlab/ref/uihtml.html
% Fernando Voltolini de Azambuja, 2026.
component.HTMLEventReceivedFcn=@receive;
% JavaScript uses a file-backed source, as required by uihtml. Only changed
% help data is sent: ordinary session refreshes retain selection and scroll.
source=fullfile(fileparts(mfilename('fullpath')),'dialogHelp.html');
if ~isequal(component.Data,html),component.Data=html;end
if ~strcmp(component.HTMLSource,source),component.HTMLSource=source;end
    function receive(~,event)
        if strcmp(event.HTMLEventName,'dialogCloseKey'),onClose();end
    end
end

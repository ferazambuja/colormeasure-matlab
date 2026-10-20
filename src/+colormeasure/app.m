function varargout = app(model)
% APP Choose an instrument and open its live measurement batch.
%   colormeasure.app opens a device chooser. colormeasure.app('CR250') opens or
%   restores that model's batch directly. PR655, CR100, CR250, CR300 and CS2000
%   use separate batches. No measurement starts until Measure is selected.
%   session = colormeasure.app(...) returns the live session handle; the bare
%   command stores it under the selected device's named workspace variable.
%   Fernando Voltolini de Azambuja, 2026.
arguments
    model (1,:) char = ''
end
nargoutchk(0,1);
io=colormeasure.ui.services();
[session, workspaceName] = colormeasure.ui.launchDevice(model,io);
if nargout > 0
    varargout{1} = session;
elseif ~isempty(session)
    assignin('base', workspaceName, session);
    fprintf('Live batch: %s.measurements. MATLAB is available between readings.\n', workspaceName);
end
end

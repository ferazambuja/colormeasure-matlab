function varargout = measureCS2000(varargin)
%MEASURECS2000 Open or restore a CS-2000 batch; Measure starts each exposure.
%   session = colormeasure.drivers.cs2000.measureCS2000() returns a live shared-UI session.
%   The bare command stores colorMeasureCS2000Session. MAT saves after each reading;
%   Finish exports CSV. Close hides the view without discarding the session.
%   colormeasure.drivers.cs2000.measureCS2000('BaudRate',9600,'FlowControl','hardware') selects RS-232C
%   settings. Defaults: USB 115200/no flow, ResponseTimeout=10 seconds,
%   PreMeasurementTimeout=35 seconds. See README for options and side effects.
%   Relaunch restores an existing session only with matching connection options.
%   Fernando Voltolini de Azambuja, 2026.
nargoutchk(0,1);
session = colormeasure.ui.launchSession(colormeasure.drivers.cs2000.uiAdapter(varargin{:}));
if nargout == 0
    if ~isempty(session)
        assignin('base',session.workspaceName,session);
        fprintf('Live batch: %s.measurements. Measure starts one exposure.\n',session.workspaceName);
    end
else
    varargout{1} = session;
end
end

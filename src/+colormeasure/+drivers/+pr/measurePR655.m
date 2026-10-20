function varargout = measurePR655()
% MEASUREPR655 Open a live batch session and immediately return control to MATLAB.
%   session = colormeasure.drivers.pr.measurePR655() returns a handle. session.measurements is the growing
%   struct array; session.files and session.log expose save paths and events.
%   The bare command stores the handle as colorMeasurePR655Session, without writing ans.
%   Each Measure saves the MAT. Finish batch exports CSV and retains the data.
%   session.measure(name, notes) and session.finish() also work from commands.
%   Repeating the launcher restores the active or finished batch.
%   Close hides the window. Finish keeps results visible; New batch starts again.
%   Fernando Voltolini de Azambuja, 2026.
nargoutchk(0, 1);
session = colormeasure.ui.launchSession(colormeasure.drivers.pr.uiAdapter());
if nargout == 0
    if ~isempty(session)
        assignin('base', session.workspaceName, session);
        fprintf('Live batch: %s.measurements. MATLAB is available between readings.\n', session.workspaceName);
    end
else
    varargout{1} = session;
end
end

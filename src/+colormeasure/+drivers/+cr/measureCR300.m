function varargout = measureCR300(varargin)
%MEASURECR300 Open or restore the shared CR300 measurement window.
% The bare command stores colorMeasureCR300Session; no acquisition until Measure.
% Options: ResponseTimeout (5 s), MeasurementTimeout (120 s for M only).
% Fernando Voltolini de Azambuja, 2026.
nargoutchk(0,1);
session = colormeasure.drivers.cr.launchSession('CR300',varargin{:});
if nargout
    varargout{1} = session;
elseif ~isempty(session)
    assignin('base',session.workspaceName,session);
    fprintf('Live batch: %s.measurements\n',session.workspaceName);
end
end

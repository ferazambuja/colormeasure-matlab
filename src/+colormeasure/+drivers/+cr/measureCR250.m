function varargout = measureCR250(varargin)
%MEASURECR250 Open or restore the shared CR250 measurement window.
% The bare command stores colorMeasureCR250Session; no acquisition until Measure.
% Options: ResponseTimeout (5 s), MeasurementTimeout (120 s for M only).
% Fernando Voltolini de Azambuja, 2026.
nargoutchk(0,1);
session = colormeasure.drivers.cr.launchSession('CR250',varargin{:});
if nargout
    varargout{1} = session;
elseif ~isempty(session)
    assignin('base',session.workspaceName,session);
    fprintf('Live batch: %s.measurements\n',session.workspaceName);
end
end

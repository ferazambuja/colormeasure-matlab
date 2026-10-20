function varargout = demoCR250(mode)
%DEMOCR250 Synthetic CR250 preview; never enumerates or opens physical ports.
% Modes: interactive (explicit Measure), batch (two readings, no window),
% gallery (12 readings in a separate restorable window). Bare commands store
% colorMeasureCR250DemoSession, colorMeasureCR250DemoBatch, or colorMeasureCR250DemoGallery respectively.
% Fernando Voltolini de Azambuja, 2026.
if nargin<1, mode='interactive'; end
nargoutchk(0,1);
mode = validatestring(mode,{'interactive','batch','gallery'});
session = colormeasure.drivers.cr.demoSession('CR250',mode);
if nargout
    varargout{1} = session;
elseif ~isempty(session)
    assignin('base',session.workspaceName,session);
    fprintf('Synthetic batch: %s.measurements\n',session.workspaceName);
end
end

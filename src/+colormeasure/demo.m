function varargout = demo(model, mode)
% DEMO Practice the measurement workflow without connected hardware.
%   colormeasure.demo opens a device chooser. colormeasure.demo('CR250') opens an
%   interactive synthetic session; 'batch' saves two readings and finishes;
%   'gallery' populates twelve illustrative readings in a separate window.
%   Example: session = colormeasure.demo('CS2000', 'gallery');
%   CR-100 demonstrates XYZ-only readings and does not invent a spectrum.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0, 2); nargoutchk(0, 1);
if nargin < 1, model = ''; end
if nargin < 2, mode = 'interactive'; end
mode = validatestring(mode, {'interactive','batch','gallery'});
[session, workspaceName] = colormeasure.ui.launchDevice(model, [], mode);
if nargout > 0
    varargout{1} = session;
elseif ~isempty(session)
    assignin('base', workspaceName, session);
    fprintf('Live synthetic batch: %s.measurements\n', workspaceName);
end
end

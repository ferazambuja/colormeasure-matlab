function varargout = demoSession(mode, io, folder)
%DEMOSESSION Shared UI or headless batch using generated CS-grid readings.
% Optional services/destination are internal isolated-test seams; the public
% colormeasure.drivers.cs2000.demoCS2000 launcher accepts only its mode.
narginchk(0,3); nargoutchk(0,1);
if nargin == 0, mode = 'interactive'; end
mode = validatestring(mode,{'interactive','batch','gallery'});
colormeasure.session.assertSessionCompatible();
if nargin < 2, io = colormeasure.session.services(); end
if nargin < 3, folder = fullfile(tempdir,'colormeasure','CS2000'); end
adapter = colormeasure.drivers.cs2000.demoAdapter(mode);
if ~isfolder(folder), mkdir(folder); end
fprintf('SYNTHETIC DEMO: generated readings, no physical instrument connection.\n');
session = colormeasure.session.runDemo(adapter,mode,io,folder, ...
    struct('reading','CS2000:DemoReading','finish','CS2000:DemoFinish','retained','CS2000:DemoBatchRetained'));
if nargout == 0
    if ~isempty(session)
        assignin('base',adapter.workspaceName,session);
        fprintf('Live demo: %s.measurements\n',adapter.workspaceName);
    end
else
    varargout{1} = session;
end
end

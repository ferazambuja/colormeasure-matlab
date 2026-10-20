function varargout = demoSession(mode, io, folder, delaySeconds)
% DEMOSESSION Open the real measurement UI using a synthetic, disconnected meter.
%   demo = colormeasure.drivers.pr.demoPR655 returns a live session. The bare command assigns
%   colorMeasurePR655DemoSession. The batch command saves two synthetic
%   readings without UI and publishes colorMeasurePR655DemoBatch.
%   colormeasure.drivers.pr.demoPR655('gallery') opens a separate live session with twelve varied
%   synthetic readings. Repeating the command restores that gallery.
%   Every record identifies itself as synthetic; no serial port is opened.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0, 4); nargoutchk(0, 1);
if nargin == 0, mode = 'interactive'; end
mode = validatestring(mode, {'interactive','batch','gallery'});
colormeasure.session.assertSessionCompatible();
% Services, destination and the per-reading delay are internal seams for
% disconnected tests; an omitted or empty delay keeps the mode's own pacing.
if nargin < 2, io = colormeasure.session.services(); end
if nargin < 3, folder = fullfile(tempdir, 'colormeasure', 'PR655'); end
if nargin < 4, delaySeconds = []; end
pacing = struct('interactive', 0.5, 'batch', 0.5, 'gallery', 0.03);
if isempty(delaySeconds), delaySeconds = pacing.(mode); end
validateattributes(delaySeconds, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
if ~isfolder(folder), mkdir(folder); end
adapter = colormeasure.drivers.pr.uiAdapter();
adapter.catalog = struct('model','PR655','mode',mode);
adapter.key = 'PR655Demo';
adapter.workspaceName = 'colorMeasurePR655DemoSession';
adapter.label = 'PR-655 measurements (synthetic demo)';
adapter.listPorts = @(~) "/dev/cu.usbmodem_DEMO_ONLY";
adapter.connect = @connect;
adapter.prepareSample = @prepareSample;
adapter.release = @(~) []; % One virtual meter retains its settings across connections.
demoInstrument = [];
sampleIntent = struct([]);
if strcmp(mode, 'batch')
    adapter.key = 'PR655DemoBatch';
    adapter.workspaceName = 'colorMeasurePR655DemoBatch';
elseif strcmp(mode, 'gallery')
    adapter.key = 'PR655DemoGallery';
    adapter.workspaceName = 'colorMeasurePR655DemoGallery';
    % The gallery is an explicit automatic preview, separate from the manual
    % demo and real-instrument workflow. Generated files stay in temp storage.
    adapter.label = 'PR-655 synthetic spectrum gallery';
end
fprintf('SYNTHETIC DEMO: generated readings, no physical instrument connection.\n');
session = colormeasure.session.runDemo(adapter, mode, io, folder, struct('reading', 'PR655:DemoReading', ...
    'finish', 'PR655:DemoFinish', 'retained', 'PR655:DemoBatchRetained'), @annotate);
if nargout == 0
    if ~isempty(session)
        assignin('base', adapter.workspaceName, session);
        fprintf('Live demo: %s.measurements\n', adapter.workspaceName);
    end
else
    varargout{1} = session;
end
    function [name, notes] = annotate(sample, name, notes)
        % Repeated and long names exercise selection and plot labelling.
        if ismember(sample, [3 10])
            name = 'Custom sample';
        elseif sample == 8
            name = 'Sample 008 - Magenta mix with a longer descriptive name';
        elseif sample == 12
            notes = sprintf(['%s\nLow-amplitude preview for selection and plot inspection.\n' ...
                'Its base profile has one hundredth of reading 3''s amplitude. ' ...
                'Each exposure adds small brightness jitter; both retain the same chromaticity. ' ...
                'Use the reading number to distinguish repeated sample names.'], notes);
        end
    end
    function prepareSample(intent)
        sampleIntent=intent;
        if ~isempty(demoInstrument)&&isvalid(demoInstrument)
            demoInstrument.prepareSample(intent);
        end
    end
    function instrument = connect(~)
        if isempty(demoInstrument) || ~isvalid(demoInstrument)
            demoInstrument = colormeasure.drivers.pr.DemoInstrument(1, delaySeconds);
        end
        demoInstrument.prepareSample(sampleIntent);
        instrument = demoInstrument;
    end
end

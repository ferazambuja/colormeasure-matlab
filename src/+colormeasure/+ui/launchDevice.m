function [session, workspaceName] = launchDevice(model, io, mode)
% LAUNCHDEVICE Select a catalog entry without probing or opening a port.
%   Each adapter key owns its own retained batch. Selection never changes the
%   instrument of an existing batch. IO uses the ordinary desktop services;
%   chooseDevice and launchSession can be supplied for disconnected tests.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 1, model = ''; end
if nargin < 2 || isempty(io), io = colormeasure.session.services(); end
if nargin < 3, mode = 'measure'; end
mode = validatestring(mode, colormeasure.session.catalogModes());
io = colormeasure.ui.services(io);
if ~isfield(io, 'chooseDevice'), io.chooseDevice = @chooseDevice; end
session = []; workspaceName = '';
catalog = colormeasure.ui.deviceCatalog();
if isempty(catalog)
    error('Measurement:NoAdapters', 'No measurement window adapters are installed. Check that this installation includes its drivers.');
end
if ~((ischar(model) && (isrow(model) || isempty(model))) || ...
        (isstring(model) && isscalar(model) && ~ismissing(model)))
    error('Measurement:Device', 'Specify one catalog model: %s.', strjoin({catalog.model}, ', '));
end
model = upper(regexprep(char(model), '[-\s]', ''));
if isempty(model)
    index = io.chooseDevice({catalog.label}');
    if isempty(index) || isequal(index, 0), return; end
    if ~isnumeric(index) || ~isscalar(index) || ~isfinite(index) || ...
            index ~= fix(index) || index < 1 || index > numel(catalog)
        error('Measurement:Device', 'Select one available instrument.');
    end
else
    if strcmp(model,'PR670'), model='PR655'; end
    if strcmp(model,'CS2000A'), model='CS2000'; end
    index = find(strcmp({catalog.model}, model), 1);
    if isempty(index)
        error('Measurement:Device', 'Unknown or unavailable instrument: %s.', model);
    end
end
if strcmp(mode,'measure')
    % The generic selector requests a model, not new connection settings.
    % Restore the retained configuration; explicit family launchers still
    % reject conflicting caller-supplied options through colormeasure.ui.launchSession.
    colormeasure.session.assertSessionCompatible();
    session = colormeasure.ui.retainedSession(catalog(index));
    if ~isempty(session)
        colormeasure.session.assertSessionCompatible(metaclass(session));
        workspaceName = session.workspaceName;
        session.show();
        return
    end
end
factory = catalog(index).factory;
adapter = factory();
if isempty(adapter),return;end
workspaceName = adapter.workspaceName;
if strcmp(mode,'measure')
    session = io.launchSession(adapter, io);
else
    factory = catalog(index).demoFactory;
    if isempty(factory)
        error('Measurement:Device', ...
            'The %s entry has no simulated demo in the chooser; use its dedicated demo.', catalog(index).label);
    end
    session = factory(mode);
    if ~isempty(session), workspaceName = session.workspaceName; end
end
end

function index = chooseDevice(labels)
[index, accepted] = listdlg('ListString', labels, 'SelectionMode', 'single', ...
    'Name', 'Measurement instrument', 'PromptString', 'Choose the instrument:', ...
    'OKString', 'Open batch', 'CancelString', 'Cancel', 'ListSize', [300 145]);
if ~accepted, index = 0; end
end

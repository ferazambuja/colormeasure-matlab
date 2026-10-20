function target = switchDevice(source, model, io)
% SWITCHDEVICE Open a model's separate batch, saving a paused source chart.
%   Restore retained connection options instead of reconstructing defaults.
%   The caller hides its source view only after this operation succeeds.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 3, io = colormeasure.session.services(); end
target = [];
targetWasVisible=false;
colormeasure.session.assertSessionCompatible();
if ~isa(source,'colormeasure.session.Session') || ~isscalar(source) || ~isvalid(source)
    error('Measurement:DeviceSession','An active measurement session is required.');
end
if source.busy || (source.finishing && ~source.finished), return; end
[catalog,current,mode] = colormeasure.ui.deviceCatalog(source.catalogIdentity);
if isempty(current)
    error('Measurement:DeviceSession','This custom session has no instrument selector.');
end
assertSourceOwner(source);
if ~((ischar(model) && isrow(model)) || ...
        (isstring(model) && isscalar(model) && ~ismissing(model)))
    error('Measurement:Device','Select one available instrument.');
end
index = find(strcmp({catalog.model},char(model)),1);
if isempty(index)
    error('Measurement:Device','Select one available instrument.');
end
if index == current
    target = source;
else
    chart=source.chart;
    assert(isempty(chart)||~chart.unsaved,'Measurement:ChartSave', ...
        'Use Retry save before switching instruments. The source chart remains available.');
    target = colormeasure.ui.retainedSession(catalog(index),mode);
    if ~isempty(target)
        colormeasure.session.assertSessionCompatible(metaclass(target));
        targetWasVisible=isgraphics(target.window)&&strcmp(target.window.Visible,'on');
    else
        target = colormeasure.ui.launchDevice(catalog(index).model,io,mode);
        if isempty(target), return; end
    end
end
if ~isa(target,'colormeasure.session.Session') || ~isscalar(target) || ~isvalid(target)
    error('Measurement:DeviceSession','The instrument launcher did not return a valid session.');
end
chart=source.chart;
if target~=source&&~source.finished&&~isempty(chart)&&~chart.paused
    try
        saved=source.pauseChart();
    catch problem
        if ~targetWasVisible,target.hide();end
        rethrow(problem);
    end
    if ~saved
        if ~targetWasVisible,target.hide();end
        error('Measurement:ChartSave', ...
            'The source chart could not be saved. Use Retry save before switching instruments.');
    end
end
target.show();
if ~isgraphics(target.window) || ~strcmp(get(target.window,'Visible'),'on')
    error('Measurement:DeviceWindow','The instrument window could not be opened.');
end
name = target.workspaceName;
if isvarname(name), assignin('base',name,target); end
% A window may belong to a directly constructed Session. Retain that exact
% source only after success, without changing the launcher's parent-folder
% preference. Never replace a different registered batch with the same key.
registry = assertSourceOwner(source);
if ~any(strcmp(registry.keys,source.adapterKey))
    colormeasure.session.sessionRegistry('put',source.adapterKey,source,registry.lastFolder);
end
end

function registry = assertSourceOwner(source)
registry = colormeasure.session.sessionRegistry('get');
index = find(strcmp(registry.keys,source.adapterKey),1);
if ~isempty(index) && registry.sessions{index} ~= source
    error('Measurement:DeviceSessionOwnership', ...
        ['Another batch for this instrument is already retained. Open its window ' ...
        'to switch instruments; this batch and its readings remain available.']);
end
end

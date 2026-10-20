function adapter = validateAdapter(adapter)
%VALIDATEADAPTER Check an instrument adapter against docs/session/adapters.md.
%   Direct adapters supply key, label, listPorts, connect, read, release and
%   toTable. Connection owners may attach Measurement:ConnectCleanupConfirmed only
%   after proving no outstanding host I/O. Unmarked connection failures keep
%   the chart's durable stop guard; an empty handle is not cleanup evidence.
%   Operation-adapter fields such as operationContext are refused.
%   Optional direct hooks and fields are type-checked when present. Preparation
%   headings must be a text list with at most one heading per details entry.
%   Validation performs no I/O and never calls a hook, so a
%   missing or mistyped hook fails when the session is constructed rather
%   than at the first reading, export or window action.
%   Errors use Measurement:AdapterContract.
%   Fernando Voltolini de Azambuja, 2026.
assert(isstruct(adapter) && isscalar(adapter), 'Measurement:AdapterContract', ...
    'An adapter must be one struct of hooks.');
requireText(adapter, 'key');
assert(~any(isfield(adapter,{'operationContext','operationClient','snapshot','viewOptions', ...
    'projectOperations','eventValidator','connectionReadiness','nextBatchAdapter'})), 'Measurement:AdapterContract', ...
    'This installation accepts current direct serial adapters only.');
requireText(adapter, 'label');
for name = {'listPorts','connect','read','release','toTable'}
    assert(isfield(adapter, name{1}), 'Measurement:AdapterContract', ...
        'Direct adapters require the %s hook.', name{1});
    requireHook(adapter, name{1});
end
optionalHook(adapter, 'viewData');
optionalHook(adapter, 'toTable');
optionalHook(adapter, 'csvAvailability');
optionalHook(adapter, 'prepareSample');
if isfield(adapter, 'settings')
    settings = adapter.settings;
    assert(isstruct(settings) && isscalar(settings) && all(isfield(settings, {'catalog','read','apply'})), ...
        'Measurement:AdapterContract', 'settings must supply catalog, read and apply.');
    requireHook(settings, 'read');
    requireHook(settings, 'apply');
    % The editor renders this static catalog before any readback; check it
    % here with the readback rules rather than at a later window action.
    colormeasure.session.validateSettingsCatalog(settings.catalog, 'Measurement:AdapterContract');
end
if isfield(adapter, 'preparation')
    preparation = adapter.preparation;
    assert(isstruct(preparation) && isscalar(preparation) && ...
        colormeasure.session.isPlainData(preparation), ...
        'Measurement:AdapterContract', 'preparation must be one struct of ordinary data.');
    if isfield(preparation, 'headings')
        assert(isfield(preparation, 'details') && isTextList(preparation.details) && ...
            isTextList(preparation.headings) && numel(preparation.headings) <= numel(preparation.details), ...
            'Measurement:AdapterContract', 'preparation.headings must be text, at most one per details entry.');
    end
end
if isfield(adapter, 'configuration')
    assert(colormeasure.session.isPlainData(adapter.configuration), ...
        'Measurement:AdapterContract', 'configuration must be ordinary data.');
end
for name = {'workspaceName','configurationSummary'}
    if isfield(adapter, name{1})
        assert(colormeasure.session.isText(adapter.(name{1})), 'Measurement:AdapterContract', ...
            'Adapter %s must be text.', name{1});
    end
end
if isfield(adapter, 'catalog')
    entry = adapter.catalog;
    assert(isstruct(entry) && isscalar(entry) && all(isfield(entry, {'model','mode'})) && ...
        colormeasure.session.isText(entry.model) && strlength(string(entry.model))>0 && colormeasure.session.isText(entry.mode) && ...
        any(strcmp(entry.mode,colormeasure.session.catalogModes())), 'Measurement:AdapterContract', ...
        'catalog must name a nonempty model and one of these modes: %s.', ...
        strjoin(colormeasure.session.catalogModes(),', '));
end
if isfield(adapter,'prepareSample')
    assert(isfield(adapter,'catalog')&& ...
        any(strcmp(adapter.catalog.mode,{'interactive','batch','gallery'})), ...
        'Measurement:AdapterContract','prepareSample is a direct synthetic-demo hook only.');
end
end

function requireText(s, name)
assert(isfield(s, name) && colormeasure.session.isText(s.(name)) && strlength(string(s.(name))) > 0, ...
    'Measurement:AdapterContract', 'Adapter %s must be nonempty text.', name);
end


function yes = isTextList(value)
% The list forms the preparation dialog renders: a cellstr or a string array.
yes = iscellstr(value) || (isstring(value) && ~any(ismissing(value(:))));
end

function requireHook(s, name)
assert(isa(s.(name), 'function_handle') && isscalar(s.(name)), ...
    'Measurement:AdapterContract', 'Adapter %s must be a function handle.', name);
end

function optionalHook(s, name)
if isfield(s, name), requireHook(s, name); end
end

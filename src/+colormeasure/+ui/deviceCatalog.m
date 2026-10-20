function [catalog, current, mode] = deviceCatalog(identity)
% DEVICECATALOG Bundled instrument windows and their exact session identities.
%   [catalog, current, mode] = deviceCatalog(identity) lists the installed
%   direct PR, CR and CS instrument families. Listing does not add paths,
%   enumerate ports or construct an adapter; factories do that when called.
%   identity is the model and mode explicitly declared by the adapter and
%   exposed through session.catalogIdentity. Registry keys identify batch
%   ownership; their spelling never selects a model or mode. An adapter that
%   declares no catalog identity has no selected entry.
%   Fernando Voltolini de Azambuja, 2026.
arguments
    identity (1,1) struct=struct()
end
drivers = fullfile(colormeasure.root(),'src','+colormeasure','+drivers');
entries = { ...
    'PR655', 'PR-655 / PR-670 (tentative)', '+pr', @() colormeasure.drivers.pr.uiAdapter(), @(kind) colormeasure.drivers.pr.demoSession(kind); ...
    'CR100', 'CR-100 (XYZ only)', '+cr', @() colormeasure.drivers.cr.uiAdapter('CR100'), @(kind) colormeasure.drivers.cr.demoSession('CR100',kind); ...
    'CR250', 'CR-250', '+cr', @() colormeasure.drivers.cr.uiAdapter('CR250'), @(kind) colormeasure.drivers.cr.demoSession('CR250',kind); ...
    'CR300', 'CR-300', '+cr', @() colormeasure.drivers.cr.uiAdapter('CR300'), @(kind) colormeasure.drivers.cr.demoSession('CR300',kind); ...
    'CS2000', 'CS-2000 / CS-2000A', '+cs2000', @() colormeasure.drivers.cs2000.uiAdapter(), @(kind) colormeasure.drivers.cs2000.demoSession(kind)};
catalog = struct('model',{},'label',{},'folder',{},'factory',{},'demoFactory',{});
for index = 1:size(entries,1)
    folder = fullfile(drivers,entries{index,3});
    if isfile(fullfile(folder,'uiAdapter.m'))
        catalog(end+1) = struct('model',entries{index,1}, ...
            'label',entries{index,2},'folder',folder, ...
            'factory',entries{index,4},'demoFactory',entries{index,5}); %#ok<AGROW>
    end
end
[current, mode] = match(catalog, identity);
end

function [current, mode] = match(catalog, identity)
current = []; mode = '';
if all(isfield(identity,{'model','mode'})) && ~isempty(identity.model)
    modes = colormeasure.session.catalogModes();
    for index = 1:numel(catalog)
        if strcmp(catalog(index).model,char(identity.model)) && any(strcmp(modes,char(identity.mode)))
            current = index; mode = char(identity.mode); return
        end
    end
end
end

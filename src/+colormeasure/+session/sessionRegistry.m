function registry = sessionRegistry(action, key, session, folder)
% SESSIONREGISTRY Own sessions for the lifetime of this MATLAB process.
%   Root appdata survives ordinary workspace/function clearing. It is not a
%   disk checkpoint and is not restored when MATLAB exits or crashes.
%   Fernando Voltolini de Azambuja, 2026.
name = 'ColorMeasureSessions';
registry = getappdata(groot, name);
if isempty(registry)
    registry = struct('keys', {{}}, 'sessions', {{}}, 'lastFolder', '');
end
% Explicitly deleted handles must not prevent the next launcher from opening.
valid = cellfun(@(value) isa(value, 'colormeasure.session.Session') && isvalid(value), registry.sessions);
registry.keys = registry.keys(valid);
registry.sessions = registry.sessions(valid);
switch action
    case 'get'
        % Persist pruning below, even for a read.
    case 'put'
        index = find(strcmp(registry.keys, key), 1);
        if isempty(index)
            registry.keys{end+1} = key;
            registry.sessions{end+1} = session;
        else
            registry.sessions{index} = session;
        end
        registry.lastFolder = folder;
    otherwise
        error('Measurement:RegistryAction', 'Unknown session registry action: %s.', action);
end
setappdata(groot, name, registry);
end

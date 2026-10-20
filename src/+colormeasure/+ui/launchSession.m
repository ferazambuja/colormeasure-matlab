function session = launchSession(adapter, io, initialFolder, forceNew, destination)
% LAUNCHSESSION Open or restore the window for an instrument adapter.
%   Ownership lives in root appdata, so clear functions/clear all do not create
%   a second batch. A finished session stays available until New batch is used.
%   The optional fourth argument requests a new batch after the retained batch
%   is finished and idle. Session.newBatch passes it. The optional fifth argument is an
%   already selected initial destination. It bypasses only this folder prompt;
%   Session retains the supplied services for recovery and later batches.
%   Fernando Voltolini de Azambuja, 2026.
colormeasure.session.assertSessionCompatible();
if nargin < 2, io = colormeasure.session.services(); end
io = colormeasure.ui.services(io);
registry = colormeasure.session.sessionRegistry('get');
if nargin < 3, initialFolder = registry.lastFolder; end
if nargin < 4, forceNew = false; end
index = find(strcmp(registry.keys, adapter.key), 1);
if ~isempty(index)
    previous = registry.sessions{index};
    colormeasure.session.assertSessionCompatible(metaclass(previous));
    if forceNew&&previous.finished&&previous.chartIoUnconfirmed
        previous.show();
        error('Measurement:ConnectionCleanupUnconfirmed', ...
            'Connection cleanup is unconfirmed. Resolve it in the open batch before starting a new batch.');
    end
    if forceNew&&previous.finished&&previous.needsRecovery
        previous.show();
        error('Measurement:SaveRecovery', ...
            'Save needs attention. Use Retry save or Another folder before starting a new batch.');
    end
    if ~forceNew || ~previous.finished || previous.busy
        requested = struct();
        if isfield(adapter,'configuration'), requested = adapter.configuration; end
        if ~isequaln(requested,previous.configuration)
            error('Measurement:SessionConfiguration', ...
                ['This model already has a retained batch with different connection settings. ' ...
                'Finish that batch, keep its saved files or a copy of its measurements, ' ...
                'then delete its session handle and launch again with the new settings.']);
        end
        session = previous;
        session.show();
        fprintf('Restored session started %s | %s.\nSave destination: %s\n', session.startedAtUTC, ...
            colormeasure.session.counted(numel(session.measurements), 'reading', 'readings'), session.destination);
        fprintf('The session has no automatic expiry. Finish batch ends acquisition; New batch replaces the view.\n');
        if isfield(adapter, 'workspaceName') && isvarname(adapter.workspaceName)
            fprintf('The bare launcher stores this handle as %s.\n', adapter.workspaceName);
        end
        return
    end
end
if nargin < 5 || isempty(destination)
    folder = io.chooseFolder(initialFolder);
else
    folder = destination;
end
if isempty(folder)
    session = [];
    return
end
session = colormeasure.session.Session(adapter, folder, io);
try
    session.show();
catch err
    delete(session);
    rethrow(err)
end
% Publish only after construction and UI setup succeed. Cancellation/failure
% leaves the previous registry entry and its completed view untouched.
colormeasure.session.sessionRegistry('put', adapter.key, session, folder);
if forceNew && isfield(adapter, 'workspaceName') && isvarname(adapter.workspaceName)
    assignin('base', adapter.workspaceName, session);
    fprintf('New batch: %s.measurements. Previous session handles remain readable.\n', adapter.workspaceName);
end
end

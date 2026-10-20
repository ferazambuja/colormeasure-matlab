function session = runDemo(adapter, mode, io, folder, ids, annotate)
% RUNDEMO Run a family's synthetic demo session in one of its three modes.
%   batch saves two synthetic readings without a window. If a reading or the
%   final save fails, the incomplete session is kept in the base workspace
%   under adapter.workspaceName, an ids.retained warning names it, and the
%   ids.reading or ids.finish error is rethrown. interactive opens the
%   session window. gallery keeps its files in folder and fills a session it
%   newly opens with the twelve synthetic profiles; repeating the command
%   restores that session. annotate optionally names and notes gallery samples.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 6, annotate = {}; else, annotate = {annotate}; end
if strcmp(mode,'batch')
    session = colormeasure.session.Session(adapter,folder,io);
    try
        colormeasure.session.demoBatch(session,2,ids.reading,ids.finish);
    catch problem
        % A throwing call cannot return its session. Keep complete readings
        % and diagnostics, including unsaved results, where the caller finds them.
        assignin('base',adapter.workspaceName,session);
        warning(ids.retained,'Incomplete synthetic batch retained as %s; inspect its log and save errors.', ...
            adapter.workspaceName);
        rethrow(problem);
    end
    return
end
if strcmp(mode,'gallery'), io.chooseFolder = @(~) folder; end
registry = colormeasure.session.sessionRegistry('get');
populate = strcmp(mode,'gallery') && ~ismember(adapter.key,registry.keys);
session = colormeasure.ui.launchSession(adapter,io,folder);
if populate && ~isempty(session)
    fprintf('Creating a 12-reading synthetic gallery; MAT snapshots are saved under %s.\n',folder);
    colormeasure.session.demoGallery(session,colormeasure.simulation.syntheticProfiles(),annotate{:});
end
end

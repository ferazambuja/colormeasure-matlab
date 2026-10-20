function disposeBatch(session)
%DISPOSEBATCH Delete a session and its own batch folder; other batches stay.
if isempty(session) || ~isvalid(session), return; end
folder = session.files.folder; delete(session);
if ~isempty(folder) && isfolder(folder), rmdir(folder,'s'); end
end

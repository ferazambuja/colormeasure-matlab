function saveMatFile(filename, variables, replaceExisting)
%SAVEMATFILE Stage named MAT variables and publish in the same directory.
%   Replacing uses movefile; exclusive publication creates a hard link and
%   refuses an occupied name. Failed publication removes the staged file.
%   Staging reduces partial-write exposure; it is not a durability guarantee.
%   Callers validate their record and destination and wrap failures for their
%   own API. Exclusive publication needs a filesystem with hard links; on
%   exFAT, FAT32 and many SMB mounts it fails as Measurement:SaveLinkFailed
%   and the staged file is removed. An occupied name keeps Java's
%   FileAlreadyExistsException, so callers can report it as such.
%   Fernando Voltolini de Azambuja, 2026.
[parent,~,~] = fileparts(filename);
if isempty(parent), parent = pwd; end
[found,folder] = fileattrib(parent);
assert(found && isscalar(folder) && folder.directory, 'Measurement:SavePath', ...
    'Choose a MAT file in an existing folder.');
[~,stem,extension] = fileparts(filename);
filename = fullfile(folder.Name,[stem extension]);
assert(~isfolder(filename), 'Measurement:SavePath', ...
    'The MAT destination is a directory: %s', filename);
staged = [tempname(folder.Name) '.part.mat'];
cleanup = onCleanup(@() removeStaged(staged));
save(staged,'-struct','variables','-v7');
if replaceExisting
    movefile(staged,filename,'f');
else
    try
        java.nio.file.Files.createLink(java.io.File(filename).toPath(), ...
            java.io.File(staged).toPath());
    catch problem
        if contains(problem.message,'FileAlreadyExistsException'), rethrow(problem); end
        error('Measurement:SaveLinkFailed', ['Exclusive publication creates a hard link, which ' ...
            'this folder''s filesystem may not support (exFAT, FAT32 and many SMB mounts do not). ' ...
            'Choose a folder on a local disk. Cause: %s'], problem.message);
    end
end
end

function removeStaged(filename)
if isfile(filename), delete(filename); end
end

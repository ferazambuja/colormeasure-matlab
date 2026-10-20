function filename = exportPR655Csv(matFilename, filename)
% EXPORTPR655CSV Regenerate the supporting CSV from a saved measurement MAT.
%   colormeasure.drivers.pr.exportPR655Csv opens a MAT-file picker. colormeasure.drivers.pr.exportPR655Csv(matFilename) writes
%   measurements.csv beside the selected MAT; a second argument changes its path.
%   An existing .csv is replaced after the new staged export succeeds.
%   The source MAT is never a valid export destination, even under an alias.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0, 2);
if nargin == 0
    [file, folder] = uigetfile('*.mat', 'Export a saved measurement batch to CSV');
    if isequal(file, 0)
        filename = '';
        return
    end
    matFilename = fullfile(folder, file);
end
matFilename = resolveMatSource(matFilename);
if nargin < 2
    filename = fullfile(fileparts(matFilename), 'measurements.csv');
end
% Compare existing file identity, not just suffixes or path spelling. This
% covers relative paths, symbolic links, hard links and a CSV-named MAT file.
if isfile(filename)
    source = java.io.File(char(matFilename));
    destination = java.io.File(char(filename));
    if java.nio.file.Files.isSameFile(source.toPath(), destination.toPath())
        error('PR655:ExportSource', 'Choose a CSV destination different from the source MAT: %s', filename);
    end
end
saved = load(matFilename, 'measurements', 'batchInfo', '-mat');
if ~all(isfield(saved, {'measurements','batchInfo'}))
    error('PR655:ExportSource','The source MAT must contain measurements and batchInfo.');
end
colormeasure.session.exportCsv(saved.measurements, saved.batchInfo, filename, @colormeasure.drivers.pr.batchTable);
fprintf('CSV exported: %s\n', filename);
end

function filename = resolveMatSource(filename)
% Resolve once, then use exactly this path for identity checks and loading.
% MATLAB load also searches its path and accepts a missing .mat extension.
filename = char(filename);
[~, ~, extension] = fileparts(filename);
if isempty(extension)
    filename = [filename '.mat'];
end
if ~isfile(filename)
    filename = which(filename);
end
if isempty(filename) || ~isfile(filename)
    error('PR655:MatSource', 'The source MAT file could not be found. Specify its full path.');
end
file = java.io.File(filename);
filename = char(file.getCanonicalPath());
end

function folder = createMeasurementFolder(parent, name, timestamp)
% CREATEMEASUREMENTFOLDER Reserve a new output folder without reusing old data.
%   Fernando Voltolini de Azambuja, 2026.

if ~isfolder(parent)
    error('Measurement:SaveFolder', 'The selected save folder no longer exists: %s', parent);
end
% Keep a portable filename; preserve the original label inside both data files.
stem = regexprep(char(name), '[^A-Za-z0-9_-]', '_');
stem = stem(1:min(numel(stem), 60));
if isempty(stem) || all(stem == '_')
    stem = 'measurement';
end
timestamp.TimeZone = 'UTC';
timestamp.Format = 'yyyyMMdd_HHmmss_SSS';
base = [stem '_' char(timestamp)];
for index = 1:10000
    if index == 1
        suffix = '';
    else
        suffix = sprintf('_%03d', index);
    end
    folder = fullfile(parent, [base suffix]);
    % Java mkdir atomically succeeds only for a new directory. MATLAB mkdir
    % also reports success for existing folders, which must never be reused.
    candidate = java.io.File(folder);
    if candidate.mkdir()
        return
    elseif ~candidate.exists()
        error('Measurement:SaveFolder', ...
            'Cannot create a measurement folder in %s. Choose a writable location.', parent);
    end
end
error('Measurement:SaveFolder', 'Could not choose an unused measurement folder in %s.', parent);
end

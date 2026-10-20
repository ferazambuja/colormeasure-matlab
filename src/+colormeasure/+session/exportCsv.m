function digest=exportCsv(measurements, batchInfo, filename, toTable)
% EXPORTCSV Export an instrument adapter's table using a staged replacement.
%   The destination must end in .csv. Repeated exports replace that CSV
%   only after table writing and its byte witness succeed. The returned
%   SHA-256 names the exact staged bytes published by this call.
%   Fernando Voltolini de Azambuja, 2026.
try
    [folder, ~, extension] = fileparts(filename);
    if ~strcmpi(extension, '.csv')
        error('Measurement:CsvExtension', 'The export destination must end in .csv: %s', filename);
    end
    if isempty(folder)
        folder = pwd;
    end
    staged = [tempname(folder) '.part.csv'];
    cleanup = onCleanup(@() removeStaged(staged));
    if isfolder(filename)
        error('Measurement:SavePath', 'The CSV destination is a directory: %s', filename);
    end
    data = toTable(measurements, batchInfo);
    % Quoting alone does not prevent spreadsheet formula evaluation. Escape
    % only textual cells at this publication boundary; MAT and analysis
    % tables retain their exact source identifiers, notes and other text.
    data = literalText(data);
    % Quote every text value, including lone CR/LF characters in names or serials.
    writetable(data, staged, 'QuoteStrings','all');
    digest=colormeasure.fileDigest(staged);
    movefile(staged, filename, 'f');
catch err
    wrapped = MException('Measurement:CsvSaveFailed', 'CSV export failed: %s', err.message);
    throw(addCause(wrapped, err));
end
end

function data=literalText(data)
for name=data.Properties.VariableNames
    values=data.(name{1});
    if isstring(values)
        for index=1:numel(values)
            if ~ismissing(values(index)),values(index)=string(literal(char(values(index))));end
        end
    elseif iscell(values)
        for index=1:numel(values)
            if ischar(values{index})&&(isrow(values{index})||isempty(values{index}))
                values{index}=literal(values{index});
            elseif isstring(values{index})&&isscalar(values{index})&&~ismissing(values{index})
                values{index}=string(literal(char(values{index})));
            end
        end
    end
    data.(name{1})=values;
end
end

function value=literal(value)
if ~isempty(regexp(value,'^\s*[=+\-@]','once'))|| ...
        (~isempty(value)&&ismember(value(1),sprintf('\t\r\n')))
    value=['''' value];
end
end

function removeStaged(filename)
if isfile(filename)
    delete(filename);
end
end

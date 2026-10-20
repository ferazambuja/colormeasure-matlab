function value = isPlainData(data)
%ISPLAINDATA True for values safe to persist: no objects, handles or connections.
%   Structs and cells are checked recursively. Numeric, logical, char, string,
%   datetime and duration values are plain.
%   Fernando Voltolini de Azambuja, 2026.
if isstruct(data)
    value = true;
    fields = fieldnames(data);
    for index = 1:numel(data)
        for field = 1:numel(fields)
            if ~colormeasure.session.isPlainData(data(index).(fields{field}))
                value = false;
                return
            end
        end
    end
elseif iscell(data)
    value = all(cellfun(@colormeasure.session.isPlainData, data(:)));
else
    value = isnumeric(data) || islogical(data) || ischar(data) || isstring(data) || ...
        isa(data, 'datetime') || isa(data, 'duration');
end
end

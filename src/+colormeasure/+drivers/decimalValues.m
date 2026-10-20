function values = decimalValues(payload, count, prefix)
%DECIMALVALUES Parse finite comma-separated decimals without executing expressions.
%   COUNT=[] accepts the framed payload's field count. PREFIX binds errors to
%   the calling driver family; family-specific sentinels are checked there.
%   Fernando Voltolini de Azambuja, 2026.
fields = strsplit(strtrim(char(payload)),',','CollapseDelimiters',false);
pattern = '^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$';
if (~isempty(count) && numel(fields)~=count) || ...
        any(cellfun(@(value) isempty(regexp(strtrim(value),pattern,'once')),fields))
    error([prefix ':NumericPayload'],'Unexpected number or format of decimal response fields.');
end
values = cellfun(@str2double,fields);
mantissas=regexprep(fields,'[eE].*$','');
nonzero=cellfun(@(value)~isempty(regexp(value,'[1-9]','once')),mantissas);
if any(values==0 & nonzero)
    error([prefix ':NumericPayload'],'A nonzero protocol value underflows to zero.');
end
if any(~isfinite(values))
    error([prefix ':NumericPayload'],'Protocol values must be finite.');
end
end

function value = textValue(value)
%TEXTVALUE Normalize optional scalar analysis text; malformed values are empty.
if isstring(value) && isscalar(value) && ~ismissing(value), value=char(value); end
if ~ischar(value) || (~isrow(value) && ~isempty(value)), value=''; end
end

function value = textField(record, name)
%TEXTFIELD One text field of a reading or record as char, or '' when absent.
%   Shared by the family viewData functions; a missing field, a non-text
%   value or a missing string all read as empty text.
%   Fernando Voltolini de Azambuja, 2026.
value = '';
if ~isfield(record, name), return, end
candidate = record.(name);
if (ischar(candidate) && (isrow(candidate) || isempty(candidate))) || ...
        (isstring(candidate) && isscalar(candidate) && ~ismissing(candidate))
    value = char(candidate);
end
end

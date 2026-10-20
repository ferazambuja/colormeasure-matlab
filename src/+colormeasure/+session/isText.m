function yes = isText(value)
%ISTEXT One nonmissing string or a character row; empty character rows are valid.
%   Callers separately require nonempty text where their contract needs it.
%   Fernando Voltolini de Azambuja, 2026.
yes = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value));
end

function value = fieldOr(record, name, fallback)
%FIELDOR Read an optional current record field without changing its value.
%   Unannotated driver readings can omit host-session names, notes and timing;
%   analysis configurations can omit their optional settings.
%   Required record fields must be validated and read directly by their caller.
%   Fernando Voltolini de Azambuja, 2026.
value = fallback;
if isfield(record,name), value = record.(name); end
end

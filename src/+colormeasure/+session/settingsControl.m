function item = settingsControl(id, label, type, choices, minimum, maximum, available, help)
%SETTINGSCONTROL One plain settings control, as documented in docs/session/adapters.md.
%   Families build their catalogs through this constructor so every control has
%   the same fields and the window never meets a partial one. Constructing a
%   control performs no I/O. With no arguments it returns an empty 0-by-1
%   control array with the same fields, for catalogs that grow by appending.
%   Fernando Voltolini de Azambuja, 2026.
if nargin == 0
    item = repmat(colormeasure.session.settingsControl('template', '', 'number', ...
        struct('value', {}, 'label', {}), NaN, NaN, false, ...
        struct('meaning', '', 'whenToUse', '', 'tradeoff', '', 'normal', '', 'source', '')), 0, 1);
    return
end
% Braces keep each argument whole, so a cell argument is refused, not expanded.
item = struct('id', {id}, 'label', {label}, 'type', {type}, 'choices', {choices}, ...
    'minimum', {minimum}, 'maximum', {maximum}, 'available', {available}, 'help', {help});
% The same rules the session applies to adapter catalogs and settings readback.
colormeasure.session.validateSettingsCatalog(item, 'Measurement:SettingsControl');
item.id = char(id); item.label = char(label); item.type = char(type);
item.minimum = double(minimum); item.maximum = double(maximum);
end

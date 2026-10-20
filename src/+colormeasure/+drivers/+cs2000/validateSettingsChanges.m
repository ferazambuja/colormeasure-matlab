function changes = validateSettingsChanges(changes)
%VALIDATESETTINGSCHANGES Validate explicit values before any device access.
% Coupled settings and actual capabilities are checked by settingsPlan.
% Fernando Voltolini de Azambuja, 2026.
if ~isstruct(changes) || ~isscalar(changes)
    error('CS2000:SettingsArguments','Settings changes must be one scalar struct.');
end
catalog = colormeasure.drivers.cs2000.settingsCatalog();
names = fieldnames(changes);
for k = 1:numel(names)
    name = names{k}; index = find(strcmp({catalog.id},name));
    if isempty(index) || strcmp(name,'measurementAngleDegrees')
        error('CS2000:SettingsArguments','Unknown or read-only setting: %s.',name);
    end
    value = changes.(name); item = catalog(index);
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
        error('CS2000:SettingsArguments','%s must be one finite real numeric value.',name);
    end
    if strcmp(item.type,'choice')
        valid = ismember(value,[item.choices.value]);
    else
        valid = value >= item.minimum && value <= item.maximum;
    end
    if ~valid
        error('CS2000:SettingsArguments','%s is outside its documented range.',name);
    end
    if strcmp(name,'frequencyHz') && abs(value*100-round(value*100)) > 1e-6
        error('CS2000:SettingsArguments','Frequency must use whole 0.01 Hz increments.');
    end
    if strcmp(name,'integrationTimeSeconds') && abs(value*1e6-round(value*1e6)) > 1e-6
        error('CS2000:SettingsArguments','Integration time must use whole microseconds.');
    end
    changes.(name) = double(value);
end
end

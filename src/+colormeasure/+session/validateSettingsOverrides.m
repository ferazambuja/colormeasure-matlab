function validateSettingsOverrides(overrides, controls)
% VALIDATESETTINGSOVERRIDES Check staged values without instrument I/O.
%   This checks the known catalog only. The driver must revalidate actual
%   capabilities and coupled settings before the first setting write.
%   Fernando Voltolini de Azambuja, 2026.
if ~isstruct(overrides) || ~isscalar(overrides)
    error('Measurement:InvalidSettings', 'Settings overrides must be a scalar struct.');
end
names = fieldnames(overrides);
for index = 1:numel(names)
    name = names{index};
    match = [];
    if ~isempty(controls) && isfield(controls, 'id')
        match = find(strcmp({controls.id}, name));
    end
    if numel(match) ~= 1
        error('Measurement:UnknownSetting', 'Unknown instrument setting: %s.', name);
    end
    control = colormeasure.session.settingsControlForValues(controls(match),overrides);
    if ~isfield(control, 'available') || ~isequal(control.available, true)
        % A control the catalog offers can still be unavailable for the
        % staged context (a CS interval under Normal or Fast); say that
        % reason rather than sending the operator back to a readback.
        reason = 'Read the instrument settings to check its capabilities.';
        if isequal(controls(match).available, true) && isfield(control, 'help') && ...
                isfield(control.help, 'meaning') && ~isempty(control.help.meaning)
            reason = control.help.meaning;
        end
        error('Measurement:SettingUnavailable', 'Setting %s is unavailable. %s', name, reason);
    end
    value = overrides.(name);
    switch control.type
        case 'number'
            valid = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
            if valid && isfinite(control.minimum), valid = value >= control.minimum; end
            if valid && isfinite(control.maximum), valid = value <= control.maximum; end
            if valid && isfield(control,'editor') && isfield(control.editor,'kind')
                editor=control.editor;
                if strcmp(editor.kind,'automaticNumber')
                    valid=isequal(value,editor.automaticValue)||value>=editor.fixedMinimum;
                end
                if valid&&isfield(editor,'integer')&&editor.integer,valid=value==fix(value);end
                if valid&&isfield(editor,'incrementScale')
                    scaled=value*editor.incrementScale;
                    valid=abs(scaled-round(scaled))<=editor.incrementTolerance;
                end
            end
        case 'choice'
            valid = ~isempty(colormeasure.session.settingsChoiceIndex(control.choices,value));
        otherwise
            error('Measurement:InvalidSettingsCatalog', 'Unknown control type for %s.', name);
    end
    if ~valid
        error('Measurement:InvalidSetting', 'Invalid value for instrument setting %s.', name);
    end
end
end

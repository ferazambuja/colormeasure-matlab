function validateSettingsCombination(requested, before, model)
%VALIDATESETTINGSCOMBINATION Validate one proposed configuration without I/O.
% before is a readSettings value report (controls and values); demos may supply
% an explicitly synthetic report. No device changes or acquisition occur here.
% Remote 1.36 sections 4.2/4.3; App 1.5.10 pp.20,23,78.
% CR100 Colorimeter mode is an internal automatic-policy field; the public
% native applySettings argument validator rejects a caller-supplied mode.
[~, model] = colormeasure.drivers.cr.modelInfo(model);
spectral = ~strcmp(model,'CR-100');
if ~isstruct(requested) || ~isscalar(requested)
    error('CR:SettingsArgument','Settings must be a scalar struct of named values.');
end
target = before.values; controls = before.controls;
fields = fieldnames(requested);
for k = 1:numel(fields)
    id = fields{k}; control = controls(strcmp({controls.id},id)); value = requested.(id);
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
        error('CR:SettingsArgument','%s requires a finite numeric scalar.',id);
    end
    value = double(value);
    if strcmp(id,'exposureMultiplier') && fix(value)~=value
        error('CR:SettingsArgument','exposureMultiplier requires an integer.');
    end
    automaticMode = strcmp(id,'mode') && ~spectral && ...
        strcmp(colormeasure.drivers.cr.settingLabel(controls,requested,'mode'),'Colorimeter');
    if isempty(control) || (~control.available && ~automaticMode)
        error('CR:SettingsUnavailable','%s is not available on the connected instrument.',id);
    end
    if strcmp(control.type,'choice')
        valid = ismember(value,[control.choices.value]);
    else
        valid = value>=control.minimum && value<=control.maximum;
    end
    if ~valid, error('CR:SettingsArgument','%s is outside the reported choices or limits.',id); end
    target.(id) = value;
end
exposure = colormeasure.drivers.cr.settingLabel(controls,target,'exposureMode');
fixed = ismember(exposure,{'Fixed','Manual'});
if fixed && any(ismember(fields,{'exposureMs','exposureMode','rangeMode','range'}))
    requireManualValue(controls,target,'exposureMs');
end
if strcmp(colormeasure.drivers.cr.settingLabel(controls,target,'syncMode'),'Manual') && ...
        any(ismember(fields,{'syncMode','syncFrequencyHz'}))
    requireManualValue(controls,target,'syncFrequencyHz');
end
if isfield(requested,'exposureMs') && ~fixed
    error('CR:SettingsDependency','exposureMs requires explicitly selected or reported Fixed exposure.');
end
if ~spectral && fixed && any(ismember(fields,{'exposureMs','exposureMode','rangeMode','range'}))
    if ~ismember(colormeasure.drivers.cr.settingLabel(controls,target,'rangeMode'),{'Fixed','Manual'}) || ...
            ~strcmp(colormeasure.drivers.cr.settingLabel(controls,target,'range'),'D')
        error('CR:SettingsDependency','CR100 Fixed exposure requires Fixed range D.');
    end
end
if isfield(requested,'range') && ~ismember(colormeasure.drivers.cr.settingLabel(controls,target,'rangeMode'),{'Fixed','Manual'})
    error('CR:SettingsDependency','A fixed range requires Fixed range mode.');
end
if isfield(requested,'syncFrequencyHz') && ~strcmp(colormeasure.drivers.cr.settingLabel(controls,target,'syncMode'),'Manual')
    error('CR:SettingsDependency','syncFrequencyHz requires Manual synchronization.');
end
if isfield(requested,'maxAutoExposureMs') && ~strcmp(exposure,'Auto')
    error('CR:SettingsDependency','maxAutoExposureMs requires Auto exposure.');
end
mode = colormeasure.drivers.cr.settingLabel(controls,target,'userCalibrationMode');
if isfield(requested,'matrixId') && ~strcmp(mode,'Matrix')
    error('CR:SettingsDependency','matrixId requires Matrix correction mode.');
end
if isfield(requested,'matchId') && ~strcmp(mode,'Match')
    error('CR:SettingsDependency','matchId requires Match correction mode.');
end
if isfield(requested,'userCalibrationMode') && strcmp(mode,'Matrix') && ~isfield(target,'matrixId')
    error('CR:SettingsDependency','Select a reported matrixId with Matrix correction mode.');
end
if isfield(requested,'userCalibrationMode') && strcmp(mode,'Match') && ~isfield(target,'matchId')
    error('CR:SettingsDependency','Select a reported matchId with Match correction mode.');
end
changedAccessory = isfield(requested,'accessory') && ...
    (~isfield(before.values,'accessory') || requested.accessory~=before.values.accessory);
if changedAccessory && (strcmp(mode,'Matrix') || isfield(requested,'matrixId'))
    error('CR:SettingsDependency',['Accessory-specific matrices cannot be validated before an accessory change. ' ...
        'Explicitly disable Matrix correction, change the accessory, then read its matrices before selecting one.']);
end
end

function requireManualValue(controls,target,id)
% A mode-only request must not enable an unestablished numeric setting.
control = controls(strcmp({controls.id},id));
if numel(control)~=1 || ~control.available
    error('CR:SettingsUnavailable','Manual mode requires available %s limits.',id);
end
if ~isfield(target,id)
    error('CR:SettingsDependency','Manual mode requires a known %s within the reported limits.',id);
end
value = target.(id);
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || ...
        ~isfinite(control.minimum) || ~isfinite(control.maximum) || control.minimum<=0 || ...
        value<control.minimum || value>control.maximum
    error('CR:SettingsDependency','Manual mode requires a known %s within the reported limits.',id);
end
end

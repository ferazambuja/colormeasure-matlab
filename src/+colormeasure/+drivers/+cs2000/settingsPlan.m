function [commands,target] = settingsPlan(changes,before)
%SETTINGSPLAN Validate a complete target before any setting command is sent.
% Rev.7 pp.15-22,24-25,31-32,36-37; operating manual pp.43,45.
% Fernando Voltolini de Azambuja, 2026.
changes = colormeasure.drivers.cs2000.validateSettingsChanges(changes);
current = before.values; target = current;
names = fieldnames(changes);
for k = 1:numel(names), target.(names{k}) = changes.(names{k}); end
speedFields = {'speedMode','integrationTimeSeconds','internalNDMode'};
speedRequested = any(isfield(changes,speedFields));
if speedRequested
    if ismember(target.speedMode,[0 1])
        if isfield(changes,'integrationTimeSeconds')
            error('CS2000:SettingsCombination','Normal/Fast choose integration automatically; omit integrationTimeSeconds.');
        end
        target.integrationTimeSeconds = NaN;
    else
        if target.speedMode ~= current.speedMode && ...
                ~isfield(changes,'integrationTimeSeconds') && ...
                ~(ismember(target.speedMode,[2 4]) && ismember(current.speedMode,[2 4]))
            error('CS2000:SettingsCombination','Specify integrationTimeSeconds when changing to Manual or Multi mode.');
        end
        value = target.integrationTimeSeconds;
        if target.speedMode == 3
            valid = isfinite(value) && value >= .005 && value <= 120 && ...
                abs(value*1e6-round(value*1e6)) <= 1e-6 && ismember(target.internalNDMode,0:1);
        else
            valid = isfinite(value) && value >= 1 && value <= 16 && value == fix(value);
        end
        if ~valid
            error('CS2000:SettingsCombination','Manual needs 0.005-120 s and ND Off/On; Multi needs 1-16 whole seconds.');
        end
    end
    if ~strcmp(before.speedLayout,'modern') && ...
            (target.speedMode == 4 || (target.speedMode ~= 3 && target.internalNDMode ~= 2))
        error('CS2000:SettingsCapability','This readback does not establish support for Multi-Fast or nonmanual fixed ND.');
    end
end
if target.syncMode == 1
    if ~isfinite(target.frequencyHz) || target.frequencyHz < 20 || target.frequencyHz > 200
        error('CS2000:SettingsCombination','Internal sync requires a known frequency from 20.00 to 200.00 Hz.');
    end
else
    if isfield(changes,'frequencyHz')
        error('CS2000:SettingsCombination','frequencyHz applies only to Internal sync.');
    end
    target.frequencyHz = NaN;
end
if any(isfield(changes,{'closeupLens','externalNDFilter'})) && ...
        target.closeupLens == 1 && target.externalNDFilter ~= 0
    error('CS2000:SettingsCombination','Do not combine the optional close-up lens and external ND filter (operating manual pp.43,45).');
end
commands = {};
% Disable an incompatible accessory before enabling its replacement.
accessoryNames = {'closeupLens','externalNDFilter'};
accessoryCommands = {'LNSS','NDFS'};
for enabled = [false true]
    for k = 1:2
        name = accessoryNames{k};
        if target.(name) ~= current.(name) && (target.(name) ~= 0) == enabled
            commands{end+1} = sprintf('%s,%d',accessoryCommands{k},target.(name)); %#ok<AGROW>
        end
    end
end
if ~isequaln([target.speedMode,target.integrationTimeSeconds,target.internalNDMode], ...
        [current.speedMode,current.integrationTimeSeconds,current.internalNDMode])
    if target.speedMode == 3
        command = sprintf('SPMS,3,%09d,%d',round(target.integrationTimeSeconds*1e6),target.internalNDMode);
    else
        command = sprintf('SPMS,%d',target.speedMode);
        if ismember(target.speedMode,[2 4])
            command = sprintf('%s,%d',command,target.integrationTimeSeconds);
        end
        if strcmp(before.speedLayout,'modern')
            command = sprintf('%s,%d',command,target.internalNDMode);
        end
        % In an unknown CS-2000 generation, common nonmanual forms deliberately
        % request Auto: old firmware fixes it, modern omission defaults to it.
        % This is the requested change, never a capability-probing command.
    end
    commands{end+1} = command;
end
if ~isequaln([target.syncMode,target.frequencyHz],[current.syncMode,current.frequencyHz])
    command = sprintf('SCMS,%d',target.syncMode);
    if target.syncMode == 1, command = sprintf('%s,%05d',command,round(target.frequencyHz*100)); end
    commands{end+1} = command;
end
if target.userCalibrationChannel ~= current.userCalibrationChannel
    commands{end+1} = sprintf('UCCS,%02d',target.userCalibrationChannel);
end
end

function [commands, ids] = settingsCommands(overrides, model, before)
% SETTINGSCOMMANDS Validate a complete request before producing setting writes.
%   Empty BEFORE checks arguments only, without I/O or invented capabilities.
%   Fernando Voltolini de Azambuja, 2026. See docs/drivers/pr/settings.md.
commands={}; ids={};
if ~isstruct(overrides)||~isscalar(overrides)
    error('PR655:InvalidSettings','Settings overrides must be a scalar struct.');
end
names=fieldnames(overrides);
catalog=colormeasure.drivers.pr.settingsCatalog(model,struct(),true);
dynamic={'primaryAccessoryId','addon1Id','addon2Id','addon3Id','apertureId'};
for index=1:numel(names)
    id=names{index}; control=catalog(strcmp({catalog.id},id));
    if isempty(control), error('PR655:InvalidSettings','Unknown setting: %s.',id); end
    if ~control.available && ~ismember(id,dynamic)
        error('PR655:UnsupportedSetting','%s is unavailable for %s.',id,model);
    end
    if strcmp(id,'apertureId') && ~strcmp(model,'PR-670')
        error('PR655:UnsupportedSetting','PR-655 has no software aperture selector.');
    end
    value=overrides.(id);
    if ismember(id,dynamic)||strcmp(control.type,'number')
        if ~isnumeric(value)||~isscalar(value)||~isreal(value)||~isfinite(value)||value~=fix(value)
            error('PR655:InvalidSettings','%s requires a finite integer.',id);
        end
        minimum=control.minimum; maximum=control.maximum;
        if ismember(id,dynamic), minimum=0; maximum=Inf; end
        if strcmp(id,'exposureMilliseconds')&&strcmp(model,'PR-670'), maximum=30000; end
        if value<minimum||value>maximum
            error('PR655:InvalidSettings','%s is outside its supported range.',id);
        end
        if strcmp(id,'exposureMilliseconds')&&value>0
            lower=3; if strcmp(model,'PR-670'),lower=6;end
            if value<lower,error('PR655:InvalidSettings','Fixed exposure must be at least %d ms.',lower);end
        end
    else
        if isstring(value)&&isscalar(value)&&~ismissing(value),value=char(value);end
        if ~any(arrayfun(@(choice) isequal(value,choice.value),control.choices))
            error('PR655:InvalidSettings','Unsupported value for %s.',id);
        end
        overrides.(id)=value;
    end
end
if nargin<3||isempty(before)||isempty(names),return;end
target=before.values;
for index=1:numel(names),target.(names{index})=overrides.(names{index});end
catalog=before.controls;
for index=1:numel(names)
    id=names{index};
    if ismember(id,dynamic)
        control=catalog(strcmp({catalog.id},id));
        if ~control.available||~any(arrayfun(@(choice) isequal(choice.value,overrides.(id)),control.choices))
            error('PR655:InvalidSettings','%s must use an ID reported by this instrument.',id);
        end
    end
end
if any(ismember(names,{'addon1Id','addon2Id','addon3Id'}))
    selected=[target.addon1Id target.addon2Id target.addon3Id];
    selected=selected(isfinite(selected)&selected>=0);
    if numel(unique(selected))~=numel(selected)
        error('PR655:InvalidSettings','An add-on accessory cannot occupy more than one slot (manual error -1007).');
    end
end
if isfield(overrides,'exposureMilliseconds')&&overrides.exposureMilliseconds>6000 && ...
        ~strcmp(target.sensitivityMode,'extended')
    error('PR655:InvalidSettings','Exposure above 6000 ms requires known Extended sensitivity.');
end
if isfield(overrides,'sensitivityMode')&&strcmp(overrides.sensitivityMode,'standard') && ...
        (~isfinite(target.exposureMilliseconds)||target.exposureMilliseconds>6000)
    error('PR655:InvalidSettings','Select Adaptive or a fixed exposure no greater than 6000 ms with Standard sensitivity.');
end
if isfield(overrides,'syncFrequencyHz')&&~strcmp(target.syncMode,'user')
    error('PR655:InvalidSettings','A user frequency requires User frequency synchronization.');
end
if isfield(overrides,'syncMode')&&strcmp(target.syncMode,'user') && ...
        (~isfinite(target.syncFrequencyHz)||target.syncFrequencyHz<20||target.syncFrequencyHz>400)
    error('PR655:InvalidSettings','User synchronization requires a frequency from 20 to 400 Hz.');
end
% Lower a fixed exposure before reducing its ceiling; raise the ceiling first
% for an exposure above 6000 ms. No unrequested intermediate settings are sent.
order={'exposureMilliseconds','sensitivityMode','cycles','syncMode','syncFrequencyHz', ...
    'primaryAccessoryId','addon1Id','addon2Id','addon3Id','apertureId','smartDark', ...
    'photometricUnits','instrumentObserver','shutterMode'};
if isfield(overrides,'exposureMilliseconds')&&overrides.exposureMilliseconds>6000
    order(1:2)=order([2 1]);
end
for index=1:numel(order)
    id=order{index}; if ~isfield(overrides,id),continue;end
    value=overrides.(id);
    if isfield(before.values,id)&&isequaln(before.values.(id),value),continue;end
    switch id
        case 'exposureMilliseconds', command=sprintf('SE%d',value);
        case 'cycles', command=sprintf('SN%d',value);
        case 'syncMode', command=sprintf('SS%d',choiceCode(value,{'none','auto','user'},[0 1 3]));
        case 'syncFrequencyHz', command=sprintf('SK%03d',value);
        case 'primaryAccessoryId', command=sprintf('SP%d',value);
        case 'addon1Id', command=sprintf('SA%d',value);
        case 'addon2Id', command=sprintf('SB%d',value);
        case 'addon3Id', command=sprintf('SC%d',value);
        case 'apertureId', command=sprintf('SF%d',value);
        case 'sensitivityMode', command=sprintf('SH%d',choiceCode(value,{'standard','extended'},[0 1]));
        case 'smartDark', command=sprintf('SD%d',value);
        case 'photometricUnits', command=sprintf('SU%d',choiceCode(value,{'english','metric'},[0 1]));
        case 'instrumentObserver', command=sprintf('SO%d',value);
        case 'shutterMode', command=sprintf('SZ%d',choiceCode(value,{'closeAfter','alwaysOpen'},[0 1]));
    end
    commands{end+1}=command; ids{end+1}=id; %#ok<AGROW>
end
end
function value=choiceCode(selected,values,codes)
value=codes(strcmp(selected,values));
end

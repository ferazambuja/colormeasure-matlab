function choices = settingsChoices(lines, columns)
%SETTINGSCHOICES Strict RC capability rows. Preserve names, never evaluate text.
% Remote 1.36 section 4.3.2: ID,name[,quantity type], exact declared row count.
choices = repmat(struct('value',[],'label',''),numel(lines),1);
for index = 1:numel(lines)
    fields = strsplit(lines{index},',','CollapseDelimiters',false);
    if numel(fields)~=columns || isempty(fields{2}) || ...
            any(lines{index}<32 | lines{index}>126)
        error('CR:SettingsPayload','Malformed configuration list row: %s',lines{index});
    end
    id = colormeasure.drivers.cr.numbers(fields{1},1);
    if id<0 || fix(id)~=id
        error('CR:SettingsPayload','Configuration IDs must be nonnegative integers.');
    end
    choices(index) = struct('value',id,'label',fields{2});
end
if numel(unique([choices.value]))~=numel(choices)
    error('CR:SettingsPayload','Configuration list contains duplicate IDs.');
end
end

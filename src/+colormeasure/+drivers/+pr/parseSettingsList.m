function entries = parseSettingsList(command, rows)
% PARSESETTINGSLIST Interpret complete, count-bounded D116/D117 responses.
%   Values are reported calibration IDs, never positions in a dropdown.
%   Fernando Voltolini de Azambuja, 2026.
if strcmp(command,'D116')
    entries=struct('id',{},'name',{},'type',{},'photometry',{},'radiometry',{});
    expected=6;
elseif strcmp(command,'D117')
    entries=struct('id',{},'name',{},'bandwidth',{}); expected=4;
else
    error('PR655:InvalidSettings','Unsupported discovery report.');
end
for index=1:numel(rows)
    fields=rows{index};
    if numel(fields)~=expected
        error('PR655:InvalidResponse','%s returned an unexpected field count.',command);
    end
    id=str2double(fields{2}); name=strtrim(fields{3});
    if ~isreal(id)||~isfinite(id)||id<0||id~=fix(id)||isempty(name)||any(isstrprop(name,'cntrl'))
        error('PR655:InvalidResponse','%s returned an invalid ID or name.',command);
    end
    if strcmp(command,'D116')
        type=strtrim(fields{4});
        if ~ismember(type,{'Primary','Addon'})||isempty(strtrim(fields{5}))||isempty(strtrim(fields{6}))
            error('PR655:InvalidResponse','D116 returned an invalid accessory description.');
        end
        entry=struct('id',id,'name',name,'type',type, ...
            'photometry',strtrim(fields{5}),'radiometry',strtrim(fields{6}));
    else
        bandwidth=str2double(fields{4});
        if ~isreal(bandwidth)||~isfinite(bandwidth)||bandwidth<0,error('PR655:InvalidResponse','D117 returned invalid bandwidth.');end
        entry=struct('id',id,'name',name,'bandwidth',bandwidth);
    end
    if any([entries.id]==id),error('PR655:InvalidResponse','%s returned duplicate IDs.',command);end
    entries(end+1)=entry; %#ok<AGROW>
end
end

function index=settingsChoiceIndex(choices,value)
%SETTINGSCHOICEINDEX Match one settings value without changing its wire type.
% Char and scalar string represent the same text. Text never selects a
% numeric instrument ID. Zero and false remain real choices rather than an
% editor placeholder; an unmatched value returns no index.
% Fernando Voltolini de Azambuja, 2026.
index=[];
for n=1:numel(choices)
    candidate=choices(n).value;
    if colormeasure.session.isText(value)&&colormeasure.session.isText(candidate)
        matches=strcmp(char(value),char(candidate));
    else
        matches=(isnumeric(value)||islogical(value))&&isreal(value)&& ...
            isscalar(value)&&isequal(value,candidate);
    end
    if matches,index=n;return;end
end
end

function yes=isTextEditKey(event,multiline)
%ISTEXTEDITKEY Keys that can change a classic edit control's draft.
% Navigation and application shortcuts do not change its text. Modern fields
% use ValueChangingFcn instead; this predicate is for classic KeyPressFcn.
% Fernando Voltolini de Azambuja, 2026.
if nargin<2,multiline=false;end
key=char(event.Key);modifiers=cellstr(string(event.Modifier));
% Word/line deletion and Shift+Insert paste can edit without a character.
yes=ismember(key,{'backspace','delete'})|| ...
    (strcmp(key,'insert')&&any(strcmp(modifiers,'shift')));
if yes,return;end
if any(ismember(modifiers,{'command','control'}))
    yes=ismember(key,{'v','x','z','y'}); % Paste, cut, undo and redo.
    return
end
yes=isscalar(key)||strcmp(key,'space')|| ...
    (multiline&&ismember(key,{'return','enter'}));
if ~yes&&(isprop(event,'Character')||(isstruct(event)&&isfield(event,'Character')))
    yes=any(double(event.Character)>=32);
end
end

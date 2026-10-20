function yes=isCloseKey(event)
%ISCLOSEKEY The dialog close keys shared by the MATLAB views.
% Other keys, including typing, Tab and button activation, stay with the UI.
yes=strcmp(event.Key,'escape')|| ...
    (strcmp(event.Key,'period')&&any(strcmp(event.Modifier,'command')));
end

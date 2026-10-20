function values = pauseLog(action,value)
%PAUSELOG Only the narrowly scoped legacy-duration fixture uses this state.
persistent calls
switch action
    case 'reset', calls = [];
    case 'append', calls(end+1) = value;
    case 'read'
    otherwise, error('cs2000test:PauseAction','Unknown pause recorder action.');
end
values = calls;
end

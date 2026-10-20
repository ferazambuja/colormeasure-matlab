function [handled, reply, state] = settingsReply(command, state)
% SETTINGSREPLY Test-only stateful setup reports and acknowledgements.
%   Existing metadata fixtures remain unchanged unless setup is inspected.
handled = any(strcmp(command,{'D601','D112','D116','D117'})) || ...
    (strcmp(command,'D602')&&isfield(state,'settingsNumeric')) || ...
    ~isempty(regexp(command,'^S[A-FHKNOPS-UZ][0-9]+$','once'));
reply='';
if ~handled,return;end
if ~isfield(state,'settingsNumeric')
    state.settingsNumeric=[0 -1 -1 -1 0 0 0 0 0 1 2 0 0 0 60];
end
if isfield(state,'settingsReplyOverrides')&&isfield(state.settingsReplyOverrides,command)
    reply=state.settingsReplyOverrides.(command);return;
end
if isfield(state,'settingsFailureCommand')&&strcmp(command,state.settingsFailureCommand)
    reply=sprintf('-1000\r\n');return;
end
n=state.settingsNumeric;
switch command
    case 'D601'
        reply=[sprintf('00000') sprintf(',%g',n) sprintf('\r\n')];
    case 'D602'
        units={'English','Metric'}; sync={'No Sync','Auto Sync','unused','User Sync'};
        sensitivity={'Standard Sensitivity','Extended Sensitivity'};
        exposure='Fixed';if n(8)==0,exposure='Adaptive';end
        dark='No Smart Dark';if n(12)==1,dark='Smart Dark';end
        reply=sprintf('00000,MS-75,None,None,None,1 deg,%s,%s,%g msec,Normal,%g cycles,%g deg,%s,%s,%s,%g Hertz\r\n', ...
            units{n(6)+1},exposure,n(8),n(10),n(11),dark,sync{n(13)+1},sensitivity{n(14)+1},n(15));
    case 'D112',reply=sprintf('00000,3,4\r\n');
    case 'D116'
        reply=sprintf(['00000,0,MS-75,Primary,Luminance,Radiance\r\n' ...
            '00000,7,ND filter,Addon,Luminance,Radiance\r\n' ...
            '00000,9,Receptor,Primary,Illuminance,Irradiance\r\n']);
    case 'D117'
        reply=sprintf('00000,0,1 deg,0\r\n00000,1,1/2 deg,0\r\n00000,2,1/4 deg,0\r\n00000,3,1/8 deg,0\r\n');
    otherwise
        value=str2double(command(3:end));
        switch command(1:2)
            case 'SP',n(1)=value;
            case 'SA',n(2)=value;
            case 'SB',n(3)=value;
            case 'SC',n(4)=value;
            case 'SF',n(5)=value;
            case 'SU',n(6)=value;
            case 'SE',n(8)=value;
            case 'SN',n(10)=value;
            case 'SO',n(11)=value;
            case 'SD',n(12)=value;
            case 'SS',n(13)=value;
            case 'SH',n(14)=value;
            case 'SK',n(15)=value;
            case 'SZ' % No documented D601/D602 readback field.
            otherwise,error('PR655Test:UnexpectedSetting','Unexpected setting command %s.',command);
        end
        if isfield(state,'settingsAfterNumeric')
            n=state.settingsAfterNumeric;state=rmfield(state,'settingsAfterNumeric');
        end
        state.settingsNumeric=n;reply=sprintf('0000\r\n');
end
end

function text = displayTime(utc, zone)
%DISPLAYTIME Show a recorded UTC instant in local time with an explicit offset.
%   Empty text, an absent optional timestamp, returns empty text. Anything else
%   must be one recorded UTC instant; utcValue refuses it otherwise. The zone
%   defaults to this computer's; tests pass one to fix the expected offset.
%   Fernando Voltolini de Azambuja, 2026.
if nargin<2, zone='local'; end
text = '';
if (ischar(utc) && isempty(utc)) || (isstring(utc) && isscalar(utc) && strlength(utc)==0)
    return
end
value=colormeasure.session.utcValue(utc);
value.TimeZone=char(zone);
[local,~]=colormeasure.session.localTimeText(value,value.TimeZone);
text=[strrep(local(1:19),'T',' ') ' UTC' local(24:end)];
end

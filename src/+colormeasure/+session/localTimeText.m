function [text, zone] = localTimeText(value, zone)
% LOCALTIMETEXT Retain an instant as local ISO 8601 text with a UTC offset.
%   The optional time zone defaults to this computer's zone. Store the
%   returned zone with the text so later display need not infer the location.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 2 || isempty(zone)
    zone = 'local';
end
if ~isa(value, 'datetime') || ~isscalar(value) || isnat(value) || isempty(value.TimeZone)
    error('Measurement:InvalidTime', 'A timestamp must be one valid, zoned datetime.');
end
value.TimeZone = char(zone);
zone = value.TimeZone;
value.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX';
text = char(value);
if endsWith(text, 'Z')
    text = [text(1:end-1) '+00:00'];
end
end

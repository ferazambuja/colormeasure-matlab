function receipt = settingsReceipt(requested)
% SETTINGSRECEIPT Stable plain-data result for explicit native setting changes.
%   Fernando Voltolini de Azambuja, 2026.
receipt=struct('requested',requested,'before',struct([]),'after',struct([]), ...
    'commands',{{}},'acknowledgements',struct('command',{},'rawReply',{},'status',{}), ...
    'status','unchanged','error',struct('identifier','','message',''));
end

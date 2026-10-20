function value = onOff(condition)
% ONOFF Graphics on/off text for one logical condition.
%   Shared by every view; replaces the per-file copies of the same helper.
%   Fernando Voltolini de Azambuja, 2026.
if condition, value = 'on'; else, value = 'off'; end
end

function io = services()
% SERVICES Clock, persistence, and platform operations for the session core.
%   Fernando Voltolini de Azambuja, 2026.
io = struct('now', @() datetime('now', 'TimeZone', 'UTC'), ...
    'saveMat', @colormeasure.session.saveMat, ...
    'exportCsv', @colormeasure.session.exportCsv, 'isMac', ismac());
end

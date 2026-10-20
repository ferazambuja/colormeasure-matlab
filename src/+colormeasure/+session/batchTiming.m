function info = batchTiming(measurements)
% BATCHTIMING Distinguish each reading's duration from the batch's elapsed span.
%   The span ends at the latest completed reading and includes gaps between
%   readings; it does not include time spent at the final Finish prompt.
%   Endpoints are host reading times, including native setup and cleanup;
%   they do not establish the instrument's physical exposure duration.
%   Fernando Voltolini de Azambuja, 2026.

info = struct('measurementCount', numel(measurements), ...
    'startedAtUTC', '', 'completedAtUTC', '', ...
    'startedAtLocal', '', 'completedAtLocal', '', 'localTimeZone', '', 'elapsedSeconds', 0);
if isempty(measurements)
    return
end
info.startedAtUTC = measurements(1).startedAtUTC;
info.completedAtUTC = measurements(end).completedAtUTC;
info.startedAtLocal = measurements(1).startedAtLocal;
info.completedAtLocal = measurements(end).completedAtLocal;
zones = unique(string({measurements.localTimeZone}));
if isscalar(zones)
    info.localTimeZone = char(zones);
end
started = colormeasure.session.utcValue(info.startedAtUTC);
completed = colormeasure.session.utcValue(info.completedAtUTC);
info.elapsedSeconds = seconds(completed - started);
end

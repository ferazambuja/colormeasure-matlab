function reading = stampReading(reading, name, notes, port, started, completed, duration, zone)
% STAMPREADING Add the session's sample identity and host timing to a reading.
%   Every acquisition route records the sample name and notes, the port, the
%   start and completion instants in UTC and as local text with their zone,
%   the duration and the MATLAB version. Batch tables read these fields
%   directly. The duration is the caller's: the interval around a direct
%   read, or NaN for an operation whose host interval includes operator steps.
%   Fernando Voltolini de Azambuja, 2026.
reading.name = char(name);
reading.notes = char(notes);
reading.port = port;
reading.startedAtUTC = colormeasure.session.utcText(started);
reading.completedAtUTC = colormeasure.session.utcText(completed);
[reading.startedAtLocal, reading.localTimeZone] = colormeasure.session.localTimeText(started, zone);
reading.completedAtLocal = colormeasure.session.localTimeText(completed, reading.localTimeZone);
reading.durationSeconds = duration;
reading.matlabVersion = version;
end

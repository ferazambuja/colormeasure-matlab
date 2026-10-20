function tests = testMeasurementTime
% Timestamp conversion checks use named zones, independent of the test host.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testAutumnRepeatedClockTimeRetainsDifferentOffsets(t)
early = datetime(2026, 11, 1, 5, 30, 0, 'TimeZone', 'UTC');
late = early + hours(1);
[earlyText, zone] = colormeasure.session.localTimeText(early, 'America/New_York');
lateText = colormeasure.session.localTimeText(late, zone);
verifyEqual(t, earlyText, '2026-11-01T01:30:00.000-04:00');
verifyEqual(t, lateText, '2026-11-01T01:30:00.000-05:00');
verifyEqual(t, zone, 'America/New_York');
verifyEqual(t, parseLocal(earlyText), early);
verifyEqual(t, parseLocal(lateText), late);
end

function testSpringClockChangePreservesElapsedTime(t)
first = datetime(2026, 3, 8, 6, 59, 0, 'TimeZone', 'UTC');
last = first + minutes(2);
firstText = colormeasure.session.localTimeText(first, 'America/New_York');
lastText = colormeasure.session.localTimeText(last, 'America/New_York');
verifyEqual(t, firstText, '2026-03-08T01:59:00.000-05:00');
verifyEqual(t, lastText, '2026-03-08T03:01:00.000-04:00');
verifyEqual(t, seconds(parseLocal(lastText)-parseLocal(firstText)), 120);
end

function testUtcAndFractionalHourOffsetsAreExplicit(t)
instant = datetime(2026, 9, 16, 12, 0, 0.125, 'TimeZone', 'UTC');
verifyEqual(t, colormeasure.session.localTimeText(instant, 'UTC'), '2026-09-16T12:00:00.125+00:00');
verifyEqual(t, colormeasure.session.localTimeText(instant, 'Asia/Kathmandu'), '2026-09-16T17:45:00.125+05:45');
verifyEqual(t, colormeasure.session.displayTime('2026-09-16T12:00:00.125Z', 'Asia/Kathmandu'), ...
    '2026-09-16 17:45:00 UTC+05:45');
end

function testDisplayShowsAbsentAsEmptyAndRefusesMalformedTimestamps(t)
verifyEqual(t, colormeasure.session.displayTime('2026-09-16T12:00:00.125Z', 'America/New_York'), ...
    '2026-09-16 08:00:00 UTC-04:00');
for value = {'', ""}
    verifyEmpty(t, colormeasure.session.displayTime(value{1}, 'UTC'));
end
% Recorded timestamps are validated where they enter; a malformed one here is
% a defect to surface, not an absent value to hide.
for value = {'not a timestamp', struct(), 3, ["a" "b"], string(missing)}
    verifyError(t, @() colormeasure.session.displayTime(value{1}, 'UTC'), 'Measurement:InvalidTime');
end
verifyError(t, @() colormeasure.session.displayTime('2026-09-16T12:00:00.125Z', 'not/a_zone'), ...
    'MATLAB:datetime:UnknownTimeZone');
end

function testSavingRequiresAnUnambiguousInstant(t)
verifyError(t, @() colormeasure.session.localTimeText(datetime(2026, 1, 1)), 'Measurement:InvalidTime');
verifyError(t, @() colormeasure.session.localTimeText(NaT), 'Measurement:InvalidTime');
verifyError(t, @() colormeasure.session.localTimeText('2026-01-01'), 'Measurement:InvalidTime');
end

function testUtcTextRequiresOneZonedInstant(t)
zonedNaT = datetime(2026, 1, 1, 'TimeZone', 'UTC') + seconds(NaN);
for value = {datetime(2026, 1, 1), NaT, zonedNaT, datetime(2026, 1, 1:2, 'TimeZone', 'UTC')}
    verifyError(t, @() colormeasure.session.utcText(value{1}), 'Measurement:InvalidTime');
end
end

function testUtcTextRecordsAZonedInstantInUtc(t)
instant = datetime(2026, 9, 16, 17, 45, 0.125, 'TimeZone', 'Asia/Kathmandu');
text = colormeasure.session.utcText(instant);
verifyEqual(t, text, '2026-09-16T12:00:00.125Z');
verifyEqual(t, colormeasure.session.utcValue(text), datetime(2026, 9, 16, 12, 0, 0.125, 'TimeZone', 'UTC'));
end

function testUtcValueRequiresTheRecordedFormat(t)
for value = {'2026-09-16T12:00:00.125', '2026-09-16T12:00:00Z', '', ""}
    verifyError(t, @() colormeasure.session.utcValue(value{1}), 'Measurement:InvalidTime');
end
end

function testBatchSpanRetainsCapturedLocalTimesAcrossDst(t)
readings = struct('startedAtUTC', {'2026-11-01T05:30:00.000Z', '2026-11-01T06:30:00.000Z'}, ...
    'completedAtUTC', {'2026-11-01T05:30:01.000Z', '2026-11-01T06:30:01.000Z'}, ...
    'startedAtLocal', {'2026-11-01T01:30:00.000-04:00', '2026-11-01T01:30:00.000-05:00'}, ...
    'completedAtLocal', {'2026-11-01T01:30:01.000-04:00', '2026-11-01T01:30:01.000-05:00'}, ...
    'localTimeZone', 'America/New_York');
info = colormeasure.session.batchTiming(readings);
verifyEqual(t, info.elapsedSeconds, 3601);
verifyEqual(t, info.startedAtLocal, readings(1).startedAtLocal);
verifyEqual(t, info.completedAtLocal, readings(2).completedAtLocal);
verifyEqual(t, info.localTimeZone, 'America/New_York');
end

function value = parseLocal(text)
value = datetime(text, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX', 'TimeZone', 'UTC');
end

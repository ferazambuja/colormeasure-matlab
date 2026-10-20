function calibration = calibrationDate(payload)
%CALIBRATIONDATE Factory calibration timestamp, Rev.7 p.71. Zone unspecified.
% https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
tokens = regexp(payload,'^(\d{8}),(\d{6})$','tokens','once');
if isempty(tokens)
    error('CS2000:CalibrationDate', 'DTCR must return YYYYMMDD,HHMMSS.');
end
date = tokens{1}; time = tokens{2};
v = [str2double(date(1:4)),str2double(date(5:6)),str2double(date(7:8)), ...
    str2double(time(1:2)),str2double(time(3:4)),str2double(time(5:6))];
% Validate before datetime, which can normalize out-of-range components.
leap = mod(v(1),4) == 0 && (mod(v(1),100) ~= 0 || mod(v(1),400) == 0);
monthDays = [31 28+leap 31 30 31 30 31 31 30 31 30 31];
if v(1) < 1 || v(2) < 1 || v(2) > 12 || v(3) < 1 || ...
        v(3) > monthDays(v(2)) || v(4) > 23 || v(5) > 59 || v(6) > 59
    error('CS2000:CalibrationDate', 'DTCR returned an invalid calendar date or time.');
end
calibration = struct('date',date,'time',time, ...
    'dateTime',datetime(v(1),v(2),v(3),v(4),v(5),v(6)));
end

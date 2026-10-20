function settings = syncSettings(payload)
%SYNCSETTINGS Current sync configuration, Rev.7 p.15; frequency is 100x Hz.
% https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
v = colormeasure.drivers.cs2000.numbers(payload);
valid = all(v == fix(v)) && ismember(v(1),0:2);
if valid && v(1) == 1
    valid = numel(v) == 2 && v(2) >= 2000 && v(2) <= 20000;
else
    valid = valid && isscalar(v);
end
if ~valid
    error('CS2000:SyncMode', 'SCMR returned an unsupported synchronization configuration.');
end
settings = struct('syncMode',v(1),'frequencyHz',NaN);
if v(1) == 1, settings.frequencyHz = v(2)/100; end
end

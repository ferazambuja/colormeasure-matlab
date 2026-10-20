classdef LegacySession < handle
    % Older public session shape for compatibility-guard tests only.
    % No instrument, persistence, UI or class-path manipulation.
    properties
        measurements = struct('name','retained sample','XYZ',[1 2 3])
        files = struct('mat','already-saved.mat','csv','')
        finished = false
        busy = false
    end
end

classdef RealClock < handle
    %REALCLOCK Wall-clock seconds and sleep for transport deadline loops.
    %   now() counts seconds since construction; sleep(seconds) pauses. The
    %   transports take any object with these two methods, so tests substitute
    %   colormeasuretest.FakeClock, whose time advances only on sleep.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access = private)
        Started
    end
    methods
        function obj = RealClock()
            obj.Started = tic;
        end
        function t = now(obj)
            t = toc(obj.Started);
        end
        function sleep(~, seconds)
            pause(seconds);
        end
    end
end

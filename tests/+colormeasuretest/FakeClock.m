classdef FakeClock < handle
    %FAKECLOCK Simulated clock for transport deadline tests.
    %   Time advances only through sleep (as the transports' deadline loops
    %   call it) or advance; nothing waits on the wall clock. Share one
    %   instance between a driver ('Clock' option) and its fake port so
    %   queued reply delays and driver deadlines run on the same time base.
    properties (SetAccess = private)
        Time = 0
        Sleeps = zeros(0, 1)   % Every requested sleep, in order.
    end
    methods
        function t = now(obj)
            t = obj.Time;
        end
        function sleep(obj, seconds)
            assert(isscalar(seconds) && isfinite(seconds) && seconds >= 0, ...
                'test:FakeClock', 'Sleep must be a finite non-negative scalar.');
            obj.Time = obj.Time + seconds;
            obj.Sleeps(end+1, 1) = seconds;
        end
        function advance(obj, seconds)
            obj.Time = obj.Time + seconds;
        end
    end
end

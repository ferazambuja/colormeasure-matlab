classdef FailingCleanup < handle
    %FAILINGCLEANUP Handle whose next delete fails, for release paths that
    % must report a cleanup error without hiding the acquisition outcome.
    properties
        Fail = true
    end
    methods
        function delete(obj)
            if obj.Fail
                obj.Fail = false;
                error('colormeasuretest:Cleanup','Injected cleanup failure.');
            end
        end
    end
end

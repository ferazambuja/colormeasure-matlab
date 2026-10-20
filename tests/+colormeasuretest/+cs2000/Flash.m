classdef Flash < handle
    %FLASH Counting peer demonstrates that original strobe code never fires.
    properties
        Count = 0
    end
    methods
        function TestFlash(obj)
            obj.Count = obj.Count + 1;
        end
    end
end

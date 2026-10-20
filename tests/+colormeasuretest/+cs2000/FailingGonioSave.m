classdef FailingGonioSave < colormeasure.drivers.cs2000.CS2000Gonio
    %FAILINGGONIOSAVE Save failure after a complete simulated Gonio acquisition.
    methods
        function obj=FailingGonioSave(varargin)
            obj@colormeasure.drivers.cs2000.CS2000Gonio(varargin{:});
        end
    end
    methods (Access=protected)
        function saveSnapshot(~,~,~)
            error('cs2000test:SaveFailure','Injected Gonio snapshot save failure.');
        end
    end
end

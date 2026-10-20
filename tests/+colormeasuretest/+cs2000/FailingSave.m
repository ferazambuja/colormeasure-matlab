classdef FailingSave < colormeasure.drivers.cs2000.CS2000
    %FAILINGSAVE Snapshot publication failure for the save-on-delete warning.
    methods
        function obj = FailingSave(varargin)
            obj@colormeasure.drivers.cs2000.CS2000(varargin{:});
        end
    end
    methods (Access=protected)
        function saveSnapshot(~,fileName,~)
            error('cs2000test:SaveFailure','Injected save failure for %s.',fileName);
        end
    end
end

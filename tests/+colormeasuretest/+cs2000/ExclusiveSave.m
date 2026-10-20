classdef ExclusiveSave < colormeasure.drivers.cs2000.CS2000
    %EXCLUSIVESAVE Expose automatic-path publication without opening hardware.
    methods
        function obj=ExclusiveSave(varargin)
            obj@colormeasure.drivers.cs2000.CS2000(varargin{:});
        end
        function saveIfUnused(obj,fileName)
            obj.saveSnapshot(fileName,false);
        end
    end
end

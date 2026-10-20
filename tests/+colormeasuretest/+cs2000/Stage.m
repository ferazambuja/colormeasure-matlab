classdef Stage < handle
    % STAGE Record motion requests without operating physical hardware.
    % Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = private)
        Calls = {}
    end
    methods
        function PanTilt(obj,pan,tilt)
            obj.Calls{end+1} = {'PanTilt',pan,tilt};
        end
        function Wait(obj)
            obj.Calls{end+1} = {'Wait'};
        end
        function Move(obj,axis,position)
            obj.Calls{end+1} = {'Move',axis,position};
        end
    end
end

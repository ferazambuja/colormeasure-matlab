classdef CS2000manual < colormeasure.drivers.cs2000.CS2000
    %CS2000MANUAL Same verified acquisition with explicit manual integration.
    properties
        integrationTime (1,1) double {mustBeFinite,mustBePositive} = 2
    end
    methods
        function h = CS2000manual(portNumber, varargin)
            if nargin == 0, portNumber = ""; end
            h@colormeasure.drivers.cs2000.CS2000(portNumber, varargin{:});
        end
        function MeasureManual(h)
            h.measureWithIntegration(h.integrationTime);
        end
    end
end

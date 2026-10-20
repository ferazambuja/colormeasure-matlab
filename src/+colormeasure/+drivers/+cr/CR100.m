classdef CR100 < colormeasure.drivers.cr.Instrument
    %CR100 CR-100 tristimulus colorimeter; XYZ is read from the instrument.
    methods
        function obj = CR100(portID, varargin)
            if nargin == 0, portID = ""; end
            obj@colormeasure.drivers.cr.Instrument('CR-100', portID, varargin{:});
        end
    end
end

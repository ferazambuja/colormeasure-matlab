classdef CR250 < colormeasure.drivers.cr.Instrument
    %CR250 CR-250 spectroradiometer; wavelength grid comes from each reply.
    methods
        function obj = CR250(portID, varargin)
            if nargin == 0, portID = ""; end
            obj@colormeasure.drivers.cr.Instrument('CR-250', portID, varargin{:});
        end
    end
end

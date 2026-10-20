classdef CR300 < colormeasure.drivers.cr.Instrument
    %CR300 CR-300 spectroradiometer; wavelength grid comes from each reply.
    % A 380:2:780 grid contains 201 samples, not 401. Do not infer output
    % spacing from the instrument's optical bandwidth or detector pitch.
    methods
        function obj = CR300(portID, varargin)
            if nargin == 0, portID = ""; end
            obj@colormeasure.drivers.cr.Instrument('CR-300', portID, varargin{:});
        end
    end
end

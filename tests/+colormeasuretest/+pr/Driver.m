classdef Driver < colormeasure.drivers.pr.PR655
    % Override only hardware entry points; exercise the real driver/parser.
    % The fake port shares the driver's clock, so queued reply delays and
    % the driver's deadlines run on one time base, simulated or real.
    methods
        function obj = Driver(varargin)
            obj@colormeasure.drivers.pr.PR655(varargin{:});
        end
        function clock = injectedClock(obj)
            % The clock the driver runs on; the protocol suite pins the default.
            clock = obj.clock;
        end
    end
    methods (Access = protected)
        function connection = openConnection(obj, portID)
            state = colormeasuretest.pr.state();
            state.openedPort = portID;
            colormeasuretest.pr.state(state);
            connection = colormeasuretest.pr.Port(obj.clock);
        end
        function ports = listPorts(~, mode)
            state = colormeasuretest.pr.state();
            state.listModes{end+1} = mode;
            colormeasuretest.pr.state(state);
            ports = state.ports;
        end
        function yes = isMac(~)
            state = colormeasuretest.pr.state();
            yes = state.onMac;
        end
    end
end

classdef OriginalPort < handle
    %ORIGINALPORT Bounded adapter for actual pre-v2 methods; no hardware API.
    properties
        Peer
        PollLimit = 40
    end
    properties (Dependent)
        NumBytesAvailable
    end
    properties (Access = private)
        PollCount = 0
    end
    methods
        function obj = OriginalPort(model)
            obj.Peer = colormeasuretest.cr.Port(model);
        end
        function queue(obj,varargin)
            obj.Peer.queue(varargin{:});
        end
        function writeline(obj,command)
            obj.PollCount = 0;
            obj.Peer.writeline(command);
        end
        function value = get.NumBytesAvailable(obj)
            obj.PollCount = obj.PollCount + 1;
            if obj.PollCount > obj.PollLimit
                error('crtest:OriginalWaitBound', ...
                    'Original fixed-byte wait exceeded the simulated poll bound.');
            end
            value = obj.Peer.NumBytesAvailable;
        end
        function value = read(obj,count,type)
            value = obj.Peer.read(count,type);
        end
        function value = readline(obj)
            value = string(obj.Peer.read(obj.Peer.NumBytesAvailable,'char'));
        end
        function delete(obj)
            delete(obj.Peer);
        end
    end
end

classdef Instrument < handle
    % Test instrument with programmable reads; never opens a serial connection.
    properties
        Read
        Release
    end
    methods
        function obj = Instrument(read, release)
            obj.Read = read;
            obj.Release = release;
        end
        function delete(obj)
            obj.Release();
        end
    end
end

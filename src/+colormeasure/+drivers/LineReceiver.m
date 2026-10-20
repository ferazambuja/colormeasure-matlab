classdef LineReceiver < handle
    %LINERECEIVER Buffered line reads from a serial-style port against a clock.
    %   Shared by the CR and CS-2000 transports, which used to carry the same
    %   loop each. Bytes are collected as they arrive and kept until a line is
    %   complete; a line ends at CR or LF, and the LF of a CR LF pair is dropped
    %   when it arrives, whether in the same read or a later one. A line may
    %   carry at most 4096 bytes before its terminator (4097 framed bytes):
    %   4096 unterminated bytes still wait for the terminator, the 4097th byte
    %   without one is a framing error. The family names its prefix and messages, so
    %   every identifier and message stays as the family documented it. The
    %   clock (now, sleep) lets deadline loops run against simulated time.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = private)
        Buffer = ''   % Received bytes not yet returned as a line.
        RecoveryStatus = struct('attempted',false,'discardedBytes',uint8([]), ...
            'quietPeriod',NaN,'timeout',NaN,'quietObserved',false)
    end
    properties (Access = private)
        OptionalLF = false
        Messages
        Clock
    end
    methods
        function obj = LineReceiver(messages, clock)
            %LINERECEIVER messages: struct with prefix, timeout (a format taking
            %   the timeout in seconds), overflow and overflowUnterminated.
            required = {'prefix', 'timeout', 'overflow', 'overflowUnterminated'};
            assert(isstruct(messages) && isscalar(messages) && all(isfield(messages, required)), ...
                'Measurement:LineReceiver', ...
                'Line receiver messages must name prefix, timeout, overflow and overflowUnterminated.');
            if nargin < 2 || isempty(clock), clock = colormeasure.drivers.RealClock(); end
            obj.Messages = messages;
            obj.Clock = clock;
        end

        function t = now(obj)
            t = obj.Clock.now();
        end

        function sleep(obj, seconds)
            obj.Clock.sleep(seconds);
        end

        function clear(obj)
            % Forget buffered bytes and any pending optional LF (port reopened
            % or an abandoned exchange discarded by the family).
            obj.Buffer = '';
            obj.OptionalLF = false;
        end

        function collect(obj, port)
            count = port.NumBytesAvailable;
            if count > 0
                bytes = char(read(port, count, 'uint8'));
                obj.Buffer = [obj.Buffer reshape(bytes, 1, [])];
            end
            obj.consumeOptionalLF();
        end

        function status = drain(obj, port, quietPeriod, timeout, byteLimit, timeoutMessage)
            %DRAIN Explicitly abandon pending input until the quiet interval.
            %   The family owns permission to abandon the exchange and its byte
            %   limit/message. This does not prove a physical measurement ended.
            %   Partial diagnostics remain readable if the drain fails. The port is
            %   checked once more at the deadline, so a quiet interval completed by
            %   then is observed. A clock or scheduler jump beyond the deadline
            %   must still fail; quiet observed outside the budget is insufficient.
            obj.RecoveryStatus = struct('attempted',true,'discardedBytes',uint8(obj.Buffer), ...
                'quietPeriod',quietPeriod,'timeout',timeout,'quietObserved',false);
            if numel(obj.RecoveryStatus.discardedBytes)>byteLimit
                error([obj.Messages.prefix ':DrainLimit'], ...
                    'Recovery exceeded %d bytes; no command was sent.',byteLimit);
            end
            obj.clear();
            started=obj.Clock.now(); quiet=started;
            while true
                count=port.NumBytesAvailable;
                if count>0
                    if numel(obj.RecoveryStatus.discardedBytes)+count > byteLimit
                        error([obj.Messages.prefix ':DrainLimit'], ...
                            'Recovery exceeded %d bytes; no command was sent.',byteLimit);
                    end
                    bytes=reshape(uint8(read(port,count,'uint8')),1,[]);
                    obj.RecoveryStatus.discardedBytes=[obj.RecoveryStatus.discardedBytes bytes];
                    quiet=obj.Clock.now();
                end
                observed=obj.Clock.now();
                remaining=timeout-(observed-started);
                if count==0 && remaining>=0 && observed-quiet >= quietPeriod
                    obj.RecoveryStatus.quietObserved=true;
                    status=obj.RecoveryStatus;
                    return
                end
                if remaining<=0
                    error([obj.Messages.prefix ':DrainTimeout'],'%s',timeoutMessage);
                end
                obj.Clock.sleep(min(0.005,remaining));
            end
        end

        function line = readLine(obj, port, started, timeout)
            %READLINE One complete line, or the family's timeout error once
            %   timeout seconds have passed since the clock read `started`.
            %   The port is read once more when the deadline is reached, so a
            %   line that arrived during the last sleep is returned, not timed out.
            while true
                obj.collect(port);
                finish = find(obj.Buffer == char(13) | obj.Buffer == newline, 1);
                if ~isempty(finish)
                    if finish > 4097
                        error([obj.Messages.prefix ':Framing'], '%s', obj.Messages.overflow);
                    end
                    line = obj.Buffer(1:finish-1);
                    obj.OptionalLF = obj.Buffer(finish) == char(13);
                    obj.Buffer(1:finish) = [];
                    obj.consumeOptionalLF();
                    return
                end
                if numel(obj.Buffer) > 4096
                    error([obj.Messages.prefix ':Framing'], '%s', obj.Messages.overflowUnterminated);
                end
                remaining = timeout - (obj.Clock.now() - started);
                if remaining <= 0
                    error([obj.Messages.prefix ':Timeout'], obj.Messages.timeout, timeout);
                end
                obj.Clock.sleep(min(0.005, remaining));
            end
        end
    end
    methods (Access = private)
        function consumeOptionalLF(obj)
            if obj.OptionalLF && ~isempty(obj.Buffer)
                if obj.Buffer(1) == newline
                    obj.Buffer(1) = []; % second byte of the preceding CR LF
                end
                obj.OptionalLF = false;
            end
        end
    end
end

classdef Port < handle
    %PORT In-memory PR peer based on PR-655/PR-670 User Manual Rev. B; opens no device or serial port.
    properties
        FailCleanup = false
        EnableWriteTimeout = false
        WriteTimeoutPrefix = ''
        ConfigurationFailure = false
    end
    properties (Dependent)
        Timeout
        NumBytesAvailable
    end
    properties (Access = private)
        buffer = '';
        command = '';
        chunks = {};
        due = [];
        Started
        Clock = [] % Shared with the driver under test on simulated time.
        TimeoutValue = 10
    end
    methods
        function obj = Port(clock)
            obj.Started = tic;
            if nargin > 0, obj.Clock = clock; end
        end
        function t = now(obj)
            if isempty(obj.Clock), t = toc(obj.Started); else, t = obj.Clock.now(); end
        end
        function value = get.Timeout(obj)
            value = obj.TimeoutValue;
        end
        function set.Timeout(obj,value)
            if obj.ConfigurationFailure
                error('SerialTest:WriteConfiguration','Simulated write-deadline configuration failure.');
            end
            obj.TimeoutValue = value;
        end
        function count = get.NumBytesAvailable(obj)
            while ~isempty(obj.due) && obj.now() >= obj.due(1)
                obj.buffer = [obj.buffer obj.chunks{1}];
                obj.chunks(1) = [];
                obj.due(1) = [];
            end
            count = numel(obj.buffer);
        end
        function bytes = read(obj, count, precision)
            assert(strcmp(precision, 'uint8'));
            assert(count <= numel(obj.buffer));
            state = colormeasuretest.pr.state();
            if ~isfield(state,'readCounts'),state.readCounts = [];end
            state.readCounts(end+1) = count;
            colormeasuretest.pr.state(state);
            bytes = uint8(obj.buffer(1:count));
            obj.buffer(1:count) = [];
        end
        function flush(obj, direction)
            assert(strcmp(direction, 'input'));
            count = obj.NumBytesAvailable; %#ok<NASGU>
            obj.buffer = '';
        end
        function write(obj, byte, precision)
            assert(strcmp(precision, 'char') && isscalar(byte), ...
                'Every command character must be written separately.');
            state = colormeasuretest.pr.state();
            if ~isfield(state,'writeAttempts'), state.writeAttempts = ''; end
            state.writeAttempts(end+1) = byte;
            colormeasuretest.pr.state(state);
            if ~isempty(obj.WriteTimeoutPrefix) && ...
                    strcmp([obj.command byte],obj.WriteTimeoutPrefix)
                assert(obj.EnableWriteTimeout,'SerialTest:UnboundedWrite', ...
                    'The driver did not enable write deadlines.');
                assert(~isempty(obj.Clock),'SerialTest:Clock','A simulated write timeout needs a clock.');
                obj.Clock.sleep(obj.Timeout);
                error('SerialTest:WriteTimeout','Simulated partial serial write timed out.');
            end
            if isempty(obj.command) && byte == 'Q'
                obj.respond('Q');
            elseif byte == char(13)
                obj.respond(obj.command);
                obj.command = '';
            else
                obj.command = [obj.command byte];
                if strcmp(obj.command, 'PHOTO')
                    obj.respond('PHOTO');
                    obj.command = '';
                end
            end
        end
        function delete(obj)
            if obj.FailCleanup,error('SerialTest:Cleanup','Injected port cleanup failure.');end
            state = colormeasuretest.pr.state();
            state.closed = true;
            colormeasuretest.pr.state(state);
        end
    end
    methods (Access = private)
        function respond(obj, command)
            state = colormeasuretest.pr.state();
            state.commands{end+1} = command;
            colormeasuretest.pr.state(state);
            [handled, reply, state] = colormeasuretest.pr.settingsReply(command, state);
            if handled
                colormeasuretest.pr.state(state);
                if state.echo, reply = [sprintf('%s\r',command) reply]; end
                obj.enqueue({reply},0);
                return
            end
            switch command
                case 'Q'
                    return
                case 'PHOTO'
                    reply = state.remoteReply;
                case 'D111'
                    reply = sprintf('%s\r\n', state.identityReply);
                case {'B00', 'B100'}
                    if state.failRestore && strcmp(command, 'B100')
                        reply = sprintf('-1000\r\n');
                    else
                        format = 'Backlight set to %d %%\r\n';
                        if isfield(state,'backlightFormat'), format = state.backlightFormat; end
                        reply = sprintf(format, str2double(command(2:end)));
                    end
                case 'D14'
                    reply = sprintf('%s\r\n', state.flickerReply);
                case {'D110', 'D114', 'D602', 'D13'}
                    reply = state.metadataReplies.(command);
                    if ~ismember(command, state.metadataUnterminated)
                        reply = sprintf('%s\r\n', reply);
                    end
                case 'M5'
                    parts = state.chunks;
                    if state.echo
                        parts{1} = [sprintf('M5\r') parts{1}];
                    end
                    obj.enqueue(parts, state.delays);
                    return
                otherwise
                    error('PR655Test:UnexpectedCommand', 'Unexpected command: %s', command);
            end
            if state.echo
                reply = [sprintf('%s\r', command) reply];
            end
            obj.enqueue({reply}, 0);
        end
        function enqueue(obj, parts, delays)
            obj.chunks = [obj.chunks parts];
            obj.due = [obj.due obj.now() + delays];
            [obj.due, order] = sort(obj.due);
            obj.chunks = obj.chunks(order);
        end
    end
end

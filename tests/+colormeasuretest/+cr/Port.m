classdef Port < handle
    %PORT In-memory CR peer based on Remote Communications Manual 1.36; opens no device or serial port.
    properties
        FailCleanup = false
        State
        Model
        Terminator = ''
        Timeout = 10
        EnableWriteTimeout = false
        WriteTimeoutCommand = ''
    end
    properties (Dependent)
        NumBytesAvailable
    end
    properties (Access = private)
        Queues
        Buffer = uint8([])
        Pending = {}
        Started
        Clock = []
    end
    methods
        function obj = Port(model, clock)
            % Optional clock (now) shared with the driver under test; the
            % wall clock otherwise.
            if nargin >= 2, obj.Clock = clock; end
            obj.Model = model;
            obj.State = containers.Map('KeyType','char','ValueType','any');
            obj.State('deleted') = false;
            obj.State('deleteCount') = 0;
            obj.State('commands') = {};
            obj.State('commandTimes') = [];
            obj.State('readTimes') = [];
            obj.State('readCommandIndices') = [];
            obj.Queues = containers.Map('KeyType','char','ValueType','any');
            obj.Started = tic;
        end

        function configureTerminator(obj, terminator)
            obj.Terminator = terminator;
        end

        function queue(obj, command, text, sizes, delays)
            % Chunks become readable at times relative to writeline. Thus the
            % production receiver must actually wait and reassemble replies.
            if nargin < 4, sizes = numel(text); end
            if nargin < 5, delays = zeros(size(sizes)); end
            assert(sum(sizes) == numel(text) && numel(sizes) == numel(delays));
            offsets = [0 cumsum(sizes)];
            chunks = cell(size(sizes));
            for k = 1:numel(sizes)
                chunks{k} = uint8(text(offsets(k)+1:offsets(k+1)));
            end
            reply = struct('chunks',{chunks},'delays',delays);
            if isKey(obj.Queues,command), list = obj.Queues(command); else, list = {}; end
            list{end+1} = reply;
            obj.Queues(command) = list;
        end

        function writeline(obj, command)
            command = char(command);
            history = obj.State('commands');
            history{end+1} = command;
            obj.State('commands') = history;
            obj.State('commandTimes') = [obj.State('commandTimes') obj.now()];
            if strcmp(command,obj.WriteTimeoutCommand)
                obj.State('writeTimeout') = obj.Timeout;
                assert(obj.EnableWriteTimeout,'SerialTest:UnboundedWrite', ...
                    'The driver did not enable write deadlines.');
                assert(~isempty(obj.Clock),'SerialTest:Clock','A simulated write timeout needs a clock.');
                obj.Clock.sleep(obj.Timeout);
                error('SerialTest:WriteTimeout','Simulated partial serial write timed out.');
            end
            if isKey(obj.Queues,command) && ~isempty(obj.Queues(command))
                list = obj.Queues(command);
                reply = list{1};
                obj.Queues(command) = list(2:end);
            else
                reply = struct('chunks',{{uint8(obj.defaultReply(command))}},'delays',0);
            end
            now = obj.now();
            for k = 1:numel(reply.chunks)
                obj.Pending{end+1} = struct('due',now+reply.delays(k),'bytes',reply.chunks{k});
            end
        end

        function n = get.NumBytesAvailable(obj)
            obj.release();
            n = numel(obj.Buffer);
        end

        function data = read(obj, count, type)
            obj.release();
            assert(count <= numel(obj.Buffer), 'Fake transport never blocks a read.');
            data = obj.Buffer(1:count);
            obj.Buffer(1:count) = [];
            obj.State('readTimes') = [obj.State('readTimes') obj.now()];
            obj.State('readCommandIndices') = [obj.State('readCommandIndices') numel(obj.State('commands'))];
            if strcmp(type,'char'), data = char(data); end
        end

        function inject(obj, bytes, delay)
            if nargin < 3
                obj.Buffer = [obj.Buffer uint8(bytes)];
            else
                obj.Pending{end+1} = struct('due',obj.now()+delay,'bytes',uint8(bytes));
            end
        end

        function delete(obj)
            if obj.FailCleanup,error('SerialTest:Cleanup','Injected port cleanup failure.');end
            obj.State('deleted') = true;
            obj.State('deleteCount') = obj.State('deleteCount') + 1;
        end
    end
    methods (Access = protected)
        function t = now(obj)
            if isempty(obj.Clock), t = toc(obj.Started); else, t = obj.Clock.now(); end
        end
        function release(obj)
            while ~isempty(obj.Pending) && obj.Pending{1}.due <= obj.now()
                obj.Buffer = [obj.Buffer obj.Pending{1}.bytes];
                obj.Pending(1) = [];
            end
        end

        function text = defaultReply(obj, command)
            switch command
                case 'RC Model', value = obj.Model;
                case 'RC ID', value = 'SIM-001';
                case 'RC Firmware', value = '1.36';
                case 'M', value = 'No errors';
                case 'RM XYZ', value = '95.047,100,108.883';
                case 'RM Time', value = 'NA';
                case 'RM Accessory', value = 'Standard';
                case 'RM Filter', value = 'None';
                case 'RM Aperture'
                    if strcmp(obj.Model,'CR-100'), value = '5 deg'; else, value = '1 deg'; end
                case 'RM Mode'
                    if strcmp(obj.Model,'CR-100'), value = 'Colorimeter'; else, value = 'Spectroradiometer'; end
                case 'RM ExposureMode', value = 'Auto';
                case 'RM Exposure', value = '111.622 msec';
                case 'RM MaxAutoExposure', value = '449.999 msec';
                case 'RM RangeMode', value = 'Auto';
                case 'RM Range', value = 'D';
                case 'RM SyncMode', value = 'None';
                case 'RM SyncFreq', value = '60.00 Hz';
                case 'RM ExposureX', value = '1';
                case 'RM CMF', value = '0';
                case 'RM UserCalibMode', value = 'None';
                case 'RM MatrixMode', value = 'Disabled';
                case 'RM Matrix', value = '0';
                case 'RM Match', value = '0';
                case 'RM Speed', value = 'Normal';
                case 'RM Warnings', value = '0';
                case 'RM Radiometric', value = '0,0.402,8.835e+17';
                case 'RM Spectrum'
                    step = 2;
                    if strcmp(obj.Model,'CR-300'), step = 1; end
                    grid = 380:step:780;
                    value = sprintf('380,780,%d,%d\r\n',step,numel(grid));
                    % Synthetic grids, not hardware captures or claims about
                    % the output grid of a particular firmware revision.
                    text = ['OK:0:RM Spectrum:' value repmat(sprintf('0.001\r\n'),1,numel(grid))];
                    return
                otherwise
                    error('crtest:UnexpectedCommand','Unexpected command: %s',command);
            end
            text = sprintf('OK:0:%s:%s\r\n',command,value);
        end
    end
end

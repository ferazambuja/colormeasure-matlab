classdef Port < handle
    %PORT Isolated peer based on KMSE A0E3-CS.07J; never opens real hardware.
    properties
        FailCleanup = false
        State
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
        function obj = Port(clock)
            % Optional clock (now) shared with the driver under test; the
            % wall clock otherwise.
            if nargin >= 1, obj.Clock = clock; end
            obj.State = containers.Map('KeyType','char','ValueType','any');
            obj.State('deleted') = false;
            obj.State('deleteCount') = 0;
            obj.State('commands') = {};
            obj.State('speedPayload') = '0,2';
            obj.State('speedGeneration') = 'legacy'; % CS2000.m speedLayout name; 'modern' is the other.
            obj.State('syncPayload') = '0';
            obj.State('angleCode') = 0;
            obj.State('lensCode') = 0;
            obj.State('externalNDCode') = 0;
            obj.State('channelCode') = 0;
            obj.Queues = containers.Map('KeyType','char','ValueType','any');
            obj.Started = tic;
        end
        function configureTerminator(obj, terminator)
            obj.Terminator = terminator;
        end
        function queue(obj, command, text, sizes, delays)
            if nargin < 4, sizes = numel(text); end
            if nargin < 5, delays = zeros(size(sizes)); end
            assert(sum(sizes) == numel(text) && numel(sizes) == numel(delays));
            offsets = [0 cumsum(sizes)]; chunks = cell(size(sizes));
            for k = 1:numel(sizes)
                chunks{k} = uint8(text(offsets(k)+1:offsets(k+1)));
            end
            reply = struct('chunks',{chunks},'delays',delays);
            if isKey(obj.Queues,command), list = obj.Queues(command); else, list = {}; end
            list{end+1} = reply; obj.Queues(command) = list;
        end
        function writeline(obj, command)
            command = char(command);
            history = obj.State('commands'); history{end+1} = command;
            obj.State('commands') = history;
            if strcmp(command,obj.WriteTimeoutCommand)
                obj.State('writeTimeout') = obj.Timeout;
                assert(obj.EnableWriteTimeout,'SerialTest:UnboundedWrite', ...
                    'The driver did not enable write deadlines.');
                assert(~isempty(obj.Clock),'SerialTest:Clock','A simulated write timeout needs a clock.');
                obj.Clock.sleep(obj.Timeout);
                error('SerialTest:WriteTimeout','Simulated partial serial write timed out.');
            end
            if startsWith(command,'STDS,') || startsWith(command,'STDR,')
                error('cs2000test:MemoryCommand','Fixture forbids measurement memory writes and reads.');
            end
            if isKey(obj.Queues,command) && ~isempty(obj.Queues(command))
                list = obj.Queues(command); reply = list{1};
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
            obj.release(); n = numel(obj.Buffer);
        end
        function data = read(obj, count, type)
            obj.release();
            assert(count <= numel(obj.Buffer),'Simulated reads never block.');
            data = obj.Buffer(1:count); obj.Buffer(1:count) = [];
            if strcmp(type,'char'), data = char(data); end
        end
        function inject(obj, bytes)
            obj.Buffer = [obj.Buffer uint8(bytes)];
        end
        function injectLater(obj, bytes, delay)
            obj.Pending{end+1} = struct('due',obj.now()+delay,'bytes',uint8(bytes));
        end
        function delete(obj)
            if obj.FailCleanup,error('SerialTest:Cleanup','Injected port cleanup failure.');end
            obj.State('deleted') = true;
            obj.State('deleteCount') = obj.State('deleteCount') + 1;
        end
    end
    methods (Access = private)
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
                case {'RMTS,1','RMTS,0','BALS,1,0','BALS,1,1','BALS,0,0','BALS,0,1','MSWE,0'}
                    payload = '';
                case 'IDDR', payload = ',CS-2000  ,1,1234567';
                case 'DTCR', payload = ',20070201,235607';
                case 'BALR', payload = ',1,1';
                case 'SCMR', payload = [',' obj.State('syncPayload')];
                case 'STSR', payload = sprintf(',%d',obj.State('angleCode'));
                case 'LNSR', payload = sprintf(',%d',obj.State('lensCode'));
                case 'NDFR', payload = sprintf(',%d',obj.State('externalNDCode'));
                case 'UCCR', payload = sprintf(',%02d',obj.State('channelCode'));
                case 'OBSR', payload = ',0';
                case 'MEAS,1'
                    text = sprintf('OK00,002\r\nOK00\r\n'); return
                case 'MEDR,2,0,01', payload = ',95.047,100,108.883';
                case 'MEDR,0,0,1', payload = ',0,0,002000000,0,0,0,0,00';
                case 'SPMR', payload = [',' obj.State('speedPayload')];
                otherwise
                    token = regexp(command,'^MEDR,1,0,([1-4])$','tokens','once');
                    if ~isempty(token)
                        block = str2double(token{1});
                        first = 380+(block-1)*100;
                        last = min(first+99,780);
                        if block == 4, last = 780; end
                        % Each wavelength has a distinct simulated value to
                        % expose reordered, duplicated or incomplete blocks.
                        payload = sprintf(',%.4fe+0',(first:last)/1000);
                    elseif startsWith(command,'SPMS,')
                        value = command(6:end);
                        if strcmp(obj.State('speedGeneration'),'modern')
                            parts = strsplit(value,',');
                            if (any(strcmp(parts{1},{'0','1'})) && isscalar(parts)) || ...
                                    (any(strcmp(parts{1},{'2','4'})) && numel(parts) == 2)
                                value = [value ',2'];
                            end
                        end
                        obj.State('speedPayload') = value;
                        payload = '';
                    elseif startsWith(command,'SCMS,')
                        obj.State('syncPayload') = command(6:end);
                        payload = '';
                    elseif startsWith(command,'LNSS,')
                        obj.State('lensCode') = str2double(command(6:end));
                        payload = '';
                    elseif startsWith(command,'NDFS,')
                        obj.State('externalNDCode') = str2double(command(6:end));
                        payload = '';
                    elseif startsWith(command,'UCCS,')
                        obj.State('channelCode') = str2double(command(6:end));
                        payload = '';
                    elseif ~isempty(regexp(command,'^UCPR,2,(0[1-9]|10)$','once'))
                        payload = ',User Cal  ';
                    else
                        error('cs2000test:UnexpectedCommand','Unexpected command: %s',command);
                    end
            end
            text = sprintf('OK00%s\r\n',payload);
        end
    end
end

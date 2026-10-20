classdef COMClass < handle
    %COMCLASS Owned serialport connection with finite, buffered line reads.
    % CS-2000/2000A Communication Specifications Rev.7, sections 1.1, 1.4,
    % 1.6: USB virtual COM, selectable line ending, command response timeout.
    % https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
    properties
        serialPort = []
        responseTimeout (1,1) double {mustBePositive,mustBeFinite} = 10
    end
    properties (SetAccess = private)
        recoveryStatus = struct('attempted',false,'discardedBytes',uint8([]), ...
            'quietPeriod',NaN,'timeout',NaN,'quietObserved',false)
    end
    properties (Access = protected)
        streamSynchronized = true
        portName = ''
        hostIoClosed = true
    end
    properties (Access = private)
        baudRate
        parity
        dataBits
        stopBits
        flowControl
        portList
        dtr
        rts
        injected = false
        opened = false
        receiver
        clock
    end
    methods
        function obj = COMClass(portNumber, baudRate, parity, dataBits, stopBits, dtr, rts, varargin)
            if nargin < 6, dtr = true; end
            if nargin < 7, rts = true; end
            if isnumeric(portNumber)
                validateattributes(portNumber, {'numeric'}, {'scalar','real','finite','integer','positive'});
                obj.portName = sprintf('COM%d', portNumber);
            else
                if ~(ischar(portNumber) && (isrow(portNumber) || isempty(portNumber))) && ...
                        ~(isstring(portNumber) && isscalar(portNumber) && ~ismissing(portNumber))
                    error('CS2000:Port', 'Use one port name, an empty string for automatic selection, or a positive COM port number.');
                end
                obj.portName = strtrim(char(portNumber));
            end
            p = inputParser;
            p.addParameter('Transport', []);
            p.addParameter('Clock', []); % Deadline clock seam (now, sleep) for tests.
            p.addParameter('PortList', @() serialportlist("available"), ...
                @(x) isa(x,'function_handle') && isscalar(x));
            p.addParameter('ResponseTimeout', 10, @(x) isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x) && x>0);
            p.addParameter('BaudRate', baudRate, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && ...
                ismember(x,[600 1200 2400 4800 9600 19200 38400 57600 115200]));
            p.addParameter('FlowControl', 'none', @(x) (ischar(x) || (isstring(x) && isscalar(x))) && ...
                any(strcmpi(x,{'none','hardware'})));
            p.parse(varargin{:});
            obj.portList = p.Results.PortList;
            obj.clock = p.Results.Clock;
            if isempty(obj.clock), obj.clock = colormeasure.drivers.RealClock(); end
            obj.receiver = colormeasure.drivers.LineReceiver(struct('prefix', 'CS2000', ...
                'timeout', 'Timed out after %.3g seconds waiting for a complete response.', ...
                'overflow', 'Response line exceeds 4096 bytes.', ...
                'overflowUnterminated', 'Response line exceeds 4096 bytes.'), obj.clock);
            obj.responseTimeout = p.Results.ResponseTimeout;
            obj.baudRate = p.Results.BaudRate;
            obj.flowControl = lower(char(p.Results.FlowControl));
            obj.parity = parity; obj.dataBits = dataBits; obj.stopBits = stopBits;
            obj.dtr = logical(dtr); obj.rts = logical(rts);
            obj.injected = ~isempty(p.Results.Transport);
            obj.serialPort = p.Results.Transport;
            if obj.injected,obj.hostIoClosed=false;end
            % Construction never enumerates or opens ports. Connect calls Open.
        end

        function flag = isConnected(obj)
            flag = obj.isOpened();
        end
        function yes=canRetryConnectionCleanup(obj)
            % This reads ownership only; false is not a cleanup confirmation.
            yes=~isempty(obj.serialPort)&&isvalid(obj.serialPort);
        end

        function delete(obj)
            obj.Close();
        end
    end
    methods (Access = protected)
        function Open(obj)
            if obj.isOpened(), return; end
            % Recovery diagnoses one connection; a new one starts unattempted.
            obj.recoveryStatus = struct('attempted',false,'discardedBytes',uint8([]), ...
                'quietPeriod',NaN,'timeout',NaN,'quietObserved',false);
            try
                % Selection happens once, on Connect. Keep that name across
                % reconnects rather than silently choosing a different port.
                obj.portName = colormeasure.drivers.cs2000.selectPort(obj.portName,obj.portList);
                if obj.injected
                    if isempty(obj.serialPort) || ~isvalid(obj.serialPort)
                        error('CS2000:Disconnected', 'The injected transport is closed. Construct a new instrument.');
                    end
                else
                    obj.hostIoClosed=false;
                    obj.serialPort = serialport(obj.portName, obj.baudRate, ...
                        'Parity',obj.parity,'DataBits',obj.dataBits,'StopBits',obj.stopBits, ...
                        'FlowControl',obj.flowControl,'Timeout',obj.responseTimeout);
                end
                colormeasure.drivers.configureSerialWrites(obj.serialPort,obj.responseTimeout);
                if ~obj.injected
                    setDTR(obj.serialPort,obj.dtr);
                    if strcmp(obj.flowControl,'none'), setRTS(obj.serialPort,obj.rts); end
                end
                configureTerminator(obj.serialPort,'CR/LF');
                obj.receiver.clear();
                obj.streamSynchronized = true; obj.opened = true;
            catch err
                try
                    if obj.Close(),err=colormeasure.drivers.confirmedConnectionFailure(err);end
                catch cleanupError
                    err=addCause(err,cleanupError);
                end
                rethrow(err);
            end
        end

        function closed=Close(obj)
            ownedPort = obj.serialPort;
            % Close also runs from the destructor of an object whose
            % constructor failed before the receiver existed.
            if ~isempty(obj.receiver), obj.receiver.clear(); end
            closed=obj.hostIoClosed;
            if ~isempty(ownedPort) && isvalid(ownedPort)
                colormeasure.drivers.closeConnection(ownedPort);
                closed=true;
            end
            obj.hostIoClosed=closed;
            if closed,obj.serialPort=[];obj.opened=false;end
        end

        function discardPendingInput(obj, quietPeriod, timeout)
            % Only Connect invokes this, before a new command is sent.
            % Caller must first establish that the old exchange is abandoned
            % and the instrument is idle; this is not a cancellation command.
            obj.requireOpen();
            obj.streamSynchronized = false;
            try
                obj.recoveryStatus=obj.receiver.drain(obj.serialPort,quietPeriod,timeout,65536, ...
                    'Recovery did not observe the requested quiet interval; no command was sent.');
            catch problem
                obj.recoveryStatus=obj.receiver.RecoveryStatus;
                rethrow(problem);
            end
            obj.streamSynchronized=true;
        end

        function Send(obj, command)
            obj.validateIdleInput();
            try
                colormeasure.drivers.configureSerialWrites(obj.serialPort,obj.responseTimeout);
                writeline(obj.serialPort,command);
            catch err
                obj.streamSynchronized = false;
                rethrow(err);
            end
        end

        function validateIdleInput(obj)
            % Reject bytes already received after a response. A quiet buffer
            % cannot establish that unsolicited bytes will never arrive later.
            obj.requireOpen();
            if ~obj.streamSynchronized
                error('CS2000:Unsynchronized', 'The response stream is unsynchronized. Disconnect, establish that the instrument is idle, then reconnect with explicit recovery if needed.');
            end
            try
                obj.receiver.collect(obj.serialPort);
                if ~isempty(obj.receiver.Buffer)
                    error('CS2000:PendingInput', 'Unread serial data precede the command. No bytes were flushed. After establishing instrument idle, use Connect(''DiscardPendingInput'',true) for an abandoned exchange.');
                end
            catch err
                obj.streamSynchronized = false;
                rethrow(err);
            end
        end

        function message = Receive(obj, timeout)
            if nargin < 2, timeout = obj.responseTimeout; end
            validateattributes(timeout, {'numeric'}, {'scalar','real','finite','positive'});
            obj.requireOpen();
            started = obj.clock.now();
            try
                message = obj.receiver.readLine(obj.serialPort, started, timeout);
            catch err
                obj.streamSynchronized = false;
                rethrow(err);
            end
        end

        function flag = isOpened(obj)
            flag = obj.opened && ~isempty(obj.serialPort) && isvalid(obj.serialPort);
        end
    end
    methods (Access = private)
        function requireOpen(obj)
            if ~obj.isOpened()
                error('CS2000:Disconnected', 'The serial port is closed. Call Connect first.');
            end
        end
    end
end

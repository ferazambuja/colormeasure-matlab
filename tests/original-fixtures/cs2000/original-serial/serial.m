classdef serial < handle
    %SERIAL Strict in-memory legacy serial peer; never forwards hardware I/O.
    % Lowercase name is required by untouched COMClass.isOpened's isa check.
    properties
        Port
        BaudRate
        Parity
        DataBits
        StopBits
        Timeout
        InputBufferSize
        DataTerminalReady
        RequestToSend
        Status = 'closed'
        PinStatusFcn = []
        Commands = {}
        CurrentSpectrum = (380:780)'/1000
        CurrentXYZ = [95.047;100;108.883]
        StoredSpectrum = -ones(401,1)
        StoredXYZ = [-1;-2;-3]
        Conditions = '0,0,002000000,0,0,0,0,00'
        Speed = '0'
        Observer = '0'
    end
    properties (Access = private)
        Replies = {}
        Overrides
    end
    methods
        function obj = serial(port,varargin)
            if ~strcmp(port,'SIM-LEGACY-CS2000')
                error('cs2000test:HardwareForbidden','Only the literal legacy simulation port is allowed.');
            end
            p = inputParser;
            p.addParameter('BaudRate',9600,@(x) isequal(x,9600));
            p.addParameter('Parity','none',@(x) strcmp(x,'none'));
            p.addParameter('DataBits',8,@(x) isequal(x,8));
            p.addParameter('StopBits',1,@(x) isequal(x,1));
            p.parse(varargin{:});
            obj.Port = port;
            for name = fieldnames(p.Results).'
                obj.(name{1}) = p.Results.(name{1});
            end
            obj.Overrides = containers.Map('KeyType','char','ValueType','any');
        end
        function fopen(obj)
            assert(strcmp(obj.Status,'closed'),'cs2000test:LegacyState','Already open.');
            obj.Status = 'open';
        end
        function fclose(obj)
            obj.Status = 'closed';
        end
        function queue(obj,command,lines)
            if ischar(lines), lines = {lines}; end
            obj.Overrides(command) = lines;
        end
        function fprintf(obj,command)
            assert(strcmp(obj.Status,'open'),'cs2000test:LegacyState','Closed fixture.');
            assert(isempty(obj.Replies),'cs2000test:LegacyUnread','Unread response before command.');
            obj.Commands{end+1} = command;
            if isKey(obj.Overrides,command)
                obj.Replies = obj.Overrides(command); remove(obj.Overrides,command); return
            end
            switch command
                case {'RMT,1','RMT,0'}
                    obj.Replies = {'OK'}; return
                case 'BALS,1,0'
                case 'SPMS,0', obj.Speed = '0';
                case 'OBSS,0', obj.Observer = '0';
                case 'MEAS,1'
                    obj.Replies = {'OK00,002','OK00'}; return
                case 'STDS,99'
                    obj.StoredSpectrum = obj.CurrentSpectrum;
                    obj.StoredXYZ = obj.CurrentXYZ;
                case 'STDR,99,2,0,01'
                    obj.Replies = {['OK00' sprintf(',%.17g',obj.StoredXYZ)]}; return
                case 'STDR,99,0,1,1'
                    obj.Replies = {['OK00,' obj.Conditions]}; return
                case 'OBSR'
                    obj.Replies = {['OK00,' obj.Observer]}; return
                otherwise
                    block = regexp(command,'^STDR,99,1,0,0([1-4])$','tokens','once');
                    if ~isempty(block)
                        index = str2double(block{1}); first = (index-1)*100+1;
                        last = index*100; if index == 4, last = 401; end
                        obj.Replies = {['OK00' sprintf(',%.17g',obj.StoredSpectrum(first:last))]}; return
                    elseif ~isempty(regexp(command,'^SPMS,3,\d{9},0$','once'))
                        obj.Speed = command(6:end);
                    else
                        error('cs2000test:LegacyCommand','Unexpected legacy command: %s',command);
                    end
            end
            obj.Replies = {'OK00'};
        end
        function value = fscanf(obj)
            assert(strcmp(obj.Status,'open'),'cs2000test:LegacyState','Closed fixture.');
            if isempty(obj.Replies)
                error('cs2000test:LegacyTimeout','No queued legacy reply; reads never block.');
            end
            value = [obj.Replies{1} sprintf('\r\n')]; obj.Replies(1) = [];
        end
        function delete(obj)
            obj.Status = 'closed';
        end
    end
end

classdef LegacyPort < handle
    % LEGACYPORT Complete synthetic replies for the unchanged school driver.
    %   No serial API is called. Frame timing/fault tests belong to the new
    %   driver's protocol suite; the original driver can wait indefinitely.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Dependent)
        NumBytesAvailable
    end
    properties (Access = private)
        buffer = '';
        command = '';
    end
    methods
        function obj = LegacyPort(varargin)
        end
        function count = get.NumBytesAvailable(obj)
            count = numel(obj.buffer);
        end
        function configureTerminator(~, terminator)
            assert(strcmp(terminator, 'CR/LF'));
        end
        function bytes = read(obj, count, precision)
            assert(strcmp(precision, 'char') && count <= numel(obj.buffer));
            bytes = obj.buffer(1:count);
            obj.buffer(1:count) = [];
        end
        function write(obj, byte, precision)
            assert(strcmp(precision, 'char') && isscalar(byte));
            obj.command = [obj.command byte];
            if strcmp(obj.command, 'QPHOTO')
                obj.buffer = sprintf('REMOTE MODE\r\n');
                obj.command = '';
            end
        end
        function writeline(obj, command)
            state = colormeasuretest.pr.state();
            switch command
                case {'B00', 'B100'}
                    obj.buffer = sprintf('Backlight set to %d %%\r\n', str2double(command(2:end)));
                case 'M5'
                    assert(isscalar(state.chunks), ...
                        'Legacy replay requires one complete reply; it must not wait on hardware.');
                    obj.buffer = state.chunks{1};
                case 'D14'
                    obj.buffer = sprintf('%s\r\n', state.flickerReply);
                case 'Q'
                    obj.buffer = '';
                otherwise
                    error('PR655Test:UnexpectedLegacyCommand', 'Unexpected legacy command: %s', command);
            end
        end
    end
end

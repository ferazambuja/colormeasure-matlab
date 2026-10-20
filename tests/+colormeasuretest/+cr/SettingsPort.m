classdef SettingsPort < colormeasuretest.cr.Port
    %SETTINGSPORT Mutable simulated settings, independently modelled RC/RS/SM.
    % No physical port, operating-system enumeration or native SDK calls.
    properties
        Setup
        Configuration
        IgnoreWrites = {}
        SideEffects
    end
    methods
        function obj = SettingsPort(model, clock)
            if nargin < 2, clock = []; end % Optional clock shared with the driver.
            obj@colormeasuretest.cr.Port(model, clock);
            obj.Setup = containers.Map('KeyType','char','ValueType','any');
            obj.Configuration = containers.Map('KeyType','char','ValueType','any');
            obj.SideEffects = containers.Map('KeyType','char','ValueType','any');
            rows = {'Mode',0;'ExposureMode',1;'Exposure',25;'RangeMode',1;'Range',3; ...
                'ExposureX',4;'SyncMode',0;'SyncFreq',60;'Speed',1; ...
                'Accessory',0;'Filter1',0;'Filter2',0;'Filter3',0; ...
                'UserCalibMode',0;'Matrix',7;'Match',9;'MaxAutoExposure',450};
            for k = 1:size(rows,1), obj.Setup(rows{k,1}) = rows{k,2}; end
            lists = {'Mode',{'0,Colorimeter','1,Flicker','2,Response Time'}; ...
                'ExposureMode',{'0,Auto','1,Fixed'}; ...
                'RangeMode',{'0,Auto','1,Fixed'};'Range',{'0,A','1,B','2,C','3,D'}; ...
                'SyncMode',{'0,None','1,Auto','2,Manual'}; ...
                'Speed',{'0,Slow','1,Normal','2,Fast','3,2x Fast'}; ...
                'Accessory',{'0,Standard,Radiance','5,IR-100,Irradiance'}; ...
                'Filter',{'3,ND-1,Radiance','4,ND-2,Radiance'}; ...
                'UserCalibMode',{'0,None','1,Matrix','2,Match'}; ...
                'Matrix',{'7,Display'};'Match',{'9,Reference'}};
            for k = 1:size(lists,1), obj.Configuration(lists{k,1}) = lists{k,2}; end
        end
    end
    methods (Access = protected)
        function text = defaultReply(obj,command)
            parts = strsplit(command,' ');
            if strcmp(parts{1},'SM') && numel(parts)==3
                token = parts{2}; value = str2double(parts{3});
                % Independent fixture enforces the documented CR100 dependency.
                if strcmp(obj.Model,'CR-100') && ...
                        ((strcmp(token,'RangeMode') && value==0 && obj.Setup('ExposureMode')==1) || ...
                        (strcmp(token,'ExposureMode') && value==1 && ...
                        (obj.Setup('RangeMode')~=1 || obj.Setup('Range')~=3)))
                    text = sprintf('ER:-519:%s:Invalid range for Fixed exposure\r\n',token); return
                end
                if ~ismember(command,obj.IgnoreWrites), obj.Setup(token) = value; end
                if isKey(obj.SideEffects,command)
                    effects = obj.SideEffects(command); fields = fieldnames(effects);
                    for k=1:numel(fields), obj.Setup(fields{k}) = effects.(fields{k}); end
                end
                if strcmp(token,'Accessory') && value==5
                    obj.Configuration('Matrix') = {'8,Irradiance matrix'};
                end
                if strcmp(token,'Mode'), token = 'SM Mode'; end
                text = sprintf('OK:0:%s:No errors\r\n',token); return
            end
            if numel(parts)==2 && strcmp(parts{1},'RC')
                token = parts{2};
                if isKey(obj.Configuration,token)
                    rows = obj.Configuration(token);
                    text = sprintf('OK:0:%s:%d\r\n',command,numel(rows));
                    for k = 1:numel(rows), text = [text sprintf('%s\r\n',rows{k})]; end %#ok<AGROW>
                    return
                end
                switch token
                    case 'MinExposure', value = '1.0 msec';
                    case 'MaxExposure', value = '30000.0 msec';
                    case 'MinExposureX', value = '1';
                    case 'MaxExposureX', value = '50';
                    case 'MinSyncFreq', value = '10.0 Hz';
                    case 'MaxSyncFreq', value = '10000.0 Hz';
                    otherwise, text = defaultReply@colormeasuretest.cr.Port(obj,command); return
                end
                text = sprintf('OK:0:%s:%s\r\n',command,value); return
            end
            if numel(parts)==2 && strcmp(parts{1},'RS')
                token = parts{2};
                if strcmp(token,'Aperture')
                    value = '0.5 deg';
                elseif strcmp(token,'Filter')
                    names = cell(1,3);
                    for k=1:3
                        names{k} = obj.optionName('Filter',obj.Setup(sprintf('Filter%d',k)));
                    end
                    value = strjoin(names,',');
                elseif ismember(token,{'Mode','ExposureMode','RangeMode','Range','SyncMode','Speed','Accessory','UserCalibMode'})
                    value = obj.optionName(token,obj.Setup(token));
                elseif strcmp(token,'Exposure')
                    value = sprintf('%.15g msec',obj.Setup(token));
                elseif strcmp(token,'SyncFreq')
                    value = sprintf('%.15g Hz',obj.Setup(token));
                else
                    value = sprintf('%.15g',obj.Setup(token));
                end
                text = sprintf('OK:0:%s:%s\r\n',command,value); return
            end
            text = defaultReply@colormeasuretest.cr.Port(obj,command);
        end
    end
    methods (Access = private)
        function name = optionName(obj,token,id)
            name = 'None'; rows = obj.Configuration(token);
            for k = 1:numel(rows)
                fields = strsplit(rows{k},',');
                if str2double(fields{1})==id, name = fields{2}; return; end
            end
        end
    end
end

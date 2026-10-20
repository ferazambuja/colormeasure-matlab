classdef CS2000Gonio < colormeasure.drivers.cs2000.CS2000 & colormeasure.drivers.cs2000.GonioMeasurementDevice
    % CS2000GONIO Acquire at paired pan/tilt angles using an external stage.
    %   Fernando Voltolini de Azambuja, 2026: validate before stage motion.
    %%%%%%%%%%%%%%%%%%%%
    % Member variables %
    %%%%%%%%%%%%%%%%%%%%
    properties ( SetAccess = 'protected' )
        % Instance of stage of PTU
        panTilt = [];
        % Measurement count
        measurementTime = 1;
    end % properties

    %%%%%%%%%%%%%%%%%%%%
    % Member functions %
    %%%%%%%%%%%%%%%%%%%%
    methods
        %
        % Constructor
        %
        % Arguments
        %   portNumber: Serial port number (Windows) or strings (Mac OS X)
        %        stage: Instance of stage of measurement devices
        % homePosition: Home position of CS-2000
        %      panTilt: Instance of stage of PTU
        %
        % Optional name-value arguments are passed to the CS2000 constructor.
        function h = CS2000Gonio( portNumber,stage,homePosition,panTilt,varargin )
            h = h@colormeasure.drivers.cs2000.CS2000( portNumber,varargin{:} );
            h = h@colormeasure.drivers.cs2000.GonioMeasurementDevice( stage, homePosition );
            h.panTilt = panTilt;
            h.measurementTime = 1;
        end

        %
        % Function for measurement
        %
        % Arguments
        %  measurementDirection: {panAngles, tiltAngles}, matched finite real vectors
        %
        % Return values
        %  dataFileName: a file name of measured data
        %
        % Failure aborts the sequence without homing, saving or clearing
        % earlier readings. Preserve partial data with Save before EraseAll
        % and restart; a new sequence otherwise appends to existing history.
        % Successful sequences use the next free csN.mat name. A save failure
        % leaves the completed history and sequence counter unchanged.
        function dataFileName = Measure(h,measurementDirection)
            % Validate the whole sequence before the first stage command.
            if ~iscell(measurementDirection) || ~isvector(measurementDirection) || ...
                    numel(measurementDirection) ~= 2 || ...
                    ~all(cellfun(@validDirections,measurementDirection)) || ...
                    numel(measurementDirection{1}) ~= numel(measurementDirection{2})
                error('CS2000:GonioDirections', ...
                    'Specify two nonempty, equally sized vectors of finite real pan and tilt angles.');
            end
            h.requireAcquisitionReady();

            % Pan and Tilt PTU, and Measure
            for index = 1:numel( measurementDirection{1} )
                h.panTilt.PanTilt( measurementDirection{1}(index), measurementDirection{2}(index) );
                h.panTilt.Wait;
                Measure@colormeasure.drivers.cs2000.CS2000(h);
            end

            % Skip occupied names, then publish without replacing any destination.
            for offset=0:9999
                number=h.measurementTime+offset;
                name=['cs' num2str(number)];
                if ~isfile([name '.mat']) && ~isfolder([name '.mat'])
                    h.saveSnapshot(name,false);
                    dataFileName={name};
                    h.measurementTime=number+1;
                    h.EraseAll();
                    return
                end
            end
            error('CS2000:SavePath','No unused sequence filename is available. Readings remain in memory.');
        end


    end
end

function valid = validDirections(angles)
valid = isnumeric(angles) && isreal(angles) && isvector(angles) && ...
    ~isempty(angles) && all(isfinite(angles(:)));
end

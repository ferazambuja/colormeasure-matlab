classdef GonioMeasurementDevice < handle

    %%%%%%%%%%%%%%%%%%%%
    % Member variables %
    %%%%%%%%%%%%%%%%%%%%
    properties ( SetAccess = 'private' )
        %
        homePosition = 0;
        stage = [];
    end % properties


    methods (Abstract)
        dataFileName = Measure(h,parameter);
    end

    methods
        function h = GonioMeasurementDevice( stage, homePosition )
            h.stage = stage;
            h.homePosition = homePosition;
        end

        function MoveToHome(h)
            if isempty( h.stage )
                error('CS2000:GonioStage','Stage of the measurement device has NOT been set');
            end

            h.stage.Move(1,h.homePosition);
        end

        function set.homePosition(h,homePosition)
            if ~isnumeric( homePosition )
                error('CS2000:GonioHome','Home position must be numeric');
            end
            h.homePosition = homePosition;
        end
    end
end
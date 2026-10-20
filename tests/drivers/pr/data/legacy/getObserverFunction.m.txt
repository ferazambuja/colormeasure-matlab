function [observer, lambda] = getObserverFunction(name, varargin)
    % GETOBSERVERFUNCTION Get a tristimulus observer function
    % 
    % [observer, lambda] = getObserevrFunction(NAME) gets the observer with the
    % name NAME at it's default wavelength spacing. Name can be any of 
    % 'xyz', 'xyz10', 'lms', 'lms2'.
    % 
    % [observer, lambda] = getObserevrFunction(NAME, WL) gets the observer with the
    % name NAME at each wavelength in the vector WL. Interpolates from the
    % observers default wavelength vector to the requested vector using
    % pchip. Does not return NAN. 
    % 
    % WL must be a vector of real numbers. No
    % other checks are done, but WL SHOULD also be monotonic for most use
    % cases. 
    
    if (nargin > 1)
        in = parseInputs(varargin{:});
    end
    
    % Persistent + isEmpty to only load files once
    persistent CIE1931_2Deg CIE1964_10Deg CIE2006_LMS_10Deg CIE2006_LMS_2Deg Stockman2012_2Deg Stockman2012_10Deg
    
    switch lower(name)
        case {'1931', '2deg', 'xyz', 'xyz2'}
            %%
            if isempty(CIE1931_2Deg)
                load('ObsFunctions.mat', 'CIE1931_2Deg');
            end
            observer = CIE1931_2Deg.data;
            lambda = CIE1931_2Deg.lambda;
            
        case {'1964', '10deg', 'xyz10'}
            %%
            if isempty(CIE1964_10Deg)
                load('ObsFunctions.mat', 'CIE1964_10Deg');
            end
            observer = CIE1964_10Deg.data;
            lambda = CIE1964_10Deg.lambda;
       
        case {'lms2', 'lms2deg'}
            %% LMS Comes from CVRL.org "CIE 2006 LMS functions, retrieved on
            %  2020-09-08
            
            if isempty(CIE2006_LMS_2Deg)
                load('ObsFunctions.mat', 'CIE2006_LMS_2Deg');
            end
            observer = CIE2006_LMS_2Deg.data;
            lambda = CIE2006_LMS_2Deg.lambda;
            
        case {'lms', 'lms10', 'lms10deg'}  
            %% LMS Comes from CVRL.org "CIE 2006 LMS functions, retrieved on 
            % 2020-09-08
 
            if isempty(CIE2006_LMS_10Deg)
                load('ObsFunctions.mat', 'CIE2006_LMS_10Deg');
            end
            observer = CIE2006_LMS_10Deg.data;
            lambda = CIE2006_LMS_10Deg.lambda;
        case {'2012','20122deg','xyz2012','stockman2deg'}
            %% Converted from 2006 LMS following CVRL.org instructions

            if isempty(Stockman2012_2Deg)
                load('ObsFunctions.mat','Stockman2012_2Deg')
            end
            observer = Stockman2012_2Deg.data;
            lambda = Stockman2012_2Deg.lambda;
        case {'201210deg','stockman10deg'}
            %% Converted from 2006 LMS following CVRL.org instructions

            if isempty(Stockman2012_10Deg)
                load('ObsFunctions.mat','Stockman2012_10Deg')
            end
            observer = Stockman2012_10Deg.data;
            lambda = Stockman2012_10Deg.lambda;           
    end
    %%
    if nargin > 1 && ~isempty(in.lambda)
        observer = interp1(lambda, observer, in.lambda, 'pchip', 0);
        lambda = in.lambda;
    end
    
    function options = parseInputs(varargin)
        narginchk(0,1); % doc nargincheck
        persistent parser; 
        if isempty(parser)
            % Set up parser
            parser = inputParser();
            parser.FunctionName = mfilename;
            
            parser.addOptional('lambda', [], ...
                @validateLambda);
        end
        parser.parse(varargin{:})
        options = parser.Results;
    end
end
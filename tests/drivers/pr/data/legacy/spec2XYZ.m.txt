function [XYZ] = spec2XYZ(radiance, lambda, observer)
% spectralRadiance2XYZ converts radiance to CIE 1931 2deg XYZ
%
% Input radiance in W/st/m^2, Y is returned as cd/m^2. Lamda must be a
% vector describing the wavelength sampling of radiance. numel(lambda) = N.
% Radiance is an M x N or N x M matrix with M radiance samples. XYZ is
% returned as a M x 3 matrix. Square input matracies will be interpreted as
% column vectors.

%% Error Checking

arguments
    radiance
    lambda (:, 1) = nan;
    observer = 'xyz'
end

if isnan(lambda)
    warning('Assuming wavelength sample based on size of reflectance.')
    lambda = guessWL(radiance(:,1));
end

if ~any(size(radiance)==numel(lambda))
    error('Number of elements in lambda must match the dimmension of radiance');
end

if size(radiance, 1) ~= numel(lambda) && size(radiance,2) ~= size(radiance,1)
    radiance = radiance';
end
%% Load Data


persistent obsDB;
if isempty(obsDB)
    obsDB = struct();
end

obsVName = "x" + observer;

if ~isfield(obsDB, obsVName);
    [obsDB.(obsVName).data, obsDB.(obsVName).lambda] = getObserverFunction(observer);
end

if ~isfield(obsDB.(obsVName),"lastLambda") || ~isequal(obsDB.(obsVName).lastLambda, lambda);
    obsDB.(obsVName).lastLambda = lambda;
    obsDB.(obsVName).stdob = interp1(obsDB.(obsVName).lambda, obsDB.(obsVName).data, obsDB.(obsVName).lastLambda, 'spline', 0);
    
    c = 299792458;                 % Speed of light in a vacuum
    peak = (1/540e12 * c) / 1e-9;  % the candela wavelength in nm
    
    % peak ~ 555nm, Used to calculate the scale such that this function retuns
    % results in candela. See the definition of candela on Wikipedia:
    %
    % The candela is defined by taking the fixed numerical value of the
    % luminous efficacy of monochromatic radiation of frequency 540 × 1012 Hz,
    % Kcd, to be 683 when expressed in the unit lm W–1.
    %
    % https://en.wikipedia.org/wiki/Candela
    obsDB.(obsVName).scale = (683 * (lambda(2)-lambda(1))) ./ interp1(obsDB.(obsVName).lambda, obsDB.(obsVName).data(:, 2), peak);
end
%% Calculations

XYZ = obsDB.(obsVName).scale .* (obsDB.(obsVName).stdob' * radiance)';
end


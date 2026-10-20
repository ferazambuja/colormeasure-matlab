function setupColorMeasure()
% SETUPCOLORMEASURE Add this installation's runtime to the MATLAB path.
%   Run once from the project folder. Tests and tools are not added.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0,0);
folder = fileparts(mfilename('fullpath'));
addpath(fullfile(folder,'src'));
end

function folder = root()
% ROOT Absolute installation folder, independent of the current directory.
%   Fernando Voltolini de Azambuja, 2026.
folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

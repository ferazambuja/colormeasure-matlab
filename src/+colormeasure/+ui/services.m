function io = services(io)
% SERVICES Add optional desktop operations to measurement core services.
%   Existing overrides are retained for custom launchers and software tests.
%   Fernando Voltolini de Azambuja, 2026.
if nargin == 0, io = colormeasure.session.services(); end
defaults = struct('chooseFolder', @chooseFolder, ...
    'createView', @colormeasure.ui.Window, 'launchSession', @colormeasure.ui.launchSession);
names = fieldnames(defaults);
for index = 1:numel(names)
    name = names{index};
    if ~isfield(io, name), io.(name) = defaults.(name); end
end
end

function folder = chooseFolder(previous)
folder = colormeasure.ui.chooseMeasurementFolder(previous);
if isequal(folder, 0), folder = ''; end
end

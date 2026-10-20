function [cmf, wavelength] = observer()
% OBSERVER CIE 1931 2-degree CMFs at 360:1:830 nm, independent of MATLAB path.
%   Data: CIE 2019, DOI 10.25039/CIE.DS.xvudnb9b, CC BY-SA 4.0.
%   Fernando Voltolini de Azambuja, 2026. See resources/colorimetry/README.md.
persistent values
if isempty(values)
    root = colormeasure.root();
    candidate = readmatrix(fullfile(root,'resources','colorimetry','CIE_xyz_1931_2deg.csv'));
    if ~isequal(size(candidate),[471 4]) || ~isequal(candidate(:,1),(360:830)') || ...
            any(~isfinite(candidate),'all')
        error('colormeasure:Colorimetry:ObserverData','The bundled CIE observer table is invalid.');
    end
    values = candidate;
end
cmf = values(:,2:4);
wavelength = values(:,1);
end

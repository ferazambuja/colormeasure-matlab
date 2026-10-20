function [wavelength,step] = uniformGrid(wavelength)
% Shared explicit wavelength contract; no observer lookup or resampling.
if ~isa(wavelength,'double') || ...
        ~isreal(wavelength) || ~isvector(wavelength) || ...
        numel(wavelength)<2 || any(~isfinite(wavelength))
    error('colormeasure:Colorimetry:Wavelength','Supply at least two finite real double wavelengths in nm.');
end
wavelength = double(wavelength(:));
steps = diff(wavelength);
% Cap roundoff tolerance relative to spacing, so nearly coincident but
% meaningfully irregular samples cannot pass on an absolute nm tolerance.
tolerance = min(4*eps(max(1,max(abs(wavelength)))),abs(steps(1))*1e-8);
if any(wavelength<=0) || any(steps<=0) || any(~isfinite(steps)) || ...
        any(abs(steps-steps(1))>tolerance)
    error('colormeasure:Colorimetry:Wavelength','Wavelengths must be positive, increasing and uniformly spaced.');
end
step = steps(1);
end

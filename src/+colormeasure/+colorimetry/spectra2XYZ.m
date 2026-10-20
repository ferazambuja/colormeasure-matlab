function XYZ = spectra2XYZ(spectra, wavelength)
% SPECTRA2XYZ Convert spectra to CIE 1931 2-degree XYZ on an explicit nm grid.
%   XYZ = colormeasure.colorimetry.spectra2XYZ(spectra, wavelength)
%   N x M spectra (or M x N) produce M x 3 double XYZ. Square spectra are
%   columns. Wavelengths must be double, increasing and uniform; they are not guessed.
%   This first version preserves the MCSL numerical integration convention.
%   Use colormeasure.colorimetry.XYZIntegrator for repeated calls on a fixed grid.
%   Fernando Voltolini de Azambuja, 2026. See docs/colorimetry/science.md.
narginchk(2,2);
% Bounded cache avoids repeated preparation in ordinary single-grid scripts.
% An explicit immutable integrator is preferable when several grids alternate.
persistent integrator
if isempty(integrator) || ...
        ~(isa(wavelength,'double') && isreal(wavelength) && isvector(wavelength) && ...
          isequal(integrator.Wavelength,double(wavelength(:))))
    integrator = colormeasure.colorimetry.XYZIntegrator(wavelength);
end
XYZ = integrator.convert(spectra);
end

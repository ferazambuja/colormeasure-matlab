function [XYZ, integratedSpectrum] = spectralValues(spectrum, wl)
%SPECTRALVALUES Retain the existing CR spectral integration convention.
% Signed bins are preserved. Input is assumed per nm; the radiometric quantity
% determines the other dimensions. This denominator requires vendor confirmation
% (see docs/drivers/cr/color-science.md). Output two is a generic band integral; it
% is radiance only for radiometric type 0.
% XYZ uses bundled colormeasure.colorimetry CIE 1931 2-degree data and legacy scaling.
% colormeasure.colorimetry applies a stricter roundoff-only uniform-grid check; never resample.
% References: https://doi.org/10.25039/CIE.DS.xvudnb9b
% https://www.nist.gov/pml/sensor-science/optical-radiation/realization-candela
if ~isnumeric(spectrum) || ~isreal(spectrum) || ~isvector(spectrum) || ...
        ~isnumeric(wl) || ~isreal(wl) || ~isvector(wl) || ...
        numel(wl) < 2 || numel(spectrum) ~= numel(wl) || ...
        any(~isfinite(spectrum(:))) || any(~isfinite(wl(:))) || any(wl(:) <= 0)
    error('CR:InvalidSpectrum', 'Spectrum and positive wavelengths must be matching finite real vectors.');
end
spectrum = double(spectrum(:));
wl = double(wl(:));
steps = diff(wl);
delta = steps(1);
if delta <= 0 || any(abs(steps - delta) > 1e-9 * max(1, abs(delta)))
    error('CR:InvalidSpectrum', 'Wavelengths must increase with uniform spacing.');
end

% Uniform-grid rectangle sum, including both endpoints, as in the CR API.
% Do not resample, normalize or clip the acquired spectrum.
try
    XYZ = colormeasure.colorimetry.spectra2XYZ(spectrum, wl);
    integratedSpectrum = colormeasure.colorimetry.spectralIntegral(spectrum, wl);
catch exception
    switch exception.identifier
        case 'colormeasure:Colorimetry:Wavelength'
            error('CR:InvalidSpectrum', 'Wavelengths must increase with uniform double-precision spacing.');
        case 'colormeasure:Colorimetry:NumericRange'
            error('CR:DerivedOverflow', 'Spectral integration produced nonfinite values.');
        otherwise
            rethrow(exception);
    end
end
if ~isreal(XYZ) || any(~isfinite(XYZ(:))) || ~isfinite(integratedSpectrum)
    error('CR:DerivedOverflow', 'Spectral integration produced nonfinite or nonreal values.');
end
end

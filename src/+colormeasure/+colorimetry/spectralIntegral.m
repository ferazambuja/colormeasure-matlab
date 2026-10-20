function value = spectralIntegral(spectra,wavelength)
% SPECTRALINTEGRAL Inclusive uniform-step sum, preserving measurement convention.
%   One result per spectrum, as an M x 1 column. This is not trapz and is not
%   photon weighting. Input spectral density times nm gives the integral units
%   only when the input per-nm density is established. Signed bins are retained.
%   Fernando Voltolini de Azambuja, 2026.
[wavelength,step] = uniformGrid(wavelength);
n = numel(wavelength);
if ~(isa(spectra,'single') || isa(spectra,'double')) || ~ismatrix(spectra) || ...
        ~isreal(spectra) || any(~isfinite(spectra),'all')
    error('colormeasure:Colorimetry:Spectrum','Spectra must be finite real single or double values.');
end
if size(spectra,1)==n
    value = sum(double(spectra),1).' * step;
elseif size(spectra,2)==n
    value = sum(double(spectra),2) * step;
else
    error('colormeasure:Colorimetry:SpectrumShape','One spectrum dimension must match the wavelength count.');
end
if any(~isfinite(value)), error('colormeasure:Colorimetry:NumericRange','Integral exceeds finite range.'); end
end

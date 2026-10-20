function spectra=spectralColumns(spectra,count,label)
% Validate spectra with explicit wavelength count; square arrays use columns.
if ~(isa(spectra,'single')||isa(spectra,'double')) || ~isreal(spectra) || ...
        ~ismatrix(spectra) || any(~isfinite(spectra),'all')
    error('colormeasure:Colorimetry:Spectrum','%s must be a finite real single or double matrix.',label);
end
if size(spectra,1)==count
    spectra=double(spectra);
elseif size(spectra,2)==count
    spectra=double(spectra.');
else
    error('colormeasure:Colorimetry:SpectrumShape','One %s dimension must match the wavelength count.',label);
end
end

function [reflectance, meta] = reflectanceFromReference(sample, reference, referenceReflectance, wavelength)
% REFLECTANCEFROMREFERENCE Estimate a spectral factor using a measured reference.
%   R = sample ./ reference .* referenceReflectance on ONE explicit nm grid.
%   The caller establishes identical wavelengths, units, illumination, geometry
%   and instrument settings. No resampling, dark correction or clipping occurs.
%   Sample spectra are N-by-M or M-by-N; result is N-by-M, square inputs use
%   columns. Reference and its characterized factor must each be one N-vector.
%   Factors use fraction units (1=100%). Signed samples and R>1 are retained.
%   Reference bins <= sqrt(eps)*peak or nonpositive are refused. This is only
%   a numerical floor, not a measured noise or signal-to-noise qualification.
%   Definitions: https://cie.co.at/eilvterm/17-24-070 and 17-24-075.
%   Reference-measurement workflow: Konica Minolta CS-S10w manual, 2.10.15.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
narginchk(4,4);
[wavelength,step]=uniformGrid(wavelength);
count=numel(wavelength);
sample=spectralColumns(sample,count,'Sample');
reference=spectralColumns(reference,count,'Reference');
referenceReflectance=spectralColumns(referenceReflectance,count,'Reference reflectance');
if size(reference,2)~=1 || size(referenceReflectance,2)~=1
    error('colormeasure:Colorimetry:SpectrumShape','Reference and characterized reflectance must each contain one spectrum.');
end
if any(referenceReflectance<=0)
    error('colormeasure:Colorimetry:ReferenceReflectance','Characterized reference reflectance must be positive fractions.');
end
relativeFloor=sqrt(eps('double'));
peak=max(reference);
if peak<=0 || any(reference<=0) || any(reference/peak<=relativeFloor)
    error('colormeasure:Colorimetry:WeakReference', ...
        'Reference has nonpositive or weak bins (at most sqrt(eps) of its peak); no ratio was calculated.');
end
reflectance=(sample./reference).*referenceReflectance;
if any(~isfinite(reflectance),'all')
    error('colormeasure:Colorimetry:NumericRange','Reference-normalized reflectance exceeds the finite calculation range.');
end
meta=struct('method','Sample/reference times characterized reference reflectance', ...
    'quantity','Estimated spectral reflectance factor','units','fraction (1 = 100%)', ...
    'wavelength',wavelength,'wavelengthRangeNm',wavelength([1 end]).', ...
    'wavelengthStepNm',step,'referenceReflectance',referenceReflectance, ...
    'referenceRelativeFloor',relativeFloor,'minimumReference',min(reference), ...
    'maximumReference',peak,'hasNegativeEstimates',any(reflectance<0,'all'), ...
    'hasEstimatesAboveOne',any(reflectance>1,'all'), ...
    'limitations','Same grid, illumination, geometry and numerical scale required; fluorescence is not modeled');
end

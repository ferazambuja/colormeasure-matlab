function [XYZ, white, meta] = reflectanceXYZ(reflectance, wavelength, illuminant)
% REFLECTANCEXYZ Integrate a spectral factor under an explicit illuminant SPD.
%   Illuminant is D50/D65/A or a nonnegative SPD vector on the same grid.
%   Factors use fractions (1=100%); N-by-M or M-by-N input gives M-by-3 XYZ.
%   WHITE is the 1-by-3 perfect-diffuser XYZ on this grid, normalized to Y=100.
%   CIE 1931 2-degree CMFs are linearly interpolated to the uniform native
%   measurement grid, wholly within 360-830 nm. No extrapolation/resampling
%   of measured factors; no 683 multiplier, chromatic adaptation or clipping.
%   Object-colour normalization and uniform sum: Changjun Li, CIE TC1-71
%   Perspective: An Overview on Accurately Computing Tristimulus Values
%   (2008), p. 22, equations (1)-(3):
%   https://library.imaging.org/admin/apis/public/api/ist/website/downloadArticle/cic/16/1/art00005
%   Evaluated on the supplied grid without spectral bandpass correction;
%   no CIE standard conformance is claimed for arbitrary or truncated grids.
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
narginchk(3,3);
[wavelength,step]=uniformGrid(wavelength);
[cmf,native]=colormeasure.colorimetry.observer();
if wavelength(1)<native(1) || wavelength(end)>native(end)
    error('colormeasure:Colorimetry:ObserverDomain','Reflectance integration must stay within the CIE observer range 360-830 nm.');
end
reflectance=spectralColumns(reflectance,numel(wavelength),'Reflectance');
if ischar(illuminant)||isstring(illuminant)
    [spd,illuminantMeta]=colormeasure.colorimetry.illuminantSpectrum(illuminant,wavelength);
else
    spd=spectralColumns(illuminant,numel(wavelength),'Illuminant');
    if size(spd,2)~=1
        error('colormeasure:Colorimetry:SpectrumShape','Illuminant must be one spectrum on the reflectance grid.');
    end
    illuminantMeta=struct('name','Custom SPD','source','Caller-supplied spectrum on the measurement grid', ...
        'interpolation','None','extrapolation','None','units','Relative spectral power distribution');
end
if any(spd<0) || ~any(spd>0)
    error('colormeasure:Colorimetry:IlluminantSpectrum','Illuminant SPD must be nonnegative with at least one positive bin.');
end
matching=interp1(native,cmf,wavelength,'linear');
% Relative SPD scaling prevents overflow and cancels in the Y normalization.
% The common uniform step cancels too: inclusive sums use both endpoints.
weighted=matching.*(spd/max(spd));
denominator=sum(weighted(:,2));
if ~isfinite(denominator) || denominator<=0
    error('colormeasure:Colorimetry:IlluminantSpectrum','Illuminant has no finite positive photopic weight on this grid.');
end
weights=weighted/denominator;
XYZ=100*(weights.'*reflectance).';
white=100*sum(weights,1);
if any(~isfinite(XYZ),'all') || any(~isfinite(white))
    error('colormeasure:Colorimetry:NumericRange','Reflectance XYZ exceeds the finite calculation range.');
end
meta=struct('method','CIE 1931 2-degree; inclusive uniform spectral sum; perfect diffuser Y=100', ...
    'observerId','CIE1931_2deg','observerSource','CIE 10.25039/CIE.DS.xvudnb9b', ...
    'illuminant',illuminantMeta,'illuminantSPD',spd,'whiteXYZ',white, ...
    'wavelength',wavelength,'wavelengthRangeNm',wavelength([1 end]).','wavelengthStepNm',step, ...
    'limitedRange',wavelength(1)>native(1)||wavelength(end)<native(end), ...
    'cmfInterpolation','Linear','extrapolation','None','XYZUnits','Relative XYZ; perfect diffuser Y=100', ...
    'hasNegativeReflectance',any(reflectance<0,'all'), ...
    'hasReflectanceAboveOne',any(reflectance>1,'all'));
end

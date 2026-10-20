function [rgb,valid,clipped,context]=relativeColor(XYZ,whiteXYZ,observerId)
%RELATIVECOLOR Approximate sRGB with one explicit relative white and Y scale.
%   XYZ is N-by-3. whiteXYZ is a positive 1-by-3 reference in the SAME scale.
%   observerId must be CIE1931_2deg: changing observer needs spectral data,
%   not a label change. Finite nonnegative XYZ rows are eligible, including
%   black. Invalid rows return NaN and valid=false. Numerical overflow errors.
%   All rows are divided by white Y together, then Bradford-adapted to the
%   ICC sRGB D65 white. No patch is normalized to its own brightness.
%   The shared matrix and transfer function clip outside [0,1]; clipped is
%   a display status, not measurement validity or a color-difference result.
%   Input values are never changed. A display profile/viewing model is absent.
%   ICC sRGB interpretation A.3/A.6-A.8 and ICC.1:2004-10 Annex E.3:
%   https://registry.color.org/rgb-registry/files/sRGB.pdf
%   https://www.color.org/ICC1V42.pdf
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
validateattributes(XYZ,{'numeric'},{'2d','ncols',3});
assert(isnumeric(whiteXYZ)&&isreal(whiteXYZ)&&isequal(size(whiteXYZ),[1 3])&& ...
    all(isfinite(whiteXYZ))&&all(whiteXYZ>0), ...
    'colormeasure:Colorimetry:RelativeWhite','Supply positive finite white XYZ in the readings'' scale.');
text=(ischar(observerId)&&isrow(observerId))|| ...
    (isstring(observerId)&&isscalar(observerId)&&~ismissing(observerId));
assert(text&&strcmp(observerId,'CIE1931_2deg'), ...
    'colormeasure:Colorimetry:RelativeObserver','Relative sRGB needs the CIE 1931 2-degree observer.');
destinationWhite=[.9505 1 1.089]; % ICC sRGB A.3: [76.04 80 87.12] / 80.
valid=all(imag(XYZ)==0,2)&all(isfinite(XYZ),2)&all(real(XYZ)>=0,2);
rgb=NaN(size(XYZ));clipped=false(size(XYZ,1),1);
values=double(real(XYZ(valid,:)))./double(whiteXYZ(2));
assert(all(isfinite(values),'all'),'colormeasure:Colorimetry:NumericRange', ...
    'Relative XYZ exceeds the supported numerical range.');
adapted=colormeasure.colorimetry.adaptXYZ(values,double(whiteXYZ),destinationWhite);
linear=linearSRGB(adapted);
assert(all(isfinite(linear),'all'),'colormeasure:Colorimetry:NumericRange', ...
    'Linear display values exceed the supported numerical range.');
[rgb(valid,:),clipped(valid)]=encodeSRGB(linear);
context=struct('observerId','CIE1931_2deg','whiteXYZ',double(whiteXYZ), ...
    'destinationWhiteXYZ',destinationWhite,'scale','shared reference-white Y', ...
    'adaptation','Bradford','encoding','sRGB','brightnessNormalizedPerSample',false);
end

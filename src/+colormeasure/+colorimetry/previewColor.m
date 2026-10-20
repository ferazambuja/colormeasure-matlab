function [rgb, valid, clipped] = previewColor(XYZ, whiteXYZ)
% PREVIEWCOLOR Approximate sRGB chromaticity swatches, brightness normalized.
%   Each nonblack preview has a maximum linear RGB channel of one. Swatches
%   do not represent measured luminance or calibrated appearance. Negative
%   linear RGB channels are clipped; invalid integrated XYZ has no preview.
%   Fernando Voltolini de Azambuja, 2026.
%   Matrix/encoding: ICC sRGB interpretation, A.7-A.8, pp. 1-2:
%   https://registry.color.org/rgb-registry/files/sRGB.pdf
%   Optional whiteXYZ declares the XYZ reference white: Bradford adaptation
%   to the ICC sRGB D65 white precedes brightness normalization. The caller
%   must establish the CIE 1931 observer and shared input white. Without this
%   argument, the original display interpretation is preserved exactly.
%   Clipping and max-channel normalization are project display choices,
%   not an ICC profile transform. See docs/colorimetry/science.md.
narginchk(1,2);
validateattributes(XYZ,{'numeric'},{'2d','ncols',3});
if nargin==2
    assert(isnumeric(whiteXYZ)&&isreal(whiteXYZ)&&isequal(size(whiteXYZ),[1 3])&& ...
        all(isfinite(whiteXYZ))&&all(whiteXYZ>0),'colormeasure:Colorimetry:RelativeWhite', ...
        'Supply positive finite white XYZ in the readings'' scale.');
end
valid=all(imag(XYZ)==0,2) & all(isfinite(XYZ),2) & all(real(XYZ)>=0,2);
rgb=NaN(size(XYZ)); clipped=false(size(XYZ,1),1);
values=double(real(XYZ(valid,:)));
scale=max(values,[],2); black=scale==0; scale(black)=1;
values=values./scale;
if nargin==2
    values=colormeasure.colorimetry.adaptXYZ(values,double(whiteXYZ),[.9505 1 1.089]);
end
linear=linearSRGB(values);
clipped(valid)=any(linear<0,2);
linear=max(0,linear); scale=max(linear,[],2); scale(scale==0)=1;
linear=linear./scale;
rgb(valid,:)=encodeSRGB(linear);
end

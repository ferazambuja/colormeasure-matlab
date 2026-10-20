function [CCT, Duv] = cct(XYZ)
%CCT The bundled colormeasure.colorimetry Ohno-style CCT calculation for one reading.
% CCT is kelvin; Duv is signed distance in CIE 1960 UCS (u,v).
% Unavailable values are a NaN pair; the original XYZ is never changed.
% XYZ2CCT owns the applicability policy: it judges the integrated XYZ (a
% signed spectral bin alone is not a reason to reject colorimetry) and
% returns the NaN pair outside its table and Duv limits. This wrapper adds
% only the one-reading shape check and its CR identifier.
% CIE TN 013:2022 section 6: https://doi.org/10.25039/TN.013.2022
% Ohno (2014): https://doi.org/10.1080/15502724.2014.839020
if ~isnumeric(XYZ) || ~isvector(XYZ) || numel(XYZ) ~= 3
    error('CR:InvalidXYZ', 'XYZ must contain one numeric tristimulus triplet.');
end
[CCT, Duv] = colormeasure.colorimetry.XYZ2CCT(double(reshape(XYZ, 1, 3)));
end

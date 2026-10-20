function [rmsDifference,residual] = spectralRMS(a,lambdaA,b,lambdaB)
% SPECTRALRMS Raw RMS difference of two spectra; signed residual is B minus A.
%   Requires identical increasing uniform grids and column/row vectors.
%   The caller must establish compatible quantities and units. RMS is in the
%   spectral input units, not Delta E, uncertainty, or statistical significance.
%   Fernando Voltolini de Azambuja, 2026.
if ~(isvector(a)&&isvector(b)) || numel(a)~=numel(b) || ...
        ~isreal(a)||~isreal(b) || ...
        ~(isa(a,'double')||isa(a,'single')) || ~(isa(b,'double')||isa(b,'single')) || ...
        any(~isfinite(a))||any(~isfinite(b))
    error('colormeasure:Colorimetry:Spectrum','Supply two finite real spectral vectors of equal length.');
end
lambdaA = uniformGrid(lambdaA);
lambdaB = uniformGrid(lambdaB);
if ~isequal(lambdaA,lambdaB) || numel(a)~=numel(lambdaA)
    error('colormeasure:Colorimetry:Wavelength','RMS requires identical wavelength grids without resampling.');
end
residual = double(b(:))-double(a(:));
if any(~isfinite(residual)), error('colormeasure:Colorimetry:NumericRange','Residual exceeds finite range.'); end
scale = max(abs(residual));
if scale==0
    rmsDifference = 0;
else
    % Scale before the native norm to avoid extreme-value overflow/underflow.
    % The normalized RMS cannot exceed one; cap floating-point roundoff there.
    rmsDifference = scale*min(1,norm(residual/scale,2)/sqrt(numel(residual)));
end
end

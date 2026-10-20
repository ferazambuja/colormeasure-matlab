function result=colorValues(reading,attempt)
%COLORVALUES Preserve native chart quantities without inventing reflectance.
% Direct radiance/luminance and naming-only acquisitions do not establish the
% relative XYZ/white context required for measured chart fills or placement.
% Ordinary native color calculations remain with colormeasure.colorimetry.
result=struct('available',false,'XYZ',[],'context',struct(), ...
    'provenance',struct(),'reason', ...
    'Acquired radiance/luminance or naming-only data is retained; relative chart color is unavailable.');
accepted=attempt.acceptedContext;
if ~isstruct(accepted)||~isscalar(accepted)|| ...
        ~all(isfield(accepted,{'phase','route','material'}))||~strcmp(accepted.phase,'accepted'),return;end
colormeasure.chart.assertDirectSource(accepted,reading);
end

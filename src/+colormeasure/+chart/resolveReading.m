function [reading,facts]=resolveReading(chart,measurements,attempt,index)
%RESOLVEREADING Resolve an original segment/index without a live old adapter.
% Inherited observations stay in the flat source registry. They never enter
% this segment's acquisition-order measurement array.
if nargin<4,index=attempt.readingIndices;end
identifier='Measurement:ChartReference';
assert(isfield(attempt,'segmentId')&&colormeasure.session.isText(attempt.segmentId), ...
    identifier,'A chart attempt must name its original segment.');
inherited=~strcmp(attempt.segmentId,chart.segmentId);
owner=measurements;
if inherited
    matches=find(strcmp({chart.sources.segmentId},attempt.segmentId));
    assert(isscalar(matches),identifier,'The original chart reading segment is missing or ambiguous.');
    owner=chart.sources(matches).measurements;
end
assert(isnumeric(index)&&isreal(index)&&isscalar(index)&&isfinite(index)&& ...
    index==fix(index)&&index>=1&&index<=numel(owner),identifier, ...
    'A chart reading reference must name one retained original reading.');
reading=owner(index);
facts=struct('segmentId',char(attempt.segmentId),'readingIndex',index,'inherited',inherited, ...
    'name',colormeasure.session.textField(reading,'name'),'notes',colormeasure.session.textField(reading,'notes'), ...
    'XYZ',[],'xyzUnits',colormeasure.session.textField(reading,'xyzUnits'), ...
    'spectralQuantity',colormeasure.session.textField(reading,'spectralQuantity'));
if isfield(reading,'XYZ'),facts.XYZ=reading.XYZ;end
colormeasure.chart.assertDirectSource(struct(),reading);
end

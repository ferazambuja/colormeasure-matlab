function result = catalogClassification(route, controls)
%CATALOGCLASSIFICATION Classify acquisition options for chart pass boundaries.
% Catalogues remain owned by the drivers/descriptors. This helper classifies
% their keys; it does not invent availability, choices or instrument facts.
% A newly added key requires an explicit completion-context decision here.
route = upper(char(route));
switch route
    case 'PR'
        material = {'exposureMilliseconds','syncMode','syncFrequencyHz', ...
            'primaryAccessoryId','addon1Id','addon2Id','addon3Id','apertureId', ...
            'sensitivityMode','smartDark','shutterMode'};
        count = {'cycles'};
        provenance = {'photometricUnits','instrumentObserver'};
    case 'CR'
        material = {'mode','exposureMode','exposureMs','rangeMode','range', ...
            'exposureMultiplier','syncMode','syncFrequencyHz','speed','accessory', ...
            'aperture','filter1','filter2','filter3','userCalibrationMode', ...
            'matrixId','matchId','maxAutoExposureMs'};
        count = {}; provenance = {};
    case 'CS2000'
        material = {'speedMode','integrationTimeSeconds','internalNDMode', ...
            'syncMode','frequencyHz','measurementAngleDegrees','closeupLens', ...
            'externalNDFilter','userCalibrationChannel'};
        count = {}; provenance = {};
    otherwise
        error('Chart:ContextCatalog','No chart-context classification for route %s.', route);
end
if iscell(controls)
    ids = cellfun(@(item) char(item.id), controls, 'UniformOutput', false);
elseif isstruct(controls) && isempty(controls)
    ids = {};
elseif isstruct(controls) && isfield(controls,'id')
    ids = {controls.id};
else
    error('Chart:ContextCatalog','Acquisition controls must carry their catalogue IDs.');
end
assert(numel(unique(ids)) == numel(ids), 'Chart:ContextCatalog', ...
    'Acquisition catalogue contains duplicate keys.');
unknown = setdiff(ids,[material count provenance]);
assert(isempty(unknown),'Chart:ContextCatalog', ...
    'Unclassified acquisition options: %s.',strjoin(unknown,', '));
result = struct('route',route,'material',{material},'count',{count}, ...
    'provenance',{provenance},'catalogueKeys',{ids});
end

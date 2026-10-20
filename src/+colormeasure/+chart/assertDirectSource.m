function assertDirectSource(info,readings)
%ASSERTDIRECTSOURCE Refuse unsupported acquisition formats before interpretation.
% Retired fields do not identify a particular producer. Refusal preserves the
% original files and ordinary saved values for plain MATLAB load inspection.
identifier='Measurement:DirectSource';
assert(isstruct(info)&&isscalar(info)&&isstruct(readings),identifier, ...
    'Supply ordinary direct acquisition facts and readings.');
assert(~any(isfield(info,{'operationContext','operationSetup','operations', ...
    'operationCount','unacceptedOperations'}))&& ...
    ~any(isfield(readings,{'canonicalOperationJson','operationId','operationStatus'})),identifier, ...
    'This acquisition format is unsupported here. Ordinary saved MAT values remain available for plain load inspection; the original data was not changed.');
if isfield(info,'configuration')&&isstruct(info.configuration)
    assert(~isfield(info.configuration,'operationContext'),identifier, ...
        'This saved source uses an acquisition format unavailable in this installation.');
end
if isfield(info,'route')
    assert(~strcmp(info.route,'ARGYLL'),identifier, ...
        'This chart uses an acquisition route unavailable in this installation.');
end
if isfield(info,'adapterKey')
    assert(~startsWith(string(info.adapterKey),'ARGYLL'),identifier, ...
        'This acquisition adapter is unavailable in this installation.');
end
if isfield(info,'catalogIdentity')&&isstruct(info.catalogIdentity)&&isfield(info.catalogIdentity,'key')
    assert(~startsWith(string(info.catalogIdentity.key),'ARGYLL'),identifier, ...
        'This saved source uses an acquisition adapter unavailable in this installation.');
end
end

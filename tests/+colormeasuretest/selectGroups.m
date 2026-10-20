function [selection, definitions] = selectGroups(groups)
%SELECTGROUPS Resolve test scope independently of discovery or execution.
% An all-group selection describes scope, not completion or hardware coverage.
catalog = colormeasuretest.groupCatalog();
available = {catalog.key};
if nargin == 0 || isempty(groups), groups = available; end
if ischar(groups) && isrow(groups), groups = {groups}; end
if isstring(groups) && isvector(groups) && ~any(ismissing(groups))
    groups = cellstr(groups);
end
assert(iscellstr(groups) && isvector(groups) && ...
    all(ismember(groups,available)) && numel(unique(groups)) == numel(groups), ...
    'measurement:TestGroups','Choose each known test group at most once.');
groups = reshape(groups,1,[]);
omitted = setdiff(available,groups,'stable');
selection = struct('availableGroups',{available},'selectedGroups',{groups}, ...
    'omittedGroups',{omitted},'isPartialRun',~isempty(omitted));
[~,indices] = ismember(groups,available);
definitions = catalog(indices);
end

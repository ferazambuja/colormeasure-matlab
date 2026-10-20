function differences = contextDifference(before, after)
%CONTEXTDIFFERENCE Compare readable chart material facts, never opaque IDs.
% Intent cannot re-read the instrument: unavailable readback in an intended
% context is not evidence of loss. Accepted readings must retain previously
% established facts. Newly known facts enrich a pass without discarding it.
% Source/certainty changes alone and count-only averages are not pass changes.
assert(isstruct(before)&&isscalar(before)&&isfield(before,'material')&& ...
    isstruct(after)&&isscalar(after)&&isfield(after,'material'), ...
    'Chart:Context','Supply two retained chart contexts.');
differences = struct('key',{},'kind',{},'before',{},'after',{},'message',{});
keys = union(fieldnames(before.material),fieldnames(after.material));
accepted = isfield(after,'phase') && strcmp(after.phase,'accepted');
for index = 1:numel(keys)
    key = keys{index}; old = getFact(before.material,key); new = getFact(after.material,key);
    oldKnown = ~strcmp(old.certainty,'unknown'); newKnown = ~strcmp(new.certainty,'unknown');
    kind = '';
    if oldKnown && newKnown && ~isequaln(old.value,new.value)
        kind = 'changed';
    elseif ~oldKnown && newKnown && ~accepted && strcmp(new.certainty,'requested')
        kind = 'specified';
    elseif oldKnown && ~newKnown && accepted
        kind = 'lost';
    end
    if isempty(kind), continue; end
    differences(end+1) = struct('key',key,'kind',kind, ...
        'before',old,'after',new,'message', ...
        sprintf('%s: %s.',colormeasure.chart.settingLabel(key),kind)); %#ok<AGROW>
end
end

function value = getFact(material,key)
value = struct('value',[],'certainty','unknown','source','not reported');
if isfield(material,key), value = material.(key); end
assert(isstruct(value)&&isscalar(value)&&all(isfield(value,{'value','certainty','source'})), ...
    'Chart:Context','Material facts require value, certainty and source.');
end

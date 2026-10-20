function decision=continuity(before,after,declarations)
%CONTINUITY Classify cross-session identity and material facts explicitly.
% Within-session intent comparison deliberately tolerates unknown readback;
% disk continuity cannot infer equality from two missing facts or requests.
if nargin<3,declarations=struct();end
identifier='Measurement:ChartContinuationContext';
assert(isstruct(declarations)&&isscalar(declarations)&&colormeasure.session.isPlainData(declarations), ...
    identifier,'Observable setup declarations must be one ordinary struct.');
observable={'serial','accessory','aperture','primaryAccessoryId','addon1Id','addon2Id','addon3Id','apertureId', ...
    'filter1','filter2','filter3','captureFilters','measurementAngleDegrees','closeupLens','externalNDFilter'};
assert(all(ismember(fieldnames(declarations),observable)),identifier, ...
    'Declarations may describe observable identity or fitted optics, not calibration, units or acquisition ownership.');
decision=struct('continueEligible',true,'differences',struct('key',{},'kind',{},'before',{},'after',{},'message',{}), ...
    'unknowns',{{}},'declarations',struct('key',{},'value',{},'certainty',{},'scope',{}), ...
    'declarableFacts',struct('key',{},'label',{},'valueType',{},'sourceValue',{},'targetValue',{}), ...
    'versionNotes',{{}},'requiredAcknowledgment',false);
assert(validContext(before)&&validContext(after), ...
    identifier,'Cross-session context must identify its required material facts.');
keys=union(before.requiredMaterial,after.requiredMaterial);
assert(all(ismember(fieldnames(declarations),keys)),identifier, ...
    'Declare only observable facts required by these two acquisition setups.');
for n=1:numel(keys)
    key=keys{n};old=getFact(before,key);current=getFact(after,key);
    if ismember(key,observable)&&(~known(old)||~known(current)|| ...
            strcmp(old.certainty,'requested')||strcmp(current.certainty,'requested'))
        valueType='text';example=current.value;if isempty(example),example=old.value;end
        if islogical(example),valueType='logical';elseif isnumeric(example)&&~isempty(example),valueType='number';end
        decision.declarableFacts(end+1)=struct('key',key,'label',colormeasure.chart.settingLabel(key),'valueType',valueType, ...
            'sourceValue',old.value,'targetValue',current.value);
    end
    if isfield(declarations,key)
        value=declarations.(key);
        assert((ischar(value)&&isrow(value)&&~isempty(strtrim(value)))|| ...
            (isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value))|| ...
            (islogical(value)&&isscalar(value)), ...
            identifier,'A declaration must supply one observable text or numeric value.');
        assert((~known(old)||isequaln(old.value,value))&&(~known(current)||isequaln(current.value,value)), ...
            identifier,'An operator declaration cannot override reported %s.',key);
        if ~known(old)||strcmp(old.certainty,'requested'),old=declared(value);end
        if ~known(current)||strcmp(current.certainty,'requested'),current=declared(value);end
        decision.declarations(end+1)=struct('key',key,'value',value, ...
            'certainty','operator-declared','scope','source and current target');
    end
    if known(old)&&known(current)&&~isequaln(old.value,current.value)
        decision.differences(end+1)=struct('key',key,'kind','changed','before',old,'after',current, ...
            'message',sprintf('%s: changed.',key));
    elseif ~known(old)||~known(current)
        % A field present only as an unknown on both sides is still required
        % when its meaning is acquisition material, not an inactive quantity.
        decision.unknowns{end+1}=[key ': not established.'];
    elseif strcmp(old.certainty,'requested')||strcmp(current.certainty,'requested')
        decision.unknowns{end+1}=[key ': requested, not observed.'];
    end
end
oldCapability=capability(before);newCapability=capability(after);
if ~isempty(oldCapability)&&~isempty(newCapability)&&~strcmp(oldCapability,newCapability)
    decision.versionNotes={'The current capability snapshot changed; readable material facts were compared separately.'};
    decision.requiredAcknowledgment=true;
end
decision.continueEligible=isempty(decision.differences)&&isempty(decision.unknowns);
end
function value=capability(context)
value='';
if isfield(context,'provenance')&&isfield(context.provenance,'capabilityId'),value=context.provenance.capabilityId;end
end
function fact=getFact(context,key)
fact=struct('value',[],'certainty','unknown','source','not reported');
if isfield(context.material,key),fact=context.material.(key);end
assert(isstruct(fact)&&isscalar(fact)&&all(isfield(fact,{'value','certainty','source'})), ...
    'Measurement:ChartContinuationContext','Material context facts require value, certainty and source.');
assert(colormeasure.session.isText(fact.source)&&colormeasure.session.isText(fact.certainty)&& ...
    any(strcmp(fact.certainty,{'unknown','requested','acknowledged','derived','readback','operator-declared'}))&& ...
    colormeasure.session.isPlainData(fact.value),'Measurement:ChartContinuationContext', ...
    'Material facts must retain ordinary values and their declared certainty.');
% A staged value alone is intent. Existing target readback can establish the
% same supported value without interpreting the source as fresh evidence.
if strcmp(fact.certainty,'requested')&&isfield(context,'accepted')&& ...
        isfield(context.accepted,key)&&isequaln(context.accepted.(key),fact.value)
    fact.certainty='readback';fact.source='current target settings readback';
end
end
function yes=known(fact)
yes=~strcmp(fact.certainty,'unknown')&&~isempty(fact.value);
if colormeasure.session.isText(fact.value)&&any(strcmpi(fact.value,{'unknown','unspecified','not reported'})),yes=false;end
end
function fact=declared(value)
fact=struct('value',value,'certainty','operator-declared','source','explicit continuation setup declaration');
end
function yes=validContext(context)
yes=isstruct(context)&&isscalar(context)&&all(isfield(context,{'material','requiredMaterial'}))&& ...
    isstruct(context.material)&&isscalar(context.material)&&iscell(context.requiredMaterial)&& ...
    isvector(context.requiredMaterial)&&all(cellfun(@(key)ischar(key)&&isrow(key)&&isvarname(key),context.requiredMaterial));
end

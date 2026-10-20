function result = context(facts, reading)
%CONTEXT Freeze readable acquisition facts for a guided-chart attempt.
%   context(facts) describes intended acquisition without instrument I/O.
%   context(facts,reading) describes the retained result and its existing
%   settings receipt/metadata. No metadata query or measurement is added.
%   Facts are supplied by Session, not by a view. Per-field certainty keeps
%   requested settings distinct from accepted requests and native readback.
assert(isstruct(facts)&&isscalar(facts),'Chart:Context','Session facts must be one struct.');
accepted = nargin > 1 && ~isempty(reading);
if ~accepted
    reading = get(facts,'latestReading',struct([]));
end
assert(isstruct(reading)&&(isempty(reading)||isscalar(reading)), ...
    'Chart:Context','Supply at most one retained reading.');
catalogue = get(facts,'catalogIdentity',struct());
configuration = get(facts,'configuration',struct());
colormeasure.chart.assertDirectSource(facts,reading);
if startsWith(get(catalogue,'model',''),'PR')
    route = 'PR';
elseif startsWith(get(catalogue,'model',''),'CR')
    route = 'CR';
elseif startsWith(get(catalogue,'model',''),'CS')
    route = 'CS2000';
else
    error('Chart:ContextCatalog','This adapter has no classified chart acquisition route.');
end
result = struct('phase','intended','route',route,'material',struct(), ...
    'counts',struct(),'provenance',struct(),'requested',struct(), ...
    'accepted',struct());
if accepted, result.phase='accepted'; end
keys={'route','provenance','model','serial','serialEncoding', ...
    'mode','workflow','opticalMode','quantity','xyzUnits','xyzScale', ...
    'observer','spectralUnits','spectralGrid'};
for key=keys, result.material.(key{1})=fact([], 'unknown','not reported'); end
result.material.route=fact(route,'derived','adapter acquisition owner');
result = direct(result,facts,configuration,catalogue,reading,accepted);
% Unsupported model controls are not required facts. Cross-session
% continuity must establish the supported material controls and quantities.
required={'route','provenance','model','serial','serialEncoding','mode','workflow','opticalMode','quantity','xyzUnits','xyzScale','observer'};
controls=get(facts,'settingsCatalog',struct('id',{}));
classification=colormeasure.chart.catalogClassification(route,controls);
supported=intersect(classification.catalogueKeys,classification.material,'stable');
required=[required reshape(supported,1,[])];
if ~strcmp(result.material.spectralUnits.certainty,'unknown')
    required{end+1}='spectralUnits';
end
extra={'captureFilters','legacyMatrixMode'};
required=[required extra(isfield(result.material,extra))];
if ~strcmp(result.material.spectralGrid.certainty,'unknown')
    required{end+1}='spectralGrid';
end
result.requiredMaterial=unique(required,'stable');
end

function result = direct(result,facts,configuration,catalogue,reading,accepted)
route=result.route;
synthetic=get(configuration,'synthetic',false) || ...
    any(strcmp(get(catalogue,'mode',''),{'interactive','batch','gallery'}));
if ~isempty(reading),synthetic=get(reading,'isSynthetic',synthetic);end
provenance='physical';if synthetic,provenance='simulated';end
result.material.provenance=fact(provenance,'derived','adapter and retained reading');
result.material.mode=fact('ordinary','derived','existing single-reading adapter');
result.material.workflow=fact('spot','derived','existing single-reading adapter');
optical=get(facts,'opticalMode',get(configuration,'opticalMode','spot'));
result.material.opticalMode=fact(optical,'derived','single-target acquisition; fitted optics unverified');
controls=get(facts,'settingsCatalog',struct('id',{}));
classification=colormeasure.chart.catalogClassification(route,controls);
report=get(facts,'settingsSnapshot',struct());
receipt=get(facts,'lastSettingsReceipt',struct());
if accepted && ~isempty(reading) && isfield(reading,'instrumentSettings') && ...
        ~isempty(reading.instrumentSettings)
    receipt=reading.instrumentSettings;
    report=get(receipt,'after',struct());
end
overrides=get(facts,'settingsOverrides',struct());
assert(isstruct(overrides)&&isscalar(overrides),'Chart:Context','Settings overrides must be one struct.');
assert(all(ismember(fieldnames(overrides),[classification.material classification.count classification.provenance])), ...
    'Chart:ContextCatalog','Settings overrides contain an unclassified acquisition key.');
requested=recipe(route,controls,report);
for key=reshape(fieldnames(overrides),1,[]),requested.(key{1})=overrides.(key{1});end
result.requested=requested;
observed=get(report,'values',struct());
if isempty(observed),observed=struct();end
if ~isempty(reading)
    meta=get(reading,'instrumentMetadata',struct());
    if accepted
        observed=captureValues(route,meta,observed,report);
        identity=get(meta,'identity',get(report,'identity',struct()));
    else
        identity=get(report,'identity',get(meta,'identity',struct()));
    end
else
    identity=get(report,'identity',struct());
end
    result=identityFacts(result,identity);
    reportedModel=get(reading,'deviceType',[]);
    if ~isempty(reportedModel) && (accepted || strcmp(result.material.model.certainty,'unknown'))
        result.material.model=fact(reportedModel,'readback','retained reading model');
    end
if ~isempty(reading)
    for pair={{'spectralQuantity','quantity'},{'xyzUnits','xyzUnits'}, ...
            {'xyzScale','xyzScale'}, ...
            {'observerId','observer'},{'spectralUnits','spectralUnits'}}
        result.material.(pair{1}{2})=quantityFact(pair{1}{2},get(reading,pair{1}{1},[]),'readback','retained reading');
    end
    result.material.spectralGrid=fact(reshape(get(reading,'lambda',[]),[],1), ...
        'readback','retained spectral wavelength grid');
    % XYZ-only colorimeters still supply a surface-color observation. Do not
    % infer a radiometric scale from a missing spectral quantity.
    if strcmp(route,'PR')
        quantities={'radiance','irradiance','radiant intensity','radiant flux'};
        code=get(reading,'unitsCode',NaN);
        if isnumeric(code)&&isscalar(code)&&ismember(code,11:14)
            result.material.quantity=fact(quantities{code-10},'readback','M5 unitsCode');
        elseif synthetic
            result.material.quantity=fact('synthetic spectrum','derived','synthetic M5 reading');
        end
        result.material.observer=fact('CIE1931_2deg','derived','existing M5 spectrum-derived XYZ');
    end
    if strcmp(result.material.quantity.certainty,'unknown') && isfield(reading,'XYZ') && ~strcmp(route,'PR')
        result.material.quantity=fact('surface color','derived','XYZ-only retained reading');
    end
elseif any(strcmp(route,{'PR','CS2000'})) && ~synthetic
    result.material.quantity=fact('radiance','derived','documented adapter acquisition');
end
if synthetic
    result.material.quantity=fact('synthetic spectrum','derived','synthetic adapter');
end
allKeys=[classification.material classification.count classification.provenance];
for index=1:numel(allKeys)
    key=allKeys{index}; value=get(observed,key,[]);
    if strcmp(key,'mode')&&~any(strcmp(classification.catalogueKeys,key))&& ...
            ~isfield(requested,key)&&~isfield(observed,key)
        continue % This model has no configurable mode; retain ordinary acquisition.
    end
    item=fact(value,'readback','existing settings report/capture metadata');
    if isfield(requested,key)
        wanted=requested.(key);
        if ~accepted || strcmp(item.certainty,'unknown')
            certainty='requested';
            if accepted && ~isempty(receipt) && ...
                    any(strcmp(get(receipt,'status',''),{'applied','unchanged'}))
                certainty='acknowledged';
            end
            item=fact(wanted,certainty,'automatic recipe and staged overrides');
        end
    end
    if any(strcmp(key,classification.count)),result.counts.(key)=item;
    elseif any(strcmp(key,classification.provenance)),result.provenance.(key)=item;
    else,result.material.(key)=item;
    end
end
result.accepted=observed;
if isfield(observed,'captureFilters')
    result.material.captureFilters=fact(observed.captureFilters,'readback','RM Filter');
end
if isfield(observed,'legacyMatrixMode')
    result.material.legacyMatrixMode=fact(observed.legacyMatrixMode,'readback','RM MatrixMode');
end
result=normalizePolicy(result,route,report);
end

function requested=recipe(route,controls,report)
requested=struct();
switch route
    case 'PR'
        requested=struct('exposureMilliseconds',0,'cycles',1,'syncMode','auto');
    case 'CS2000'
        requested=struct('speedMode',2,'integrationTimeSeconds',1,'internalNDMode',2,'syncMode',0);
    case 'CR'
        live=get(report,'controls',controls);
        requested.exposureMode=choice(live,'exposureMode','Auto');
        if ~isempty(live) && any(strcmp({live.id},'rangeMode'))
            requested.rangeMode=choice(live,'rangeMode','Auto');
            requested.mode=choice(live,'mode','Colorimeter');
        end
end
end

function values=captureValues(route,meta,values,report)
if isempty(meta),return;end
switch route
    case 'CR'
        capture=get(meta,'captureSettings',struct());
        controls=get(report,'controls',struct('id',{}));
        for key=reshape(fieldnames(capture),1,[])
            id=key{1};if strcmp(id,'instrumentMode'),id='mode';end
            if strcmp(id,'filters')
                % RM Filter is free text. Retain it independently; do not
                % manufacture three IDs from a comma-separated name.
                values.captureFilters=capture.(key{1});continue
            end
            if any(strcmp(id,{'deviceTime','warnings','cmfIndex'})),continue;end
            value=capture.(key{1});
            if ischar(value) && ~strcmp(id,'aperture')
                code=choice(controls,id,value);
                if ~isempty(code),value=code;
                elseif isfield(values,id),continue;end
            end
            values.(id)=value;
        end
    case 'CS2000'
        capture=get(meta,'conditions',struct());
        for id={'speedMode','syncMode','closeupLens','externalNDFilter', ...
                'measurementAngleDegrees','userCalibrationChannel'}
            if isfield(capture,id{1}),values.(id{1})=capture.(id{1});end
        end
        % MEDR reports effective integration/ND, whereas SPMR reports policy.
        % Keep the policy; effective automatic values belong to each attempt.
        if get(values,'speedMode',NaN)==3 && isfield(capture,'integrationTime')
            values.integrationTimeSeconds=capture.integrationTime;
        end
end
end

function result=normalizePolicy(result,route,report)
switch route
    case 'PR'
        if isequal(value(result,'exposureMilliseconds'),0)
            result.material.exposureMilliseconds=fact('adaptive','derived','PR automatic recipe');
        end
        if ~strcmp(value(result,'syncMode'),'user')
            result.material.syncFrequencyHz=fact('inactive','derived','PR synchronization policy');
        end
    case 'CR'
        controls=get(report,'controls',struct('id',{}));
        exposure=value(result,'exposureMode');range=value(result,'rangeMode');
        if isequal(exposure,choice(controls,'exposureMode','Auto')) || strcmp(exposure,'Auto')
            if ~isempty(exposure),result.material.exposureMs=fact('automatic','derived','CR automatic exposure policy');end
        end
        if isequal(range,choice(controls,'rangeMode','Auto')) || strcmp(range,'Auto')
            if ~isempty(range),result.material.range=fact('automatic','derived','CR automatic range policy');end
        end
    case 'CS2000'
        if isequal(value(result,'speedMode'),0) || isequal(value(result,'speedMode'),1)
            result.material.integrationTimeSeconds=fact('automatic','derived','Normal/Fast integration policy');
        end
        if ~isequal(value(result,'syncMode'),1)
            result.material.frequencyHz=fact('inactive','derived','CS synchronization policy');
        end
end
end

function result=identityFacts(result,identity)
for pair={{'model','model'},{'serial','serial'},{'serial_encoding','serialEncoding'}}
    result.material.(pair{1}{2})=fact(get(identity,pair{1}{1},[]),'readback','retained device identity');
end
if isfield(identity,'serialNumber')
    result.material.serial=fact(identity.serialNumber,'readback','native identity report');
    if ~strcmp(result.material.serial.certainty,'unknown')
        result.material.serialEncoding=fact('native-text','derived','native parsed serial identity');
    end
end
% Only a native parsed serialNumber establishes native-text. Other retained
% identities keep their declared encoding; missing encoding remains unknown.
end

function answer=choice(controls,id,label)
answer=[];
for index=1:numel(controls)
    if ~strcmp(controls(index).id,id),continue;end
    choices=get(controls(index),'choices',struct([]));
    match=find(strcmpi({choices.label},label));
    if isscalar(match),answer=choices(match).value;end
    return
end
end

function item=quantityFact(key,value,certainty,source)
% An explicit unknown XYZ scale establishes no scale. Retain the raw reading
% unchanged; normalize only the comparison fact.
% Identity text such as a serial named "unknown" keeps its reported meaning.
if strcmp(key,'xyzScale') && colormeasure.session.isText(value) && ...
        any(strcmpi(strtrim(value),{'unknown','unspecified','not reported'}))
    value=[];
end
item=fact(value,certainty,source);
end

function item=fact(value,certainty,source)
unknown=isempty(value) || (isnumeric(value)&&any(~isfinite(value),'all')) || ...
    (isstring(value)&&any(ismissing(value),'all'));
if unknown,certainty='unknown';value=[];end
item=struct('value',value,'certainty',certainty,'source',source);
end

function result=value(context,key)
result=[];if isfield(context.material,key),result=context.material.(key).value;end
end

function value=get(source,key,fallback)
value=fallback;
if isstruct(source)&&isscalar(source)&&isfield(source,key),value=source.(key);end
end

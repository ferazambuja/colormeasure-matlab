function data=continuationSource(source)
%CONTINUATIONSOURCE Read and validate one current, portable saved chart.
% A live Session supplies ordinary retained values only. A disk preview binds
% the exact consumed MAT bytes; neither path opens an instrument or writes.
identifier='Measurement:ChartContinuationSource';
live=isa(source,'colormeasure.session.Session');
digest='';
if live
    assert(isscalar(source)&&isvalid(source),identifier,'The source session is no longer available.');
    assert(~source.busy&&~(source.finishing&&~source.finished),identifier,'Wait for the source operation to finish before previewing continuation.');
    readings=source.measurements;info=source.info;path=source.files.mat;
    if ~isempty(path),digest=colormeasure.fileDigest(path);end
else
    assert(colormeasure.session.isText(source)&&~isempty(source)&&isfile(source), ...
        identifier,'Choose an existing saved chart MAT file.');
    path=char(java.io.File(char(source)).getCanonicalPath());
    variables=whos('-file',path);names={variables.name};
    wanted=ismember(names,{'measurements','batchInfo'});
    assert(nnz(wanted)==2&&all(strcmp({variables(wanted).class},'struct'))&& ...
        sum([variables(wanted).bytes])<=256*1024^2,identifier, ...
        'A saved chart must contain bounded ordinary measurements and batchInfo structs (maximum 256 MiB).');
    digest=colormeasure.fileDigest(path);loaded=load(path,'measurements','batchInfo');
    assert(strcmp(digest,colormeasure.fileDigest(path)),identifier,'The source MAT changed while it was read. Preview it again.');
    readings=loaded.measurements;info=loaded.batchInfo;
end
assert(isstruct(readings)&&(isempty(readings)||isvector(readings))&& ...
    isstruct(info)&&isscalar(info)&&colormeasure.session.isPlainData(readings)&& ...
    colormeasure.session.isPlainData(info),identifier,'The saved source must contain ordinary data, not runtime objects.');
[chart,definition]=colormeasure.chart.validateSnapshot(info,readings);
required={'referenceData','orientation','traversal','currentCell','paused','activePass', ...
    'pendingContext','revision','savedRevision','pendingSample','freeSample','chartSample'};
assert(all(isfield(chart,required))&&isequal(chart.traversal,'row-major-v1')&& ...
    scalarIndex(chart.activePass,numel(chart.passes))&&islogical(chart.paused)&&isscalar(chart.paused)&& ...
    isnumeric(chart.orientation)&&isscalar(chart.orientation)&&ismember(chart.orientation,[0 90 180 270])&& ...
    isnumeric(chart.currentCell)&&isreal(chart.currentCell)&&isequal(size(chart.currentCell),[1 2])&& ...
    scalarIndex(chart.currentCell(1),definition.rows)&&scalarIndex(chart.currentCell(2),definition.columns)&& ...
    scalarIndex(chart.revision,Inf)&&scalarIndex(chart.savedRevision,Inf)&&chart.savedRevision<=chart.revision, ...
    identifier,'The saved chart state is incomplete or inconsistent.');
assert(isstruct(chart.pendingContext)&&(isempty(chart.pendingContext)|| ...
    (isscalar(chart.pendingContext)&&all(isfield(chart.pendingContext,{'previous','proposed','differences','reason'})))), ...
    identifier,'A retained pending context decision must remain an ordinary context record.');
for draft={'pendingSample','freeSample','chartSample'}
    sample=chart.(draft{1});
    assert(isstruct(sample)&&isscalar(sample)&&all(isfield(sample,{'name','notes'}))&& ...
        colormeasure.session.isText(sample.name)&&colormeasure.session.isText(sample.notes),identifier, ...
        'The saved chart must retain ordinary sample drafts.');
end
% An ancestor's retained uncertainty is resolved only by a later segment's
% recorded operator declaration; a segment's own records never clear itself.
holders=[{info} arrayfun(@(item)item.batchInfo,reshape(chart.sources,1,[]),'UniformOutput',false)];
[blocked,uncertain]=guardReason(info,chart,readings);
for k=1:numel(chart.sources)
    item=chart.sources(k);
    [reason,itemUncertain]=guardReason(item.batchInfo,item.batchInfo.chart,item.measurements);
    if itemUncertain&&declared(item.segmentId,item.batchInfo.chart.runId,holders([1 k+2:end])),reason='';end
    if ~isempty(reason),blocked=reason;uncertain=false;break;end
end
% Validate the frozen scientific illustration through its existing owner.
colormeasure.chart.colors(definition,chart.passes(chart.activePass),readings,chart.referenceData,chart);
owner=struct('segmentId',{},'runId',{});
if uncertain,owner=struct('segmentId',chart.segmentId,'runId',chart.runId);end
if live&&isempty(blocked)&&(source.needsRecovery||~isempty(source.saveError)||source.savedCount~=numel(readings)||chart.revision~=chart.savedRevision)
    blocked='Recover saving the live source before continuing its chart.';
end
data=struct('measurements',readings,'batchInfo',info,'chart',chart,'definition',definition, ...
    'path',path,'sourceSha256',digest,'live',live,'blockedReason',blocked,'retainedUncertainty',owner);
end
function [reason,uncertain]=guardReason(info,chart,readings)
identifier='Measurement:ChartContinuationSource';
assert(isfield(info,'continuationGuard')&&isstruct(info.continuationGuard)&&isscalar(info.continuationGuard), ...
    identifier,'The current saved chart continuation guard is missing.');
guard=info.continuationGuard;
fields={'operationActive','cleanupPending'};
assert(all(isfield(guard,[{'version'} fields]))&&isequal(guard.version,1)&& ...
    all(cellfun(@(key)islogical(guard.(key))&&isscalar(guard.(key)),fields)), ...
    identifier,'The current saved chart continuation guard is invalid.');
reason='';
colormeasure.chart.assertDirectSource(info,readings);
% Descendant contexts may enrich material facts, but every retained pass
% must still identify a supported acquisition route.
assert(all(arrayfun(@(pass)validRoute(pass.context,{'PR','CR','CS2000'}),chart.passes)),identifier, ...
    'Chart passes must identify a classified direct route matching their derived material route.');
assert(isfield(info,'readingAnnotations')&&isstruct(info.readingAnnotations)&& ...
    (isempty(info.readingAnnotations)||isvector(info.readingAnnotations)),identifier, ...
    'The source must retain its ordinary reading-annotation history.');
indices=[];
for annotation=reshape(info.readingAnnotations,1,[])
    fields={'originalName','originalNotes','name','notes','editedAtUTC'};
    assert(all(isfield(annotation,[{'readingIndex'} fields]))&& ...
        scalarIndex(annotation.readingIndex,numel(readings))&& ...
        all(cellfun(@(key)colormeasure.session.isText(annotation.(key)),fields))&& ...
        ~ismember(annotation.readingIndex,indices),identifier,'Source annotation references must identify original retained readings.');
    reading=readings(annotation.readingIndex);
    assert(strcmp(annotation.name,colormeasure.session.textField(reading,'name'))&& ...
        strcmp(annotation.notes,colormeasure.session.textField(reading,'notes')),identifier, ...
        'Retained annotation history must agree with the indexed source reading and its current annotations.');
    indices(end+1)=annotation.readingIndex; %#ok<AGROW>
end
% Inherited attempts belong to an ancestor, whose own guard is checked above.
started=any(arrayfun(@(pass)any(strcmp({pass.attempts.status},'started')& ...
    strcmp({pass.attempts.segmentId},chart.segmentId)),chart.passes));
uncertain=guard.operationActive||guard.cleanupPending||started;
if uncertain
    reason=['The chart was saved while a measurement or its connection cleanup was unfinished. ' ...
        'Resolve connection cleanup in the batch that saved it before continuing.'];
end
end
function yes=declared(segmentId,runId,holders)
% Each holder is a later segment's batchInfo. Validate the consumed records.
yes=false;
for holder=holders
    value=holder{1};
    assert(isfield(value,'chartIoConfirmations')&&isstruct(value.chartIoConfirmations)&& ...
        all(isfield(value.chartIoConfirmations,{'segmentId','runId','confirmedAtUTC','declaration','connectionClosed','instrumentIdle'})), ...
        'Measurement:ChartContinuationSource','The saved cleanup declarations are missing or invalid.');
    for record=reshape(value.chartIoConfirmations,1,[])
        if colormeasure.session.isText(record.segmentId)&&strcmp(record.segmentId,segmentId)&& ...
                colormeasure.session.isText(record.runId)&&strcmp(record.runId,runId)&& ...
                colormeasure.session.isText(record.confirmedAtUTC)&& ...
                ~isempty(strtrim(char(record.confirmedAtUTC)))&& ...
                isequal(record.connectionClosed,true)&&isequal(record.instrumentIdle,true)
            colormeasure.chart.declarationText(record.declaration,'A retained cleanup declaration', ...
                'Measurement:ChartContinuationSource');
            yes=true;return
        end
    end
end
end

function yes=validRoute(context,routes)
% The context owner derives both route representations from one adapter.
% Inherited context enrichment cannot change that retained owner binding.
yes=isstruct(context)&&isscalar(context)&&all(isfield(context,{'route','material'}))&& ...
    colormeasure.session.isText(context.route)&&any(strcmp(context.route,routes))&& ...
    isstruct(context.material)&&isscalar(context.material)&&isfield(context.material,'route');
if ~yes,return;end
fact=context.material.route;
yes=isstruct(fact)&&isscalar(fact)&&all(isfield(fact,{'value','certainty','source'}))&& ...
    colormeasure.session.isText(fact.value)&&strcmp(context.route,fact.value)&& ...
    colormeasure.session.isText(fact.certainty)&&strcmp(fact.certainty,'derived')&& ...
    colormeasure.session.isText(fact.source);
end

function yes=scalarIndex(value,maximum)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&& ...
    value>=1&&value<=maximum&&value==fix(value);
end

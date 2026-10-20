function cells=colors(definition,pass,measurements,referenceData,chart)
%COLORS Read-only reference and selected measured illustrations per chart cell.
% Canonical row-major definition indices never depend on display rotation.
% References are frozen separately in Run.Snapshot.referenceData. Only the
% selected completed attempt reports acquired-color availability; a failed
% retry leaves that selection intact. Coverage/saving/Active remain Session's.
% Reference illustrations use relativeColor with declared white, shared Y
% scale and CIE 1931 observer, without fabricated spectra.
% Direct radiance readings remain measured but unavailable as relative chart
% colors. Historical references remain separate from acquired quantities.
% The caller supplies the exact schema-5 chart owner, including its frozen
% source registry; attempt order cannot establish ownership after continuation.
assert(nargin==5,'colormeasure:Chart:Colors', ...
    'Supply the exact retained schema-5 chart as the fifth argument.');
definition=colormeasure.chart.validateDefinition(definition);
count=numel(definition.cells);
assert(isstruct(chart)&&isscalar(chart)&& ...
    all(isfield(chart,{'format','version','runId','definition','segmentId','sources','passes'}))&& ...
    strcmp(chart.format,'guided-chart')&&isequal(chart.version,colormeasure.chart.Run.FormatVersion)&& ...
    isequaln(chart.definition,definition)&&colormeasure.session.isText(chart.runId)&&~isempty(chart.runId)&& ...
    colormeasure.session.isText(chart.segmentId)&&~isempty(chart.segmentId)&& ...
    isstruct(chart.sources)&&(isempty(chart.sources)||isvector(chart.sources))&& ...
    all(isfield(chart.sources,fieldnames(colormeasure.chart.emptySources())))&& ...
    isstruct(chart.passes)&&isvector(chart.passes)&&~isempty(chart.passes)&&all(isfield(chart.passes,'id')), ...
    'colormeasure:Chart:Colors','Supply the exact retained schema-5 chart and its original source registry.');
assert(isstruct(pass)&&isscalar(pass)&&all(isfield(pass,{'id','attempts','selectedAttempt'}))&& ...
    colormeasure.session.isText(pass.id)&&~isempty(pass.id)&& ...
    isnumeric(pass.selectedAttempt)&&isreal(pass.selectedAttempt)&& ...
    isvector(pass.selectedAttempt)&&numel(pass.selectedAttempt)==count&&all(isfinite(pass.selectedAttempt))&& ...
    all(pass.selectedAttempt>=0)&&all(fix(pass.selectedAttempt)==pass.selectedAttempt)&& ...
    isstruct(measurements), 'colormeasure:Chart:Colors','Supply a retained chart pass and measurement rows.');
owner=find(strcmp({chart.passes.id},pass.id));
assert(isscalar(owner)&&isequaln(pass,chart.passes(owner)), ...
    'colormeasure:Chart:Colors','The supplied pass must belong to the exact retained chart owner.');
colormeasure.chart.assertDirectSource(pass.context,measurements);
empty=unavailable('No accepted reading is selected for this cell.');
cells=repmat(struct('reference',empty,'measured',empty),1,count);
if ~isempty(referenceData)
    assert(isstruct(referenceData)&&isscalar(referenceData)&& ...
        all(isfield(referenceData,{'format','version','definitionId','definitionRevision','cells','context','provenance'}))&& ...
        strcmp(referenceData.format,'chart-reference-illustrations')&&isequal(referenceData.version,1)&& ...
        strcmp(referenceData.definitionId,definition.id)&&strcmp(referenceData.definitionRevision,definition.revision)&& ...
        isstruct(referenceData.cells)&&numel(referenceData.cells)==count&& ...
        all(isfield(referenceData.cells,{'sourceLocation','available','XYZ','reason','originalValues'})), ...
        'colormeasure:Chart:Colors','Frozen reference data must belong to this chart definition.');
end
for index=1:count
    if isempty(referenceData)
        cells(index).reference=unavailable('This chart has no frozen reference values and context.');
    else
        ref=referenceData.cells(index);
        assert(strcmp(ref.sourceLocation,definition.cells(index).sourceLocation)&& ...
            islogical(ref.available)&&isscalar(ref.available)&&colormeasure.session.isText(ref.reason), ...
            'colormeasure:Chart:Colors','Reference cells must preserve canonical source locations and availability.');
        if ref.available
            cells(index).reference=project(ref.XYZ,referenceData.context,referenceData.provenance);
            if cells(index).reference.available
                cells(index).reference.reason='Historical Argyll D50/1931 reference illustration; physical chart edition and specimen conditions unverified.';
            end
        else
            cells(index).reference=unavailable(ref.reason);
        end
    end
    selected=pass.selectedAttempt(index);
    if selected==0,continue;end
    assert(selected<=numel(pass.attempts),'colormeasure:Chart:Colors','Selected attempt is not retained.');
    attempt=pass.attempts(selected);
    assert(all(isfield(attempt,{'cellIndex','status','readingIndices','acceptedContext'}))&& ...
        attempt.cellIndex==index&&strcmp(attempt.status,'completed')&& ...
        isnumeric(attempt.readingIndices)&&isreal(attempt.readingIndices)&&isscalar(attempt.readingIndices)&& ...
        isfinite(attempt.readingIndices)&&fix(attempt.readingIndices)==attempt.readingIndices&& ...
        attempt.readingIndices>=1, ...
        'colormeasure:Chart:Colors','Selected completed attempt must reference exactly one retained reading in its cell.');
    reading=colormeasure.chart.resolveReading(chart,measurements,attempt);
    cells(index).measured=measured(reading,attempt);
end
end

function result=measured(reading,attempt)
values=colormeasure.chart.colorValues(reading,attempt);
result=unavailable(values.reason);
end

function result=project(XYZ,context,provenance)
result=unavailable('Reference white, observer or shared scale is unavailable.');
if ~isstruct(context)||~isscalar(context)|| ...
        ~all(isfield(context,{'observerId','xyzUnits','xyzScale','whiteXYZ'})),return;end
result.context=context;result.provenance=provenance;
if ~strcmp(context.xyzUnits,'1')||~strcmp(context.xyzScale,'relative; perfect-diffuser Y=100')
    result.reason='Reference XYZ must declare relative units and perfect-diffuser Y=100.';return
end
if ~strcmp(context.observerId,'CIE1931_2deg')
    result.reason='Reference observer is missing or incompatible with CIE 1931 sRGB.';return
end
if ~isnumeric(context.whiteXYZ)||~isreal(context.whiteXYZ)|| ...
        ~isequal(size(context.whiteXYZ),[1 3])||any(~isfinite(context.whiteXYZ))|| ...
        any(context.whiteXYZ<=0)||context.whiteXYZ(2)~=100
    result.reason='The declared perfect-diffuser Y=100 scale requires a positive white XYZ row with Y=100.';return
end
if ~isnumeric(XYZ)||~isequal(size(XYZ),[1 3])
    result.reason='One XYZ row is required for the chart color.';return
end
try
    [rgb,valid,clipped]=colormeasure.colorimetry.relativeColor(XYZ,context.whiteXYZ,context.observerId);
catch cause
    if ~startsWith(cause.identifier,'colormeasure:Colorimetry:'),rethrow(cause);end
    result.reason=['Chart color is unavailable: ' cause.message];return
end
result.available=valid;result.rgb=rgb;result.clipped=clipped;
result.reason='';
if ~valid,result.reason='XYZ must be finite and nonnegative for the relative display illustration.';end
end

function result=unavailable(reason)
result=struct('available',false,'rgb',NaN(1,3),'clipped',false, ...
    'reason',char(reason),'context',struct(),'provenance',struct());
end

function value=referenceData(definition)
%REFERENCEDATA Freeze historical expected values separately from measurements.
% Preset resources retain their original values, source context and terms.
% Custom grids have no invented references. This performs no acquisition,
% spectral derivation, display conversion or physical-reference qualification.
definition=colormeasure.chart.validateDefinition(definition);
if strcmp(definition.kind,'custom')
    reason='No reference values and context were supplied for this custom grid.';
    provenance=struct();
    cells=repmat(struct('sourceLocation','','available',false,'XYZ',[], ...
        'reason',reason, ...
        'originalValues',[]),1,numel(definition.cells));
    for index=1:numel(cells),cells(index).sourceLocation=definition.cells(index).sourceLocation;end
    value=struct('format','chart-reference-illustrations','version',1, ...
        'definitionId',definition.id,'definitionRevision',definition.revision, ...
        'cells',cells,'context',struct(),'provenance',provenance);
    return
end
manifestDigest = '1feec9496324d71039e9222bb5d83450bc00d342b1673f98a75121b1fa950f38'; % Pins the committed resource manifest.
root=colormeasure.root();
manifest=authenticatedJson(fullfile(root,'resources','provenance','chart-reference-source.json'),manifestDigest,65536);
assert(isstruct(manifest)&&isscalar(manifest)&& ...
    all(isfield(manifest,{'format','version','files'}))&& ...
    strcmp(manifest.format,'chart-reference-sources')&&isequal(manifest.version,1)&& ...
    isstruct(manifest.files)&&all(isfield(manifest.files,{'path','sha256'})), ...
    'colormeasure:Chart:Resource','Reference source manifest has an unsupported structure.');
assert(all(arrayfun(@(item)ischar(item.path)&&isrow(item.path)&& ...
    ischar(item.sha256)&&isrow(item.sha256)&& ...
    ~isempty(regexp(item.sha256,'^[0-9a-f]{64}$','once')),manifest.files)), ...
    'colormeasure:Chart:Resource','Reference source manifest has invalid file identities.');
relative=['resources/charts/' definition.kind '-reference.json'];
resourceIndex=find(strcmp({manifest.files.path},relative));
assert(isscalar(resourceIndex),'colormeasure:Chart:Resource','Reference resource must be uniquely identified.');
value=authenticatedJson(fullfile(root,relative),manifest.files(resourceIndex).sha256,262144);
value.cells=reshape(value.cells,1,[]);
% JSON vectors decode as columns in MATLAB; freeze one explicit row shape.
if isfield(value.context,'whiteXYZ'),value.context.whiteXYZ=reshape(value.context.whiteXYZ,1,3);end
for index=1:numel(value.cells)
    value.cells(index).XYZ=reshape(value.cells(index).XYZ,1,3);
    value.cells(index).originalValues=reshape(value.cells(index).originalValues,1,3);
end
value.resourceDigest=manifest.files(resourceIndex).sha256;
value.manifestDigest=manifestDigest;
end

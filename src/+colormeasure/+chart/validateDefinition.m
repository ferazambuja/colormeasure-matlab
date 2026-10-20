function value = validateDefinition(value)
%VALIDATEDEFINITION Validate the complete structural identity of a chart.
%   The canonical cell key is (row,column), in row-major-v1 traversal. Preset
%   mappings must match authenticated packaged data: a swapped but bijective
%   source map is invalid. Custom dimensions are bounded before allocation.
%   Coordinates are generated centrally; a supplied coordinate must agree.
%   Definitions remain ordinary structs without handles or color values.
%   Fernando Voltolini de Azambuja, 2026.
identifier='colormeasure:Chart:Definition';
required={'id','revision','kind','name','rows','columns','traversal','cells', ...
    'provenance','referenceConditions'};
assert(~(isstruct(value)&&isscalar(value)&&isfield(value,'kind')&& ...
    colormeasure.session.isText(value.kind)&&strcmp(value.kind,'imported')), ...
    'Measurement:DirectSource','Imported target definitions are unsupported here. Retain their original values for inspection; no data was changed.');
if ~isstruct(value)||~isscalar(value)||~all(isfield(value,required))|| ...
        ~all(ismember(fieldnames(value),[required {'digest'}]))
    error(identifier,'Chart definition has missing or unsupported fields.');
end
for field={'id','revision','kind','name','traversal'}
    if ~colormeasure.session.isText(value.(field{1}))||isempty(strtrim(char(value.(field{1}))))
        error(identifier,'Chart %s must be nonempty scalar text.',field{1});
    end
    value.(field{1})=char(value.(field{1}));
end
if numel(value.name)>128||any(double(value.name)<32)||~strcmp(value.name,strtrim(value.name))
    error(identifier,'Chart name must contain 1 to 128 printable characters without surrounding whitespace.');
end
if ~dimension(value.rows)||~dimension(value.columns)||double(value.rows)*double(value.columns)>140
    error('colormeasure:Chart:Dimensions','Use positive whole dimensions with at most 140 cells.');
end
value.rows=double(value.rows); value.columns=double(value.columns);
if ~strcmp(value.traversal,'row-major-v1')||~any(strcmp(value.kind,{'classic','sg','custom'}))
    error(identifier,'Chart kind or traversal is unsupported.');
end
cells=value.cells;
fields={'row','column','sourceLocation','sourceId','exportId','patchNumber','patchName'};
if ~isstruct(cells)||numel(cells)~=value.rows*value.columns||~all(isfield(cells,fields))|| ...
        ~all(ismember(fieldnames(cells),[fields {'coordinate'}]))
    error(identifier,'Chart cells must provide exactly one complete canonical grid.');
end
hasCoordinates=isfield(cells,'coordinate');
cells=reshape(cells,1,[]);
locations=cell(1,numel(cells)); exportIds=zeros(1,numel(cells));
for index=1:numel(cells)
    cellValue=cells(index);
    row=floor((index-1)/value.columns)+1; column=mod(index-1,value.columns)+1;
    if ~dimension(cellValue.row)||~dimension(cellValue.column)|| ...
            cellValue.row~=row||cellValue.column~=column
        error(identifier,'Chart cells must cover the grid exactly once in canonical row-major order.');
    end
    label=colormeasure.chart.coordinate(row,column);
    if hasCoordinates&& ...
            (~colormeasure.session.isText(cellValue.coordinate)||~strcmp(cellValue.coordinate,label))
        error(identifier,'Cell %s has an inconsistent application coordinate.',label);
    end
    if ~colormeasure.session.isText(cellValue.sourceLocation)||isempty(cellValue.sourceLocation)|| ...
            ~colormeasure.session.isText(cellValue.patchName)|| ...
            ~positiveOrEmpty(cellValue.sourceId)||~positiveOrEmpty(cellValue.patchNumber)|| ...
            ~dimension(cellValue.exportId)||cellValue.exportId>numel(cells)
        error(identifier,'Cell %s has invalid source or patch metadata.',label);
    end
    locations{index}=char(cellValue.sourceLocation);
    if isempty(regexp(locations{index},'^[A-Z]+[0-9]+$','once'))
        error(identifier,'Cell %s has an unsupported source location.',label);
    end
    % Source schemes may pad rows. Normalize only for collision detection;
    % never use that normalized label as the application cell association.
    locations{index}=regexprep(locations{index},'([A-Z]+)0+([1-9][0-9]*)$','$1$2');
    exportIds(index)=cellValue.exportId;
    cells(index).row=row; cells(index).column=column;
    cells(index).coordinate=label;
    cells(index).sourceLocation=char(cellValue.sourceLocation);
    cells(index).patchName=char(cellValue.patchName);
end
if numel(unique(locations))~=numel(cells)||numel(unique(exportIds))~=numel(cells)
    error(identifier,'Chart source locations and export identifiers must be unique.');
end
value.cells=cells;
textMetadata(value.provenance,{'source','sourceLocationScheme','referenceData'},identifier);
textMetadata(value.referenceConditions,{'edition','illuminant','observer','scale'},identifier);
if strcmp(value.kind,'custom')
    if isempty(regexp(value.id,'^custom-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$','once'))|| ...
            ~strcmp(value.revision,'custom-v1')
        error(identifier,'Custom chart identity or revision is unsupported.');
    end
    for index=1:numel(cells)
        cellValue=cells(index);
        if ~isempty(cellValue.sourceId)||~isempty(cellValue.patchNumber)||~isempty(cellValue.patchName)|| ...
                ~strcmp(cellValue.sourceLocation,cellValue.coordinate)||cellValue.exportId~=index
            error(identifier,'A custom grid must not invent external chart identifiers or reference patch names.');
        end
    end
    if isfield(value,'digest'), originalDigest=value.digest; value=rmfield(value,'digest'); else, originalDigest=''; end
    hash=java.security.MessageDigest.getInstance('SHA-256');
    bytes=unicode2native(jsonencode(orderfields(value)),'UTF-8');
    value.digest=lower(reshape(dec2hex(typecast(hash.digest(typecast(bytes,'int8')),'uint8'),2).',1,[]));
    if ~isempty(originalDigest)&&(~colormeasure.session.isText(originalDigest)||~strcmp(originalDigest,value.digest))
        error(identifier,'Custom chart data no longer matches its frozen digest. Create a new definition.');
    end
else
    expected=packagedDefinition(value.kind);
    % Only coordinate labels are derived; all persisted source metadata must
    % remain equal to the authenticated mapping, including the raw SG ID 26.
    expected.cells=reshape(expected.cells,1,[]);
    for index=1:numel(expected.cells)
        expected.cells(index).coordinate=colormeasure.chart.coordinate( ...
            expected.cells(index).row,expected.cells(index).column);
    end
    if ~isfield(value,'digest'), value.digest=expected.digest; end
    if ~isequaln(orderfields(value),orderfields(expected))
        error(identifier,'The %s definition does not match its verified packaged mapping and revision.',value.kind);
    end
end
end

function yes=dimension(value)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&& ...
    value>=1&&value<=140&&value==fix(value);
end

function yes=positiveOrEmpty(value)
yes=(isnumeric(value)&&isreal(value)&&isempty(value))||dimension(value);
end

function textMetadata(value,fields,identifier)
if ~isstruct(value)||~isscalar(value)||~isequal(sort(fieldnames(value)),sort(fields(:)))|| ...
        ~all(cellfun(@(field)colormeasure.session.isText(value.(field)),fields))
    error(identifier,'Chart provenance and reference conditions must contain their declared text fields only.');
end
end

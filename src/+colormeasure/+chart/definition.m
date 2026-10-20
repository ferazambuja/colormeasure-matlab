function value = definition(kind, varargin)
%DEFINITION Validated layout for a packaged chart or a custom rectangular grid.
%   definition('classic') and definition('sg') load bundled structural data.
%   definition('custom',name,rows,columns) accepts at most 140 cells. It checks
%   dimensions before allocation. Every cell has one canonical numeric key;
%   coordinate labels are generated only by colormeasure.chart.coordinate.
%   Returned data contains no measured or reference color values and needs no
%   Python installation. Preset conditions identify their historical source,
%   not the edition or measurement conditions of the user's physical chart.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(1,4);
if ~colormeasure.session.isText(kind)||~any(strcmp(kind,{'classic','sg','custom'}))
    error('colormeasure:Chart:Definition','Choose classic, sg or custom.');
end
kind=char(kind);
if ~strcmp(kind,'custom')
    if ~isempty(varargin)
        error('colormeasure:Chart:Definition','A packaged chart takes no custom dimensions.');
    end
    value=colormeasure.chart.validateDefinition(packagedDefinition(kind));
    return
end
if numel(varargin)~=3
    error('colormeasure:Chart:Definition','A custom chart needs a name, row count and column count.');
end
name=varargin{1}; rows=varargin{2}; columns=varargin{3};
if ~colormeasure.session.isText(name)||isempty(strtrim(char(name)))|| ...
        numel(char(name))>128||any(double(char(name))<32)
    error('colormeasure:Chart:Definition','Chart name must contain 1 to 128 printable characters.');
end
% Validate before allocating cells, including before multiplying large inputs.
if ~dimension(rows)||~dimension(columns)||double(rows)*double(columns)>140
    error('colormeasure:Chart:Dimensions','Use positive whole dimensions with at most 140 cells.');
end
rows=double(rows); columns=double(columns);
cellValue=struct('row',0,'column',0,'sourceLocation','','sourceId',[], ...
    'exportId',0,'patchNumber',[],'patchName','');
cells=repmat(cellValue,1,rows*columns);
for index=1:numel(cells)
    row=floor((index-1)/columns)+1; column=mod(index-1,columns)+1;
    cells(index).row=row; cells(index).column=column;
    cells(index).sourceLocation=colormeasure.chart.coordinate(row,column);
    cells(index).exportId=index;
end
value=struct('id',['custom-' char(java.util.UUID.randomUUID())], ...
    'revision','custom-v1','kind','custom','name',strtrim(char(name)), ...
    'rows',rows,'columns',columns,'traversal','row-major-v1','cells',cells, ...
    'provenance',struct('source','Operator-defined rectangular grid', ...
        'sourceLocationScheme','Application column letters and row numbers', ...
        'referenceData','Unavailable: no reference dataset was supplied'), ...
    'referenceConditions',struct('edition','Unspecified', ...
        'illuminant','Unspecified','observer','Unspecified','scale','Unspecified'));
value=colormeasure.chart.validateDefinition(value);
end

function yes=dimension(value)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&& ...
    value>=1&&value<=140&&value==fix(value);
end

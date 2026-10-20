function data=selectedTable(readings,info,adapter,options)
%SELECTEDTABLE One fixed identity/status row per canonical cell and pass.
% This summary never substitutes zero for an unmeasured quantity. The MAT
% chart and ordinary reading rows are the authority; references are portable.
% ForCsv=true encodes missing numeric values as empty numeric cells for the
% existing staged CSV writer. The default table retains numeric NaN values
% for analysis; no missing value becomes a measured zero.
% Direct chart summaries retain acquired quantities; placement is unavailable.
arguments
    readings struct
    info (1,1) struct
    adapter (1,1) struct
    options.ForCsv (1,1) logical = false
end
[chart,definition]=colormeasure.chart.validateSnapshot(info,readings);
count=numel(chart.passes)*numel(definition.cells);
text=repmat({''},count,1);numbers=NaN(count,1);
RunId=text;PassId=text;SegmentId=text;DefinitionId=text;DefinitionRevision=text;
Row=numbers;Column=numbers;Coordinate=text;SourceLocation=text;SourceId=text;ExportId=text;
SourceRow=numbers;
PatchNumber=numbers;PatchName=text;ReadingName=text;ReadingNotes=text;OriginalName=text;OriginalNotes=text;
Status=text;SelectedAttempt=numbers;ReadingIndex=numbers;
X=numbers;Y=numbers;Z=numbers;Quantities=text;Units=text;Context=text;UnavailableReason=text;
row=0;
for p=1:numel(chart.passes)
    pass=chart.passes(p);
    presentation=selectedPresentation(chart,readings,pass,adapter);
    for c=1:numel(definition.cells)
        row=row+1;cell=definition.cells(c);
        RunId{row}=chart.runId;PassId{row}=pass.id;SegmentId{row}=chart.segmentId;
        DefinitionId{row}=definition.id;DefinitionRevision{row}=char(string(definition.revision));
        Row(row)=cell.row;Column(row)=cell.column;Coordinate{row}=cell.coordinate;
        SourceLocation{row}=cell.sourceLocation;SourceId{row}=sourceIdentifier(cell.sourceId);
        if isfield(cell,'sourceRow'),SourceRow(row)=cell.sourceRow;end
        ExportId{row}=char(string(cell.exportId));if ~isempty(cell.patchNumber),PatchNumber(row)=cell.patchNumber;end;PatchName{row}=cell.patchName;
        Status{row}='unmeasured';UnavailableReason{row}='No selected successful reading.';
        selected=pass.selectedAttempt(c);
        attempts=find([pass.attempts.cellIndex]==c);
        if selected==0
            if ~isempty(attempts)
                last=pass.attempts(attempts(end));
                if ~isempty(last.reason),UnavailableReason{row}=last.reason;end
            end
            continue
        end
        attempt=pass.attempts(selected);index=attempt.readingIndices;
        Context{row}=jsonencode(attempt.acceptedContext);
        [reading,facts]=colormeasure.chart.resolveReading(chart,readings,attempt);
        SegmentId{row}=facts.segmentId;SelectedAttempt(row)=selected;ReadingIndex(row)=index;
        ReadingName{row}=colormeasure.session.textField(reading,'name');
        ReadingNotes{row}=colormeasure.session.textField(reading,'notes');
        OriginalName{row}=attempt.name;OriginalNotes{row}=attempt.notes;Status{row}='measured';
        display=presentation(strcmp({presentation.segmentId},facts.segmentId));
        if ~isempty(display.availability)
            UnavailableReason{row}=display.availability;continue
        end
        xyz=facts.XYZ;
        Quantities{row}=facts.spectralQuantity;
        Units{row}=facts.xyzUnits;
        view=display.view;
        if ~isempty(view)
            n=find(display.indices==index,1);
            if isfield(view,'XYZ')&&isequal(size(view.XYZ),[numel(display.indices) 3]),xyz=view.XYZ(n,:);end
            if isfield(view,'xyzUnitsByReading'),Units{row}=view.xyzUnitsByReading{n};end
            if isfield(view,'spectralQuantities'),Quantities{row}=view.spectralQuantities{n};end
        end
        if isnumeric(xyz)&&numel(xyz)==3&&isreal(xyz)&&all(isfinite(xyz))
            X(row)=xyz(1);Y(row)=xyz(2);Z(row)=xyz(3);UnavailableReason{row}='';
        else
            UnavailableReason{row}='Selected reading does not expose a finite XYZ triplet; use its retained quantities in MAT.';
        end
    end
end
data=table(string(RunId),string(PassId),string(SegmentId),string(DefinitionId),string(DefinitionRevision), ...
    Row,Column,string(Coordinate),string(SourceLocation),string(SourceId),SourceRow,string(ExportId),PatchNumber,string(PatchName), ...
    string(ReadingName),string(ReadingNotes),string(OriginalName),string(OriginalNotes),string(Status),SelectedAttempt, ...
    ReadingIndex,X,Y,Z,string(Quantities),string(Units),string(Context), ...
    string(UnavailableReason),'VariableNames',{'RunId','PassId','SegmentId','DefinitionId','DefinitionRevision', ...
    'Row','Column','Coordinate','SourceLocation','SourceId','SourceRow','ExportId','PatchNumber','PatchName','ReadingName','ReadingNotes', ...
    'OriginalName','OriginalNotes','Status','SelectedAttempt','ReadingIndex', ...
    'X','Y','Z','Quantities','Units','Context','UnavailableReason'}, ...
    'DimensionNames',{'Patch','Variable'});
if options.ForCsv
    % Writetable emits an empty CSV field for an empty numeric cell. Keep
    % finite numeric entries numeric so the ordinary writer handles their
    % precision, quoting and staged replacement without a second CSV stack.
    for name=data.Properties.VariableNames
        values=data.(name{1});
        if isnumeric(values)&&any(isnan(values))
            missingValues=isnan(values);encoded=num2cell(values);
            encoded(missingValues)=repmat({[]},nnz(missingValues),1);
            data.(name{1})=encoded;
        end
    end
end
end

function result=selectedPresentation(chart,readings,pass,adapter)
% Each retained segment keeps its original family/mode presentation. The
% complete chart has already passed validation before any adapter callback.
result=struct('segmentId',{},'indices',{},'availability',{},'view',{});
selected=pass.selectedAttempt(pass.selectedAttempt>0);
segments=[{chart.segmentId} {chart.sources.segmentId}];
for segmentId=segments
    owned=selected(strcmp({pass.attempts(selected).segmentId},segmentId{1}));
    if isempty(owned),continue;end
    indices=[pass.attempts(owned).readingIndices];
    sourceReadings=readings;sourceAdapter=adapter;
    if ~strcmp(segmentId{1},chart.segmentId)
        source=chart.sources(strcmp({chart.sources.segmentId},segmentId{1}));
        sourceReadings=source.measurements;
        sourceAdapter=inheritedPresentation(source.batchInfo);
    end
    availability='';view=struct([]);
    if isfield(sourceAdapter,'csvAvailability')
        reason=sourceAdapter.csvAvailability(sourceReadings(indices));
        assert(colormeasure.session.isText(reason),'Measurement:AdapterContract', ...
            'csvAvailability must return an empty value or text reason.');
        availability=char(reason);
    end
    if isempty(availability)&&isfield(sourceAdapter,'viewData')
        view=colormeasure.session.validateViewData(sourceAdapter.viewData(sourceReadings(indices)),numel(indices));
    end
    result(end+1)=struct('segmentId',segmentId{1},'indices',indices, ...
        'availability',availability,'view',view); %#ok<AGROW> One projection per original segment.
end
end

function adapter=inheritedPresentation(owner)
% Resolve only existing, I/O-free presentation owners from retained metadata.
% An unknown custom adapter keeps its original values; a receiver's adapter
% cannot establish that custom family's quantity or numerical interpretation.
adapter=struct();catalog=owner.catalogIdentity;
key=char(catalog.key);model=char(catalog.model);
colormeasure.chart.assertDirectSource(owner,struct([]));
if ~isfield(catalog,'mode')||~colormeasure.session.isText(catalog.mode),return;end
mode=char(catalog.mode);
switch mode
    case 'measure',expected=model;
    case 'interactive',expected=[model 'Demo'];
    case 'batch',expected=[model 'DemoBatch'];
    case 'gallery',expected=[model 'DemoGallery'];
    otherwise,return
end
if ~strcmp(key,expected),return;end
switch model
    case {'CR100','CR250','CR300'}
        adapter.viewData=@(values)colormeasure.drivers.cr.viewData(values,model);
    case 'PR655'
        adapter.viewData=@colormeasure.drivers.pr.viewData;
    case 'CS2000'
        adapter.viewData=@colormeasure.drivers.cs2000.viewData;
end
end

function value=sourceIdentifier(sourceId)
if isempty(sourceId),value='';else,value=char(string(sourceId));end
end

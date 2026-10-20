function tests = testChartSelectedTable
% Chart CSV summaries preserve identifiers and distinguish absent numbers.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testCustomSourceIdentifierIsScalarEmptyText(t)
[readings,info,adapter]=snapshot(false);
data=colormeasure.chart.selectedTable(readings,info,adapter);
verifyEqual(t,height(data),2);
verifyEqual(t,size(data.SourceId),[2 1]);
verifyEqual(t,data.SourceId,["";""]);
verifyEqual(t,data.Coordinate,["A1";"B1"]);
verifyEqual(t,data.ExportId,["1";"2"]);
verifyEqual(t,data.Properties.DimensionNames,{'Patch','Variable'});
verifyTrue(t,all(isnan(data.PatchNumber)));
verifyTrue(t,all(isnan(data.X)));
end

function testAvailabilityUsesSessionTextContract(t)
[readings,info,adapter]=snapshot(true);
for invalid={[],0,true,struct(),{'reason'},["a" "b"],string(missing),['a';'b']}
    adapter.csvAvailability=@(~)invalid{1};
    verifyError(t,@()colormeasure.chart.selectedTable(readings,info,adapter), ...
        'Measurement:AdapterContract');
end
for absent={'',""}
    adapter.csvAvailability=@(~)absent{1};
    data=colormeasure.chart.selectedTable(readings,info,adapter);
    verifyEqual(t,[data.X(1) data.Y(1) data.Z(1)],[0 2 3]);
    verifyEqual(t,data.UnavailableReason(1),"");
end
for reason={'Unsupported numerical view',"Unsupported numerical view"}
    adapter.csvAvailability=@(~)reason{1};
    data=colormeasure.chart.selectedTable(readings,info,adapter);
    verifyTrue(t,isnan(data.X(1)));
    verifyEqual(t,data.Status(1),"measured");
    verifyEqual(t,data.UnavailableReason(1),"Unsupported numerical view");
end
end

function testCsvBytesHaveEmptyUnknownNumbersAndKeepMeasuredZero(t)
[readings,info,adapter]=snapshot(true);
fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename=fullfile(fixture.Folder,'chart-selected.csv');
colormeasure.session.exportCsv(readings,info,filename, ...
    @(m,i)colormeasure.chart.selectedTable(m,i,adapter,ForCsv=true));
raw=fileread(filename);
verifyFalse(t,contains(raw,'NaN'));
lines=regexp(strtrim(raw),'\r?\n','split');
verifyEqual(t,numel(lines),3);
% Numeric columns precede the quoted JSON context. Check those raw fields
% independently of readtable's missing-value interpretation below.
headers=regexp(lines{1},',','split');
verifyEqual(t,sum(strcmp(headers,'Row')),1);
first=regexp(lines{2},',','split'); second=regexp(lines{3},',','split');
for name={'X','Y','Z','PatchNumber','SelectedAttempt','ReadingIndex'}
    index=find(strcmp(headers,name{1}));
    verifyEqual(t,numel(index),1);
    verifyEqual(t,second{index},'',sprintf('Unmeasured %s must be an empty field.',name{1}));
end
verifyEqual(t,first{strcmp(headers,'PatchNumber')},'');
verifyEqual(t,str2double(first{strcmp(headers,'X')}),0); % A measured zero remains zero.
verifyEqual(t,str2double(first{strcmp(headers,'Y')}),2);
verifyEqual(t,str2double(first{strcmp(headers,'Z')}),3);
verifyEqual(t,str2double(first{strcmp(headers,'SelectedAttempt')}),1);
verifyEqual(t,str2double(first{strcmp(headers,'ReadingIndex')}),1);
loaded=readtable(filename,'TextType','string');
verifyEqual(t,[loaded.X(1) loaded.Y(1) loaded.Z(1)],[0 2 3]);
verifyTrue(t,all(isnan([loaded.X(2) loaded.Y(2) loaded.Z(2)])));
end


function testEmptySelectedSnapshotWritesAllRowsWithOriginalCsvHeaders(t)
[readings,info,adapter]=snapshot(false);
fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename=fullfile(fixture.Folder,'empty-chart.csv');
colormeasure.session.exportCsv(readings,info,filename, ...
    @(m,i)colormeasure.chart.selectedTable(m,i,adapter,ForCsv=true));
raw=fileread(filename);verifyFalse(t,contains(raw,'NaN'));
lines=regexp(strtrim(raw),'\r?\n','split');verifyEqual(t,numel(lines),3);
headers=regexp(lines{1},',','split');verifyEqual(t,sum(strcmp(headers,'Row')),1);
for row=2:3
    values=regexp(lines{row},',','split');
    verifyEqual(t,numel(values),numel(headers));
    for name={'X','Y','Z','PatchNumber','SelectedAttempt','ReadingIndex'}
        verifyEqual(t,values{strcmp(headers,name{1})},'');
    end
    verifyEqual(t,str2double(values{strcmp(headers,'Row')}),1);
    verifyEqual(t,str2double(values{strcmp(headers,'Column')}),row-1);
end
end

function testDefaultAnalysisTableRemainsNumeric(t)
[readings,info,adapter]=snapshot(true);
analysis=colormeasure.chart.selectedTable(readings,info,adapter);
encoded=colormeasure.chart.selectedTable(readings,info,adapter,ForCsv=true);
verifyClass(t,analysis.X,'double'); verifyEqual(t,analysis.X(1),0); verifyTrue(t,isnan(analysis.X(2)));
verifyClass(t,encoded.X,'cell'); verifyEqual(t,encoded.X{1},0); verifyEmpty(t,encoded.X{2});
verifyEqual(t,analysis.Properties.VariableNames,encoded.Properties.VariableNames);
verifyEqual(t,analysis.Coordinate,encoded.Coordinate);
end
function testCsvPublicationEscapesFormulaTextWithoutChangingAnalysis(t)
fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename=fullfile(fixture.Folder,'literal.csv');
text=["=1+1";"+name";"-name";"@name";"  =name";"plain";"007"];
numbers=(1:numel(text)).';data=table(text,cellstr(text),numbers,'VariableNames',{'Text','Cells','Number'});
colormeasure.session.exportCsv(struct([]),struct(),filename,@(~,~)data);
loaded=readtable(filename,'TextType','string');
verifyEqual(t,loaded.Text,["'=1+1";"'+name";"'-name";"'@name";"'  =name";"plain";"007"]);
verifyEqual(t,loaded.Cells,loaded.Text);verifyEqual(t,loaded.Number,numbers);
verifyEqual(t,data.Text,text);verifyEqual(t,data.Cells,cellstr(text));
end

function testSelectedContextBelongsToItsAttemptAndMissingCellsStayBlank(t)
[readings,info,adapter]=snapshot(true);
accepted=info.chart.passes.attempts.acceptedContext;
accepted.counts=struct('cycles',1);accepted.provenance.correctionSourceDigest='first';
info.chart.passes.attempts.acceptedContext=accepted;
info.chart.passes.context.counts=struct('cycles',4);
info.chart.passes.context.provenance.correctionSourceDigest='latest';
data=colormeasure.chart.selectedTable(readings,info,adapter);
verifyEqual(t,char(data.Context(1)),jsonencode(accepted));
verifyEqual(t,data.Context(2),"");
info.chart.passes.selectedAttempt(1)=0;
info.chart.passes.attempts.status='unresolved';
data=colormeasure.chart.selectedTable(readings,info,adapter);
verifyEqual(t,data.Context,["";""]);
end

function testSelectedAcceptedContextIsValidatedBeforeHooks(t)
[readings,base]=snapshot(true);
for invalid={struct([]),struct(),[struct('x',1) struct('x',2)],[],true,'context',struct('x',@()true)}
    info=base;info.chart.passes.attempts.acceptedContext=invalid{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end
info=base;info.chart.passes.attempts=rmfield(info.chart.passes.attempts,'acceptedContext');
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end


function testUnsupportedSnapshotIsRefusedBeforeAdapterHooks(t)
[readings,base]=snapshot(true);
for version={[],[2 2],0,1,2,3,NaN,Inf,true,'2',2+1i}
    info=base;info.chart.version=version{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end
info=base;info.chart=repmat(info.chart,1,2);
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
info=base;info.chart.format='another-chart';
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
info=base;info.chart=rmfield(info.chart,'version');
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
info=base;info.chart.definition.cells(1).coordinate='B1';
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
info=base;info.chart.passes.context.runtime=@()true;
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end

function testSelectedAttemptShapeAndRangeAreRefusedBeforeHooks(t)
[readings,base]=snapshot(true);
for selected={[],1,[1 0 0],[NaN 0],[.5 0],[2 0],[-1 0],[Inf 0], ...
        [true false],'10',[1+1i 0],[1 1]}
    info=base;info.chart.passes.selectedAttempt=selected{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end
end

function testReadingLinksAreValidatedBeforeAnySubsetOrHook(t)
[readings,base]=snapshot(true);
for reference={[],[1 1],NaN,.5,0,2,Inf,true,'1',1+1i}
    info=base;info.chart.passes.attempts.readingIndices=reference{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end
for cellIndex={2,0,NaN,.5,[1 2],true,'1'}
    info=base;info.chart.passes.attempts.cellIndex=cellIndex{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end
for status={'failed','unresolved','started','cancelled'}
    info=base;info.chart.passes.attempts.status=status{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end
end

function testCorruptLaterPassRefusesBeforeEarlierPassHooks(t)
[readings,info]=snapshot(true);
info.chart.passes(2)=info.chart.passes(1);
info.chart.passes(2).id='second-pass';
info.chart.passes(2).attempts.readingIndices=NaN;
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end

function testPassIdentitiesAreNonemptyUniqueTextBeforeHooks(t)
[readings,base]=snapshot(true);
for identity={'',"",[],0,{'pass'},["first" "second"],string(missing)}
    info=base;info.chart.passes.id=identity{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end
info=base;info.chart.passes(2)=info.chart.passes(1);
info.chart.passes(2).id=string(info.chart.passes(1).id);
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end

function testForeignOperationIdentityRefusesBeforeHooks(t)
[readings,info]=snapshot(true);
for field={'operationId','operationStatus','canonicalOperationJson'}
    changed=readings;changed.(field{1})='foreign';
    assertRejectedBeforeHooks(t,changed,info,'Measurement:DirectSource');
end
end

function testDirectAppendLinksRefuseCorruptionBeforeHooks(t)
[readings,base]=snapshot(true);
for link={0,2,[1 1]}
    info=base;info.chart.passes.attempts.readingIndices=link{1};
    assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
end
info=base;info.chart.passes.attempts.segmentId='unretained-segment';
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartReference');
info=base;info.chart.passes.attempts.observationIds={''};
assertRejectedBeforeHooks(t,readings,info,'Measurement:ChartExport');
end

function testDirectAppendIndexRemainsTheRetainedIdentity(t)
[readings,info]=snapshot(true);
data=colormeasure.chart.selectedTable(readings,info,struct());
verifyEqual(t,data.SegmentId(1),string(info.segmentId));
verifyEqual(t,data.ReadingIndex(1),1);
verifyEqual(t,[data.X(1) data.Y(1) data.Z(1)],[0 2 3]);
verifyFalse(t,ismember('ObservationId',data.Properties.VariableNames));
verifyFalse(t,ismember('OperationId',data.Properties.VariableNames));
end

function testUnselectedCompletedAttemptRemainsUnmeasuredAndRetainsReason(t)
[readings,info,adapter]=snapshot(true);
info.chart.passes.selectedAttempt(1)=0;
info.chart.passes.attempts.reason='Retained reading was not selected.';
data=colormeasure.chart.selectedTable(readings,info,adapter);
verifyEqual(t,data.Status,["unmeasured";"unmeasured"]);
verifyEqual(t,data.UnavailableReason(1),"Retained reading was not selected.");
verifyTrue(t,all(isnan([data.X data.Y data.Z data.SelectedAttempt data.ReadingIndex]),'all'));
verifyFalse(t,any(startsWith(data.Properties.VariableNames,'Position')));
end

function testInheritedAndNewCrDemoReadingsUseSameQuantityPresentation(t)
[source,adapter]=chartDemo(t,'CR250');
source.startChart(colormeasure.chart.definition('custom','Inherited CSV presentation',1,2));
verifyTrue(t,source.measure());source.finish(AllowIncompleteChart=true);
preview=source.prepareChartContinuation(source.files.mat);
receiver=source.freshChartContinuationSession();t.addTeardown(@()colormeasuretest.disposeSession(receiver));
verifyTrue(t,receiver.acceptChartContinuation(preview,Action='new-pass'));
verifyTrue(t,receiver.measure());
measurements=receiver.measurements;info=receiver.info;
sourceBytes=colormeasuretest.readBytes(source.files.mat);
data=colormeasure.chart.selectedTable(measurements,info,adapter);
verifyEqual(t,data.Quantities([1 3]),["synthetic radiance";"synthetic radiance"]);
verifyEqual(t,[data.X(1) data.Y(1) data.Z(1)],source.measurements(1).XYZ);
verifyEqual(t,[data.X(3) data.Y(3) data.Z(3)],measurements(1).XYZ);
verifyEqual(t,data.SegmentId([1 3]),string({source.info.segmentId,receiver.info.segmentId}).');
verifyEqual(t,receiver.measurements,measurements);verifyEqual(t,receiver.info,info);
verifyEqual(t,colormeasuretest.readBytes(source.files.mat),sourceBytes);
end

function testInheritedCrUsesItsOwnPresentationUnderForeignReceiver(t)
[source,~]=chartDemo(t,'CR250');
source.startChart(colormeasure.chart.definition('custom','Foreign CSV presentation',1,2));
verifyTrue(t,source.measure());source.finish(AllowIncompleteChart=true);
[target,adapter]=chartDemo(t,'CS2000');
preview=target.prepareChartContinuation(source.files.mat);
receiver=target.freshChartContinuationSession();t.addTeardown(@()colormeasuretest.disposeSession(receiver));
verifyTrue(t,receiver.acceptChartContinuation(preview,Action='new-pass'));
receiver.selectChartCell(1,2);verifyTrue(t,receiver.measure());
calls=0;adapter.viewData=@receiverView;adapter.csvAvailability=@receiverAvailability;
data=colormeasure.chart.selectedTable(receiver.measurements,receiver.info,adapter);
verifyEqual(t,calls,2,'Receiver hooks must receive only receiver-owned readings.');
verifyEqual(t,data.Quantities([1 4]),["synthetic radiance";"synthetic radiance"]);
verifyEqual(t,[data.X(1) data.Y(1) data.Z(1)],source.measurements(1).XYZ);
verifyEqual(t,[data.X(4) data.Y(4) data.Z(4)],receiver.measurements(1).XYZ);
verifyEqual(t,receiver.chart.sources(1).measurements,source.measurements);
    function value=receiverAvailability(readings)
        verifyEqual(t,{readings.deviceType},{'CS-2000'});calls=calls+1;value='';
    end
    function value=receiverView(readings)
        verifyEqual(t,{readings.deviceType},{'CS-2000'});calls=calls+1;
        value=colormeasure.drivers.cs2000.viewData(readings);
    end
end

function testCorruptInheritedReadingRefusesBeforeReceiverHooks(t)
[source,~]=chartDemo(t,'CR250');
source.startChart(colormeasure.chart.definition('custom','Inherited validation control',1,2));
verifyTrue(t,source.measure());source.finish(AllowIncompleteChart=true);
preview=source.prepareChartContinuation(source.files.mat);
receiver=source.freshChartContinuationSession();t.addTeardown(@()colormeasuretest.disposeSession(receiver));
verifyTrue(t,receiver.acceptChartContinuation(preview,Action='new-pass'));
verifyTrue(t,receiver.measure());
info=receiver.info;info.chart.sources(1).measurements(1).XYZ=[1 NaN 3];
assertRejectedBeforeHooks(t,receiver.measurements,info,'Measurement:ChartReference');
end

function assertRejectedBeforeHooks(t,readings,info,identifier)
calls=0;
adapter=struct('csvAvailability',@availability,'viewData',@view);
verifyError(t,@()colormeasure.chart.selectedTable(readings,info,adapter),identifier);
verifyEqual(t,calls,0,'Invalid chart links must be refused before any adapter callback.');
    function value=availability(~)
        calls=calls+1;value='';
    end
    function value=view(~)
        calls=calls+1;value=struct();
    end
end

function [s,adapter]=chartDemo(t,model)
fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
switch model
    case 'CR250',adapter=colormeasure.drivers.cr.demoAdapter(model,'interactive');
    case 'CS2000',adapter=colormeasure.drivers.cs2000.demoAdapter('interactive');
end
s=colormeasure.session.Session(adapter,fixture.Folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));
end

function [readings,info,adapter]=snapshot(selected)
definition=colormeasure.chart.definition('custom','CSV chart',1,2);
readings=struct('XYZ',[0 2 3],'name','Reading','notes','Note', ...
    'xyzUnits','relative','spectralQuantity','radiance', ...
    'deviceType','CR-250','isSynthetic',true);
configuration=struct('synthetic',true);catalog=struct('model','CR250','key','CR250Fixture');
context=colormeasure.chart.context(struct('configuration',configuration,'catalogIdentity',catalog),readings);
chart=colormeasure.chart.Run(definition,'segment-fixture',context);
info=struct('segmentId','segment-fixture','configuration',configuration,'catalogIdentity',catalog,'chart',chart.Snapshot);delete(chart);
adapter=struct();
if selected
    info.chart.passes.attempts=struct('cellIndex',1,'row',1,'column',1,'name','A1','notes','Original note', ...
        'status','completed','reason','','readingIndices',1,'segmentId','segment-fixture', ...
        'context',context,'acceptedContext',context, ...
        'startedAtUTC','fixture start','completedAtUTC','fixture end');
    info.chart.passes.selectedAttempt(1)=1;
else
    readings=struct([]);
end
end

function tests = testChartDefinitions
% Chart identity tests distinguish canonical application and source locations.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testClassicKeepsAsymmetricSourceMapping(t)
value=colormeasure.chart.definition('classic');
verifyEqual(t,[value.rows value.columns],[4 6]);
verifyEqual(t,value.traversal,'row-major-v1');
verifyEqual(t,{value.cells.coordinate},{'A1','B1','C1','D1','E1','F1', ...
    'A2','B2','C2','D2','E2','F2','A3','B3','C3','D3','E3','F3', ...
    'A4','B4','C4','D4','E4','F4'});
verifyEqual(t,value.cells(2).sourceLocation,'A2');
verifyEqual(t,value.cells(2).patchNumber,2);
verifyEqual(t,value.cells(2).patchName,'Light skin');
verifyEqual(t,value.cells(7).sourceLocation,'B1');
verifyEqual(t,value.cells(7).patchNumber,7);
verifyEqual(t,value.cells(7).patchName,'Orange');
verifyEqual(t,[value.cells.exportId],1:24);
verifyEqual(t,value,colormeasure.chart.validateDefinition(value));
end

function testSGPreservesPaddingRawDuplicateAndCorrectedExportIdentity(t)
value=colormeasure.chart.definition('sg');
verifyEqual(t,[value.rows value.columns],[10 14]);
verifyEqual(t,value.cells(1).sourceLocation,'A01');
verifyEqual(t,value.cells(2).coordinate,'B1');
verifyEqual(t,value.cells(2).sourceLocation,'B01');
verifyEqual(t,value.cells(2).exportId,11);
verifyEqual(t,value.cells(15).coordinate,'A2');
verifyEqual(t,value.cells(15).sourceLocation,'A02');
verifyEqual(t,value.cells(15).exportId,2);
c06=value.cells((6-1)*14+3); c07=value.cells((7-1)*14+3);
verifyEqual(t,c06.sourceId,26); verifyEqual(t,c07.sourceId,26);
verifyEqual(t,c06.exportId,26); verifyEqual(t,c07.exportId,27);
verifyEqual(t,c07.sourceLocation,'C07');
verifyEqual(t,sort([value.cells.exportId]),1:140);
verifyEqual(t,numel(unique([value.cells.sourceId])),139);
verifyEmpty(t,[value.cells.patchNumber]);
verifyEqual(t,value.cells(end).coordinate,'N10');
verifyEqual(t,value,colormeasure.chart.validateDefinition(value));
end

function testStructurallyBijectiveSwappedKnownMapIsRefused(t)
for kind={'classic','sg'}
    value=colormeasure.chart.definition(kind{1});
    original=value.cells(1);
    fields={'sourceLocation','sourceId','exportId','patchNumber','patchName'};
    for index=1:numel(fields)
        field=fields{index};
        value.cells(1).(field)=value.cells(2).(field);
        value.cells(2).(field)=original.(field);
    end
    verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
end
end

function testCoordinatesHaveOneFormatterPastZAndRowNine(t)
verifyEqual(t,colormeasure.chart.coordinate(10,26),'Z10');
verifyEqual(t,colormeasure.chart.coordinate(10,27),'AA10');
verifyEqual(t,colormeasure.chart.coordinate(1,52),'AZ1');
verifyEqual(t,colormeasure.chart.coordinate(1,53),'BA1');
verifyEqual(t,colormeasure.chart.coordinate(140,1),'A140');
for invalid={0,-1,1.5,Inf,NaN,[],[1 2],true,'1',1+1i}
    verifyError(t,@()colormeasure.chart.coordinate(invalid{1},1),'colormeasure:Chart:Coordinate');
    verifyError(t,@()colormeasure.chart.coordinate(1,invalid{1}),'colormeasure:Chart:Coordinate');
end
end

function testCustomGridHasNoInventedReference(t)
value=colormeasure.chart.definition('custom','Position chart',2,3);
verifyEqual(t,{value.cells.coordinate},{'A1','B1','C1','A2','B2','C2'});
verifyEqual(t,[value.cells.row],[1 1 1 2 2 2]);
verifyEqual(t,[value.cells.column],[1 2 3 1 2 3]);
verifyEqual(t,[value.cells.exportId],1:6);
verifyEmpty(t,[value.cells.sourceId]);
verifyEmpty(t,[value.cells.patchNumber]);
verifyEqual(t,{value.cells.patchName},repmat({''},1,6));
verifyEqual(t,value.referenceConditions.illuminant,'Unspecified');
verifyEqual(t,value,colormeasure.chart.validateDefinition(value));
other=colormeasure.chart.definition('custom','Position chart',2,3);
verifyNotEqual(t,value.id,other.id);
verifyNotEqual(t,value.digest,other.digest);
end

function testCustomProductBoundIsCheckedBeforeAllocation(t)
for shape={[1 140],[140 1],[2 70],[10 14],[4 35]}
    value=colormeasure.chart.definition('custom','Boundary',shape{1}(1),shape{1}(2));
    verifyEqual(t,numel(value.cells),140);
end
for shape={[141 1],[1 141],[11 14],[realmax realmax],[Inf 1],[NaN 1], ...
        [0 1],[-1 1],[1.5 1]}
    verifyError(t,@()colormeasure.chart.definition('custom','Oversized',shape{1}(1),shape{1}(2)), ...
        'colormeasure:Chart:Dimensions');
end
for invalid={[],[1 2],true,'2',1+1i}
    verifyError(t,@()colormeasure.chart.definition('custom','Invalid',invalid{1},1), ...
        'colormeasure:Chart:Dimensions');
end
value=colormeasure.chart.definition('custom','Wide',1,140);
verifyEqual(t,value.cells(27).coordinate,'AA1');
verifyEqual(t,value.cells(140).coordinate,'EJ1');
end

function testDamagedSnapshotMetadataAndTraversalAreRefused(t)
base=colormeasure.chart.definition('classic');
value=base; value.digest=repmat('0',1,64);
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.revision='unknown';
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.cells(1).coordinate='B1';
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.cells=value.cells([2 1 3:end]);
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.cells(1).exportId=value.cells(2).exportId;
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.traversal='column-major';
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.colorValues=zeros(24,3);
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=base; value.cells=value.cells(1:end-1);
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
end

function testCustomDigestPreventsReinterpretingFrozenIdentity(t)
value=colormeasure.chart.definition('custom','Frozen',2,3);
value.name='Changed';
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
value=colormeasure.chart.definition('custom','Frozen',2,3);
value.cells(1).patchNumber=1;
verifyError(t,@()colormeasure.chart.validateDefinition(value),'colormeasure:Chart:Definition');
end

function testNamesAreUsefulScalarText(t)
for invalid={'',"",'   ',struct(),[],["a" "b"],string(missing),sprintf('line\nname'),repmat('x',1,129)}
    verifyError(t,@()colormeasure.chart.definition('custom',invalid{1},1,1), ...
        'colormeasure:Chart:Definition');
end
value=colormeasure.chart.definition('custom','  Chart  ',1,1);
verifyEqual(t,value.name,'Chart');
verifyError(t,@()colormeasure.chart.definition('unknown'),'colormeasure:Chart:Definition');
verifyError(t,@()colormeasure.chart.definition('classic','extra'),'colormeasure:Chart:Definition');
end

function testSavedDefinitionNeedsOnlyItsInstalledResources(t)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
value=colormeasure.chart.definition('sg');
save(fullfile(folder,'definition.mat'),'value');
loaded=load(fullfile(folder,'definition.mat'));
verifyEqual(t,colormeasure.chart.validateDefinition(loaded.value),value);
verifyFalse(t,any(contains(struct2cell(value.provenance),'/Users/')));
end

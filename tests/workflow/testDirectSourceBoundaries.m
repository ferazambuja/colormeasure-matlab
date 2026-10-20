function tests=testDirectSourceBoundaries
% Foreign sources must refuse before native hooks, acquisition or mutation.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testForeignSavedOwnerCannotReachNativeContinuationOrTableHooks(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
[source,~]=colormeasuretest.continuationBatch(folder);
t.addTeardown(@()colormeasuretest.disposeSession(source));
source.startChart(colormeasure.chart.definition('custom','Direct',1,2));source.measure();
original=load(source.files.mat);[target,state]=colormeasuretest.continuationBatch(folder);
t.addTeardown(@()colormeasuretest.disposeSession(target));
before=target.info;hooks=0;
adapter=struct('toTable',@forbidden,'csvAvailability',@forbidden,'viewData',@forbidden);
unsupported='This acquisition format is unsupported here.';
defects={'operationOwner','operationSetup','operations','operationCount','unacceptedOperations', ...
    'canonicalReading','operationIdentity','operationStatus','configurationOwner','route', ...
    'adapterKey','catalogKey','importedTarget'};
for defect=defects
    data=original;
    identifier='Measurement:DirectSource';message=unsupported;
    switch defect{1}
        case 'operationOwner',data.batchInfo.operationContext=struct('mode','foreign');
        case 'operationSetup',data.batchInfo.operationSetup=struct('mode','foreign');
        case 'operations',data.batchInfo.operations=struct('id','foreign');
        case 'operationCount',data.batchInfo.operationCount=1;
        case 'unacceptedOperations',data.batchInfo.unacceptedOperations=struct('id','foreign');
        case 'canonicalReading',data.measurements.canonicalOperationJson='opaque foreign payload';
        case 'operationIdentity',data.measurements.operationId='foreign-operation';
        case 'operationStatus',data.measurements.operationStatus='completed';
        case 'configurationOwner'
            data.batchInfo.configuration.operationContext=struct('mode','foreign');
            message='uses an acquisition format unavailable in this installation';
        case 'route',data.batchInfo.route='ARGYLL';message='acquisition route unavailable';
        case 'adapterKey',data.batchInfo.adapterKey='ARGYLL_SPOT';message='acquisition adapter is unavailable';
        case 'catalogKey'
            data.batchInfo.catalogIdentity.key='ARGYLL_SPOT';
            message='uses an acquisition adapter unavailable';
        case 'importedTarget'
            data.batchInfo.chart.definition.kind='imported';
            identifier='Measurement:ChartExport'; % Snapshot validation wraps definition refusals.
    end
    path=fullfile(folder,[defect{1} '.mat']);save(path,'-struct','data');
    bytes=colormeasuretest.readBytes(path);
    verifyError(t,@()target.prepareChartContinuation(path),identifier);
    if ~strcmp(defect{1},'importedTarget')
        problem=colormeasuretest.captureError(@()target.prepareChartContinuation(path));
        verifySubstring(t,problem.message,message,defect{1});
    end
    if strcmp(defect{1},'importedTarget')
        problem=colormeasuretest.captureError(@()target.prepareChartContinuation(path));
        verifyTrue(t,any(cellfun(@(cause)strcmp(cause.identifier,'Measurement:DirectSource'),problem.cause)), ...
            'The definition refusal must retain its DirectSource cause, not another generic validation error.');
    end
    verifyError(t,@()colormeasure.chart.selectedTable(data.measurements,data.batchInfo,adapter), ...
        identifier);
    verifyEqual(t,target.info,before);verifyEqual(t,state('reads'),0);
    verifyEqual(t,state('connects'),0);verifyEqual(t,state('saves'),0);
    verifyEqual(t,hooks,0);verifyEqual(t,colormeasuretest.readBytes(path),bytes);
end
    function result=forbidden(varargin) %#ok<STOUT> Always throws.
        hooks=hooks+1;error('Fixture:ForeignHook','A foreign source reached native presentation.');
    end
end
function testImportedDefinitionRefusalPreservesCurrentNativeChartAndMat(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
[s,state]=colormeasuretest.continuationBatch(folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(colormeasure.chart.definition('custom','Direct',1,2));s.measure();
before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);reads=state('reads');
definition=s.chart.definition;definition.kind='imported';
verifyError(t,@()s.startChart(definition),'Measurement:DirectSource');
verifyEqual(t,s.info,before);verifyEqual(t,state('reads'),reads);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
end

function tests=testChartRun
% Returned-context decisions cannot be dismissed by editing intended settings.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testRepeatedSelectionValidatesCoordinatesWithoutChangingSavedRevision(t)
run=colormeasure.chart.Run(colormeasure.chart.definition('custom','Small',2,3), ...
    'segment',context('intended',1));t.addTeardown(@()delete(run));run.markSaved();
before=run.Snapshot;
verifyFalse(t,run.select(uint8(1),uint8(1)));verifyEqual(t,run.Snapshot,before);
verifyError(t,@()run.select(0,1),'MATLAB:expectedPositive');verifyEqual(t,run.Snapshot,before);
verifyTrue(t,run.select(2,3));verifyEqual(t,run.Snapshot.currentCell,[2 3]);
verifyEqual(t,run.Snapshot.revision,before.revision+1);
verifyEqual(t,run.Snapshot.savedRevision,before.savedRevision);
before=run.Snapshot;verifyFalse(t,run.select(2,3));verifyEqual(t,run.Snapshot,before);
end
function testReturnedContextDecisionSurvivesIntendedChangesAndReversion(t)
base=context('intended',1);run=colormeasure.chart.Run( ...
    colormeasure.chart.definition('custom','Two patches',1,2),'segment',base);
t.addTeardown(@()delete(run));
attempt=run.begin(base,'A1','','start');
run.complete(attempt,1,'completed','',context('accepted',1),'end');
run.select(1,1);attempt=run.begin(base,'A1','','start');
run.complete(attempt,2,'completed','',context('accepted',2),'end');
verifyEqual(t,run.Snapshot.passes.selectedAttempt(1),1);
verifyEqual(t,run.Snapshot.passes.attempts(2).status,'unresolved');
cells=run.cells(1);verifyEqual(t,cells(1).status,'measured');
verifyEqual(t,cells(1).latestAttemptStatus,'unresolved');verifyEqual(t,cells(1).readingIndex,1);
verifyTrue(t,run.Snapshot.pendingContext.requiresDecision);
run.checkContext(context('intended',3));run.checkContext(base);
verifyTrue(t,run.Snapshot.pendingContext.requiresDecision);
verifyError(t,@()run.begin(base,'A1','','start'),'Measurement:ChartContext');
run.acceptContext();verifyEqual(t,run.Snapshot.activePass,2);
verifyEmpty(t,run.Snapshot.pendingContext);verifyEqual(t,run.Snapshot.passes(1).selectedAttempt(1),1);
end
function value=context(phase,speed)
value=struct('phase',phase,'route','CR','material',struct());
for pair={{'mode','ordinary'},{'workflow','spot'},{'opticalMode','spot'},{'quantity','radiance'},{'speed',speed}}
    value.material.(pair{1}{1})=struct('value',pair{1}{2},'certainty','requested','source','fixture policy');
end
end

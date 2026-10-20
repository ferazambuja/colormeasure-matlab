function tests=testChartSession
% Guided-chart acquisition/persistence with existing direct demo adapters.
% One hidden window checks read-only rendering; no physical instruments.
% Faults use the existing IO seam.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end
function testSetupAndNumericIdentityAreSavedBeforeAcquisition(t)
[s,e]=make(t);s.startChart(grid());
verifyEqual(t,s.name,'A1');verifyEqual(t,s.chart.coverage,0);verifyFalse(t,s.chart.unsaved);
verifyEqual(t,e('reads'),0);verifyEmpty(t,s.measurements);
saved=load(s.files.mat);verifyEqual(t,saved.batchInfo.segmentId,s.chart.segmentId);
verifyEqual(t,saved.batchInfo.chart.format,'guided-chart');verifyEqual(t,saved.batchInfo.chart.version,5);
verifyEqual(t,saved.batchInfo.chart.savedRevision,saved.batchInfo.chart.revision);
verifyEqual(t,saved.batchInfo.chart.definition,gridDefinition(s));
end
function testFailedConnectCanRetryWithoutAnUnconfirmedStop(t)
[s,e]=make(t);s.startChart(grid());e('failConnect')=true;
verifyFalse(t,s.measure());verifyFalse(t,s.chartIoUnconfirmed);
verifyFalse(t,s.needsRecovery);verifyEqual(t,e('reads'),0);verifyEqual(t,e('releases'),0);
verifyNumElements(t,s.chart.passes.attempts,1);
verifyEqual(t,s.chart.passes.attempts.status,'failed');
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
e('failConnect')=false;verifyTrue(t,s.measure());
verifyEqual(t,e('connects'),2);verifyEqual(t,e('reads'),1);verifyEqual(t,e('releases'),1);
verifyEqual(t,s.chart.coverage,1);verifyFalse(t,s.chartIoUnconfirmed);
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
end
function testFailedSettingsConnectCanRetryAndRefreshCompanions(t)
[s,e]=make(t);s.startChart(grid());e('failConnect')=true;
verifyFalse(t,s.refreshInstrumentSettings());verifyFalse(t,s.chartIoUnconfirmed);
verifyFalse(t,s.needsRecovery);verifyTrue(t,s.chart.csvCurrent);
verifyEmpty(t,s.chart.passes.attempts);verifyEqual(t,e('reads'),0);
e('failConnect')=false;verifyTrue(t,s.refreshInstrumentSettings());
verifyEqual(t,e('connects'),2);verifyEqual(t,e('releases'),1);
verifyEqual(t,e('reads'),0);verifyFalse(t,s.chartIoUnconfirmed);
end
function testOrdinaryConfirmedConnectRefusalKeepsRetryGuidanceAndNoGuard(t)
[s,e]=make(t);e('failConnect')=true;
verifyFalse(t,s.measure());verifyFalse(t,s.chartIoUnconfirmed);
verifySubstring(t,s.log(end).message,'retry explicitly');
verifyFalse(t,contains(s.log(end).message,'..'));
e('failConnect')=false;verifyTrue(t,s.measure());
verifyEqual(t,e('connects'),2);verifyEqual(t,e('reads'),1);
end
function testOrdinaryUnwitnessedConnectNamesCleanupBeforeRetry(t)
[s,e]=make(t);e('unconfirmedConnect')=true;
verifyFalse(t,s.measure());verifyTrue(t,s.chartIoUnconfirmed);
verifySubstring(t,s.log(end).message,'Resolve connection cleanup before retrying');
verifyFalse(t,contains(s.log(end).message,'retry explicitly'));
verifyFalse(t,contains(s.log(end).message,'..'));
verifyFalse(t,s.measure());
verifySubstring(t,s.log(end).message,'Measurement:ConnectionCleanupUnconfirmed');
verifyFalse(t,contains(s.log(end).message,'ChartContinuationBlocked'));
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),0);
end
function testUnconfirmedReleaseBlocksWithoutCreatingPhantomAttempts(t)
[s,e]=make(t);s.startChart(grid());e('failRelease')=true;
verifyTrue(t,s.measure());verifyTrue(t,s.chartIoUnconfirmed);
verifyTrue(t,s.needsRecovery);before=s.chart.passes.attempts;
verifyFalse(t,s.measure());verifyEqual(t,s.chart.passes.attempts,before);
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);verifyEqual(t,e('releases'),1);
verifyTrue(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
end
function testReachableOwnerRequiresOwnedCleanupAndRetryNeverMeasures(t)
[s,e]=make(t);s.startChart(grid());e('ownedConnection')=true;e('failRelease')=true;s.measure();
readings=s.measurements;attempts=s.chart.passes.attempts;
verifyTrue(t,s.directCleanupCanRetry);verifyTrue(t,s.chartIoUnconfirmed);
verifyError(t,@()s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='The owner is still retained.'),'Measurement:ConnectionCleanup');
verifyError(t,@()s.retryDirectCleanup(),'Fixture:Release');
verifyTrue(t,s.directCleanupCanRetry);verifyTrue(t,s.chartIoUnconfirmed);
verifyEqual(t,s.measurements,readings);verifyEqual(t,s.chart.passes.attempts,attempts);
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);verifyEqual(t,e('releases'),2);
e('failRelease')=false;verifyTrue(t,s.retryDirectCleanup());
verifyFalse(t,s.directCleanupCanRetry);verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.needsRecovery);
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);verifyEqual(t,e('releases'),3);
verifyEqual(t,s.measurements,readings);verifyEqual(t,s.chart.passes.attempts,attempts);
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
verifyError(t,@()s.retryDirectCleanup(),'Measurement:ConnectionCleanup');
verifyEqual(t,e('releases'),3);
end
function testOwnedCleanupSuccessWithSaveFailureNeedsOnlyPersistenceRetry(t)
[s,e]=make(t);s.startChart(grid());e('ownedConnection')=true;e('failRelease')=true;s.measure();
e('failRelease')=false;e('failSave')=true;
verifyFalse(t,s.retryDirectCleanup());verifyFalse(t,s.directCleanupCanRetry);
verifyFalse(t,s.chartIoUnconfirmed);verifyTrue(t,s.needsRecovery);
releases=e('releases');e('failSave')=false;s.retrySave();
verifyFalse(t,s.needsRecovery);verifyEqual(t,e('releases'),releases);
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
end
function testOrdinaryBatchRetainsOriginalOwnerAndRefusesSettingsReconnect(t)
[s,e]=make(t);e('ownedConnection')=true;e('failRelease')=true;
verifyTrue(t,s.measure());readings=s.measurements;
verifyTrue(t,s.directCleanupCanRetry);verifyTrue(t,s.chartIoUnconfirmed);
verifyFalse(t,s.refreshInstrumentSettings());verifyFalse(t,s.measure());
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);verifyEqual(t,e('releases'),1);
verifyEqual(t,s.measurements,readings);
e('failRelease')=false;verifyTrue(t,s.retryDirectCleanup());
verifyEqual(t,e('releases'),2);verifyFalse(t,s.chartIoUnconfirmed);
verifyEqual(t,s.measurements,readings);verifyTrue(t,s.refreshInstrumentSettings());
verifyEqual(t,e('connects'),2);verifyEqual(t,e('reads'),1);
end
function testOrdinaryBatchUnavailableOwnerCanRetainAnExplicitDeclaration(t)
[s,e]=make(t);e('ownedConnection')=true;e('loseOwner')=true;s.measure();
verifyTrue(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);verifyEmpty(t,s.chart);
readings=s.measurements;
verifyTrue(t,s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='The unavailable connection was closed and the instrument checked idle.'));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.needsRecovery);
verifyEqual(t,s.measurements,readings);verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),1);
record=load(s.files.mat).batchInfo.chartIoConfirmations;
verifyNumElements(t,record,1);verifyEmpty(t,record.runId);verifyEqual(t,record.segmentId,s.info.segmentId);
end
function testOrdinaryEmptyDeclarationSaveFailureCanRetryWithoutAcquisition(t)
[s,e]=make(t);e('unconfirmedConnect')=true;verifyFalse(t,s.measure());
verifyTrue(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);
e('failSave')=true;
verifyFalse(t,s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='Host connection closed; instrument idle.'));
verifyTrue(t,s.needsRecovery);verifyNumElements(t,s.info.chartIoConfirmations,1);
verifyEmpty(t,s.measurements);verifyEqual(t,e('reads'),0);
e('failSave')=false;s.retrySave();
verifyFalse(t,s.needsRecovery);verifyTrue(t,isfile(s.files.mat));
verifyNumElements(t,load(s.files.mat).batchInfo.chartIoConfirmations,1);
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),0);verifyEqual(t,e('releases'),0);
end
function testUnknownConnectRequiresExplicitCleanupAndDoesNotAcquireDuringConfirmation(t)
[s,e]=make(t);s.startChart(grid());e('unconfirmedConnect')=true;
verifyFalse(t,s.measure());verifyTrue(t,s.chartIoUnconfirmed);
attempts=s.chart.passes.attempts;before=s.info;
verifyEmpty(t,s.newBatch());
verifyError(t,@()s.freshChartContinuationSession(),'Measurement:ConnectionCleanupUnconfirmed');
verifyError(t,@()s.confirmChartIoStopped(),'Measurement:ConnectionCleanup');
verifyError(t,@()s.confirmChartIoStopped(ConfirmConnectionClosed=true, ...
    Declaration='Checked connection'),'Measurement:ConnectionCleanup');
verifyError(t,@()s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='  '),'Measurement:ConnectionCleanup');
verifyEqual(t,s.info,before);verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),0);
verifyFalse(t,s.measure());verifyEqual(t,s.chart.passes.attempts,attempts);
verifyTrue(t,s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='I closed the connection and checked the idle instrument.'));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.needsRecovery);
retained=load(s.files.mat).batchInfo;
verifyFalse(t,retained.continuationGuard.operationActive);verifyNumElements(t,retained.chartIoConfirmations,1);
verifyEqual(t,retained.chartIoConfirmations.declaration, ...
    'I closed the connection and checked the idle instrument.');
verifyEqual(t,e('connects'),1);verifyEqual(t,e('reads'),0);verifyEqual(t,e('releases'),0);
e('unconfirmedConnect')=false;verifyTrue(t,s.measure());verifyEqual(t,e('reads'),1);
end
function testCleanupDeclarationSaveFailureRetainsItAndRequiresOnlySaveRetry(t)
[s,e]=make(t);s.startChart(grid());e('unconfirmedConnect')=true;s.measure();
e('failSave')=true;
verifyFalse(t,s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='Connection closed; instrument idle.'));
verifyFalse(t,s.chartIoUnconfirmed);verifyTrue(t,s.needsRecovery);
verifyNumElements(t,s.info.chartIoConfirmations,1);verifyFalse(t,s.measure());
verifyEqual(t,e('reads'),0);verifyEqual(t,e('connects'),1);
e('failSave')=false;s.retrySave();verifyFalse(t,s.needsRecovery);
verifyNumElements(t,load(s.files.mat).batchInfo.chartIoConfirmations,1);
verifyEqual(t,e('reads'),0);verifyEqual(t,e('connects'),1);
end
function testPausedFreeReadingFailureRefreshesCurrentCompanions(t)
[s,e]=make(t);s.startChart(grid());s.pauseChart();e('failRead')=true;
verifyFalse(t,s.measure());verifyEqual(t,e('reads'),1);verifyTrue(t,s.chart.csvCurrent);
verifyEmpty(t,s.chart.passes.attempts);verifyFalse(t,s.chartIoUnconfirmed);
end
function testFailedSettingsReadRefreshesCurrentCompanions(t)
[s,e]=make(t);s.startChart(grid());e('failSettingsRead')=true;
verifyFalse(t,s.refreshInstrumentSettings());verifyTrue(t,s.chart.csvCurrent);
verifyFalse(t,s.chartIoUnconfirmed);verifyEqual(t,e('reads'),0);
end
function testFailedEmptyChartReplacementCannotCallPriorCsvCurrent(t)
[s,e]=make(t);s.startChart(grid());previous=s.files.chartCsv;bytes=colormeasuretest.readBytes(previous);
e('failSave')=true;
verifyFalse(t,s.startChart(colormeasure.chart.definition('custom','Replacement',2,2)));
verifyFalse(t,s.chart.csvCurrent);verifyEqual(t,s.files.chartCsv,previous);
verifyEqual(t,colormeasuretest.readBytes(previous),bytes);verifyTrue(t,s.chart.unsaved);
e('failSave')=false;s.retrySave();verifyTrue(t,s.chart.csvCurrent);verifyEqual(t,e('reads'),0);
end
function testChartCsvFailurePreservesLastGoodBytesAndRetriesSavedSnapshot(t)
[s,e]=make(t);s.startChart(grid());s.measure();path=s.files.chartCsv;bytes=colormeasuretest.readBytes(path);
e('failExport')=true;s.measure();verifyFalse(t,s.chart.csvCurrent);verifyTrue(t,s.chartCsvNeedsRetry);
verifyFalse(t,s.needsRecovery);verifyEqual(t,s.savedCount,2);verifyEqual(t,colormeasuretest.readBytes(path),bytes);
mat=colormeasuretest.readBytes(s.files.mat);saves=e('saves');reads=e('reads');e('failExport')=false;s.retrySave();
verifyTrue(t,s.chart.csvCurrent);verifyFalse(t,s.chartCsvNeedsRetry);verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),mat);
end
function testChartCsvRetryRefusesChangedAuthoritativeMatWithoutReplacingBytes(t)
for finished=[false true]
    [s,e]=make(t);s.startChart(grid());s.measure();path=s.files.chartCsv;
    if finished,s.finish(AllowIncompleteChart=true);end
    before=colormeasuretest.readBytes(path);e('failChartCsv')=true;
    if finished,s.editReading(1,'Edited','');else,s.measure();end
    verifyTrue(t,s.chartCsvNeedsRetry);verifyFalse(t,s.chart.csvCurrent);
    data=load(s.files.mat);data.measurements(1).XYZ=[99 99 99];save(s.files.mat,'-struct','data');
    changed=colormeasuretest.readBytes(s.files.mat);saves=e('saves');reads=e('reads');exports=e('exports');
    e('failChartCsv')=false;s.retrySave();
    verifyEqual(t,e('exports'),exports);verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
    verifyEqual(t,s.finished,finished);verifyEqual(t,s.files.chartCsv,path);
    verifyEqual(t,colormeasuretest.readBytes(path),before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),changed);
    verifyFalse(t,s.chart.csvCurrent);verifySubstring(t,s.chart.csvUnavailableReason,'MAT changed outside');
    verifySubstring(t,s.chart.csvUnavailableReason,'Another folder');
    verifyFalse(t,s.chartCsvNeedsRetry);verifyTrue(t,s.companionRecoveryAvailable);
    s.retrySave();verifyEqual(t,e('exports'),exports);verifyEqual(t,e('saves'),saves);
end
end
function testFinishKeepsCurrentChartCsvWithoutRedundantWrite(t)
[s,e]=make(t);s.startChart(grid());s.measure();path=s.files.chartCsv;
bytes=colormeasuretest.readBytes(path);reads=e('reads');exports=e('exports');e('failChartCsv')=true;
s.finish(AllowIncompleteChart=true);
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyEmpty(t,s.exportError);
verifyTrue(t,isfile(s.files.csv));verifyFalse(t,s.chartCsvNeedsRetry);
verifyEqual(t,e('exports'),exports+1);verifyEmpty(t,s.chart.csvUnavailableReason);
verifyTrue(t,s.chart.csvCurrent);verifyEqual(t,s.chart.csvRevision,s.chart.revision);
verifyEqual(t,s.files.chartCsv,path);verifyEqual(t,colormeasuretest.readBytes(path),bytes);
verifyEqual(t,e('reads'),reads);csv=readtable(s.files.csv);
verifyEqual(t,height(csv),max(1,numel(s.measurements(1).lambda)));
verifyEqual(t,unique(csv.MeasurementIndex),1);
end
function testChartProjectionRefusalOffersNeitherRetryNorRelocation(t)
[s,e]=make(t);s.startChart(grid());s.measure();path=s.files.chartCsv;
before=colormeasuretest.readBytes(path);e('failChartProjection')=true;
s.measure();verifyFalse(t,s.chart.csvCurrent);verifyFalse(t,s.chartCsvNeedsRetry);
verifyFalse(t,s.companionRecoveryAvailable);verifySubstring(t,s.chart.csvUnavailableReason,'Invalid selected projection');
verifyFalse(t,s.needsRecovery);verifyEmpty(t,s.saveError);
verifyEqual(t,colormeasuretest.readBytes(path),before);
exports=e('exports');saves=e('saves');reads=e('reads');s.retrySave();
verifyEqual(t,e('exports'),exports);verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
verifyEqual(t,s.activity,'Awaiting Measure');
end
function testFailedChartReadingKeepsFailureVisibleAfterCompanionUpdates(t)
[s,e]=make(t);s.startChart(grid());e('failRead')=true;
verifyFalse(t,s.measure());verifyEqual(t,s.activity,'Reading failed');verifyFalse(t,s.busy);
verifyEqual(t,s.chart.passes(s.chart.activePass).attempts.status,'failed');verifyTrue(t,isfile(s.files.mat));
verifyEmpty(t,s.measurements);verifyEqual(t,e('reads'),1);
end
function testOptionalChartCsvFailureKeepsFinishedEditsAndRelocationFinished(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.finish(AllowIncompleteChart=true);
path=s.files.chartCsv;bytes=colormeasuretest.readBytes(path);reads=e('reads');e('failChartCsv')=true;
verifyTrue(t,s.editReading(1,'Edited','notes'));verifyTrue(t,s.finished);
verifyFalse(t,s.needsRecovery);verifyEmpty(t,s.exportError);verifyTrue(t,s.chartCsvNeedsRetry);
verifyEqual(t,load(s.files.mat).measurements.name,'Edited');verifyTrue(t,isfile(s.files.csv));
verifyEqual(t,colormeasuretest.readBytes(path),bytes);
parent=fullfile(t.TestData.folder,'relocated');mkdir(parent);s.saveElsewhere(parent);
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyEmpty(t,s.exportError);
verifyTrue(t,s.chartCsvNeedsRetry);verifyTrue(t,isfile(s.files.mat));verifyTrue(t,isfile(s.files.csv));
verifyEqual(t,load(s.files.mat).measurements.name,'Edited');
verifyEqual(t,colormeasuretest.readBytes(path),bytes);verifyEqual(t,e('reads'),reads);
end
function testOrdinaryCsvFailureStillRequiresFinishRecovery(t)
[s,e]=make(t);s.startChart(grid());s.measure();reads=e('reads');e('failOrdinaryCsv')=true;
s.finish(AllowIncompleteChart=true);
verifyFalse(t,s.finished);verifyTrue(t,s.needsRecovery);verifyNotEmpty(t,s.exportError);
verifyTrue(t,s.chart.csvCurrent);verifyFalse(t,s.chartCsvNeedsRetry);verifyTrue(t,isfile(s.files.mat));
e('failOrdinaryCsv')=false;s.retrySave();verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);
verifyTrue(t,isfile(s.files.csv));verifyEqual(t,e('reads'),reads);
end
function testRepeatedActiveSelectionDoesNotSaveOrChangeSampleAndCsvState(t)
[s,e]=make(t);s.startChart(grid());s.setSample('A1','chart notes');
before=s.chart;files=s.files;revision=s.sampleRevision;logs=s.log;activity=s.activity;
bytes=colormeasuretest.readBytes(s.files.mat);saves=e('saves');
for attempt=1:3,verifyTrue(t,s.selectChartCell(1,1));end
verifyEqual(t,s.chart,before);verifyEqual(t,s.files,files);verifyEqual(t,s.sampleRevision,revision);
verifyEqual(t,s.name,'A1');verifyEqual(t,s.notes,'chart notes');verifyEqual(t,s.log,logs);
verifyEqual(t,s.activity,activity);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),0);
end
function testRepeatedPausedSelectionPreservesFreeDraftWithoutSaving(t)
[s,e]=make(t);s.startChart(grid());s.selectChartCell(2,2);s.pauseChart();
s.setSample('Free draft','free notes');before=s.chart;revision=s.sampleRevision;
bytes=colormeasuretest.readBytes(s.files.mat);saves=e('saves');
verifyTrue(t,s.selectChartCell(2,2));verifyEqual(t,s.chart,before);
verifyEqual(t,s.name,'Free draft');verifyEqual(t,s.notes,'free notes');verifyEqual(t,s.sampleRevision,revision);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyEqual(t,e('saves'),saves);
verifyEqual(t,e('reads'),0);
end
function testRepeatedSelectionStillRefusesBusyRecoveryAndFinishedCsv(t)
[s,e]=make(t);e('duringSave')=@()s.selectChartCell(1,1);s.startChart(grid());
verifyEqual(t,e('callbackError'),'Measurement:ChartBusy');
e('failSave')=true;s.rotateChart(90);before=s.chart;
verifyError(t,@()s.selectChartCell(1,1),'Measurement:ChartSave');verifyEqual(t,s.chart,before);
e('failSave')=false;s.retrySave();s.finish(AllowIncompleteChart=true);
before=s.chart;files=s.files;bytes=colormeasuretest.readBytes(s.files.mat);saves=e('saves');
verifyTrue(t,before.csvCurrent);
verifyError(t,@()s.selectChartCell(1,1),'Measurement:ChartBusy');
verifyEqual(t,s.chart,before);verifyEqual(t,s.files,files);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyEqual(t,e('saves'),saves);
end
function testSinglePassNativePromptsDoNotInventEarlierPasses(t)
[s,e]=make(t);s.startChart(grid());captureChartQuestion(t);
for purpose={'finish','change-context'}
    verifyFalse(t,colormeasure.ui.confirmChartFinish(s,purpose{1},struct(),'Change mode?'));
    question=getappdata(groot,'ChartFinishPromptTest');message=question{1};
    verifyFalse(t,contains(lower(message),'earlier passes'));
    verifySubstring(t,message,'Active pass 1: 0 of 6 patches measured.');
    if strcmp(purpose{1},'change-context')
        verifySubstring(t,message,'The chart setup stays saved in this batch.');
        verifySubstring(t,message,'The new batch does not inherit the chart.');
    end
end
verifyEqual(t,e('reads'),0);verifyFalse(t,s.finished);
end
function testOnePatchFinishPromptCountsOnePatch(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One patch',1,1));captureChartQuestion(t);
verifyFalse(t,colormeasure.ui.confirmChartFinish(s,'finish',struct(),'Change mode?'));
question=getappdata(groot,'ChartFinishPromptTest');
verifySubstring(t,question{1},'Active pass 1: 0 of 1 patch measured.');
verifyEqual(t,e('reads'),0);verifyFalse(t,s.finished);
end
function testMultiplePassNativePromptsDescribeRetainedEarlierPasses(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.setInstrumentSettings(struct('speed',2));
s.acceptChartContext();captureChartQuestion(t);before=s.chart;
for purpose={'finish','change-context'}
    verifyFalse(t,colormeasure.ui.confirmChartFinish(s,purpose{1},struct(),'Change mode?'));
    question=getappdata(groot,'ChartFinishPromptTest');message=question{1};
    verifySubstring(t,lower(message),'earlier passes');
    verifySubstring(t,message,'Active pass 2: 0 of 6 patches measured.');
end
verifyEqual(t,s.chart,before);verifyEqual(t,e('reads'),1);verifyFalse(t,s.finished);
end
function testPendingChartAndFreeDraftsSurviveSavingAndTaskChanges(t)
[s,e]=make(t);s.setSample('Free draft','free notes');s.startChart(grid());
s.setSample('A1','pending chart notes');
saved=load(s.files.mat);verifyEqual(t,saved.batchInfo.pendingSample,struct('name','A1','notes','pending chart notes'));
verifyEqual(t,saved.batchInfo.chart.chartSample,saved.batchInfo.pendingSample);
verifyEqual(t,saved.batchInfo.chart.freeSample,struct('name','Free draft','notes','free notes'));
s.pauseChart();s.setSample('Another free draft','changed free notes');
saved=load(s.files.mat);verifyEqual(t,saved.batchInfo.pendingSample,saved.batchInfo.chart.freeSample);
verifyEqual(t,saved.batchInfo.chart.chartSample.notes,'pending chart notes');
verifyEqual(t,saved.batchInfo.chart.savedRevision,saved.batchInfo.chart.revision);
s.resumeChart();verifyEqual(t,s.name,'A1');verifyEqual(t,s.notes,'pending chart notes');
verifyEqual(t,e('reads'),0);
end
function testUnconfirmedReleaseKeepsRetainedPassAvailableForInspectionAndFinish(t)
[s,e]=make(t);s.startChart(grid());e('failRelease')=true;s.measure();before=s.chart;
value=s.chart;verifyTrue(t,s.chartIoUnconfirmed);
verifyEqual(t,value.passes,before.passes);verifyEqual(t,value.cells,before.cells);
verifyFalse(t,s.measure());verifyEqual(t,e('reads'),1);
verifyNumElements(t,s.measurements,1);s.finish(AllowIncompleteChart=true);
verifyTrue(t,s.finished);verifyEqual(t,e('reads'),1);
verifyEqual(t,s.status,'Cleanup unconfirmed | Finished | 1 reading saved');
end
function testOutOfOrderAndRetryChooseSuccessfulReadingWithoutDroppingHistory(t)
[s,e]=make(t);s.startChart(grid());s.selectChartCell(2,2);
verifyTrue(t,s.measure());verifyEqual(t,s.chart.currentCell,[2 3]);
verifyEqual(t,s.chart.cells(5).readingIndex,1);verifyEqual(t,s.measurements.name,'B2');
s.selectChartCell(2,2);verifyTrue(t,s.measure());
verifyEqual(t,s.chart.coverage,1);verifyEqual(t,s.chart.cells(5).attemptCount,2);
verifyEqual(t,s.chart.cells(5).readingIndex,2);verifyNumElements(t,s.measurements,2);
s.selectChartCell(2,2);e('failRead')=true;verifyFalse(t,s.measure());
verifyEqual(t,s.chart.currentCell,[2 2]);verifyEqual(t,s.chart.cells(5).attemptCount,3);
verifyEqual(t,s.chart.cells(5).readingIndex,2);verifyEqual(t,s.chart.coverage,1);
verifyEqual(t,s.chart.passes.attempts(3).status,'failed');
verifyEqual(t,e('reads'),3);
end
function testSuccessfulChartReadingConsumesOnlyItsPendingNotes(t)
[s,e]=make(t);s.startChart(grid());s.setSample('A1','Patch-specific note');s.measure();
verifyEqual(t,s.measurements.notes,'Patch-specific note');
verifyEqual(t,s.chart.passes.attempts.notes,'Patch-specific note');
verifyEqual(t,s.notes,'');verifyEqual(t,load(s.files.mat).batchInfo.chart.chartSample.notes,'');
s.setSample('B1','Retry note');e('failRead')=true;s.measure();verifyEqual(t,s.notes,'Retry note');
e('failRead')=false;s.measure();verifyEqual(t,s.measurements(2).notes,'Retry note');
verifyEqual(t,s.notes,'');verifyFalse(t,e('failRead'));
end
function testSaveFailureKeepsSelectedReadingAndBlocksAcquisitionAndNavigation(t)
[s,e]=make(t);s.startChart(grid());e('duringRead')=@failReadingSave;
% The intent save must succeed; this fault belongs to retention after reading.
verifyTrue(t,s.measure());verifyTrue(t,s.chart.unsaved);verifyEqual(t,s.chart.coverage,1);
e('duringRead')=[];
verifyFalse(t,s.measure());verifyEqual(t,e('reads'),1);
verifyError(t,@()s.selectChartCell(2,2),'Measurement:ChartSave');
verifyError(t,@()s.rotateChart(90),'Measurement:ChartSave');
verifyError(t,@()s.pauseChart(),'Measurement:ChartSave');
verifyError(t,@()s.setSample(s.name,'changed'),'Measurement:ChartSave');
verifyError(t,@()s.setInstrumentSettings(struct('speed',1)),'Measurement:ChartSave');
e('failSave')=false;s.retrySave();verifyFalse(t,s.chart.unsaved);
verifyEqual(t,e('reads'),1);s.selectChartCell(2,2);verifyTrue(t,s.measure());
    function failReadingSave()
        e('failSave')=true;
    end
end
function testFailedPauseSaveBlocksFreeAcquisitionUntilRecovery(t)
[s,e]=make(t);s.startChart(grid());s.measure();e('failSave')=true;verifyFalse(t,s.pauseChart());
verifyTrue(t,s.chart.paused);reads=e('reads');verifyFalse(t,s.measure());verifyEqual(t,e('reads'),reads);
e('failSave')=false;s.retrySave();verifyTrue(t,s.measure());verifyEqual(t,s.chart.coverage,1);
verifyFalse(t,e('failSave'));
end
function testChartSaveRefusesReentrantMutationWithoutLosingItsRevision(t)
[s,e]=make(t);e('duringSave')=@()s.rotateChart(90);
verifyTrue(t,s.startChart(grid()));
verifyEqual(t,e('callbackError'),'Measurement:ChartBusy');
verifyEqual(t,s.chart.orientation,0);saved=load(s.files.mat);
verifyEqual(t,saved.batchInfo.chart.revision,s.chart.revision);
verifyEqual(t,saved.batchInfo.chart.savedRevision,s.chart.savedRevision);
verifyEqual(t,e('reads'),0);
end
function testPersistenceStateSeparatesAcquisitionFromSavingAndClearsAfterFailure(t)
[s,e]=make(t);verifyFalse(t,s.saving);s.startChart(grid());
verifyFalse(t,s.saving);readChecks=0;saveChecks=0;
e('duringRead')=@whileReading;e('duringSave')=@whileSaving;
verifyTrue(t,s.measure());verifyEqual(t,readChecks,1);verifyEqual(t,saveChecks,2);
verifyFalse(t,s.saving);verifyFalse(t,s.chart.unsaved);verifyFalse(t,s.busy);
e('duringSave')=@whileSaving;
verifyTrue(t,s.measure());verifyEqual(t,readChecks,2);verifyEqual(t,saveChecks,3);
verifyFalse(t,s.saving);verifyTrue(t,s.chart.unsaved);verifyTrue(t,s.needsRecovery);
verifyFalse(t,s.busy);e('failSave')=false;s.retrySave();
verifyEqual(t,saveChecks,4);verifyEqual(t,e('reads'),2);verifyEmpty(t,e('callbackError'));
verifyFalse(t,s.saving);verifyFalse(t,s.chart.unsaved);verifyFalse(t,s.needsRecovery);
    function whileReading()
        readChecks=readChecks+1;
        verifyFalse(t,s.saving);verifyFalse(t,s.chart.unsaved);verifyTrue(t,s.busy);
        verifyTrue(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
        e('duringSave')=@whileSaving;
        if readChecks==2,e('failSave')=true;end
    end
    function whileSaving()
        saveChecks=saveChecks+1;
        verifyTrue(t,s.saving);verifyTrue(t,s.chart.unsaved);verifyTrue(t,s.busy);
    end
end
function testInvalidAcceptedMetadataStillSavesReadingAndPreservesSelection(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.selectChartCell(1,1);
e('badMetadata')=true;verifyTrue(t,s.measure());
verifyNumElements(t,s.measurements,2);verifyEqual(t,s.chart.coverage,1);
verifyEqual(t,s.chart.cells(1).readingIndex,1);verifyEqual(t,s.chart.currentCell,[1 1]);
verifyEqual(t,s.chart.passes.attempts(2).status,'unresolved');
verifyEmpty(t,s.chart.passes.attempts(2).acceptedContext);
verifyTrue(t,s.chart.pendingContext.interpretationError);
saved=load(s.files.mat);verifyNumElements(t,saved.measurements,2);
verifyEqual(t,saved.batchInfo.chart.passes.attempts(2).readingIndices,2);
s.setInstrumentSettings(struct('speed',2));s.setInstrumentSettings(struct());
verifyTrue(t,s.chart.pendingContext.interpretationError);
verifyFalse(t,s.measure());verifyEqual(t,e('reads'),2);
end
function testPauseFreeReadingsAndResumeDoNotAssignOrDiscardChartCells(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.pauseChart();
verifyTrue(t,s.chart.paused);s.measure('Free sample','');verifyEqual(t,s.chart.coverage,1);
s.resumeChart();verifyFalse(t,s.chart.paused);verifyEqual(t,s.name,'B1');
s.measure();verifyEqual(t,s.chart.coverage,2);verifyEqual(t,e('reads'),3);
verifyEqual(t,s.chart.passes.attempts(2).readingIndices,3);
end

function testRepeatedRefusedResumeKeepsSavedDecisionAndFreeAcquisitionAvailable(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.pauseChart();
s.setInstrumentSettings(struct('speed',2));before=s.chart;bytes=colormeasuretest.readBytes(s.files.mat);
verifyNotEmpty(t,before.pendingContext);verifyFalse(t,before.unsaved);
for attempt=1:3
    verifyError(t,@()s.resumeChart(),'Measurement:ChartContext');
    verifyEqual(t,s.chart,before);verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);
end
verifyTrue(t,s.measure('Free sample',''));verifyEqual(t,e('reads'),2);
verifyEqual(t,s.chart.coverage,1);verifyTrue(t,s.chart.paused);verifyFalse(t,s.chart.unsaved);
end

function testCompleteActivePassFinishesWithEarlierIncompletePassRetained(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','Small',1,2));s.measure();
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();s.measure();
verifyEqual(t,s.chart.passes(1).coverage,1);verifyEqual(t,s.chart.coverage,2);
s.finish();verifyTrue(t,s.finished);verifyEqual(t,e('reads'),3);
saved=load(s.files.mat);verifyEqual(t,numel(saved.batchInfo.chart.passes),2);
data=colormeasure.chart.selectedTable(saved.measurements,saved.batchInfo,struct());
verifyEqual(t,data.Status,["measured";"unmeasured";"measured";"measured"]);
verifyNotEmpty(t,s.files.chartCsv);
end

function testChartCsvKeepsEachReadingsAveragingCount(t)
a=colormeasure.drivers.pr.uiAdapter();a.key='PR655Demo';
a.catalog=struct('model','PR655','mode','interactive');
meter=colormeasure.drivers.pr.DemoInstrument(1,0);
a.connect=@(~)meter;a.release=@(~)[];a.listPorts=@(~)"DEMO";
a.prepareSample=@(intent)meter.prepareSample(intent);
s=colormeasure.session.Session(a,t.TestData.folder);
t.addTeardown(@()delete(meter));t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(colormeasure.chart.definition('custom','Small',1,3));verifyTrue(t,s.measure());
s.setInstrumentSettings(struct('cycles',4));verifyTrue(t,s.measure());
verifyEqual(t,s.chart.activePass,1);s.finish(AllowIncompleteChart=true);
data=readtable(s.files.chartCsv,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);
first=jsondecode(char(data.Context(1)));second=jsondecode(char(data.Context(2)));
verifyEqual(t,first.counts.cycles.value,1);verifyEqual(t,second.counts.cycles.value,4);
verifyEqual(t,data.Context(1),string(jsonencode(s.chart.passes.attempts(1).acceptedContext)));
verifyEqual(t,data.Context(2),string(jsonencode(s.chart.passes.attempts(2).acceptedContext)));
verifyTrue(t,ismissing(data.Context(3))||strlength(data.Context(3))==0);
end
function testFinishIncompleteAndRenameKeepFixedCellReferencesAndRegenerateCsv(t)
[s,e]=make(t);s.startChart(grid());s.selectChartCell(2,2);s.measure();
verifyError(t,@()s.finish(),'Measurement:ChartIncomplete');
s.finish(AllowIncompleteChart=true);verifyTrue(t,s.finished);
data=readtable(s.files.chartCsv,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);verifyEqual(t,height(data),6);
verifyEqual(t,data.Coordinate(5),"B2");verifyEqual(t,data.ReadingName(5),"B2");
verifyTrue(t,all(isnan(data.X([1:4 6]))));verifyEqual(t,data.ReadingIndex(5),1);
verifyTrue(t,s.editReading(1,'Foo','retained annotation'));verifyTrue(t,s.finished);
data=readtable(s.files.chartCsv,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);verifyEqual(t,data.Coordinate(5),"B2");
verifyEqual(t,data.ReadingName(5),"Foo");verifyEqual(t,data.OriginalName(5),"B2");
verifyEqual(t,s.chart.passes.attempts.name,'B2');verifyEqual(t,e('reads'),1);
verifyFalse(t,s.measure());
end
function testRelocatedMatResolvesEverySelectedReferenceWithoutOldFolder(t)
[s,e]=make(t);s.startChart(grid());s.measure();old=s.files.mat;
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;s.saveElsewhere(folder);
saved=load(s.files.mat);verifyEqual(t,saved.batchInfo.chart.segmentId,saved.batchInfo.segmentId);
pass=saved.batchInfo.chart.passes;
for selected=pass.selectedAttempt(pass.selectedAttempt>0)
    attempt=pass.attempts(selected);verifyEqual(t,saved.measurements(attempt.readingIndices).name,attempt.name);
end
verifyEqual(t,load(old).batchInfo.chart.runId,s.chart.runId);verifyEqual(t,e('reads'),1);
end
function testMaterialSettingsStartEmptyPassAndCountsDoNot(t)
[s,~]=make(t);s.startChart(grid());s.measure();
s.setInstrumentSettings(struct('speed',2));verifyNotEmpty(t,s.chart.pendingContext);
verifyFalse(t,s.measure());verifyEqual(t,s.chart.coverage,1);
s.acceptChartContext();verifyEqual(t,s.chart.activePass,2);verifyEqual(t,s.chart.coverage,0);
verifyEqual(t,nnz(s.chart.passes(1).selectedAttempt),1);
verifyTrue(t,s.measure());verifyEqual(t,s.chart.coverage,1);
before=s.chart;
verifyEqual(t,before.passes(1).coverage,1);verifyEqual(t,before.passes(1).cells(1).readingIndex,1);
verifyEqual(t,before.passes(2).coverage,1);verifyEqual(t,before.passes(2).cells(1).readingIndex,2);
verifyEqual(t,s.chart.activePass,2);verifyEqual(t,s.chart.currentCell,before.currentCell);
end
function testReplacementAfterAnyAttemptRefusesWithoutChangingDefinition(t)
[s,e]=make(t);s.startChart(grid());e('failRead')=true;s.measure();before=s.chart;
verifyError(t,@()s.startChart(colormeasure.chart.definition('classic')),'Measurement:ChartDefinition');
verifyEqual(t,s.chart.definition,before.definition);verifyEqual(t,e('reads'),1);
end
function testChartCsvAvailabilityUsesSelectedRowsAndStillExportsSummary(t)
[s,~]=make(t,true);s.measure('Free only','');s.startChart(grid());s.measure();
s.finish(AllowIncompleteChart=true);verifyTrue(t,s.finished);verifyEmpty(t,s.files.csv);
verifyNotEmpty(t,s.files.chartCsv);data=readtable(s.files.chartCsv,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true);
verifyEqual(t,data.ReadingIndex(1),2);verifyTrue(t,isfinite(data.X(1)));
end
function testExportFailureAndFinishedRenameUseMatFirstAndNoAcquisition(t)
[s,e]=make(t);s.startChart(grid());s.measure();s.finish(AllowIncompleteChart=true);old=s.files.chartCsv;
e('failExport')=true;verifyFalse(t,s.editReading(1,'Foo','changed'));
verifyEqual(t,load(s.files.mat).measurements.name,'Foo');verifyEqual(t,s.files.chartCsv,old);
verifyFalse(t,s.chart.csvCurrent);verifyTrue(t,s.chartCsvNeedsRetry);
verifyTrue(t,isfile(old));verifyTrue(t,s.finishing);verifyFalse(t,s.finished);
reads=e('reads');e('failExport')=false;s.retrySave();verifyTrue(t,s.finished);
verifyEqual(t,e('reads'),reads);verifyEqual(t,readtable(s.files.chartCsv,'TextType','string','Delimiter',',','NumHeaderLines',0,'ReadVariableNames',true).ReadingName(1),"Foo");
end
function testRepeatedTaskTransitionsAndEmptyReplacementPreserveFreeDraft(t)
[s,~]=make(t);s.setSample('Operator draft','free note');s.startChart(grid());
s.startChart(colormeasure.chart.definition('sg'));s.resumeChart();s.pauseChart();s.pauseChart();
verifyEqual(t,s.name,'Operator draft');verifyEqual(t,s.notes,'free note');
s.resumeChart();verifyEqual(t,s.name,'A1');s.pauseChart();verifyEqual(t,s.name,'Operator draft');
end
function testRevertingStagedContextClearsOnlyIntentDecision(t)
[s,~]=make(t);s.startChart(grid());s.measure();
s.setInstrumentSettings(struct('speed',2));verifyNotEmpty(t,s.chart.pendingContext);
s.setInstrumentSettings(struct());verifyEmpty(t,s.chart.pendingContext);verifyEqual(t,s.chart.activePass,1);
end
function testEmptyChartSelectedTableHasOneExplicitUnavailableRowPerCell(t)
[s,~]=make(t);s.startChart(grid());
a=colormeasure.drivers.cr.demoAdapter('CR250','interactive');
data=colormeasure.chart.selectedTable(s.measurements,s.info,a);
verifyEqual(t,height(data),6);verifyTrue(t,all(isnan(data.X)));
verifyTrue(t,all(strlength(data.UnavailableReason)>0));
end
function definition=grid()
definition=colormeasure.chart.definition('custom','Asymmetric grid',2,3);
end
function value=gridDefinition(s)
value=s.chart.definition;
end
function [s,e]=make(t,mixed)
if nargin<2,mixed=false;end
e=containers.Map('KeyType','char','ValueType','any');
e('reads')=0;e('failRead')=false;e('failSave')=false;e('failExport')=false;
e('connects')=0;e('releases')=0;e('failConnect')=false;e('unconfirmedConnect')=false;
e('failRelease')=false;e('failSettingsRead')=false;e('ownedConnection')=false;e('loseOwner')=false;
e('failChartCsv')=false;e('failOrdinaryCsv')=false;e('failChartProjection')=false;
e('saves')=0;e('exports')=0;
e('duringSave')=[];e('duringRead')=[];e('callbackError')='';e('badMetadata')=false;
a=colormeasure.drivers.cr.demoAdapter('CR250','interactive');read=a.read;a.read=@acquire;
connect=a.connect;release=a.release;readSettings=a.settings.read;
a.connect=@connectOnce;a.release=@releaseOnce;a.settings.read=@settingsOnce;
a.csvAvailability=@availability;
io=colormeasure.session.services();io.saveMat=@save;io.exportCsv=@export;
s=colormeasure.session.Session(a,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
    function value=connectOnce(port)
        e('connects')=e('connects')+1;
        if e('unconfirmedConnect'),error('Fixture:Connect','Connection cleanup is unknown.');end
        if e('failConnect')
            problem=MException('Fixture:Connect','Instrument connection unavailable.');
            % This injection refuses before calling the connection owner.
            throw(colormeasure.drivers.confirmedConnectionFailure(problem));
        end
        value=connect(port);
        if e('ownedConnection'),value=colormeasuretest.session.Instrument(@()[],@()[]);end
    end
    function releaseOnce(instrument)
        e('releases')=e('releases')+1;
        if e('loseOwner')
            delete(instrument);error('Fixture:Release','The returned owner became unavailable during cleanup.');
        end
        if e('failRelease'),error('Fixture:Release','Release could not be confirmed.');end
        release(instrument);
        if e('ownedConnection'),delete(instrument);end
    end
    function value=settingsOnce(instrument)
        if e('failSettingsRead'),error('Fixture:Settings','Settings read unavailable.');end
        value=readSettings(instrument);
    end
    function value=acquire(instrument)
        e('reads')=e('reads')+1;
        callback=e('duringRead');if ~isempty(callback),callback();end
        if e('failRead'),error('Fixture:Read','Reading unavailable.');end
        value=read(instrument);
        if e('badMetadata'),value.instrumentMetadata.captureSettings=42;end
    end
    function save(m,f,i)
        e('saves')=e('saves')+1;
        if e('failSave'),error('Fixture:Save','Disk unavailable.');end
        callback=e('duringSave');
        if ~isempty(callback)
            e('duringSave')=[];
            try
                callback();
            catch problem
                e('callbackError')=problem.identifier;
            end
        end
        colormeasure.session.saveMat(m,f,i);
    end
    function digest=export(m,i,f,toTable)
        e('exports')=e('exports')+1;
        [~,stem]=fileparts(f);
        if e('failExport')||(e('failChartCsv')&&strcmp(stem,'chart-selected'))|| ...
                (e('failOrdinaryCsv')&&strcmp(stem,'measurements'))
            error('Fixture:Export','CSV unavailable.');
        end
        digest=colormeasure.session.exportCsv(m,i,f,toTable);
    end
    function reason=availability(m)
        if e('failChartProjection'),error('Fixture:Projection','Invalid selected projection.');end
        reason='';if mixed&&any(strcmp({m.name},'Free only')),reason='Mixed free readings are unavailable in this CSV.';end
    end
end
function captureChartQuestion(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
colormeasuretest.preserveAppdata(t,'ChartFinishPromptTest');
colormeasuretest.writeText(fullfile(folder,'questdlg.m'),sprintf([ ...
    'function answer=questdlg(varargin)\n' ...
    'setappdata(groot,''ChartFinishPromptTest'',varargin);answer='''';\nend\n']));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
end

function tests=testSavedMatWitness
% Native saved-source/CSV invariants retained from the former companion suite.
% Transports are substituted; no Python or physical instrument is used.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end

function testQueuedChartFinishWritesSummaryOnceBeforeRequiredCsv(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));
e('events')={};e('readHook')=@()s.finish(AllowIncompleteChart=true);s.measure();
% Acquisition intent, retained reading, then explicit Finish each save MAT.
verifyEqual(t,e('events'),{'mat','mat','mat','chart-selected','measurements'});
verifyEqual(t,e('reads'),1);verifyTrue(t,s.finished);verifyTrue(t,s.chart.csvCurrent);
end
function testRequiredCsvFailureRetainsMatAndRetriesWithoutAcquisition(t)
[s,e]=make(t);s.measure();e('events')={};e('failCsv')=true;s.finish();
verifyEqual(t,e('events'),{'mat','measurements'});
verifyFalse(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyTrue(t,isfile(s.files.mat));verifyEmpty(t,s.files.csv);verifyNotEmpty(t,s.exportError);
e('events')={};e('failCsv')=false;s.retrySave();
verifyEqual(t,e('events'),{'measurements'});
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyEqual(t,e('reads'),1);
end

function testFinishRecreatesMissingCurrentChartSummary(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));s.measure();
path=s.files.chartCsv;before=colormeasuretest.readBytes(path);delete(path);e('events')={};s.finish();
verifyEqual(t,e('events'),{'mat','chart-selected','measurements'});
verifyTrue(t,isfile(path));verifyEqual(t,colormeasuretest.readBytes(path),before);
verifyTrue(t,s.finished);verifyTrue(t,s.chart.csvCurrent);
end
function testFinishPreservesChangedChartCsvAndOffersANewSavedCopy(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));s.measure();
path=s.files.chartCsv;expected=colormeasuretest.readBytes(path);
colormeasuretest.writeText(path,'Changed outside the session.');external=colormeasuretest.readBytes(path);
e('events')={};s.finish();verifyEqual(t,e('events'),{'mat','measurements'});
verifyEqual(t,colormeasuretest.readBytes(path),external);verifyFalse(t,s.chart.csvCurrent);
verifyFalse(t,s.chartCsvNeedsRetry);verifyTrue(t,s.companionRecoveryAvailable);
verifySubstring(t,s.chart.csvUnavailableReason,'changed outside');verifyFalse(t,s.needsRecovery);
verifyEqual(t,e('reads'),1);verifyTrue(t,s.finished);
s.retrySave();
folder=fullfile(t.TestData.folder,'another');mkdir(folder);s.saveElsewhere(folder);
verifyTrue(t,s.chart.csvCurrent);verifyNotEqual(t,s.files.chartCsv,path);
verifyEqual(t,colormeasuretest.readBytes(path),external);
verifyEqual(t,colormeasuretest.readBytes(s.files.chartCsv),expected);verifyEqual(t,e('reads'),1);
end

function testNewReadingPreservesExternallyChangedLastGoodChartCsv(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','Two',1,2));s.measure();
path=s.files.chartCsv;colormeasuretest.writeText(path,'Externally edited earlier chart summary.');
external=colormeasuretest.readBytes(path);s.measure();
verifyEqual(t,e('reads'),2);verifyEqual(t,s.savedCount,2);
verifyFalse(t,s.needsRecovery);verifyFalse(t,s.chart.csvCurrent);verifyFalse(t,s.chartCsvNeedsRetry);
verifyTrue(t,s.companionRecoveryAvailable);verifyEqual(t,colormeasuretest.readBytes(path),external);
verifyEqual(t,numel(load(s.files.mat).measurements),2);
end

function testCsvOnlyRetryPreservesSavedMatAndDoesNotAcquire(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));s.measure();
e('failChartCsv')=true;s.editReading(1,'Edited','');
verifyTrue(t,s.chartCsvNeedsRetry);verifyFalse(t,s.chart.csvCurrent);
mat=colormeasuretest.readBytes(s.files.mat);
saves=e('saves');reads=e('reads');e('events')={};
e('failChartCsv')=false;s.retrySave();
verifyEqual(t,e('events'),{'chart-selected'});
verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),mat);
verifyFalse(t,s.chartCsvNeedsRetry);verifyTrue(t,s.chart.csvCurrent);verifyFalse(t,s.saving);verifyFalse(t,s.busy);
end
function testFinishedRelocationMatFailureCanRetryWithoutResumingAcquisition(t)
[s,e]=make(t);s.measure();s.finish();reads=e('reads');e('failMat')=true;
newParent=fullfile(t.TestData.folder,'another');mkdir(newParent);s.saveElsewhere(newParent);
verifyTrue(t,s.finished);verifyNotEmpty(t,s.saveError);e('failMat')=false;s.retrySave();
verifyTrue(t,s.finished);verifyEmpty(t,s.saveError);verifyTrue(t,isfile(s.files.mat));
verifyTrue(t,isfile(s.files.csv));verifyEqual(t,e('reads'),reads);
end

function testFinishedRelocationRefusesReplacementUntilMatAndCsvRecover(t)
[s,e]=make(t);s.measure();s.finish();reads=e('reads');
original=s.files;readings=s.measurements;
mat=colormeasuretest.readBytes(original.mat);csv=colormeasuretest.readBytes(original.csv);
e('failMat')=true;
newParent=fullfile(t.TestData.folder,'another');mkdir(newParent);s.saveElsewhere(newParent);
verifyTrue(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyEqual(t,s.status,'Finished | Save needs attention | 0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyTrue(t,isfolder(original.folder));verifyTrue(t,ismember(original.folder,s.files.previousFolders));
verifyEqual(t,colormeasuretest.readBytes(original.mat),mat);
verifyEqual(t,colormeasuretest.readBytes(original.csv),csv);
verifyFalse(t,s.measure('Must not acquire',''));verifyEqual(t,s.measurements,readings);
verifyEqual(t,e('reads'),reads);
verifyError(t,@()s.newBatch(),'Measurement:SaveRecovery');
e('events')={};e('failMat')=false;e('failCsv')=true;s.retrySave();
verifyEqual(t,e('events'),{'mat','measurements'});
verifyTrue(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyEqual(t,s.status,'Finished | CSV export needs attention | 1 reading saved');
verifyTrue(t,isfile(s.files.mat));verifyEmpty(t,s.files.csv);
verifyError(t,@()s.newBatch(),'Measurement:SaveRecovery');
saves=e('saves');e('events')={};e('failCsv')=false;s.retrySave();
verifyEqual(t,e('events'),{'measurements'});
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyTrue(t,isfile(s.files.csv));
verifyEqual(t,s.status,'Finished | 1 reading saved');
verifyEqual(t,colormeasuretest.readBytes(original.mat),mat);
verifyEqual(t,colormeasuretest.readBytes(original.csv),csv);
verifyEqual(t,e('reads'),reads);verifyEqual(t,e('saves'),saves);
end

function testZeroReadingChartFinishSavesMatAndReusesCurrentChartCsv(t)
% Starting the chart already published its current selected-cell CSV.
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));
csv=s.files.chartCsv;before=colormeasuretest.readBytes(csv);
e('events')={};s.finish(AllowIncompleteChart=true);
verifyEqual(t,e('events'),{'mat'});verifyEqual(t,colormeasuretest.readBytes(csv),before);
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyEmpty(t,s.exportError);
verifyEmpty(t,s.files.csv);verifyTrue(t,isfile(s.files.chartCsv));verifyTrue(t,s.chart.csvCurrent);
verifyEqual(t,s.status,'Finished | 0 readings saved');verifyEqual(t,e('reads'),0);
saved=load(s.files.mat);verifyEmpty(t,saved.measurements);
verifyEqual(t,saved.batchInfo.chart.passes.selectedAttempt,0);
end
function testUnreadableSavedMatKeepsChartCsvRetryableWithoutMatRewrite(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));s.measure();
e('failChartCsv')=true;s.editReading(1,'Edited','');
mat=s.files.mat;missing=[mat '.unreadable'];movefile(mat,missing);
t.addTeardown(@()restoreFile(missing,mat));saves=e('saves');reads=e('reads');
s.retrySave();
verifyTrue(t,s.chartCsvNeedsRetry);verifyTrue(t,s.companionRecoveryAvailable);
verifyFalse(t,s.chart.csvCurrent);verifySubstring(t,s.chart.csvUnavailableReason,'Cannot read');
verifyFalse(t,s.needsRecovery);verifyFalse(t,isfile(mat));
movefile(missing,mat);bytes=colormeasuretest.readBytes(mat);e('failChartCsv')=false;
s.retrySave();verifyTrue(t,s.chart.csvCurrent);verifyFalse(t,s.chartCsvNeedsRetry);
verifyFalse(t,s.companionRecoveryAvailable);verifyEqual(t,colormeasuretest.readBytes(mat),bytes);
verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
end
function restoreFile(source,destination)
if isfile(source)&&~isfile(destination),movefile(source,destination);end
end

% Each reachable recovery combination keeps every part in a fixed order:
% cleanup, Finished, save, CSV, then the saved count.
function testUnconfirmedCleanupWithSaveFailureStatus(t)
[s,e]=make(t);e('failRelease')=true;e('failMat')=true;verifyTrue(t,s.measure());
verifyTrue(t,s.chartIoUnconfirmed);
verifyEqual(t,s.status,'Cleanup unconfirmed | Save needs attention | 0 of 1 reading saved');
verifyEqual(t,e('reads'),1);
end
function testUnconfirmedCleanupWithCsvFailureStatus(t)
[s,e]=make(t);e('failRelease')=true;verifyTrue(t,s.measure());e('failCsv')=true;s.finish();
verifyFalse(t,s.finished);
verifyEqual(t,s.status,'Cleanup unconfirmed | CSV export needs attention | 1 reading saved');
verifyEqual(t,e('reads'),1);
end
function testSaveAndCsvFailureStatus(t)
[s,e]=make(t);s.measure();e('failCsv')=true;s.finish();e('failMat')=true;
folder=fullfile(t.TestData.folder,'another');mkdir(folder);s.saveElsewhere(folder);
verifyFalse(t,s.finished);verifyNotEmpty(t,s.exportError);
verifyEqual(t,s.status,'Save needs attention | CSV export needs attention | 0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyEqual(t,e('reads'),1);
end
function testFinishedRecoveryStatusesKeepUnconfirmedCleanupFirst(t)
[s,e]=make(t);e('failRelease')=true;verifyTrue(t,s.measure());s.finish();
verifyEqual(t,s.status,'Cleanup unconfirmed | Finished | 1 reading saved');
e('failCsv')=true;first=fullfile(t.TestData.folder,'first');mkdir(first);s.saveElsewhere(first);
verifyEqual(t,s.status,'Cleanup unconfirmed | Finished | CSV export needs attention | 1 reading saved');
e('failMat')=true;second=fullfile(t.TestData.folder,'second');mkdir(second);s.saveElsewhere(second);
verifyEqual(t,s.status, ...
    'Cleanup unconfirmed | Finished | Save needs attention | CSV export needs attention | 0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyTrue(t,s.finished);verifyEqual(t,e('reads'),1);
end
function testFinishedSaveFailureWithUnconfirmedCleanupStatus(t)
[s,e]=make(t);e('failRelease')=true;verifyTrue(t,s.measure());s.finish();e('failMat')=true;
folder=fullfile(t.TestData.folder,'another');mkdir(folder);s.saveElsewhere(folder);
verifyEqual(t,s.status,'Cleanup unconfirmed | Finished | Save needs attention | 0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyEqual(t,e('reads'),1);
end
function testFinishedSaveAndCsvFailureStatus(t)
[s,e]=make(t);s.measure();s.finish();e('failCsv')=true;
first=fullfile(t.TestData.folder,'first');mkdir(first);s.saveElsewhere(first);
e('failMat')=true;second=fullfile(t.TestData.folder,'second');mkdir(second);s.saveElsewhere(second);
verifyEqual(t,s.status,'Finished | Save needs attention | CSV export needs attention | 0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyEqual(t,e('reads'),1);
end

function testChangedSavedMatRefusesCsvRetryAndKeepsBothOriginals(t)
[s,e]=make(t);s.measure();e('failCsv')=true;s.finish();
verifyFalse(t,s.finished);verifyNotEmpty(t,s.exportError);
before=s.measurements;data=load(s.files.mat);data.measurements.XYZ=[99 99 99];
save(s.files.mat,'-struct','data');external=colormeasuretest.readBytes(s.files.mat);
saves=e('saves');reads=e('reads');e('failCsv')=false;e('events')={};s.retrySave();
verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);verifyEmpty(t,e('events'));
verifySubstring(t,s.exportError,'changed outside');verifyFalse(t,s.finished);
verifyTrue(t,s.companionRecoveryAvailable);verifyEqual(t,s.measurements,before);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),external);
previous=s.files.mat;folder=fullfile(t.TestData.folder,'recovered');mkdir(folder);s.saveElsewhere(folder);
verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);verifyFalse(t,s.companionRecoveryAvailable);
verifyEqual(t,load(s.files.mat).measurements,before);
verifyEqual(t,colormeasuretest.readBytes(previous),external);verifyEqual(t,e('reads'),reads);
end

function testMatFailureRetainsReadingAndRecoveryDoesNotAcquire(t)
[s,e]=make(t);e('failMat')=true;s.measure();
verifyTrue(t,s.needsRecovery);verifyNumElements(t,s.measurements,1);verifyEmpty(t,s.files.csv);
e('failMat')=false;s.retrySave();verifyFalse(t,s.needsRecovery);
verifyEqual(t,load(s.files.mat).measurements,s.measurements);verifyEqual(t,e('reads'),1);
end

function testSavingCoversMatOnlyWhileBusyAlsoCoversCsv(t)
[s,e]=make(t);s.startChart(colormeasure.chart.definition('custom','One',1,1));
matCalls=0;csvCalls=0;e('saveHook')=@duringMat;e('csvHook')=@duringCsv;
s.measure();s.finish();verifyEqual(t,matCalls,3);verifyEqual(t,csvCalls,2);
verifyFalse(t,s.saving);verifyFalse(t,s.busy);
    function duringMat()
        matCalls=matCalls+1;verifyTrue(t,s.saving);verifyTrue(t,s.busy);
    end
    function duringCsv()
        csvCalls=csvCalls+1;verifyFalse(t,s.saving);verifyTrue(t,s.busy);
    end
end

function testAnnotationRefreshPreservesMeasuredFieldsAndChangesSavedWitness(t)
[s,e]=make(t);s.measure('Before','');before=s.measurements;first=colormeasure.fileDigest(s.files.mat);
s.editReading(1,'After','Edited');second=colormeasure.fileDigest(s.files.mat);
verifyEqual(t,rmfield(s.measurements,{'name','notes'}),rmfield(before,{'name','notes'}));
verifyEqual(t,s.measurements.name,'After');verifyEqual(t,s.measurements.notes,'Edited');
verifyNotEqual(t,first,second);verifyEqual(t,e('reads'),1);
verifyEqual(t,load(s.files.mat).measurements,s.measurements);
end

function testQueuedFinishResaveFailurePreservesDurableReadingAndRecovery(t)
[s,e]=make(t);s.measure();e('readHook')=@()s.finish();e('saveHook')=@refuseFinish;s.measure();
verifyTrue(t,s.finishing);verifyFalse(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyNumElements(t,s.measurements,2);verifyNumElements(t,load(s.files.mat).measurements,2);
verifyEqual(t,e('reads'),2);e('failMat')=false;e('saveHook')=[];s.retrySave();
verifyTrue(t,s.finished);verifyEqual(t,e('reads'),2);verifyTrue(t,isfile(s.files.csv));
    function refuseFinish()
        if s.finishing,error('Fixture:FinishSave','Final MAT resave failed.');end
    end
end

function testRecoveryClassificationUsesTheActualCsvBoundary(t)
cases={'Measurement:FileDigest','source',true,true; ...
    'Measurement:FileDigest','result',true,true; ...
    'Measurement:CompanionSourceChanged','source',false,true; ...
    'Measurement:CompanionOutputChanged','output',false,true; ...
    'Measurement:CompanionSource','source',false,false; ...
    'Fixture:Write','publication',true,true; ...
    'Fixture:Projection','projection',false,false};
for n=1:size(cases,1)
    value=colormeasure.session.companionFailure(MException(cases{n,1},'Failure.'),cases{n,2});
    verifyEqual(t,value,struct('retryable',cases{n,3},'relocatable',cases{n,4}));
end
end

function [s,e]=make(t)
e=containers.Map('KeyType','char','ValueType','any');
for key={'reads','saves'},e(key{1})=0;end
for key={'failMat','failCsv','failChartCsv','failRelease'},e(key{1})=false;end
e('saveHook')=[];e('csvHook')=[];
e('events')={};e('readHook')=[];e('csvReason')='';
a=struct('key','saved-witness-test','label','Native saved witness fixture','listPorts',@(~) "FIXTURE", ...
    'connect',@(~)struct(),'read',@acquire,'release',@release, 'toTable',@toTable, ...
    'csvAvailability',@(~)e('csvReason'), ...
    'catalog',struct('model','CR250','mode','interactive'), ...
    'configuration',struct('synthetic',true));
io=colormeasure.session.services();io.saveMat=@saveMat;
exportCsv=io.exportCsv;io.exportCsv=@saveCsv;
s=colormeasure.session.Session(a,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
    function reading=acquire(~)
        e('reads')=e('reads')+1;reading=direct();
        callback=e('readHook');if ~isempty(callback),callback();end
    end
    function release(~)
        if e('failRelease'),error('Fixture:Release','Synthetic unconfirmed release.');end
    end
    function saveMat(readings,folder,info)
        e('events')=[e('events') {'mat'}];
        e('saves')=e('saves')+1;if e('failMat'),error('Fixture:Mat','Disk unavailable.');end
        hook=e('saveHook');if ~isempty(hook),hook();end
        colormeasure.session.saveMat(readings,folder,info);
    end
    function digest=saveCsv(varargin)
        [~,stem]=fileparts(varargin{3});e('events')=[e('events') {stem}];
        if e('failCsv')||(e('failChartCsv')&&strcmp(stem,'chart-selected'))
            error('Fixture:Csv','CSV export unavailable.');
        end
        hook=e('csvHook');if ~isempty(hook),hook();end
        digest=exportCsv(varargin{:});
    end
end

function reading=direct()
reading=struct('XYZ',[1 2 3],'xyzUnits','cd/m^2','xyzScale','absolute; Y is luminance', ...
    'observerId','CIE1931_2deg','xyzMethod','Native XYZ', ...
    'isSynthetic',true);
end
function data=toTable(readings,~)
xyz=vertcat(readings.XYZ);data=table(xyz(:,1),xyz(:,2),xyz(:,3),'VariableNames',{'X','Y','Z'});
end

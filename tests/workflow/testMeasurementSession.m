function tests = testMeasurementSession
% Shared session behavior with a non-spectral instrument; no physical hardware.
% Two cases open the product window over the product UI services (makeSession
% with 'real'), four inject view and launcher stubs, and the rest run headless.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = fixture.Folder;
visibility = get(groot, 'DefaultFigureVisible');
t.addTeardown(@() set(groot, 'DefaultFigureVisible', visibility));
set(groot, 'DefaultFigureVisible', 'off');
end

function testTwoReadingsUpdateSameMatAndCsvOnlyAtFinish(t)
[s,e] = makeSession(t);
s.measure('Tile A', 'first'); first = s.files.folder;
s.measure('Tile B', 'second');
verifyEqual(t, s.files.folder, first);
saved = load(s.files.mat);
verifyEqual(t, saved.measurements, s.measurements);
verifyTrue(t,all(arrayfun(@(r)isstruct(r.instrumentSettings) && (isempty(r.instrumentSettings) || isscalar(r.instrumentSettings)),s.measurements)));
verifyEqual(t, saved.batchInfo.measurementCount, 2);
verifyFalse(t, saved.batchInfo.acquisitionComplete);
verifyEmpty(t, s.files.csv);
verifyFalse(t, isfile(fullfile(first,'measurements.csv')));
verifyEqual(t, e('releases'), 2);
s.finish();
verifyTrue(t, s.finished);
verifyTrue(t, isfile(s.files.csv));
saved = load(s.files.mat);
verifyTrue(t, saved.batchInfo.acquisitionComplete);
verifyEqual(t, height(readtable(s.files.csv)), 2); % XYZ-only adapter, not spectra.
saves=e('saves'); exports=e('exports');
s.finish(); s.measure();
verifyEqual(t, e('saves'), saves);
verifyEqual(t, e('exports'), exports);
verifyEqual(t, e('reads'), 2);
end

function testCompletedReadingWarningIsLoggedAndSavedWithoutRetry(t)
reads=0; releases=0;
a=struct('key','warning-test','label','Warning test', ...
    'listPorts',@(~) "VIRTUAL",'connect',@(~) struct(), ...
    'read',@readOnce,'release',@releaseOnce,'toTable',@toTable);
s=colormeasure.session.Session(a,t.TestData.folder);t.addTeardown(@() colormeasuretest.disposeSession(s));
verifyTrue(t,s.measure('Sample 001',''));
verifyEqual(t,reads,1);verifyEqual(t,releases,1);
verifyNumElements(t,s.measurements,1);verifyEqual(t,s.savedCount,1);
saved=load(s.files.mat);
verifyEqual(t,saved.measurements.warnings,{'Backlight restoration unverified.'});
levels={s.log.level};messages={s.log.message};
verifyTrue(t,any(strcmp(levels,'warning') & contains(messages,'Backlight restoration unverified')));
    function reading=readOnce(~)
        reads=reads+1;
        reading=struct('XYZ',[1 2 3],'warnings',{{'Backlight restoration unverified.'}});
    end
    function releaseOnce(~)
        releases=releases+1;
    end
end

function testSnapshotsStayIndependentOfLiveCollection(t)
[s,~] = makeSession(t);
s.measure();
snapshot=s.measurements;
s.measure();
verifyNumElements(t, snapshot, 1);
verifyNumElements(t, s.measurements, 2);
verifyEqual(t, s.name, 'Sample 003');
end

function testRelativeDestinationStaysAnchoredWhenCurrentFolderChanges(t)
original=pwd; t.addTeardown(@() cd(original));
root=t.TestData.folder; cd(root); mkdir('chosen');
t.TestData.folder='chosen'; [s,~]=makeSession(t);
verifyTrue(t,s.measure()); first=s.files.mat;
cd(original);
verifyTrue(t,s.measure()); verifyEqual(t,s.savedCount,2);
verifyEqual(t,s.files.mat,first); verifyTrue(t,isfile(first));
verifyEqual(t,load(first).measurements,s.measurements);
verifyEqual(t,s.destination,fileparts(first));
end

function testRelativeRelocationStaysAnchoredWhenCurrentFolderChanges(t)
original=pwd; t.addTeardown(@() cd(original));
[s,~]=makeSession(t); verifyTrue(t,s.measure()); old=s.files.mat;
cd(t.TestData.folder); mkdir('alternate'); s.saveElsewhere('alternate');
relocated=s.files.mat; cd(original);
verifyTrue(t,s.measure()); verifyEqual(t,s.savedCount,2);
verifyEqual(t,s.files.mat,relocated); verifyTrue(t,isfile(old));
verifyEqual(t,load(relocated).measurements,s.measurements);
verifyTrue(t,isfile(fullfile(fileparts(old),'relocated_to.txt')));
end

function testMissingOptionalPreparationDoesNotRequireAWindow(t)
[s,e] = makeSession(t);
verifyEmpty(t,s.preparation);
verifyEqual(t,e('connections'),0);
verifyEqual(t,e('reads'),0);
% Headless, an adapter without a preparation measures at once; the
% confirmation gate a preparation can ask for belongs to the window.
verifyTrue(t,s.measure('No preparation','Custom adapter without optional help'));
verifyEqual(t,e('connections'),1);verifyEqual(t,e('reads'),1);
verifyNumElements(t,s.measurements,1);
end

function testPreparationIsPlainIndependentDataWithoutIOOrViews(t)
guide = struct('title','Test instrument help','summary','Prepare the target.', ...
    'details',{{'Keep the target stable.','No invented preparation telemetry.'}}, ...
    'url','https://example.com/manual','required',true);
for required = [true false]
    guide.required = required;
    [s,e] = makeSession(t,false,false,guide);
    before = s.log; figures = findall(groot,'Type','figure');
    verifyEqual(t,s.preparation,guide);
    verifyEqual(t,s.log,before);
    verifyEqual(t,e('connections'),0); verifyEqual(t,e('reads'),0);
    verifyEqual(t,e('views'),0); verifyEqual(t,e('saves'),0);
    verifyEqual(t,findall(groot,'Type','figure'),figures);
    % Headless acquisition keeps its existing synchronous public behavior.
    verifyTrue(t,s.measure());
    verifyEqual(t,e('reads'),1);
end
end

function testCanonicalAndLocalTimestampsRetainTheSameInstant(t)
[s,~] = makeSession(t);
s.measure();
reading = s.measurements;
format = 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX';
verifyEqual(t, datetime(reading.startedAtLocal, 'InputFormat', format, 'TimeZone', 'UTC'), fixedTime());
verifyEqual(t, datetime(reading.completedAtLocal, 'InputFormat', format, 'TimeZone', 'UTC'), fixedTime());
verifyEqual(t, reading.startedAtUTC, '2026-09-16T12:00:00.000Z');
verifyEqual(t, reading.localTimeZone, s.localTimeZone);
verifyNotEmpty(t, reading.localTimeZone);
verifyNotEqual(t, reading.localTimeZone, 'local');
verifyEqual(t, s.info.startedAtLocal, reading.startedAtLocal);
verifyEqual(t, s.info.completedAtLocal, reading.completedAtLocal);
verifyEqual(t, s.info.sessionStartedAtLocal, s.startedAtLocal);
verifyEqual(t, s.info.sessionLocalTimeZone, s.localTimeZone);
saved = load(s.files.mat);
verifyEqual(t, saved.measurements, reading);
verifyEqual(t, saved.batchInfo.localTimeZone, s.localTimeZone);
end

function testStatusShowsActivityAndFailuresWithoutSaveCounters(t)
[s,e] = makeSession(t);
verifyEqual(t, s.status, 'Ready | 0 readings');
e('readHook') = @() verifyEqual(t, s.status, 'Measuring | 0 readings');
s.measure();
verifyEqual(t, s.status, 'Ready | 1 reading');
e('readHook') = [];
e('failSaves') = 2;
s.measure();
verifyEqual(t, s.status, 'Save needs attention | 1 of 2 readings saved');
s.retrySave();
e('failExports') = 1;
s.finish();
verifyEqual(t, s.status, 'CSV export needs attention | 2 readings saved');
s.retrySave();
verifyEqual(t, s.status, 'Finished | 2 readings saved');
end

function testExplicitSampleUpdatesAndAdvancementCarryRevision(t)
[s,e]=makeSession(t);
initial=s.sampleRevision;
s.setSample(s.name,s.notes);
verifyEqual(t,s.sampleRevision,initial+1);
s.setSample('Command sample','');
verifyEqual(t,s.sampleRevision,initial+2);
e('failReads')=1;
verifyFalse(t,s.measure());
verifyEqual(t,s.sampleRevision,initial+2); % A failed read does not advance drafts.
verifyTrue(t,s.measure());
verifyEqual(t,s.sampleRevision,initial+3);
end

function testBusyAndFinishedSampleUpdatesDoNotAdvanceRevision(t)
[s,e]=makeSession(t); before=s.sampleRevision;
e('readHook')=@() s.setSample('Ignored','Ignored');
s.measure();
verifyEqual(t,s.sampleRevision,before+1); % Successful acquisition only.
s.finish(); before=s.sampleRevision;
s.setSample('Still ignored','');
verifyEqual(t,s.sampleRevision,before);
end

function testFirstReadFailureRetainsSampleAndReleasesInstrument(t)
[s,e] = makeSession(t); e('failReads')=1;
s.setSample('Grey card','keep this note');
verifyFalse(t, s.measure());
verifyEmpty(t, s.measurements);
verifyEqual(t, s.name, 'Grey card');
verifyEqual(t, s.notes, 'keep this note');
verifyEqual(t, e('releases'), 1);
verifyFalse(t, s.busy);
verifyTrue(t, s.measure());
verifyEqual(t, s.measurements.name, 'Grey card');
verifyEqual(t, s.measurements.notes, 'keep this note');
verifyEqual(t, s.name, 'Sample 002');
verifyEqual(t, numel(dir(fullfile(t.TestData.folder,'batch_*'))), 1);
end

function testLaterFailureRetainsEarlierMatAndPendingSample(t)
[s,e]=makeSession(t); s.measure(); e('failReads')=2;
s.measure('Later sample','retry me');
verifyNumElements(t, s.measurements, 1);
verifyEqual(t, s.name,'Later sample');
verifyEqual(t, s.notes,'retry me');
saved=load(s.files.mat); verifyEqual(t,saved.measurements,s.measurements);
verifyEqual(t,e('releases'),2);
end

function testBusyMeasureRefreshAndSaveCannotReenter(t)
[s,e]=makeSession(t);
e('readHook')=@() nestedActions(s);
s.measure();
verifyEqual(t,e('reads'),1);
verifyEqual(t,e('connections'),1);
verifyEqual(t,e('saves'),1);
verifyFalse(t,s.busy);
end

function nestedActions(s)
s.measure('Must not happen',''); s.refreshPorts(); s.retrySave();
s.selectPort('invalid'); s.setSample('Ignored','');
s.saveElsewhere(); s.newBatch();
end

function testBusyFinishWaitsForReadingAndSave(t)
[s,e]=makeSession(t); e('readHook')=@() s.finish();
s.measure();
verifyTrue(t,s.finished);
verifyEqual(t,e('reads'),1);
verifyEqual(t,e('releases'),1);
verifyTrue(t,isfile(s.files.mat)); verifyTrue(t,isfile(s.files.csv));
end

function testBusyFinishWithMatFailureFreezesUntilRetry(t)
[s,e]=makeSession(t); e('failSaves')=1; e('readHook')=@() s.finish();
verifyTrue(t,s.measure());
verifyTrue(t,s.finishing); verifyFalse(t,s.finished); verifyTrue(t,s.needsRecovery);
verifyFalse(t,s.measure('Must not acquire',''));
verifyEqual(t,e('reads'),1);
s.retrySave();
verifyTrue(t,s.finished); verifyFalse(t,s.needsRecovery);
verifyEqual(t,e('reads'),1); verifyTrue(t,isfile(s.files.csv));
saved=load(s.files.mat); verifyTrue(t,saved.batchInfo.acquisitionComplete);
verifyEqual(t,saved.measurements,s.measurements);
end

function testDeferredFinishFreezesBeforeIdleNotification(t)
[s,e]=makeSession(t); e('failSaves')=1; e('readHook')=@() s.finish();
attempted=false; accepted=true;
listener=addlistener(s,'Changed',@observe); t.addTeardown(@() delete(listener));
s.measure();
verifyTrue(t,attempted); verifyFalse(t,accepted); verifyEqual(t,e('reads'),1);
s.retrySave(); verifyTrue(t,s.finished);
    function observe(~,~)
        if ~attempted && ~s.busy && s.needsRecovery
            attempted=true;
            accepted=s.measure('Must not acquire','');
        end
    end
end

function testBusyFinishWithMatFailureCanRelocateAndFinalize(t)
[s,e]=makeSession(t); s.measure(); old=s.files.mat; bytes=colormeasuretest.readBytes(old);
e('failSaves')=2; e('readHook')=@() s.finish(); s.measure();
verifyTrue(t,s.finishing); verifyEqual(t,s.savedCount,1);
other=fullfile(t.TestData.folder,'alternate'); mkdir(other); s.saveElsewhere(other);
verifyTrue(t,s.finished); verifyFalse(t,s.needsRecovery);
verifyTrue(t,isfile(s.files.csv)); verifyEqual(t,e('reads'),2);
verifyEqual(t,colormeasuretest.readBytes(old),bytes);
saved=load(s.files.mat); verifyTrue(t,saved.batchInfo.acquisitionComplete);
verifyEqual(t,saved.measurements,s.measurements); verifyNumElements(t,saved.measurements,2);
verifyEqual(t,saved.batchInfo.previousFolders,{fileparts(old)});
verifyFalse(t,s.measure());
end

function testRepeatedFailedSavesRetainOneLiveCollection(t)
[s,e]=makeSession(t); e('failSaves')=[1 2 3];
s.measure(); s.retrySave(); s.retrySave();
verifyEqual(t,e('reads'),1); verifyEqual(t,e('saves'),3);
verifyNumElements(t,s.measurements,1); verifyEqual(t,s.savedCount,0);
verifyTrue(t,s.needsRecovery); verifyFalse(t,s.busy);
s.retrySave(); verifyEqual(t,s.savedCount,1); verifyFalse(t,s.needsRecovery);
end

function testSaveFailureAfterSuccessTracksOlderDiskCount(t)
[s,e]=makeSession(t); s.measure(); old=colormeasuretest.readBytes(s.files.mat);
e('failSaves')=2; s.measure();
verifyEqual(t,s.savedCount,1); verifyNumElements(t,s.measurements,2);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),old);
verifyTrue(t,contains(s.status,'1 of 2'));
s.retrySave(); saved=load(s.files.mat); verifyEqual(t,saved.measurements,s.measurements);
end

function testCsvFailureAtFinishFreezesAcquisitionAndCanRetry(t)
[s,e]=makeSession(t); s.measure(); e('failExports')=1;
s.finish();
verifyTrue(t,s.finishing); verifyFalse(t,s.finished); verifyTrue(t,s.needsRecovery);
verifyTrue(t,isfile(s.files.mat)); verifyEmpty(t,s.files.csv);
s.measure(); verifyEqual(t,e('reads'),1);
s.retrySave(); verifyTrue(t,s.finished); verifyTrue(t,isfile(s.files.csv));
end

function testCsvRetryDoesNotRewriteAnAlreadyFinalizedMat(t)
[s,e]=makeSession(t); s.measure(); e('failExports')=1;
s.finish(); saves=e('saves'); e('failSaves')=saves+1;
s.retrySave();
verifyTrue(t,s.finished); verifyEqual(t,e('saves'),saves);
verifyEqual(t,e('exports'),2); verifyEqual(t,e('reads'),1);
end

function testFailedFinalMatDoesNotExportPrematurely(t)
[s,e]=makeSession(t); s.measure(); e('failSaves')=2;
s.finish(); verifyFalse(t,s.finished); verifyEqual(t,e('exports'),0);
s.retrySave(); verifyTrue(t,s.finished); verifyEqual(t,e('reads'),1);
end

function testRelocationPreservesOldFilesAndRecordsRelationship(t)
[s,e]=makeSession(t); s.measure(); old=s.files.folder;
bytes=colormeasuretest.readBytes(s.files.mat); e('failSaves')=2; s.measure();
other=fullfile(t.TestData.folder,'alternate'); mkdir(other); s.saveElsewhere(other);
verifyNotEqual(t,s.files.folder,old);
verifyEqual(t,colormeasuretest.readBytes(fullfile(old,'measurements.mat')),bytes);
verifyTrue(t,isfile(fullfile(old,'relocated_to.txt')));
saved=load(s.files.mat); verifyNumElements(t,saved.measurements,2);
verifyEqual(t,saved.batchInfo.previousFolders,{old});
verifyEqual(t,e('reads'),2);
end

function testRelocationWorksWhenPreviousFolderIsUnavailable(t)
[s,~]=makeSession(t); s.measure(); old=s.files.folder;
moved=[old '_offline']; movefile(old,moved);
other=fullfile(t.TestData.folder,'alternate'); mkdir(other); s.saveElsewhere(other);
verifyTrue(t,isfile(s.files.mat)); verifyEqual(t,s.savedCount,1);
verifyFalse(t,s.needsRecovery);
verifyTrue(t,any(contains({s.log.message},'could not be marked')));
end

function testRelocationCleanupDoesNotCloseFilesOpenedByListeners(t)
[s,~]=makeSession(t); s.measure();
opened=-1; filename=fullfile(t.TestData.folder,'listener.txt');
listener=addlistener(s,'Changed',@observe); t.addTeardown(@() delete(listener));
other=fullfile(t.TestData.folder,'alternate'); mkdir(other); s.saveElsewhere(other);
verifyGreaterThan(t,opened,2);
verifyEqual(t,fopen(opened),filename);
    function observe(~,~)
        if opened==-1 && startsWith(s.log(end).message,'Relocation notice written')
            opened=fopen(filename,'w');
            t.addTeardown(@() closeTestFile(opened,filename));
        end
    end
end

function testFailedRelocationKeepsCollectionAndCanRecover(t)
[s,e]=makeSession(t); s.measure(); old=s.files.mat;
e('failSaves')=2;
other=fullfile(t.TestData.folder,'alternate'); mkdir(other); s.saveElsewhere(other);
verifyEqual(t,s.savedCount,0); verifyTrue(t,isfile(old));
verifySubstring(t,s.status,'0 of 1 reading saved here; earlier MAT saved 1 reading');
verifyNumElements(t,s.measurements,1); verifyTrue(t,s.needsRecovery);
s.retrySave(); verifyTrue(t,isfile(s.files.mat));
verifyTrue(t,isfile(fullfile(fileparts(old),'relocated_to.txt')));
end

function testLogAccumulatesAcrossFailuresAndOtherActions(t)
[s,e]=makeSession(t); original=s.log;
s.refreshPorts(); s.measure(); e('failReads')=2; s.measure();
verifyEqual(t,s.log(1:numel(original)),original);
verifyTrue(t,any(strcmp({s.log.level},'error')));
verifyTrue(t,any(contains({s.log.message},'MAT saved')));
verifyGreaterThan(t,numel(s.log),numel(original));
end

function testMissingInitialDestinationAllowsChangingFolderBeforeRead(t)
[s,e]=makeSession(t); rmdir(t.TestData.folder);
s.measure();
verifyTrue(t,s.needsRecovery); verifyEqual(t,e('connections'),0);
mkdir(t.TestData.folder); other=fullfile(t.TestData.folder,'replacement'); mkdir(other);
s.saveElsewhere(other); verifyFalse(t,s.needsRecovery);
verifyTrue(t,s.measure()); verifyEqual(t,s.savedCount,1);
verifyTrue(t,startsWith(s.files.mat,other));
end

function testPortAvailabilityRecheckedBeforeConnection(t)
[s,e]=makeSession(t); e('available')=strings(0,1);
s.measure(); verifyEqual(t,e('connections'),0);
verifyEmpty(t,s.measurements); verifyFalse(t,s.busy);
verifyEqual(t,s.activity,'Setup failed');
verifyTrue(t,contains(s.log(end).message,'Setup failed'));
end

function testConnectionAndReadingFailuresHaveAccurateStageLabels(t)
[s,e]=makeSession(t); e('failConnect')=true;
verifyFalse(t,s.measure()); verifyEqual(t,s.activity,'Connection failed');
verifyTrue(t,contains(s.log(end).message,'Connection failed'));
verifyEqual(t,e('reads'),0); verifyEqual(t,e('releases'),0);
verifyTrue(t,s.chartIoUnconfirmed);
% A failed connection without a cleanup witness cannot be reused for reading.
[s,e]=makeSession(t); e('failReads')=1;
verifyFalse(t,s.measure()); verifyEqual(t,s.activity,'Reading failed');
verifyTrue(t,contains(s.log(end).message,'Reading failed'));
verifyEqual(t,e('reads'),1); verifyEqual(t,e('releases'),1);
verifyFalse(t,s.chartIoUnconfirmed);
end

function testPortStatusDistinguishesSelectionFromConnection(t)
[s,e]=makeSession(t);
verifyEqual(t,s.activity,'Awaiting Measure'); verifyEqual(t,e('connections'),0);
e('ports')=strings(0,1); e('available')=strings(0,1); s.refreshPorts();
verifyEqual(t,s.activity,'No port available');
e('ports')=["A";"B"]; e('available')=["A";"B"]; s.refreshPorts();
verifyEqual(t,s.activity,'Select instrument port');
s.selectPort('B'); verifyEqual(t,s.activity,'Awaiting Measure');
verifyEqual(t,e('connections'),0);
end

function testPresentationDataIsOnlyComputedWhenRequested(t)
[s,e]=makeSession(t,true);
verifyTrue(t,s.measure()); verifyTrue(t,isfile(s.files.mat));
verifyEqual(t,e('viewDataCalls'),0);
verifyEqual(t,s.viewData(),struct('XYZ',[1 2 3],'kind','XYZ-only'));
verifyEqual(t,e('viewDataCalls'),1);
end

function testMissingPresentationHookReturnsEmptyStruct(t)
[s,~]=makeSession(t);
verifyEqual(t,s.viewData(),struct([]));
end

function testPortDiscoveryDoesNotAutoChooseAmongDistinctPorts(t)
[s,e]=makeSession(t); e('ports')=["A";"B"]; e('available')=["A";"B"];
s.refreshPorts(); verifyEmpty(t,s.port); s.selectPort('B');
s.refreshPorts(); verifyEqual(t,s.port,'B');
s.measure(); verifyEqual(t,s.measurements.port,'B');
end

function testMacAliasPreferencePreservesAdapterAndTtyOnly(t)
ports=["/dev/tty.usbmodem1";"/dev/cu.usbmodem1";"/dev/cu.usbserial2";"/dev/tty.only"];
actual=colormeasure.session.availablePorts(ports,ports,true);
verifyEqual(t,actual,ports(2:4));
verifyEqual(t,colormeasure.session.availablePorts(ports,ports,false),ports);
verifyEqual(t,colormeasure.session.availablePorts(ports,ports(1),true),ports(1));
end

function testFinishBeforeAnyReadingDoesNotCreateBatch(t)
[s,e]=makeSession(t); s.finish();
verifyTrue(t,s.finished); verifyEqual(t,e('connections'),0);
verifyEmpty(t,dir(fullfile(t.TestData.folder,'batch_*')));
end

function testFailedFirstReadingEmptyReservationRemovedOnFinish(t)
[s,e]=makeSession(t); e('failReads')=1; s.measure();
reserved=s.files.folder; verifyTrue(t,isfolder(reserved));
s.finish(); verifyFalse(t,isfolder(reserved));
end

function testSessionDeletionPreservesUnsavedOrdinaryStructs(t)
[s,e]=makeSession(t); e('failSaves')=1; s.measure();
expected=s.measurements; before=evalin('base','who(''colorMeasureRecovered_*'')');
warningState=warning('off','Measurement:UnsavedSession'); cleanup=onCleanup(@() warning(warningState));
delete(s);
after=evalin('base','who(''colorMeasureRecovered_*'')'); names=setdiff(after,before);
verifyNumElements(t,names,1);
recovered=evalin('base',names{1}); verifyEqual(t,recovered.measurements,expected);
evalin('base',['clear ' names{1}]);
end

function testBatchFolderReservationDoesNotOverwrite(t)
a=colormeasure.session.createMeasurementFolder(t.TestData.folder,'batch',fixedTime());
b=colormeasure.session.createMeasurementFolder(t.TestData.folder,'batch',fixedTime());
verifyNotEqual(t,a,b);
end

function testDefaultServicesHaveNoPresentationDependencies(t)
io=colormeasure.session.services();
verifyFalse(t,isfield(io,'chooseFolder'));
verifyFalse(t,isfield(io,'createView'));
verifyFalse(t,isfield(io,'launchSession'));
verifyClass(t,io.now(),'datetime');
verifyClass(t,io.saveMat,'function_handle');
verifyClass(t,io.exportCsv,'function_handle');
verifyEqual(t,io.isMac,ismac());
end

function testCoreActionsNeverConstructAnInjectedView(t)
[s,e]=makeSession(t,true,true);
figures=findall(groot,'Type','figure');
s.measure(); s.finish();
verifyTrue(t,s.finished); verifyEqual(t,e('reads'),1);
verifyEqual(t,e('views'),0); verifyEqual(t,e('launches'),0);
verifyEqual(t,e('viewDataCalls'),0);
verifyEmpty(t,s.window);
verifyEqual(t,findall(groot,'Type','figure'),figures);
end

function testMissingPresentationServicesGiveActionableErrors(t)
[s,e]=makeSession(t);
s.hide(); verifyEmpty(t,s.window);
verifyError(t,@() s.show(),'Measurement:ViewUnavailable');
verifyEmpty(t,s.newBatch()); % A running batch is never replaced.
s.finish();
verifyError(t,@() s.newBatch(),'Measurement:LauncherUnavailable');
verifyTrue(t,s.finished); verifyEqual(t,e('reads'),0);
verifyEmpty(t,s.window);
end

function testMissingFolderPickerDoesNotChangeState(t)
[s,e]=makeSession(t); before=s.log; activity=s.activity;
verifyError(t,@() s.saveElsewhere(),'Measurement:FolderPickerUnavailable');
verifyFalse(t,s.busy); verifyEqual(t,s.log,before); verifyEqual(t,s.activity,activity);
other=fullfile(t.TestData.folder,'explicit'); mkdir(other);
s.saveElsewhere(other);
verifyEqual(t,s.destination,other); verifyEqual(t,e('reads'),0);
verifyTrue(t,s.measure()); verifyTrue(t,startsWith(s.files.mat,other));
end

function testInjectedFolderPickerCanCancelOrChangeDestination(t)
[s,e]=makeSession(t,false,true); before=s.destination;
s.saveElsewhere(); verifyEqual(t,s.destination,before); verifyFalse(t,s.busy);
other=fullfile(t.TestData.folder,'chosen'); mkdir(other); e('pickedFolder')=other;
s.saveElsewhere(); verifyEqual(t,s.destination,other);
verifyEqual(t,e('folderChoices'),2); verifyEqual(t,e('reads'),0);
verifyEqual(t,e('pickerPrevious'),before);
end

function testInjectedViewLifecycleDoesNotAcquire(t)
[s,e]=makeSession(t,false,true); s.show(); first=s.window;
verifyTrue(t,isgraphics(first)); verifyEqual(t,e('views'),1);
verifyEqual(t,e('reads'),0); verifyEmpty(t,s.measurements);
s.show(); verifyEqual(t,s.window,first); verifyEqual(t,e('views'),1);
s.hide(); verifyEqual(t,char(get(first,'Visible')),'off'); verifyFalse(t,s.finished);
close(first); verifyTrue(t,isgraphics(first)); verifyFalse(t,s.finishing);
delete(first); s.show(); second=s.window;
verifyTrue(t,isgraphics(second)); verifyNotEqual(t,second,first);
% The injected view restores its figure without replacing its owner.
verifyEqual(t,e('views'),1); verifyEqual(t,e('deletedViews'),0);
close(second);verifyTrue(t,isgraphics(second));verifyEqual(t,char(second.Visible),'off');
verifyFalse(t,s.finished);verifyFalse(t,s.finishing);
s.show();verifyEqual(t,s.window,second);verifyEqual(t,e('views'),1);
delete(s); verifyFalse(t,isgraphics(second)); verifyEqual(t,e('deletedViews'),1);
verifyEqual(t,e('reads'),0);
end

function testInjectedLauncherPreservesWindowUntilReplacement(t)
[s,e]=makeSession(t,false,true); s.show(); first=s.window;
verifyEmpty(t,s.newBatch()); verifyEqual(t,e('launches'),0);
s.finish();
verifyEmpty(t,s.newBatch()); verifyTrue(t,isgraphics(first));
e('nextSession')=s; verifyEqual(t,s.newBatch(),s); verifyTrue(t,isgraphics(first));
[next,~]=makeSession(t); e('nextSession')=next;
verifyEqual(t,s.newBatch(),next); verifyFalse(t,isgraphics(first)); verifyEmpty(t,s.window);
verifyEqual(t,e('launches'),3); verifyEqual(t,e('launchParent'),t.TestData.folder);
verifyTrue(t,e('launchNewBatch'));
adapter=e('launchAdapter'); verifyEqual(t,adapter.label,s.label);
io=e('launchIO'); verifyClass(t,io.createView,'function_handle');
verifyClass(t,io.launchSession,'function_handle'); verifyEqual(t,io.now(),fixedTime());
verifyEqual(t,e('reads'),0); verifyFalse(t,next.finished);
end

function testConstructorAndWindowReturnWithoutMeasuring(t)
% The product window over the product UI services: showing it acquires
% nothing. Display problems are errors here, not warnings.
displayProblemsAreErrors(t);
[s,e] = makeSession(t,false,'real');
s.show();
verifyTrue(t, isgraphics(s.window));
verifyEmpty(t, s.measurements);
verifyEqual(t, e('reads'), 0);
verifyFalse(t, s.busy);
verifyNotEmpty(t, s.log);
end

function testBusyCloseWithMatFailureRetainsRecovery(t)
displayProblemsAreErrors(t);
[s,e]=makeSession(t,false,'real'); s.show();
e('failSaves')=1; e('readHook')=@() close(s.window);
s.measure();
verifyFalse(t,s.finished); verifyFalse(t,s.busy);
verifyFalse(t,s.finishing); verifyEqual(t,char(get(s.window,'Visible')),'off');
verifyTrue(t,s.needsRecovery); verifyTrue(t,isgraphics(s.window));
verifyNumElements(t,s.measurements,1);
s.retrySave(); s.finish(); verifyTrue(t,s.finished);
end

function displayProblemsAreErrors(t)
state = warning('error','Measurement:Display');
t.addTeardown(@() warning(state));
end

function [s,e]=makeSession(t,withPresentation,withWindow,preparation)
% withWindow: false (no window), true (the injected view and launcher stubs
% below) or 'real' (the product window and UI services).
e=containers.Map('KeyType','char','ValueType','any');
for key={'reads','connections','releases','saves','exports','views','deletedViews','launches','folderChoices','viewDataCalls'}, e(key{1})=0; end
e('failReads')=[]; e('failSaves')=[]; e('failExports')=[];
e('readHook')=[]; e('ports')="VIRTUAL"; e('available')="VIRTUAL";
e('failConnect')=false; e('pickedFolder')=''; e('nextSession')=[];
a=struct('key',t.TestData.folder,'label','Test colorimeter', ...
    'listPorts',@(mode) ports(mode,e),'connect',@(port) connect(port,e), ...
    'read',@(instrument) instrument.Read(), 'release',@(instrument) delete(instrument), ...
    'toTable',@toTable);
if nargin>1 && withPresentation
    a.viewData=@(m) viewData(m,e);
end
if nargin>3
    a.preparation=preparation;
end
io=colormeasure.session.services();
if nargin>2 && isequal(withWindow,'real'), io=colormeasure.ui.services(io); end
io.now=@fixedTime; io.isMac=true;
io.saveMat=@(m,f,i) saveMat(m,f,i,e); io.exportCsv=@(m,i,f,fun) exportCsv(m,i,f,fun,e);
if nargin>2 && isequal(withWindow,true)
    io.createView=@(session) createView(session,e);
    io.launchSession=@(adapter,services,parent,forceNew) launchSession(adapter,services,parent,forceNew,e);
    io.chooseFolder=@(previous) chooseFolder(previous,e);
end
s=colormeasure.session.Session(a,t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.disposeSession(s));
end
function p=ports(mode,e)
if strcmp(mode,'all'), p=e('ports'); else, p=e('available'); end
end
function instrument=connect(~,e)
e('connections')=e('connections')+1;
if e('failConnect'), error('Test:Connect','Injected connection failure'); end
instrument=colormeasuretest.session.Instrument(@() read(e),@() released(e));
end
function reading=read(e)
e('reads')=e('reads')+1;
hook=e('readHook'); if ~isempty(hook), hook(); end
if ismember(e('reads'),e('failReads')), error('Test:Read','Injected read failure'); end
reading=struct('XYZ',[1 2 3]*e('reads'),'deviceType','XYZ-only test instrument');
end
function released(e)
e('releases')=e('releases')+1;
end
function saveMat(m,f,i,e)
e('saves')=e('saves')+1;
assert(e('releases')==e('connections'),'Instrument must be released before saving');
if ismember(e('saves'),e('failSaves')), error('Test:Save','Injected MAT failure'); end
colormeasure.session.saveMat(m,f,i);
end
function digest=exportCsv(m,i,f,fun,e)
e('exports')=e('exports')+1;
if ismember(e('exports'),e('failExports')), error('Test:Export','Injected CSV failure'); end
digest=colormeasure.session.exportCsv(m,i,f,fun);
end
function data=viewData(m,e)
e('viewDataCalls')=e('viewDataCalls')+1;
data=struct('XYZ',vertcat(m.XYZ),'kind','XYZ-only');
end
function view=createView(session,e)
e('views')=e('views')+1;
view=colormeasuretest.session.PresentationView(session,@() deletedView(e));
end
function deletedView(e)
e('deletedViews')=e('deletedViews')+1;
end
function session=launchSession(adapter,services,parent,forceNew,e)
e('launches')=e('launches')+1;
e('launchAdapter')=adapter; e('launchIO')=services;
e('launchParent')=parent; e('launchNewBatch')=forceNew;
session=e('nextSession');
end
function folder=chooseFolder(previous,e)
e('folderChoices')=e('folderChoices')+1; e('pickerPrevious')=previous;
folder=e('pickedFolder');
end
function data=toTable(m,~)
data=table((1:numel(m))',{m.name}',vertcat(m.XYZ),'VariableNames',{'Index','Name','XYZ'});
end
function time=fixedTime()
time=datetime(2026,9,16,12,0,0,'TimeZone','UTC');
end
function closeTestFile(fid,filename)
try
    if strcmp(fopen(fid),filename), fclose(fid); end
catch
    % An already-closed test descriptor needs no cleanup.
end
end

function testCsvPreservesQuotedTextWithEachLineEnding(t)
filename=fullfile(t.TestData.folder,'quoted.csv');
values={sprintf('Name\rpart'),sprintf('Notes\npart'),'Serial "quoted"'};
data=table(values(1),values(2),values(3),7,'VariableNames',{'Name','Notes','Serial','Value'});
colormeasure.session.exportCsv([],struct(),filename,@(~,~)data);
text=fileread(filename);
verifySubstring(t,text,['"' values{1} '"']);verifySubstring(t,text,['"' values{2} '"']);
verifySubstring(t,text,'"Serial ""quoted"""');
restored=readtable(filename,'TextType','string','VariableNamingRule','preserve');
verifyEqual(t,restored.Name,string(values{1}));verifyEqual(t,restored.Notes,string(values{2}));
verifyEqual(t,restored.Serial,string(values{3}));verifyEqual(t,restored.Value,7);
end

function testCsvPublishesTheExactStagedByteWitness(t)
filename=fullfile(t.TestData.folder,'witness.csv');data=table(7,"Sample",'VariableNames',{'Y','Name'});
digest=colormeasure.session.exportCsv([],struct(),filename,@(~,~)data);
verifyEqual(t,digest,colormeasure.fileDigest(filename));
data.Y=9;next=colormeasure.session.exportCsv([],struct(),filename,@(~,~)data);
verifyNotEqual(t,next,digest);verifyEqual(t,next,colormeasure.fileDigest(filename));
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.csv')));
end

function testCsvDigestRefusalPreservesPublishedBytesAndRemovesStage(t)
filename=fullfile(t.TestData.folder,'unchanged.csv');data=table(7,'VariableNames',{'Y'});
colormeasure.session.exportCsv([],struct(),filename,@(~,~)data);
bytes=colormeasuretest.readBytes(filename);
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
package=fullfile(folder,'+colormeasure');mkdir(package);
colormeasuretest.writeText(fullfile(package,'fileDigest.m'),sprintf([ ...
    'function digest=fileDigest(varargin) %%#ok<STOUT> Deliberate staged-read refusal.\n' ...
    'error(''Measurement:FileDigest'',''Injected staged-byte read failure.'');\nend\n']));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
assertEqual(t,which('colormeasure.fileDigest'),fullfile(package,'fileDigest.m'));
problem=colormeasuretest.captureError(@()colormeasure.session.exportCsv([],struct(),filename,@(~,~)data));
verifyEqual(t,problem.identifier,'Measurement:CsvSaveFailed');
verifyTrue(t,any(cellfun(@(cause)strcmp(cause.identifier,'Measurement:FileDigest'),problem.cause)));
verifyEqual(t,colormeasuretest.readBytes(filename),bytes);
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.csv')));
end

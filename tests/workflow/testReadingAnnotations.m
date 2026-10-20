function tests=testReadingAnnotations
% Operator annotations over retained readings; real MAT/CSV, fake acquisition.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end
function testEditSavesOriginalAnnotationsAndLeavesAcquisitionUntouched(t)
[s,e]=batch(t);s.measure('Original','first');s.measure('Original','second');
before=s.measurements;draft={s.name,s.notes};
verifyTrue(t,s.editReading(1,'Renamed',sprintf('line 1\nline 2')));
verifyTrue(t,s.editReading(1,'Final label','last note'));
verifyEqual(t,s.measurements(1).name,'Final label');
verifyEqual(t,s.measurements(2),before(2));
verifyEqual(t,rmfield(s.measurements,{'name','notes'}),rmfield(before,{'name','notes'}));
verifyEqual(t,{s.name,s.notes},draft);verifyEqual(t,e('reads'),2);
verifyEqual(t,s.readingAnnotations.originalName,'Original');
verifyEqual(t,s.readingAnnotations.originalNotes,'first');
verifyFalse(t,isfield(s.readingAnnotations,'observationId'));
verifyEqual(t,s.annotationRevision,2);verifyNotEmpty(t,s.readingAnnotations.editedAtUTC);
saved=load(s.files.mat);verifyEqual(t,saved.measurements,s.measurements);
verifyEqual(t,saved.batchInfo.readingAnnotations,s.readingAnnotations);
verifyEqual(t,saved.batchInfo.annotationRevision,s.annotationRevision);
s.finish();data=readtable(s.files.csv,'TextType','string');
verifyEqual(t,data.MeasurementName,["Final label";"Original"]);
verifyEqual(t,data.Notes,["last note";"second"]);
end
function testMatFailureKeepsEditAndRetryDoesNotTrustUnchangedCount(t)
[s,e]=batch(t);s.measure('Before','note');original=load(s.files.mat);
e('failSave')=true;verifyFalse(t,s.editReading(1,'After','updated'));
verifyTrue(t,s.needsRecovery);verifyEqual(t,s.measurements.name,'After');
verifyEqual(t,s.savedCount,1);verifyEqual(t,load(s.files.mat).measurements,original.measurements);
e('failSave')=false;s.retrySave();
verifyFalse(t,s.needsRecovery);verifyEqual(t,load(s.files.mat).measurements,s.measurements);
verifyEqual(t,e('reads'),1);s.finish();verifyTrue(t,s.finished);
end
function testFinishedBatchEditRefreshesBothFilesWithoutOpeningAcquisition(t)
[s,e]=batch(t);s.measure('Before','note');s.finish();
verifyTrue(t,s.editReading(1,'After','new note'));verifyTrue(t,s.finished);
verifyEqual(t,load(s.files.mat).measurements,s.measurements);
data=readtable(s.files.csv,'TextType','string');verifyEqual(t,data.MeasurementName,"After");
verifyEqual(t,data.Notes,"new note");verifyFalse(t,s.measure());verifyEqual(t,e('reads'),1);
end
function testFinishedBatchMatFailurePreservesRecoveryAndAcquisitionLock(t)
[s,e]=batch(t);s.measure('Before','note');s.finish();old=load(s.files.mat);
e('failSave')=true;verifyFalse(t,s.editReading(1,'After','new note'));
verifyFalse(t,s.finished);verifyTrue(t,s.finishing);verifyTrue(t,s.needsRecovery);
verifyFalse(t,s.measure());verifyEmpty(t,s.newBatch());
verifyEqual(t,load(s.files.mat).measurements,old.measurements);
e('failSave')=false;s.retrySave();verifyTrue(t,s.finished);verifyFalse(t,s.needsRecovery);
verifyEqual(t,readtable(s.files.csv,'TextType','string').MeasurementName,"After");
verifyEqual(t,e('reads'),1);
end
function testFinishedBatchCsvFailureKeepsCompleteMatAndRetriesExport(t)
[s,e]=batch(t);s.measure('Before','note');s.finish();
oldCsv=s.files.csv;e('failExport')=true;verifyFalse(t,s.editReading(1,'After','new note'));
verifyTrue(t,s.finishing);verifyFalse(t,s.finished);verifyTrue(t,s.needsRecovery);
verifyEqual(t,load(s.files.mat).measurements.name,'After');
verifyEmpty(t,s.files.csv);verifyEqual(t,readtable(oldCsv,'TextType','string').MeasurementName,"Before");
saves=e('saves');e('failExport')=false;s.retrySave();
verifyTrue(t,s.finished);verifyEqual(t,e('saves'),saves);
verifyEqual(t,readtable(s.files.csv,'TextType','string').MeasurementName,"After");
end
function testAnotherFolderRetainsCurrentAnnotationsAndEarlierSnapshot(t)
[s,e]=batch(t);s.measure('Before','note');previous=s.files.mat;
e('failSave')=true;s.editReading(1,'After','new note');e('failSave')=false; %#ok<NASGU> Map writes are consumed by injected save IO.
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
s.saveElsewhere(folder);verifyFalse(t,s.needsRecovery);
verifyEqual(t,load(previous).measurements.name,'Before');
verifyEqual(t,load(s.files.mat).measurements.name,'After');
verifyEqual(t,load(s.files.mat).batchInfo.readingAnnotations,s.readingAnnotations);
end
function testInvalidAnnotationAndNoOpDoNotChangeStateOrSave(t)
[s,e]=batch(t);s.measure('Before','note');before=s.measurements;writes=e('saves');
for name={'',sprintf('two\nlines'),sprintf('two\rlines')}
    verifyError(t,@()s.editReading(1,name{1},''),'Measurement:AnnotationName');
end
verifyError(t,@()s.editReading(1,{'wrong type'},''),'Measurement:AnnotationText');
verifyTrue(t,s.editReading(1,'Before','note'));
verifyEqual(t,s.measurements,before);verifyEmpty(t,s.readingAnnotations);
verifyEqual(t,s.annotationRevision,0);verifyEqual(t,e('saves'),writes);
end
function testActiveAcquisitionCannotEditExistingReading(t)
[s,e]=batch(t);s.measure('Before','note');
e('readHook')=@()verifyError(t,@()s.editReading(1,'Changed',''), 'Measurement:AnnotationBusy'); %#ok<NASGU> The map supplies the injected read hook.
s.measure('Second','');verifyEqual(t,s.measurements(1).name,'Before');verifyEmpty(t,s.readingAnnotations);
end

function testRetainedModeLabelsPreserveNativeQuantity(t)
for code=11:14
    r=struct('XYZ',[1 2 3],'deviceType','PR655','unitsCode',code,'spectralUnits','fixture units');
    d=colormeasure.drivers.pr.viewData(r);
    labels={'Spectral radiance','Spectral irradiance','Spectral radiant intensity','Spectral radiant flux'};
    verifyEqual(t,d.measurementModes{1},labels{code-10});
end
d=colormeasure.drivers.cr.viewData(colormeasure.drivers.cr.syntheticReading('CR100',1),'CR-100');
verifyEqual(t,d.measurementModes,{'Tristimulus'});
verifyError(t,@()colormeasure.session.validateViewData(struct('measurementModes',{{'one','two'}}),1), ...
    'Measurement:InvalidViewData');
end
function [s,e]=batch(t)
e=containers.Map('KeyType','char','ValueType','any');
e('reads')=0;e('saves')=0;e('failSave')=false;e('failExport')=false;e('readHook')=[];
adapter=struct('key',t.TestData.folder,'label','Annotation fixture','listPorts',@(~)"VIRTUAL", ...
    'connect',@(~)[], 'read',@read,'release',@(~)[], ...
    'toTable',@(m,~)table(string({m.name})',string({m.notes})','VariableNames',{'MeasurementName','Notes'}));
io=colormeasure.session.services();io.saveMat=@save;io.exportCsv=@export;
s=colormeasure.session.Session(adapter,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(s));
    function reading=read(~)
        e('reads')=e('reads')+1;hook=e('readHook');if ~isempty(hook),hook();end
        reading=struct('XYZ',[1 2 3]*e('reads'),'rawResponse','exact fixture response');
    end
    function save(m,f,info)
        e('saves')=e('saves')+1;
        if e('failSave'),error('Fixture:Save','Disk unavailable');end
        colormeasure.session.saveMat(m,f,info);
    end
    function digest=export(m,info,f,toTable)
        if e('failExport'),error('Fixture:Export','CSV unavailable');end
        digest=colormeasure.session.exportCsv(m,info,f,toTable);
    end
end

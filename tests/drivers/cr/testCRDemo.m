function tests=testCRDemo
% Synthetic records and batch mode only; actual window tests live with the UI.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testSyntheticProfilesCycleWithoutInventingDeviceMetadata(t)
for model={'CR100','CR250','CR300'}
    a=colormeasure.drivers.cr.demoAdapter(model{1});
    verifyEqual(t,a.listPorts('available'),"CR_SYNTHETIC_ONLY");
    first=a.read(a.connect('CR_SYNTHETIC_ONLY'));
    wrapped=colormeasure.drivers.cr.syntheticReading(model{1},13);
    verifyNotEqual(t,first.XYZ,wrapped.XYZ);
    verifyEqual(t,first.XYZ/first.XYZ(2),wrapped.XYZ/wrapped.XYZ(2),'AbsTol',1e-12);
    verifyLessThanOrEqual(t,max(abs(wrapped.XYZ./first.XYZ-1)),.011);
    verifyEqual(t,first.syntheticProfileIndex,1);
    verifyTrue(t,first.isSynthetic);
    verifyEmpty(t,fieldnames(first.instrumentMetadata));
    verifyEmpty(t,fieldnames(first.driverSnapshot));
    verifyTrue(t,all(isnan(first.instrumentXYZ)));
    data=colormeasure.drivers.cr.viewData(first,model{1}); verifyNotEmpty(t,data.xyzComparisonKeys{1});
    if strcmp(model{1},'CR100')
        verifyEmpty(t,first.lambda); verifyEmpty(t,first.spectralData); verifyFalse(t,data.hasSpectra);
    else
        step=1+strcmp(model{1},'CR250');
        verifyEqual(t,first.lambda,(380:step:780).');
        verifyEqual(t,first.spectralUnits,'synthetic units');
        verifyNotEmpty(t,data.spectralComparisonKeys{1});
    end
end
end

function testEachModelAndModeHasSeparateRegistryIdentity(t)
keys={}; handles={};
for model={'CR100','CR250','CR300'}
    a=colormeasure.drivers.cr.uiAdapter(model{1}); keys{end+1}=a.key; handles{end+1}=a.workspaceName; %#ok<AGROW>
    verifyEqual(t,a.catalog,struct('model',model{1},'mode','measure'));
    for mode={'interactive','batch','gallery'}
        a=colormeasure.drivers.cr.demoAdapter(model{1},mode{1});
        verifyEqual(t,a.catalog,struct('model',model{1},'mode',mode{1}));
        keys{end+1}=a.key; handles{end+1}=a.workspaceName; %#ok<AGROW>
    end
end
verifyEqual(t,numel(unique(keys)),12); verifyEqual(t,numel(unique(handles)),12);
end

function testAllPublicBatchDemosSaveTwoReadingsWithoutAWindow(t)
for model={'CR100','CR250','CR300'}
    launch=str2func(['colormeasure.drivers.cr.demo' model{1}]); s=launch('batch');
    cleanup=onCleanup(@() colormeasuretest.disposeBatch(s));
    verifyTrue(t,s.finished); verifyEmpty(t,s.window); verifyNumElements(t,s.measurements,2);
    verifyTrue(t,all([s.measurements.isSynthetic]));
    verifyTrue(t,isfile(s.files.mat)); verifyTrue(t,isfile(s.files.csv));
    stored=load(s.files.mat); verifyEqual(t,stored.measurements,s.measurements);
    rows=max(1,numel(s.measurements(1).lambda));
    verifyEqual(t,height(readtable(s.files.csv)),2*rows);
    clear cleanup
end
end

function testFailedFirstOrSecondDemoReadingCannotReportCompletion(t)
for failedIndex=1:2
    attempts=0;
    a=colormeasure.drivers.cr.demoAdapter('CR100','batch'); a.read=@read;
    folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    s=colormeasure.session.Session(a,folder.Folder); cleanup=onCleanup(@() delete(s));
    verifyError(t,@() colormeasure.session.demoBatch(s,2,'CR:DemoMeasurement','CR:DemoPersistence'),'CR:DemoMeasurement');
    verifyNumElements(t,s.measurements,failedIndex-1);
    verifyFalse(t,s.finished); verifyEmpty(t,s.files.csv); verifyEmpty(t,s.window);
    clear cleanup
end
    function reading=read(~)
        attempts=attempts+1;
        if attempts==failedIndex, error('crtest:DemoRead','Injected demo reading failure.'); end
        reading=colormeasure.drivers.cr.syntheticReading('CR100',attempts);
    end
end

function testFailedFinalMatOrCsvCannotReportCompletion(t)
for target={'mat','csv'}
    count=0;
    a=colormeasure.drivers.cr.demoAdapter('CR100','batch'); io=colormeasure.session.services();
    if strcmp(target{1},'mat'), io.saveMat=@saveMat;
    else, io.exportCsv=@failCsv;
    end
    folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    s=colormeasure.session.Session(a,folder.Folder,io); cleanup=onCleanup(@() delete(s));
    verifyError(t,@() colormeasure.session.demoBatch(s,2,'CR:DemoMeasurement','CR:DemoPersistence'),'CR:DemoPersistence');
    verifyNumElements(t,s.measurements,2); verifyFalse(t,s.finished); verifyEmpty(t,s.window);
    if strcmp(target{1},'mat'), verifyNotEmpty(t,s.saveError);
    else, verifyNotEmpty(t,s.exportError);
    end
    verifyTrue(t,isfile(s.files.mat)); % Earlier complete readings remain saved.
    clear cleanup
end
    function saveMat(varargin)
        count=count+1;
        if count==3, error('crtest:DemoMat','Injected final MAT failure.'); end
        colormeasure.session.saveMat(varargin{:});
    end
end

function testFailedBatchDemoRetainsItsSessionInTheWorkspaceAndRethrows(t)
% A throwing call cannot return its session. The retained variable is
% announced with an identifier, like the PR-655 demo, and holds the complete
% readings, the saved MAT and the export error.
colormeasuretest.preserveWorkspace(t,'colorMeasureCR100DemoBatch');
io=colormeasure.session.services(); io.exportCsv=@failCsv;
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
verifyWarning(t,@() verifyError(t,@() colormeasure.drivers.cr.demoSession('CR100','batch',io,folder.Folder), ...
    'CR:DemoPersistence'),'CR:DemoBatchRetained');
s=evalin('base','colorMeasureCR100DemoBatch'); t.addTeardown(@() colormeasuretest.disposeBatch(s));
verifyNumElements(t,s.measurements,2); verifyFalse(t,s.finished);
verifyNotEmpty(t,s.exportError); verifyTrue(t,isfile(s.files.mat));
verifyTrue(t,startsWith(s.files.folder,char(java.io.File(folder.Folder).getCanonicalPath())));
end

function digest=failCsv(varargin) %#ok<STOUT> Deliberate publisher refusal.
error('crtest:DemoCsv','Injected CSV failure.');
end

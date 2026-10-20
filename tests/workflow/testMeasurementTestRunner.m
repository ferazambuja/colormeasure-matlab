function tests = testMeasurementTestRunner
% Discovery and failure reporting checks; never launch a nested MATLAB worker.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end


function testExistingReportsCannotBeOverwritten(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename = fullfile(fixture.Folder,'previous.txt');
colormeasuretest.writeText(filename,'retain this report');
verifyError(testCase,@()colormeasure.runTests(fixture.Folder),'measurement:TestOutputFolder');
verifyEqual(testCase,fileread(filename),'retain this report');
end

function testInvalidOutputArgumentsDoNotLaunchWorker(testCase)
for value = {42,'',["one" "two"],string(missing)}
    verifyError(testCase,@()colormeasure.runTests(value{1}),'measurement:TestOutputFolder');
end
end

function testInvalidPublicGroupsRefuseBeforeCreatingReports(testCase)
for groups={42,{'unknown'},{'pr','pr'},{'pr',42},{'argyll'},string(missing)}
    folder=tempname;
    verifyError(testCase,@()colormeasure.runTests(folder,'Groups',groups{1}),'measurement:TestGroups');
    verifyFalse(testCase,isfolder(folder));
end
end

function testPublicGroupFormsPreserveOutputProtection(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
colormeasuretest.writeText(fullfile(fixture.Folder,'previous.txt'),'retain this report');
for groups={{'pr','workflow'},["pr" "workflow"],'pr',{},[]}
    verifyError(testCase,@()colormeasure.runTests(fixture.Folder,'Groups',groups{1}), ...
        'measurement:TestOutputFolder');
end
end

function testGroupScopeNamesSelectedAndOmittedSuites(testCase)
for groups = {{'pr','workflow'},["pr" "workflow"]}
    scope=colormeasuretest.selectGroups(groups{1});
    verifyEqual(testCase,scope.selectedGroups,{'pr','workflow'});
    verifyEqual(testCase,scope.omittedGroups,{'cr','cs2000','colorimetry'});
    verifyTrue(testCase,scope.isPartialRun);
    verifyEqual(testCase,sort([scope.selectedGroups scope.omittedGroups]), ...
        sort(scope.availableGroups));
end
single=colormeasuretest.selectGroups('cr');
verifyEqual(testCase,single.selectedGroups,{'cr'});
end

function testDefaultAndExplicitAllGroupsHaveTheSameScope(testCase)
all=colormeasuretest.selectGroups();
for groups = {{},[],fliplr(all.availableGroups)}
    scope=colormeasuretest.selectGroups(groups{1});
    verifyFalse(testCase,scope.isPartialRun);
    verifyEmpty(testCase,scope.omittedGroups);
    verifyEqual(testCase,sort(scope.selectedGroups),sort(all.availableGroups));
end
% Scope fields must survive the on-disk JSON representation, including [].
decoded=jsondecode(jsonencode(all));
verifyFalse(testCase,decoded.isPartialRun);verifyEmpty(testCase,decoded.omittedGroups);
verifyEqual(testCase,cellstr(string(decoded.selectedGroups(:)))',all.availableGroups);
end

function testRelativeReportFolderUsesMatlabCurrentFolder(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
colormeasuretest.writeText(fullfile(fixture.Folder,'previous.txt'),'retain this report');
expected=char(java.io.File(fixture.Folder).getCanonicalPath());
try
    colormeasure.runTests('.');
    assertFail(testCase,'A nonempty report folder must be refused.');
catch problem
    verifyEqual(testCase,problem.identifier,'measurement:TestOutputFolder');
    verifySubstring(testCase,problem.message,expected);
end
end

function testDirectWorkerInvocationCannotChangePath(testCase)
previousPath = path;
verifyError(testCase,@()colormeasuretest.runSoftwareChecks(tempname), ...
    'measurement:TestWorkerOnly');
verifyEqual(testCase,path,previousPath);
end

function testDetachedSuiteIncludesEveryGroupExactlyOnce(testCase)
[root,~] = layoutFixture(testCase);
[suite,layout] = colormeasuretest.softwareTestSuite(root);
verifyEqual(testCase,{layout.key},{'pr','cr','cs2000','colorimetry','workflow'});
verifyEqual(testCase,numel(suite),6);
verifyEqual(testCase,numel(unique({suite.Name})),numel(suite));
verifyEqual(testCase,[layout.testCount],[1 1 1 1 2]);
verifyEqual(testCase,[layout.originalComparisonCount],zeros(1,numel(layout)));
verifyTrue(testCase,any(contains({suite.Name},'testNestedShared')));
verifyFalse(testCase,any(contains({suite.Name},'Original')));
for index = 1:3
    verifyEqual(testCase,layout(index).originalComparison, ...
        'Not run: SchoolRoot was not supplied.');
end
end

function testPartialSchoolBaselineIncludesComparisonsInsteadOfSkipping(testCase)
[root,repository] = layoutFixture(testCase);
mkdir(fullfile(repository,'Convert'));
[suite,layout] = colormeasuretest.softwareTestSuite(root,repository);
verifyEqual(testCase,numel(suite),9);
verifyEqual(testCase,[layout.originalComparisonCount],[1 1 1 0 0]);
verifyEqual(testCase,numel(unique({suite.Name})),numel(suite));
end

function testSelectedGroupIncludesOnlyItsComparisons(testCase)
[root,repository] = layoutFixture(testCase);
[~,layout] = colormeasuretest.softwareTestSuite(root,repository,{'pr'});
verifyEqual(testCase,{layout.key},{'pr'});
verifyEqual(testCase,[layout.originalComparisonCount],1);
end

function testReorderedGroupsKeepTheirDiscoveryAndComparisonPolicies(testCase)
[root,repository]=layoutFixture(testCase);
groups={'cs2000','colorimetry','pr','workflow','cr'};
[scope,definitions]=colormeasuretest.selectGroups(groups);
verifyEqual(testCase,{definitions.key},groups);
verifyEqual(testCase,[definitions.supportsOriginalComparison], ...
    [true false true false true]);
verifyFalse(testCase,scope.isPartialRun);
[suite,layout]=colormeasuretest.softwareTestSuite(root,repository,groups);
verifyEqual(testCase,{layout.key},groups);
verifyEqual(testCase,[layout.originalComparisonCount],[1 0 1 0 1]);
expectedFolders={fullfile('drivers','cs2000'),'colorimetry', ...
    fullfile('drivers','pr'),'workflow',fullfile('drivers','cr')};
for index=1:numel(groups)
    folder=fullfile(root,'tests',expectedFolders{index});
    verifyEqual(testCase,layout(index).folder,folder);
    groupTests=suite(layout(index).firstTest:(layout(index).firstTest+layout(index).testCount-1));
    verifyTrue(testCase,all(strcmp({groupTests.BaseFolder},folder) | ...
        startsWith({groupTests.BaseFolder},[folder filesep])));
end
end

function testDetachedBundleDoesNotBorrowUnrelatedAncestorReferences(testCase)
[root,repository] = layoutFixture(testCase);
mkdir(fullfile(repository,'Convert'));
mkdir(fullfile(repository,'Devices','PR655'));
[~,layout] = colormeasuretest.softwareTestSuite(root);
verifyEqual(testCase,[layout.originalComparisonCount],zeros(1,numel(layout)));
end

function testEveryBundledGroupIsRequired(testCase)
groups = {fullfile('drivers','pr'),fullfile('drivers','cr'),fullfile('drivers','cs2000'), ...
    'colorimetry','workflow'};
[root,repository] = layoutFixture(testCase);
aside = fullfile(repository,'aside');
for index = 1:numel(groups)
    folder = fullfile(root,'tests',groups{index});
    movefile(folder,aside);
    verifyError(testCase,@()colormeasuretest.softwareTestSuite(root), ...
        'measurement:MissingTestSuite',groups{index});
    movefile(aside,folder);
end
verifyNotEmpty(testCase,colormeasuretest.softwareTestSuite(root),'every group back in place');
end

function testOriginalTestsCannotReplaceMissingNativeChecks(testCase)
[root,repository] = layoutFixture(testCase);
mkdir(fullfile(repository,'Convert'));
delete(fullfile(root,'tests','drivers','pr','testPRFixture.m'));
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root,repository),'measurement:EmptyTestSuite');
end

function testReferenceBaselineRequiresItsComparisonTests(testCase)
[root,repository] = layoutFixture(testCase);
mkdir(fullfile(repository,'Convert'));
rmdir(fullfile(root,'tests','drivers','cr','repository'),'s');
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root,repository),'measurement:MissingOriginalTests');
end

function testDuplicateNamesCannotBeCountedAsDifferentChecks(testCase)
[root,~] = layoutFixture(testCase);
writeFixture(fullfile(root,'tests','drivers','cr'),'testPRFixture');
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root),'measurement:DuplicateTests');
end

function testInvalidDiscoveryCannotSilentlyOmitAFile(testCase)
[root,~] = layoutFixture(testCase);
colormeasuretest.writeText(fullfile(root,'tests','workflow','testInvalidFixture.m'),sprintf([ ...
    'function tests = testInvalidFixture\n' ...
    'error(''Fixture:InvalidDiscovery'',''Deliberately invalid test suite.'');\n' ...
    'tests = functiontests(localfunctions);\nend\n' ...
    'function testCase(t)\nverifyTrue(t,true);\nend\n']));
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root),'Fixture:InvalidDiscovery');
end

function testEmptyFileCannotHideAmongRunnableTests(testCase)
% The last empty file shares its name with a runnable test in another folder.
folders = {fullfile('tests','drivers','pr'),fullfile('tests','workflow','nested'), ...
    fullfile('tests','workflow','nested')};
names = {'testEmptyFixture','testEmptyFixture','testSharedFixture'};
for index = 1:numel(folders)
    [root,~] = layoutFixture(testCase);
    colormeasuretest.writeText(fullfile(root,folders{index},[names{index} '.m']),sprintf([ ...
        'function tests = %s\n' ...
        'tests = functiontests(localfunctions);\n' ...
        'tests = tests([]);\nend\n' ...
        'function testUnused(t)\nverifyTrue(t,true);\nend\n'],names{index}));
    identifier = '';
    try
        colormeasuretest.softwareTestSuite(root);
    catch problem
        identifier = problem.identifier;
    end
    % Releases may reject the empty file in testsuite itself or return an
    % empty array for the runner's explicit guard. Both must refuse the run.
    verifyTrue(testCase,ismember(identifier, ...
        {'MATLAB:unittest:TestSuite:NonTestFile','measurement:EmptyTestFile'}), ...
        ['Expected empty-file rejection; received: ' identifier]);
end
end

function testEmptyFailedIncompleteAndMissingResultsCannotPass(testCase)
passed = struct('Passed',true,'Failed',false,'Incomplete',false,'Duration',0.1);
failed = struct('Passed',false,'Failed',true,'Incomplete',false,'Duration',0.2);
incomplete = struct('Passed',false,'Failed',false,'Incomplete',true,'Duration',0.3);
cases = {repmat(passed,0,1),[passed failed],[passed incomplete],passed};
expected = [0 2 2 2];
for index = 1:numel(cases)
    outcome = colormeasuretest.summarizeResults(cases{index},expected(index));
    verifyFalse(testCase,outcome.softwarePassed);
end
outcome = colormeasuretest.summarizeResults([passed passed],2);
verifyTrue(testCase,outcome.softwarePassed);
verifyEqual(testCase,outcome.testDurationSeconds,0.2,'AbsTol',eps);
end

function testInvalidWorkerCountsRefuseBeforeCreatingReports(testCase)
for workers = {0,-1,1.5,17,Inf,NaN,[2 3],'2'}
    folder = tempname;
    verifyError(testCase,@()colormeasure.runTests(folder,'Workers',workers{1}), ...
        'measurement:TestWorkers');
    verifyFalse(testCase,isfolder(folder));
end
end

function testCancellationRefusesInvalidOrAlreadyRequestedLaunch(testCase)
for value = {42,["a" "b"],string(missing)}
    folder = tempname;
    verifyError(testCase,@()colormeasure.runTests(folder,'CancellationFile',value{1}), ...
        'measurement:TestCancellationFile');
    verifyFalse(testCase,isfolder(folder));
end
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
marker = fullfile(fixture.Folder,'cancel.request');
colormeasuretest.writeText(marker,'retained external request');
folder = tempname;
verifyError(testCase,@()colormeasure.runTests(folder,'CancellationFile',marker), ...
    'measurement:TestCancelled');
verifyFalse(testCase,isfolder(folder));
verifyEqual(testCase,fileread(marker),'retained external request');
end

function testCancellationPreservesCompletedAndIncompleteResultsAndUiTeardown(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
marker = fullfile(fixture.Folder,'cancel.request');
key = 'ColorMeasureCancellationFixture';
testCase.addTeardown(@()rmappdata(groot,key));
file = fullfile(fixture.Folder,'testCancellationFixture.m');
colormeasuretest.writeText(file,sprintf([ ...
    'function tests=testCancellationFixture\ntests=functiontests(localfunctions);\nend\n' ...
    'function testA(t)\nrecord();t.verifyTrue(true);\nend\n' ...
    'function testB(t)\nrecord();state=getappdata(groot,''%s'');\n' ...
    'f=uifigure(''Visible'',''off'',''CloseRequestFcn'',@(~,~)[]);\n' ...
    't.addTeardown(@()delete(f));\n' ...
    'if strcmp(state.mode,''during''),colormeasuretest.writeText(state.marker,''stop'');end\n' ...
    't.verifyTrue(isvalid(f));\nend\n' ...
    'function testC(t)\nrecord();t.verifyTrue(true);\nend\n' ...
    'function record()\nstate=getappdata(groot,''%s'');state.calls=state.calls+1;\n' ...
    'setappdata(groot,''%s'',state);\nend\n'],key,key,key));
suite = matlab.unittest.TestSuite.fromFile(file);
before = findall(groot,'Type','figure');
for mode = {'normal','before','during'}
    if isfile(marker), delete(marker); end
    setappdata(groot,key,struct('mode',mode{1},'marker',marker,'calls',0));
    if strcmp(mode{1},'before'), colormeasuretest.writeText(marker,'stop'); end
    plugin = colormeasuretest.CancellationPlugin(marker);
    runner = matlab.unittest.TestRunner.withNoPlugins;
    runner.addPlugin(plugin);
    if strcmp(mode{1},'normal')
        results = runner.run(suite);
        verifyTrue(testCase,all([results.Passed]));
        verifyEqual(testCase,getappdata(groot,key).calls,3);
    else
        verifyError(testCase,@()runner.run(suite),'measurement:TestCancelled');
        expected = 2*strcmp(mode{1},'during');
        verifyEqual(testCase,getappdata(groot,key).calls,expected);
        verifyEqual(testCase,numel(plugin.Results),3);
        verifyEqual(testCase,nnz([plugin.Results.Passed]),expected);
        summary = colormeasuretest.summarizeResults(plugin.Results,3);
        verifyEqual(testCase,summary.incomplete,3-expected);
        verifyFalse(testCase,summary.softwarePassed);
        colormeasuretest.writeResults(fixture.Folder,plugin.Results,summary);
        saved = load(fullfile(fixture.Folder,'test-results.mat'));
        verifyClass(testCase,saved.results,'matlab.unittest.TestResult');
        % MAT preserves public result data, not transient framework handles.
        for field = {'Name','Passed','Failed','Incomplete','Duration','Details'}
            stored = arrayfun(@(item)item.(field{1}),saved.results,'UniformOutput',false);
            original = arrayfun(@(item)item.(field{1}),plugin.Results,'UniformOutput',false);
            verifyEqual(testCase,stored,original,field{1});
        end
        verifyEqual(testCase,nnz(saved.resultsTable.Incomplete),3-expected);
    end
    verifyEqual(testCase,findall(groot,'Type','figure'),before);
end
end

function testCooperativeCleanupRequestsStopBeforeDestroyingWorkers(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
marker = fullfile(fixture.Folder,'cancel.request');
temporary = fullfile(fixture.Folder,'temporary'); mkdir(temporary);
process = struct('isAlive',@()~isfile(marker),'destroy',@refuseStop);
verifyEmpty(testCase,colormeasuretest.finishWorkers({process},{temporary},marker));
verifyTrue(testCase,isfile(marker));
verifyFalse(testCase,isfolder(temporary));
end

function testCooperativeLivenessFailureStillVisitsEveryWorker(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
marker = fullfile(fixture.Folder,'cancel.request');
folders = {fullfile(fixture.Folder,'unknown'),fullfile(fixture.Folder,'stopped')};
cellfun(@mkdir,folders);
secondAlive = true;
unknown = struct('isAlive',@refuseLiveness);
other = struct('isAlive',@isSecondAlive,'destroy',@stopSecond,'waitFor',@(varargin)true);
problems = verifyWarning(testCase,@()colormeasuretest.finishWorkers( ...
    {unknown,other},folders,marker),'measurement:TestWorkerCleanup');
verifyFalse(testCase,secondAlive);
verifyTrue(testCase,isfolder(folders{1}));
verifyFalse(testCase,isfolder(folders{2}));
verifyEqual(testCase,numel(problems),2);
    function alive = isSecondAlive()
        alive = secondAlive;
    end
    function stopSecond()
        secondAlive = false;
    end
end

function alive = refuseLiveness() %#ok<STOUT>
error('Fixture:WorkerLiveness','Simulated liveness refusal.');
end

function testWorkerSlicesCoverEverySuitePositionOnce(testCase)
for count = [0 1 7 1472]
    for workers = 1:5
        covered = [];
        for worker = 1:workers
            covered = [covered colormeasuretest.shardIndices(count,[worker workers])]; %#ok<AGROW>
        end
        verifyEqual(testCase,sort(covered),1:count);
    end
end
for shard = {[0 2],[3 2],[1 0],[1.5 2],1}
    verifyError(testCase,@()colormeasuretest.shardIndices(5,shard{1}),'measurement:TestShards');
end
end

function testMergedWorkersKeepSuiteOrderAndRequireEveryTestOnce(testCase)
[reports,results] = workerFixture({[1 3 5],[2 4]});
[report,merged] = colormeasuretest.mergeShards(reports,results);
verifyTrue(testCase,report.softwarePassed);
verifyEqual(testCase,{merged.Name},{'t1','t2','t3','t4','t5'});
verifyEqual(testCase,[report.testCount report.expectedTestCount report.passed],[5 5 5]);
verifyEqual(testCase,report.analyzerMessageCount,30);
verifyEqual(testCase,report.startedAtUTC,'2026-10-01T06:00:00.000Z');
verifyEqual(testCase,report.finishedAtUTC,'2026-10-01T06:05:00.000Z');
verifyEqual(testCase,report.shard.testIndices,1:5);

% A missing, repeated or failed test, a worker error or a different scope fails.
[reports,results] = workerFixture({[1 3 5],2});
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
verifySubstring(testCase,report.testError,'exactly once');
[reports,results] = workerFixture({[1 3 5],[2 4 5]});
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
[reports,results] = workerFixture({[1 3 5],[2 4]});
results{2}(1).Passed = false; results{2}(1).Failed = true;
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
[reports,results] = workerFixture({[1 3 5],[2 4]});
reports{2}.testError = 'Discovery failed.';
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
verifySubstring(testCase,report.testError,'Worker 2: Discovery failed.');
[reports,results] = workerFixture({[1 3 5],[2 4]});
reports{2}.selectedGroups = {'cs2000'};
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
verifySubstring(testCase,report.testError,'different test scope');

% Positions alone are not enough: a worker that discovered another order, or
% ran another test at an assigned position, fails even when every count holds.
[reports,results] = workerFixture({[1 3 5],[2 4]});
reports{2}.shard.suiteDigest = colormeasuretest.suiteDigest({'t2','t1','t3','t4','t5'});
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
verifySubstring(testCase,report.testError,'different test scope');
[reports,results] = workerFixture({[1 3 5],[2 4]});
results{2}(1).Name = 't1';
report = colormeasuretest.mergeShards(reports,results);
verifyFalse(testCase,report.softwarePassed);
verifySubstring(testCase,report.testError,'name the discovered tests');
[reports,results] = workerFixture({[1 3 5],[2 4]});
reports{2}.cancelled = true;
report = colormeasuretest.mergeShards(reports,results);
verifyTrue(testCase,report.cancelled);
verifyFalse(testCase,report.softwarePassed);
end

function testFailedWorkerStartRemovesOnlyItsTemporaryFolder(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
temporary = fullfile(fixture.Folder,'worker-temporary'); mkdir(temporary);
retained = fullfile(fixture.Folder,'matlab.log'); colormeasuretest.writeText(retained,'startup failed');
builder = workerBuilder('start');
failure = [];
try
    colormeasuretest.startWorkerProcess(builder,fixture.Folder,temporary);
catch failure
end
% The start error reaches the caller unchanged, like each setup error.
verifyNotEmpty(testCase,failure);
if ~isempty(failure)
    verifyEqual(testCase,failure.identifier,'Fixture:WorkerStart');
    verifyEqual(testCase,failure.message,'Simulated start failure.');
end
verifyFalse(testCase,isfolder(temporary));
verifyEqual(testCase,fileread(retained),'startup failed');
% A started worker keeps its folder; the launcher removes it after the run.
mkdir(temporary);
[builder,calls] = workerBuilder('');
verifyEqual(testCase,colormeasuretest.startWorkerProcess(builder,fixture.Folder,temporary),42);
verifyTrue(testCase,isfolder(temporary));
% The real setup ran: private temporary variables, then output to the log.
recorded = calls();
verifyEqual(testCase,recorded(1:3),{'TMPDIR','TMP','TEMP'});
verifyEqual(testCase,recorded(4:end), ...
    {'redirectErrorStream',['redirectOutput ' fullfile(fixture.Folder,'matlab.log')],'start'});
end

function testWorkerSetupFailureCleansUpBeforeAProcessStarts(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
retained = fullfile(fixture.Folder,'matlab.log'); colormeasuretest.writeText(retained,'retain diagnostics');
% Each real setup step must clean up and preserve its diagnostic unchanged.
steps = {'environmentLookup','environmentPut','redirectErrorStream','redirectOutput'};
messages = {'Simulated environment lookup failure.','Simulated environment failure.', ...
    'Simulated error redirection failure.','Simulated output redirection failure.'};
for k = 1:numel(steps)
    step = steps{k};
    temporary = fullfile(fixture.Folder,'worker-temporary'); mkdir(temporary);
    [builder,calls] = workerBuilder(step);
    failure = [];
    try
        colormeasuretest.startWorkerProcess(builder,fixture.Folder,temporary);
    catch failure
    end
    verifyNotEmpty(testCase,failure,step);
    if ~isempty(failure)
        verifyEqual(testCase,failure.identifier,'Fixture:WorkerSetup',step);
        verifyEqual(testCase,failure.message,messages{k},step);
    end
    verifyFalse(testCase,any(strcmp(calls(),'start')),step);
    verifyFalse(testCase,isfolder(temporary),step);
    verifyEqual(testCase,fileread(retained),'retain diagnostics',step);
end
end

function [builder,calls] = workerBuilder(failing)
% A stand-in for java.lang.ProcessBuilder that records the calls made on it
% and can fail at environment lookup, a temporary-variable write, either
% redirection call, or process start.
history = {};
environment = struct('put',@put);
builder = struct('environment',@environmentOf,'redirectErrorStream',@redirectErrorStream, ...
    'redirectOutput',@redirectOutput,'start',@start);
calls = @recorded;
    function value = recorded()
        value = history;
    end
    function value = environmentOf()
        if strcmp(failing,'environmentLookup')
            error('Fixture:WorkerSetup','Simulated environment lookup failure.');
        end
        value = environment;
    end
    function put(name,~)
        if strcmp(failing,'environmentPut')
            error('Fixture:WorkerSetup','Simulated environment failure.');
        end
        history{end+1} = name;
    end
    function redirectErrorStream(~)
        if strcmp(failing,'redirectErrorStream')
            error('Fixture:WorkerSetup','Simulated error redirection failure.');
        end
        history{end+1} = 'redirectErrorStream';
    end
    function redirectOutput(file)
        if strcmp(failing,'redirectOutput')
            error('Fixture:WorkerSetup','Simulated output redirection failure.');
        end
        history{end+1} = ['redirectOutput ' char(file.getPath())];
    end
    function process = start()
        history{end+1} = 'start';
        if strcmp(failing,'start')
            % A start that fails while producing its process, like ProcessBuilder.start.
            error('Fixture:WorkerStart','Simulated start failure.');
        end
        process = 42;
    end
end

function testCleanupFailureDoesNotSkipOtherWorkersOrDeleteLiveFiles(testCase)
fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
folders={fullfile(fixture.Folder,'running'),fullfile(fixture.Folder,'stopped'), ...
    fullfile(fixture.Folder,'forced'),fullfile(fixture.Folder,'unstoppable')};
cellfun(@mkdir,folders);
colormeasuretest.writeText(fullfile(folders{1},'live.txt'),'retain until stopped');
colormeasuretest.writeText(fullfile(folders{4},'live.txt'),'retain while running');
secondAlive=true;thirdAlive=true;forced=false;
failed=struct('isAlive',@()true,'destroy',@refuseStop);
other=struct('isAlive',@secondIsAlive,'destroy',@stopSecond, ...
    'waitFor',@(varargin)true);
stubborn=struct('isAlive',@thirdIsAlive,'destroy',@()[], ...
    'waitFor',@(varargin)false,'destroyForcibly',@forceThird);
unstoppable=struct('isAlive',@()true,'destroy',@()[],'waitFor',@(varargin)false, ...
    'destroyForcibly',@()[],'pid',@()4242);
problems=verifyWarning(testCase,@()colormeasuretest.finishWorkers( ...
    {failed,other,stubborn,unstoppable},folders),'measurement:TestWorkerCleanup');
verifyFalse(testCase,secondAlive);
verifyFalse(testCase,isfolder(folders{2}));
verifyFalse(testCase,thirdAlive);verifyTrue(testCase,forced);
verifyFalse(testCase,isfolder(folders{3}));
verifyEqual(testCase,fileread(fullfile(folders{1},'live.txt')),'retain until stopped');
verifyEqual(testCase,fileread(fullfile(folders{4},'live.txt')),'retain while running');
% Each report names what is left behind, so it can be stopped and removed.
verifyEqual(testCase,problems,{ ...
    ['Cannot stop worker 1; temporary files retained in ' folders{1} ': Simulated worker stop failure.'], ...
    ['Worker 4 (process 4242) is still running; temporary files retained in ' folders{4} '.']});

    function stopSecond()
        secondAlive=false;
    end
    function alive=secondIsAlive()
        alive=secondAlive;
    end
    function alive=thirdIsAlive()
        alive=thirdAlive;
    end
    function forceThird()
        forced=true;thirdAlive=false;
    end
end

function refuseStop()
error('Fixture:WorkerStop','Simulated worker stop failure.');
end

function testSuiteDigestIsSha256OfOrderedNames(testCase)
% Reference values: shasum -a 256 of the empty text, of "abc" and of t1..t5
% joined by newlines.
verifyEqual(testCase,colormeasuretest.suiteDigest({}), ...
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
verifyEqual(testCase,colormeasuretest.suiteDigest({'abc'}), ...
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
verifyEqual(testCase,colormeasuretest.suiteDigest(compose('t%d',1:5)), ...
    '7d0fbf428673318bc2268be09b44a45766f8b298f7788b6045c98c1da53db002');
verifyNotEqual(testCase,colormeasuretest.suiteDigest({'a','b'}), ...
    colormeasuretest.suiteDigest({'b','a'}));
end

function testDiscoveryCallsEachSuiteFactoryOnce(testCase)
[root,~] = layoutFixture(testCase);
key = 'ColorMeasureDiscoveryCalls';
setappdata(groot,key,0);
testCase.addTeardown(@() rmappdata(groot,key));
filename = fullfile(root,'tests','workflow','testSingleDiscoveryFixture.m');
colormeasuretest.writeText(filename,sprintf([ ...
    'function tests = testSingleDiscoveryFixture\n' ...
    'key = ''%s''; setappdata(groot,key,getappdata(groot,key)+1);\n' ...
    'tests = functiontests(localfunctions);\nend\n' ...
    'function testFixture(t)\nverifyTrue(t,true);\nend\n'],key));
suite = colormeasuretest.softwareTestSuite(root,'',{'workflow'});
verifyEqual(testCase,getappdata(groot,key),1);
verifyTrue(testCase,any(strcmp({suite.Name},'testSingleDiscoveryFixture/testFixture')));
end

function testDiscoveryKeepsParameterizedClassesAndSuffixNames(testCase)
[root,~] = layoutFixture(testCase);
folder = fullfile(root,'tests','workflow');
writeFixture(folder,'SuffixTest');
colormeasuretest.writeText(fullfile(folder,'testParameterizedFixture.m'),sprintf([ ...
    'classdef testParameterizedFixture < matlab.unittest.TestCase\n' ...
    'properties (ClassSetupParameter)\nmode = {1,2};\nend\n' ...
    'methods (TestClassSetup)\nfunction setup(t,mode)\nt.assertGreaterThan(mode,0);\nend\nend\n' ...
    'methods (Test)\nfunction testFixture(t)\nt.verifyTrue(true);\nend\nend\nend\n']));
suite = colormeasuretest.softwareTestSuite(root,'',{'workflow'});
verifyEqual(testCase,nnz(startsWith({suite.Name},'testParameterizedFixture[')),2);
verifyTrue(testCase,any(strcmp({suite.Name},'SuffixTest/testFixture')));
end

function testDiscoveryKeepsNamespacedTests(testCase)
[root,~] = layoutFixture(testCase);
writeFixture(fullfile(root,'tests','workflow','nested','+fixture'),'testNamespaceFixture');
suite = colormeasuretest.softwareTestSuite(root,'',{'workflow'});
verifyTrue(testCase,any(strcmp({suite.Name},'fixture.testNamespaceFixture/testFixture')));
end

function testAnalyzerTextPreservesReturnedDiagnosticDetails(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
filename = fullfile(fixture.Folder,'analyzerFixture.m');
colormeasuretest.writeText(filename,sprintf('function y = analyzerFixture\nunused = 1;\ny = 2;\nend\n'));
messages = checkcode(filename,'-id');
verifyNotEmpty(testCase,messages);
text = colormeasuretest.analyzerText(messages);
for item = messages(:)'
    verifySubstring(testCase,text,item.id);
    verifySubstring(testCase,text,item.message);
    verifySubstring(testCase,text,['L' mat2str(item.line)]);
    verifySubstring(testCase,text,['C' mat2str(item.column)]);
end
verifyEqual(testCase,colormeasuretest.analyzerText(messages([])),'');
% Some diagnostics span several lines/column ranges; none may be truncated.
messages = struct('line',[2 4],'column',[1 3;2 8], ...
    'id','TEST','message',sprintf('First line\nSecond line'));
text = colormeasuretest.analyzerText(messages);
verifySubstring(testCase,text,'L[2 4]');
verifySubstring(testCase,text,'C[1 3;2 8]');
verifySubstring(testCase,text,messages.message);
end

function testExplicitSchoolRootMustBeOneExistingFolder(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
for value = {42,["a" "b"],string(missing),fullfile(folder.Folder,'missing')}
    verifyError(testCase,@()colormeasure.runTests(tempname,'SchoolRoot',value{1}), ...
        'measurement:SchoolRoot');
end
[root,~] = layoutFixture(testCase);
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root,'',{'pr','pr'}),'measurement:TestGroups');
verifyError(testCase,@()colormeasuretest.softwareTestSuite(root,'',{'unknown'}),'measurement:TestGroups');
end

function [reports,results] = workerFixture(assignments)
% Synthetic worker reports for a five-test suite split as given.
count = numel(assignments);
suites = struct('key','workflow','name','Shared workflow and UI','folder','tests', ...
    'firstTest',1,'testCount',5,'originalComparison','Not applicable.', ...
    'originalComparisonCount',0);
reports = cell(1,count); results = cell(1,count);
for worker = 1:count
    ran = assignments{worker};
    rows = struct('Name',{},'Passed',{},'Failed',{},'Incomplete',{},'Duration',{});
    for index = ran
        rows(end+1) = struct('Name',sprintf('t%d',index),'Passed',true,'Failed',false, ...
            'Incomplete',false,'Duration',0.1); %#ok<AGROW>
    end
    results{worker} = rows;
    reports{worker} = struct('selectedGroups',{{'workflow'}},'suites',suites, ...
        'shard',struct('index',worker,'count',count,'suiteTestCount',5, ...
        'suiteDigest',colormeasuretest.suiteDigest(compose('t%d',1:5)),'testIndices',ran), ...
        'testError','','analyzerError','','analyzerMessageCount',30*(worker==1), ...
        'startedAtUTC',sprintf('2026-10-01T06:0%d:00.000Z',worker-1), ...
        'finishedAtUTC',sprintf('2026-10-01T06:0%d:00.000Z',worker+3), ...
        'testCount',numel(ran),'expectedTestCount',numel(ran),'passed',numel(ran), ...
        'failed',0,'incomplete',0,'testDurationSeconds',0.1*numel(ran),'softwarePassed',true, ...
        'cancelled',false);
end
end

function [root,repository] = layoutFixture(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
repository = fixture.Folder;
root = fullfile(repository,'project');
families = {'pr','cr','cs2000'};
names = {'PR','CR','CS'};
for index = 1:numel(families)
    folder = fullfile(root,'tests','drivers',families{index});
    writeFixture(folder,['test' names{index} 'Fixture']);
    writeFixture(fullfile(folder,'repository'),['test' names{index} 'OriginalFixture']);
end
writeFixture(fullfile(root,'tests','colorimetry'),'testColourFixture');
writeFixture(fullfile(root,'tests','workflow'),'testSharedFixture');
writeFixture(fullfile(root,'tests','workflow','nested'),'testNestedShared');
end

function writeFixture(folder,name)
if ~isfolder(folder), mkdir(folder); end
colormeasuretest.writeText(fullfile(folder,[name '.m']),sprintf([ ...
    'function tests = %s\n' ...
    'tests = functiontests(localfunctions);\nend\n' ...
    'function testFixture(t)\nverifyTrue(t,true);\nend\n'],name));
end

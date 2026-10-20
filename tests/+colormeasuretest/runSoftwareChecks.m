function runSoftwareChecks(outputFolder)
% RUNSOFTWARECHECKS Internal isolated worker; launch with colormeasure.runTests.
% Fernando Voltolini de Azambuja, 2026.
if ~batchStartupOptionUsed || ~strcmp(getenv('COLORMEASURE_TEST_OUTPUT'),outputFolder)
    error('measurement:TestWorkerOnly','Use colormeasure.runTests to launch an isolated worker.');
end
assert(strcmp(pwd,outputFolder) && ...
    strcmp(which('startup'),fullfile(outputFolder,'startup.m')) && ...
    strcmp(which('finish'),fullfile(outputFolder,'finish.m')), ...
    'measurement:TestStartupIsolation','The worker must use its own startup and finish hooks.');
root = colormeasuretest.projectRoot();
assert(strcmp(root,getenv('COLORMEASURE_TEST_ROOT')), ...
    'measurement:TestInstallation','The test worker resolved a different installation.');
guardFolder = fullfile(outputFolder,'hardware-guards');
addpath(fullfile(root,'src'),fullfile(root,'tests'));
addpath(guardFolder,'-begin');
assertGuards(guardFolder);
set(groot,'DefaultFigureVisible','off');
report = struct('kind','Software and synthetic checks; no physical instrument testing', ...
    'outputFolder',outputFolder,'measurementFolder',root, ...
    'schoolRoot',getenv('COLORMEASURE_TEST_SCHOOL_ROOT'),'startedAtUTC',utcNow(), ...
    'finishedAtUTC','','matlabVersion',version,'matlabRelease',version('-release'), ...
    'platform',computer,'revision','unavailable','gitStatus','unavailable', ...
    'testCount',0,'expectedTestCount',0,'passed',0,'failed',0,'incomplete',0, ...
    'testDurationSeconds',0,'wallDurationSeconds',0,'softwarePassed',false, ...
    'availableGroups',{{}},'selectedGroups',{{}},'omittedGroups',{{}},'isPartialRun',[], ...
    'suites',struct([]),'analyzedFileCount',0,'analyzerMessageCount',0, ...
    'testError','','analyzerError','','cancelled',false);
cancellationFile = getenv('COLORMEASURE_TEST_CANCELLATION');
% A concurrent run gives each worker every n-th test; one worker runs all.
shard = workerShard(getenv('COLORMEASURE_TEST_SHARD'));
report.shard = struct('index',shard(1),'count',shard(2),'suiteTestCount',0, ...
    'suiteDigest','','testIndices',zeros(1,0));
[report.revision,report.gitStatus] = gitState(root,outputFolder);
started = tic;
results = matlab.unittest.TestResult.empty;
colormeasuretest.writeResults(outputFolder,results,report);
try
    groups = jsondecode(getenv('COLORMEASURE_TEST_GROUPS'));
    selection = colormeasuretest.selectGroups(groups);
    for name = fieldnames(selection)'
        report.(name{1}) = selection.(name{1});
    end
    % Retain requested scope even when discovery fails before running a test.
    colormeasuretest.writeResults(outputFolder,results,report);
    [suite,report.suites] = colormeasuretest.softwareTestSuite( ...
        root,report.schoolRoot,selection.selectedGroups);
    assigned = colormeasuretest.shardIndices(numel(suite),shard);
    report.shard.suiteTestCount = numel(suite);
    % Workers discover independently; the merge requires one discovered order.
    report.shard.suiteDigest = colormeasuretest.suiteDigest({suite.Name});
    report.expectedTestCount = numel(assigned);
    for index = 1:numel(report.suites)
        group = report.suites(index);
        selected = group.firstTest:(group.firstTest+group.testCount-1);
        selected = selected(ismember(selected,assigned));
        fprintf('\n%s: %d of %d tests. %s\n',group.name,numel(selected),group.testCount, ...
            group.originalComparison);
        if isempty(selected), continue; end
        assertGuards(guardFolder);
        if isfile(cancellationFile)
            error('measurement:TestCancelled','Checks were cancelled before the next suite.');
        end
        runner = matlab.unittest.TestRunner.withDefaultPlugins;
        cancellation = colormeasuretest.CancellationPlugin(cancellationFile);
        runner.addPlugin(cancellation);
        try
            next = runner.run(suite(selected));
        catch exception
            next = cancellation.Results;
            results = [results(:); next(:)];
            report.shard.testIndices = [report.shard.testIndices selected(1:numel(next))];
            rethrow(exception);
        end
        results = [results(:); next(:)];
        report.shard.testIndices = [report.shard.testIndices selected];
        assertGuards(guardFolder);
        report = updateCounts(report,results);
        colormeasuretest.writeResults(outputFolder,results,report);
    end
catch exception
    report.testError = getReport(exception,'extended','hyperlinks','off');
    fprintf(2,'%s\n',report.testError);
end

% Analyzer findings are retained as advice, never hidden by a warning-count gate.
% In a concurrent run only worker 1 analyzes; the merged report uses its result.
analyzer = struct('file',{},'messages',{});
rawAnalyzer = '';
report.cancelled = isfile(cancellationFile);
if shard(1) == 1 && ~report.cancelled
    try
        sources = dir(fullfile(root,'**','*.m'));
        assert(~isempty(sources),'measurement:MissingSources','No MATLAB sources found to analyze.');
        for index = 1:numel(sources)
            if isfile(cancellationFile), break; end
            filename = fullfile(sources(index).folder,sources(index).name);
            messages = checkcode(filename,'-id');
            raw = colormeasuretest.analyzerText(messages);
            relative = filename(numel(root)+2:end);
            analyzer(end+1) = struct('file',relative,'messages',messages); %#ok<AGROW>
            rawAnalyzer = sprintf('%s%s\n%s\n',rawAnalyzer,relative,raw);
            report.analyzerMessageCount = report.analyzerMessageCount + numel(messages);
        end
        report.analyzedFileCount = numel(analyzer);
    catch exception
        report.analyzerError = getReport(exception,'extended','hyperlinks','off');
        fprintf(2,'%s\n',report.analyzerError);
    end
end
colormeasuretest.writeText(fullfile(outputFolder,'checkcode.txt'),rawAnalyzer);
colormeasuretest.writeText(fullfile(outputFolder,'checkcode.json'),jsonencode(analyzer));
save(fullfile(outputFolder,'checkcode.mat'),'analyzer','-v7');
report = updateCounts(report,results);
report.cancelled = isfile(cancellationFile);
outcome = colormeasuretest.summarizeResults(results,report.expectedTestCount);
report.softwarePassed = outcome.softwarePassed ...
    && isempty(report.testError) && isempty(report.analyzerError) && ~report.cancelled;
report.finishedAtUTC = utcNow();
report.wallDurationSeconds = toc(started);
colormeasuretest.writeResults(outputFolder,results,report);
fprintf('\n%d/%d tests: %d passed, %d failed, %d incomplete.\n', ...
    report.testCount,report.expectedTestCount,report.passed,report.failed,report.incomplete);
fprintf('Code Analyzer: %d messages in %d files.\n', ...
    report.analyzerMessageCount,report.analyzedFileCount);
if report.cancelled
    % Only this isolated worker owns these resources. Framework teardown has
    % already unwound; delete bypasses test-installed close callbacks.
    timers = timerfindall;
    if ~isempty(timers), stop(timers); delete(timers); end
    delete(findall(groot,'Type','figure'));
    drawnow;
    exit(143);
end
if ~report.softwarePassed
    error('measurement:SoftwareChecksFailed','Checks failed or were incomplete. See %s',outputFolder);
end
end

function assertGuards(folder)
for name = colormeasuretest.serialGuardNames()
    assert(strcmp(which(name{1}),fullfile(folder,[name{1} '.m'])), ...
        'measurement:MissingHardwareGuard','Serial guard is missing or shadowed: %s',name{1});
end
end

function report = updateCounts(report,results)
summary = colormeasuretest.summarizeResults(results,report.expectedTestCount);
for name = {'testCount','passed','failed','incomplete','testDurationSeconds'}
    report.(name{1}) = summary.(name{1});
end
end

function shard = workerShard(value)
% "k/n" from the launcher; absent means the only worker.
if isempty(value), shard = [1 1]; return; end
shard = sscanf(value,'%d/%d').';
colormeasuretest.shardIndices(0,shard);
end

function value = utcNow()
value = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end


function [revision,status] = gitState(root,folder)
revision = 'unavailable (ZIP download or Git unavailable)'; status = 'unavailable';
try
    % A copied bundle can sit below an unrelated checkout. Verify tracking first.
    gitOutput(root,{'ls-files','--error-unmatch','--', ...
        fullfile(root,'src','+colormeasure','+session','Session.m')},folder);
    revision = gitOutput(root,{'rev-parse','HEAD'},folder);
    status = gitOutput(root,{'status','--short'},folder);
catch
    % Numerical and protocol checks remain usable without a Git installation.
end
end

function value = gitOutput(root,options,folder)
processArguments = java.util.ArrayList;
for word = [{'git','-C',root},options], processArguments.add(word{1}); end
builder = java.lang.ProcessBuilder(processArguments);
builder.redirectErrorStream(true);
capture = [tempname(folder) '.txt'];
builder.redirectOutput(java.io.File(capture));
process = builder.start();
if ~process.waitFor(10,java.util.concurrent.TimeUnit.SECONDS)
    process.destroyForcibly();
    error('measurement:TestGitMetadata','Git metadata query timed out.');
end
status = process.exitValue();
value = strtrim(fileread(capture));
delete(capture);
if status ~= 0, error('measurement:TestGitMetadata','%s',value); end
end

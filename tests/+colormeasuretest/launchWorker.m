function report = launchWorker(outputFolder, schoolRoot, groups, workers, cancellationFile)
%LAUNCHWORKER Common isolated execution for public and family test runners.
% Exact selected groups, serial guards and new/empty report directories are
% shared across all entry points. Failed or incomplete results refuse success.
% With several workers, each runs every n-th test in its own isolated folder
% (hooks, guards and temporary folder); the merged report keeps suite order.
narginchk(3,5); nargoutchk(0,1);
if nargin < 4, workers = 1; end
if nargin < 5, cancellationFile = ''; end
if ~(ischar(cancellationFile) && (isrow(cancellationFile) || isempty(cancellationFile))) && ...
        ~(isstring(cancellationFile) && isscalar(cancellationFile) && ~ismissing(cancellationFile))
    error('measurement:TestCancellationFile','Choose one cancellation file path or an empty value.');
end
cancellationFile = char(cancellationFile);
if ~isempty(cancellationFile)
    cancellationPath = java.io.File(cancellationFile);
    cancellationFile = char(cancellationPath.getCanonicalPath());
    if isfile(cancellationFile)
        error('measurement:TestCancelled','Checks were cancelled before workers started.');
    end
end
if ~(isnumeric(workers) && isscalar(workers) && isreal(workers) && ...
        workers == fix(workers) && workers >= 1 && workers <= 16)
    error('measurement:TestWorkers','Choose a whole number of workers from 1 to 16.');
end
workers = double(workers);
if ~(ischar(outputFolder) && isrow(outputFolder)) && ...
        ~(isstring(outputFolder) && isscalar(outputFolder) && ~ismissing(outputFolder))
    error('measurement:TestOutputFolder','Choose one nonempty report folder.');
end
if strlength(string(outputFolder)) == 0
    error('measurement:TestOutputFolder','Choose one nonempty report folder.');
end
if ~usejava('jvm')
    error('measurement:TestRunnerJava','Software checks require MATLAB with its JVM enabled.');
end
outputPath = java.io.File(char(outputFolder));
if ~outputPath.isAbsolute()
    outputPath = java.io.File(fullfile(pwd,char(outputFolder)));
end
outputFolder = char(outputPath.getCanonicalPath());
if isfolder(outputFolder)
    entries = dir(outputFolder);
    if any(~ismember({entries.name},{'.','..'}))
        error('measurement:TestOutputFolder','Report folder must be empty: %s',outputFolder);
    end
else
    [created,message] = mkdir(outputFolder);
    if ~created, error('measurement:TestOutputFolder','%s',message); end
end

root = colormeasuretest.projectRoot();
workerCancellation = fullfile(outputFolder,'cancel.request');
folders = {outputFolder};
if workers > 1
    folders = arrayfun(@(k)fullfile(outputFolder,sprintf('worker-%d',k)),1:workers, ...
        'UniformOutput',false);
end
if workers == 1
    fprintf('Running selected software checks in a separate MATLAB process.\n');
else
    fprintf('Running selected software checks in %d separate MATLAB processes.\n',workers);
end
fprintf('Progress and reports: %s\n',outputFolder);
processes = cell(1,workers);
temporaries = cell(1,workers);
try
    for k = 1:workers
        [processes{k},temporaries{k}] = startWorker(folders{k},root,schoolRoot,groups,[k workers],workerCancellation);
    end
catch exception
    colormeasuretest.finishWorkers(processes,temporaries,workerCancellation);
    rethrow(exception);
end
% Stop any worker still running, then remove its temporary folder. A worker
% whose stop cannot be confirmed keeps its folder; the warning names both.
childCleanup = onCleanup(@()colormeasuretest.finishWorkers(processes,temporaries,workerCancellation));
started = tic;
cancelledAt = [];
while any(cellfun(@(process)process.isAlive(),processes))
    if isempty(cancelledAt) && ~isempty(cancellationFile) && isfile(cancellationFile)
        colormeasuretest.writeText(workerCancellation,'Finish the current test and stop.');
        cancelledAt = tic;
    end
    if ~isempty(cancelledAt) && toc(cancelledAt) > 30
        error('measurement:TestCancelled','Cancelled workers did not finish within 30 seconds. See %s',outputFolder);
    end
    % Use a finite limit for the whole run, including slower machines.
    if toc(started) > 60*60
        error('measurement:TestTimeout','Checks exceeded 60 minutes. See %s',outputFolder);
    end
    pause(0.25);
end
statuses = cellfun(@(process)process.exitValue(),processes);
reports = cell(1,workers);
for k = 1:workers
    reportFile = fullfile(folders{k},'report.json');
    if ~isfile(reportFile)
        error('measurement:SoftwareChecksFailed', ...
            'Worker exited with code %d before writing its report. See %s', ...
            statuses(k),fullfile(folders{k},'matlab.log'));
    end
    reports{k} = jsondecode(fileread(reportFile));
end
if workers == 1
    report = reports{1};
else
    report = mergeWorkers(outputFolder,folders,reports,statuses,toc(started));
end
if (~isempty(cancellationFile) && isfile(cancellationFile)) || report.cancelled
    error('measurement:TestCancelled','Checks were cancelled. See %s',outputFolder);
end
if any(statuses ~= 0) || ~report.softwarePassed
    error('measurement:SoftwareChecksFailed', ...
        'Checks failed or were incomplete (MATLAB exit %s). See %s', ...
        strjoin(compose('%d',statuses),', '),outputFolder);
end
fprintf('%d tests passed; %d Code Analyzer messages.\n', ...
    report.testCount,report.analyzerMessageCount);
for index = 1:numel(report.suites)
    fprintf('%s: %s\n',report.suites(index).name,report.suites(index).originalComparison);
end
end

function [process,temporary] = startWorker(folder,root,schoolRoot,groups,shard,cancellationFile)
if ~isfolder(folder)
    [created,message] = mkdir(folder);
    if ~created, error('measurement:TestOutputFolder','%s',message); end
end
% These hooks shadow personal startup/finish scripts before the worker starts.
for name = {'startup','finish'}
    colormeasuretest.writeText(fullfile(folder,[name{1} '.m']), ...
        sprintf('%% Isolated software checks: intentionally empty %s hook.\n',name{1}));
end
guardFolder = fullfile(folder,'hardware-guards');
mkdir(guardFolder);
for name = colormeasuretest.serialGuardNames()
    colormeasuretest.writeText(fullfile(guardFolder,[name{1} '.m']),sprintf([ ...
        'function varargout = %s(varargin)\n' ...
        'error(''measurement:HardwareForbidden'',''Software checks cannot call %s.'');\nend\n'], ...
        name{1},name{1}));
end
executable = fullfile(matlabroot,'bin','matlab');
if ispc, executable = [executable '.exe']; end
processArguments = java.util.ArrayList;
processArguments.add(executable);
if ispc, processArguments.add('-wait'); end
processArguments.add('-noFigureWindows');
processArguments.add('-batch');
processArguments.add(['restoredefaultpath; ' ...
    'addpath(fullfile(getenv(''COLORMEASURE_TEST_ROOT''),''src'')); ' ...
    'addpath(fullfile(getenv(''COLORMEASURE_TEST_ROOT''),''tests'')); ' ...
    'addpath(fullfile(getenv(''COLORMEASURE_TEST_OUTPUT''),''hardware-guards'')); ' ...
    'colormeasuretest.runSoftwareChecks(getenv(''COLORMEASURE_TEST_OUTPUT''));']);
builder = java.lang.ProcessBuilder(processArguments);
builder.directory(java.io.File(folder));
environment = builder.environment();
environment.put('COLORMEASURE_TEST_ROOT',root);
environment.put('COLORMEASURE_TEST_OUTPUT',folder);
environment.put('COLORMEASURE_TEST_SCHOOL_ROOT',schoolRoot);
environment.put('COLORMEASURE_TEST_GROUPS',jsonencode(groups));
environment.put('COLORMEASURE_TEST_SHARD',sprintf('%d/%d',shard));
environment.put('COLORMEASURE_TEST_CANCELLATION',cancellationFile);
environment.put('MATLABPATH',guardFolder);
temporary = '';
if shard(2) > 1
    % Concurrent workers must not share temporary files, such as demo
    % folders named by the current second. MATLAB refuses to start when
    % TEMPDIR is long, so use a short folder outside the report.
    base = tempdir;
    if isfolder('/tmp'), base = '/tmp'; end
    temporary = fullfile(base,sprintf('cmw-%s-%d', ...
        extractBefore(char(java.util.UUID.randomUUID()),9),shard(1)));
    [created,message] = mkdir(temporary);
    if ~created, error('measurement:TestOutputFolder','%s',message); end
end
% Protect every setup step after the temporary folder is created. On failure,
% the caller never receives the folder and cannot clean it up itself.
process = colormeasuretest.startWorkerProcess(builder,folder,temporary);
end

function report = mergeWorkers(outputFolder,folders,reports,statuses,seconds)
shardResults = cell(size(reports));
for k = 1:numel(folders)
    loaded = load(fullfile(folders{k},'test-results.mat'),'results');
    shardResults{k} = loaded.results;
end
[report,results] = colormeasuretest.mergeShards(reports,shardResults);
report.outputFolder = outputFolder;
report.wallDurationSeconds = seconds;
report.workerFolders = folders;
report.workerExitCodes = statuses;
colormeasuretest.writeResults(outputFolder,results,report);
for name = {'checkcode.txt','checkcode.json','checkcode.mat'}
    copyfile(fullfile(folders{1},name{1}),fullfile(outputFolder,name{1}));
end
combined = '';
for k = 1:numel(folders)
    combined = sprintf('%s===== Worker %d of %d (exit %d): %s =====\n%s\n',combined,k, ...
        numel(folders),statuses(k),folders{k},fileread(fullfile(folders{k},'matlab.log')));
end
colormeasuretest.writeText(fullfile(outputFolder,'matlab.log'),combined);
end

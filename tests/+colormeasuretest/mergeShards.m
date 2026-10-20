function [report,results] = mergeShards(reports,shardResults)
%MERGESHARDS Combine concurrent worker reports into one report in suite order.
% Every worker must report the same discovered scope and test order, and
% together they must run each discovered test exactly once, by name as well as
% by position; otherwise the merged run fails.
% Analyzer findings come from worker 1, the only worker that runs it.
% In the merged report, shard.index 0 marks a combination of all workers.
% Fernando Voltolini de Azambuja, 2026.
assert(iscell(reports) && iscell(shardResults) && ~isempty(reports) && ...
    numel(reports) == numel(shardResults), ...
    'measurement:TestShards','Each worker needs one report and one result list.');
count = numel(reports);
report = reports{1};
total = report.shard.suiteTestCount;
digest = report.shard.suiteDigest;
problems = {};
indices = zeros(1,0);
results = shardResults{1}([]);
for worker = 1:count
    shard = reports{worker};
    sameScope = isequal(shard.shard.index,worker) && isequal(shard.shard.count,count) && ...
        isequal(shard.shard.suiteTestCount,total) && ...
        isequal(shard.shard.suiteDigest,digest) && ...
        isequal(shard.selectedGroups,report.selectedGroups) && ...
        isequaln(shard.suites,report.suites);
    if ~sameScope
        problems{end+1} = sprintf('Worker %d reported a different test scope.',worker); %#ok<AGROW>
    end
    if ~isempty(shard.testError)
        problems{end+1} = sprintf('Worker %d: %s',worker,shard.testError); %#ok<AGROW>
    end
    ran = reshape(shard.shard.testIndices,1,[]);
    if numel(ran) ~= numel(shardResults{worker})
        problems{end+1} = sprintf('Worker %d results do not match its test positions.',worker); %#ok<AGROW>
        ran = ran(1:min(end,numel(shardResults{worker})));
    end
    indices = [indices ran]; %#ok<AGROW>
    results = [results(:); reshape(shardResults{worker}(1:numel(ran)),[],1)];
end
[indices,order] = sort(indices);
results = results(order);
if ~isequal(indices,1:total)
    problems{end+1} = 'Workers did not run every discovered test exactly once.';
elseif ~strcmp(colormeasuretest.suiteDigest({results.Name}),digest)
    problems{end+1} = 'Worker results do not name the discovered tests in suite order.';
end
summary = colormeasuretest.summarizeResults(results,total);
for name = {'testCount','passed','failed','incomplete','testDurationSeconds'}
    report.(name{1}) = summary.(name{1});
end
% ISO-8601 UTC stamps of equal precision sort chronologically as text.
starts = sort(cellfun(@(item)string(item.startedAtUTC),reports));
finishes = sort(cellfun(@(item)string(item.finishedAtUTC),reports));
report.startedAtUTC = char(starts(1));
report.finishedAtUTC = '';
if all(strlength(finishes) > 0), report.finishedAtUTC = char(finishes(end)); end
report.expectedTestCount = total;
report.shard = struct('index',0,'count',count,'suiteTestCount',total, ...
    'suiteDigest',digest,'testIndices',indices);
report.testError = strjoin(problems,newline);
report.cancelled = any(cellfun(@(item)item.cancelled,reports));
report.softwarePassed = summary.softwarePassed && isempty(report.testError) && ...
    isempty(report.analyzerError) && ~report.cancelled;
end

function writeResults(folder,results,report)
%WRITERESULTS Write a worker's or the merged run's results and report files.
% Fernando Voltolini de Azambuja, 2026.
% The native TestResult objects remain unchanged in MAT. An allocated case
% with neither a pass nor failure has not completed, even when MATLAB's raw
% Incomplete flag has not yet been finalized during cancellation unwind.
incomplete = [results.Incomplete] | ~([results.Passed] | [results.Failed]);
resultsTable = table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    incomplete',[results.Duration]', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','DurationSeconds'});
save(fullfile(folder,'test-results.mat'),'results','resultsTable','-v7');
writetable(resultsTable,fullfile(folder,'test-results.csv'));
colormeasuretest.writeText(fullfile(folder,'report.json'),jsonencode(report));
save(fullfile(folder,'report.mat'),'report','-v7');
end

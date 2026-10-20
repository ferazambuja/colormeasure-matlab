function report = runTests(outputFolder, varargin)
%RUNTESTS Run instrument, colorimetry, session and UI software checks in isolation.
%   colormeasure.runTests() writes reports to a new temporary folder.
%   colormeasure.runTests(folder) requires a new or empty report folder.
%   colormeasure.runTests(folder,'SchoolRoot',schoolRoot) also executes the
%   original-driver comparisons against the explicitly selected school checkout.
%   colormeasure.runTests(folder,'Groups',{'pr','workflow'}) runs selected
%   suites. Choices: pr, cr, cs2000, colorimetry, workflow.
%   Omitted or empty Groups runs all suites, with the same isolation/guards.
%   colormeasure.runTests(folder,'Workers',3) runs the tests in three
%   concurrent isolated MATLAB processes and merges one report. Default 1.
%   'CancellationFile' names a read-only stop request. When that file exists,
%   workers finish the current test, retain partial results and close their UI.
%   Tests use synthetic transports. Physical serial access is blocked.
if nargin == 0, outputFolder = tempname; end
root = colormeasure.root();
oldPath = path; cleanup = onCleanup(@()path(oldPath));
addpath(fullfile(root,'tests'));
parser=inputParser;
parser.addParameter('SchoolRoot','');parser.addParameter('Groups',{});
parser.addParameter('Workers',1);
parser.addParameter('CancellationFile','');
parser.parse(varargin{:});
schoolRoot = colormeasuretest.parseSchoolRoot('SchoolRoot',parser.Results.SchoolRoot);
selection=colormeasuretest.selectGroups(parser.Results.Groups);
report = colormeasuretest.launchWorker(outputFolder,schoolRoot,selection.selectedGroups, ...
    parser.Results.Workers,parser.Results.CancellationFile);
end

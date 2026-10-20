function report = runPR655Tests(outputFolder, varargin)
%RUNPR655TESTS Isolated software checks for the pr, colorimetry and workflow test groups.
if nargin == 0, outputFolder = tempname; end
schoolRoot = colormeasuretest.parseSchoolRoot(varargin{:});
report = colormeasuretest.launchWorker(outputFolder,schoolRoot,{'pr','colorimetry','workflow'});
end

function report = runCS2000Tests(outputFolder, varargin)
%RUNCS2000TESTS Isolated software checks for the cs2000 test group only.
if nargin == 0, outputFolder = tempname; end
schoolRoot = colormeasuretest.parseSchoolRoot(varargin{:});
report = colormeasuretest.launchWorker(outputFolder,schoolRoot,{'cs2000'});
end

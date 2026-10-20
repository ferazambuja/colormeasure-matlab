function report = runCRTests(outputFolder, varargin)
%RUNCRTESTS Isolated software checks for the cr and colorimetry test groups.
if nargin == 0, outputFolder = tempname; end
schoolRoot = colormeasuretest.parseSchoolRoot(varargin{:});
report = colormeasuretest.launchWorker(outputFolder,schoolRoot,{'cr','colorimetry'});
end

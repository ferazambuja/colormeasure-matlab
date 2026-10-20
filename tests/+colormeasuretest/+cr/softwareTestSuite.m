function [suite, layout] = softwareTestSuite(root, schoolRoot)
%SOFTWARETESTSUITE Discover the family through the shared fail-closed contract.
if nargin < 2, schoolRoot = ''; end
[suite,selected] = colormeasuretest.softwareTestSuite(root,schoolRoot,{'cr','colorimetry'});
layout = struct('measurementFolder',root,'repository',schoolRoot, ...
    'familyTestCount',selected(1).testCount, ...
    'originalComparison',selected(1).originalComparison, ...
    'originalComparisonCount',selected(1).originalComparisonCount);
layout.colorimetryFolder = selected(2).folder;
layout.colorimetryTestCount = selected(2).testCount;
end

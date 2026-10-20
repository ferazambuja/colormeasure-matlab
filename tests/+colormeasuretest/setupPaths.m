function setupPaths(testCase)
%SETUPPATHS Runtime source and qualified test helpers; never serial resources.
root = colormeasuretest.projectRoot();
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'src')));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tests')));
end

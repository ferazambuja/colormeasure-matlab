function tests = testFamilyTestRunner
% Suite discovery and launcher rejection, once for every native family.
% The family wrappers differ only in their folder, groups and school markers,
% so one parameterized file covers them.
% Launcher rejection never spawns a nested MATLAB or touches serial APIs.
%
% Coverage map: the discovery cases run once per family from families(); the
% launcher cases run once per launcher from launchers(), which adds PR-655,
% whose suite API differs and so has no discovery case. Each rule runs for
% every family it applies to: the bundled library must be present,
% driver-versus-library and nested-folder test names must not collide,
% relative report paths resolve from the current folder, and a nonempty
% report folder is refused before worker launch.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testExistingReportsAreNeverOverwritten(testCase)
for family = launchers()
    folder = tempname; mkdir(folder);
    testCase.addTeardown(@()rmdir(folder,'s'));
    fileName = fullfile(folder,'previous.txt');
    file = fopen(fileName,'w'); fprintf(file,'retain this report'); fclose(file);
    verifyError(testCase,@()family.runTests(folder),'measurement:TestOutputFolder',family.name);
    verifyEqual(testCase,fileread(fileName),'retain this report',family.name);
end
end

function testInvalidOutputArgumentsCannotLaunchAWorker(testCase)
for family = launchers()
    for value = {42, '', ["one" "two"], string(missing)}
        verifyError(testCase,@()family.runTests(value{1}),'measurement:TestOutputFolder',family.name);
    end
end
end

function testSourceInstallationDoesNotExposeHardwareOrTimingFixtures(testCase)
% Only the src folder itself is a path folder (package and private folders
% cannot shadow), so a shadow would be a file of that name directly in src.
for name = {'serialport','serial','pause'}
    verifyEmpty(testCase,dir(fullfile(colormeasuretest.projectRoot(),'src',[name{1} '.*'])),name{1});
end
% The school-driver stubs live outside every discovered test folder, so no
% shadow of pause, serial or serialport is met during suite discovery, and
% nothing but the comparison tests puts them on the path.
fixtures = {'cr','original-serial','serialport.m'; 'cs2000','original-serial','serial.m'; ...
    'cs2000','original-pause','pause.m'};
for index = 1:size(fixtures,1)
    folder = colormeasuretest.originalFixture(fixtures{index,1},fixtures{index,2});
    verifyTrue(testCase,isfile(fullfile(folder,fixtures{index,3})),fixtures{index,3});
    verifyFalse(testCase,any(strcmp(strsplit(path,pathsep),folder)),fixtures{index,3});
end
fixtureRoot = fullfile(colormeasuretest.projectRoot(),'tests','original-fixtures');
for name = {'pause.m','serial.m','serialport.m'}
    found = dir(fullfile(colormeasuretest.projectRoot(),'tests','**',name{1}));
    verifyEmpty(testCase,found(~startsWith({found.folder},fixtureRoot)), ...
        [name{1} ' must not live under a discovered test folder']);
end
end

function testDetachedSuiteExcludesOnlyRepositoryComparisons(testCase)
for family = families()
    [root, ~] = layoutFixture(testCase,family);
    [suite, layout] = family.suite(root);
    verifyEqual(testCase,layout.familyTestCount,2,family.name);
    verifyEqual(testCase,numel(suite),2+family.libraryTests,family.name);
    if family.libraryTests, verifyEqual(testCase,layout.colorimetryTestCount,1,family.name); end
    verifyEqual(testCase,layout.originalComparisonCount,0,family.name);
    verifyEqual(testCase,layout.originalComparison,'Not run: SchoolRoot was not supplied.',family.name);
    verifyEmpty(testCase,layout.repository,family.name);
    verifyTrue(testCase,any(contains({suite.Name},'testNestedCheck')),family.name);
    verifyFalse(testCase,any(contains({suite.Name},'testRepositoryCheck')),family.name);
end
end

function testExplicitSchoolRootIncludesPartialBaseline(testCase)
% An explicit school root is taken as given; the suite reads no marker folder.
for family = families()
    [project, root] = layoutFixture(testCase,family);
    [suite, layout] = family.suite(project,root);
    verifyEqual(testCase,layout.repository,root,family.name);
    verifyEqual(testCase,layout.originalComparisonCount,1,family.name);
    verifyEqual(testCase,layout.familyTestCount,3,family.name);
    verifyEqual(testCase,numel(suite),3+family.libraryTests,family.name);
    verifyTrue(testCase,any(contains({suite.Name},'testRepositoryCheck')),family.name);
end
end

function testUnrelatedAncestorRepositoryIsNotAttributed(testCase)
for family = families()
    [project, root] = layoutFixture(testCase,family);
    mkdir(fullfile(root,'.git'));
    for marker = family.markers, mkdir(fullfile(root,marker{1})); end
    [~, layout] = family.suite(project);
    verifyEmpty(testCase,layout.repository,family.name);
    verifyEqual(testCase,layout.originalComparisonCount,0,family.name);
end
end

function testExplicitSchoolRootRequiresComparisonSuite(testCase)
for family = families()
    [project, root] = layoutFixture(testCase,family);
    mkdir(fullfile(root,'Convert'));
    rmdir(fullfile(project,'tests','drivers',family.folder,'repository'),'s');
    verifyError(testCase,@()family.suite(project,root),'measurement:MissingOriginalTests',family.name);
end
end

function testInvalidTestFileFailsDiscovery(testCase)
for family = families()
    [project, ~] = layoutFixture(testCase,family);
    for folder = discoveredFolders(project,family)
        fileName = fullfile(folder{1},'testInvalidDiscovery.m');
        file = fopen(fileName,'w'); assert(file >= 0,'Could not write the invalid discovery fixture.');
        fprintf(file,['function tests = testInvalidDiscovery\n' ...
            'error(''Fixture:InvalidDiscovery'',''Deliberately invalid test suite.'');\n' ...
            'tests = functiontests(localfunctions);\nend\n' ...
            'function testFixture(testCase)\nverifyTrue(testCase,true);\nend\n']);
        fclose(file);
        verifyError(testCase,@()family.suite(project),'Fixture:InvalidDiscovery',family.name);
        delete(fileName);
    end
end
end

function testRelativeOutputUsesMatlabCurrentFolder(testCase)
% Prime Java before changing MATLAB's current folder.
java.io.File('.').getCanonicalPath();
for family = launchers()
    fixture = testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
    file = fopen(fullfile(fixture.Folder,'previous.txt'),'w');
    assert(file >= 0); fprintf(file,'Retained report'); fclose(file);
    expected = char(java.io.File(fixture.Folder).getCanonicalPath());
    try
        family.runTests('.');
        assertFail(testCase,'A nonempty report folder must be refused.');
    catch problem
        verifyEqual(testCase,problem.identifier,'measurement:TestOutputFolder',family.name);
        verifySubstring(testCase,problem.message,expected,family.name);
    end
    verifyEqual(testCase,fileread(fullfile(fixture.Folder,'previous.txt')),'Retained report',family.name);
end
end

function testEmptyFileCannotHideAmongRunnableTests(testCase)
for family = families()
    [project, ~] = layoutFixture(testCase,family);
    for folder = discoveredFolders(project,family)
        fileName = fullfile(folder{1},'testEmptyDiscovery.m');
        file = fopen(fileName,'w'); assert(file >= 0);
        fprintf(file,['function tests = testEmptyDiscovery\n' ...
            'tests = functiontests(localfunctions); tests = tests([]);\nend\n' ...
            'function testUnused(t)\nverifyTrue(t,true);\nend\n']);
        fclose(file);
        identifier = '';
        try
            family.suite(project);
        catch problem
            identifier = problem.identifier;
        end
        verifyTrue(testCase,ismember(identifier, ...
            {'MATLAB:unittest:TestSuite:NonTestFile','measurement:EmptyTestFile'}), ...
            [family.name ': expected empty-file rejection; received: ' identifier]);
        delete(fileName);
    end
end
end

function testMissingBundledLibraryCannotPassAsDetached(testCase)
% A family that bundles the colour library must find its tests.
for family = families()
    if ~family.libraryTests, continue; end
    [project, ~] = layoutFixture(testCase,family);
    rmdir(fullfile(project,'tests','colorimetry'),'s');
    verifyError(testCase,@()family.suite(project),'measurement:MissingTestSuite',family.name);
end
end

function testDuplicateNamesAcrossDriverAndLibraryAreRejected(testCase)
for family = families()
    if ~family.libraryTests, continue; end
    [project, ~] = layoutFixture(testCase,family);
    writeFixture(fullfile(project,'tests','drivers',family.folder),'testLibraryCheck');
    verifyError(testCase,@()family.suite(project),'measurement:DuplicateTests',family.name);
end
end

function testDuplicateNamesAcrossNestedFoldersAreRejected(testCase)
for family = families()
    [project, ~] = layoutFixture(testCase,family);
    writeFixture(fullfile(project,'tests','drivers',family.folder,'nested'),'testBundleCheck');
    verifyError(testCase,@()family.suite(project),'measurement:DuplicateTests',family.name);
end
end

function testOriginalComparisonsCannotReplaceNativeTests(testCase)
for family = families()
    [project, root] = layoutFixture(testCase,family);
    mkdir(fullfile(root,'Convert'));
    delete(fullfile(project,'tests','drivers',family.folder,'testBundleCheck.m'));
    rmdir(fullfile(project,'tests','drivers',family.folder,'nested'),'s');
    verifyError(testCase,@() family.suite(project,root),'measurement:EmptyTestSuite',family.name);
end
end

function list = families()
list = [ ...
    struct('name','cr','folder','cr','runTests',@colormeasuretest.cr.runCRTests, ...
        'suite',@colormeasuretest.cr.softwareTestSuite,'libraryTests',1, ...
        'markers',{{fullfile('Devices','Colorimetry_Research'),'Convert'}}), ...
    struct('name','cs2000','folder','cs2000','runTests',@colormeasuretest.cs2000.runCS2000Tests, ...
        'suite',@colormeasuretest.cs2000.softwareTestSuite,'libraryTests',0, ...
        'markers',{{fullfile('Devices','MinoltaCS2000'),'Convert'}})];
end

function list = launchers()
% Every family launcher; PR-655's suite API differs, so it appears only here.
list = [ ...
    struct('name','pr','runTests',@colormeasuretest.pr.runPR655Tests), ...
    struct('name','cr','runTests',@colormeasuretest.cr.runCRTests), ...
    struct('name','cs2000','runTests',@colormeasuretest.cs2000.runCS2000Tests)];
end

function folders = discoveredFolders(project,family)
folders = {fullfile(project,'tests','drivers',family.folder)};
if family.libraryTests, folders{end+1} = fullfile(project,'tests','colorimetry'); end
end

function [project, root] = layoutFixture(testCase,family)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
project = fullfile(root,'project');
writeFixture(fullfile(project,'tests','drivers',family.folder),'testBundleCheck');
writeFixture(fullfile(project,'tests','drivers',family.folder,'nested'),'testNestedCheck');
writeFixture(fullfile(project,'tests','drivers',family.folder,'repository'),'testRepositoryCheck');
writeFixture(fullfile(project,'tests','colorimetry'),'testLibraryCheck');
end

function writeFixture(folder,name)
if ~isfolder(folder), mkdir(folder); end
file = fopen(fullfile(folder,[name '.m']),'w');
assert(file >= 0,'Could not write the suite-discovery fixture.');
cleanup = onCleanup(@()fclose(file));
fprintf(file,['function tests = %s\n' ...
    'tests = functiontests(localfunctions);\nend\n' ...
    'function testFixture(testCase)\nverifyTrue(testCase,true);\nend\n'],name);
end

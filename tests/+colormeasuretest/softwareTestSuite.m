function [suite, layout] = softwareTestSuite(root, schoolRoot, groups)
%SOFTWARETESTSUITE Discover each selected group once and report reference scope.
% A supplied SchoolRoot selects comparison tests even when that baseline is
% incomplete, so the reference tests fail rather than silently disappearing.
if nargin < 2, schoolRoot = ''; end
if nargin < 3, groups = {}; end
[~,definitions] = colormeasuretest.selectGroups(groups);
schoolRoot = colormeasuretest.parseSchoolRoot('SchoolRoot',schoolRoot);
suite = [];
layout = struct('key',{},'name',{},'folder',{},'firstTest',{},'testCount',{}, ...
    'originalComparison',{},'originalComparisonCount',{});
for definition = definitions
    folder = fullfile(root,'tests',definition.folder);
    assert(isfolder(folder),'measurement:MissingTestSuite', ...
        'Required test folder is missing: %s',folder);
    selected = testsuite(folder,'IncludeSubfolders',true,'InvalidFileFoundAction','error');
    % A test name starts with its file/class name, before any parameterization
    % or procedure. Match both name and folder so an empty file cannot borrow
    % a test from a same-named file elsewhere. Reuse discovery instead of
    % executing every function-based suite factory a second time.
    parents = regexp({selected.Name},'^[^/(\[]+','match','once');
    baseFolders = {selected.BaseFolder};
    files = dir(fullfile(folder,'**','test*.m'));
    for item = 1:numel(files)
        filename = fullfile(files(item).folder,files(item).name);
        % Namespace folders qualify the name; BaseFolder lies above them.
        [base,name] = fileparts(filename);
        [above,namespace] = fileparts(base);
        while startsWith(namespace,'+')
            name = [namespace(2:end) '.' name]; %#ok<AGROW>
            base = above; [above,namespace] = fileparts(base);
        end
        present = strcmp(baseFolders,base) & strcmp(parents,name);
        assert(any(present),'measurement:EmptyTestFile', ...
            'No runnable tests discovered in %s',filename);
    end
    originalFolder = fullfile(folder,'repository');
    originals = strcmp({selected.BaseFolder},originalFolder) ...
        | startsWith({selected.BaseFolder},[originalFolder filesep]);
    comparison = 'Not applicable.';
    if definition.supportsOriginalComparison
        if ~isempty(schoolRoot)
            assert(any(originals),'measurement:MissingOriginalTests', ...
                'The supplied school baseline requires comparison tests: %s',originalFolder);
            comparison = 'Included; see named test results.';
        else
            selected = selected(~originals);
            originals = false(size(selected));
            comparison = 'Not run: SchoolRoot was not supplied.';
        end
    end
    assert(~isempty(selected) && any(~originals),'measurement:EmptyTestSuite', ...
        'No runnable bundled tests found in %s',folder);
    layout(end+1) = struct('key',definition.key,'name',definition.name,'folder',folder, ...
        'firstTest',numel(suite)+1,'testCount',numel(selected), ...
        'originalComparison',comparison,'originalComparisonCount',nnz(originals)); %#ok<AGROW>
    if isempty(suite), suite = selected(:); else, suite = [suite(:); selected(:)]; end
end
assert(numel(unique({suite.Name})) == numel(suite), ...
    'measurement:DuplicateTests','Discovered duplicate test names; every check must run exactly once.');
end

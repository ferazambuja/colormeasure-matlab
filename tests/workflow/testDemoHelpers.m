function tests = testDemoHelpers
% The shared demo helpers carry the failure rules every family demo relies on:
% a refused reading stops a batch with the family's reading identifier and a
% gallery silently, and a batch that does not finish saving reports the
% family's finish identifier. Checked here over a minimal direct adapter so
% the rules hold independently of any family.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end

function testBatchMeasuresEveryReadingAndFinishes(testCase)
[session, cleanup] = openSession(testCase, @(~) reading(1)); %#ok<ASGLU>
colormeasure.session.demoBatch(session, 3, 'demotest:Reading', 'demotest:Finish');
verifyNumElements(testCase, session.measurements, 3);
verifyEqual(testCase, {session.measurements.name}, {'Sample 001', 'Sample 002', 'Sample 003'});
verifyTrue(testCase, all(strcmp({session.measurements.notes}, 'SYNTHETIC DEMO')));
verifyTrue(testCase, session.finished);
verifyTrue(testCase, isfile(session.files.mat));
end

function testRefusedReadingStopsTheBatchWithTheReadingIdentifier(testCase)
for failedIndex = 1:3
    attempts = 0;
    [session, cleanup] = openSession(testCase, @read); %#ok<ASGLU>
    verifyError(testCase, @() colormeasure.session.demoBatch(session, 3, 'demotest:Reading', 'demotest:Finish'), ...
        'demotest:Reading');
    verifyNumElements(testCase, session.measurements, failedIndex - 1);
    verifyFalse(testCase, session.finished);
    clear cleanup
end
    function value = read(~)
        attempts = attempts + 1;
        if attempts == failedIndex, error('demotest:Injected', 'Injected reading failure.'); end
        value = reading(attempts);
    end
end

function testUnfinishedSaveReportsTheFinishIdentifierAndKeepsEarlierReadings(testCase)
for target = {'mat', 'csv'}
    io = colormeasure.session.services();
    if strcmp(target{1}, 'mat'), io.saveMat = @(varargin) error('demotest:Save', 'Injected MAT failure.');
    else, io.exportCsv = @(varargin) error('demotest:Export', 'Injected CSV failure.');
    end
    [session, cleanup] = openSession(testCase, @(~) reading(1), io); %#ok<ASGLU>
    verifyError(testCase, @() colormeasure.session.demoBatch(session, 2, 'demotest:Reading', 'demotest:Finish'), ...
        'demotest:Finish');
    verifyNumElements(testCase, session.measurements, 2);
    verifyFalse(testCase, session.finished);
    if strcmp(target{1}, 'mat'), verifyNotEmpty(testCase, session.saveError);
    else, verifyNotEmpty(testCase, session.exportError);
    end
    % Deleting a session whose MAT never saved retains its data in the base
    % workspace and says so; after a failed CSV export the MAT is saved, so
    % nothing is unsaved and deleting is silent. The retained variable is
    % cleared with the test.
    recovered = evalin('base', 'who(''colorMeasureRecovered_*'')');
    if strcmp(target{1}, 'mat')
        verifyWarning(testCase, @() delete(session), 'Measurement:UnsavedSession');
    else
        verifyWarningFree(testCase, @() delete(session));
    end
    clearRecovered(testCase, recovered);
    clear cleanup
end
end

function testGalleryNamesEveryProfileAndLetsTheFamilyAnnotate(testCase)
[session, cleanup] = openSession(testCase, @(~) reading(1)); %#ok<ASGLU>
profiles = struct('name', {'Grey', 'Red'}, 'description', {'A neutral.', 'A primary.'});
colormeasure.session.demoGallery(session, profiles, @annotate);
verifyEqual(testCase, {session.measurements.name}, {'Sample 001 - Grey', 'Reference red'});
verifyEqual(testCase, session.measurements(1).notes, ...
    'SYNTHETIC GALLERY: A neutral. Not a measured or calibrated reference.');
verifyEqual(testCase, session.measurements(2).notes, 'Annotated by the family.');
verifyFalse(testCase, session.finished); % A gallery leaves the session open for the operator.
    function [name, notes] = annotate(index, name, notes)
        if index == 2, name = 'Reference red'; notes = 'Annotated by the family.'; end
    end
end

function testGalleryWithoutAnnotationUsesTheDefaultNamesAndNotes(testCase)
[session, cleanup] = openSession(testCase, @(~) reading(1)); %#ok<ASGLU>
profiles = struct('name', {'Grey'}, 'description', {'A neutral.'});
colormeasure.session.demoGallery(session, profiles);
verifyEqual(testCase, session.measurements(1).name, 'Sample 001 - Grey');
verifyEqual(testCase, session.measurements(1).notes, ...
    'SYNTHETIC GALLERY: A neutral. Not a measured or calibrated reference.');
end

function testGalleryStopsAtTheFirstRefusedReadingWithoutRaising(testCase)
attempts = 0;
[session, cleanup] = openSession(testCase, @read); %#ok<ASGLU>
profiles = struct('name', {'One', 'Two', 'Three', 'Four'}, 'description', {'1', '2', '3', '4'});
colormeasure.session.demoGallery(session, profiles);
verifyNumElements(testCase, session.measurements, 2);
verifyEqual(testCase, attempts, 3); % The refused third reading ends population; the fourth is never attempted.
verifyFalse(testCase, session.finished);
    function value = read(~)
        attempts = attempts + 1;
        if attempts == 3, error('demotest:Injected', 'Injected reading failure.'); end
        value = reading(attempts);
    end
end

function testTextFieldReadsOnlyTextValues(testCase)
record = struct('row', 'abc', 'empty', '', 'scalar', "xyz", 'missing', string(missing), ...
    'number', 5, 'column', ['a'; 'b'], 'cell', {{'a'}}, 'strings', ["a" "b"]);
textField = @colormeasure.session.textField;
verifyEqual(testCase, textField(record, 'row'), 'abc');
verifyEqual(testCase, textField(record, 'empty'), '');
verifyEqual(testCase, textField(record, 'scalar'), 'xyz');
verifyEqual(testCase, textField(record, 'missing'), '');
verifyEqual(testCase, textField(record, 'number'), '');
verifyEqual(testCase, textField(record, 'column'), '');
verifyEqual(testCase, textField(record, 'cell'), '');
verifyEqual(testCase, textField(record, 'strings'), '');
verifyEqual(testCase, textField(record, 'absent'), '');
verifyClass(testCase, textField(record, 'scalar'), 'char');
end

function [session, cleanup] = openSession(testCase, read, io)
adapter = struct('key', 'demo-helper-fixture', 'label', 'Demo helper fixture', ...
    'listPorts', @(~) "VIRTUAL", 'connect', @(~) struct(), 'read', read, ...
    'release', @(~) [], 'toTable', @(m, ~) table((1:numel(m))', 'VariableNames', {'Index'}));
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
if nargin < 3
    session = colormeasure.session.Session(adapter, folder.Folder);
else
    session = colormeasure.session.Session(adapter, folder.Folder, io);
end
cleanup = onCleanup(@() delete(session));
end

function clearRecovered(testCase, before)
% Remove the workspace variables an unsaved session left behind, keeping any
% that existed before the test.
after = evalin('base', 'who(''colorMeasureRecovered_*'')');
for name = reshape(setdiff(after, before), 1, [])
    evalin('base', ['clear ' name{1}]);
end
verifyEqual(testCase, evalin('base', 'who(''colorMeasureRecovered_*'')'), before);
end

function value = reading(index)
value = struct('XYZ', [10 20 30] * index, 'xyzMethod', 'fixture');
end

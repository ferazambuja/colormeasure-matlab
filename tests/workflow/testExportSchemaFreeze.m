function tests = testExportSchemaFreeze
% Native adapters expose stable CSV contracts. Their column names, order and
% MATLAB table classes are pinned here as literals so a format change is
% deliberate and updates the producer, its consumers, these pins and the docs
% together.
% Each family's synthetic demo batch is driven through the session's own
% export, and both the table it hands to writetable and the CSV file on disk
% (header line, one kind per column, logical flags as 0/1) must match the
% pins. The stored reading-field set of each family's session MAT is pinned
% the same way, and so is the guided chart's selected-cell CSV header.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
% One synthetic batch per family serves every test here: the tests only read
% the sessions and the files they wrote.
catalog = colormeasure.ui.deviceCatalog();
sessions = containers.Map('KeyType', 'char', 'ValueType', 'any');
for index = 1:numel(catalog)
    session = catalog(index).demoFactory('batch');
    testCase.addTeardown(@() colormeasuretest.disposeBatch(session));
    sessions(catalog(index).model) = session;
end
testCase.TestData.sessions = sessions;
end

function testEveryNativeFamilyWritesItsPinnedColumnsAndClasses(testCase)
catalog = colormeasure.ui.deviceCatalog();
checked = {};
for index = 1:numel(catalog)
    model = catalog(index).model;
    session = testCase.TestData.sessions(model);
    adapter = catalog(index).factory();
    data = adapter.toTable(session.measurements, session.info);
    [names, classes] = pinned(model);
    verifyEqual(testCase, data.Properties.VariableNames, names, [model ' column names and order']);
    actual = cellfun(@(name) class(data.(name)), data.Properties.VariableNames, 'UniformOutput', false);
    verifyEqual(testCase, actual, classes, [model ' column classes']);
    verifyTrue(testCase, isfile(session.files.csv), [model ' demo must write its CSV']);
    verifyEqual(testCase, headerLine(session.files.csv), strjoin(names, ','), ...
        [model ' written CSV header line']);
    onDisk = readUnderPinnedKinds(session.files.csv, names, classes);
    verifyEqual(testCase, height(onDisk), height(data), [model ' written CSV row count']);
    for column = names(strcmp(classes, 'logical'))
        verifyTrue(testCase, all(ismember(onDisk.(column{1}), [0 1])), ...
            [model ' writes the logical column ' column{1} ' as 0/1']);
    end
    checked{end+1} = model; %#ok<AGROW>
end
verifyEqual(testCase, sort(checked), {'CR100', 'CR250', 'CR300', 'CS2000', 'PR655'});
end

function testGuidedChartCsvWritesItsPinnedHeader(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
session = colormeasuretest.continuationBatch(folder);
testCase.addTeardown(@() colormeasuretest.disposeSession(session));
session.startChart(colormeasure.chart.definition('custom', 'Pinned', 1, 2));
verifyTrue(testCase, session.measure());
names = {'RunId', 'PassId', 'SegmentId', 'DefinitionId', 'DefinitionRevision', ...
    'Row', 'Column', 'Coordinate', 'SourceLocation', 'SourceId', 'SourceRow', 'ExportId', ...
    'PatchNumber', 'PatchName', 'ReadingName', 'ReadingNotes', 'OriginalName', 'OriginalNotes', ...
    'Status', 'SelectedAttempt', 'ReadingIndex', 'X', 'Y', 'Z', ...
    'Quantities', 'Units', 'Context', 'UnavailableReason'};
verifyNumElements(testCase, names, 28);
data = colormeasure.chart.selectedTable(session.measurements, session.info, struct());
verifyEqual(testCase, data.Properties.VariableNames, names, 'chart column names and order');
verifyTrue(testCase, isfile(session.files.chartCsv), 'a chart reading must write its CSV');
verifyEqual(testCase, headerLine(session.files.chartCsv), strjoin(names, ','), ...
    'written chart CSV header line');
end

function testStoredPRSpectrumFieldIsStillRadiance(testCase)
% The stored reading field is part of the freeze.
% testPR655AdapterSessionAndExport/testAdapterRetainsCompleteSpectraAndMetadata
% pins it on a parsed instrument reading; this pins the synthetic batch too.
session = testCase.TestData.sessions('PR655');
saved = load(session.files.mat, 'measurements', '-mat');
verifyTrue(testCase, isfield(saved.measurements, 'radiance'));
verifyFalse(testCase, isfield(saved.measurements, 'spectralData'));
end

function testEveryNativeFamilyStoresItsPinnedReadingFields(testCase)
% The stored reading-field set is frozen with the CSV columns: the session
% MAT of each family's synthetic demo batch must hold exactly these fields,
% in this order. Synthetic batches carry the synthetic provenance fields;
% real-driver fields are checked separately because instrument metadata and
% synthetic-only fields differ between producers.
catalog = colormeasure.ui.deviceCatalog();
checked = {};
for index = 1:numel(catalog)
    model = catalog(index).model;
    session = testCase.TestData.sessions(model);
    saved = load(session.files.mat, 'measurements', 'batchInfo', '-mat');
    verifyEqual(testCase, sort(fieldnames(saved)), {'batchInfo'; 'measurements'}, [model ' stored variables']);
    verifyEqual(testCase, fieldnames(saved.measurements), storedFields(model), [model ' stored reading fields']);
    checked{end+1} = model; %#ok<AGROW>
end
verifyEqual(testCase, sort(checked), {'CR100', 'CR250', 'CR300', 'CS2000', 'PR655'});
end

function names = storedFields(model)
common = {'name'; 'notes'; 'port'; 'startedAtUTC'; 'completedAtUTC'; 'startedAtLocal'; ...
    'localTimeZone'; 'completedAtLocal'; 'durationSeconds'; 'matlabVersion'; 'instrumentSettings'};
switch model
    case 'PR655'
        names = [{'lambda'; 'radiance'; 'XYZ'; 'xyzMethod'; 'totalRadiance'; 'deviceType'; 'unitsCode'; ...
            'peakWavelength'; 'instrumentTotalRadiance'; 'integratedPhotonRadiance'; 'isSynthetic'; ...
            'syntheticProfile'; 'syntheticProfileIndex'; 'syntheticAssociation'; 'syntheticSeed'; ...
            'syntheticGain'; 'spectralUnits'}; common];
    case {'CR100', 'CR250', 'CR300'}
        names = [{'XYZ'; 'deviceType'; 'xyzMethod'; 'xyzUnits'; 'observerId'; 'lambda'; 'spectralData'; ...
            'spectralQuantity'; 'spectralUnits'; 'spectralUnitsConfirmed'; 'instrumentXYZ'; ...
            'instrumentMetadata'; 'driverSnapshot'; 'CCT'; 'Duv'; 'cctSource'; 'integratedSpectrum'; ...
            'radiometricType'; 'isSynthetic'; 'syntheticProfile'; 'syntheticProfileIndex'; ...
            'syntheticAssociation'; 'syntheticSeed'; 'syntheticGain'}; common];
    case 'CS2000'
        names = [{'XYZ'; 'deviceType'; 'xyzMethod'; 'xyzUnits'; 'xyzUnitsConfirmed'; 'observerId'; 'lambda'; ...
            'spectralData'; 'spectralQuantity'; 'spectralUnits'; 'spectralUnitsConfirmed'; 'driverSnapshot'; ...
            'instrumentMetadata'; 'isSynthetic'; 'cleanupStatus'; 'warnings'; 'syntheticProfile'; ...
            'syntheticProfileIndex'; 'syntheticDescription'; 'syntheticAssociation'; ...
            'syntheticSeed'; 'syntheticGain'}; common];
    otherwise
        error('test:Schema', 'No pinned stored fields for %s.', model);
end
end

function [names, classes] = pinned(model)
switch model
    case 'PR655'
        names = {'MeasurementIndex', 'MeasurementName', 'Notes', 'StartedAtUTC', 'CompletedAtUTC', ...
    'DeviceType', 'Port', 'UnitsCode', 'Wavelength_nm', 'SpectralReading', 'Computed_X', ...
    'Computed_Y', 'Computed_Z', 'IntegratedSpectralReading', 'PeakWavelength_nm', ...
    'InstrumentIntegratedReading', 'IntegratedPhotonReading', 'SpectralUnits', 'XYZMethod', ...
    'MATLABVersion', 'MeasurementDurationSeconds', 'BatchStartedAtUTC', ...
    'BatchCompletedAtUTC', 'BatchElapsedSeconds', 'StartedAtLocal', 'CompletedAtLocal', ...
    'LocalTimeZone', 'BatchStartedAtLocal', 'BatchCompletedAtLocal', 'BatchLocalTimeZone', 'IsSynthetic'};
        classes = {'double', 'cell', 'cell', 'cell', 'cell', 'cell', 'cell', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'double', 'double', 'double', 'cell', 'cell', ...
    'cell', 'double', 'cell', 'cell', 'double', 'cell', 'cell', 'cell', 'cell', 'cell', ...
    'cell', 'logical'};
    case {'CR100', 'CR250', 'CR300'}
        names = {'MeasurementIndex', 'MeasurementName', 'Notes', 'DeviceType', 'HasSpectrum', ...
    'Wavelength_nm', 'SpectralReading', 'X', 'Y', 'Z', 'Instrument_X', 'Instrument_Y', ...
    'Instrument_Z', 'XYZMethod', 'XYZUnits', 'Observer', 'SpectralQuantity', ...
    'SpectralUnits', 'SpectralUnitsConfirmed', 'IntegratedSpectrum', 'CCT_K', 'Duv_1960', ...
    'CCTSource', 'IsSynthetic', 'StartedAtUTC', 'CompletedAtUTC', 'StartedAtLocal', ...
    'CompletedAtLocal', 'LocalTimeZone', 'Port', 'BatchStartedAtUTC', 'BatchCompletedAtUTC'};
        classes = {'double', 'cell', 'cell', 'cell', 'logical', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'cell', 'cell', 'cell', 'cell', 'cell', ...
    'logical', 'double', 'double', 'double', 'cell', 'logical', 'cell', 'cell', 'cell', ...
    'cell', 'cell', 'cell', 'cell', 'cell'};
    case 'CS2000'
        names = {'MeasurementIndex', 'MeasurementName', 'Notes', 'StartedAtUTC', 'CompletedAtUTC', ...
    'DeviceType', 'Port', 'Wavelength_nm', 'SpectralReading', 'Raw_X', 'Raw_Y', 'Raw_Z', ...
    'XYZSource', 'XYZUnits', 'Observer', 'SpectralQuantity', 'SpectralUnits', 'IsSynthetic', ...
    'Warnings', 'MATLABVersion', 'MeasurementDurationSeconds', 'BatchStartedAtUTC', ...
    'BatchCompletedAtUTC', 'BatchElapsedSeconds'};
        classes = {'double', 'string', 'string', 'string', 'string', 'string', 'string', 'double', ...
    'double', 'double', 'double', 'double', 'string', 'string', 'string', 'string', ...
    'string', 'logical', 'string', 'string', 'double', 'string', 'string', 'double'};
    otherwise
        error('test:Schema', 'No pinned schema for %s.', model);
end
end

function line = headerLine(filename)
fid = fopen(filename, 'r');
assert(fid ~= -1, 'test:Schema', 'The written CSV could not be opened: %s', filename);
cleanup = onCleanup(@() fclose(fid));
line = fgetl(fid);
end

function data = readUnderPinnedKinds(filename, names, classes)
% Read the file back with every column forced to the kind its pinned class
% writes: numbers for double and logical columns (writetable stores logical
% flags as 0/1), text for the rest. A column whose on-disk representation
% changed cannot be read under its pinned kind, and the read then errors
% instead of filling the column with NaN.
options = detectImportOptions(filename, 'VariableNamingRule', 'preserve');
numeric = ismember(classes, {'double', 'logical'});
options = setvartype(options, names(numeric), 'double');
options = setvartype(options, names(~numeric), 'char');
options.ImportErrorRule = 'error';
data = readtable(filename, options);
end

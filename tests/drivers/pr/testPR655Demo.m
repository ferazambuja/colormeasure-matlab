function tests = testPR655Demo
% Deterministic synthetic previews and their separation from manual sessions.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = fixture.Folder;
oldRegistry = getappdata(groot, 'ColorMeasureSessions');
oldVisibility = get(groot, 'DefaultFigureVisible');
t.addTeardown(@() restoreRegistry(oldRegistry));
t.addTeardown(@() set(groot, 'DefaultFigureVisible', oldVisibility));
setappdata(groot, 'ColorMeasureSessions', []);
set(groot, 'DefaultFigureVisible', 'off');
end

function testProfilesHaveUsefulChromaticitySpread(t)
% Spectrum generation/cycling belongs to the core testPR655Synthetic suite.
profiles = colormeasure.simulation.syntheticProfiles();
xyz = zeros(numel(profiles), 3);
for index = 1:numel(profiles)
    instrument = colormeasure.drivers.pr.DemoInstrument(index, 0);
    reading = instrument.measure(); delete(instrument);
    xyz(index, :) = reading.XYZ;
end
uv = colormeasure.analysis.chromaticity(xyz, 'uv');
verifyGreaterThanOrEqual(t, size(unique(round(uv, 6), 'rows'), 1), 10);
verifyGreaterThan(t, max(uv(:, 1))-min(uv(:, 1)), .25);
verifyGreaterThan(t, max(uv(:, 2))-min(uv(:, 2)), .3);
end

function testGalleryReusesOneSessionAndRemainsInteractive(t)
colormeasuretest.preserveWorkspace(t, 'colorMeasurePR655DemoGallery');
session = colormeasure.drivers.pr.demoPR655('gallery');
t.addTeardown(@() colormeasuretest.disposeBatch(session));
verifyNumElements(t, session.measurements, 12);
verifyEqual(t, session.catalogIdentity, ...
    struct('model','PR655','mode','gallery','key','PR655DemoGallery'));
verifyEqual(t, session.savedCount, 12);
verifyFalse(t, session.finished); verifyEmpty(t, session.files.csv);
verifyTrue(t, all([session.measurements.isSynthetic]));
verifyEqual(t, [session.measurements.syntheticProfileIndex], 1:12);
verifyTrue(t, all(contains({session.measurements.notes}, 'SYNTHETIC GALLERY')));
verifyTrue(t, all(contains({session.measurements.notes}, 'Not a measured or calibrated reference')));
verifyEqual(t, session.measurements(3).name, session.measurements(10).name);
verifyTrue(t,contains(session.measurements(12).notes,newline));
verifyTrue(t, startsWith(session.destination, fullfile(tempdir,'colormeasure','PR655')));
loaded = load(session.files.mat);
verifyEqual(t, loaded.measurements, session.measurements);
original = session.measurements; originalFiles = session.files;
restored = colormeasure.drivers.pr.demoPR655('gallery');
verifyEqual(t, restored, session); verifyEqual(t, restored.measurements, original);
verifyEqual(t, restored.files, originalFiles);
colormeasure.drivers.pr.demoPR655('gallery'); % The bare command form publishes the handle.
verifyEqual(t, evalin('base', 'colorMeasurePR655DemoGallery'), session);
verifyTrue(t, session.measure('Manual addition', 'Explicit measure after gallery'));
verifyNumElements(t, session.measurements, 13);
verifyEqual(t, session.measurements(13).syntheticProfileIndex, 1);
verifyEqual(t, session.measurements(13).name, 'Manual addition');
verifyEqual(t, session.measurements(13).notes, 'Explicit measure after gallery');
session.finish();
verifyEqual(t, colormeasure.drivers.pr.demoPR655('gallery'), session);
verifyTrue(t, session.finished); verifyNumElements(t, session.measurements, 13);
verifyEqual(t, height(readtable(session.files.csv)), 13*101);
replacement = session.newBatch();
t.addTeardown(@() colormeasuretest.disposeBatch(replacement));
verifyEmpty(t, replacement.measurements);
verifyEqual(t, colormeasure.drivers.pr.demoPR655('gallery'), replacement);
verifyEmpty(t, replacement.measurements); % Relaunch never repopulates a manual new batch.
end

function testManualDemoRestoresWithoutAutomaticallyMeasuring(t)
colormeasuretest.preserveWorkspace(t, 'colorMeasurePR655DemoSession');
adapter = colormeasure.drivers.pr.uiAdapter(); adapter.key = 'PR655Demo';
adapter.catalog.mode = 'interactive';
adapter.label = 'Synthetic manual test'; adapter.listPorts = @(~) "DEMO_ONLY";
adapter.connect = @(~) colormeasure.drivers.pr.DemoInstrument(1, 0);
session = colormeasure.session.Session(adapter, t.TestData.folder, colormeasure.ui.services());
t.addTeardown(@() colormeasuretest.disposeBatch(session));
colormeasure.session.sessionRegistry('put', adapter.key, session, t.TestData.folder);
restored = colormeasure.drivers.pr.demoPR655();
verifyEqual(t, restored, session); verifyEmpty(t, session.measurements);
verifyEqual(t, restored.catalogIdentity, ...
    struct('model','PR655','mode','interactive','key','PR655Demo'));
colormeasure.drivers.pr.demoPR655;
verifyEqual(t, evalin('base', 'colorMeasurePR655DemoSession'), session);
verifyEmpty(t, session.measurements);
verifyTrue(t, session.measure('Explicit sample', 'Manual demo stays manual'));
verifyNumElements(t, session.measurements, 1);
verifyEqual(t, colormeasure.drivers.pr.demoPR655(), session); verifyNumElements(t, session.measurements, 1);
end

function testBatchModeSavesTwoSyntheticReadingsWithoutAWindow(t)
% The public command keeps the demo's visible pacing: at least 0.5 s per
% reading. Tests that need no pacing pass the delay seam instead.
started = tic; session = colormeasure.drivers.pr.demoPR655('batch');
t.addTeardown(@() colormeasuretest.disposeBatch(session));
verifyGreaterThanOrEqual(t, toc(started), 0.9);
verifyTrue(t, session.finished); verifyEmpty(t, session.window);
verifyEqual(t, session.catalogIdentity, ...
    struct('model','PR655','mode','batch','key','PR655DemoBatch'));
verifyNumElements(t, session.measurements, 2);
verifyTrue(t, isfile(session.files.mat)); verifyTrue(t, isfile(session.files.csv));
verifyEqual(t, height(readtable(session.files.csv)), 202);
end

function testBatchPublicationDoesNotReplaceTheInteractiveSession(t)
colormeasuretest.preserveWorkspace(t,'colorMeasurePR655DemoSession');
colormeasuretest.preserveWorkspace(t,'colorMeasurePR655DemoBatch');
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
interactive=colormeasure.drivers.pr.demoSession('interactive',io,t.TestData.folder,0);
t.addTeardown(@()colormeasuretest.disposeBatch(interactive));
% The returned-handle call does not publish; exercise the bare launcher.
colormeasure.drivers.pr.demoSession('interactive',io,t.TestData.folder,0);
verifyEqual(t,evalin('base','colorMeasurePR655DemoSession'),interactive);
colormeasure.drivers.pr.demoSession('batch',io,t.TestData.folder,0);
batch=evalin('base','colorMeasurePR655DemoBatch');
t.addTeardown(@()colormeasuretest.disposeBatch(batch));
verifyEqual(t,evalin('base','colorMeasurePR655DemoSession'),interactive);
verifyNotEqual(t,batch,interactive);verifyEmpty(t,interactive.measurements);
verifyEqual(t,colormeasure.drivers.pr.demoSession('interactive',io,t.TestData.folder,0),interactive);
end

function testSettingsInspectionRetainsDemoStateWithoutConsumingSamples(t)
io = colormeasure.ui.services();
io.chooseFolder = @(~) t.TestData.folder;
session = colormeasure.drivers.pr.demoSession('interactive', io, t.TestData.folder);
t.addTeardown(@() colormeasuretest.disposeBatch(session));
verifyTrue(t, session.refreshInstrumentSettings());
verifyEmpty(t, session.measurements);
verifyTrue(t, session.setInstrumentSettings(struct('cycles', 3)));
verifyTrue(t, session.measure('Sample 001', ''));
verifyTrue(t, session.refreshInstrumentSettings());
verifyEqual(t, session.settingsSnapshot.values.cycles, 3);
verifyTrue(t, session.measure('Sample 002', ''));
verifyEqual(t, [session.measurements.syntheticProfileIndex], [1 2]);
verifyEqual(t, session.measurements(2).instrumentSettings.after.values.cycles, 3);
end

function testGuidedDemoCountsKeepPassAndFixedExposureStartsEmptyPass(t)
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
session=colormeasure.drivers.pr.demoSession('interactive',io,t.TestData.folder,0);
t.addTeardown(@()colormeasuretest.disposeBatch(session));
session.startChart(colormeasure.chart.definition('custom','Settings passes',1,3));
verifyTrue(t,session.measure());
verifyEqual(t,session.measurements(1).deviceType,'PR-655');
verifyTrue(t,session.measurements(1).isSynthetic);
verifyEqual(t,session.chart.passes(1).context.material.model.value,'PR-655');
verifyEqual(t,session.chart.passes(1).context.material.provenance.value,'simulated');
verifyTrue(t,session.setInstrumentSettings(struct('cycles',3)));
verifyEmpty(t,session.chart.pendingContext);verifyEqual(t,session.chart.activePass,1);
verifyTrue(t,session.measure());verifyEqual(t,session.chart.coverage,2);
verifyEqual(t,session.measurements(2).instrumentSettings.after.values.cycles,3);
verifyTrue(t,session.setInstrumentSettings(struct('cycles',3,'exposureMilliseconds',30)));
verifyNotEmpty(t,session.chart.pendingContext);verifyFalse(t,session.measure());
verifyNumElements(t,session.measurements,2);
session.acceptChartContext();verifyEqual(t,session.chart.activePass,2);
verifyEqual(t,session.chart.coverage,0);verifyEqual(t,session.chart.passes(1).coverage,2);
verifyTrue(t,session.measure());verifyEqual(t,session.chart.coverage,1);
verifyNumElements(t,session.measurements,3);
session.finish(AllowIncompleteChart=true);verifyTrue(t,session.finished);
saved=load(session.files.mat);verifyEqual(t,saved.measurements,session.measurements);
verifyTrue(t,all([saved.measurements.isSynthetic]));
verifyEqual(t,saved.batchInfo.chart.passes(1).context.material.model.value,'PR-655');
end

function testBatchSaveFailureIsReportedAndRetained(t)
colormeasuretest.preserveWorkspace(t, 'colorMeasurePR655DemoBatch');
io = colormeasure.session.services();
io.exportCsv = @(varargin) error('Test:Export', 'Injected export failure');
% The retained session is announced as a warning with an identifier, not
% printed to stderr, so it can be asserted here and silenced by a caller.
verifyWarning(t, @() verifyError(t, @() colormeasure.drivers.pr.demoSession('batch', io, t.TestData.folder, 0), ...
    'PR655:DemoFinish'), 'PR655:DemoBatchRetained');
session = evalin('base', 'colorMeasurePR655DemoBatch');
t.addTeardown(@() colormeasuretest.disposeBatch(session));
verifyNumElements(t, session.measurements, 2);
verifyTrue(t, session.needsRecovery);
saved = load(session.files.mat);
verifyEqual(t, saved.measurements, session.measurements);
verifyNotEmpty(t, session.exportError);
end

function restoreRegistry(previous)
setappdata(groot, 'ColorMeasureSessions', previous);
end

function tests = testPR655Synthetic
% Deterministic synthetic spectra and command-driven batch acquisition.
% Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testProfilesAreDeterministicFiniteAndVaried(t)
profiles = colormeasure.simulation.syntheticProfiles();
verifyNumElements(t, profiles, 12);
spectra = zeros(101, numel(profiles)); xyz = zeros(numel(profiles), 3);
for index = 1:numel(profiles)
    instrument = colormeasure.drivers.pr.DemoInstrument(index, 0);
    peer = colormeasure.drivers.pr.DemoInstrument(index, 0);
    cleanup = onCleanup(@() delete([instrument peer]));
    reading = instrument.measure(); again = peer.measure();
    verifyEqual(t, reading, again);
    verifyEqual(t, reading.lambda, (380:4:780)');
    verifyTrue(t, all(isfinite(reading.radiance)) && all(reading.radiance >= 0));
    verifyTrue(t, all(isfinite(reading.XYZ)) && all(reading.XYZ > 0));
    verifyTrue(t, reading.isSynthetic);
    verifyEqual(t, reading.syntheticProfile, profiles(index).name);
    verifyEqual(t, reading.syntheticProfileIndex, index);
    % The driver's inclusive sum (docs/session/color-science.md), not trapz.
    verifyEqual(t, reading.totalRadiance, sum(reading.radiance) * 4);
    spectra(:, index) = reading.radiance; xyz(index, :) = reading.XYZ;
    clear cleanup
end
verifyEqual(t, size(unique(spectra', 'rows'), 1), numel(profiles));
ratio=max(spectra(:,12))/max(spectra(:,3));
verifyGreaterThanOrEqual(t,ratio,.01*.995/1.005);
verifyLessThanOrEqual(t,ratio,.01*1.005/.995);
verifyEqual(t, spectra(:,12), spectra(:,3)*ratio, 'AbsTol', 1e-18);
verifyEqual(t, xyz(12,:), xyz(3,:)*ratio, 'RelTol', 1e-12);
end

function testProfilesCycleWithoutInvalidData(t)
first = colormeasure.drivers.pr.DemoInstrument(1, 0); later = colormeasure.drivers.pr.DemoInstrument(13, 0);
cleanup = onCleanup(@() delete([first later]));
initial = first.measure();
nextCycle=later.measure();
verifyEqual(t,nextCycle.syntheticProfileIndex,initial.syntheticProfileIndex);
verifyNotEqual(t,nextCycle.radiance,initial.radiance);
verifyEqual(t,nextCycle.radiance/max(nextCycle.radiance), ...
    initial.radiance/max(initial.radiance),'AbsTol',1e-15);
for index = 2:numel(colormeasure.simulation.syntheticProfiles())
    reading = first.measure();
    verifyEqual(t, reading.syntheticProfileIndex, index);
    verifyTrue(t, all(isfinite(reading.radiance)) && all(reading.radiance >= 0));
    verifyTrue(t, all(isfinite(reading.XYZ)) && all(reading.XYZ > 0));
end
wrapped=first.measure(); % Same shape on the next cycle, with a different gain.
verifyEqual(t,wrapped,nextCycle);
end

function testSyntheticSessionNeedsNoWindow(t)
f = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
a = colormeasure.drivers.pr.adapter(); a.listPorts = @(~) "SYNTHETIC";
a.connect = @(~) colormeasure.drivers.pr.DemoInstrument(1, 0);
% Each injected virtual connection owns a fresh meter and no serial port.
a.release = @delete;
before = findall(groot, 'Type', 'figure');
s = colormeasure.session.Session(a, f.Folder); t.addTeardown(@() delete(s));
verifyTrue(t, s.measure('Sample 001', 'Synthetic'));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);
verifyTrue(t, s.measure('Sample 002', 'Synthetic'));
verifyFalse(t,s.chartIoUnconfirmed);verifyFalse(t,s.directCleanupCanRetry);
s.finish();
verifyTrue(t, s.finished); verifyEmpty(t, s.window);
verifyEqual(t, findall(groot, 'Type', 'figure'), before);
saved = load(s.files.mat);
verifyEqual(t, saved.measurements, s.measurements);
verifyTrue(t, all([saved.measurements.isSynthetic]));
verifyEqual(t, height(readtable(s.files.csv)), 202);
end

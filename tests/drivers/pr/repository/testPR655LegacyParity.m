function tests = testPR655LegacyParity
% TESTPR655LEGACYPARITY Execute original and opt-in drivers on identical bytes.
%   Original source stays in Devices/PR655. Only the temporary class name,
%   conversion dependency names and serial factory are substituted. The
%   measurement algorithms are unchanged. No physical port is opened.
%   Fernando Voltolini de Azambuja, 2026.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testsFolder = fileparts(fileparts(mfilename('fullpath')));
betaFolder = fullfile(colormeasuretest.projectRoot(),'src','+colormeasure','+drivers','+pr');
root = colormeasuretest.schoolRoot();
legacyFolder = fullfile(root,'Devices','PR655');
fixtureFolder = fullfile(testsFolder,'data','legacy');
colormeasuretest.setupPaths(testCase);
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(legacyFolder));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'Convert')));
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(temporary.Folder));
testCase.TestData.legacyFolder = legacyFolder;
testCase.TestData.betaFolder = betaFolder;
testCase.TestData.outputFolder = temporary.Folder;

% Frozen baseline identity prevents an edited old driver/data table from
% silently becoming the reference. See data/legacy/README.md for provenance.
checkDigest(testCase, fullfile(legacyFolder, 'PR655.m'), ...
    'bfb506f87205ac4b4398598622686439d6dbd16a671b1ea13c4ae51959990c60');
checkDigest(testCase, fullfile(root, 'Convert', 'ObsFunctions.mat'), ...
    '84a47bcc10921983bf182004d06b6f9339003201d39d8e83b8841914918de925');
checkDigest(testCase, fullfile(fixtureFolder, 'spec2XYZ.m.txt'), ...
    '3b63ebe1f9b34c295d3f5969eb3903630453e5274b3b074caf91a1b9e9a6d4a6');
checkDigest(testCase, fullfile(fixtureFolder, 'getObserverFunction.m.txt'), ...
    '5506394a87b3fb91e8536f0f0a7d3f4d9f9fdd6bea838a18d484cc51d49a05f0');

source = fileread(fullfile(legacyFolder, 'PR655.m'));
source = replaceOnce(source, 'classdef PR655 < handle', 'classdef LegacyPR655 < handle');
source = replaceOnce(source, 'function obj = PR655(varargin)', 'function obj = LegacyPR655(varargin)');
source = replaceOnce(source, 'serialport(portID,115200,', 'colormeasuretest.pr.LegacyPort(portID,115200,');
source = replaceOnce(source, 'spec2XYZ(obj.radiance, obj.wl)', 'legacySpec2XYZ(obj.radiance, obj.wl)');
writeText(fullfile(temporary.Folder, 'LegacyPR655.m'), source);
source = fileread(fullfile(fixtureFolder, 'spec2XYZ.m.txt'));
source = replaceOnce(source, 'function [XYZ] = spec2XYZ(', 'function [XYZ] = legacySpec2XYZ(');
source = replaceOnce(source, 'getObserverFunction(observer)', 'legacyGetObserverFunction(observer)');
writeText(fullfile(temporary.Folder, 'legacySpec2XYZ.m'), source);
source = fileread(fullfile(fixtureFolder, 'getObserverFunction.m.txt'));
source = replaceOnce(source, 'function [observer, lambda] = getObserverFunction(', ...
    'function [observer, lambda] = legacyGetObserverFunction(');
writeText(fullfile(temporary.Folder, 'legacyGetObserverFunction.m'), source);
testCase.addTeardown(@clearTemporaryFunctions);
end

function testOriginalAndNamespacedDriverCoexist(testCase)
verifyEqual(testCase, which('PR655'), fullfile(testCase.TestData.legacyFolder, 'PR655.m'));
verifyEqual(testCase, which('colormeasure.drivers.pr.PR655'), ...
    fullfile(testCase.TestData.betaFolder, 'PR655.m'));
end

function testIdenticalRepliesPreserveHistoryAndSavedValues(testCase)
wavelengths = (380:4:780)';
spectra = [0.01 + 0.03 * exp(-0.5 * ((wavelengths - 545) / 65).^2), ...
    0.2 * exp(-0.5 * ((wavelengths - 616) / 5).^2), ...
    1e-7 * sin(wavelengths / 7), zeros(size(wavelengths))];
configure(frame(spectra(:, 1)));
old = LegacyPR655('SYNTHETIC_ONLY');
testCase.addTeardown(@() delete(old));
new = colormeasuretest.pr.Driver('SYNTHETIC_ONLY', 'Timeout', 2);
testCase.addTeardown(@() delete(new));
for index = 1:size(spectra, 2)
    state = colormeasuretest.pr.state();
    state.chunks = {frame(spectra(:, index))};
    colormeasuretest.pr.state(state);
    originalCall(@() old.measure());
    reading = new.measure();
    verifyEqual(testCase, reading.lambda, old.wl);
    verifyEqual(testCase, reading.radiance, old.radiance(:, end));
    verifyEqual(testCase, new.radiance, old.radiance);
    verifyEqual(testCase, new.XYZ, old.XYZ, 'AbsTol', 1e-12, 'RelTol', 1e-12);
    verifyEqual(testCase, new.totalRadiance, old.totalRadiance);
end
legacy = struct('lambda', old.wl, 'radiance', old.radiance, ...
    'XYZ', old.XYZ, 'totalRadiance', old.totalRadiance);
beta = struct('lambda', new.wl, 'radiance', new.radiance, ...
    'XYZ', new.XYZ, 'totalRadiance', new.totalRadiance);
filename = fullfile(testCase.TestData.outputFolder, 'legacy-beta-parity.mat');
save(filename, 'legacy', 'beta');
saved = load(filename);
verifyEqual(testCase, saved.legacy, legacy);
verifyEqual(testCase, saved.beta, beta);
verifyEqual(testCase, saved.beta.XYZ, saved.legacy.XYZ, 'AbsTol', 1e-12, 'RelTol', 1e-12);
end

function testShortHeaderIsAnIntentionalParsingDifference(testCase)
spectrum = linspace(0.01, 0.02, 101)';
reply = frame(spectrum);
reply = strrep(reply, '00000,0,0.000e+000,1.827e-01,5.147e+01', '0,0,0,1,2');
configure(reply);
old = LegacyPR655('SYNTHETIC_ONLY');
testCase.addTeardown(@() delete(old));
new = colormeasuretest.pr.Driver('SYNTHETIC_ONLY', 'Timeout', 2);
testCase.addTeardown(@() delete(new));
oldError = [];
try
    originalCall(@() old.measure());
catch err
    oldError = err;
end
reading = new.measure();
verifyEqual(testCase, reading.lambda, (380:4:780)');
verifySize(testCase, reading.radiance, [101 1]);
verifyEqual(testCase, reading.radiance, spectrum, 'AbsTol', 1e-14);
verifyTrue(testCase, ~isempty(oldError) || ~isequal(old.wl, reading.lambda) || ...
    ~isequal(old.radiance, reading.radiance), ...
    'The original fixed-offset parser must not be mistaken for the corrected line parser.');
verifyEqual(testCase, reading.instrumentTotalRadiance, 1);
end

function testOriginalAutoSyncValuesArePreserved(testCase)
configure(frame(ones(101, 1)));
old = LegacyPR655('SYNTHETIC_ONLY');
testCase.addTeardown(@() delete(old));
new = colormeasuretest.pr.Driver('SYNTHETIC_ONLY', 'Timeout', 2);
testCase.addTeardown(@() delete(new));
originalCall(@() old.getFlicker());
new.getFlicker();
verifyEqual(testCase, new.flicker, old.flicker);
verifyEqual(testCase, new.flicker, 60);
state = colormeasuretest.pr.state();
state.flickerReply = '00000,None,0.00 Hertz';
colormeasuretest.pr.state(state);
originalCall(@() old.getFlicker());
new.getFlicker();
verifyTrue(testCase, isnan(old.flicker) && isnan(new.flicker));
end

function reply = frame(spectrum)
rows = sprintf('%d,%.12e\r\n', [(380:4:780); spectrum(:)']);
reply = [sprintf('00000,0,0.000e+000,1.827e-01,5.147e+01\r\n') rows];
end

function configure(reply)
colormeasuretest.pr.state(struct('ports', "SYNTHETIC_ONLY", 'listModes', {{}}, ...
    'onMac', false, 'openedPort', '', 'closed', false, 'commands', {{}}, ...
    'identityReply', '00000,PR-655', 'remoteReply', sprintf('REMOTE MODE\r\n'), ...
    'metadataReplies', struct('D110', '-1000', 'D114', '-1000', ...
        'D602', '-1000', 'D13', '-1000'), 'metadataUnterminated', {{}}, ...
    'flickerReply', '00000,Auto Sync,60.00 Hertz', 'echo', false, ...
    'failRestore', false, 'chunks', {{reply}}, 'delays', 0));
end

function originalCall(operation)
% The original clearBuffer changes all warning settings. Contain that side
% effect in the fixture without changing the original method being executed.
previous = warning;
cleanup = onCleanup(@() warning(previous));
operation();
end

function source = replaceOnce(source, before, after)
assert(isscalar(strfind(source, before)), ...
    'PR655Test:BaselineTransform', 'Expected exactly one frozen-source substitution.');
source = strrep(source, before, after);
end

function writeText(filename, source)
fid = fopen(filename, 'w');
assert(fid >= 0, 'PR655Test:FixtureWrite', 'Cannot create isolated legacy fixture.');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, source, 'char');
end

function checkDigest(testCase, filename, expected)
assert(isfile(filename), 'PR655Test:BaselineMissing', 'Cannot read baseline file: %s', filename);
actual = colormeasuretest.fileSha256(filename);
assertEqual(testCase, actual, expected, sprintf('Frozen baseline changed: %s', filename));
end

function clearTemporaryFunctions
clear LegacyPR655 legacySpec2XYZ legacyGetObserverFunction
end

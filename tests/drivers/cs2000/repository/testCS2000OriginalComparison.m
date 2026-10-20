function tests = testCS2000OriginalComparison
% Run the preserved original classes, not a reimplementation of their math.
% Common synthetic readings prove software compatibility, never lab parity.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
family = fileparts(fileparts(mfilename('fullpath')));
repo = colormeasuretest.schoolRoot();
testCase.TestData.path = path;
testCase.TestData.family = family;
testCase.TestData.source = fullfile(colormeasuretest.projectRoot(),'src','+colormeasure','+drivers','+cs2000');
testCase.TestData.repo = repo;
testCase.TestData.original = fullfile(repo,'Devices','MinoltaCS2000');
colormeasuretest.setupPaths(testCase);
addpath(testCase.TestData.original,fullfile(testCase.TestData.original,'Share'));
end

function teardownOnce(testCase)
path(testCase.TestData.path);
end

function setup(testCase)
testCase.TestData.casePath = path;
testCase.TestData.serialBefore = which('serial');
testCase.TestData.warning = warning;
testCase.TestData.originalObjects = {};
testCase.TestData.newObjects = {};
fixture = colormeasuretest.originalFixture('cs2000','original-serial');
addpath(fixture,'-begin');
% Check resolution BEFORE every original constructor, including rejection tests.
assertEqual(testCase,which('serial'),fullfile(fixture,'serial.m'));
for name = {'CS2000','CS2000manual','CS2000strobe','Spectroradiometer'}
    assertEqual(testCase,which(name{1}),fullfile(testCase.TestData.original,[name{1} '.m']));
end
assertEqual(testCase,which('COMClass'),fullfile(testCase.TestData.original,'Share','COMClass.m'));
end

function teardown(testCase)
restore = onCleanup(@()restorePath(testCase));
% Close originals explicitly while their fake transport is still installed.
for k = 1:numel(testCase.TestData.originalObjects)
    obj = testCase.TestData.originalObjects{k};
    if isvalid(obj)
        try
            obj.Disconnect();
        catch err
            verifyFail(testCase,['Original fixture disconnect failed: ' err.message]);
        end
        if isvalid(obj.serialPort), fclose(obj.serialPort); end
    end
end
% Original delete methods are protected. Dropping the final references invokes
% them naturally after Disconnect/fclose, still before restoring the path.
testCase.TestData.originalObjects = {};
clear obj
for k = 1:numel(testCase.TestData.newObjects)
    obj = testCase.TestData.newObjects{k};
    if isvalid(obj), delete(obj); end
end
testCase.TestData.newObjects = {};
clear obj restore
end

function restorePath(testCase)
path(testCase.TestData.casePath);
verifyEqual(testCase,which('serial'),testCase.TestData.serialBefore);
warning(testCase.TestData.warning);
end

function testEntireOriginalFamilyMatchesPinnedMainBytes(testCase)
manifest = jsondecode(fileread(fullfile(testCase.TestData.family, ...
    'fixtures','original-source.json')));
verifyEqual(testCase,manifest.sourceCommit,'ce4e63f19ad54617478ff84791483deec920532d');
for k = 1:numel(manifest.files)
    fileName = fullfile(testCase.TestData.repo,manifest.files(k).path);
    actual = colormeasuretest.fileSha256(fileName);
    verifyEqual(testCase,actual,manifest.files(k).sha256,manifest.files(k).path);
end
for name = {'CS2000','CS2000manual','CS2000Gonio','Spectroradiometer','COMClass'}
    verifyEqual(testCase,which(['colormeasure.drivers.cs2000.' name{1}]), ...
        fullfile(testCase.TestData.source,[name{1} '.m']));
end
end

function testLegacyFixtureRejectsEveryNonSentinelPortAndEmptyRead(testCase)
% setup has already established that this resolves to our strict fake class.
% The school CS-2000 code constructs MathWorks' retired serial class, so the
% fixture keeps that name on purpose; the Analyzer's SERIAL message is expected
% on these three calls only and suppressed here, never globally. A green
% comparison shows that our driver reproduces the pinned school behaviour in
% software; it does not show that the school code runs on a current MATLAB.
verifyError(testCase,@()serial('COM4'),'cs2000test:HardwareForbidden'); %#ok<SERIAL>
verifyError(testCase,@()serial('/dev/cu.usbserial'),'cs2000test:HardwareForbidden'); %#ok<SERIAL>
peer = serial('SIM-LEGACY-CS2000'); cleanup = onCleanup(@()delete(peer)); %#ok<SERIAL>
verifyTrue(testCase,isa(peer,'serial'));
verifyFalse(testCase,isa(peer,'Serial'));
fopen(peer);
verifyError(testCase,@()fscanf(peer),'cs2000test:LegacyTimeout');
verifyError(testCase,@()fprintf(peer,'UNEXPECTED'),'cs2000test:LegacyCommand');
fclose(peer);
end

function testOrdinaryTwoReadingSignedSpectraAndXYZMatch(testCase)
[old,legacy,new,peer] = pair(testCase);
for k = 1:2
    spectrum = (380:780)'/1000*k; spectrum([1 100 201]) = [-0.01;0;0.125]*k;
    xyz = [-1;0;3]*k;
    reading(legacy,peer,spectrum,xyz);
    old.Measure(); new.Measure();
    verifyEqual(testCase,old.spectralData,new.spectralData);
    verifyEqual(testCase,old.XYZData,new.XYZData);
end
verifySize(testCase,old.spectralData,[401 2]);
verifySize(testCase,new.XYZData,[3 2]);
verifyEqual(testCase,numel(new.metadata),2);
end

function testSavedArraysMatchAcrossTheOriginalAndCurrentLayouts(testCase)
% The original saves separate spectral and XYZ arrays; the current driver saves
% one native snapshot. For the same readings the saved numbers must agree
% (docs/drivers/cs2000/original-comparison.md). Neither file is loaded by the
% other driver. The folder name contains a space; the original's eval-based
% Save takes only a simple file name, so it saves from inside that folder.
[old,legacy,new,peer] = pair(testCase);
for k = 1:2
    spectrum = (380:780)'/1000*k; spectrum([1 100 201]) = [-0.01;0;0.125]*k;
    reading(legacy,peer,spectrum,[-1;0;3]*k);
    old.Measure(); new.Measure();
end
folder = fullfile(testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder,'saved arrays');
mkdir(folder);
saveOriginalInFolder(old,folder,'original.mat'); new.Save(fullfile(folder,'current.mat'));
savedOld = load(fullfile(folder,'original.mat')); savedNew = load(fullfile(folder,'current.mat'));
verifyEqual(testCase,savedNew.measurements.spectralData,savedOld.spectralData);
verifyEqual(testCase,savedNew.measurements.XYZData,savedOld.XYZData);
verifySize(testCase,savedOld.spectralData,[401 2]);
end

function testConnectionAndSlot99DifferencesAreExplicit(testCase)
[old,legacy,new,peer] = pair(testCase);
verifyEqual(testCase,legacy.BaudRate,9600);
verifyEqual(testCase,legacy.Commands,{'RMT,1','BALS,1,0','SPMS,0','OBSS,0'});
verifyEqual(testCase,peer.State('commands'),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0','DTCR'});
slotBefore = legacy.StoredSpectrum;
old.Measure(); new.Measure();
verifyNotEqual(testCase,legacy.StoredSpectrum,slotBefore);
verifyEqual(testCase,legacy.StoredSpectrum,legacy.CurrentSpectrum);
verifyTrue(testCase,any(strcmp(legacy.Commands,'STDS,99')));
verifyFalse(testCase,any(startsWith(peer.State('commands'),{'STDS,','STDR,'})));
state = peer.State;
old.Disconnect(); new.Disconnect();
verifyEqual(testCase,legacy.Commands(end-1:end),{'BALS,1,0','RMT,0'});
commands = state('commands');
verifyEqual(testCase,commands(end-1:end),{'BALS,1,1','RMTS,0'});
end

function testConditionsCommonFieldsMatchAndOldMappingDiffers(testCase)
[old,legacy,new,peer] = pair(testCase);
legacy.Conditions = '0,1,002000000,1,0,1,2,07';
peer.queue('MEDR,0,0,1',sprintf('OK00,%s\r\n',legacy.Conditions));
old.Measure(); old.StoreMeasurementConditions(); new.Measure();
for field = {'speedMode','syncMode','integrationTime','internalNDFilter','closeupLens'}
    verifyEqual(testCase,old.measurementConditions.(field{1}),new.measurementConditions.(field{1}));
end
verifyFalse(testCase,isfield(old.measurementConditions,'externalNDFilter'));
verifyEqual(testCase,old.measurementConditions.measurementAngle,1);
verifyEqual(testCase,old.measurementConditions.userCalibrationChannel,2);
verifyEqual(testCase,new.measurementConditions.externalNDFilter,1);
verifyEqual(testCase,new.measurementConditions.measurementAngle,2);
verifyEqual(testCase,new.measurementConditions.userCalibrationChannel,7);
end

function testOriginal002PauseIsFractionWhileV2RetainsIntegerSeconds(testCase)
[old,~,new] = pair(testCase);
pauseBefore = which('pause');
fixture = colormeasuretest.originalFixture('cs2000','original-pause');
beforePath = path; cleanup = onCleanup(@()path(beforePath));
colormeasuretest.cs2000.pauseLog('reset'); addpath(fixture,'-begin');
assertEqual(testCase,which('pause'),fullfile(fixture,'pause.m'));
old.Measure();
calls = colormeasuretest.cs2000.pauseLog('read');
verifyEqual(testCase,nnz(calls == 0.002),1);
clear cleanup
assertEqual(testCase,which('pause'),pauseBefore);
new.Measure();
verifyEqual(testCase,new.metadata(1).acquisition.announcedDurationSeconds,2);
end

function testBlockFailureExposesOldPartialHistoryAndV2Atomicity(testCase)
[old,legacy,new,peer] = pair(testCase);
old.Measure(); new.Measure(); beforeSpectrum = new.spectralData; beforeXYZ = new.XYZData;
legacy.queue('STDR,99,1,0,04','ER20');
peer.queue('MEDR,1,0,4',sprintf('ER20\r\n'));
exception = colormeasuretest.captureError(@()old.Measure()); assertNotEmpty(testCase,exception);
verifyEqual(testCase,exception.message,'ER20');
verifyError(testCase,@()new.Measure(),'CS2000:InstrumentError');
verifySize(testCase,old.spectralData,[401 1]); verifySize(testCase,old.XYZData,[3 2]);
verifyEqual(testCase,new.spectralData,beforeSpectrum); verifyEqual(testCase,new.XYZData,beforeXYZ);
verifyEqual(testCase,numel(new.metadata),1);
verifyTrue(testCase,old.isConnected()); verifyTrue(testCase,new.isConnected());
end

function testBenignNumericExpressionIsEvaluatedOnlyByOriginal(testCase)
[old,legacy,new,peer] = pair(testCase);
legacy.queue('STDR,99,2,0,01','OK00,1+2,2,3');
peer.queue('MEDR,2,0,01',sprintf('OK00,1+2,2,3\r\n'));
old.Measure();
verifyEqual(testCase,old.XYZData,[3;2;3]);
verifyError(testCase,@()new.Measure(),'CS2000:NumericPayload');
verifyEmpty(testCase,new.XYZData); verifyEmpty(testCase,new.spectralData);
verifyTrue(testCase,new.isConnected());
end

function testManualOriginalReadsStaleSlotWithoutXYZAndV2ReadsFresh(testCase)
[old,legacy] = original(testCase,'CS2000manual');
[new,peer] = improved(testCase,@colormeasure.drivers.cs2000.CS2000manual);
old.Connect(); new.Connect();
oldSlot = -ones(401,1)*0.123;
legacy.StoredSpectrum = oldSlot;
fresh = (380:780)'/1000;
reading(legacy,peer,fresh,[1;2;3]);
old.MeasureManual(); new.MeasureManual();
verifyEqual(testCase,old.spectralData,oldSlot); verifyEmpty(testCase,old.XYZData);
verifyFalse(testCase,any(strcmp(legacy.Commands,'STDS,99')));
verifyEqual(testCase,legacy.Speed,'3,002000000,0');
verifyEqual(testCase,new.spectralData,fresh); verifyEqual(testCase,new.XYZData,[1;2;3]);
verifyEqual(testCase,numel(new.metadata),1);
commands = peer.State('commands'); verifyEqual(testCase,commands{end},'SPMS,0,2');
end

function testOriginalStrobeNeverTriggersAndOrdinaryAcquisitionMatches(testCase)
[old,legacy] = original(testCase,'CS2000strobe');
[new,peer] = improved(testCase,@colormeasure.drivers.cs2000.CS2000);
old.Connect(); new.Connect();
flash = colormeasuretest.cs2000.Flash;
old.MeasureStrobe(flash,0);
verifyEqual(testCase,flash.Count,0);
verifySize(testCase,old.spectralData,[401 1]);
reading(legacy,peer,(380:780)'/1000,[95.047;100;108.883]);
old.Measure(); new.Measure();
verifyEqual(testCase,old.spectralData(:,end),new.spectralData);
verifyEqual(testCase,old.XYZData(:,end),new.XYZData);
end

function saveOriginalInFolder(obj,folder,fileName)
% The original Save builds a command-syntax save with eval. Save from inside
% the folder and restore the current folder, also when that Save fails.
previousFolder = pwd;
restore = onCleanup(@()cd(previousFolder));
cd(folder);
obj.Save(fileName);
end

function [old,legacy,new,peer] = pair(testCase)
[old,legacy] = original(testCase,'CS2000');
[new,peer] = improved(testCase,@colormeasure.drivers.cs2000.CS2000);
old.Connect(); new.Connect();
end

function [old,legacy] = original(testCase,name)
fixture = fullfile(colormeasuretest.originalFixture('cs2000','original-serial'),'serial.m');
assertEqual(testCase,which('serial'),fixture);
factory = str2func(name); old = factory('SIM-LEGACY-CS2000');
testCase.TestData.originalObjects{end+1} = old;
legacy = old.serialPort;
assertTrue(testCase,isa(legacy,'serial'));
end

function [obj,peer] = improved(testCase,factory)
peer = colormeasuretest.cs2000.Port;
obj = factory('SIM','Transport',peer,'ResponseTimeout',0.05);
testCase.TestData.newObjects{end+1} = obj;
end

function reading(legacy,peer,spectrum,xyz)
legacy.CurrentSpectrum = spectrum; legacy.CurrentXYZ = xyz;
for k = 1:4
    first = (k-1)*100+1; last = k*100; if k == 4, last = 401; end
    peer.queue(sprintf('MEDR,1,0,%d',k), ...
        ['OK00' sprintf(',%.17g',spectrum(first:last)) sprintf('\r\n')]);
end
peer.queue('MEDR,2,0,01',['OK00' sprintf(',%.17g',xyz) sprintf('\r\n')]);
end

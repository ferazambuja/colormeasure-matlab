function tests = testCROriginalComparison
% Execute the preserved original classes as well as qualified v2 classes.
% Synthetic fixtures establish software differences, never hardware parity.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
family = fileparts(fileparts(mfilename('fullpath')));
repo = colormeasuretest.schoolRoot();
testCase.TestData.path = path;
testCase.TestData.repo = repo;
testCase.TestData.family = family;
testCase.TestData.source = fullfile(colormeasuretest.projectRoot(),'src','+colormeasure','+drivers','+cr');
colormeasuretest.setupPaths(testCase);
addpath(fullfile(repo,'Convert'),fullfile(repo,'Devices','Colorimetry_Research'));
end

function teardownOnce(testCase)
path(testCase.TestData.path);
end

function setup(testCase)
testCase.TestData.casePath = path;
testCase.TestData.warning = warning;
testCase.TestData.serialBefore = which('serialport');
% Only this test's duration shadows the worker's rejecting serialport guard.
% The replacement rejects every request except a registered in-memory peer.
stubFolder = colormeasuretest.originalFixture('cr','original-serial');
addpath(stubFolder,'-begin');
assertEqual(testCase,which('serialport'),fullfile(stubFolder,'serialport.m'));
for model = {'CR100','CR250','CR300'}
    assertEqual(testCase,which(model{1}),fullfile(testCase.TestData.repo, ...
        'Devices','Colorimetry_Research',[model{1} '.m']));
end
end

function teardown(testCase)
colormeasuretest.cr.originalTransport('clear');
path(testCase.TestData.casePath);
verifyEqual(testCase,which('serialport'),testCase.TestData.serialBefore);
warning(testCase.TestData.warning);
end

function testOriginalFilesMatchPinnedMainBytes(testCase)
manifest = jsondecode(fileread(fullfile(testCase.TestData.family, ...
    'fixtures','original-source.json')));
verifyEqual(testCase,manifest.sourceCommit,'ce4e63f19ad54617478ff84791483deec920532d');
for k = 1:numel(manifest.files)
    fileName = fullfile(testCase.TestData.repo,manifest.files(k).path);
    file = fopen(fileName,'rb');
    assertGreaterThanOrEqual(testCase,file,0,['Missing baseline file: ' fileName]);
    cleanup = onCleanup(@()fclose(file));
    bytes = fread(file,Inf,'*uint8');
    expected = manifest.files(k).sha256;
    if ~isempty(manifest.files(k).executableLinesSha256)
        % Shared conversion documentation may evolve without changing math.
        % This is a line fingerprint, not a general MATLAB parser: preserve
        % every character of retained lines, including inline comments.
        lines = regexp(native2unicode(bytes.','UTF-8'),'\r\n|\r|\n','split');
        keep = ~cellfun(@(line) isempty(strtrim(line)) || ...
            startsWith(strtrim(line),'%'),lines);
        bytes = unicode2native(strjoin(lines(keep),newline),'UTF-8');
        expected = manifest.files(k).executableLinesSha256;
    end
    actual = colormeasuretest.sha256(bytes);
    verifyEqual(testCase,actual,expected);
    clear cleanup
end
for model = {'CR100','CR250','CR300'}
    verifyEqual(testCase,which(model{1}),fullfile(testCase.TestData.repo, ...
        'Devices','Colorimetry_Research',[model{1} '.m']));
    verifyEqual(testCase,which(['colormeasure.drivers.cr.' model{1}]),fullfile(testCase.TestData.source,[model{1} '.m']));
end
end

function testOriginalFixtureCannotOpenAnUnregisteredPort(testCase)
verifyError(testCase,@()serialport('COM4',115200),'crtest:HardwareForbidden');
end

function testCR100OriginalAndV2MatchNormalValuesAndSavedArrays(testCase)
[old,legacy,new,peer] = pair(testCase,'CR-100');
xyz = [95.047 100 108.883];
queueXYZ(legacy,xyz); queueXYZ(peer,xyz);
old.Measure(); new.Measure();
verifyCommon(testCase,old,new);
oldFile = [tempname '.mat']; newFile = [tempname '.mat'];
testCase.addTeardown(@()delete(oldFile)); testCase.addTeardown(@()delete(newFile));
old.Save(oldFile); new.Save(newFile);
a = load(oldFile,'measurements'); b = load(newFile,'measurements');
for name = {'XYZ','CCT','Duv'}
    verifyEqual(testCase,a.measurements.(name{1}),b.measurements.(name{1}),'AbsTol',1e-7);
end
verifyFalse(testCase,isfield(a.measurements,'identity'));
verifyTrue(testCase,isfield(b.measurements,'identity'));
end

function testCR250OriginalAndV2MatchNumericalPipeline(testCase)
compareSpectrum(testCase,'CR-250',2);
end

function testCR300OriginalAndV2MatchNumericalPipeline(testCase)
compareSpectrum(testCase,'CR-300',1);
end

function compareSpectrum(testCase,model,step)
[old,legacy,new,peer] = pair(testCase,model);
wavelength = 380:step:780;
values = 0.001*ones(size(wavelength)); values(1) = -0.00001;
queueSpectrum(legacy,wavelength,values,true);
queueSpectrum(peer,wavelength,values,false);
old.Measure(); new.Measure();
verifyEqual(testCase,old.wl,new.wl);
verifyEqual(testCase,old.radiance,new.spectralData,'AbsTol',1e-15);
verifyEqual(testCase,old.totalRadiance,new.integratedSpectrum,'AbsTol',1e-12);
verifyCommon(testCase,old,new);
verifyEqual(testCase,new.metadata.radiometricUnit,'W/(m^2 sr)');
verifyLessThan(testCase,new.spectralData(1),0);
end

function testCanonicalCRLFExposesOriginalSpectralParserFailure(testCase)
for entry = {{'CR-250',2},{'CR-300',1}}
    item = entry{1}; [old,legacy,new,peer] = pair(testCase,item{1});
    wavelength = 380:item{2}:780; values = 0.001*ones(size(wavelength));
    queueSpectrum(legacy,wavelength,values,false);
    queueSpectrum(peer,wavelength,values,false);
    exception = colormeasuretest.captureError(@()old.Measure());
    % Canonical CRLF gives the original parser a nonscalar colon bound.
    % The supported MATLAB release must expose that failure, not accept it.
    assertNotEmpty(testCase,exception);
    verifyEqual(testCase,exception.identifier,'MATLAB:colon:operandsNotRealScalar');
    new.Measure();
    verifyEqual(testCase,new.spectralData,values);
end
end

function testShortValidXYZExposesOriginalFixedByteWait(testCase)
[old,legacy,new,peer] = pair(testCase,'CR-100');
reply = sprintf('OK:0:RM XYZ:1,1,1\r\n');
legacy.queue('RM XYZ',reply); peer.queue('RM XYZ',reply);
verifyError(testCase,@()old.Measure(),'crtest:OriginalWaitBound');
new.Measure(); verifyEqual(testCase,new.XYZ,[1 1 1]);
end

function testDefaultRetryAndFailureHistoryIntentionallyDiffer(testCase)
[old,legacy,new,peer] = pair(testCase,'CR-100');
reply = sprintf('ER:-305:M:Light intensity too low\r\n');
for k = 1:3, legacy.queue('M',reply); end
peer.queue('M',reply);
old.Measure();
verifyError(testCase,@()new.Measure(),'CR:InstrumentError');
verifyEqual(testCase,nnz(strcmp(legacy.Peer.State('commands'),'M')),3);
verifyEqual(testCase,nnz(strcmp(peer.State('commands'),'M')),1);
verifyTrue(testCase,all(isnan(old.XYZ)));
verifyEmpty(testCase,new.XYZ); verifyEmpty(testCase,new.metadata);
% A subsequent explicit call succeeds without connecting again.
queueXYZ(peer,[95.047 100 108.883]); new.Measure();
verifySize(testCase,new.XYZ,[1 3]);
end

function testMalformedXYZOriginalPartialCommitIsPreventedInV2(testCase)
[old,legacy,new,peer] = pair(testCase,'CR-100');
reply = sprintf('OK:0:RM XYZ:1.000000000000e+00,2.000000000000e+00\r\n');
legacy.queue('RM XYZ',reply); peer.queue('RM XYZ',reply);
verifyNotEmpty(testCase,colormeasuretest.captureError(@()old.Measure()));
verifyEqual(testCase,old.XYZ,[1 2]); verifyEmpty(testCase,old.CCT);
verifyError(testCase,@()new.Measure(),'CR:NumericPayload');
verifyEmpty(testCase,new.XYZ); verifyEmpty(testCase,new.CCT);
verifyFalse(testCase,peer.State('deleted'));
end

function testBlackAndExtremeCCTPreserveXYZButMarkV2Unavailable(testCase)
for xyz = {[0 0 0],[1.005139268121361 1 2.014285859586932]}
    [old,legacy,new,peer] = pair(testCase,'CR-100');
    queueXYZ(legacy,xyz{1}); queueXYZ(peer,xyz{1});
    old.Measure(); new.Measure();
    verifyEqual(testCase,old.XYZ,new.XYZ);
    verifyTrue(testCase,isfinite(old.CCT));
    verifyTrue(testCase,isnan(new.CCT) && isnan(new.Duv));
    if all(xyz{1} == 0)
        verifyEqual(testCase,old.CCT,0); verifyEqual(testCase,old.Duv,Inf);
    else
        verifyEqual(testCase,old.CCT,25000);
    end
end
end

function testNonRadianceQuantityRetainsDataWithExplicitV2Labels(testCase)
for type = 1:3
    [old,legacy,new,peer] = pair(testCase,'CR-250');
    wavelength = 380:2:780; values = 0.001*ones(size(wavelength));
    queueSpectrum(legacy,wavelength,values,true);
    queueSpectrum(peer,wavelength,values,false);
    peer.queue('RM Radiometric',sprintf('OK:0:RM Radiometric:%d,0.402,1e10\r\n',type));
    old.Measure(); new.Measure();
    verifyEqual(testCase,old.radiance,new.spectralData);
    verifyEqual(testCase,old.totalRadiance,new.integratedSpectrum,'AbsTol',1e-12);
    verifyTrue(testCase,all(isfinite(new.spectralData)) && isfinite(new.integratedSpectrum));
    verifyEqual(testCase,new.metadata.radiometricType,type);
    verifyFalse(testCase,any(strcmp(legacy.Peer.State('commands'),'RM Radiometric')));
end
end

function testEmptyEraseOriginalErrorAndV2NoOp(testCase)
[old,~,new] = pair(testCase,'CR-100');
verifyNotEmpty(testCase,colormeasuretest.captureError(@()old.Erase()));
new.Erase(); new.EraseAll(); verifyEmpty(testCase,new.XYZ);
end

function testSaveOriginalWarningMutationIsPreventedInV2(testCase)
[old,~,new] = pair(testCase,'CR-100');
fileName = [tempname '.mat']; testCase.addTeardown(@()delete(fileName));
warning('off','MATLAB:structOnObject'); old.Save(fileName);
state = warning('query','MATLAB:structOnObject'); verifyEqual(testCase,state.state,'on');
warning('off','MATLAB:structOnObject'); new.Save(fileName);
state = warning('query','MATLAB:structOnObject'); verifyEqual(testCase,state.state,'off');
end

function [old,legacy,new,peer] = pair(testCase,model)
legacy = colormeasuretest.cr.OriginalPort(model);
colormeasuretest.cr.originalTransport('set',legacy);
factory = str2func(strrep(model,'-','')); old = factory('CR-ORIGINAL-SIM');
testCase.addTeardown(@()delete(legacy));
peer = colormeasuretest.cr.Port(model);
factory = str2func(['colormeasure.drivers.cr.' strrep(model,'-','')]);
new = factory('SIM','Transport',peer,'ResponseTimeout',0.3,'MeasurementTimeout',0.3);
testCase.addTeardown(@()delete(new));
end

function queueXYZ(port,xyz)
port.queue('RM XYZ',sprintf('OK:0:RM XYZ:%.16e,%.16e,%.16e\r\n',xyz));
end

function queueSpectrum(port,wavelength,values,legacyLayout)
header = sprintf('OK:0:RM Spectrum:%g,%g,%g,%d\r\n', ...
    wavelength(1),wavelength(end),wavelength(2)-wavelength(1),numel(wavelength));
if legacyLayout
    % Numerical-pipeline fixture only: one CR lets the unchanged original
    % parser run. The extra LF accommodates its unconditional end-2 slice.
    % This mixed layout is NOT a verified device response or protocol claim.
    samples = [sprintf('%.12e\n',values) newline];
else
    samples = sprintf('%.12e\r\n',values);
end
port.queue('RM Spectrum',[header samples]);
end

function verifyCommon(testCase,old,new)
verifyEqual(testCase,old.XYZ,new.XYZ,'AbsTol',1e-10);
verifyEqual(testCase,old.CCT,new.CCT,'AbsTol',1e-6);
verifyEqual(testCase,old.Duv,new.Duv,'AbsTol',1e-10);
end

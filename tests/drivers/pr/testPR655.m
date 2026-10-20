function tests = testPR655
% Protocol regression tests. Driver overrides prevent all hardware access.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
% Make hidden legacy dependencies fail even when another checkout is installed.
blocked = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
for name = {'spec2XYZ','getObserverFunction'}
    fid = fopen(fullfile(blocked.Folder,[name{1} '.m']),'w');
    assert(fid>=0);
    fprintf(fid,'function varargout = %s(varargin)\nerror(''PR655Test:LegacyColorDependency'',''Use colormeasure.colorimetry.'');\nend\n',name{1});
    fclose(fid);
end
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(blocked.Folder));
end


function setup(~)
configure('PR-655');
end

function testTransportOptionRunsTheProtocolAgainstASubstitutedPort(testCase)
% The same seam the other families offer: a caller-owned port object stands
% in for serialport, and the driver's handshake, pacing and parsing run on it.
clock = colormeasuretest.FakeClock();
pr = colormeasure.drivers.pr.PR655('SIM-PR655', 'Transport', colormeasuretest.pr.Port(clock), 'Clock', clock);
cleanup = onCleanup(@() delete(pr));
verifyEqual(testCase, pr.portName, 'SIM-PR655');
m = pr.measure();
verifyEqual(testCase, m.lambda, (380:4:780)');
verifySize(testCase, m.XYZ, [1 3]);
end

function testSerialWritesUseFiniteCommandTimeout(testCase)
for timeout = [0.2 300]
    configure('PR-655');
    clock = colormeasuretest.FakeClock();
    port = colormeasuretest.pr.Port(clock);
    pr = colormeasure.drivers.pr.PR655('SIM','Transport',port,'Clock',clock,'Timeout',timeout);
    cleanup = onCleanup(@()colormeasuretest.dispose(pr));
    verifyTrue(testCase,port.EnableWriteTimeout);
    verifyEqual(testCase,port.Timeout,min(5,timeout));
    verifyEqual(testCase,pr.Timeout,timeout); % Acquisition deadline is separate.
    port.Timeout = 999; port.EnableWriteTimeout = false;
    pr.measure(); % An external transport reference cannot disable deadlines.
    verifyTrue(testCase,port.EnableWriteTimeout);
    verifyEqual(testCase,port.Timeout,min(5,timeout));
    clear cleanup
end
end

function testPartialWriteDoesNotRetryRestoreOrQuit(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.pr.Port(clock);
pr = colormeasure.drivers.pr.PR655('SIM','Transport',port,'Clock',clock);
cleanup = onCleanup(@()colormeasuretest.dispose(pr));
pr.measure();
before = struct('XYZ',pr.XYZ,'radiance',pr.radiance,'metadata',pr.instrumentMetadata);
port.WriteTimeoutPrefix = 'M5'; started = clock.now();
verifyError(testCase,@()pr.measure(),'SerialTest:WriteTimeout');
verifyEqual(testCase,clock.now()-started,port.Timeout+0.25,'AbsTol',1e-12);
verifyEqual(testCase,pr.XYZ,before.XYZ);
verifyEqual(testCase,pr.radiance,before.radiance);
verifyEqual(testCase,pr.instrumentMetadata,before.metadata);
state = colormeasuretest.pr.state(); attempts = state.writeAttempts;
verifyEqual(testCase,sum(strcmp(state.commands,'M5')),1);
verifyError(testCase,@()pr.measure(),'PR655:ReconnectRequired');
delete(pr);
state = colormeasuretest.pr.state();
verifyEqual(testCase,state.writeAttempts,attempts);
verifyTrue(testCase,state.closed);
clear cleanup
end

function testInitializationWriteTimeoutClosesWithoutFurtherCommands(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.pr.Port(clock);
port.WriteTimeoutPrefix = 'PH';
verifyError(testCase,@()colormeasure.drivers.pr.PR655('SIM','Transport',port,'Clock',clock), ...
    'SerialTest:WriteTimeout');
state = colormeasuretest.pr.state();
verifyTrue(testCase,state.closed);
verifyEqual(testCase,state.commands,{'Q'});
verifyEqual(testCase,state.writeAttempts,'QPH');
verifyEqual(testCase,clock.now(),5.6,'AbsTol',1e-12);
end

function testConfigurationFailureSendsNoCleanupAndKeepsHistory(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.pr.Port(clock);
pr = colormeasure.drivers.pr.PR655('SIM','Transport',port,'Clock',clock);
cleanup = onCleanup(@()colormeasuretest.dispose(pr)); pr.measure();
state = colormeasuretest.pr.state(); attempts = state.writeAttempts; previous = pr.XYZ;
port.ConfigurationFailure = true; started = clock.now();
verifyError(testCase,@()pr.measure(),'SerialTest:WriteConfiguration');
verifyEqual(testCase,pr.XYZ,previous);
verifyEqual(testCase,clock.now(),started);
verifyError(testCase,@()pr.measure(),'PR655:ReconnectRequired');
delete(pr); state = colormeasuretest.pr.state();
verifyEqual(testCase,state.writeAttempts,attempts);
verifyTrue(testCase,state.closed);
end

function testTransportWithoutWriteDeadlineCapabilityIsRefused(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.pr.LegacyPort();
verifyError(testCase,@()colormeasure.drivers.pr.PR655('SIM','Transport',port,'Clock',clock), ...
    'Measurement:WriteTimeoutUnsupported');
verifyEqual(testCase,clock.now(),0); % No command pacing or cleanup command.
verifyFalse(testCase,isvalid(port));
end

function testPR655OutputAndLegacyHistory(testCase)
pr = connect(testCase);
m = pr.measure();
verifyEqual(testCase, m.lambda, (380:4:780)');
verifyEqual(testCase, m.radiance, ones(101, 1));
verifyEqual(testCase, m.totalRadiance, 404);
verifySize(testCase, m.XYZ, [1 3]);
verifyTrue(testCase, all(isfinite(m.XYZ) & m.XYZ > 0));
verifyEqual(testCase, m.unitsCode, 0);
verifyEqual(testCase, m.xyzMethod, ...
    'colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1');
verifyEqual(testCase, m.peakWavelength, 0);
pr.measure(); % Legacy call with no output still appends one measurement.
verifyEqual(testCase, pr.radiance, ones(101, 2));
verifyEqual(testCase, pr.XYZ, repmat(m.XYZ, 2, 1));
verifyEqual(testCase, pr.totalRadiance, [404 404]);
verifyEqual(testCase, pr.wl, m.lambda);
verifyEmpty(testCase, pr.errorCode);
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands(1:3), {'Q', 'PHOTO', 'D111'});
verifyEqual(testCase, state.commands(4:end), ...
    {'B00', 'M5', 'B100', 'B00', 'M5', 'B100'});
end

function testDefaultMetadataDoesNotQueryEitherModel(testCase)
for model = {'PR-655', 'PR-670'}
    configure(model{1});
    state = colormeasuretest.pr.state();
    state.metadataReplies = struct(); % Any accidental metadata query must fail.
    state.flickerReply = '';
    colormeasuretest.pr.state(state);
    pr = connect(testCase);
    verifyFalse(testCase, pr.Metadata);
    first = pr.measure(); second = pr.measure();
    verifyEmpty(testCase, first.instrumentMetadata.serialNumber);
    verifyFalse(testCase, first.instrumentMetadata.metadataQueriesRequireReconnect);
    names = fieldnames(first.instrumentMetadata.queries);
    for index = 1:numel(names)
        record = first.instrumentMetadata.queries.(names{index});
        verifyEqual(testCase, record.status, 'notQueried');
        verifyEmpty(testCase, record.rawReply);
    end
    verifyEqual(testCase, pr.instrumentMetadata, ...
        [first.instrumentMetadata second.instrumentMetadata]);
    state = colormeasuretest.pr.state();
    verifyEqual(testCase, state.commands, ...
        {'Q', 'PHOTO', 'D111', 'B00', 'M5', 'B100', 'B00', 'M5', 'B100'});
    delete(pr);
end
end

function testMetadataOptionMustBeExplicitLogical(testCase)
verifyError(testCase, @() colormeasuretest.pr.Driver('COM3', 'Metadata', 'false', 'Clock', colormeasuretest.FakeClock()), ...
    'MATLAB:InputParser:ArgumentFailedValidation');
state = colormeasuretest.pr.state();
verifyEmpty(testCase, state.openedPort);
end

function testMetadataReportsAndMatRoundTrip(testCase)
pr = connect(testCase, 'COM3', 'Timeout', 2, 'Metadata', true);
measurement = pr.measure();
metadata = measurement.instrumentMetadata;
verifyTrue(testCase, pr.Metadata);
verifyEqual(testCase, metadata.serialNumber, '655 SAMPLE-1');
verifyEqual(testCase, metadata.softwareVersion, '2.22D beta');
verifyEqual(testCase, metadata.currentSetup.aperture, '1 deg');
verifyEqual(testCase, metadata.currentSetup.exposureMode, 'Adaptive');
verifyEqual(testCase, metadata.currentSetup.exposureTime, '0 msec');
verifyEqual(testCase, metadata.lastMeasurementExposure.gain, 'Fast');
verifyEqual(testCase, metadata.lastMeasurementExposure.exposureMilliseconds, 16500);
verifyEqual(testCase, metadata.synchronization.mode, 'Auto Sync');
verifyEqual(testCase, metadata.synchronization.frequencyHertz, 60);
verifyFalse(testCase, metadata.metadataQueriesRequireReconnect);
names = fieldnames(metadata.queries);
for index = 1:numel(names)
    record = metadata.queries.(names{index});
    verifyEqual(testCase, record.status, 'available');
    verifyNotEmpty(testCase, record.rawReply);
    verifyEqual(testCase, strsplit(record.rawReply, ',', 'CollapseDelimiters', false), record.fields);
    verifyEmpty(testCase, record.errorIdentifier);
end
verifyEqual(testCase, pr.instrumentMetadata, metadata);
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
file = fullfile(folder.Folder, 'metadata.mat');
save(file, 'measurement');
loaded = load(file);
verifyEqual(testCase, loaded.measurement, measurement);
state = colormeasuretest.pr.state();
verifyEqual(testCase, sum(strcmp(state.commands, 'M5')), 1);
end

function testMetadataIdentityCachedButSettingsRefresh(testCase)
pr = connect(testCase, 'COM3', 'Timeout', 2, 'Metadata', true);
first = pr.measure();
state = colormeasuretest.pr.state();
state.metadataReplies.D110 = '0,CHANGED ON WIRE';
state.metadataReplies.D13 = '0,Normal,125 msec';
state.metadataReplies.D602 = strrep(state.metadataReplies.D602, ',Adaptive,0 msec,', ',Fixed,125 msec,');
colormeasuretest.pr.state(state);
second = pr.measure();
verifyEqual(testCase, second.instrumentMetadata.serialNumber, first.instrumentMetadata.serialNumber);
verifyEqual(testCase, second.instrumentMetadata.lastMeasurementExposure.exposureMilliseconds, 125);
verifyEqual(testCase, second.instrumentMetadata.currentSetup.exposureMode, 'Fixed');
verifyEqual(testCase, first.instrumentMetadata.lastMeasurementExposure.exposureMilliseconds, 16500);
verifyEqual(testCase, pr.instrumentMetadata, [first.instrumentMetadata second.instrumentMetadata]);
state = colormeasuretest.pr.state();
verifyEqual(testCase, sum(strcmp(state.commands, 'D110')), 1);
verifyEqual(testCase, sum(strcmp(state.commands, 'D114')), 1);
verifyEqual(testCase, sum(strcmp(state.commands, 'D602')), 2);
verifyEqual(testCase, sum(strcmp(state.commands, 'D13')), 2);
verifyEqual(testCase, sum(strcmp(state.commands, 'D14')), 2);
verifyEqual(testCase, sum(strcmp(state.commands, 'M5')), 2);
end

function testUnsupportedMetadataKeepsReadingAndAllowsNext(testCase)
state = colormeasuretest.pr.state();
state.metadataReplies.D110 = '-1000';
state.metadataReplies.D114 = '-1035';
state.metadataReplies.D602 = '-2000';
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', 2, 'Metadata', true);
first = pr.measure();
second = pr.measure();
for name = {'serialNumber', 'softwareVersion', 'currentSetup'}
    record = first.instrumentMetadata.queries.(name{1});
    verifyEqual(testCase, record.status, 'unsupported');
    verifyEqual(testCase, record.errorIdentifier, 'PR655:InstrumentError');
end
verifyEmpty(testCase, first.instrumentMetadata.serialNumber);
verifyEmpty(testCase, first.instrumentMetadata.softwareVersion);
verifyEqual(testCase, first.instrumentMetadata.queries.lastMeasurementExposure.status, 'available');
verifyFalse(testCase, first.instrumentMetadata.metadataQueriesRequireReconnect);
verifyEqual(testCase, fieldnames(first.instrumentMetadata), fieldnames(second.instrumentMetadata));
verifySize(testCase, pr.radiance, [101 2]);
verifyEqual(testCase, pr.instrumentMetadata, [first.instrumentMetadata second.instrumentMetadata]);
state = colormeasuretest.pr.state();
verifyEqual(testCase, sum(strcmp(state.commands, 'M5')), 2);
verifyEqual(testCase, sum(strcmp(state.commands, 'D110')), 1);
verifyEqual(testCase, sum(strcmp(state.commands, 'D602')), 2);
end

function testMetadataTimeoutRetainsSpectrumAndStopsQueries(testCase)
state = colormeasuretest.pr.state();
state.metadataReplies.D110 = '0,PARTIAL';
state.metadataUnterminated = {'D110'};
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .15, 'Metadata', true);
measurement = pr.measure();
verifySize(testCase, measurement.radiance, [101 1]);
verifySize(testCase, pr.radiance, [101 1]);
verifyEqual(testCase, pr.instrumentMetadata, measurement.instrumentMetadata);
verifyTrue(testCase, measurement.instrumentMetadata.metadataQueriesRequireReconnect);
verifyEqual(testCase, measurement.instrumentMetadata.queries.serialNumber.status, 'error');
verifyEqual(testCase, measurement.instrumentMetadata.queries.serialNumber.errorIdentifier, 'PR655:Timeout');
verifyEqual(testCase, measurement.instrumentMetadata.queries.serialNumber.rawReply, '0,PARTIAL');
verifyEqual(testCase, measurement.instrumentMetadata.queries.softwareVersion.status, 'notQueried');
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands(4:end), {'B00', 'M5', 'D110', 'B100'});
verifyReconnectRequired(testCase, pr);
verifyEmpty(testCase, pr.errorCode); % The spectrum itself succeeded.
end

function testMalformedMetadataRetainsPriorAndCurrentHistories(testCase)
pr = connect(testCase, 'COM3', 'Timeout', 2, 'Metadata', true);
first = pr.measure();
state = colormeasuretest.pr.state();
state.metadataReplies.D13 = '0,Fast,NaN msec';
colormeasuretest.pr.state(state);
second = pr.measure();
verifyEqual(testCase, pr.radiance, [first.radiance second.radiance]);
verifyEqual(testCase, pr.instrumentMetadata, [first.instrumentMetadata second.instrumentMetadata]);
verifyTrue(testCase, second.instrumentMetadata.metadataQueriesRequireReconnect);
verifyEqual(testCase, second.instrumentMetadata.queries.lastMeasurementExposure.status, 'error');
verifyEqual(testCase, second.instrumentMetadata.queries.lastMeasurementExposure.rawReply, '0,Fast,NaN msec');
verifyEqual(testCase, second.instrumentMetadata.queries.synchronization.status, 'notQueried');
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands(12:end), {'B00', 'M5', 'D602', 'D13', 'B100'});
verifyReconnectRequired(testCase, pr);
end

function testInvalidMetadataIdentityTextIsNotInvented(testCase)
for text = {'0,   ', ['0,SN' char(1)], '0,SN,EXTRA'}
    configure('PR-655');
    state = colormeasuretest.pr.state();
    state.metadataReplies.D110 = text{1};
    colormeasuretest.pr.state(state);
    pr = connect(testCase, 'COM3', 'Timeout', 2, 'Metadata', true);
    measurement = pr.measure();
    verifyEmpty(testCase, measurement.instrumentMetadata.serialNumber);
    verifyTrue(testCase, measurement.instrumentMetadata.metadataQueriesRequireReconnect);
    verifyEqual(testCase, measurement.instrumentMetadata.queries.serialNumber.errorIdentifier, 'PR655:InvalidResponse');
    verifySize(testCase, pr.radiance, [101 1]);
    verifyReconnectRequired(testCase, pr);
    delete(pr);
end
end

function testPR670NativeSampling(testCase)
configure('PR-670');
pr = connect(testCase);
m = pr.measure();
verifyEqual(testCase, m.deviceType, 'PR-670');
verifyEqual(testCase, m.lambda, (380:2:780)');
verifyEqual(testCase, m.radiance, ones(201, 1));
verifyEqual(testCase, m.totalRadiance, 402);
verifySize(testCase, pr.XYZ, [1 3]);
verifyEqual(testCase, m.instrumentTotalRadiance, 1.827e-1);
verifyEqual(testCase, m.integratedPhotonRadiance, 5.147e1);
end

function testExtraSpectralRowsAreRejectedBeforeHistoryCommit(testCase)
for model={'PR-655','PR-670'}
    for tail={sprintf('784,1\r\n'),'784,','unexpected'}
        configure(model{1}); pr=connect(testCase); pr.measure();
        before=pr.radiance; state=colormeasuretest.pr.state();
        state.chunks{1}=[state.chunks{1} tail{1}];
        colormeasuretest.pr.state(state);
        verifyError(testCase,@() pr.measure(),'PR655:InvalidSpectrum');
        verifyEqual(testCase,pr.radiance,before);
        verifyReconnectRequired(testCase,pr); delete(pr);
    end
end
end

function testComplexSpectralHeaderCannotEnterMeasurementMetadata(testCase)
for index=1:5
    configure('PR-655'); state=colormeasuretest.pr.state();
    frame=state.chunks{1}; first=strfind(frame,sprintf('\r\n'));
    header={'0','0','550','1','3'};header{index}='1+2i';
    state.chunks{1}=[strjoin(header,',') sprintf('\r\n') frame(first(1)+2:end)];
    colormeasuretest.pr.state(state); pr=connect(testCase);
    verifyError(testCase,@() pr.measure(),'PR655:InvalidResponse');
    verifyEmpty(testCase,pr.radiance); verifyEmpty(testCase,pr.instrumentMetadata);
    verifyReconnectRequired(testCase,pr);delete(pr);
end
configure('PR-655'); state=colormeasuretest.pr.state();
state.chunks{1}=strrep(state.chunks{1},'1.000e+00','1+2i');
colormeasuretest.pr.state(state);pr=connect(testCase);
verifyError(testCase,@() pr.measure(),'PR655:InvalidSpectrum');
verifyEmpty(testCase,pr.radiance);verifyReconnectRequired(testCase,pr);
end

function testFragmentedReplyAndTemporaryEmptyBuffer(testCase)
state = colormeasuretest.pr.state();
frame = state.chunks{1};
% Split inside the header and inside a spectral row; the last part arrives
% 0.2 s after the second. The native row count, not a pause, ends the reply.
state.chunks = {frame(1:7), frame(8:105), frame(106:end)};
state.delays = [0 .05 .25];
state.echo = true;
colormeasuretest.pr.state(state);
pr = connect(testCase);
m = pr.measure();
verifySize(testCase, m.radiance, [101 1]);
end

function testReplyLineLimitAllowsBothNativeMultiLineSpectra(testCase)
for model={'PR-655','PR-670'}
    configure(model{1});state=colormeasuretest.pr.state();
    % Total reply is large; each raw line remains below the resource bound.
    frame=strrep(state.chunks{1},sprintf('\r\n'),[repmat(' ',1,100) sprintf('\r\n')]);
    verifyGreaterThan(testCase,numel(frame),4096);
    state.chunks={frame};state.echo=true;colormeasuretest.pr.state(state);
    pr=connect(testCase);measurement=pr.measure();
    step=4;if strcmp(model{1},'PR-670'),step=2;end
    verifyEqual(testCase,measurement.lambda,(380:step:780)');
    verifyEqual(testCase,measurement.radiance,ones(numel(measurement.lambda),1));
    state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
    delete(pr);
end
end

function testExactly4096RawBytesBeforeFragmentedCRLFRemainValid(testCase)
state=colormeasuretest.pr.state();frame=state.chunks{1};delimiter=strfind(frame,sprintf('\r\n'));
header=frame(1:delimiter(1)-1);header=[header repmat(' ',1,4096-numel(header))];
state.chunks={header,sprintf('\r'),[newline frame(delimiter(1)+2:end)]};
state.delays=[0 .08 .11];colormeasuretest.pr.state(state);
pr=connect(testCase);measurement=pr.measure();
verifyEqual(testCase,measurement.radiance,ones(101,1));
state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
end

function testExactly4096UnterminatedBytesWaitForTheDeadline(testCase)
state=colormeasuretest.pr.state();state.chunks={repmat(' ',1,4096)};
colormeasuretest.pr.state(state);pr=connect(testCase,'COM3','Timeout',.25);
verifyError(testCase,@()pr.measure(),'PR655:Timeout');
clock=testCase.TestData.clock;verifyEqual(testCase,sum(clock.Sleeps==.01),25);
verifyEmpty(testCase,pr.radiance);verifyReconnectRequired(testCase,pr);
state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
end

function testOversizedRawLinesRefuseBeforeHistoryOrUnboundedRead(testCase)
for bytes=[4097 65536]
    for terminator={sprintf('\r\n'),''}
        configure('PR-655');pr=connect(testCase);pr.measure();
        before=struct('radiance',pr.radiance,'XYZ',pr.XYZ,'metadata',pr.instrumentMetadata);
        header='0,0,550,1,3';state=colormeasuretest.pr.state();
        state.chunks={[header repmat(' ',1,bytes-numel(header)) terminator{1}]};
        colormeasuretest.pr.state(state);
        verifyError(testCase,@()pr.measure(),'PR655:Framing');
        verifyEqual(testCase,pr.radiance,before.radiance);verifyEqual(testCase,pr.XYZ,before.XYZ);
        verifyEqual(testCase,pr.instrumentMetadata,before.metadata);
        verifyReconnectRequired(testCase,pr);
        state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
        delete(pr);
    end
end
end

function testOversizedMetadataRetainsSpectrumAndBoundedRawPrefix(testCase)
state=colormeasuretest.pr.state();state.metadataReplies.D110=['0,' repmat('X',1,65536)];
colormeasuretest.pr.state(state);pr=connect(testCase,'COM3','Metadata',true);
measurement=pr.measure();record=measurement.instrumentMetadata.queries.serialNumber;
verifyEqual(testCase,record.status,'error');verifyEqual(testCase,record.errorIdentifier,'PR655:Framing');
verifyEqual(testCase,numel(record.rawReply),4097);verifyEmpty(testCase,measurement.instrumentMetadata.serialNumber);
verifyEqual(testCase,measurement.instrumentMetadata.queries.softwareVersion.status,'notQueried');
verifyTrue(testCase,measurement.instrumentMetadata.metadataQueriesRequireReconnect);
verifyEqual(testCase,pr.radiance,measurement.radiance);verifyEmpty(testCase,pr.errorCode);
verifyReconnectRequired(testCase,pr);
state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
end

function testOversizedSettingsLineRetainsOnlyABoundedRawPrefix(testCase)
state=colormeasuretest.pr.state();
state.settingsReplyOverrides=struct('D601',['0,' repmat('X',1,65536) sprintf('\r\n')]);
colormeasuretest.pr.state(state);pr=connect(testCase);report=pr.readSettings();
record=report.responses(strcmp({report.responses.command},'D601'));
verifyEqual(testCase,record.status,'error');verifyEqual(testCase,record.errorIdentifier,'PR655:Framing');
verifyEqual(testCase,numel(record.rawReply),4097);
verifyReconnectRequired(testCase,pr);
state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
end

function testSurplusWhitespaceUsesTheSameLineBound(testCase)
for route={'spectrum','settings'}
    configure('PR-655');state=colormeasuretest.pr.state();
    if strcmp(route{1},'spectrum')
        state.chunks{1}=[state.chunks{1} repmat(' ',1,65536)];
    else
        [~,reply,state]=colormeasuretest.pr.settingsReply('D116',state);
        state.settingsReplyOverrides=struct('D116',[reply repmat(' ',1,65536)]);
    end
    colormeasuretest.pr.state(state);pr=connect(testCase);
    if strcmp(route{1},'spectrum')
        verifyError(testCase,@()pr.measure(),'PR655:Framing');verifyEmpty(testCase,pr.radiance);
    else
        report=pr.readSettings();record=report.responses(strcmp({report.responses.command},'D116'));
        verifyEqual(testCase,record.status,'error');verifyEqual(testCase,record.errorIdentifier,'PR655:Framing');
    end
    verifyReconnectRequired(testCase,pr);
    state=colormeasuretest.pr.state();verifyLessThanOrEqual(testCase,max(state.readCounts),4097);
    delete(pr);
end
end

function testVariableLengthHeader(testCase)
state = colormeasuretest.pr.state();
state.chunks = {strrep(state.chunks{1}, ...
    '00000,0,0.000e+000,1.827e-01,5.147e+01', '0,0,0,12345,67')};
colormeasuretest.pr.state(state);
pr = connect(testCase);
m = pr.measure();
verifyEqual(testCase, m.instrumentTotalRadiance, 12345);
verifyEqual(testCase, m.integratedPhotonRadiance, 67);
verifyEqual(testCase, m.lambda(1), 380);
end

function testInstrumentErrorDoesNotAppendOrRetry(testCase)
pr = connect(testCase);
pr.measure();
state = colormeasuretest.pr.state();
state.chunks = {sprintf('-8\r\n')};
colormeasuretest.pr.state(state);
verifyError(testCase, @() pr.measure(), 'PR655:InstrumentError');
verifySize(testCase, pr.radiance, [101 1]);
verifySize(testCase, pr.XYZ, [1 3]);
verifyEqual(testCase, pr.errorCode.identifier, 'PR655:InstrumentError');
state = colormeasuretest.pr.state();
verifyEqual(testCase, sum(strcmp(state.commands, 'M5')), 2);
verifyEqual(testCase, state.commands{end}, 'B100');
end

function testSynchronizationErrorsPreserveHistoryAndWaitForExplicitRetry(testCase)
codes = [-3 -9 -10];
meanings = {'20 Hz', 'Synchronization error', 'automatically synchronize'};
for model = {'PR-655', 'PR-670'}
    configure(model{1});
    pr = connect(testCase);
    pr.measure();
    previousSpectrum = pr.radiance;
    previousXYZ = pr.XYZ;
    for index = 1:numel(codes)
        state = colormeasuretest.pr.state();
        before = numel(state.commands);
        state.chunks = {sprintf('%d\r\n', codes(index))};
        colormeasuretest.pr.state(state);
        verifyError(testCase, @() pr.measure(), 'PR655:InstrumentError');
        verifySubstring(testCase, pr.errorCode.message, sprintf('M5 returned instrument error %d', codes(index)));
        verifySubstring(testCase, pr.errorCode.message, meanings{index});
        verifyEqual(testCase, pr.radiance, previousSpectrum);
        verifyEqual(testCase, pr.XYZ, previousXYZ);
        state = colormeasuretest.pr.state();
        % One exposure request, no setting changes or automatic retry.
        verifyEqual(testCase, state.commands(before+1:end), {'B00', 'M5', 'B100'});
    end
end
end

function testUnknownInstrumentErrorRetainsCodeAndManualGuidance(testCase)
state = colormeasuretest.pr.state();
state.chunks = {sprintf('-9876\r\n')};
colormeasuretest.pr.state(state);
pr = connect(testCase);
verifyError(testCase, @() pr.measure(), 'PR655:InstrumentError');
verifySubstring(testCase, pr.errorCode.message, 'M5 returned instrument error -9876');
verifySubstring(testCase, pr.errorCode.message, 'Remote Control Error Codes');
verifyEmpty(testCase, pr.radiance);
end

function testRejectMalformedHeader(testCase)
assertBadFrame(testCase, sprintf('0,0,NaN,1,2\r\n'), 'PR655:InvalidResponse');
end

function testRejectWrongHeaderFieldCount(testCase)
assertBadFrame(testCase, sprintf('0,0,1\r\n'), 'PR655:InvalidResponse');
end

function testRejectInvalidStatus(testCase)
assertBadFrame(testCase, sprintf('oops,0,0,1,2\r\n'), 'PR655:InvalidResponse');
end

function testErrorCodeWithExtraFieldsRequiresReconnect(testCase)
assertBadFrame(testCase, sprintf('-8,extra\r\n'), 'PR655:InvalidResponse');
end

function testSpectralRowCannotMasqueradeAsErrorCode(testCase)
assertBadFrame(testCase, sprintf('380,1\r\n'), 'PR655:InvalidResponse');
end

function testPositiveStatusRequiresReconnect(testCase)
assertBadFrame(testCase, sprintf('1\r\n'), 'PR655:InvalidResponse');
end

function testRejectMalformedSpectralRow(testCase)
assertBadFrame(testCase, sprintf('0,0,0,1,2\r\n380,NaN\r\n'), 'PR655:InvalidSpectrum');
end

function testRejectWrongWavelengthGrid(testCase)
assertBadFrame(testCase, sprintf('0,0,0,1,2\r\n382,1\r\n'), 'PR655:WavelengthGrid');
end

function testRejectTruncatedSpectrum(testCase)
assertBadFrame(testCase, sprintf('0,0,0,1,2\r\n380,1\r\n'), 'PR655:Timeout');
end

function testRejectUnterminatedLastRow(testCase)
state = colormeasuretest.pr.state();
frame = state.chunks{1};
assertBadFrame(testCase, frame(1:end-2), 'PR655:Timeout');
end

function testSilentMeterTimeout(testCase)
assertBadFrame(testCase, '', 'PR655:Timeout');
end

function testTimeoutRunsOnSimulatedTimeWithTheDriversOwnPacing(testCase)
% The clock seam replaces only the wall clock: the driver keeps its 10 ms
% poll, 50 ms per command character and 0.5 s remote-mode wait, and the
% timeout is raised on the first poll at or past the deadline.
state = colormeasuretest.pr.state(); state.chunks = {''}; colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
clock = testCase.TestData.clock; started = clock.now();
verifyError(testCase, @() pr.measure(), 'PR655:Timeout');
elapsed = clock.now() - started;
% B00\r (4 characters) and M5\r (3), 25 polls to the 0.25 s deadline, then
% B100\r (5) restoring the backlight: 12 x 0.05 + 25 x 0.01.
verifyEqual(testCase, elapsed, .85, 'AbsTol', 1e-9);
% Every wait went through the simulated clock; none was waited for real.
verifyTrue(testCase, all(ismember(clock.Sleeps, [0.01 0.05 0.5])));
verifyEqual(testCase, sum(clock.Sleeps == 0.01), 25); % The first poll at or past the deadline ends the wait.
verifyEqual(testCase, sum(clock.Sleeps == 0.05), 23); % Q, PHOTO, D111\r, B00\r, M5\r, B100\r.
verifyEqual(testCase, sum(clock.Sleeps == 0.5), 1);   % Once, after leaving remote mode.
end

function testReplyArrivingDuringTheLastPollIntervalIsRead(testCase)
% The M5 frame becomes available 5 ms before the final poll at the 0.25 s
% deadline. That poll reads it rather than reporting a timeout, and the
% driver waits no longer than its 25 polls.
state = colormeasuretest.pr.state(); state.delays = .295; colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
measurement = pr.measure();
verifyEqual(testCase, measurement.radiance, ones(101,1));
clock = testCase.TestData.clock;
verifyEqual(testCase, sum(clock.Sleeps == 0.01), 25);
end

function testWallClockIsTheDefaultBehindEveryDeadline(testCase)
% Without 'Clock' the driver runs on colormeasure.drivers.RealClock, so an
% instrument sees the pacing the seam left unchanged: connecting alone costs
% the 0.5 s remote-mode wait plus eleven paced characters. Every other test
% here injects a simulated clock through connect.
wall = tic;
pr = colormeasuretest.pr.Driver('COM3', 'Timeout', 2);
testCase.addTeardown(@() delete(pr));
verifyClass(testCase, pr.injectedClock(), 'colormeasure.drivers.RealClock');
verifyGreaterThanOrEqual(testCase, toc(wall), 1);
end

function testDeadlineAppliesToWholeSpectrum(testCase)
state = colormeasuretest.pr.state();
frame = state.chunks{1};
state.chunks = {frame(1:50), frame(51:100), frame(101:end)};
% The last chunk falls due 0.34 s after the M5 carriage return: after the
% whole-spectrum deadline (0.30 s: 0.05 s of pacing plus 0.25 s), before a
% deadline restarted per row would expire (0.37 s, measured from the second
% chunk), and before the backlight acknowledgement (0.50 s). A driver that
% restarted the deadline per row would therefore complete the spectrum and
% fail this test; a 0.5 s delay tied with the acknowledgement exactly and
% left their order to floating-point rounding.
state.delays = [0 .12 .34];
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
clock = testCase.TestData.clock; started = clock.now();
% Late spectral bytes also prevent a clean backlight acknowledgement.
% The cleanup warning must not replace the original timeout exception.
verifyWarning(testCase, @() verifyError(testCase, @() pr.measure(), ...
    'PR655:Timeout'), 'PR655:BacklightRestore');
elapsed = clock.now() - started;
verifyGreaterThanOrEqual(testCase, elapsed, .25); % One deadline for the whole spectrum.
verifyLessThan(testCase, elapsed, 1.5);           % Deadline plus command pacing and cleanup.
verifyEmpty(testCase, pr.radiance);
end

function testRestoreFailurePreservesMeasurementError(testCase)
state = colormeasuretest.pr.state();
state.failRestore = true;
state.chunks = {sprintf('-8\r\n')};
colormeasuretest.pr.state(state);
pr = connect(testCase);
testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('PR655:BacklightRestore'));
verifyError(testCase, @() pr.measure(), 'PR655:InstrumentError');
verifyEqual(testCase, pr.errorCode.identifier, 'PR655:InstrumentError');
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands{end}, 'B100');
end

function testLateSpectrumCannotBecomeNextMeasurement(testCase)
state = colormeasuretest.pr.state();
state.delays = .95; % Arrives after timeout and the cleanup acknowledgement.
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
verifyError(testCase, @() pr.measure(), 'PR655:Timeout');
state = colormeasuretest.pr.state();
commands = state.commands;
% A second M5 would finish later than the outstanding first measurement.
state.chunks = {strrep(state.chunks{1}, '1.000e+00', '2.000e+00')};
state.delays = 2;
colormeasuretest.pr.state(state);
verifyError(testCase, @() pr.measure(), 'PR655:ReconnectRequired');
verifyError(testCase, @() pr.getFlicker(), 'PR655:ReconnectRequired');
verifyEmpty(testCase, pr.radiance);
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands, commands);
end

function testCompleteInstrumentErrorCanRetry(testCase)
state = colormeasuretest.pr.state();
frame = state.chunks{1};
state.chunks = {sprintf('-8\r\n')};
colormeasuretest.pr.state(state);
pr = connect(testCase);
verifyError(testCase, @() pr.measure(), 'PR655:InstrumentError');
state = colormeasuretest.pr.state();
state.chunks = {frame};
colormeasuretest.pr.state(state);
measurement = pr.measure();
verifySize(testCase, measurement.radiance, [101 1]);
verifySize(testCase, pr.radiance, [101 1]);
verifyEmpty(testCase, pr.errorCode);
end

function testRestoreFailureKeepsDataButRequiresReconnect(testCase)
state = colormeasuretest.pr.state();
state.failRestore = true;
colormeasuretest.pr.state(state);
pr = connect(testCase);
verifyWarning(testCase, @() pr.measure(), 'PR655:BacklightRestore');
verifySize(testCase, pr.radiance, [101 1]);
verifySize(testCase, pr.XYZ, [1 3]);
verifyReconnectRequired(testCase, pr);
end

function testFlickerTimeoutRequiresReconnect(testCase)
state = colormeasuretest.pr.state();
state.flickerReply = ''; % No complete, nonempty response to D14.
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
verifyError(testCase, @() pr.getFlicker(), 'PR655:Timeout');
verifyReconnectRequired(testCase, pr);
end

function testExplicitWindowsPortAndDelete(testCase)
pr = colormeasuretest.pr.Driver("COM12", 'Clock', colormeasuretest.FakeClock());
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.openedPort, 'COM12');
verifyEmpty(testCase, state.listModes);
verifyEqual(testCase, pr.portName, 'COM12');
delete(pr);
state = colormeasuretest.pr.state();
verifyTrue(testCase, state.closed);
verifyEqual(testCase, state.commands{end}, 'Q');
end

function testAutomaticSingleCandidate(testCase)
pr = connect(testCase, '');
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.openedPort, char(state.ports(1)));
verifyEqual(testCase, pr.deviceType, 'PR-655');
verifyEqual(testCase, pr.portName, state.openedPort);
verifyEqual(testCase, state.listModes, {'available'});
verifyEqual(testCase, state.commands, {'Q', 'PHOTO', 'D111'});
end

function testAutomaticLinuxPortNames(testCase)
for port = ["/dev/ttyACM0", "/dev/ttyUSB0"]
    configure('PR-655');
    state = colormeasuretest.pr.state();
    state.onMac = false;
    state.ports = port;
    colormeasuretest.pr.state(state);
    pr = connect(testCase, '');
    verifyEqual(testCase, pr.portName, char(port));
    delete(pr);
end
end

function testAutomaticMacAliasPairAndTtyOnly(testCase)
state = colormeasuretest.pr.state();
state.onMac = true;
state.ports = ["/dev/tty.usbserial123", "/dev/cu.usbserial123", "/dev/cu.usbserial123"];
colormeasuretest.pr.state(state);
pr = connect(testCase, "");
verifyEqual(testCase, pr.portName, '/dev/cu.usbserial123');
delete(pr);
state = colormeasuretest.pr.state();
state.ports = "/dev/tty.usbserial123";
colormeasuretest.pr.state(state);
pr = connect(testCase, "");
verifyEqual(testCase, pr.portName, '/dev/tty.usbserial123');
end

function testAutomaticWrongModelNeverMeasures(testCase)
state = colormeasuretest.pr.state();
state.identityReply = '00000,PR-650';
colormeasuretest.pr.state(state);
verifyError(testCase, @() colormeasuretest.pr.Driver('', 'Clock', colormeasuretest.FakeClock()), 'PR655:UnsupportedModel');
state = colormeasuretest.pr.state();
verifyTrue(testCase, state.closed);
verifyEqual(testCase, state.commands, {'Q', 'PHOTO', 'D111', 'Q'});
end

function testAutomaticIdentityTimeoutClosesWithoutMeasuring(testCase)
state = colormeasuretest.pr.state();
state.identityReply = '';
colormeasuretest.pr.state(state);
verifyError(testCase, @() colormeasuretest.pr.Driver('', 'Timeout', .1, 'Clock', colormeasuretest.FakeClock()), 'PR655:Timeout');
state = colormeasuretest.pr.state();
verifyTrue(testCase, state.closed);
verifyEqual(testCase, state.commands, {'Q', 'PHOTO', 'D111', 'Q'});
end

function testAutomaticNoCandidates(testCase)
state = colormeasuretest.pr.state();
state.ports = strings(1, 0);
colormeasuretest.pr.state(state);
verifyError(testCase, @() colormeasuretest.pr.Driver('', 'Clock', colormeasuretest.FakeClock()), 'PR655:NoPort');
state = colormeasuretest.pr.state();
verifyEmpty(testCase, state.openedPort);
verifyEmpty(testCase, state.commands);
end

function testAutomaticAmbiguousCandidates(testCase)
state = colormeasuretest.pr.state();
state.ports = [state.ports state.ports + "2"];
colormeasuretest.pr.state(state);
try
    colormeasuretest.pr.Driver('', 'Clock', colormeasuretest.FakeClock());
    verifyFail(testCase, 'Ambiguous ports must not connect.');
catch problem
    verifyEqual(testCase, problem.identifier, 'PR655:AmbiguousPort');
    for port = state.ports
        verifySubstring(testCase, problem.message, char(port));
    end
end
state = colormeasuretest.pr.state();
verifyEmpty(testCase, state.openedPort);
verifyEmpty(testCase, state.commands);
end

function testInitializationFailureQuitsAndCloses(testCase)
state = colormeasuretest.pr.state();
state.identityReply = '00000,PR-650';
colormeasuretest.pr.state(state);
verifyError(testCase, @() colormeasuretest.pr.Driver('COM3', 'Clock', colormeasuretest.FakeClock()), 'PR655:UnsupportedModel');
state = colormeasuretest.pr.state();
verifyTrue(testCase, state.closed);
verifyEqual(testCase, state.commands{end}, 'Q');
end

function testRemoteModeFailureCloses(testCase)
state = colormeasuretest.pr.state();
state.remoteReply = sprintf('wrong device\r\n');
colormeasuretest.pr.state(state);
verifyError(testCase, @() colormeasuretest.pr.Driver('COM3', 'Clock', colormeasuretest.FakeClock()), 'PR655:RemoteMode');
state = colormeasuretest.pr.state();
verifyTrue(testCase, state.closed);
end

function testInvalidPortNeverOpens(testCase)
verifyError(testCase, @() colormeasuretest.pr.Driver(12, 'Clock', colormeasuretest.FakeClock()), 'PR655:InvalidPort');
state = colormeasuretest.pr.state();
verifyEmpty(testCase, state.openedPort);
end

function testFlickerFrequencyWithUnits(testCase)
pr = connect(testCase);
verifyFalse(testCase, pr.Metadata);
pr.getFlicker();
verifyEqual(testCase, pr.flicker, 60);
state = colormeasuretest.pr.state();
state.flickerReply = '00000,None,0.00 Hertz';
colormeasuretest.pr.state(state);
pr.getFlicker();
verifyTrue(testCase, isnan(pr.flicker));
end

function testOverflowFlickerFrequencyRetainsPreviousValueAndRequiresReconnect(testCase)
pr=connect(testCase);pr.getFlicker();previous=pr.flicker;
state=colormeasuretest.pr.state();
state.flickerReply=['00000,Auto Sync,' repmat('9',1,400) ' Hertz'];
colormeasuretest.pr.state(state);
verifyError(testCase,@()pr.getFlicker(),'PR655:InvalidResponse');
verifyEqual(testCase,pr.flicker,previous);
verifyError(testCase,@()pr.measure(),'PR655:ReconnectRequired');
state=colormeasuretest.pr.state();verifyFalse(testCase,any(strcmp(state.commands,'M5')));
end

function testBacklightAcknowledgementComparesTheReportedLevel(testCase)
% Manual p.104 gives "Backlight set to nn %" without fixing zero padding or
% spacing. Those variations must not abort a measurement; a different level must.
pr = connect(testCase);
for format = {'Backlight set to %02d %%\r\n','Backlight set to %02d%%\r\n','BACKLIGHT SET TO %d%%\r\n'}
    state = colormeasuretest.pr.state();
    state.backlightFormat = format{1};
    colormeasuretest.pr.state(state);
    measurement = pr.measure();
    verifySize(testCase, measurement.radiance, [101 1], format{1});
    state = colormeasuretest.pr.state();
    verifyEqual(testCase, state.commands(end-2:end), {'B00','M5','B100'}, format{1});
end
state = colormeasuretest.pr.state();
state.backlightFormat = 'Backlight set to 1%d %%\r\n';
colormeasuretest.pr.state(state);
testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('PR655:BacklightRestore'));
verifyError(testCase, @() pr.measure(), 'PR655:InvalidResponse');
verifySize(testCase, pr.radiance, [101 3]);
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands(end-1:end), {'B00','B100'});
verifyReconnectRequired(testCase, pr);
end

function pr = connect(testCase, varargin)
if isempty(varargin)
    varargin = {'COM3', 'Timeout', 2};
end
% Deadlines, reply delays and pacing run on simulated time shared with the
% fake port; nothing here waits on the wall clock.
clock = colormeasuretest.FakeClock();
pr = colormeasuretest.pr.Driver(varargin{:}, 'Clock', clock);
testCase.TestData.clock = clock;
testCase.addTeardown(@() delete(pr));
end

function assertBadFrame(testCase, frame, identifier)
state = colormeasuretest.pr.state();
state.chunks = {frame};
colormeasuretest.pr.state(state);
pr = connect(testCase, 'COM3', 'Timeout', .25);
verifyError(testCase, @() pr.measure(), identifier);
verifyEmpty(testCase, pr.radiance);
verifyEmpty(testCase, pr.XYZ);
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands{end}, 'B100');
verifyReconnectRequired(testCase, pr);
end

function verifyReconnectRequired(testCase, pr)
state = colormeasuretest.pr.state();
commands = state.commands;
verifyError(testCase, @() pr.measure(), 'PR655:ReconnectRequired');
verifyError(testCase, @() pr.getFlicker(), 'PR655:ReconnectRequired');
state = colormeasuretest.pr.state();
verifyEqual(testCase, state.commands, commands);
end

function configure(model)
if ispc()
    ports = "COM3";
else
    ports = "/dev/cu.usbmodem101";
end
colormeasuretest.pr.configure('Model', model, 'Ports', ports, 'OnMac', ismac(), ...
    'D110', '00000,655 SAMPLE-1', 'D114', '00000,2.22D beta', 'D13', '00000,Fast,16500 msec');
end

function testNonzeroDecimalUnderflowCannotBecomeZeroHeaderStatusOrSpectrum(testCase)
for token={'1e-9999','-1e-9999'}
    assertBadFrame(testCase,sprintf('0,0,%s,1,2\r\n',token{1}),'PR655:InvalidResponse');
    assertBadFrame(testCase,sprintf('%s,0,0,1,2\r\n',token{1}),'PR655:InvalidResponse');
    assertBadFrame(testCase,sprintf('0,0,0,1,2\r\n380,%s\r\n',token{1}),'PR655:InvalidSpectrum');
end
end

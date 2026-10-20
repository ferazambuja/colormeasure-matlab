function tests = testCRInstrument
% Simulated public API tests; every constructor injects colormeasuretest.cr.Port.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testAllModelsInitializeAcquireAndDisconnect(testCase)
for model = {'CR-100','CR-250','CR-300'}
    [meter, port, state] = instrument(testCase,model{1});
    verifyEqual(testCase,meter.identity.model,model{1});
    verifyEqual(testCase,meter.identity.serialNumber,'SIM-001');
    verifyEqual(testCase,port.Terminator,'CR/LF');
    meter.Measure();
    verifyAligned(testCase,meter,1);
    verifyEqual(testCase,meter.instrumentXYZ,[95.047 100 108.883]);
    verifyEqual(testCase,meter.metadata(1).attempts,1);
    if strcmp(model{1},'CR-100')
        verifyEqual(testCase,meter.XYZ,meter.instrumentXYZ);
        verifyEmpty(testCase,meter.spectralData);
    else
        verifyEqual(testCase,meter.spectralData,0.001*ones(size(meter.wl)));
        verifyEqual(testCase,meter.integratedSpectrum,sum(meter.spectralData)*diff(meter.wl(1:2)),'AbsTol',1e-12);
        verifyEqual(testCase,meter.metadata(1).instrumentRadiometricValue,0.402);
    end
    meter.Disconnect(); meter.Disconnect();
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('deleteCount'),1);
    verifyError(testCase,@()meter.Measure(),'CR:Disconnected');
end
end

function testWrongModelClosesInitializationTransport(testCase)
port = colormeasuretest.cr.Port('CR-300'); state = port.State;
verifyError(testCase,@()colormeasure.drivers.cr.CR250('SIM','Transport',port),'CR:Identity');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RC Model'});
end

function testAllModelsEnableWriteDeadlines(testCase)
for model = {'CR-100','CR-250','CR-300'}
    clock = colormeasuretest.FakeClock(); port = colormeasuretest.cr.Port(model{1},clock);
    meter = colormeasuretest.cr.attach(testCase,model{1},port,clock,'ResponseTimeout',0.4);
    verifyTrue(testCase,port.EnableWriteTimeout);
    verifyEqual(testCase,port.Timeout,0.4);
    verifyEqual(testCase,meter.measurementTimeout,120);
end
end

function testInitializationWriteTimeoutClosesWithoutRetry(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cr.Port('CR-100',clock);
state = port.State; port.WriteTimeoutCommand = 'RC Model';
verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port, ...
    'Clock',clock,'ResponseTimeout',0.4),'SerialTest:WriteTimeout');
verifyEqual(testCase,clock.now(),0.4,'AbsTol',1e-12);
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RC Model'});
end

function testWriteTimeoutKeepsHistoryAndDoesNotAcquireAgain(testCase)
clock = colormeasuretest.FakeClock(); port = colormeasuretest.cr.Port('CR-250',clock);
meter = colormeasuretest.cr.attach(testCase,'CR-250',port,clock,'ResponseTimeout',0.4);
meter.Measure(); before = struct('XYZ',meter.XYZ,'spectrum',meter.spectralData,'metadata',meter.metadata);
state = port.State; port.WriteTimeoutCommand = 'M'; meter.repeatOnError = true;
meter.responseTimeout = 0.25;
started = clock.now();
verifyError(testCase,@()meter.Measure(),'SerialTest:WriteTimeout');
verifyEqual(testCase,clock.now()-started,0.25,'AbsTol',1e-12);
verifyEqual(testCase,state('writeTimeout'),0.25);
verifyTrue(testCase,state('deleted')); verifyEqual(testCase,state('deleteCount'),1);
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),2); % One success and one failed send.
verifyEqual(testCase,meter.XYZ,before.XYZ);
verifyEqual(testCase,meter.spectralData,before.spectrum);
verifyEqual(testCase,meter.metadata,before.metadata);
verifyAligned(testCase,meter,1);
verifyError(testCase,@()meter.Measure(),'CR:Disconnected');
end

function testConstructorTimeoutClosesTransport(testCase)
port = colormeasuretest.cr.Port('CR-100'); state = port.State;
port.queue('RC ID','');
verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port,'ResponseTimeout',0.03),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
end

function testConstructorRejectsTrailingIdentityData(testCase)
for discard = [false true]
    % Test trailing identity input after recovery, not host scheduling of a
    % 10 ms quiet interval. Driver and queued replies share the same clock.
    clock = colormeasuretest.FakeClock();
    port = colormeasuretest.cr.Port('CR-100',clock); state = port.State;
    if discard, port.inject('abandoned'); end
    port.queue('RC Firmware',sprintf('OK:0:RC Firmware:1.36\r\nUNEXPECTED\r\n'));
    verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port,'Clock',clock, ...
        'DiscardPendingInput',discard,'DrainQuietPeriod',0.01, ...
        'DrainTimeout',0.1),'CR:PendingInput');
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('commands'),{'RC Model','RC ID','RC Firmware'});
    verifyEqual(testCase,clock.now(),double(discard)*0.01,'AbsTol',1e-12);
end
end

function testFragmentedAndDelayedTerminators(testCase)
for ending = {newline,sprintf('\r'),sprintf('\r\n')}
    port = colormeasuretest.cr.Port('CR-250');
    text = ['OK:0:RC Model:CR-250' ending{1}];
    port.queue('RC Model',text,[3 numel(text)-4 1],[0 0.015 0.035]);
    text = ['OK:0:M:No errors' ending{1}];
    port.queue('M',text,[2 5 numel(text)-8 1],[0 0.01 0.02 0.03]);
    text = ['OK:0:RM Spectrum:380,780,2,201' ending{1} repmat(['0.001' ending{1}],1,201)];
    port.queue('RM Spectrum',text,[7 37 numel(text)-45 1],[0 0.005 0.02 0.035]);
    meter = attach(testCase,'CR-250',port);
    meter.Measure();
    verifyAligned(testCase,meter,1);
    verifyEqual(testCase,meter.wl,380:2:780);
end
end

function testMeasurementTimeoutNeverRetries(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
meter.measurementTimeout = 0.03; meter.repeatOnError = true;
text = sprintf('OK:0:M:No errors\r\n');
port.queue('M',text,numel(text),0.2);
verifyError(testCase,@()meter.Measure(),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),1);
verifyAligned(testCase,meter,0);
end

function testFailedMeasurementPreservesExistingHistory(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
meter.Measure(); original = snapshot(meter);
port.queue('M',sprintf('ER:-305:M:Light intensity too low or unmeasurable\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:InstrumentError');
verifyEqual(testCase,snapshot(meter),original);
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),2);
verifyFalse(testCase,state('deleted'));
verifyEqual(testCase,meter.errorCode,-305);
meter.Measure(); verifyAligned(testCase,meter,2);
end

function testPositiveMeasurementWarningIsRetained(testCase)
[meter,port] = instrument(testCase,'CR-100');
text = sprintf('OK:100:M:Light intensity too low for automatic sync\r\n');
port.queue('M',text); meter.Measure();
verifyEqual(testCase,meter.errorCode,100);
verifyEqual(testCase,meter.metadata(1).measurementResponses,{strtrim(text)});
verifyAligned(testCase,meter,1);
end

function testOptInRetryLimitResetsForEachCall(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
meter.repeatOnError = true;
previous = warning('off','CR:NewMeasurement');
testCase.addTeardown(@()warning(previous));
for attempt = 1:2
    port.queue('M',sprintf('ER:-305:M:Too low\r\n'));
    port.queue('M',sprintf('ER:-303:M:Fluctuating\r\n'));
    port.queue('M',sprintf('OK:0:M:No errors\r\n'));
    meter.Measure();
    verifyEqual(testCase,meter.metadata(end).attempts,3);
    verifyEqual(testCase,numel(meter.metadata(end).measurementResponses),3);
end
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),6);
verifyAligned(testCase,meter,2);
end

function testRetriesExhaustAtThreeAndDoNotAppend(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
meter.repeatOnError = true;
previous = warning('off','CR:NewMeasurement');
cleanup = onCleanup(@()warning(previous));
for k = 1:4, port.queue('M',sprintf('ER:-305:M:Too low\r\n')); end
verifyError(testCase,@()meter.Measure(),'CR:InstrumentError');
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),3);
verifyAligned(testCase,meter,0);
verifyFalse(testCase,state('deleted'));
end

function testNonrecoverableErrorIsNotRetried(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
meter.repeatOnError = true;
port.queue('M',sprintf('ER:-331:M:Hardware malfunction\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:InstrumentError');
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),1);
verifyAligned(testCase,meter,0);
end

function testCompleteMalformedXYZPreservesConnectionAndHistory(testCase)
for payload = {'1,2','1,2,3,4','1,,3','NaN,2,3','Inf,2,3','1e999,2,3','sin(1),2,3','1;2;3','1+2i,2,3'}
    [meter,port,state] = instrument(testCase,'CR-100');
    meter.Measure(); original = snapshot(meter);
    port.queue('RM XYZ',sprintf('OK:0:RM XYZ:%s\r\n',payload{1}));
    verifyError(testCase,@()meter.Measure(),'CR:NumericPayload');
    verifyEqual(testCase,snapshot(meter),original);
    verifyFalse(testCase,state('deleted'));
    meter.Measure(); verifyAligned(testCase,meter,2);
end
end

function testInconsistentSpectralHeadersAreRejected(testCase)
% One inconsistent grid, then consistent grids that each fail one other guard:
% the 10000-sample cap, a non-integer count, a reversed range, a start at zero.
for header = {'380,780,2,401','380,780,0.04,10001','380,781,2,201.5','780,380,-2,201','0,400,2,201'}
    [meter,port,state] = instrument(testCase,'CR-300');
    port.queue('RM Spectrum',sprintf('OK:0:RM Spectrum:%s\r\n',header{1}));
    verifyError(testCase,@()meter.Measure(),'CR:SpectrumHeader');
    verifyAligned(testCase,meter,0);
    verifyTrue(testCase,state('deleted'));
end
end

function testIncompleteSpectrumTimesOutWithoutCommit(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
meter.responseTimeout = 0.04;
port.queue('RM Spectrum',sprintf('OK:0:RM Spectrum:380,780,2,201\r\n0.01\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:Timeout');
verifyTrue(testCase,state('deleted'));
verifyAligned(testCase,meter,0);
end

function testMalformedAndExtraSpectralSamplesAreRejected(testCase)
for payload = {sprintf('0.01\r\nNaN\r\n'),sprintf('0.01\r\n0.02\r\n0.03\r\n')}
    [meter,port,state] = instrument(testCase,'CR-250');
    port.queue('RM Spectrum',['OK:0:RM Spectrum:500,501,1,2' sprintf('\r\n') payload{1}]);
    expected = 'CR:NumericPayload';
    if ~contains(payload{1},'NaN'), expected = 'CR:SpectrumCount'; end
    verifyError(testCase,@()meter.Measure(),expected);
    verifyEqual(testCase,state('deleted'),strcmp(expected,'CR:SpectrumCount'));
    verifyAligned(testCase,meter,0);
    if strcmp(expected,'CR:NumericPayload')
        meter.Measure(); verifyAligned(testCase,meter,1);
    end
end
end

function testSpectrumQueryErrorLeavesHistoryAligned(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
meter.Measure(); original = snapshot(meter);
port.queue('RM Spectrum',sprintf('ER:-500:Invalid command:Spectrum\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:InstrumentError');
verifyEqual(testCase,snapshot(meter),original);
verifyFalse(testCase,state('deleted'));
end

function testOverflowInDerivedCalculationDoesNotCommit(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
meter.Measure(); original = snapshot(meter);
text = [sprintf('OK:0:RM Spectrum:380,780,2,201\r\n') repmat(sprintf('1e308\r\n'),1,201)];
port.queue('RM Spectrum',text);
verifyError(testCase,@()meter.Measure(),'CR:DerivedOverflow');
verifyEqual(testCase,snapshot(meter),original);
verifyFalse(testCase,state('deleted'));
meter.Measure(); verifyAligned(testCase,meter,2);
end

function testChangedSampleCountRequiresNewHistory(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
meter.Measure(); original = snapshot(meter);
text = [sprintf('OK:0:RM Spectrum:380,780,1,401\r\n') repmat(sprintf('0.001\r\n'),1,401)];
port.queue('RM Spectrum',text);
verifyError(testCase,@()meter.Measure(),'CR:HistoryGrid');
verifyEqual(testCase,snapshot(meter),original);
verifyFalse(testCase,state('deleted'));
fileName = [tempname '.mat'];
testCase.addTeardown(@()delete(fileName));
meter.Save(fileName); meter.EraseAll();
port.queue('RM Spectrum',text); meter.Measure();
verifyAligned(testCase,meter,1);
verifyEqual(testCase,meter.wl,380:780);
end

function testAllRadiometricQuantitiesPreserveDataWithoutMislabeling(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
quantities = {'radiance','irradiance','radiant intensity','radiant flux'};
units = {'W/(m^2 sr)','W/m^2','W/sr','W'};
yUnits = {'cd/m^2','lx','cd','lm'};
for type = 0:3
    port.queue('RM Radiometric',sprintf('OK:0:RM Radiometric:%d,0.4,1e17\r\n',type));
    values = 0.001*ones(1,201); values(1) = -0.001;
    port.queue('RM Spectrum',[sprintf('OK:0:RM Spectrum:380,780,2,201\r\n') sprintf('%.6g\r\n',values)]);
    meter.Measure();
    verifyEqual(testCase,meter.spectralData(end,:),values);
    verifyEqual(testCase,meter.instrumentXYZ(end,:),[95.047 100 108.883]);
    verifyEqual(testCase,meter.metadata(end).radiometricType,type);
    verifyEqual(testCase,meter.metadata(end).radiometricQuantity,quantities{type+1});
    verifyEqual(testCase,meter.metadata(end).radiometricUnit,units{type+1});
    verifyEqual(testCase,meter.metadata(end).xyzUnit, ...
        [yUnits{type+1} ' (provisional: assumes per nm)']);
    verifyTrue(testCase,endsWith(meter.metadata(end).spectralDensityUnit, ...
        ' (provisional: assumes per nm)'));
    verifyFalse(testCase,meter.metadata(end).spectralDensityUnitsConfirmed);
    verifyEqual(testCase,meter.metadata(end).instrumentRadiometricValue,0.4);
    verifyEqual(testCase,meter.metadata(end).instrumentPhotonValue,1e17);
    verifyEqual(testCase,meter.integratedSpectrum(end),sum(values)*2,'AbsTol',1e-12);
end
verifyAligned(testCase,meter,4);
verifyTrue(testCase,all(isfinite(meter.spectralData),'all'));
verifyTrue(testCase,all(isfinite(meter.integratedSpectrum)));
verifyFalse(testCase,isprop(meter,'radiance'));
verifyFalse(testCase,isprop(meter,'totalRadiance'));
verifyFalse(testCase,isfield(meter.metadata,'instrumentTotalRadiance'));
verifyEqual(testCase,meter.XYZ,repmat(meter.XYZ(1,:),4,1));
verifyFalse(testCase,state('deleted'));
fileName = [tempname '.mat']; testCase.addTeardown(@()delete(fileName));
meter.Save(fileName); saved = load(fileName);
verifyEqual(testCase,saved.measurements.spectralData,meter.spectralData);
verifyEqual(testCase,saved.measurements.metadata,meter.metadata);
meter.Erase(); verifyAligned(testCase,meter,3);
meter.EraseAll(); verifyAligned(testCase,meter,0);
end

function testUnknownQuantityFailsWithoutLosingConnection(testCase)
[meter,port,state] = instrument(testCase,'CR-250');
for type = [-1 0.5 4]
    port.queue('RM Radiometric',sprintf('OK:0:RM Radiometric:%.2g,0.4,1e17\r\n',type));
    verifyError(testCase,@()meter.Measure(),'CR:Quantity');
    verifyAligned(testCase,meter,0);
    verifyFalse(testCase,state('deleted'));
end
meter.Measure(); verifyAligned(testCase,meter,1);
end

function testUnsupportedMetadataIsRecorded(testCase)
[meter,port] = instrument(testCase,'CR-250');
port.queue('RM Accessory',sprintf('ER:-500:Invalid command:Accessory\r\n'));
port.queue('RM CMF',sprintf('ER:-500:Invalid command:CMF\r\n'));
meter.Measure();
verifyAligned(testCase,meter,1);
responses=meter.metadata.metadataResponses;
verifySubstring(testCase,responses(strcmp({responses.field},'accessory')).response,'ER:-500:');
verifySubstring(testCase,responses(strcmp({responses.field},'cmfIndex')).response,'ER:-500:');
verifyFalse(testCase,any(isfield(meter.metadata, ...
    {'accessoryResponse','cmfResponse','calibrationResponse','matrixResponse'})));
end

function testFramingErrorsFailClosed(testCase)
for text = {sprintf('OK:0:RM XYZ:1,2,3\r\n'),sprintf('OK:-305:M:Wrong status\r\n'),sprintf('ER:0:M:Wrong status\r\n'),sprintf('>M\r\n'),sprintf('ER:-305:RM XYZ:Wrong command\r\n')}
    [meter,port,state] = instrument(testCase,'CR-100');
    port.queue('M',text{1});
    verifyError(testCase,@()meter.Measure(),'CR:Framing');
    verifyTrue(testCase,state('deleted'));
    verifyAligned(testCase,meter,0);
end
end

function testStaleInputIsNotDiscardedOrFollowedByMeasurement(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.inject(sprintf('OK:0:RM XYZ:1,2,3\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:PendingInput');
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),0);
verifyTrue(testCase,state('deleted'));
end

function testConstructorRejectsStaleInputWithoutSendingCommands(testCase)
port = colormeasuretest.cr.Port('CR-100'); state = port.State;
port.inject('abandoned response');
verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port),'CR:PendingInput');
verifyEmpty(testCase,state('commands'));
verifyTrue(testCase,state('deleted'));
end

function testExplicitDrainWaitsForFragmentedInputThenIdentifies(testCase)
clock = colormeasuretest.FakeClock();
port = colormeasuretest.cr.Port('CR-100',clock); state = port.State;
port.inject('old'); port.inject(' response',0.03); port.inject(sprintf('\r\n'),0.06);
meter = colormeasure.drivers.cr.CR100('SIM','Transport',port,'DiscardPendingInput',true, ...
    'DrainQuietPeriod',0.04,'DrainTimeout',0.4,'Clock',clock);
testCase.addTeardown(@()delete(meter));
verifyEqual(testCase,meter.recoveryStatus.discardedBytes,uint8(sprintf('old response\r\n')));
verifyTrue(testCase,meter.recoveryStatus.attempted);
verifyTrue(testCase,meter.recoveryStatus.quietObserved);
verifyEqual(testCase,meter.recoveryStatus.quietPeriod,0.04);
verifyEqual(testCase,meter.recoveryStatus.timeout,0.4);
verifyEqual(testCase,state('commands'),{'RC Model','RC ID','RC Firmware'});
meter.Measure(); verifyAligned(testCase,meter,1);
end

function testExplicitDrainDeadlineClosesWithoutCommands(testCase)
clock = colormeasuretest.FakeClock();
port = colormeasuretest.cr.Port('CR-100',clock); state = port.State;
for delay = 0:0.01:0.3, port.inject('pending',delay); end
verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port,'DiscardPendingInput',true, ...
    'DrainQuietPeriod',0.04,'DrainTimeout',0.08,'Clock',clock),'CR:DrainTimeout');
verifyEmpty(testCase,state('commands'));
verifyTrue(testCase,state('deleted'));
end

function testDrainStillRequiresCorrectIdentity(testCase)
% Simulated time: the drain's quiet interval must not depend on host scheduling.
clock = colormeasuretest.FakeClock();
port = colormeasuretest.cr.Port('CR-300',clock); state = port.State; port.inject('stale');
verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port,'Clock',clock, ...
    'DiscardPendingInput',true,'DrainQuietPeriod',0.01,'DrainTimeout',0.1),'CR:Identity');
verifyEqual(testCase,state('commands'),{'RC Model'});
verifyTrue(testCase,state('deleted'));
end

function testDrainTimeoutMustExceedTheQuietPeriod(testCase)
% The option check precedes port selection and every transport action.
port = colormeasuretest.cr.Port('CR-100'); state = port.State;
for pair = {[0.1 0.1],[0.2 0.1]}
    verifyError(testCase,@()colormeasure.drivers.cr.CR100('SIM','Transport',port, ...
        'DrainQuietPeriod',pair{1}(1),'DrainTimeout',pair{1}(2)),'CR:DrainOptions');
end
verifyEmpty(testCase,state('commands'));
verifyFalse(testCase,state('deleted'));
end

function testExtraReplyAfterFinalQueryPreventsCommit(testCase)
[meter,port,state] = instrument(testCase,'CR-100');
port.queue('RM Warnings',sprintf('OK:0:RM Warnings:0\r\nEXTRA\r\n'));
verifyError(testCase,@()meter.Measure(),'CR:PendingInput');
verifyTrue(testCase,state('deleted'));
verifyAligned(testCase,meter,0);
end

function testSavedSnapshotReloadsAllDataWithoutChangingWarnings(testCase)
for model = {'CR-100','CR-250'}
    [meter,~] = instrument(testCase,model{1});
    meter.Measure(); meter.Measure();
    fileName = [tempname '.mat'];
    cleanup = onCleanup(@()delete(fileName));
    before = warning;
    meter.Save(fileName);
    verifyEqual(testCase,warning,before);
    loaded = load(fileName);
    verifyEqual(testCase,fieldnames(loaded),{'measurements'});
    for field = {'XYZ','CCT','Duv','instrumentXYZ','metadata','identity'}
        verifyEqual(testCase,loaded.measurements.(field{1}),meter.(field{1}));
    end
    verifyFalse(testCase,isfield(loaded.measurements,'port'));
    if ~strcmp(model{1},'CR-100')
        verifyEqual(testCase,loaded.measurements.wl,meter.wl);
        verifyEqual(testCase,loaded.measurements.spectralData,meter.spectralData);
        verifyEqual(testCase,loaded.measurements.integratedSpectrum,meter.integratedSpectrum);
    end
end
end

function testNativeSnapshotIsIndependentAndMatchesSavedHistory(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
for model = {'CR-100','CR-250','CR-300'}
    [meter,~,state] = instrument(testCase,model{1});
    meter.Measure(); meter.Measure();
    commands = state('commands'); beforeWarnings = warning;
    values = meter.snapshot();
    verifyEqual(testCase,state('commands'),commands);
    verifyEqual(testCase,warning,beforeWarnings);
    verifyFalse(testCase,state('deleted'));
    verifyFalse(testCase,isfield(values,'port'));
    verifyEqual(testCase,values.XYZ,meter.XYZ);
    verifyEqual(testCase,values.metadata,meter.metadata);
    verifyEqual(testCase,isfield(values,'spectralData'),~strcmp(model{1},'CR-100'));
    fileName = fullfile(folder.Folder,[model{1} '.mat']);
    meter.Save(fileName);
    saved = load(fileName,'measurements');
    verifyEqual(testCase,saved.measurements,values);
    values.XYZ(1,1) = -12345;
    values.metadata(1).identity.model = 'changed copy';
    verifyNotEqual(testCase,meter.XYZ(1,1),values.XYZ(1,1));
    verifyEqual(testCase,meter.metadata(1).identity.model,model{1});
    meter.Disconnect();
    verifyEqual(testCase,meter.snapshot(),saved.measurements);
    verifyEqual(testCase,state('commands'),commands);
end
end

function testNativeSnapshotSupportsEmptyAndErasedHistory(testCase)
for model = {'CR-100','CR-250','CR-300'}
    [meter,~,state] = instrument(testCase,model{1});
    commands = state('commands');
    empty = meter.snapshot();
    verifyEmpty(testCase,empty.XYZ);
    verifyEmpty(testCase,empty.metadata);
    verifyEqual(testCase,empty.identity.model,model{1});
    verifyEqual(testCase,empty.schemaVersion,2);
    verifyEqual(testCase,state('commands'),commands);
    meter.Measure(); meter.EraseAll();
    values = meter.snapshot();
    verifyEmpty(testCase,values.XYZ);
    verifyEmpty(testCase,values.metadata);
    if ~strcmp(model{1},'CR-100')
        verifyEmpty(testCase,values.spectralData);
        verifyEmpty(testCase,values.integratedSpectrum);
    end
    meter.Disconnect();
    verifyEqual(testCase,meter.snapshot(),values);
end
end

function testPreparationIsAvailableWithoutConnectionForEachModel(testCase)
for model = {'CR100','CR250','CR300'}
    guide = colormeasure.drivers.cr.preparation(model{1});
    verifyEqual(testCase,guide,colormeasure.drivers.cr.preparation(strrep(model{1},'CR','CR-')));
    verifyTrue(testCase,isstruct(guide) && isscalar(guide));
    verifyTrue(testCase,ischar(guide.title) && isrow(guide.title));
    verifyTrue(testCase,ischar(guide.summary) && isrow(guide.summary));
    verifyTrue(testCase,iscellstr(guide.details));
    verifyNotEmpty(testCase,guide.details);
    verifyEqual(testCase,guide.url,'https://www.colorimetryresearch.com/downloads');
    verifyTrue(testCase,guide.required);
end
guide100 = colormeasure.drivers.cr.preparation('CR100');
guide250 = colormeasure.drivers.cr.preparation('CR250');
verifyNotEqual(testCase,guide100.details,guide250.details);
end

function testPreparationRejectsUnknownOrAmbiguousModels(testCase)
for value = {'CR250-RH','CR200',[],["CR100","CR250"],string(missing)}
    verifyError(testCase,@()colormeasure.drivers.cr.preparation(value{1}),'CR:AdapterModel');
end
end

function testFailedSavePreservesWarningState(testCase)
[meter,~] = instrument(testCase,'CR-100');
before = warning; caught = false;
try
    meter.Save(fullfile(tempname,'missing','capture.mat'));
catch
    caught = true;
end
verifyTrue(testCase,caught);
verifyEqual(testCase,warning,before);
verifyAligned(testCase,meter,0);
end

function testFailedSaveIsAFamilyErrorAndLeavesNoStagedFile(testCase)
% CR Save stages like CS-2000 Save: a refused destination is CR:SaveFailed,
% an existing directory is left alone and no staged copy remains.
[meter,~] = instrument(testCase,'CR-100');
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
verifyError(testCase,@()meter.Save(fullfile(fixture.Folder,'missing','capture.mat')),'CR:SaveFailed');
occupied = fullfile(fixture.Folder,'capture.mat'); mkdir(occupied);
verifyError(testCase,@()meter.Save(occupied),'CR:SaveFailed');
verifyTrue(testCase,isfolder(occupied));
verifyEmpty(testCase,dir(fullfile(fixture.Folder,'*.part.mat')));
verifyError(testCase,@()meter.Save(''),'CR:SavePath');
meter.Save(fullfile(fixture.Folder,'named'));
saved = load(fullfile(fixture.Folder,'named.mat'),'measurements');
verifyEqual(testCase,saved.measurements.XYZ,meter.XYZ);
verifyEqual(testCase,saved.measurements.schemaVersion,2);
end

function testReadingIdentitySurvivesEraseAndNeverUsesAnArrayPosition(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
for model = {'CR-100','CR-250','CR-300'}
    [meter,~,state] = instrument(testCase,model{1});
    segmentId = meter.segmentId;
    meter.Measure(); meter.Measure(); original = meter.metadata;
    verifyNotEqual(testCase,original(1).readingId,original(2).readingId);
    meter.Erase();
    verifyEqual(testCase,meter.metadata,original(1));
    meter.Measure(); replacementId = meter.metadata(2).readingId;
    verifyFalse(testCase,ismember(replacementId,{original.readingId}));
    meter.EraseAll(); meter.Measure(); afterEraseId = meter.metadata.readingId;
    verifyFalse(testCase,ismember(afterEraseId,[{original.readingId} {replacementId}]));
    values = meter.snapshot();
    verifyEqual(testCase,values.segmentId,segmentId);
    path = fullfile(folder.Folder,[model{1} '-identity.mat']);
    meter.Save(path); saved = load(path,'measurements');
    verifyEqual(testCase,saved.measurements,values);
    verifyEqual(testCase,nnz(strcmp(state('commands'),'M')),4);
end
end

function testDirectSaveRetainsNativeSnapshotWithoutAcquiring(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[meter,~,state] = instrument(testCase,'CR-250');
meter.Measure();meter.Measure();before=meter.snapshot();commands=state('commands');
path=fullfile(folder.Folder,'durable.mat');meter.Save(path);
verifyEqual(testCase,load(path,'measurements'),struct('measurements',before));
verifyEqual(testCase,meter.snapshot(),before);verifyEqual(testCase,state('commands'),commands);
end

function testRepeatedDirectSaveAfterEraseKeepsSnapshotAndDoesNotAcquire(testCase)
folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
[meter,~,state] = instrument(testCase,'CR-250');
meter.Measure();meter.Measure();commands=state('commands');
path=fullfile(folder.Folder,'durable.mat');meter.Save(path);previous=colormeasure.fileDigest(path);
meter.Erase();before=meter.snapshot();
meter.Save(path);
verifyEqual(testCase,load(path,'measurements'),struct('measurements',before));
verifyEqual(testCase,meter.snapshot(),before);verifyEqual(testCase,state('commands'),commands);
verifyNotEqual(testCase,colormeasure.fileDigest(path),previous);
other=fullfile(folder.Folder,'another.mat');meter.Save(other);
verifyEqual(testCase,load(other,'measurements'),struct('measurements',before));
verifyEqual(testCase,state('commands'),commands);
end

function testEraseWorksOnEmptyAndFullHistory(testCase)
for model = {'CR-100','CR-250'}
    [meter,~] = instrument(testCase,model{1});
    meter.Erase(); meter.EraseAll(); meter.Erase();
    verifyAligned(testCase,meter,0);
    meter.Measure(); meter.Measure(); meter.Erase();
    verifyAligned(testCase,meter,1);
    meter.Erase(); meter.Erase(); verifyAligned(testCase,meter,0);
    meter.Measure(); meter.EraseAll(); verifyAligned(testCase,meter,0);
end
end

function testAdvancedDirectCommandRemainsUsable(testCase)
[meter,port] = instrument(testCase,'CR-100');
writeline(meter.port,'RC ID');
text = char(read(port,port.NumBytesAvailable,'uint8'));
verifyEqual(testCase,text,sprintf('OK:0:RC ID:SIM-001\r\n'));
meter.Measure(); verifyAligned(testCase,meter,1);
end

function testSignedAndBlackInstrumentXYZStayUnchanged(testCase)
[meter,port] = instrument(testCase,'CR-100');
port.queue('RM XYZ',sprintf('OK:0:RM XYZ:-1,2,3\r\n'));
port.queue('RM XYZ',sprintf('OK:0:RM XYZ:0,0,0\r\n'));
meter.Measure(); meter.Measure();
verifyEqual(testCase,meter.XYZ,[-1 2 3; 0 0 0]);
verifyTrue(testCase,all(isnan(meter.CCT)) && all(isnan(meter.Duv)));
verifyAligned(testCase,meter,2);
end

function testWorkingExampleSavesAndClosesPort(testCase)
port = colormeasuretest.cr.Port('CR-250'); state = port.State;
fileName = [tempname '.mat'];
cleanup = onCleanup(@()delete(fileName));
colormeasure.drivers.cr.measureToFile('CR250','SIM',fileName,'Transport',port);
verifyTrue(testCase,state('deleted'));
loaded = load(fileName);
verifySize(testCase,loaded.measurements.XYZ,[1 3]);
verifyEqual(testCase,loaded.measurements.identity.model,'CR-250');
verifyEqual(testCase,loaded.measurements.responseTimeout,5);
verifyEqual(testCase,loaded.measurements.measurementTimeout,120);
end

function testExampleForwardsHostDeadlinesForEachModel(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
for model = {'CR-100','CR-250','CR-300'}
    port = colormeasuretest.cr.Port(model{1}); state = port.State;
    fileName = fullfile(folder.Folder,[model{1} '.mat']);
    measurements = colormeasure.drivers.cr.measureToFile(strrep(model{1},'-',''),'SIM',fileName, ...
        'Transport',port,'ResponseTimeout',10,'MeasurementTimeout',180);
    verifyEqual(testCase,measurements.responseTimeout,10);
    verifyEqual(testCase,measurements.measurementTimeout,180);
    verifyEqual(testCase,measurements.identity.model,model{1});
    verifySize(testCase,measurements.XYZ,[1 3]);
    verifyEqual(testCase,numel(measurements.metadata),1);
    verifyEqual(testCase,sum(strcmp(state('commands'),'M')),1);
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('deleteCount'),1);
    saved = load(fileName);
    verifyEqual(testCase,saved.measurements,measurements);
end
end

function testExampleDelegatesDeadlineValidationWithoutCommandsOrSave(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'invalid options.mat');
cases = {'ResponseTimeout',0; 'ResponseTimeout',[]; ...
    'MeasurementTimeout',Inf; 'MeasurementTimeout',[]};
for index = 1:size(cases,1)
    port = colormeasuretest.cr.Port('CR-250'); state = port.State;
    cleanup = onCleanup(@()delete(port));
    verifyError(testCase,@()colormeasure.drivers.cr.measureToFile('CR250','SIM',fileName, ...
        'Transport',port,cases{index,:}),'MATLAB:InputParser:ArgumentFailedValidation');
    verifyEmpty(testCase,state('commands'));
    verifyFalse(testCase,isfile(fileName));
    clear cleanup
end
end

function testExampleFailureClosesAndDoesNotSave(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fileName = fullfile(folder.Folder,'reading.mat');
for alreadySaved = [false true]
    if alreadySaved
        previousReading = struct('name','retained earlier measurement','XYZ',[1 2 3]);
        save(fileName,'previousReading');
    end
    port = colormeasuretest.cr.Port('CR-250'); state = port.State;
    port.queue('M',sprintf('ER:-305:M:Too low\r\n'));
    verifyError(testCase,@()colormeasure.drivers.cr.measureToFile('CR250','SIM',fileName,'Transport',port, ...
        'ResponseTimeout',10,'MeasurementTimeout',180),'CR:InstrumentError');
    verifyTrue(testCase,state('deleted'));
    verifyEqual(testCase,state('deleteCount'),1);
    verifyEqual(testCase,sum(strcmp(state('commands'),'M')),1);
    if alreadySaved
        verifyEqual(testCase,load(fileName),struct('previousReading',previousReading));
    else
        verifyFalse(testCase,isfile(fileName));
    end
end
end

function testAutomaticSelectionVerifiesEachModelWithoutMeasuring(testCase)
for model = {'CR-100','CR-250','CR-300'}
    port = colormeasuretest.cr.Port(model{1}); state = port.State;
    constructor = str2func(['colormeasure.drivers.cr.' strrep(model{1},'-','')]);
    meter = constructor("",'Transport',port,'PortList',@() "SIM-AUTO");
    testCase.addTeardown(@()delete(meter));
    verifyEqual(testCase,meter.identity.port,'SIM-AUTO');
    verifyEqual(testCase,meter.identity.model,model{1});
    verifyEqual(testCase,state('commands'),{'RC Model','RC ID','RC Firmware'});
    verifyEmpty(testCase,meter.XYZ);
end
end

function testAutomaticSelectionRejectsNoOrMultiplePortsBeforeIO(testCase)
for names = {strings(0,1),["SIM-A","SIM-B"]}
    port = colormeasuretest.cr.Port('CR-250'); state = port.State;
    testCase.addTeardown(@()delete(port));
    if isempty(names{1}), expected = 'CR:NoPort'; else, expected = 'CR:AmbiguousPort'; end
    verifyError(testCase,@()colormeasure.drivers.cr.CR250("",'Transport',port, ...
        'PortList',@() names{1}),expected);
    verifyEmpty(testCase,state('commands'));
    verifyFalse(testCase,state('deleted'));
end
end

function testAutomaticSelectionRejectsWrongDeviceAndCloses(testCase)
port = colormeasuretest.cr.Port('CR-100'); state = port.State;
verifyError(testCase,@()colormeasure.drivers.cr.CR250("",'Transport',port, ...
    'PortList',@() "SIM-WRONG"),'CR:Identity');
verifyEqual(testCase,state('commands'),{'RC Model'});
verifyTrue(testCase,state('deleted'));
end

function testAutomaticIdentityTimeoutClosesWithoutTryingAnotherDevice(testCase)
port = colormeasuretest.cr.Port('CR-250'); state = port.State;
port.queue('RC Model','');
verifyError(testCase,@()colormeasure.drivers.cr.CR250("",'Transport',port,'ResponseTimeout',0.03, ...
    'PortList',@() "SIM-LATE"),'CR:Timeout');
verifyEqual(testCase,state('commands'),{'RC Model'});
verifyTrue(testCase,state('deleted'));
end

function testExplicitPortDoesNotEnumerate(testCase)
port = colormeasuretest.cr.Port('CR-250');
meter = colormeasure.drivers.cr.CR250('SIM-EXPLICIT','Transport',port, ...
    'PortList',@()error('test:UnexpectedEnumeration','Explicit port must bypass listing.'));
testCase.addTeardown(@()delete(meter));
verifyEqual(testCase,meter.identity.port,'SIM-EXPLICIT');
end

function testIdentityRequiresUsableSerialAndFirmware(testCase)
for command = {'RC ID','RC Firmware'}
    for value = {'', '   ', char(0)}
        port = colormeasuretest.cr.Port('CR-250'); state = port.State;
        port.queue(command{1},sprintf('OK:0:%s:%s\r\n',command{1},value{1}));
        verifyError(testCase,@()colormeasure.drivers.cr.CR250("",'Transport',port, ...
            'PortList',@() "SIM"),'CR:Identity');
        verifyTrue(testCase,state('deleted'));
        verifyFalse(testCase,any(strcmp(state('commands'),'M')));
    end
end
end

function testInvalidAutomaticPortInputsFailBeforeIO(testCase)
verifyError(testCase,@()colormeasure.drivers.cr.selectPort(["A","B"],@() "SIM"),'CR:Port');
verifyError(testCase,@()colormeasure.drivers.cr.selectPort(string(missing),@() "SIM"),'CR:Port');
verifyError(testCase,@()colormeasure.drivers.cr.selectPort("",@() ["A",""]),'CR:PortList');
verifyError(testCase,@()colormeasure.drivers.cr.selectPort("",@() ["A","B";"C","D"]),'CR:PortList');
end

function testPortableNamesAndMacAliases(testCase)
for name = ["COM4","/dev/ttyACM0","/dev/ttyUSB0","/dev/tty.usbmodem1"]
    verifyEqual(testCase,colormeasure.drivers.cr.selectPort("",@() name),char(name));
end
aliases = ["/dev/tty.usbmodem1","/dev/cu.usbmodem1","/dev/cu.usbmodem1"];
if ismac
    verifyEqual(testCase,colormeasure.drivers.cr.selectPort("",@() aliases),'/dev/cu.usbmodem1');
else
    verifyError(testCase,@()colormeasure.drivers.cr.selectPort("",@() aliases),'CR:AmbiguousPort');
end
verifyError(testCase,@()colormeasure.drivers.cr.selectPort("", ...
    @() [aliases,"/dev/cu.usbserial2"]),'CR:AmbiguousPort');
verifyEqual(testCase,colormeasure.drivers.cr.selectPort('/dev/tty.usbmodem1', ...
    @()error('test:UnexpectedEnumeration','Explicit port must bypass listing.')), ...
    '/dev/tty.usbmodem1');
end

function testAutomaticExampleSavesVerifiedIdentityAndCloses(testCase)
port = colormeasuretest.cr.Port('CR-300'); state = port.State;
fileName = [tempname '.mat'];
cleanup = onCleanup(@()delete(fileName));
values = colormeasure.drivers.cr.measureToFile('CR300',"",fileName,'Transport',port,'PortList',@() "SIM-AUTO");
verifyEqual(testCase,values.identity.model,'CR-300');
verifyEqual(testCase,values.identity.port,'SIM-AUTO');
verifySize(testCase,values.XYZ,[1 3]);
verifyTrue(testCase,state('deleted'));
saved = load(fileName,'measurements');
verifyEqual(testCase,saved.measurements,values);
end

function testTheFirstCommandAfterASpectrumWaitsTheDocumentedGuard(testCase)
% CR manual p.35: require the 200 ms gap after the spectrum, before the
% first subsequent command. The transport and driver share simulated time.
[meter,~,state,clock] = instrument(testCase,'CR-250');
meter.Measure(); meter.Measure();
commands=state('commands');written=state('commandTimes');
readTimes=state('readTimes');readCommands=state('readCommandIndices');
spectra=find(strcmp(commands,'RM Spectrum'));
checked=0;
for index=spectra
    if index<numel(commands)
        afterSpectrum=readTimes(readCommands==index);
        assertNotEmpty(testCase,afterSpectrum);completed=max(afterSpectrum);
        verifyGreaterThanOrEqual(testCase,written(index+1)-completed,0.2-1e-12);
        checked=checked+1;
    end
end
verifyGreaterThanOrEqual(testCase,checked,1);
verifyLessThanOrEqual(testCase,max(clock.Sleeps),0.2);
end

function [meter,port,state,clock] = instrument(testCase,model)
% This suite's deadlines: a generous reply timeout, a short measurement one.
[meter,port,state,clock] = colormeasuretest.cr.instrument(testCase,model,'ResponseTimeout',0.8,'MeasurementTimeout',0.2);
end

function meter = attach(testCase,model,port)
meter = colormeasuretest.cr.attach(testCase,model,port,[],'ResponseTimeout',0.8,'MeasurementTimeout',0.2);
end


function data = snapshot(meter)
data = struct('XYZ',meter.XYZ,'CCT',meter.CCT,'Duv',meter.Duv, ...
    'instrumentXYZ',meter.instrumentXYZ,'wl',meter.wl,'metadata',meter.metadata, ...
    'spectralData',meter.spectralData,'integratedSpectrum',meter.integratedSpectrum);
end

function verifyAligned(testCase,meter,count)
for field = {'XYZ','CCT','Duv','instrumentXYZ','metadata'}
    verifyEqual(testCase,size(meter.(field{1}),1),count,sprintf('%s alignment',field{1}));
end
if ~strcmp(meter.identity.model,'CR-100')
    for field = {'wl','spectralData','integratedSpectrum'}
        verifyEqual(testCase,size(meter.(field{1}),1),count,sprintf('%s alignment',field{1}));
    end
end
end

function testDecimalUnderflowDoesNotBecomeAMeasuredZero(testCase)
colormeasuretest.verifyDecimalValues(testCase,@colormeasure.drivers.cr.numbers,'CR');
end

function testPairedCR250TranscriptKeepsNativeAndHostXYZSeparate(testCase)
[port,clock,shared]=pairedPort('CR-250','success');
meter=colormeasuretest.cr.attach(testCase,'CR-250',port,clock);
meter.Measure();verifyAligned(testCase,meter,1);
verifyEqual(testCase,meter.identity.serialNumber,'SYNTHETIC-250');
verifyEqual(testCase,meter.identity.firmware,'1.34.0-S28');
verifyEqual(testCase,meter.instrumentXYZ,[12.5 25 6.25]);
verifyEqual(testCase,meter.wl,380:2:780);
verifyEqual(testCase,meter.spectralData,shared.spectrum);
verifyEqual(testCase,meter.metadata(1).attempts,1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'M'),1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'RM Spectrum'),1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'RM Radiometric'),1);
% The shared wire fixture does not establish physical per-nm calibration.
verifyFalse(testCase,meter.metadata(1).spectralDensityUnitsConfirmed);
pairedResult('cr250-201',shared,port.State,meter,[]);
end

function testPairedCR100TranscriptIsNativeXYZOnly(testCase)
[port,clock,shared]=pairedPort('CR-100','success');
meter=colormeasuretest.cr.attach(testCase,'CR-100',port,clock);
meter.Measure();verifyAligned(testCase,meter,1);
verifyEqual(testCase,meter.identity.serialNumber,'SYNTHETIC-100');
verifyEqual(testCase,meter.identity.firmware,'1.34.0-S28');
verifyEqual(testCase,meter.instrumentXYZ,[12.5 25 6.25]);
verifyEqual(testCase,meter.XYZ,meter.instrumentXYZ);
verifyEmpty(testCase,meter.spectralData);verifyEmpty(testCase,meter.wl);
verifyEqual(testCase,meter.metadata(1).attempts,1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'M'),1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'RM Spectrum'),0);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'RM Radiometric'),0);
pairedResult('cr100-xyz',shared,port.State,meter,[]);
end

function testPairedUnderRangeReplyPublishesNothingAndDoesNotRetry(testCase)
[port,clock,shared]=pairedPort('CR-250','under-range');
meter=colormeasuretest.cr.attach(testCase,'CR-250',port,clock);
verifyFalse(testCase,meter.repeatOnError);
problem=colormeasuretest.captureError(@()meter.Measure());
assertNotEmpty(testCase,problem);verifyEqual(testCase,problem.identifier,'CR:InstrumentError');
verifyAligned(testCase,meter,0);verifyEmpty(testCase,meter.spectralData);
verifyEqual(testCase,meter.errorCode,-305);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'M'),1);
verifyEqual(testCase,colormeasuretest.countCommands(port.State,'RM XYZ'),0);
pairedResult('under-range',shared,port.State,meter,problem);
end

function testPairedWrongModelRefusesBeforeAcquisition(testCase)
[port,clock,shared]=pairedPort('CR-250','wrong-model');
state=port.State;
problem=colormeasuretest.captureError(@()colormeasure.drivers.cr.CR250('SIM', ...
    'Transport',port,'Clock',clock));
assertNotEmpty(testCase,problem);verifyEqual(testCase,problem.identifier,'CR:Identity');
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('commands'),{'RC Model'});
verifyEqual(testCase,colormeasuretest.countCommands(state,'M'),0);
pairedResult('wrong-model',shared,state,[],problem);
end

function [port,clock,shared]=pairedPort(model,variant)
% Read the same two byte-bound synthetic transcripts as the inert C driver.
% Only identity/acquisition replies are shared; MATLAB-only metadata queries
% use the existing Port defaults. No real connection is created.
if strcmp(model,'CR-250')
    filename='cr250-201.tsv';expected='e6b70b360a0286cd11994a826c58b5388b0c3707cbe5586983383e7df09bfea1';
    commands={'RC Model','RC ID','RC Firmware','RC InstrumentType','M','RM XYZ','RM Radiometric','RM Spectrum'};
else
    assert(strcmp(model,'CR-100'),'Pair:Model','Only the two declared paired fixtures are supported.');
    filename='cr100-xyz.tsv';expected='b89c08b9a14f181c75fc884feef9b94cf005aa593470175c6fba7d0ec0eb512e';
    commands={'RC Model','RC ID','RC Firmware','RC InstrumentType','M','RM XYZ'};
end
file=fullfile(fileparts(mfilename('fullpath')),'fixtures','paired',filename);
assert(strcmp(colormeasuretest.fileSha256(file),expected),'Pair:Digest','Shared transcript bytes changed.');
bytes=colormeasuretest.readBytes(file);
assert(all(bytes<128)&&~any(bytes==13)&&bytes(end)==10,'Pair:Format','Expected ASCII TSV with LF endings.');
lines=strsplit(char(reshape(bytes,1,[])),newline);lines(end)=[];
rows=cellfun(@(line)strsplit(line,char(9),'CollapseDelimiters',false),lines,'UniformOutput',false);
assert(all(cellfun(@numel,rows)==2),'Pair:Format','Each row needs one tab.');
rows=vertcat(rows{:});
assert(isequal(reshape(rows(1:numel(commands),1),1,[]),commands),'Pair:Commands','Shared command order changed.');
if strcmp(model,'CR-250')
    assert(size(rows,1)==209&&all(strcmp(rows(9:end,1),'.')),'Pair:Spectrum','Expected exactly 201 spectrum rows.');
    spectrum=reshape(str2double(rows(9:end,2)),1,[]);
    assert(all(isfinite(spectrum)),'Pair:Spectrum','Shared spectrum must be finite.');
    rows{8,2}=[rows{8,2} sprintf('\r\n') strjoin(rows(9:end,2),sprintf('\r\n'))];
else
    assert(size(rows,1)==6,'Pair:Commands','CR-100 must have no spectrum or radiometric rows.');
    spectrum=[];
end
assert(any(strcmp(variant,{'success','under-range','wrong-model'})),'Pair:Variant','Unknown paired control.');
if strcmp(variant,'under-range'),rows{5,2}='ER:-305:M:Light intensity too low or unmeasurable';end
if strcmp(variant,'wrong-model'),rows{1,2}='OK:0:RC Model:CR-300';end
clock=colormeasuretest.FakeClock();port=colormeasuretest.cr.Port(model,clock);
for k=1:numel(commands),port.queue(commands{k},[rows{k,2} sprintf('\r\n')]);end
shared=struct('fixture',filename,'fixtureSha256',expected,'model',model, ...
    'spectrum',spectrum,'variant',variant,'sharedCommands',{commands}, ...
    'argyllSpectrumFactor',1000,'unitsConvention','provisional wire W/(sr m^2 nm); C output mW = 1000 times wire');
end

function pairedResult(name,shared,state,meter,problem)
% Retained in the public runner log for the executor's paired comparison.
% This diagnostic is not a physical measurement or a new application format.
errorId='';errorMessage='';errorCode=[];
if ~isempty(problem)
    errorId=problem.identifier;errorMessage=problem.message;
    if ~isempty(meter),errorCode=meter.errorCode;end
end
result=struct('case',name,'fixture',shared.fixture,'fixture_sha256',shared.fixtureSha256, ...
    'model',shared.model,'variant',shared.variant,'commands',{state('commands')}, ...
    'm_count',colormeasuretest.countCommands(state,'M'),'error_id',errorId, ...
    'error_code',errorCode,'error_message',errorMessage, ...
    'units_convention',shared.unitsConvention,'argyll_spectrum_factor',shared.argyllSpectrumFactor, ...
    'metadata_reply_source','MATLAB-only settings use existing in-memory Port defaults', ...
    'rm_xyz',[],'matlab_xyz',[],'wavelengths_nm',[],'spectrum_wire',[], ...
    'capture_settings',struct(),'metadata_responses',struct([]));
if ~isempty(meter)
    result.rm_xyz=meter.instrumentXYZ;result.matlab_xyz=meter.XYZ;
    result.wavelengths_nm=meter.wl;result.spectrum_wire=meter.spectralData;
    if ~isempty(meter.metadata)
        result.capture_settings=meter.metadata(1).captureSettings;
        result.metadata_responses=meter.metadata(1).metadataResponses;
    end
end
fprintf('CR_PAIR_MATLAB %s\n',jsonencode(result));
end

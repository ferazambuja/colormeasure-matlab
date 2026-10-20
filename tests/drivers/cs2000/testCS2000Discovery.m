function tests = testCS2000Discovery
% Candidate lists and transports are isolated; never enumerate OS ports.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
colormeasuretest.setupPaths(testCase);
end


function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testOmittedPortConstructorsAndOfflineHistory(testCase)
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
for factory = {@colormeasure.drivers.cs2000.CS2000,@colormeasure.drivers.cs2000.CS2000manual}
    meter = factory{1}();
    testCase.addTeardown(@()delete(meter));
    verifyEmpty(testCase,meter.serialPort);
    verifyFalse(testCase,meter.isConnected());
    meter.Save(fileName); meter.Load(fileName);
    verifySize(testCase,meter.XYZData,[3 0]);
    verifyEmpty(testCase,meter.serialPort);
end
end

function testEmptyPortDefersListAndTransportUntilConnect(testCase)
for request = {'',"",'   '}
    [meter,port,state] = instrument(testCase,request{1},"SIM-A");
    verifyEqual(testCase,state('portListCalls'),0);
    verifyEmpty(testCase,state('commands')); verifyEmpty(testCase,port.Terminator);
    meter.Connect();
    verifyEqual(testCase,state('portListCalls'),1);
    verifyEqual(testCase,meter.identity.port,'SIM-A');
    verifyTrue(testCase,meter.isConnected());
    verifyFalse(testCase,any(startsWith(state('commands'),'MEAS,')));
end
end

function testOfflineLoadAndDeleteNeverCallInjectedPortList(testCase)
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
[meter,~,state] = instrument(testCase,"","SIM-A");
meter.Save(fileName); meter.Load(fileName); meter.Disconnect(); delete(meter);
verifyEqual(testCase,state('portListCalls'),0);
verifyEmpty(testCase,state('commands'));
end

function testSingleCandidateVerifiesCS2000AAndRetainsSelectedPort(testCase)
[meter,port,state] = instrument(testCase,"",["SIM-A","SIM-A"]);
port.queue('IDDR',sprintf('OK00,CS-2000A ,2,1234567\r\n'));
meter.Connect(); meter.Measure();
verifyEqual(testCase,meter.identity.model,'CS-2000A');
verifyEqual(testCase,meter.identity.variation,2);
verifyEqual(testCase,meter.identity.port,'SIM-A');
verifyEqual(testCase,meter.metadata(1).identity.port,'SIM-A');
verifyEqual(testCase,state('portListCalls'),1);
verifySize(testCase,meter.spectralData,[401 1]);
end

function testNoneOrMultipleCandidatesNeverSendCommands(testCase)
for ports = {strings(0,1),["SIM-A","SIM-B"]}
    [meter,~,state] = instrument(testCase,"",ports{1});
    identifier = 'CS2000:NoPort';
    if numel(ports{1}) > 1, identifier = 'CS2000:AmbiguousPort'; end
    verifyError(testCase,@()meter.Connect(),identifier);
    verifyFalse(testCase,meter.isConnected());
    verifyEmpty(testCase,state('commands'));
    verifyEqual(testCase,state('portListCalls'),1);
end
caught=false;
try
    colormeasure.drivers.cs2000.selectPort("",@()["SIM-A","SIM-B"]);
catch err
    caught=true;verifyEqual(testCase,err.identifier,'CS2000:AmbiguousPort');
    verifySubstring(testCase,err.message,'SIM-A');
    verifySubstring(testCase,err.message,'SIM-B');
end
verifyTrue(testCase,caught,'Ambiguous candidates must be refused.');
end

function testMacExactAliasesCollapseButOtherEndpointsRemainAmbiguous(testCase)
ports = ["/dev/tty.fixture","/dev/cu.fixture","/dev/cu.fixture"];
if ismac
    verifyEqual(testCase,colormeasure.drivers.cs2000.selectPort("",@()ports),'/dev/cu.fixture');
    [meter,~,~] = instrument(testCase,"",ports);
    meter.Connect(); verifyEqual(testCase,meter.identity.port,'/dev/cu.fixture');
else
    verifyError(testCase,@()colormeasure.drivers.cs2000.selectPort("",@()ports),'CS2000:AmbiguousPort');
end
verifyError(testCase,@()colormeasure.drivers.cs2000.selectPort("", ...
    @()["/dev/tty.fixture","/dev/cu.fixture","/dev/cu.second"]),'CS2000:AmbiguousPort');
verifyError(testCase,@()colormeasure.drivers.cs2000.selectPort("", ...
    @()["/dev/tty.fixture","/dev/cu.fixture-other"]),'CS2000:AmbiguousPort');
end

function testExplicitPortAndNumericCOMBypassDiscovery(testCase)
for request = {'SIM-EXPLICIT',"/dev/tty.fixture",4}
    [meter,~,state] = instrument(testCase,request{1},strings(0,1));
    meter.Connect();
    expected = char(string(request{1}));
    if isnumeric(request{1}), expected = 'COM4'; end
    verifyEqual(testCase,meter.identity.port,expected);
    verifyEqual(testCase,state('portListCalls'),0);
end
verifyEqual(testCase,colormeasure.drivers.cs2000.selectPort('/dev/tty.fixture',@listFailure),'/dev/tty.fixture');
end

function testWrongDeviceNeverFallsBackOrAcquires(testCase)
[meter,port,state] = instrument(testCase,"","SIM-A");
port.queue('IDDR',sprintf('OK00,OTHER    ,1,1234567\r\n'));
verifyError(testCase,@()meter.Connect(),'CS2000:Identity');
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR','RMTS,0'});
verifyTrue(testCase,state('deleted')); verifyFalse(testCase,meter.isConnected());
verifySize(testCase,meter.XYZData,[3 0]);
end

function testIdentificationTimeoutClosesWithoutAcquisitionOrFallback(testCase)
[meter,port,state] = instrument(testCase,"","SIM-A"); port.queue('IDDR','');
% The timeout closes the port before restoration can be confirmed.
verifyWarning(testCase,@() verifyError(testCase,@()meter.Connect(),'CS2000:Timeout'),'CS2000:CleanupUnverified');
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,state('commands'),{'RMTS,1','IDDR'});
verifyTrue(testCase,state('deleted')); verifyFalse(testCase,meter.isConnected());
end

function testUnavailableSelectedTransportDoesNotTryAnotherCandidate(testCase)
[meter,port,state] = instrument(testCase,"","SIM-A"); delete(port);
verifyError(testCase,@()meter.Connect(),'CS2000:Disconnected');
verifyEqual(testCase,state('portListCalls'),1);
verifyEmpty(testCase,state('commands')); verifyFalse(testCase,meter.isConnected());
end

function testPortListErrorAndMalformedResultsNeverSendCommands(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
meter = colormeasure.drivers.cs2000.CS2000("",'Transport',port,'PortList',@listFailure);
testCase.addTeardown(@()delete(meter));
verifyError(testCase,@()meter.Connect(),'cs2000test:PortListFailure');
verifyEmpty(testCase,state('commands')); verifyFalse(testCase,meter.isConnected());
for available = {"",string(missing),["A","B";"C","D"]}
    [meter,~,state] = instrument(testCase,"",available{1});
    verifyError(testCase,@()meter.Connect(),'CS2000:PortList');
    verifyEmpty(testCase,state('commands'));
end
end

function testReconnectRetainsChosenPortWithoutReenumerating(testCase)
[meter,~,state] = instrument(testCase,"","SIM-A");
meter.Connect(); meter.Measure(); before = meter.metadata(1);
meter.Disconnect(); state('availablePorts') = "SIM-B";
% Replacement injected peer models reopening the retained name; no OS port.
port = colormeasuretest.cs2000.Port(); replacement = port.State; meter.serialPort = port;
meter.Connect(); meter.Measure();
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,meter.identity.port,'SIM-A');
verifyEqual(testCase,meter.metadata(1),before);
verifyEqual(testCase,meter.metadata(2).identity.port,'SIM-A');
verifyEqual(testCase,replacement('commands'),{'RMTS,1','IDDR','BALR','BALS,1,0','MSWE,0', ...
    'DTCR','SCMR','SPMR','OBSR','MEAS,1','MEDR,1,0,1','MEDR,1,0,2','MEDR,1,0,3','MEDR,1,0,4', ...
    'MEDR,2,0,01','MEDR,0,0,1'});
end

function testReconnectStartsANewRecoveryRecord(testCase)
% recoveryStatus describes the current connection: a plain reconnect must not
% report the drain and discarded bytes of the previous connection.
% Simulated time: the drain's quiet interval must not depend on host scheduling.
clock = colormeasuretest.FakeClock();
[meter,port,~] = instrument(testCase,"","SIM-A",clock);
port.inject(sprintf('OK00\r\n'));
meter.Connect('DiscardPendingInput',true,'DrainQuietPeriod',0.03,'DrainTimeout',0.2);
verifyTrue(testCase,meter.recoveryStatus.attempted);
meter.Disconnect();
meter.serialPort = colormeasuretest.cs2000.Port(clock); meter.Connect();
verifyFalse(testCase,meter.recoveryStatus.attempted);
verifyEmpty(testCase,meter.recoveryStatus.discardedBytes);
end

function testFailedHandshakeAlsoRetainsSelectedName(testCase)
[meter,port,state] = instrument(testCase,"","SIM-A");
port.queue('IDDR',sprintf('OK00,OTHER    ,1,1234567\r\n'));
verifyError(testCase,@()meter.Connect(),'CS2000:Identity');
state('availablePorts') = "SIM-B";
meter.serialPort = colormeasuretest.cs2000.Port(); meter.Connect();
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,meter.identity.port,'SIM-A');
end

function testFailedSelectionCanBeRetriedBeforeAnyNameIsChosen(testCase)
[meter,~,state] = instrument(testCase,"",strings(0,1));
verifyError(testCase,@()meter.Connect(),'CS2000:NoPort');
state('availablePorts') = "SIM-A"; meter.serialPort = colormeasuretest.cs2000.Port();
meter.Connect();
verifyEqual(testCase,state('portListCalls'),2);
verifyEqual(testCase,meter.identity.port,'SIM-A');
end

function testManualVariantUsesDeferredSelection(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
state('availablePorts') = "SIM-A"; state('portListCalls') = 0;
meter = colormeasure.drivers.cs2000.CS2000manual("",'Transport',port,'PortList',@()availablePorts(state));
testCase.addTeardown(@()delete(meter));
verifyEqual(testCase,state('portListCalls'),0);
meter.Connect(); meter.Measure();
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,meter.identity.port,'SIM-A');
verifySize(testCase,meter.XYZData,[3 1]);
end

function testAutomaticExampleSavesAndDisconnects(testCase)
port = colormeasuretest.cs2000.Port(); state = port.State;
state('availablePorts') = "SIM-A"; state('portListCalls') = 0;
fileName = [tempname '.mat']; cleanup = onCleanup(@()delete(fileName));
measurements = colormeasure.drivers.cs2000.measureToFile("",fileName,'Transport',port, ...
    'PortList',@()availablePorts(state));
verifyTrue(testCase,state('deleted'));
verifyEqual(testCase,state('portListCalls'),1);
verifyEqual(testCase,measurements.identity.port,'SIM-A');
verifySize(testCase,measurements.spectralData,[401 1]);
saved = load(fileName); verifyEqual(testCase,saved.measurements,measurements);
end

function [meter,port,state] = instrument(testCase,request,ports,clock)
% clock: an optional FakeClock shared by the simulated port and the driver.
if nargin < 4, clock = []; end
port = colormeasuretest.cs2000.Port(clock); state = port.State;
state('availablePorts') = ports; state('portListCalls') = 0;
[meter,port,state] = colormeasuretest.cs2000.instrument(testCase,'Request',request,'Port',port, ...
    'PortList',@()availablePorts(state),'Clock',clock);
end

function ports = availablePorts(state)
state('portListCalls') = state('portListCalls') + 1;
ports = state('availablePorts');
end

function ports = listFailure %#ok<STOUT>
error('cs2000test:PortListFailure','Simulated port-list failure.');
end

function tests=testNativeConnectionCleanup
% Actual native connection owners with inert ports, including destructor faults.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testNativeSelectionRefusalsCarryTheExistingNoConnectionWitness(t)
for ports={strings(0,1),["SIM-A","SIM-B"]}
    colormeasuretest.pr.configure('Model','PR-655','Ports',ports{1});
    adapter=colormeasure.drivers.cs2000.adapter('PortList',@(~)ports{1});
    actions={@()colormeasuretest.pr.Driver(''), ...
        @()colormeasure.drivers.cr.CR250('','PortList',@()ports{1}), ...
        @()adapter.connect('')};
    prefixes={'PR655','CR','CS2000'};
    suffix='NoPort';if ~isempty(ports{1}),suffix='AmbiguousPort';end
    for index=1:numel(actions)
        problem=colormeasuretest.captureError(actions{index});
        assertClass(t,problem,'MException');
        verifyEqual(t,problem.identifier,[prefixes{index} ':' suffix]);
        verifyTrue(t,any(cellfun(@(cause)strcmp(cause.identifier, ...
            'Measurement:ConnectCleanupConfirmed'),problem.cause)));
    end
    state=colormeasuretest.pr.state();
    verifyEmpty(t,state.openedPort);verifyEmpty(t,state.commands);
end
end
function testNativeHandshakeRefusalsCarryOnlyConfirmedCleanupWitnesses(t)
for family={'pr','cr','cs2000'}
    [action,state,identifier,closed]=refusal(family{1},false);
    problem=colormeasuretest.captureError(action);
    verifyClass(t,problem,'MException');verifyEqual(t,problem.identifier,identifier);
    verifyTrue(t,any(cellfun(@(cause)strcmp(cause.identifier, ...
        'Measurement:ConnectCleanupConfirmed'),problem.cause)),family{1});
    verifyTrue(t,closed(state));
end
end
function testDestructorWarningsNeverBecomeCleanupWitnesses(t)
for family={'pr','cr','cs2000'}
    [action,state,identifier,closed]=refusal(family{1},true);
    problem=colormeasuretest.captureError(action);
    verifyClass(t,problem,'MException');verifyEqual(t,problem.identifier,identifier);
    verifyFalse(t,any(cellfun(@(cause)strcmp(cause.identifier, ...
        'Measurement:ConnectCleanupConfirmed'),problem.cause)),family{1});
    verifyFalse(t,closed(state),family{1});
end
end
function testSharedClosePreservesPreviousWarningAndRefusesAFailedDestructor(t)
previous=warning; t.addTeardown(@()warning(previous));
[message,identifier]=lastwarn;t.addTeardown(@()lastwarn(message,identifier));
lastwarn('Earlier diagnostic','Test:EarlierWarning');
peer=colormeasuretest.FailingCleanup();
verifyError(t,@()colormeasure.drivers.closeConnection(peer), ...
    'Measurement:ConnectionCleanupUnconfirmed');
[actualMessage,actualIdentifier]=lastwarn;
verifyEqual(t,actualMessage,'Earlier diagnostic');verifyEqual(t,actualIdentifier,'Test:EarlierWarning');
end
function [action,state,identifier,closed]=refusal(family,fail)
clock=colormeasuretest.FakeClock();
switch family
    case 'pr'
        colormeasuretest.pr.configure('Model','PR-655');
        peer=colormeasuretest.pr.Port(clock);peer.FailCleanup=fail;peer.WriteTimeoutPrefix='PH';
        action=@()colormeasure.drivers.pr.PR655('SIM','Transport',peer,'Clock',clock);
        state=@colormeasuretest.pr.state;identifier='SerialTest:WriteTimeout';
        closed=@(get) get().closed;
    case 'cr'
        peer=colormeasuretest.cr.Port('CR-300',clock);peer.FailCleanup=fail;
        state=peer.State;
        action=@()colormeasure.drivers.cr.CR250('SIM','Transport',peer,'Clock',clock);
        identifier='CR:Identity';closed=@(map)map('deleted');
    case 'cs2000'
        peer=colormeasuretest.cs2000.Port(clock);peer.FailCleanup=fail;
        peer.queue('IDDR',sprintf('OK00,OTHER,1,1234567\r\n'));state=peer.State;
        adapter=colormeasure.drivers.cs2000.adapter('Transport',peer,'PortList',@(~)"SIM", ...
            'DriverFactory',@(varargin)constructCS(clock,varargin{:}));
        action=@()adapter.connect('SIM');identifier='CS2000:Identity';closed=@(map)map('deleted');
end
end
function instrument=constructCS(clock,varargin)
instrument=colormeasure.drivers.cs2000.CS2000(varargin{:},'Clock',clock);
end

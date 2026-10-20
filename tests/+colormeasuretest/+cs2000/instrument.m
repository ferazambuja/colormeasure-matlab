function [meter,port,state] = instrument(testCase,varargin)
%INSTRUMENT A CS-2000 driver on a simulated port, deleted at teardown.
% Options: 'Manual' (the CS2000manual variant), 'Request' (the port request,
% 'SIM'), 'Port' (an already prepared simulated port) and any constructor
% option; ResponseTimeout is 0.05 s unless given. 'Clock' (a FakeClock) is shared
% by the driver and a new simulated port, so reply delays and deadlines run on
% simulated time instead of the wall clock.
p = inputParser; p.KeepUnmatched = true;
p.addParameter('Manual',false,@(x) islogical(x) && isscalar(x));
p.addParameter('Request','SIM');
p.addParameter('Port',[]);
p.addParameter('ResponseTimeout',0.05);
p.addParameter('Clock',[]);
p.parse(varargin{:});
port = p.Results.Port;
clock = p.Results.Clock;
if isempty(port), port = colormeasuretest.cs2000.Port(clock); end
state = port.State;
factory = @colormeasure.drivers.cs2000.CS2000;
if p.Results.Manual, factory = @colormeasure.drivers.cs2000.CS2000manual; end
options = namedargs2cell(p.Unmatched);
if ~isempty(clock), options = [options {'Clock',clock}]; end
meter = factory(p.Results.Request,'Transport',port,'ResponseTimeout',p.Results.ResponseTimeout,options{:});
testCase.addTeardown(@()delete(meter));
end

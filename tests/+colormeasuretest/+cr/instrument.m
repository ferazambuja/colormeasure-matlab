function [meter,port,state,clock] = instrument(testCase,model,varargin)
%INSTRUMENT A CR driver on a simulated port sharing one fake clock, so that
% deadlines, reply delays and the post-spectrum guard never wait on the wall
% clock. 'Settings' selects the settings-capable port; every other option is
% passed to the driver constructor.
p = inputParser; p.KeepUnmatched = true;
p.addParameter('Settings',false,@(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
clock = colormeasuretest.FakeClock();
if p.Results.Settings
    port = colormeasuretest.cr.SettingsPort(model,clock);
else
    port = colormeasuretest.cr.Port(model,clock);
end
state = port.State;
options = namedargs2cell(p.Unmatched);
meter = colormeasuretest.cr.attach(testCase,model,port,clock,options{:});
end

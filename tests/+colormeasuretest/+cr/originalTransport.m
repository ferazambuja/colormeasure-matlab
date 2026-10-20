function value = originalTransport(action,varargin)
%ORIGINALTRANSPORT Explicit one-use registration; never opens physical serial.
persistent registered
value = [];
switch action
    case 'set'
        registered = varargin{1};
    case 'clear'
        registered = [];
    case 'get'
        if isempty(registered) || numel(varargin) < 2 ...
                || ~strcmp(varargin{1},'CR-ORIGINAL-SIM') || varargin{2} ~= 115200
            error('crtest:HardwareForbidden','Only a registered original-code fixture is allowed.');
        end
        value = registered;
        registered = [];
    otherwise
        error('crtest:FixtureAction','Unknown fixture action.');
end
end

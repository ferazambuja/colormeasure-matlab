function value = state(varargin)
% Test-only configuration/log, shared with the simulated serial connection.
persistent current
if nargin
    current = varargin{1};
end
value = current;
end

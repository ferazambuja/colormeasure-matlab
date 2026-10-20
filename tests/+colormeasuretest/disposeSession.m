function disposeSession(s)
%DISPOSESESSION Delete a test session without the unsaved-batch warning or
% the recovery variable it would leave in the base workspace.
if isempty(s) || ~isvalid(s), return; end
before = evalin('base','who(''colorMeasureRecovered_*'')');
state = warning('off','Measurement:UnsavedSession'); cleanup = onCleanup(@() warning(state));
delete(s);
added = setdiff(evalin('base','who(''colorMeasureRecovered_*'')'),before);
if ~isempty(added), evalin('base',['clear ' strjoin(added,' ')]); end
end

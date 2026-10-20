function problem=confirmedConnectionFailure(problem)
%CONFIRMEDCONNECTIONFAILURE Preserve a refusal with its port owner's witness.
% Call only after proving no port was opened or confirming owned-port cleanup.
% A caught constructor error, an empty handle or cleared fields is not proof.
assert(isa(problem,'MException'),'Measurement:AdapterContract','Pass the original connection exception.');
problem=addCause(problem,MException('Measurement:ConnectCleanupConfirmed', ...
    'The connection owner confirmed no outstanding host I/O after this refusal.'));
end

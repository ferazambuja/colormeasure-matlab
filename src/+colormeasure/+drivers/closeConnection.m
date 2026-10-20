function closeConnection(connection)
%CLOSECONNECTION Reject a destructor warning as a cleanup confirmation.
% MATLAB can turn an exception inside delete into a warning and return
% normally. Retain that distinction at the shared native-port boundary.
% Restore the caller's last-warning record without suppressing diagnostics.
[message,identifier]=lastwarn;
restore=onCleanup(@()lastwarn(message,identifier));
lastwarn('','');
delete(connection);
[message,identifier]=lastwarn;
assert(~strcmp(identifier,'MATLAB:class:DestructorError'), ...
    'Measurement:ConnectionCleanupUnconfirmed', ...
    'The connection destructor reported unconfirmed cleanup: %s',message);
end

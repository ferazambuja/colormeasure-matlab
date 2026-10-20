function exception = captureError(action)
%CAPTUREERROR Retain the thrown exception; empty means the action succeeded.
exception=[];
try
    action();
catch exception
end
end

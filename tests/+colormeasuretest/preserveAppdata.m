function preserveAppdata(testCase,key)
%PRESERVEAPPDATA Restore or remove a root appdata entry at teardown.
if isappdata(groot,key)
    previous = getappdata(groot,key); testCase.addTeardown(@() setappdata(groot,key,previous));
else
    testCase.addTeardown(@() removeAppdata(key));
end
end

function removeAppdata(key)
if isappdata(groot,key), rmappdata(groot,key); end
end

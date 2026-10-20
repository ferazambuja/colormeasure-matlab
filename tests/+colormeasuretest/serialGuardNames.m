function names = serialGuardNames()
%SERIALGUARDNAMES Serial APIs the isolated test worker shadows with hardware guards.
% launchWorker writes one guard per name; runSoftwareChecks asserts each is in place.
names = {'serialport','serialportlist','serial','serialportfind','instrfind','instrfindall'};
end

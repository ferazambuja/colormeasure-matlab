function pause(seconds)
%PAUSE Record bounded original-driver delays; never installed for v2 tests.
validateattributes(seconds,{'double'},{'scalar','real','finite','nonnegative','<=',1});
colormeasuretest.cs2000.pauseLog('append',seconds);
end

function failsAndLeavesCleanupUnverified(testCase, action, identifier)
%FAILSANDLEAVESCLEANUPUNVERIFIED Assert the failed exchange and cleanup warning.
verifyWarning(testCase,@()verifyError(testCase,action,identifier),'CS2000:CleanupUnverified');
end

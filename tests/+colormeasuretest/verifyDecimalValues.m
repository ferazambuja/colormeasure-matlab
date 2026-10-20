function verifyDecimalValues(testCase, parse, prefix)
%VERIFYDECIMALVALUES Native parser controls for zero, subnormals and underflow.
for value={'1e-9999','-1e-9999','0.0001e-9999'}
    verifyError(testCase,@()parse(value{1},1),[prefix ':NumericPayload']);
end
verifyEqual(testCase,parse('0,-0,+0.000e-9999',3),zeros(1,3));
verifyGreaterThan(testCase,parse('1e-320',1),0);
verifyLessThan(testCase,parse('-1e-320',1),0);
verifyEqual(testCase,parse('1.25e-2,-2.5,3',3),[.0125 -2.5 3]);
end

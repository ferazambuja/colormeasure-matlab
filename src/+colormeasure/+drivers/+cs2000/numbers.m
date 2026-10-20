function values = numbers(payload, count)
%NUMBERS Parse CS finite decimals and refuse the calculation-error sentinel.
% Rev.7 sections 3 and 5. A calculation-error sentinel is not a signed bin.
% https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
if nargin<2, count=[]; end
values = colormeasure.drivers.decimalValues(payload,count,'CS2000');
if any(values == -9.9999e9)
    error('CS2000:CalculationError','The instrument returned its calculation-error sentinel.');
end
end

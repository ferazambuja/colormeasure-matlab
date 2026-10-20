function values = numbers(payload, count)
%NUMBERS Parse CR decimal protocol fields without evaluating MATLAB code.
values = colormeasure.drivers.decimalValues(payload,count,'CR');
end

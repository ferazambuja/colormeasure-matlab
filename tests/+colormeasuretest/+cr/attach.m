function meter = attach(testCase,model,port,clock,varargin)
%ATTACH The model's driver on a simulated port, deleted at teardown.
% A port built without a clock keeps the wall clock. Further arguments are
% driver constructor options, such as the suite's timeouts.
constructor = str2func(['colormeasure.drivers.cr.' strrep(model,'-','')]);
meter = constructor('SIM','Transport',port,'Clock',clock,varargin{:});
testCase.addTeardown(@()delete(meter));
end

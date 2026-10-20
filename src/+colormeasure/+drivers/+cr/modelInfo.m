function [key, label] = modelInfo(model)
%MODELINFO Validate an explicit supported CR model; never infer it from a port.
if ~((ischar(model)&&isrow(model)) || (isstring(model)&&isscalar(model)&&~ismissing(model)))
    error('CR:AdapterModel','Choose CR100, CR250 or CR300.');
end
key = strrep(char(model),'-','');
if ~ismember(key,{'CR100','CR250','CR300'})
    error('CR:AdapterModel','Choose CR100, CR250 or CR300.');
end
label = ['CR-' key(3:end)];
end

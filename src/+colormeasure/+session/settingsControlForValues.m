function [control,contextName] = settingsControlForValues(control,values,useDefault)
%SETTINGSCONTROLFORVALUES Resolve family-owned dependent control presentation.
% The default describes the next automatic acquisition, never missing readback.
% Call with useDefault=false when displaying an observation. No I/O or mutation
% of the original catalog, readings or requested values is performed.
if nargin<3,useDefault=true;end
contextName='';
if ~isfield(control,'editor')||~isfield(control.editor,'kind'),return;end
if strcmp(control.editor.kind,'automaticNumber')&&isfield(control.editor,'ceiling')
    rule=control.editor.ceiling;value=rule.observed;
    if isfield(values,rule.setting),value=values.(rule.setting);end
    control.maximum=rule.standardMaximum;
    if ((ischar(value)&&isrow(value))||(isstring(value)&&isscalar(value)&&~ismissing(value)))&& ...
            strcmp(value,rule.extendedValue),control.maximum=rule.extendedMaximum;end
end
if ~strcmp(control.editor.kind,'dependentNumber'),return;end
editor=control.editor;value=[];
if isfield(values,editor.setting),value=values.(editor.setting);
elseif useDefault,value=editor.defaultContext;end
index=find(arrayfun(@(entry)isequal(entry.value,value),editor.contexts),1);
if isempty(index)
    contextName='speed not read';
    if useDefault
        control.available=false;
        control.help.meaning='Choose a measurement speed before setting its interval.';
    end
    return
end
context=editor.contexts(index);contextName=context.name;
control.label=context.label;control.minimum=context.minimum;control.maximum=context.maximum;
control.available=control.available&&context.available;
control.help.meaning=context.meaning;control.editor.integer=context.integer;
end

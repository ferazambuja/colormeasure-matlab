function change(control)
%CHANGE Invoke a control's value-change callback as an edit would:
% ValueChangedFcn for uifigure-family components, Callback for classic controls.
if isprop(control,'ValueChangedFcn'), callback = control.ValueChangedFcn; else, callback = get(control,'Callback'); end
callback(control,[]);
end

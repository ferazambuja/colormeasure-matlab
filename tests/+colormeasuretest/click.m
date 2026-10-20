function click(control)
%CLICK Invoke a control's click callback as a click would: ButtonPushedFcn
% for uifigure-family components, Callback for classic controls.
if isprop(control,'ButtonPushedFcn'), callback = control.ButtonPushedFcn; else, callback = get(control,'Callback'); end
callback(control,[]);
end

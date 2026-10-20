function label = settingLabel(controls,values,id)
%SETTINGLABEL Resolve a current settings value to its reported choice label.
label = '';
if ~isfield(values,id), return; end
control = controls(strcmp({controls.id},id));
if isempty(control), return; end
choice = find([control.choices.value]==values.(id),1);
if ~isempty(choice), label = control.choices(choice).label; end
end

function yes=isShown(component)
%ISSHOWN A live component whose ancestors and selected tabs are visible.
% Enabled state, owner identity and permission to change focus are separate.
yes=isscalar(component)&&isgraphics(component);
while yes&&isscalar(component)&&isgraphics(component)
    if (isprop(component,'Visible')&&strcmp(component.Visible,'off'))|| ...
            (isa(component,'matlab.ui.container.Tab')&&component.Parent.SelectedTab~=component)
        yes=false;return
    end
    component=component.Parent;
end
end

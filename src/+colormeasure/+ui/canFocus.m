function yes=canFocus(component,owner)
%CANFOCUS A shown, enabled return control still belonging to its live owner.
% The caller decides whether it may raise the owner or must preserve the
% current figure. This predicate does not grant permission to take focus.
% https://www.mathworks.com/help/matlab/ref/matlab.ui.figure.focus.html
yes=isscalar(owner)&&isgraphics(owner,'figure')&&colormeasure.ui.isShown(component)&& ...
    isequal(ancestor(component,'figure'),owner);
while yes&&isscalar(component)&&isgraphics(component)
    if isprop(component,'Enable')&&strcmp(component.Enable,'off'),yes=false;return;end
    component=component.Parent;
end
end

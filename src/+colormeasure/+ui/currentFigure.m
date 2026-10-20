function fig=currentFigure()
%CURRENTFIGURE Read the current graphics figure, including hidden handles.
% Unlike gcf, this does not create or raise a figure. Auxiliary uifigures
% hide their handles by default. Expose them only for this synchronous query,
% then restore the caller's root setting before returning. This is a graphics
% refusal guard, not evidence of operating-system keyboard focus.
% https://www.mathworks.com/help/matlab/creating_plots/preventing-access-to-figures-and-axes.html
% Fernando Voltolini de Azambuja, 2026.
root=groot;previous=root.ShowHiddenHandles;
restore=onCleanup(@()set(root,'ShowHiddenHandles',previous));
root.ShowHiddenHandles='on';
fig=root.CurrentFigure;
end

function handles = field(fig,tag)
%FIELD Every visible-handle object under a figure carrying a tag; none or
% several are ordinary answers. Use control() for exactly one.
handles = findobj(fig,'Tag',tag);
end

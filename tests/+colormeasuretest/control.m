function handle = control(fig,tag)
%CONTROL The one object under a figure carrying a tag, hidden handles included.
handle = findall(fig,'Tag',tag);
assert(isscalar(handle),'colormeasuretest:Control','Expected one control tagged %s.',tag);
end

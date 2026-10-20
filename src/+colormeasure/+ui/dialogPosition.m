function position=dialogPosition(owner,requested,monitors)
%DIALOGPOSITION Center a dialog on its owner and keep it on that monitor.
% Pixel rectangles permit isolated multi-monitor tests without moving windows.
if nargin<3,monitors=get(groot,'MonitorPositions');end
if isnumeric(owner)&&numel(owner)==4
    bounds=owner;
else
    fig=[];
    if ~isempty(owner)&&isgraphics(owner),fig=ancestor(owner,'figure');end
    if isempty(fig),bounds=monitors(1,:);else,bounds=getpixelposition(fig);end
end
center=bounds(1:2)+bounds(3:4)/2;
distance=sum(max(max(monitors(:,1:2)-center,center-(monitors(:,1:2)+monitors(:,3:4))),0).^2,2);
[~,index]=min(distance);screen=monitors(index,:);
margin=[16 48];size=min(requested,max([1 1],screen(3:4)-2*margin));
origin=max(screen(1:2)+margin,min(center-size/2,screen(1:2)+screen(3:4)-margin-size));
position=[origin size];
end

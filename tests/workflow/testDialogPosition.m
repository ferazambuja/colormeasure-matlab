function tests=testDialogPosition
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testDialogsFollowOwnerOnOffsetAndSmallMonitors(t)
monitors=[1 1 1440 900;-1279 1 1280 720;1 901 1024 768];
for bounds={[-1200 50 960 650],[20 960 960 650],[100 100 960 750]}
    p=colormeasure.ui.dialogPosition(bounds{1},[720 690],monitors);
    center=bounds{1}(1:2)+bounds{1}(3:4)/2;
    index=find(all(center>=monitors(:,1:2)&center<=monitors(:,1:2)+monitors(:,3:4),2));
    assertNumElements(t,index,1);monitor=monitors(index,:);
    verifyGreaterThanOrEqual(t,p(1:2),monitor(1:2)+[16 48]);
    verifyLessThanOrEqual(t,p(1:2)+p(3:4),monitor(1:2)+monitor(3:4)-[16 48]);
    verifyLessThanOrEqual(t,p(3:4),[720 690]);
end
end
function testKeyboardMappingAndTextInputGuard(t)
[label,modifiers,hint]=colormeasure.ui.measureShortcut();
verifyEqual(t,label,'Ctrl+Shift+M');verifyEqual(t,modifiers,{'control';'shift'});verifyEqual(t,hint,label);
fig=figure('Visible','off');cleanup=onCleanup(@()delete(fig));
verifyTrue(t,colormeasure.ui.isTextInput(uicontrol(fig,'Style','edit')));
verifyTrue(t,colormeasure.ui.isTextInput(uitextarea(fig)));
verifyTrue(t,colormeasure.ui.isTextInput(uieditfield(fig)));
verifyFalse(t,colormeasure.ui.isTextInput(uibutton(fig)));
verifyFalse(t,colormeasure.ui.isTextInput([]));
end

function tests=testRelativeColor
% Shared-scale chart display and preservation of ordinary preview behavior.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testWhiteBlackAndGrayRetainRelativeBrightness(t)
white=[95.05 100 108.9];XYZ=[zeros(1,3);.18*white;.5*white;white];
[rgb,valid,clipped,context]=colormeasure.colorimetry.relativeColor(XYZ,white,'CIE1931_2deg');
verifyTrue(t,all(valid));verifyEqual(t,rgb(1,:),[0 0 0]);
% IEC sRGB neutral encoding: 0.18 -> 0.4613561295; 0.5 -> 0.7353569831.
% Published rounded inverse matrix leaves channel differences below 2e-7.
verifyEqual(t,rgb(2,:),repmat(.461356129500442,1,3),'AbsTol',2e-7);
verifyEqual(t,rgb(3,:),repmat(.735356983052449,1,3),'AbsTol',2e-7);
verifyEqual(t,rgb(4,:),ones(1,3),'AbsTol',2e-7);
verifyFalse(t,any(clipped(1:3)));verifyTrue(t,clipped(4));
% The white's +2.715e-8 linear green excursion is reported, not concealed.
verifyEqual(t,context.whiteXYZ,white);verifyFalse(t,context.brightnessNormalizedPerSample);
verifyEqual(t,XYZ,[zeros(1,3);.18*white;.5*white;white]);
end
function testOneScaleForAllSamplesAndWhite(t)
white=colormeasure.colorimetry.illuminantWhite('D50',100).XYZ;
XYZ=[.1*white;.4*white;.8*white];
[a,va,ca]=colormeasure.colorimetry.relativeColor(XYZ,white,'CIE1931_2deg');
[b,vb,cb]=colormeasure.colorimetry.relativeColor(XYZ/100,white/100,'CIE1931_2deg');
verifyEqual(t,a,b,'AbsTol',1e-14);verifyEqual(t,va,vb);verifyEqual(t,ca,cb);
verifyTrue(t,all(a(1,:)<a(2,:)));verifyTrue(t,all(a(2,:)<a(3,:)));
verifyNotEqual(t,a(1,:),a(3,:));
end
function testTransferBreakpointAndClipping(t)
white=[.9505 1 1.089];levels=[.003; .0032; 1.2];
[rgb,valid,clipped]=colormeasure.colorimetry.relativeColor(levels*white,white,'CIE1931_2deg');
verifyTrue(t,all(valid));verifyFalse(t,any(clipped(1:2)));verifyTrue(t,clipped(3));
verifyEqual(t,rgb(1,:),repmat(.003*12.92,1,3),'AbsTol',1e-8);
verifyEqual(t,rgb(2,:),repmat(1.055*.0032^(1/2.4)-.055,1,3),'AbsTol',1e-8);
% The transfer endpoint 1.055*1-.055 can round to 1-eps(1)/2.
% Allow one double-precision epsilon in RGB only; clipping flags stay exact.
verifyEqual(t,rgb(3,:),[1 1 1],'AbsTol',eps(1));
[rgb,valid,clipped]=colormeasure.colorimetry.relativeColor([1 0 0],white,'CIE1931_2deg');
verifyTrue(t,valid);verifyTrue(t,clipped);
verifyEqual(t,rgb(1),1,'AbsTol',eps(1));verifyEqual(t,rgb(2),0);
end
function testMissingContextInvalidRowsAndNumericalRange(t)
white=[.9505 1 1.089];
verifyError(t,@()colormeasure.colorimetry.relativeColor([1 1 1],[], 'CIE1931_2deg'),'colormeasure:Colorimetry:RelativeWhite');
verifyError(t,@()colormeasure.colorimetry.relativeColor([1 1 1],white,''),'colormeasure:Colorimetry:RelativeObserver');
verifyError(t,@()colormeasure.colorimetry.relativeColor([1 1 1],white,'CIE1964_10deg'),'colormeasure:Colorimetry:RelativeObserver');
verifyError(t,@()colormeasure.colorimetry.relativeColor([realmax 1 1],white*realmin,'CIE1931_2deg'),'colormeasure:Colorimetry:NumericRange');
[rgb,valid,clipped]=colormeasure.colorimetry.relativeColor([NaN 1 1;-1 1 1;1+1i 1 1],white,'CIE1931_2deg');
verifyFalse(t,any(valid));verifyTrue(t,all(isnan(rgb),'all'));verifyFalse(t,any(clipped));
[rgb,valid,clipped]=colormeasure.colorimetry.relativeColor(zeros(0,3),white,'CIE1931_2deg');
verifySize(t,rgb,[0 3]);verifyEmpty(t,valid);verifyEmpty(t,clipped);
end
function testOrdinaryPreviewPreservesFrozenArithmeticAndFlags(t)
XYZ=[0 0 0;1 0 0;0 1 0;0 0 1;.95047 1 1.08883; ...
    1 2 3;10 20 30;realmax realmax/2 realmax/3;NaN 1 1;-1 1 1;1i 1 1];
[expected,ev,ec]=priorPreview(XYZ);
[rgb,valid,clipped]=colormeasure.colorimetry.previewColor(XYZ);
verifyEqual(t,rgb,expected);verifyEqual(t,valid,ev);verifyEqual(t,clipped,ec);
end
function testDeclaredD50PreviewUsesSameHueWithoutChartBrightnessScale(t)
white=colormeasure.colorimetry.illuminantWhite('D50',100).XYZ;
XYZ=[.04*white;.18*white;.7*white];
[preview,valid]=colormeasure.colorimetry.previewColor(XYZ,white);
[chart,cv]=colormeasure.colorimetry.relativeColor(XYZ,white,'CIE1931_2deg');
verifyTrue(t,all(valid));verifyTrue(t,all(cv));
verifyEqual(t,preview,ones(3),'AbsTol',2e-7);
verifyLessThan(t,max(chart,[],2),ones(3,1));
verifyEqual(t,chart(:,1),chart(:,2),'AbsTol',2e-7);
verifyEqual(t,chart(:,2),chart(:,3),'AbsTol',2e-7);
for observer={'',strings(0),["CIE1931_2deg" "CIE1931_2deg"],string(missing),[],true,struct()}
    verifyError(t,@()colormeasure.colorimetry.relativeColor([1 1 1],white,observer{1}), ...
        'colormeasure:Colorimetry:RelativeObserver');
end
verifyError(t,@()colormeasure.colorimetry.previewColor(XYZ,[]),'colormeasure:Colorimetry:RelativeWhite');
[invalid,v]=colormeasure.colorimetry.previewColor([NaN 1 1;-1 1 1],white);
verifyFalse(t,any(v));verifyTrue(t,all(isnan(invalid),'all'));
end
function [rgb,valid,clipped]=priorPreview(XYZ)
% Frozen pre-extraction arithmetic; this pins normalization, not new science.
valid=all(imag(XYZ)==0,2)&all(isfinite(XYZ),2)&all(real(XYZ)>=0,2);
rgb=NaN(size(XYZ));clipped=false(size(XYZ,1),1);
values=double(real(XYZ(valid,:)));scale=max(values,[],2);scale(scale==0)=1;
values=values./scale;
matrix=[3.2406255 -1.5372080 -.4986286;-.9689307 1.8757561 .0415175;.0557101 -.2040211 1.0569959];
linear=values*matrix.';clipped(valid)=any(linear<0,2);
linear=max(0,linear);scale=max(linear,[],2);scale(scale==0)=1;linear=linear./scale;
encoded=12.92*linear;nonlinear=linear>.0031308;
encoded(nonlinear)=1.055*linear(nonlinear).^(1/2.4)-.055;
rgb(valid,:)=min(1,max(0,encoded));
end

function tests=testIlluminantWhiteAndPreviewColor
% The colorimetry package's illuminant whites (D50, D65, A at a given Y, the
% CIE 1931 observer, Lab of the white itself) and the sRGB preview colour
% (clipping, invalid input, scale invariance).
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function testWhites(t)
for name={'D50','D65','A'}
 w=colormeasure.colorimetry.illuminantWhite(name{1},100);
 verifyEqual(t,w.XYZ(2),100);verifyEqual(t,w.observerId,'CIE1931_2deg');
 verifyEqual(t,colormeasure.colorimetry.XYZ2Lab(w.XYZ,w.XYZ),[100 0 0],'AbsTol',1e-12);
end
verifyError(t,@()colormeasure.colorimetry.illuminantWhite('D65',0),'colormeasure:Colorimetry:WhiteY');
verifyError(t,@()colormeasure.colorimetry.illuminantWhite('D55',100),'colormeasure:Colorimetry:WhiteIlluminant');
verifyError(t,@()colormeasure.colorimetry.illuminantWhite('A',realmax),'colormeasure:Colorimetry:WhiteRange');
end
function testPreview(t)
[rgb,valid,clipped]=colormeasure.colorimetry.previewColor([0 0 0;.95047 1 1.08883;1 0 0;NaN 1 1;-1 1 1]);
verifyEqual(t,rgb(1,:),[0 0 0]);verifyTrue(t,all(rgb(2,:)>0.99));
verifyEqual(t,valid,[true;true;true;false;false]);verifyTrue(t,clipped(3));
verifyTrue(t,all(isnan(rgb(4:5,:)),'all'));
verifyEqual(t,colormeasure.colorimetry.previewColor([1 2 3]),colormeasure.colorimetry.previewColor([10 20 30]),'AbsTol',1e-14);
end

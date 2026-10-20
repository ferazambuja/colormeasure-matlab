function [rgb,clipped]=encodeSRGB(linear)
%ENCODESRGB Clip linear display channels to [0,1], then encode sRGB.
% No brightness normalization. Clipping describes the display, not the device.
% ICC sRGB interpretation, A.7-A.8: https://registry.color.org/rgb-registry/files/sRGB.pdf
% Independent implementation/extraction: Fernando Voltolini de Azambuja, 2026.
clipped=any(linear<0 | linear>1,2);
linear=min(1,max(0,linear));
encoded=12.92*linear; nonlinear=linear>.0031308;
encoded(nonlinear)=1.055*linear(nonlinear).^(1/2.4)-.055;
rgb=min(1,max(0,encoded));
end

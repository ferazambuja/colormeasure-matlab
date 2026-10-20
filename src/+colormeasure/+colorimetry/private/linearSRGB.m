function linear=linearSRGB(XYZ)
%LINEARSRGB CIE 1931 XYZ, D65, Y=1 to unbounded linear sRGB.
% Shared display matrix only; the caller owns white adaptation and scale.
% ICC sRGB interpretation, A.7: https://registry.color.org/rgb-registry/files/sRGB.pdf
% Independent implementation/extraction: Fernando Voltolini de Azambuja, 2026.
matrix=[3.2406255 -1.5372080 -.4986286; ...
    -.9689307 1.8757561 .0415175; .0557101 -.2040211 1.0569959];
linear=XYZ*matrix.';
end

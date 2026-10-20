function white = illuminantWhite(name, Y)
% ILLUMINANTWHITE Standard Lab white from published CIE 1 nm data.
%   WHITE = colormeasure.colorimetry.illuminantWhite('D65', 100) returns CIE 1931 2-degree
%   XYZ with the requested white Y. Supported names: D50, D65, A.
%   Y is explicit and must use the same scale as the measured sample XYZ.
%   This selects a Lab reference; it does not relight or adapt the samples.
%   Fernando Voltolini de Azambuja, 2026.
if ~(ischar(name)&&isrow(name) || isstring(name)&&isscalar(name)) || ...
        ~any(strcmpi(name,{'D50','D65','A'}))
    error('colormeasure:Colorimetry:WhiteIlluminant','Supported illuminants are D50, D65 and A.');
end
if ~isnumeric(Y)||~isscalar(Y)||~isreal(Y)||~isfinite(Y)||Y<=0
    error('colormeasure:Colorimetry:WhiteY','White Y must be finite and greater than zero.');
end
name=upper(char(name)); Y=double(Y);
% Sum CIE illuminant SPD * CIE 1931 CMFs over 360:1:830 nm, divide by Y.
% Derived reference data: CIE, CC BY-SA 4.0. Sources, checksums and method:
% resources/colorimetry/README.md. No measured spectrum is truncated or resampled.
names={'D50','D65','A'};
normalized=[0.964240837883784 1 0.825128116837737; ...
            0.950470558654283 1 1.08882873639588; ...
            1.09850315268456 1 0.355849301338885];
doi={'10.25039/CIE.DS.etgmuqt5','10.25039/CIE.DS.hjfjmt59','10.25039/CIE.DS.8jsxjrsn'};
index=find(strcmp(name,names),1);
xyz=normalized(index,:)*Y;
if any(~isfinite(xyz))||any(xyz<=0)
    error('colormeasure:Colorimetry:WhiteRange','White Y exceeds the calculation range.');
end
white=struct('kind','illuminant','illuminant',name,'Y',Y,'XYZ',xyz, ...
    'observerId','CIE1931_2deg', ...
    'source',['CIE ' doi{index} '; CMFs 10.25039/CIE.DS.xvudnb9b'], ...
    'method','CIE 1 nm SPD and 1931 2-degree CMFs, 360-830 nm sum; white scaled to requested Y');
end

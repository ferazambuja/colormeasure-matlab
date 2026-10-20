function [adapted, meta] = adaptXYZ(XYZ, sourceWhiteXYZ, destinationWhiteXYZ)
% ADAPTXYZ Full linear Bradford adaptation between explicit white chromaticities.
%   N-by-3 or 3-by-N single/double XYZ retains its orientation; 3-by-3 means
%   row samples. Whites are positive 1-by-3 XYZ rows, each normalized to Y=1.
%   Sample brightness is not normalized. Signed inputs/outputs are retained.
%   This predicts corresponding colors; it does not spectrally relight them.
%   Formula and matrix: ICC.1:2004-10, Annex E.3, equations E.1-E.4:
%   https://www.color.org/ICC1V42.pdf#page=102
%   Independent implementation: Fernando Voltolini de Azambuja, 2026.
narginchk(3,3);
[rows, transposed] = orientRows(XYZ,3,'XYZ');
if any(~isfinite(rows),'all')
    error('colormeasure:Colorimetry:InvalidInput','XYZ must contain finite values.');
end
source = normalizedWhite(sourceWhiteXYZ);
destination = normalizedWhite(destinationWhiteXYZ);
bradford = [0.8951 0.2664 -0.1614; -0.7502 1.7135 0.0367; 0.0389 -0.0685 1.0296];
cones = bradford * [source; destination].';
if any(~isfinite(cones),'all') || any(cones<=0,'all')
    error('colormeasure:Colorimetry:InvalidWhite','Whites must give finite positive Bradford cone responses.');
end
if isequal(source,destination)
    transform = eye(3);
else
    transform = bradford \ (diag(cones(:,2)./cones(:,1))*bradford);
end
adapted = rows * transform.';
if any(~isfinite(transform),'all') || any(~isfinite(adapted),'all')
    error('colormeasure:Colorimetry:NumericRange','Chromatic adaptation exceeds the finite calculation range.');
end
if transposed, adapted=adapted.'; end
meta = struct('method','Linear Bradford','degreeOfAdaptation',1, ...
    'sourceWhiteXYZ',double(sourceWhiteXYZ),'destinationWhiteXYZ',double(destinationWhiteXYZ), ...
    'sourceWhiteY1',source,'destinationWhiteY1',destination,'matrix',transform, ...
    'brightnessPolicy','Whites normalized to Y=1; sample XYZ scale retained', ...
    'source','ICC.1:2004-10 Annex E.3; equations E.1-E.4');
end

function white=normalizedWhite(value)
if ~(isa(value,'single')||isa(value,'double')) || ~isreal(value) || ...
        ~isequal(size(value),[1 3]) || any(~isfinite(value)) || any(value<=0)
    error('colormeasure:Colorimetry:InvalidWhite','Whites must be finite positive 1-by-3 single or double XYZ rows.');
end
white=double(value)/double(value(2));
if any(~isfinite(white)) || any(white<=0)
    error('colormeasure:Colorimetry:NumericRange','White normalization exceeds the finite calculation range.');
end
end

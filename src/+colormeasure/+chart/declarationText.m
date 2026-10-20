function text=declarationText(value,label,identifier)
%DECLARATIONTEXT Validate chart declarations on the shared UTF-16 text bound.
% The original text is not trimmed or shortened; nonblank content is required.
if nargin<3,identifier='Measurement:ChartDeclaration';end
assert(colormeasure.session.isText(value)&&~isempty(strtrim(char(value)))&& ...
    numel(char(value))<=colormeasure.chart.Run.MaxDeclarationCodeUnits,identifier, ...
    '%s must be nonblank text of at most 2,048 UTF-16 code units.',label);
text=char(value);
end

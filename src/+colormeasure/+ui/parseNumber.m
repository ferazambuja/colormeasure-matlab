function value=parseNumber(text)
%PARSENUMBER Read one finite real number without separator reinterpretation.
% UI drafts retain their original text; NaN marks an invalid entry until the
% caller reports it and validates the setting or layout's own numeric bounds.
% A period is the decimal separator. Commas are never thousands separators.
% https://www.mathworks.com/help/matlab/ref/str2double.html
% Fernando Voltolini de Azambuja, 2026.
arguments
    text (1,:) char
end
value=NaN;
if isempty(strtrim(text))||contains(text,','),return;end
parsed=str2double(text);
if isscalar(parsed)&&isreal(parsed)&&isfinite(parsed),value=parsed;end
end

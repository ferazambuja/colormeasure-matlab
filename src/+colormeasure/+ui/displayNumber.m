function text=displayNumber(value)
%DISPLAYNUMBER Six significant digits for analysis text; unavailable otherwise.
% Signed finite values are preserved. Result-table cells retain their numeric
% representation separately; this formatter is only for textual analysis.
if isscalar(value)&&isreal(value)&&isfinite(value)
    text=sprintf('%.6g',value);
else
    text='Unavailable';
end
end

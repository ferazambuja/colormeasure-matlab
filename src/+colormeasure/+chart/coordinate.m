function value = coordinate(row, column)
%COORDINATE Canonical chart label: letters for columns, numbers for rows.
%   coordinate(10,27) returns 'AA10'. These labels describe the application's
%   orientation, not a manufacturer's numbering or source traversal.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(2,2);
if ~positiveInteger(row) || ~positiveInteger(column)
    error('colormeasure:Chart:Coordinate', ...
        'Chart row and column must be positive, exactly representable integers.');
end
row=double(row); column=double(column);
letters='';
while column>0
    remainder=mod(column-1,26);
    letters=[char(65+remainder) letters]; %#ok<AGROW> At most twelve letters for flintmax.
    column=floor((column-1)/26);
end
value=[letters sprintf('%.0f',row)];
end

function yes=positiveInteger(value)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&& ...
    value>=1&&value<=flintmax&&value==fix(value);
end

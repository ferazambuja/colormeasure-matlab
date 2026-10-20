function yes = goodIndex(value, count)
%GOODINDEX Whether a value selects one row of the current analysis data.
yes = isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) && ...
    value >= 1 && value <= count && value == fix(value);
end

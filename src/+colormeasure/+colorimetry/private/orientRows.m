function [rows, transposed] = orientRows(values, channels, label)
% ORIENTROWS Validate a color array and normalize its sample orientation.
%   A matching column count wins, including ambiguous square matrices.
%   Computation uses double precision for both single and double input.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 3, label = 'Input'; end
if ~(isa(values, 'double') || isa(values, 'single')) || ~isreal(values) || ~ismatrix(values)
    error('colormeasure:Colorimetry:InvalidInput', '%s must be a real two-dimensional single or double array.', label);
end
transposed = ~any(size(values, 2) == channels);
if transposed
    if ~any(size(values, 1) == channels)
        error('colormeasure:Colorimetry:InvalidShape', '%s must have %s channels in rows or columns.', ...
            label, mat2str(channels));
    end
    values = values.';
end
rows = double(values);
end

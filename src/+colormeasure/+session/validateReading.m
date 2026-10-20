function reading = validateReading(reading, measurements)
%VALIDATEREADING Check one acquired reading before it joins a batch.
%   A reading is one scalar struct of ordinary data, so it can be saved and
%   restored unchanged. With existing MEASUREMENTS, its fields must match
%   theirs so the batch remains one struct array. Session stamps every
%   current direct reading with the same timing and settings fields.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 2, measurements = struct([]); end
assert(isstruct(reading) && isscalar(reading), 'Measurement:InvalidReading', ...
    'The instrument adapter must return one complete struct.');
assert(colormeasure.session.isPlainData(reading), 'Measurement:InvalidReading', ...
    'A reading must contain ordinary data only: no objects, handles or connections.');
if ~isempty(measurements)
    expected = sort(fieldnames(measurements));
    actual = sort(fieldnames(reading));
    assert(isequal(expected, actual), 'Measurement:InvalidReading', ...
        'Reading fields must match the batch. Missing: %s. Unexpected: %s.', ...
        strjoin(setdiff(expected, actual), ', '), strjoin(setdiff(actual, expected), ', '));
end
end

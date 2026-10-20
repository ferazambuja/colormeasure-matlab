function text = utcText(value)
%UTCTEXT Encode one zoned instant in the host record's UTC format.
%   Fernando Voltolini de Azambuja, 2026.
assert(isa(value,'datetime') && isscalar(value) && ~isnat(value) && ...
    ~isempty(value.TimeZone),'Measurement:InvalidTime', ...
    'A timestamp must be one valid, zoned datetime.');
value.TimeZone = 'UTC';
value.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
text = char(value);
end

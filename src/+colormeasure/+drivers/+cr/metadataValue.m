function [value, status] = metadataValue(payload, kind)
%METADATAVALUE Parse documented scalar last-capture replies, never execute text.
% Remote Communication v1.36: exposure suffix msec, sync suffix Hz; Time may be NA.
payload = strtrim(payload);
textKind = ismember(kind,{'text','syncMode','calibrationMode','legacyMatrixMode'});
if textKind, value = ''; else, value = NaN; end
if strcmp(payload,'NA')
    status = 'unavailable';
    return
end
if isempty(payload) || any(payload < 32 | payload > 126)
    error('CR:Metadata', 'Metadata must contain nonempty printable ASCII or the documented NA value.');
end
status = 'available';
if textKind
    % Only known, documented modes may enable a dependent metadata query.
    % CR Remote v1.36 sections 4.3.2.11, .13 and .14. Preserve other
    % printable names as unparsed raw replies; do not guess their settings.
    switch kind
        case 'syncMode'
            allowed = {'None','Auto','Manual','NTSC','PAL','CINEMA'};
        case 'calibrationMode'
            allowed = {'None','Matrix','Match'};
        case 'legacyMatrixMode'
            allowed = {'Disabled','Enabled'};
        otherwise
            allowed = {payload};
    end
    if ~ismember(payload,allowed)
        error('CR:Metadata', 'Metadata mode is not documented by Remote v1.36: %s',payload);
    end
    value = payload;
    return
end
if strcmp(kind,'milliseconds')
    match = regexp(payload,'^(.+)\s+msec$','tokens','once');
elseif strcmp(kind,'hertz')
    match = regexp(payload,'^(.+)\s+Hz$','tokens','once');
else
    match = {payload};
end
if isempty(match)
    error('CR:Metadata', 'Metadata has no documented numeric unit suffix: %s',payload);
end
try
    value = colormeasure.drivers.cr.numbers(strtrim(match{1}),1);
catch err
    error('CR:Metadata', 'Invalid metadata number: %s',err.message);
end
integerKind = ismember(kind,{'integer','positiveInteger'});
if value < 0 || (integerKind && fix(value) ~= value) || ...
        (strcmp(kind,'positiveInteger') && value == 0)
    error('CR:Metadata', 'Metadata requires a nonnegative finite value (integer for count/index fields).');
end
end

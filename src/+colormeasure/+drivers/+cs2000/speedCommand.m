function [command, settings] = speedCommand(payload, allowLegacy)
%SPEEDCOMMAND Validate SPMR before restoring it through SPMS (Rev.7 pp.17-22).
% integrationTimeSeconds is the configured Manual exposure or Multi averaging
% interval. It is not the actual exposure reported by MEDR after acquisition.
% Legacy layouts apply only to old CS-2000 units, never CS-2000A. The default
% accepts either CS-2000 layout when the caller has no model context.
% https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf
if nargin < 2, allowLegacy = true; end
validateattributes(allowLegacy,{'logical'},{'scalar'});
v = colormeasure.drivers.cs2000.numbers(payload);
valid = numel(v) <= 3 && all(v == fix(v)) && ismember(v(1),0:4);
if valid
    switch v(1)
        case {0,1}
            valid = (allowLegacy && isscalar(v)) || (numel(v) == 2 && ismember(v(2),0:2));
        case {2,4}
            valid = ismember(numel(v),[2 3]) && v(2) >= 1 && v(2) <= 16;
            if valid && numel(v) == 3, valid = ismember(v(3),0:2); end
            if v(1) == 4, valid = valid && numel(v) == 3; end
            if ~allowLegacy, valid = valid && numel(v) == 3; end
        case 3
            valid = numel(v) == 3 && v(2) >= 5000 && v(2) <= 120000000 && ismember(v(3),0:1);
    end
end
if ~valid
    error('CS2000:SpeedMode', 'SPMR returned an unsupported speed configuration.');
end
fields = arrayfun(@(x) sprintf('%d',x),v,'UniformOutput',false);
command = ['SPMS,' strjoin(fields,',')];
settings = struct('speedMode',v(1),'integrationTimeSeconds',NaN, ...
    'internalNDMode',2,'internalNDModeSource','reported');
switch v(1)
    case {0,1}
        if numel(v) == 2
            settings.internalNDMode = v(2);
        else
            settings.internalNDModeSource = 'protocol-fixed-auto';
        end
    case {2,4}
        settings.integrationTimeSeconds = v(2);
        if numel(v) == 3
            settings.internalNDMode = v(3);
        else
            settings.internalNDModeSource = 'protocol-fixed-auto';
        end
    case 3
        settings.integrationTimeSeconds = v(2)/1e6;
        settings.internalNDMode = v(3);
end
end

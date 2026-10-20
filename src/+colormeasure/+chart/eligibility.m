function [eligible, reason, kind] = eligibility(context)
%ELIGIBILITY Qualify guided spots from actual mode and quantity, not a model list.
% This stage associates names/history only. It does not establish reflectance,
% positioning, footprint, matched illumination or a reference for color fills.
eligible = false; kind = 'unavailable';
colormeasure.chart.assertDirectSource(context,struct([]));
assert(isstruct(context)&&isscalar(context)&&isfield(context,'material'), ...
    'Chart:Context','Supply a chart context.');
mode = value(context,'mode'); optical = value(context,'opticalMode');
quantity = value(context,'quantity'); workflow = value(context,'workflow');
if ~any(strcmp(workflow,{'spot','tele'})) || ...
        any(contains(lower(mode),{'strip','xy','chart','stored'}))
    reason = 'Guided charts use individual spot readings; this operation does not associate one patch.';
elseif strcmp(optical,'display-only')
    reason = 'This mode is documented for display/projector targets; physical-chart optics are not established.';
elseif any(strcmp(optical,{'ambient','flash','transmission'})) || ...
        any(contains(lower(quantity),{'irradiance','illuminance','flux','exposure','transmittance'}))
    reason = 'This optical mode does not measure a physical reflective chart patch.';
elseif strcmp(optical,'reflective') && any(strcmp(quantity,{'reflectance','surface color'}))
    eligible = true; kind = 'reflective';
    reason = 'Place the measuring footprint inside the patch and follow instrument calibration instructions.';
elseif any(strcmp(optical,{'spot','telescopic'})) && ...
        any(strcmp(quantity,{'radiance','spectral_radiance','luminance','surface color','synthetic spectrum'}))
    eligible = true; kind = 'naming-only';
    reason = 'Keep lighting, geometry and backing stable; these readings retain their acquired quantities.';
elseif strcmp(context.phase,'intended') && ...
        strcmp(optical,'spot') && isempty(quantity)
    eligible = true; kind = 'naming-only';
    reason = 'Check the fitted accessory and patch footprint; the retained reading must establish a suitable spot quantity.';
else
    reason = 'The available quantity and optical mode do not establish a suitable chart spot measurement.';
end
end

function result = value(context,key)
result = '';
if isfield(context.material,key) && ~strcmp(context.material.(key).certainty,'unknown')
    result = char(string(context.material.(key).value));
end
end

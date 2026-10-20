function [eligible,reason,context] = reflectanceRatioEligibility(data,sample,reference)
%REFLECTANCERATIOELIGIBILITY Check declared quantities for an object/reference ratio.
% Matching spectral keys permit comparison, not every derived calculation.
% Adapters explicitly declare reflectanceRatioEligible (logical per row),
% spectralQuantities (cell per row), and optional reflectanceRatioReasons.
% Only radiance or an explicitly declared synthetic radiance demonstration
% can enter this path. Physical reflective-object/setup confirmation is separate.
% This function neither changes readings nor verifies absolute calibration.
% See docs/session/illumination.md for the ratio's assumptions and sources.
eligible=false; reason='Select a sample reading.';
context=struct('sample',struct(),'reference',struct());
if ~isstruct(data)||~isscalar(data)||~isfield(data,'XYZ')|| ...
        ~isnumeric(data.XYZ)||~ismatrix(data.XYZ)||size(data.XYZ,2)~=3
    return
end
count=size(data.XYZ,1);
if ~goodIndex(sample,count),return;end
[ok,reason,context.sample]=row(data,sample,count);
if ~ok,reason=['Sample: ' reason];return;end
if ~goodIndex(reference,count)
    reason='Choose the measured white reference.';return
end
[ok,reason,context.reference]=row(data,reference,count);
if ~ok,reason=['Reference: ' reason];return;end
pair=colormeasure.analysis.compareReadings(data,reference,sample);
reason=pair.spectralReason;
eligible=isempty(reason);
end

function [eligible,reason,context]=row(data,index,count)
eligible=false;reason='Reflectance-ratio eligibility is not declared for this reading.';
context=struct('index',index,'quantity','','units','','adapterDeclaredEligible',false);
if (isfield(data,'hasSpectra')&&isequal(data.hasSpectra,false))|| ...
        ~isfield(data,'spectra')||~iscell(data.spectra)||numel(data.spectra)<index|| ...
        ~isstruct(data.spectra{index})||~isscalar(data.spectra{index})|| ...
        ~all(isfield(data.spectra{index},{'x','y'}))||isempty(data.spectra{index}.x)
    reason='This reading has no spectrum. Chromatic adaptation remains available.';return
end
if ~isfield(data,'reflectanceRatioEligible')||~islogical(data.reflectanceRatioEligible)|| ...
        ~isvector(data.reflectanceRatioEligible)||numel(data.reflectanceRatioEligible)~=count|| ...
        ~isfield(data,'spectralQuantities')||~iscell(data.spectralQuantities)|| ...
        ~isvector(data.spectralQuantities)||numel(data.spectralQuantities)~=count
    return
end
context.quantity=textValue(data.spectralQuantities{index});
context.adapterDeclaredEligible=data.reflectanceRatioEligible(index);
if isfield(data,'spectralUnitsByReading')&&iscell(data.spectralUnitsByReading)&& ...
        numel(data.spectralUnitsByReading)==count
    context.units=textValue(data.spectralUnitsByReading{index});
elseif isfield(data,'spectralUnits')
    context.units=textValue(data.spectralUnits);
end
if ~context.adapterDeclaredEligible
    if isfield(data,'reflectanceRatioReasons')&&iscell(data.reflectanceRatioReasons)&& ...
            numel(data.reflectanceRatioReasons)==count
        detail=textValue(data.reflectanceRatioReasons{index});
        if ~isempty(detail),reason=detail;end
    end
    return
end
if ~ismember(context.quantity,{'radiance','synthetic radiance'})
    reason='Reflectance ratio requires declared radiance; native reflectance and other spectral quantities are not eligible.';
    return
end
eligible=true;reason='';
end

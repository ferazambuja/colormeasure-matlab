function data = viewData(measurements)
% VIEWDATA Adapt retained PR readings for the shared, read-only result view.
%   No color values are recalculated from spectra or written back to records.
%   Fernando Voltolini de Azambuja, 2026.
%   PR-655/PR-670 manual Rev B, p.113 Table 9 and p.116 Data Code 5:
%   codes 11-14 identify radiometric quantities; the example's code 0 is
%   undefined. Equal unknown codes do not establish a common numerical scale.
count = numel(measurements);
data = struct('XYZ', NaN(count, 3), ...
    'observer', 'Observer not confirmed', 'observerId','', ...
    'spectra', {cell(count, 1)}, 'spectralXLabel', 'Wavelength (nm)', ...
    'spectralLabel', 'Spectral reading (instrument units)', 'locusXYZ', [], ...
    'spectralUnits','instrument units', ...
    'xyzComparisonKeys',{cell(count,1)}, ...
    'chromaticityComparisonKeys',{cell(count,1)}, ...
    'spectralComparisonKeys',{cell(count,1)}, ...
    'reflectanceRatioEligible',false(count,1), ...
    'spectralQuantities',{repmat({''},count,1)}, ...
    'reflectanceRatioReasons',{repmat({'Spectral radiance provenance is not established.'},count,1)}, ...
    'observerIds',{repmat({''},count,1)}, ...
    'observerNames',{repmat({'Observer not confirmed'},count,1)}, ...
    'measurementModes',{repmat({'Unavailable'},count,1)});
knownObserver=true;
stored=colormeasure.drivers.pr.storedText();
for index = 1:count
    reading = measurements(index);
    % Recognize the acquisition method, not merely the PR model or XYZ shape.
    method=colormeasure.session.textField(reading,'xyzMethod');
    recognized=knownMethod(method);
    synthetic=isfield(reading,'isSynthetic')&&isequal(reading.isSynthetic,true);
    knownObserver=knownObserver&&recognized;
    if recognized
        data.observerIds{index}='CIE1931_2deg';
        data.observerNames{index}='CIE 1931 2-degree observer';
        if ~synthetic
            % Chromaticity ratios do not require an absolute spectral scale.
            data.chromaticityComparisonKeys{index}=jsonencode({'CIE1931_2deg',false});
        end
    end
    if isfield(reading, 'XYZ') && isnumeric(reading.XYZ) && numel(reading.XYZ) == 3
        data.XYZ(index, :) = reshape(reading.XYZ, 1, 3);
    end
    if isfield(reading, 'lambda') && isfield(reading, 'radiance')
        data.spectra{index} = struct('x', reading.lambda, 'y', colormeasure.drivers.pr.spectrumOf(reading));
    end
    device=colormeasure.session.textField(reading,'deviceType');
    units=colormeasure.session.textField(reading,'spectralUnits');
    if isempty(device)||isempty(units)||~isfield(reading,'unitsCode')|| ...
            ~isnumeric(reading.unitsCode)||~isscalar(reading.unitsCode)|| ...
            ~isreal(reading.unitsCode)||~isfinite(reading.unitsCode)
        continue
    end
    if synthetic
        data.measurementModes{index}='Synthetic spectral reading';
        % Existing demos explicitly declare a common synthetic convention.
        % Their code 0 is not an interpretation of a real instrument reply.
        if isempty(method),continue;end
        if recognized,method='CIE1931_2deg_MCSL_v1';end
        key=jsonencode({{device,method,units},reading.unitsCode,true});
        data.xyzComparisonKeys{index}=key;
        data.chromaticityComparisonKeys{index}=key;
        data.spectralComparisonKeys{index}=key;
        if recognized && reading.unitsCode==0 && ...
                strcmp(units,stored.spectralUnits) && ...
                ismember(device,{'PR-655','PR-670'})
            data.spectralQuantities{index}='synthetic radiance';
            data.reflectanceRatioEligible(index)=true;
            data.reflectanceRatioReasons{index}='';
        end
    elseif ismember(reading.unitsCode,11:14)
        quantities={'radiance','irradiance','radiant intensity','radiant flux'};
        quantity=quantities{reading.unitsCode-10};
        data.measurementModes{index}=['Spectral ' quantity];
        % Matching declared quantities permit same-convention differences.
        % This does not verify calibration or the spectral-density scale.
        % Exposure, aperture, corrected ND and synchronization differences
        % may be intentional; they do not define a different physical unit.
        key=jsonencode({'PR M5 radiometric convention',device,quantity,units});
        data.spectralComparisonKeys{index}=key;
        data.spectralQuantities{index}=quantity;
        data.reflectanceRatioEligible(index)=reading.unitsCode==11;
        if data.reflectanceRatioEligible(index)
            data.reflectanceRatioReasons{index}='';
        else
            data.reflectanceRatioReasons{index}= ...
                ['Reflectance by sample/reference division requires radiance; this reading reports ' quantity '.'];
        end
        if recognized
            data.xyzComparisonKeys{index}=jsonencode({key,'CIE1931_2deg_MCSL_v1'});
        end
    end
    % Empty domain keys withhold code 0, undefined codes and photometric-only
    % unit conventions from calculations whose scale is not established.
end
% The library's complete native CIE observer grid defines the outline. It is
% not resampled to the meter's wavelength spacing or truncated to its range.
persistent locus;
if knownObserver
    % An empty batch shows the configured PR observer before its first reading.
    data.observer='CIE 1931 2-degree observer';data.observerId='CIE1931_2deg';
    if isempty(locus), locus = colormeasure.colorimetry.observer(); end
    data.locusXYZ = locus;
end
if count > 0 && isfield(measurements, 'isSynthetic') && all([measurements.isSynthetic])
    data.spectralLabel = 'Synthetic spectral reading';
    data.spectralUnits = 'synthetic units';
end
end

function yes = knownMethod(value)
% Accept the explicitly recorded observer and integration convention.
stored = colormeasure.drivers.pr.storedText();
yes = strcmp(value, stored.xyzMethod);
end

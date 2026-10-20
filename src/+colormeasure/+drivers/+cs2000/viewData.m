function data = viewData(readings)
%VIEWDATA Present retained CS-2000 values without recomputing measurements.
% Absolute XYZ scale is not established by the verified communication protocol.
% Separate keys allow chromaticity/spectral comparisons without asserting that
% reconnecting readings share an unchanged XYZ scale. Exposure/ND need not match.
count = numel(readings);
emptyKeys = cell(count,1);
stored = colormeasure.drivers.cs2000.storedText();
data = struct('XYZ',NaN(count,3),'observer','Observer not confirmed', ...
    'observerId','','locusXYZ',[],'spectra',{cell(count,1)}, ...
    'spectralXLabel','Wavelength (nm)','spectralLabel','Spectral radiance', ...
    'spectralUnits',stored.spectralUnits, ...
    'xyzComparisonKeys',{emptyKeys},'chromaticityComparisonKeys',{emptyKeys}, ...
    'xyzScaleDeclarationKeys',{emptyKeys}, ...
    'spectralComparisonKeys',{emptyKeys},'observerNames',{cell(count,1)}, ...
    'reflectanceRatioEligible',false(count,1), ...
    'spectralQuantities',{repmat({''},count,1)}, ...
    'reflectanceRatioReasons',{repmat({'Spectral radiance provenance is not established.'},count,1)}, ...
    'observerIds',{emptyKeys},'xyzSources',{cell(count,1)}, ...
    'xyzUnitsByReading',{cell(count,1)},'spectralUnitsByReading',{cell(count,1)}, ...
    'spectralLabels',{cell(count,1)},'measurementModes',{repmat({'Unavailable'},count,1)});
known = false(count,1);
for index = 1:count
    reading = readings(index);
    source = colormeasure.session.textField(reading,'xyzMethod');
    units = colormeasure.session.textField(reading,'xyzUnits');
    spectralUnits = colormeasure.session.textField(reading,'spectralUnits');
    if strcmp(colormeasure.session.textField(reading,'spectralQuantity'),'radiance')
        data.measurementModes{index}='Spectral radiance';
    end
    synthetic = isfield(reading,'isSynthetic') && isequal(reading.isSynthetic,true);
    liveMethod = strcmp(source,colormeasure.drivers.cs2000.CS2000.nativeXYZSource);
    % Retain the acquired source; recognize only the declared calculation.
    syntheticMethod = strcmp(source, stored.syntheticXYZMethod);
    known(index) = strcmp(colormeasure.session.textField(reading,'observerId'),'CIE1931_2deg') && ...
        ((~synthetic && liveMethod) || (synthetic && syntheticMethod));
    data.xyzSources{index} = source;
    data.xyzUnitsByReading{index} = units;
    data.spectralUnitsByReading{index} = spectralUnits;
    data.observerNames{index} = 'Observer not confirmed';
    if isfield(reading,'XYZ') && isnumeric(reading.XYZ) && numel(reading.XYZ) == 3
        data.XYZ(index,:) = reshape(reading.XYZ,1,3);
    end
    if all(isfield(reading,{'lambda','spectralData'}))
        data.spectra{index} = struct('x',reading.lambda,'y',reading.spectralData);
    end
    if known(index)
        data.observerNames{index} = 'CIE 1931 2-degree observer';
        data.observerIds{index} = 'CIE1931_2deg';
        data.chromaticityComparisonKeys{index} = jsonencode({'CIE1931_2deg',synthetic});
    end
    if synthetic
        data.spectralLabels{index} = 'Synthetic spectral reading';
        validUnits = strcmp(spectralUnits,stored.syntheticSpectralUnits);
        % Generated units are labelled, never established by an instrument.
        if known(index) && strcmp(units,stored.syntheticXYZUnits) && ...
                isfield(reading,'xyzUnitsConfirmed') && isequal(reading.xyzUnitsConfirmed,false)
            data.xyzComparisonKeys{index} = jsonencode({stored.syntheticXYZMethod,units,'synthetic'});
        end
    else
        data.spectralLabels{index} = 'Spectral radiance';
        validUnits = strcmp(spectralUnits,stored.spectralUnits);
        % Live XYZ keys remain empty: changes of instrument scale across
        % reconnects cannot be detected from retained protocol fields.
        if known(index)
            data.xyzScaleDeclarationKeys{index} = scaleDeclarationKey(reading);
        end
    end
    if known(index) && validUnits && strcmp(colormeasure.session.textField(reading,'spectralQuantity'),'radiance') && ...
            isfield(reading,'spectralUnitsConfirmed') && isequal(reading.spectralUnitsConfirmed,~synthetic)
        data.spectralComparisonKeys{index} = jsonencode({'radiance',spectralUnits,synthetic});
        data.spectralQuantities{index} = 'radiance';
        if synthetic, data.spectralQuantities{index} = 'synthetic radiance'; end
        data.reflectanceRatioEligible(index) = true;
        data.reflectanceRatioReasons{index} = '';
    end
end
if isempty(readings) || all(known)
    data.observer = 'CIE 1931 2-degree observer';
    data.observerId = 'CIE1931_2deg';
end
if isempty(readings) || any(known)
    data.locusXYZ = colormeasure.colorimetry.observer();
end
if count > 0 && all(arrayfun(@(x) isfield(x,'isSynthetic') && isequal(x.isSynthetic,true),readings))
    data.spectralLabel = 'Synthetic spectral reading';
    data.spectralUnits = stored.syntheticSpectralUnits;
end
end

function key = scaleDeclarationKey(reading)
% An operator may separately declare a common scale for a selected pair and
% white. This key only rejects known convention/identity differences; it is
% neither a unit verification nor an automatic permission to compare XYZ.
key = '';
stored = colormeasure.drivers.cs2000.storedText();
if ~isfield(reading,'instrumentMetadata') || ...
        ~strcmp(colormeasure.session.textField(reading,'xyzUnits'),stored.xyzUnits) || ...
        ~isfield(reading,'xyzUnitsConfirmed') || ~isequal(reading.xyzUnitsConfirmed,false)
    return
end
metadata = reading.instrumentMetadata;
if ~isstruct(metadata) || ~isscalar(metadata) || ...
        ~all(isfield(metadata,{'identity','conditions','acquisition'}))
    return
end
identity = metadata.identity; conditions = metadata.conditions; acquisition = metadata.acquisition;
if ~isstruct(identity) || ~isscalar(identity) || ~isstruct(conditions) || ...
        ~isscalar(conditions) || ~isstruct(acquisition) || ~isscalar(acquisition)
    return
end
model = colormeasure.session.textField(identity,'model'); serial = colormeasure.session.textField(identity,'serialNumber');
if isempty(model) || numel(model) > 9 || any(model < 32 | model > 126) || ...
        ~strcmp(model,colormeasure.session.textField(reading,'deviceType')) || ...
        isempty(regexp(serial,'^\d{7}$','once')) || ...
        ~enumField(identity,'variation',[1 2])
    return
end
if (strcmp(model,'CS-2000') && identity.variation ~= 1) || ...
        (strcmp(model,'CS-2000A') && identity.variation ~= 2)
    return
end
if ~strcmp(colormeasure.session.textField(acquisition,'xyzSource'),colormeasure.session.textField(reading,'xyzMethod')) || ...
        ~enumField(acquisition,'observer',0) || ~enumField(conditions,'observer',0) || ...
        ~enumField(conditions,'closeupLens',0:1) || ...
        ~enumField(conditions,'externalNDFilter',0:2) || ...
        ~enumField(conditions,'measurementAngle',0:2) || ...
        ~enumField(conditions,'userCalibrationChannel',0:10)
    return
end
angles = [1 0.2 0.1];
if ~enumField(conditions,'measurementAngleDegrees',angles(conditions.measurementAngle+1)) || ...
        ~isfield(acquisition,'userCalibration')
    return
end
calibration = acquisition.userCalibration;
if ~isstruct(calibration) || ~isscalar(calibration) || ...
        ~enumField(calibration,'channel',conditions.userCalibrationChannel) || ...
        ~isfield(calibration,'name')
    return
end
rawName = calibration.name;
if ~((ischar(rawName) && (isrow(rawName) || isempty(rawName))) || ...
        (isstring(rawName) && isscalar(rawName) && ~ismissing(rawName)))
    return
end
status = colormeasure.session.textField(calibration,'status'); name = colormeasure.session.textField(calibration,'name');
if conditions.userCalibrationChannel == 0
    if ~strcmp(status,'factory-standard') || ~isempty(name)
        return
    end
elseif ~strcmp(status,'available') || isempty(strtrim(name)) || ...
        numel(name) > 10 || any(name < 32 | name > 126)
    return
end
key = jsonencode({'CS2000 operator scale declaration',model,identity.variation,serial, ...
    colormeasure.session.textField(reading,'xyzMethod'),'CIE1931_2deg',conditions.closeupLens, ...
    conditions.externalNDFilter,conditions.measurementAngle, ...
    conditions.userCalibrationChannel,status,name});
end

function valid = enumField(record,field,allowed)
valid = isfield(record,field);
if ~valid
    return
end
value = record.(field);
valid = isnumeric(value) && isscalar(value) && isreal(value) && ...
    isfinite(value) && ismember(value,allowed);
end

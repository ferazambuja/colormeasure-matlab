function data = viewData(readings,model)
%VIEWDATA Read-only CR presentation; never integrate, normalize or resample.
if nargin < 2
    model = '';
    if ~isempty(readings), model = colormeasure.session.textField(readings(1),'deviceType'); end
end
count = numel(readings);
hasSpectra = ~ismember(model,{'CR100','CR-100'});
data = struct('XYZ',NaN(count,3),'observer','Observer not confirmed','observerId','', ...
    'spectra',{cell(count,1)},'spectralXLabel','Wavelength (nm)', ...
    'spectralLabel','Spectral reading','spectralUnits','See per-reading units', ...
    'locusXYZ',[], ...
    'xyzComparisonKeys',{repmat({''},count,1)},'xyzScaleDeclarationKeys',{repmat({''},count,1)}, ...
    'chromaticityComparisonKeys',{repmat({''},count,1)}, ...
    'spectralComparisonKeys',{repmat({''},count,1)},'observerNames',{repmat({''},count,1)}, ...
    'reflectanceRatioEligible',false(count,1), ...
    'spectralQuantities',{repmat({''},count,1)}, ...
    'reflectanceRatioReasons',{repmat({'Spectral radiance provenance is not established.'},count,1)}, ...
    'observerIds',{repmat({''},count,1)},'xyzSources',{repmat({''},count,1)}, ...
    'xyzUnitsByReading',{repmat({''},count,1)},'spectralUnitsByReading',{repmat({''},count,1)}, ...
    'spectralLabels',{repmat({''},count,1)},'hasSpectra',hasSpectra,'noSpectrumReason','', ...
    'measurementModes',{repmat({'Unavailable'},count,1)});
if ~hasSpectra
    data.noSpectrumReason = 'CR-100 is a tristimulus colorimeter and does not return a spectrum.';
    data.reflectanceRatioReasons = repmat({data.noSpectrumReason},count,1);
end
stored = colormeasure.drivers.cr.storedText();
for index = 1:count
    r = readings(index);
    if isfield(r,'XYZ') && isnumeric(r.XYZ) && numel(r.XYZ)==3
        data.XYZ(index,:) = reshape(r.XYZ,1,3);
    end
    source = colormeasure.session.textField(r,'xyzMethod');
    observer = colormeasure.session.textField(r,'observerId');
    data.xyzSources{index} = source;
    data.xyzUnitsByReading{index} = colormeasure.session.textField(r,'xyzUnits');
    units = colormeasure.session.textField(r,'spectralUnits');
    data.spectralUnitsByReading{index} = units;
    quantity = colormeasure.session.textField(r,'spectralQuantity');
    if ~hasSpectra
        data.measurementModes{index}='Tristimulus';
    elseif ~isempty(quantity)
        data.measurementModes{index}=['Spectral ' quantity];
    end
    data.spectralLabels{index} = strtrim([quantity ' (' units ')']);
    if isfield(r,'lambda') && isfield(r,'spectralData') && ~isempty(r.lambda)
        data.spectra{index} = struct('x',r.lambda,'y',r.spectralData);
    end
    synthetic = isfield(r,'isSynthetic') && isequal(r.isSynthetic,true);
    device = colormeasure.session.textField(r,'deviceType');
    host = strcmp(source,stored.host) ...
        && ismember(device,{'CR-250','CR-300'}) && ~synthetic;
    colorimeter = strcmp(source,stored.native) ...
        && strcmp(device,'CR-100') && ~synthetic;
    generated = synthetic && strcmp(source, ...
        stored.synthetic) ...
        && ismember(device,{'CR-100','CR-250','CR-300'});
    known = strcmp(observer,'CIE1931_2deg') && (host||colorimeter||generated);
    if ~known, continue; end
    data.observerIds{index} = observer;
    data.observerNames{index} = 'CIE 1931 2-degree observer';
    data.chromaticityComparisonKeys{index} = jsonencode({observer,synthetic});
    if colorimeter
        data.xyzScaleDeclarationKeys{index} = scaleDeclarationKey(r);
    end
    if generated && strcmp(colormeasure.session.textField(r,'xyzUnits'),stored.syntheticXYZUnits)
        data.xyzComparisonKeys{index} = jsonencode({device,source,observer,stored.syntheticXYZUnits});
        if hasSpectra && strcmp(units,stored.syntheticSpectralUnits)
            data.spectralComparisonKeys{index} = jsonencode({device,source,stored.syntheticSpectralUnits});
            if ismember(device,{'CR-250','CR-300'}) && strcmp(quantity,stored.syntheticQuantity)
                data.spectralQuantities{index} = 'synthetic radiance';
                data.reflectanceRatioEligible(index) = true;
                data.reflectanceRatioReasons{index} = '';
            end
        end
    elseif host && knownQuantity(r)
        % Absolute units remain provisional. Identical declared conventions
        % permit differences on that same scale, not a calibration claim.
        data.xyzComparisonKeys{index} = jsonencode({device,source,observer, ...
            r.radiometricType,r.xyzUnits,units,r.spectralUnitsConfirmed});
        data.spectralComparisonKeys{index} = jsonencode({device,source, ...
            r.radiometricType,units,r.spectralUnitsConfirmed});
        data.spectralQuantities{index} = quantity;
        data.reflectanceRatioEligible(index) = r.radiometricType==0;
        if data.reflectanceRatioEligible(index)
            data.reflectanceRatioReasons{index} = '';
        else
            data.reflectanceRatioReasons{index} = ...
                ['Reflectance by sample/reference division requires radiance; this reading reports ' quantity '.'];
        end
    end
end
if count==0 || all(strcmp(data.observerIds,'CIE1931_2deg'))
    data.observer = 'CIE 1931 2-degree observer';
    data.observerId = 'CIE1931_2deg';
    data.locusXYZ = colormeasure.colorimetry.observer();
end
if count>0 && isscalar(unique(data.spectralUnitsByReading))
    data.spectralUnits = data.spectralUnitsByReading{1};
end
if count>0 && isscalar(unique(data.spectralLabels))
    data.spectralLabel = data.spectralLabels{1};
end
end

function key = scaleDeclarationKey(r)
% Eligibility for a separate operator declaration, never automatic agreement.
key = '';
stored = colormeasure.drivers.cr.storedText();
if ~strcmp(colormeasure.session.textField(r,'xyzUnits'),stored.colorimeterXYZUnits) || ...
        ~isfield(r,'instrumentMetadata') || ~isstruct(r.instrumentMetadata) || ...
        ~isscalar(r.instrumentMetadata)
    return
end
meta = r.instrumentMetadata;
if ~all(isfield(meta,{'identity','captureSettings','metadataResponses'})) || ...
        ~isstruct(meta.identity) || ~isscalar(meta.identity) || ...
        ~isstruct(meta.captureSettings) || ~isscalar(meta.captureSettings) || ...
        ~isstruct(meta.metadataResponses)
    return
end
identity = meta.identity;
serial = colormeasure.session.textField(identity,'serialNumber'); firmware = colormeasure.session.textField(identity,'firmware');
if ~strcmp(colormeasure.session.textField(identity,'model'),'CR-100') || ...
        ~printable(serial) || ~printable(firmware)
    return
end
settings = meta.captureSettings;
fields = {'accessory','filters','aperture','userCalibrationMode'};
calibration = colormeasure.session.textField(settings,'userCalibrationMode');
if strcmp(calibration,'Matrix'), fields{end+1}='matrixId';
elseif strcmp(calibration,'Match'), fields{end+1}='matchId';
elseif ~strcmp(calibration,'None'), return
end
entries = meta.metadataResponses;
if ~all(isfield(entries,{'field','status','value'})), return; end
values = cell(size(fields));
for index=1:numel(fields)
    selected = arrayfun(@(entry) strcmp(colormeasure.session.textField(entry,'field'),fields{index}),entries);
    if nnz(selected)~=1, return; end
    entry=entries(selected); value=colormeasure.session.textField(settings,fields{index});
    if ~strcmp(colormeasure.session.textField(entry,'status'),'available') || ~printable(value) || ...
            ~isequal(entry.value,settings.(fields{index}))
        return
    end
    values{index}=value;
end
key=jsonencode({'CR100 operator scale declaration v1','CR-100',serial,firmware, ...
    r.xyzMethod,r.observerId,r.xyzUnits,fields,values});
end

function yes = printable(value)
yes = ~isempty(strtrim(value)) && all(value>=32 & value<=126);
end

function yes = knownQuantity(r)
yes = false;
if ~all(isfield(r,{'radiometricType','spectralUnitsConfirmed'})) || ...
        ~isnumeric(r.radiometricType) || ~isscalar(r.radiometricType) || ...
        ~ismember(r.radiometricType,0:3) || ~isequal(r.spectralUnitsConfirmed,false)
    return
end
stored = colormeasure.drivers.cr.storedText();
i = r.radiometricType+1;
yes = strcmp(colormeasure.session.textField(r,'spectralQuantity'),stored.radiometricQuantities{i}) ...
    && strcmp(colormeasure.session.textField(r,'spectralUnits'),[stored.radiometricDensityUnits{i} stored.provisionalSuffix]) ...
    && strcmp(colormeasure.session.textField(r,'xyzUnits'),[stored.radiometricXYZUnits{i} stored.provisionalSuffix]);
end

function result = deriveIllumination(data, sample, config)
% DERIVEILLUMINATION Derived adaptation or object-color result; no acquisition.
%   Original adapter data is retained in the result and is never modified.
%   Adaptation uses white chromaticities, not an absolute luminance conversion.
%   Reflectance requires eligible radiance spectra and a setup declaration.
%   See docs/session/illumination.md for assumptions, equations and source attribution.
%   Fernando Voltolini de Azambuja, 2026.
result=struct('available',false,'reason','Select a reading.', ...
    'mode','','label','','XYZ',NaN(1,3),'whiteXYZ',NaN(1,3), ...
    'rgb',NaN(1,3),'coordinates',NaN(1,2),'spectrum',struct('x',[],'y',[]), ...
    'details',{{}},'provenance',struct(),'sourceXYZ',[], ...
    'sourceSpectrum',[],'referenceSpectrum',[],'createdAtUTC','', ...
    'config',config,'sampleIndex',sample);
try
    if ~isstruct(data)||~isscalar(data)||~isfield(data,'XYZ')|| ...
            ~isnumeric(data.XYZ)||size(data.XYZ,2)~=3|| ...
            ~goodIndex(sample,size(data.XYZ,1))
        return
    end
    if ~isstruct(config)||~isscalar(config)||~isfield(config,'mode')
        error('Measurement:Illumination','Choose a color view.');
    end
    result.mode=validatestring(config.mode,{'adaptation','reflectance'});
    result.sourceXYZ=data.XYZ(sample,:);
    result.sourceSpectrum=spectrum(data,sample);
    result.createdAtUTC=colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
    if strcmp(result.mode,'adaptation')
        requireObserver(data,sample);
        [source,sourceInfo]=white(data,sample,colormeasure.session.fieldOr(config,'sourceWhite',''));
        [destination,destinationInfo]=white(data,sample,colormeasure.session.fieldOr(config,'destinationWhite',''));
        [result.XYZ,method]=colormeasure.colorimetry.adaptXYZ(result.sourceXYZ,source,destination);
        result.whiteXYZ=destination/destination(2);
        result.label='Adapted color (Bradford)';
        result.provenance=struct('method',method,'sourceWhite',sourceInfo, ...
            'destinationWhite',destinationInfo,'observer','CIE1931_2deg', ...
            'XYZConvention','Transformed sample scale; no per-sample Y normalization', ...
            'whiteXYZConvention','Chromaticity reference Y=1; not a same-scale Lab white');
        result.details={'Full Bradford adaptation; white chromaticities only.', ...
            'Acquired readings unchanged. Not a relit spectrum.', ...
            'Destination changes coordinates; the preview is always adapted to display D65.'};
    else
        ref=colormeasure.session.fieldOr(config,'reference',0);
        if ~goodIndex(ref,size(data.XYZ,1))
            error('Measurement:Illumination','Choose the measured white reference.');
        end
        [eligible,reason,quantityContext]=colormeasure.analysis.reflectanceRatioEligibility(data,sample,ref);
        if ~eligible
            error('Measurement:Illumination','%s',reason);
        end
        if ~isequal(colormeasure.session.fieldOr(config,'confirmedSetup',false),true)
            error('Measurement:Illumination', ...
                'Confirm an externally illuminated, nonfluorescent reflective object and matched reference setup/scale.');
        end
        a=result.sourceSpectrum; b=spectrum(data,ref);
        if isempty(a)||isempty(b)||~isequal(a.x(:),b.x(:))
            error('Measurement:Illumination','Sample and reference need the same wavelength grid.');
        end
        result.referenceSpectrum=b;
        w=double(a.x(:));
        refData=colormeasure.session.fieldOr(config,'referenceReflectance',[]);
        if isempty(refData)
            if ~isequal(colormeasure.session.fieldOr(config,'assumePerfectReference',false),true)
                error('Measurement:Illumination', ...
                    'Load white-reference reflectance data or explicitly assume an ideal white.');
            end
            referenceR=ones(size(w));
            referenceKind='Assumed ideal white: relative spectral ratio';
        else
            validateattributes(refData,{'numeric'},{'real','finite','2d','ncols',2});
            if size(refData,1)<2||any(diff(refData(:,1))<=0)||any(refData(:,2)<=0)
                error('Measurement:Illumination', ...
                    'White-reference data needs increasing wavelengths and positive fractions (1 = 100%%).');
            end
            referenceR=interp1(double(refData(:,1)),double(refData(:,2)),w,'linear',NaN);
            if any(~isfinite(referenceR))
                error('Measurement:Illumination','White-reference data must cover every measured wavelength.');
            end
            referenceKind='Reflectance factor from supplied reference data';
        end
        [reflectance,ratioInfo]=colormeasure.colorimetry.reflectanceFromReference(a.y,b.y,referenceR,w);
        target=colormeasure.session.fieldOr(config,'targetIlluminant','');
        targetSpectrum=[];
        if isnumeric(target)
            if ~goodIndex(target,size(data.XYZ,1))
                error('Measurement:Illumination','Choose a target illuminant spectrum.');
            end
            targetSpectrum=spectrum(data,target);
            check=colormeasure.analysis.compareReadings(data,sample,target);
            if isempty(targetSpectrum)||~isempty(check.spectralReason)|| ...
                    ~isequal(w,double(targetSpectrum.x(:)))
                error('Measurement:Illumination', ...
                    'The illuminant reading needs compatible spectral units and the same wavelength grid.');
            end
            target=targetSpectrum.y;
            targetLabel=sprintf('Reading %d treated as illuminant SPD',config.targetIlluminant);
        else
            targetLabel=char(target);
        end
        [result.XYZ,result.whiteXYZ,integrationInfo]=colormeasure.colorimetry.reflectanceXYZ(reflectance,w,target);
        result.spectrum=struct('x',w,'y',reflectance(:));
        result.label=referenceKind;
        result.provenance=struct('ratio',ratioInfo,'integration',integrationInfo, ...
            'referenceIndex',ref,'referenceKind',referenceKind, ...
            'referenceReflectanceOnGrid',referenceR,'targetIlluminant',targetLabel, ...
            'targetSpectrum',targetSpectrum,'setupDeclaredBy','operator', ...
            'setupDeclaredAtUTC',result.createdAtUTC,'observer','CIE1931_2deg');
        result.provenance.quantityContext=quantityContext;
        result.provenance.XYZConvention='Relative object XYZ; perfect diffuser Y=100 on available grid';
        result.provenance.whiteXYZConvention='Same-grid perfect diffuser Y=100; same scale as derived XYZ';
        result.details={referenceKind,['Target: ' targetLabel], ...
            sprintf('%.0f–%.0f nm; perfect diffuser Y = 100 over this measured range.',w(1),w(end)), ...
            'Reflective object and matched setup declared; fluorescence is not modeled.'};
    end
    [result.coordinates,valid]=colormeasure.analysis.chromaticity(result.XYZ,'uv');
    % Display encoding has a fixed D65 white. Adapt the derived destination
    % XYZ to D65 for the swatch only, preserving XYZ/plot coordinates above.
    previewValid=false; clipped=false;
    try
        d65=colormeasure.colorimetry.illuminantWhite('D65',1);
        preview=colormeasure.colorimetry.adaptXYZ(result.XYZ,result.whiteXYZ,d65.XYZ);
        [result.rgb,previewValid,clipped]=colormeasure.colorimetry.previewColor(preview);
    catch previewProblem
        % A narrow-band target can produce valid object XYZ but no usable
        % adapting white. Display limitations must not discard that result.
        result.details{end+1}=['Preview unavailable: ' previewProblem.message];
    end
    result.provenance.previewWhite='D65';
    result.provenance.previewClipped=clipped;
    result.provenance.previewBrightnessNormalized=true;
    if ~valid, result.details{end+1}='Derived XYZ has no valid chromaticity; values are retained.'; end
    if ~previewValid, result.details{end+1}='Derived XYZ has no displayable sRGB preview.'; end
    if clipped, result.details{end+1}='Preview clipped to sRGB gamut.'; end
    result.available=true; result.reason='';
catch problem
    result.reason=problem.message;
end
end

function [xyz,info]=white(data,sample,selection)
if isnumeric(selection)
    if ~goodIndex(selection,size(data.XYZ,1))
        error('Measurement:Illumination','Choose a source and destination white.');
    end
    requireObserver(data,selection);
    pair=colormeasure.analysis.compareReadings(data,sample,selection);
    if ~isempty(pair.chromaticityReason)
        error('Measurement:Illumination','White and sample chromaticity conventions must match.');
    end
    xyz=data.XYZ(selection,:);
    info=struct('kind','reading','index',selection,'XYZ',xyz, ...
        'assumption','Operator-selected adapting white');
else
    info=colormeasure.colorimetry.illuminantWhite(selection,1); xyz=info.XYZ;
end
end

function requireObserver(data,index)
% Each reading's own observer; a batch-level summary never stands in for it.
id='';
if isfield(data,'observerIds')&&iscell(data.observerIds)&&numel(data.observerIds)>=index
    id=data.observerIds{index};
end
if ~strcmp(id,'CIE1931_2deg')
    error('Measurement:Illumination','This view requires confirmed CIE 1931 2-degree coordinates.');
end
end

function value=spectrum(data,index)
value=[];
if isfield(data,'spectra')&&iscell(data.spectra)&&numel(data.spectra)>=index
    s=data.spectra{index};
    if isstruct(s)&&isscalar(s)&&all(isfield(s,{'x','y'})), value=s; end
end
end

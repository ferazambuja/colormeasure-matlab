function result = compareReadings(data, reference, sample, white, declaration)
% COMPAREREADINGS Read-only pair comparison from an adapter's viewData.
%   A=REFERENCE, B=SAMPLE; signed differences are B-A. WHITE is a separate
%   reading used for both Lab conversions, zero when none is selected, or
%   struct('illuminant','D65','Y',100) for an explicit standard reference.
%   Preset Y must use the samples' XYZ scale; it is not a sample normalization.
%   No per-sample normalization, resampling, or black subtraction is applied.
%   Adapters declare compatibility separately with xyzComparisonKeys,
%   chromaticityComparisonKeys and spectralComparisonKeys (one cell per row).
%   An absent or empty domain key withholds that domain. Keys declare a
%   common numerical convention, not physical calibration. XYZ/Lab,
%   chromaticity and spectra are independent.
%   DECLARATION optionally records an operator's common-scale confirmation:
%   confirmed=true, referenceIndex, sampleIndex, white (this exact argument),
%   and nonblank declaredAtUTC. Matching xyzScaleDeclarationKeys must permit
%   the selected rows; known automatic XYZ keys cannot be overridden. The
%   declaration is a calculation assumption, not instrument validation.
%   Spectral RMS does not require XYZ. Validated spectralWavelengths and
%   spectralDifference are column vectors, with differences in B-A order.
%   Fernando Voltolini de Azambuja, 2026.
%   CIELAB: https://cie.co.at/eilvterm/17-23-076
%   CIEDE2000: Sharma, Wu & Dalal (2005), doi:10.1002/col.20070, Eq. 2-22.
%   RMS: https://www.mathworks.com/help/matlab/ref/rms.html (definition).
%   Code origins, interpretation limits and signed-component conventions:
%   docs/session/color-science.md. Numerical agreement is not perceptual validation.
if nargin<4, white=0; end
if nargin<5, declaration=struct([]); end
result=struct('referenceIndex',reference,'sampleIndex',sample,'whiteIndex',0, ...
    'whiteReference',struct(),'whiteXYZ',NaN(1,3),'observer','', ...
    'xyzComparisonKey','','chromaticityComparisonKey','','spectralComparisonKey','', ...
    'scaleDeclaration',struct([]),'scaleDeclarationEligible',false, ...
    'deltaXYZ',NaN(1,3),'deltaUV',NaN(1,2),'deltaXY',NaN(1,2), ...
    'Lab',NaN(2,3),'deltaLab',NaN(1,3),'deltaC',NaN,'deltaH',NaN, ...
    'deltaE00',NaN,'spectralRMS',NaN,'spectralRange',[], ...
    'spectralWavelengths',[],'spectralDifference',[], ...
    'spectralStep',NaN,'spectralUnits','','colorReason','Select two readings.', ...
    'spectralReason','Select two readings.','chromaticityReason','Select two readings.', ...
    'pairReason','Select two readings.');
if ~isstruct(data)||~isscalar(data), return; end
count=readingCount(data);
if ~goodIndex(reference,count)||~goodIndex(sample,count), return; end
indices=[reference sample];
[xyzCompatible,result.xyzComparisonKey]=compatible(data,indices,'xyzComparisonKeys');
[chromaCompatible,result.chromaticityComparisonKey]=compatible(data,indices,'chromaticityComparisonKeys');
[spectraCompatible,result.spectralComparisonKey]=compatible(data,indices,'spectralComparisonKeys');
if ~xyzCompatible
    [result.scaleDeclarationEligible,key]=scaleEligibility(data,indices,white,count);
    if result.scaleDeclarationEligible&&validDeclaration(declaration,indices,white)
        xyzCompatible=true;
        result.xyzComparisonKey=['operator-declared:' key];
        result.scaleDeclaration=declaration;
        result.scaleDeclaration.source='operator';
    end
end
result.observer=commonText(rowText(data,indices,'observerNames','observer'));
result.colorReason='Common numerical scale not established.';
result.chromaticityReason='Chromaticity conventions are unknown or differ.';
result.spectralReason='Spectral quantities or unit conventions are unknown or differ.';
if isfield(data,'hasSpectra')&&isequal(data.hasSpectra,false)
    spectraCompatible=false;
    result.spectralComparisonKey='';
    result.spectralReason='This instrument does not report a spectrum.';
end
result.pairReason='Measurement conventions are unknown or differ.';
conditionReason=conditionDifference(data,indices);
if ~isempty(conditionReason)
    result.pairReason=conditionReason;
    if ~xyzCompatible,result.colorReason=conditionReason;end
    if ~chromaCompatible,result.chromaticityReason=conditionReason;end
    if ~spectraCompatible&&isfield(data,'hasSpectra')&&data.hasSpectra,result.spectralReason=conditionReason;end
end
if ~any([xyzCompatible chromaCompatible spectraCompatible]), return; end
result.pairReason='';
xyz=readXYZ(data,indices);
if chromaCompatible
    result.chromaticityReason='Comparable XYZ values are unavailable.';
    if ~isempty(xyz)
        [uv,validUV]=colormeasure.analysis.chromaticity(xyz,'uv');
        [xy,validXY]=colormeasure.analysis.chromaticity(xyz,'xy');
        if all(validUV), result.deltaUV=uv(2,:)-uv(1,:); end
        if all(validXY), result.deltaXY=xy(2,:)-xy(1,:); end
        if all(validUV)&&all(validXY)
            result.chromaticityReason='';
        else
            result.chromaticityReason='Chromaticity requires finite, nonnegative, nonzero XYZ.';
        end
    end
end
if xyzCompatible && ~isempty(xyz) && isreal(xyz) && all(isfinite(xyz),'all')
    difference=xyz(2,:)-xyz(1,:);
    if all(isfinite(difference))
        result.deltaXYZ=difference;
    else
        xyzCompatible=false;
        result.colorReason='XYZ differences exceed the calculation range.';
    end
end
if xyzCompatible&&isempty(xyz)
    result.colorReason='Comparable XYZ values are unavailable.';
elseif xyzCompatible
    result.colorReason='Choose a Lab white reading or illuminant.';
    w=[];
    if goodIndex(white,count)
        result.whiteIndex=white;
        w=readXYZ(data,white);
        result.whiteReference=struct('kind','reading','index',white);
        if isempty(w)
            result.colorReason='White XYZ values are unavailable.';
        elseif ~compatible(data,[reference sample white],'xyzComparisonKeys')&& ...
                isempty(result.scaleDeclaration)
            result.colorReason='White uses different or unknown measurement conventions.';
            w=[];
        end
    elseif isstruct(white)&&isscalar(white)
        result.colorReason='Preset white requires illuminant and positive Y.';
        if all(isfield(white,{'illuminant','Y'}))
            observerIds=rowText(data,indices,'observerIds','observerId');
            if ~all(strcmp(observerIds,'CIE1931_2deg'))
                result.colorReason='Illuminant presets require CIE 1931 2-degree XYZ.';
            else
                try
                    result.whiteReference=colormeasure.colorimetry.illuminantWhite(white.illuminant,white.Y);
                    w=result.whiteReference.XYZ;
                catch problem
                    if ~startsWith(problem.identifier,'colormeasure:Colorimetry:White'),rethrow(problem);end
                    result.colorReason=problem.message;
                end
            end
        end
    end
    if ~isempty(w)
        result.whiteXYZ=w;
        if ~isreal(w)||any(~isfinite(w))||any(w<=0)
            result.colorReason='White XYZ must be finite and positive.';
        elseif ~isreal(xyz)||any(~isfinite(xyz),'all')||any(xyz<0,'all')
            result.colorReason='Color difference requires finite, nonnegative XYZ.';
        else
            % XYZ2Lab divides both samples by the same white. A common scale
            % cancels without falsely promising absolute photometric units.
            try
                lab=colormeasure.colorimetry.XYZ2Lab(xyz,w);
            catch problem
                if ~strcmp(problem.identifier,'colormeasure:Colorimetry:NumericRange'),rethrow(problem);end
                lab=NaN(2,3);
            end
            if isreal(lab)&&all(isfinite(lab),'all')
                result.Lab=lab; result.deltaLab=lab(2,:)-lab(1,:);
                chroma=hypot(lab(:,2),lab(:,3));
                result.deltaC=chroma(2)-chroma(1);
                % Signed CIELAB hue chord (B-A), not CIEDE2000's primed term.
                % Reporting policy: withhold it if either hue angle is undefined.
                if all(chroma>0)
                    hue=atan2d(lab(:,3),lab(:,2));
                    dh=hue(2)-hue(1);
                    if dh>180,dh=dh-360;elseif dh< -180,dh=dh+360;end
                    result.deltaH=2*sqrt(chroma(1))*sqrt(chroma(2))*sind(dh/2);
                end
                try
                    result.deltaE00=colormeasure.colorimetry.deltaE00(lab(2,:),lab(1,:));
                catch problem
                    if ~strcmp(problem.identifier,'colormeasure:Colorimetry:NumericRange'),rethrow(problem);end
                    result.deltaE00=NaN;
                end
                if isreal(result.deltaE00)&&isfinite(result.deltaE00)
                    result.colorReason='';
                else
                    result.deltaE00=NaN;
                    result.colorReason='Color difference exceeds the calculation range.';
                end
            else
                result.colorReason='Sample-to-white ratios exceed the calculation range.';
            end
        end
    end
end
if ~spectraCompatible, return; end
result.spectralReason='Comparable spectra are unavailable.';
if ~isfield(data,'spectra')||~iscell(data.spectra)||numel(data.spectra)<max(reference,sample), return; end
a=data.spectra{reference}; b=data.spectra{sample};
if ~goodSpectrum(a)||~goodSpectrum(b), return; end
x=double(a.x(:)); y=double(b.x(:));
if ~isequal(x,y)
    result.spectralReason='Wavelength grids differ; no resampling is applied.'; return
end
try
    [value,difference]=colormeasure.colorimetry.spectralRMS(double(a.y(:)),x,double(b.y(:)),y);
catch problem
    switch problem.identifier
        case 'colormeasure:Colorimetry:Wavelength'
            result.spectralReason='Spectral RMS requires positive, uniform increasing wavelengths.';
        case 'colormeasure:Colorimetry:NumericRange'
            result.spectralReason='Spectral difference exceeds the calculation range.';
        otherwise
            rethrow(problem);
    end
    return
end
result.spectralRMS=value; result.spectralRange=x([1 end]).'; result.spectralStep=x(2)-x(1);
result.spectralWavelengths=x; result.spectralDifference=difference;
result.spectralUnits=commonText(rowText(data,indices,'spectralUnitsByReading','spectralUnits'));
result.spectralReason='';
end

function count=readingCount(data)
% Capabilities may be missing independently; their row identities still agree.
count=0;
if isfield(data,'XYZ')&&isnumeric(data.XYZ)&&ismatrix(data.XYZ)&&size(data.XYZ,2)==3
    count=size(data.XYZ,1);
end
for field={'spectra','xyzComparisonKeys', ...
        'chromaticityComparisonKeys','spectralComparisonKeys'}
    if isfield(data,field{1})&&iscell(data.(field{1}))
        count=max(count,numel(data.(field{1})));
    end
end
end
function xyz=readXYZ(data,indices)
xyz=[];
if isfield(data,'XYZ')&&isnumeric(data.XYZ)&&ismatrix(data.XYZ)&& ...
        size(data.XYZ,2)==3&&size(data.XYZ,1)>=max(indices)
    xyz=double(data.XYZ(indices,:));
end
end
function [yes,key]=compatible(data,indices,field)
% A complete, nonempty domain declaration is required for this metric.
key='';
yes=isfield(data,field)&&iscell(data.(field))&&numel(data.(field))>=max(indices);
if ~yes, return; end
keys=data.(field)(indices);
yes=all(cellfun(@(value) ischar(value)&&isrow(value)&&~isempty(value),keys))&& ...
    all(strcmp(keys,keys{1}));
if yes, key=keys{1}; end
end
function yes=validDeclaration(declaration,indices,white)
required={'confirmed','referenceIndex','sampleIndex','white','declaredAtUTC'};
yes=isstruct(declaration)&&isscalar(declaration)&&all(isfield(declaration,required))&& ...
    isequal(declaration.confirmed,true)&& ...
    isequaln(declaration.referenceIndex,indices(1))&& ...
    isequaln(declaration.sampleIndex,indices(2))&& ...
    isequaln(declaration.white,white)&& ...
    ~isempty(strtrim(textValue(declaration.declaredAtUTC)));
end
function [yes,key]=scaleEligibility(data,indices,white,count)
yes=false; key='';
if goodIndex(white,count), indices=[indices white]; end
% Eligibility is a separate adapter declaration. Chromaticity keys
% cannot establish a common XYZ scale, even when the operator checks a box.
if ~isfield(data,'xyzScaleDeclarationKeys'), return; end
[eligible,candidateKey]=compatible(data,indices,'xyzScaleDeclarationKeys');
if ~eligible||~unconfirmedScale(data,indices), return; end
yes=true; key=candidateKey;
end
function yes=unconfirmedScale(data,indices)
field='xyzComparisonKeys';
% No automatic declaration means unknown. Malformed or partially populated
% declarations are not permission to replace an existing scale convention.
yes=~isfield(data,field);
if yes, return; end
keys=data.(field);
if isempty(keys), yes=true; return; end
if ~iscell(keys)||numel(keys)<max(indices), return; end
yes=all(cellfun(@isempty,keys(indices)));
end
function values=rowText(data,indices,rowField,scalarField)
% Per-reading metadata overrides batch labels, even when blank/incomplete.
values=repmat({''},size(indices));
if isfield(data,rowField)
    supplied=data.(rowField);
    if ~iscell(supplied)||numel(supplied)<max(indices), return; end
    for index=1:numel(indices), values{index}=textValue(supplied{indices(index)}); end
elseif isfield(data,scalarField)
    values(:)={textValue(data.(scalarField))};
end
end
function value=commonText(values)
value='';
if ~isempty(values)&&all(strcmp(values,values{1})), value=values{1}; end
end
function yes=goodSpectrum(value)
yes=isstruct(value)&&isscalar(value)&&all(isfield(value,{'x','y'}));
if ~yes, return; end
yes=isnumeric(value.x)&&isnumeric(value.y)&&isreal(value.x)&&isreal(value.y)&& ...
    isvector(value.x)&&isvector(value.y)&&numel(value.x)>1&& ...
    numel(value.x)==numel(value.y)&&all(isfinite(value.x))&&all(isfinite(value.y));
end

function reason=conditionDifference(data,indices)
% A driver's condition keys describe numerical conditions, never proof of
% calibration quality or matching physical geometry/accessories.
reason='';
if ~isfield(data,'measurementConditionKeys'),return;end
labels=rowText(data,indices,'measurementConditions','');
if any(cellfun(@isempty,labels)),return;end
keys=rowText(data,indices,'measurementConditionKeys','');
if any(cellfun(@isempty,keys))
    reason=sprintf('Measurement condition is unconfirmed: A: %s; B: %s.',labels{1},labels{2});
elseif ~strcmp(keys{1},keys{2})
    reason=sprintf('Measurement conditions differ: A: %s; B: %s.',labels{1},labels{2});
end
end

function [spd, meta] = illuminantSpectrum(name, wavelength)
% ILLUMINANTSPECTRUM Bundled CIE D50, D65 or A relative SPD on a supplied grid.
%   Wavelengths are uniform double nm values within 300-830 nm. Output is an
%   N-by-1 relative SPD. Native integer samples are exact; fractional samples
%   use linear interpolation, never extrapolation. For A this interpolation
%   is a table approximation; CIE metadata recommends the related formula.
%   Original datasets and metadata are unmodified, CIE CC BY-SA 4.0.
%   Sources/checksums: resources/colorimetry/README.md. No runtime network access.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(2,2);
if ~((ischar(name)&&isrow(name))||(isstring(name)&&isscalar(name)&&~ismissing(name))) || ...
        ~any(strcmpi(name,{'D50','D65','A'}))
    error('colormeasure:Colorimetry:WhiteIlluminant','Supported illuminants are D50, D65 and A.');
end
[wavelength,step]=uniformGrid(wavelength);
if wavelength(1)<300 || wavelength(end)>830
    error('colormeasure:Colorimetry:IlluminantDomain','Illuminant wavelengths must stay within the bundled 300-830 nm range.');
end
name=upper(char(name)); names={'D50','D65','A'}; index=find(strcmp(name,names),1);
stems={'CIE_std_illum_D50','CIE_std_illum_D65','CIE_std_illum_A_1nm'};
doi={'10.25039/CIE.DS.etgmuqt5','10.25039/CIE.DS.hjfjmt59','10.25039/CIE.DS.8jsxjrsn'};
hashes={'b23049c6f7b266c1c1fbe147aa271e8930ca02d6e569c5ae1804c036faea4193', ...
    'e76f210bffff3d552ef7113025da5f325d5dfec200dd4b878b1a2f3a507032cb', ...
    '61ef23fe146b8b665c74706717ab28cec7db6c9022993490bdc71991f43cb59b'};
persistent tables
if isempty(tables), tables=cell(1,3); end
if isempty(tables{index})
    root = colormeasure.root();
    candidate=readmatrix(fullfile(root,'resources','colorimetry',[stems{index} '.csv']));
    if ~isequal(size(candidate),[531 2]) || ~isequal(candidate(:,1),(300:830)') || ...
            any(~isfinite(candidate),'all') || any(candidate(:,2)<0)
        error('colormeasure:Colorimetry:IlluminantData','The bundled CIE illuminant table is invalid.');
    end
    tables{index}=candidate;
end
values=tables{index};
if all(wavelength==fix(wavelength))
    spd=values(wavelength-299,2);
    interpolation='Exact native samples';
else
    spd=interp1(values(:,1),values(:,2),wavelength,'linear');
    interpolation='Linear table interpolation';
end
meta=struct('name',name,'source',['CIE ' doi{index}], ...
    'sourceFile',[stems{index} '.csv'],'sourceSHA256',hashes{index}, ...
    'license','CC BY-SA 4.0','nativeRangeNm',[300 830],'nativeStepNm',1, ...
    'wavelengthRangeNm',wavelength([1 end]).','wavelengthStepNm',step, ...
    'interpolation',interpolation,'extrapolation','None', ...
    'units','Relative spectral power distribution');
end

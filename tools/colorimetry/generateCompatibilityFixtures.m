function generateCompatibilityFixtures(schoolRoot)
% Optional maintainer tool; ordinary library use/tests do not need MCSL-Tools.
% Generate frozen expected results using the school implementation, never this
% library's functions. Inspect source changes before replacing the reference.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
directory = java.io.File(char(schoolRoot));
if ~directory.isAbsolute(), directory = java.io.File(pwd,char(schoolRoot)); end
schoolRoot = char(directory.getCanonicalPath());
assert(isfolder(schoolRoot),'colormeasure:Colorimetry:BenchmarkReference','Supply one existing school checkout folder.');
source = jsondecode(fileread(fullfile(root,'tools','colorimetry','reference-source.json')));
for j=1:numel(source.files)
    fid=fopen(fullfile(schoolRoot,source.files(j).path),'rb');
    assert(fid>=0,'colormeasure:Colorimetry:BenchmarkReference','Missing school reference file.');
    raw=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(raw);
    hash=reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]);
    assert(strcmpi(hash,source.files(j).sha256),'colormeasure:Colorimetry:BenchmarkReference','Reference source changed; review before regenerating.');
end
oldpath = path; cleanup = onCleanup(@() path(oldpath));
oldfolder = pwd; folderCleanup = onCleanup(@() cd(oldfolder));
cd(fullfile(schoolRoot,'Convert'));
addpath(fullfile(schoolRoot,'Convert'));
assert(strcmp(which('spec2XYZ'),fullfile(schoolRoot,'Convert','spec2XYZ.m')),'colormeasure:Colorimetry:BenchmarkReference', ...
    'School reference dependency resolves outside the selected Convert folder: %s','spec2XYZ');
clear spec2XYZ getObserverFunction
assert(strcmp(which('getObserverFunction'),fullfile(schoolRoot,'Convert','getObserverFunction.m')),'colormeasure:Colorimetry:BenchmarkReference', ...
    'School reference dependency resolves outside the selected Convert folder: %s','getObserverFunction');
assert(strcmp(which('ObsFunctions.mat'),fullfile(schoolRoot,'Convert','ObsFunctions.mat')),'colormeasure:Colorimetry:BenchmarkReference', ...
    'School reference dependency resolves outside the selected Convert folder: %s','ObsFunctions.mat');
wavelengths = {(380:4:780)',(380:2:780)',(380:1:780)', ...
    (380.25:2:780.25)',(350:5:850)',(360:830)',(380:4:388)'};
cases = struct([]);
for k=1:numel(wavelengths)
    w = wavelengths{k};
    s = [ones(size(w)),exp(-0.5*((w-555)/50).^2), ...
        exp(-0.5*((w-612)/4).^2),zeros(size(w)),1e-5*sin(w/13)];
    cases(k).wavelength = w;
    cases(k).spectra = s;
    cases(k).XYZ = spec2XYZ(s,w);
    cases(k).integral = sum(s,1).'*(w(2)-w(1));
end
w = (380:4:388)'; s = reshape(1:9,3,3)/100;
cases(end+1) = struct('wavelength',w,'spectra',s, ...
    'XYZ',spec2XYZ(s,w),'integral',sum(s,1).'*(w(2)-w(1)));
provenance = struct('project',source.project, ...
    'revision',source.revision, ...
    'functions',{{source.files.path}}, ...
    'sourceFiles',source.files, ...
    'convention','CIE1931 2deg, spline, inclusive uniform sum, inherited vacuum-wavelength normalization');
save(fullfile(root,'tests','colorimetry','data','mcsl-spectra-reference.mat'),'cases','provenance');
end

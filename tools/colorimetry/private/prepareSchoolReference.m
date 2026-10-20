function [cleanup,outputFile] = prepareSchoolReference(schoolRoot,requiredFiles,outputFile)
% Isolate the explicitly selected baseline, including its bare MAT-file loads.
% Fernando Voltolini de Azambuja, 2026.
originalFolder=pwd; originalPath=path;
cleanup=onCleanup(@()restore(originalFolder,originalPath));
source=java.io.File(char(schoolRoot));
if ~source.isAbsolute(), source=java.io.File(fullfile(originalFolder,char(schoolRoot))); end
folder=fullfile(char(source.getCanonicalPath()),'Convert');
if ~isempty(outputFile)
    output=java.io.File(char(outputFile));
    if ~output.isAbsolute(), output=java.io.File(fullfile(originalFolder,char(outputFile))); end
    outputFile=char(output.getCanonicalPath());
end
for index=1:numel(requiredFiles)
    assert(isfile(fullfile(folder,requiredFiles{index})), 'colormeasure:Colorimetry:BenchmarkReference', ...
        'Missing school benchmark dependency: %s',fullfile(folder,requiredFiles{index}));
end
cd(folder); addpath(folder,'-begin');
for index=1:numel(requiredFiles)
    name=requiredFiles{index};
    if ~isempty(fileparts(name)), continue; end % Private helper resolution is lexical.
    assert(strcmp(which(name),fullfile(folder,name)), 'colormeasure:Colorimetry:BenchmarkReference', ...
        'School benchmark dependency resolves outside the selected Convert folder: %s',name);
end
% Baseline functions cache data loaded by bare filename. Reset after selection.
clear spec2XYZ getObserverFunction XYZ2CCT
end

function restore(originalFolder,originalPath)
clear spec2XYZ getObserverFunction XYZ2CCT
cd(originalFolder); path(originalPath);
end

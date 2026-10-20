function report=benchmarkColorKernels(schoolRoot,outputFile)
% Optional developer timing: warm numerical kernels, no instrument operations.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<2, outputFile=[]; end
[restore,outputFile]=prepareSchoolReference(schoolRoot,{'XYZ2Lab.m','XYZ2uvY.m','XYZ2xyY.m','xyY2uvY.m', ...
    'XYZ2CCT.m',fullfile('private','XYZ2uvY1960.m'),'PlanckLocus.mat'},outputFile); %#ok<ASGLU>
addpath(fullfile(root,'src'));
x=repmat([0.9687838667891457 1 1.121180717781349],32,1);
w=[.95047 1 1.08883];
oldLab=XYZ2Lab(x,w);newLab=colormeasure.colorimetry.XYZ2Lab(x,w);
assert(max(abs(oldLab-newLab),[],'all')<1e-10,'colormeasure:Colorimetry:BenchmarkParity','Lab differs from the school reference before timing.');
oldUV=XYZ2uvY(x);newUV=colormeasure.colorimetry.XYZ2uvY(x);
assert(max(abs(oldUV-newUV),[],'all')<1e-14,'colormeasure:Colorimetry:BenchmarkParity','uvY differs from the school reference before timing.');
[a,b]=XYZ2CCT(x);[c,d]=colormeasure.colorimetry.XYZ2CCT(x);
assert(max(abs(a-c))<1e-7 && max(abs(b-d))<1e-10,'colormeasure:Colorimetry:BenchmarkParity','CCT differs from the school reference before timing.');
old={@()XYZ2Lab(x,w),@()XYZ2uvY(x),@()XYZ2CCT(x)};
new={@()colormeasure.colorimetry.XYZ2Lab(x,w),@()colormeasure.colorimetry.XYZ2uvY(x),@()colormeasure.colorimetry.XYZ2CCT(x)};
times=zeros(3,3,2);
for i=1:3
    for round=1:3
        if mod(round,2)
            times(i,round,1)=timeit(old{i}); times(i,round,2)=timeit(new{i});
        else
            times(i,round,2)=timeit(new{i}); times(i,round,1)=timeit(old{i});
        end
    end
end
school=median(times(:,:,1),2); standalone=median(times(:,:,2),2);
report=table(["Lab";"uv1976";"CCT"],school,standalone,school./standalone, ...
    'VariableNames',{'Calculation','SchoolSeconds','StandaloneSeconds','Speedup'});
disp(report);
if nargin>1,writetable(report,outputFile);end
end

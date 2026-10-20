function report = benchmarkAgainstMCSL(schoolRoot, outputFile)
% BENCHMARKAGAINSTMCSL Optional developer comparison; not a runtime dependency.
%   Compare repeated conversions, not serial acquisition or physical accuracy.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<2, outputFile=[]; end
[restore,outputFile]=prepareSchoolReference(schoolRoot,{'spec2XYZ.m','getObserverFunction.m','ObsFunctions.mat'},outputFile); %#ok<ASGLU>
addpath(fullfile(root,'src'));
rows=cell(0,7);
for step=[4 2 1]
    wl=(380:step:780)'; plan=colormeasure.colorimetry.XYZIntegrator(wl);
    for n=[1 32 1024]
        spectra=exp(-0.5*((wl-(500+mod(1:n,100)))/35).^2);
        expected=spec2XYZ(spectra,wl); actual=plan.convert(spectra);
        err=max(abs(expected-actual),[],'all');
        assert(err<1e-8,'colormeasure:Colorimetry:BenchmarkParity','Compatibility check failed before timing.');
        baseline=timeit(@()spec2XYZ(spectra,wl));
        convenience=timeit(@()colormeasure.colorimetry.spectra2XYZ(spectra,wl));
        prepared=timeit(@()plan.convert(spectra));
        rows(end+1,:)={numel(wl),n,baseline,convenience,prepared,baseline/prepared,err}; %#ok<AGROW>
    end
end
report=cell2table(rows,'VariableNames',{'Wavelengths','Spectra','SchoolSeconds', ...
    'StandaloneSeconds','PreparedSeconds','PreparedSpeedup','MaxAbsoluteXYZDifference'});
disp(report);
if nargin>1
    writetable(report,outputFile);
end
end

function [report, details] = benchmarkMATLAB(outputFile)
% BENCHMARKMATLAB Compare colormeasure with public MathWorks calculation APIs.
%   [report, details] = benchmarkMATLAB() runs synthetic numerical checks and
%   55 timing cases. benchmarkMATLAB('timing.csv') also writes the table.
%   Optional developer tool: xyz2lab and imcolordiff require Image Processing
%   Toolbox. The colormeasure runtime does not. No device or school checkout is used.
%
%   Every variant is warmed with 1000 consumed calls. Timings are medians of
%   three timeit estimates in alternating variant order. Up to 32 color rows
%   and all RMS cases use batches of 1000 calls, including loop/dispatch overhead. A zero
%   estimate is marked unresolved, never interpreted as zero computation cost.
%   Direct APIs, validated wrappers, and wrappers with a per-call path check
%   are separate cases; wrapper overhead is part of a potential integration.
%   MATLAB path and random-generator state are restored when this returns.
%
%   Public APIs only; no MathWorks implementation is copied:
%   https://www.mathworks.com/help/images/ref/xyz2lab.html
%   https://www.mathworks.com/help/images/ref/imcolordiff.html
%   https://www.mathworks.com/help/matlab/ref/rms.html
%   https://www.mathworks.com/help/matlab/ref/timeit.html
%   Fernando Voltolini de Azambuja, 2026. See docs/colorimetry/performance.md.
narginchk(0, 1);
if nargin > 0 && ~(ischar(outputFile) && isrow(outputFile) || ...
        isstring(outputFile) && isscalar(outputFile) && ~ismissing(outputFile))
    error('colormeasure:Colorimetry:BenchmarkOutput', 'Output must be one CSV file path.');
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldPath = path; pathCleanup = onCleanup(@()path(oldPath));
oldRng = rng; rngCleanup = onCleanup(@()rng(oldRng));
addpath(fullfile(root,'src'));
assert(strcmp(which('colormeasure.colorimetry.XYZ2Lab'),fullfile(root,'src','+colormeasure','+colorimetry','XYZ2Lab.m')), ...
    'colormeasure:Colorimetry:BenchmarkShadowed', 'A different colormeasure package is selected.');
metadata = struct('release',version('-release'), 'version',version, ...
    'computer',computer, 'whiteXYZ',[95 100 108], 'rngSeed',72019, ...
    'rounds',3, 'warmupCalls',1000, 'smallBatchCallsPerEstimate',1000, ...
    'rmsCallsPerEstimate',1000);
for name = {'xyz2lab','imcolordiff','rms'}
    metadata.functionPaths.(name{1}) = official(name{1});
end
rng(metadata.rngSeed,'twister');
white = metadata.whiteXYZ;
parity = checkParity(root,white);
fprintf('Numerical checks passed; warming and timing public MATLAB APIs.\n');
bench = struct('calculation',{},'size',{},'variant',{},'seconds',{}, ...
    'medianSeconds',{},'callsPerEstimate',{},'belowResolution',{});
variants = {'colormeasure','MATLAB direct','MATLAB validated', ...
    'MATLAB validated + resolver'};
for count = [1 2 32 1024 32768]
    repetitions = 1;
    if count <= 32, repetitions = 1000; end
    xyz = (.01 + 1.5*rand(count,3)).*white;
    labA = [100*rand(count,1),100*rand(count,2)-50];
    labB = [100*rand(count,1),100*rand(count,2)-50];
    calls = {@()colormeasure.colorimetry.XYZ2Lab(xyz,white), ...
        @()xyz2lab(xyz,'WhitePoint',white), ...
        @()wrappedLab(xyz,white,false),@()wrappedLab(xyz,white,true)};
    bench = runGroup(bench,'Lab',count,calls,variants,repetitions);
    calls = {@()colormeasure.colorimetry.deltaE00(labA,labB),@()officialDE(labA,labB), ...
        @()wrappedDE(labA,labB,false),@()wrappedDE(labA,labB,true)};
    bench = runGroup(bench,'DeltaE00',count,calls,variants,repetitions);
end
for count = [101 201 401]
    lambda = linspace(380,780,count)';
    a = rand(count,1); b = rand(count,1); residual = b-a;
    calls = {@()colormeasure.colorimetry.spectralRMS(a,lambda,b,lambda),@()rms(residual), ...
        @()scaledRMS(residual),@()wrappedRMS(a,lambda,b,lambda,false), ...
        @()wrappedRMS(a,lambda,b,lambda,true)};
    variants = {'colormeasure','MATLAB direct on residual','MATLAB scaled on residual', ...
        'MATLAB validated','MATLAB validated + resolver'};
    bench = runGroup(bench,'Spectral RMS',count,calls,variants,1000);
end
report = struct2table(rmfield(bench,'seconds'));
details = struct('metadata',metadata,'parity',parity,'timings',bench);
disp(report);
if nargin > 0, writetable(report,outputFile); end
end

function parity = checkParity(root,white)
threshold = (6/29)^3;
ratios = [zeros(1,3);ones(1,3);[-1 -.1 -.001]; ...
    [threshold-eps(threshold),threshold,threshold+eps(threshold)]; ...
    [eps,realmin,1];2*rand(2000,3)-.5];
xyz = ratios.*white;
ours = colormeasure.colorimetry.XYZ2Lab(xyz,white);
native = xyz2lab(xyz,'WhitePoint',white);
parity.lab = struct('rows',size(xyz,1), ...
    'maxAbsDifference',max(abs(ours-native),[],'all'));
assert(isreal(native) && all(isfinite(native),'all') && ...
    parity.lab.maxAbsDifference < 1e-10, ...
    'colormeasure:Colorimetry:BenchmarkParity', 'MATLAB Lab differs on the signed/breakpoint cases.');
fixture = readmatrix(fullfile(root,'tests','colorimetry','data','ciede2000.txt'));
assert(isequal(size(fixture),[34 7]),'colormeasure:Colorimetry:BenchmarkFixture', ...
    'The Sharma fixture must contain all 34 reference pairs.');
ours = colormeasure.colorimetry.deltaE00(fixture(:,1:3),fixture(:,4:6));
native = officialDE(fixture(:,1:3),fixture(:,4:6));
parity.sharma = struct('pairs',size(fixture,1), ...
    'maxAbsDifference',max(abs(ours-native)), ...
    'nativeMaxReferenceError',max(abs(native-fixture(:,7))), ...
    'colormeasureMaxReferenceError',max(abs(ours-fixture(:,7))));
assert(isreal(native) && all(isfinite(native)) && ...
    parity.sharma.maxAbsDifference <= 5e-5 && ...
    parity.sharma.nativeMaxReferenceError <= 5e-5 && ...
    parity.sharma.colormeasureMaxReferenceError <= 5e-5, ...
    'colormeasure:Colorimetry:BenchmarkParity', 'CIEDE2000 reference parity failed.');
% Extreme inputs document contract differences; unlike the ordinary cases,
% native agreement is not presumed. Scaling must precede native RMS here.
extraA = [50 0 0;50 20 0;50 -20 1e-10; ...
    50 1e50 1e50;50 1e100 1e100;50 1e150 1e150];
extraB = [50 0 0;50 0 20;50 -20 -1e-10; ...
    55 1e50 -1e50;55 1e100 -1e100;55 1e150 -1e150];
parity.extremeDE = struct('A',extraA,'B',extraB, ...
    'colormeasure',capture(@()colormeasure.colorimetry.deltaE00(extraA,extraB)), ...
    'native',capture(@()officialDE(extraA,extraB)));
parity.extremeLab = struct('XYZ',realmax*[1 1 1],'white',realmin*[1 1 1], ...
    'colormeasure',capture(@()colormeasure.colorimetry.XYZ2Lab(realmax*[1 1 1],realmin*[1 1 1])), ...
    'native',capture(@()xyz2lab(realmax*[1 1 1],'WhitePoint',realmin*[1 1 1])));
profiles = {randn(101,1),repmat(1e300,101,1), ...
    repmat(1e-300,101,1),repmat(realmax/2,101,1)};
values = zeros(numel(profiles),3); lambda = (380:4:780)';
for k = 1:numel(profiles)
    residual = profiles{k};
    expected = colormeasure.colorimetry.spectralRMS(zeros(101,1),lambda,residual,lambda);
    scaled = scaledRMS(residual);
    assert(isfinite(scaled) && abs(scaled/expected-1) < 1e-14, ...
        'colormeasure:Colorimetry:BenchmarkParity', 'Scaled RMS differs on an extreme-input case.');
    values(k,:) = [expected,rms(residual),scaled];
end
parity.rms = array2table(values,'VariableNames',{'colormeasure','nativeRaw','nativeScaled'}, ...
    'RowNames',{'ordinary','large1e300','tiny1eMinus300','realmaxHalf'});
end

function bench = runGroup(bench,calculation,count,calls,variants,repetitions)
expected = calls{1}();
for k = 1:numel(calls)
    actual = calls{k}();
    if strcmp(calculation,'DeltaE00')
        tolerance = 5e-5; % Published reference precision; no bit-parity claim.
    else
        tolerance = 1e-10*max(1,abs(expected));
    end
    assert(isequal(size(expected),size(actual)) && isreal(actual) && ...
        all(isfinite(actual),'all') && ...
        all(abs(actual-expected) <= tolerance,'all'), ...
        'colormeasure:Colorimetry:BenchmarkParity', 'A timing variant differs before timing.');
    repeated(calls{k},1000);
end
times = zeros(3,numel(calls));
for pass = 1:3
    order = 1:numel(calls);
    if mod(pass,2)==0, order=fliplr(order); end
    for k = order
        if repetitions == 1
            times(pass,k) = timeit(calls{k},1);
        else
            times(pass,k) = timeit(@()repeated(calls{k},repetitions),1)/repetitions;
        end
    end
end
for k = 1:numel(calls)
    seconds = median(times(:,k));
    bench(end+1) = struct('calculation',calculation,'size',count, ...
        'variant',variants{k},'seconds',times(:,k),'medianSeconds',seconds, ...
        'callsPerEstimate',repetitions,'belowResolution',any(times(:,k)<=0)); %#ok<AGROW>
    fprintf('%s N=%d %-28s %.9g seconds\n',calculation,count,variants{k},seconds);
end
end

function total = repeated(call,count)
% Consume one returned value so the repeated kernel remains observable.
total = 0;
for k = 1:count
    result = call(); total = total+result(1);
end
end

function result = capture(call)
try
    result = struct('value',call(),'identifier','');
catch problem
    result = struct('value',[],'identifier',problem.identifier);
end
end

function Lab = wrappedLab(XYZ,white,resolve)
[rows,transposed] = orient(XYZ);
if any(~isfinite(rows),'all'), error('colormeasure:Colorimetry:BenchmarkInput','Nonfinite XYZ.'); end
if ~(isa(white,'double') || isa(white,'single')) || ~isreal(white) || ...
        ~isequal(size(white),[1 3]) || any(~isfinite(white)) || any(white<=0)
    error('colormeasure:Colorimetry:BenchmarkWhite','Invalid white.');
end
if resolve, official('xyz2lab'); end
Lab = xyz2lab(rows,'WhitePoint',double(white));
if ~isreal(Lab) || any(~isfinite(Lab),'all')
    error('colormeasure:Colorimetry:BenchmarkRange','Invalid Lab.');
end
if transposed, Lab=Lab.'; end
end

function value = officialDE(a,b)
value = imcolordiff(a,b,Standard='CIEDE2000',isInputLab=true,kL=1,kC=1,kH=1);
end

function result = wrappedDE(a,b,resolve)
[first,transposed] = orient(a); [second,~] = orient(b);
if any(~isfinite(first),'all') || any(~isfinite(second),'all')
    error('colormeasure:Colorimetry:BenchmarkInput','Nonfinite Lab.');
end
if size(second,1)~=1 && size(second,1)~=size(first,1)
    error('colormeasure:Colorimetry:BenchmarkCount','Invalid sample count.');
end
if size(second,1)==1, second=repmat(second,size(first,1),1); end
if resolve, official('imcolordiff'); end
result = officialDE(first,second);
if ~isreal(result) || any(~isfinite(result))
    error('colormeasure:Colorimetry:BenchmarkRange','Invalid difference.');
end
if transposed, result=result.'; end
end

function result = wrappedRMS(a,lambdaA,b,lambdaB,resolve)
if ~(isvector(a) && isvector(b)) || numel(a)~=numel(b) || ~isreal(a) || ~isreal(b) || ...
        ~(isa(a,'double') || isa(a,'single')) || ~(isa(b,'double') || isa(b,'single')) || ...
        any(~isfinite(a)) || any(~isfinite(b))
    error('colormeasure:Colorimetry:BenchmarkSpectrum','Invalid spectra.');
end
lambdaA = grid(lambdaA); lambdaB = grid(lambdaB);
if ~isequal(lambdaA,lambdaB) || numel(a)~=numel(lambdaA)
    error('colormeasure:Colorimetry:BenchmarkWavelength','Unequal grids.');
end
residual = double(b(:))-double(a(:));
if any(~isfinite(residual)), error('colormeasure:Colorimetry:BenchmarkRange','Invalid residual.'); end
if resolve, official('rms'); end
result = scaledRMS(residual);
end

function value = scaledRMS(residual)
scale = max(abs(residual));
if scale==0
    value=0;
else
    value=scale*min(1,rms(residual/scale));
end
end

function wavelengths = grid(wavelengths)
if ~isa(wavelengths,'double') || ~isreal(wavelengths) || ~isvector(wavelengths) || ...
        numel(wavelengths)<2 || any(~isfinite(wavelengths))
    error('colormeasure:Colorimetry:BenchmarkWavelength','Invalid wavelengths.');
end
wavelengths = wavelengths(:); steps = diff(wavelengths);
tolerance = min(4*eps(max(1,max(abs(wavelengths)))),abs(steps(1))*1e-8);
if any(wavelengths<=0) || any(steps<=0) || any(~isfinite(steps)) || ...
        any(abs(steps-steps(1))>tolerance)
    error('colormeasure:Colorimetry:BenchmarkWavelength','Invalid grid.');
end
end

function [rows,transposed] = orient(values)
if ~(isa(values,'double') || isa(values,'single')) || ~isreal(values) || ~ismatrix(values)
    error('colormeasure:Colorimetry:BenchmarkInput','Invalid color array.');
end
transposed = size(values,2)~=3;
if transposed
    if size(values,1)~=3, error('colormeasure:Colorimetry:BenchmarkShape','Invalid color shape.'); end
    values = values.';
end
rows = double(values);
end

function resolved = official(name)
resolved = which(name);
if isempty(resolved)
    error('colormeasure:Colorimetry:BenchmarkDependency', ...
        '%s is unavailable. Lab/DeltaE00 comparison requires Image Processing Toolbox.',name);
end
if ~startsWith(resolved,[matlabroot filesep])
    error('colormeasure:Colorimetry:BenchmarkShadowed','%s must resolve inside matlabroot.',name);
end
end

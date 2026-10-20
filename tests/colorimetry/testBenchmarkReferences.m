function tests = testBenchmarkReferences
% Reference selection is checked without computing timings or using instruments.
% Fernando Voltolini de Azambuja, 2026.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(colormeasuretest.projectRoot(),'tools','colorimetry')));
end


function testMissingDependenciesRefusedBeforeBaselineExecution(t)
for kind={'kernels','spectra'}
    [school,caller,entry,required,benchmark]=fixture(t,kind{1});
    writeStub(fullfile(school,'Convert',[entry '.m']),entry,'Fixture:BaselineExecuted');
    oldPath=path;
    verifyError(t,@()benchmark(school),'colormeasure:Colorimetry:BenchmarkReference');
    verifyEqual(t,pwd,caller); verifyEqual(t,path,oldPath);
    verifyFalse(t,isfile(fullfile(school,'Convert',required{end})));
end
end
function testCurrentFolderCannotReplaceSelectedBaseline(t)
for kind={'kernels','spectra'}
    [school,caller,entry,required,benchmark]=fixture(t,kind{1});
    for index=1:numel(required)
        filename=fullfile(school,'Convert',required{index});
        parent=fileparts(filename); if ~isfolder(parent), mkdir(parent); end
        [~,name,extension]=fileparts(filename);
        if strcmp(extension,'.m')
            writeStub(filename,name,'Fixture:SelectedSchoolSource');
        else
            unused=true; save(filename,'unused');
        end
    end
    writeStub(fullfile(caller,[entry '.m']),entry,'Fixture:CallerShadow');
    oldPath=path;
    verifyError(t,@()benchmark(school),'Fixture:SelectedSchoolSource');
    verifyEqual(t,pwd,caller); verifyEqual(t,path,oldPath);
end
end
function [school,caller,entry,required,benchmark]=fixture(t,kind)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
school=fullfile(f.Folder,'school'); mkdir(fullfile(school,'Convert'));
working=t.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture); caller=working.Folder;
% Refuse an unintended timing path rather than spending seconds benchmarking.
writeStub(fullfile(caller,'timeit.m'),'timeit','Fixture:TimingForbidden');
t.applyFixture(matlab.unittest.fixtures.PathFixture(caller));
if strcmp(kind,'kernels')
    entry='XYZ2Lab'; benchmark=@benchmarkColorKernels;
    required={'XYZ2Lab.m','XYZ2uvY.m','XYZ2xyY.m','xyY2uvY.m','XYZ2CCT.m', ...
        fullfile('private','XYZ2uvY1960.m'),'PlanckLocus.mat'};
else
    entry='spec2XYZ'; benchmark=@benchmarkAgainstMCSL;
    required={'spec2XYZ.m','getObserverFunction.m','ObsFunctions.mat'};
end
end
function writeStub(filename,name,identifier)
file=fopen(filename,'w'); assert(file>=0); cleanup=onCleanup(@()fclose(file));
fprintf(file,'function varargout=%s(varargin)\nerror(''%s'',''Benchmark test sentinel.'');\nend\n',name,identifier);
end

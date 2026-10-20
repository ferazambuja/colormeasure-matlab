function tests = testCRColorimetryIntegration
% V2 acquisition must not depend on any flat school conversion function.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end


function testAllModelsAcquireAndSaveWithSchoolConvertersBlocked(testCase)
guard = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
names = {'spec2XYZ','XYZ2CCT','getObserverFunction'};
for index = 1:numel(names)
    fileName = fullfile(guard.Folder,[names{index} '.m']);
    file = fopen(fileName,'w');
    assertGreaterThanOrEqual(testCase,file,0);
    cleanup = onCleanup(@()fclose(file));
    fprintf(file,['function varargout = %s(varargin)\n' ...
        'error(''CR:SchoolConverterForbidden'',''Use bundled colormeasure.colorimetry.'');\nend\n'],names{index});
    clear cleanup
end
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(guard.Folder));
clear spec2XYZ XYZ2CCT getObserverFunction
testCase.addTeardown(@clearSchoolFunctions);
for index = 1:numel(names)
    verifyEqual(testCase,which(names{index}),fullfile(guard.Folder,[names{index} '.m']));
    verifyError(testCase,str2func(names{index}),'CR:SchoolConverterForbidden');
end

for model = {'CR-100','CR-250','CR-300'}
    peer = colormeasuretest.cr.Port(model{1});
    factory = str2func(['colormeasure.drivers.cr.' strrep(model{1},'-','')]);
    meter = factory('SIM','Transport',peer,'ResponseTimeout',0.1);
    cleanup = onCleanup(@()delete(meter));
    meter.Measure();
    verifyEqual(testCase,meter.instrumentXYZ,[95.047 100 108.883]);
    verifyEqual(testCase,meter.metadata.cctSource, ...
        'MATLAB colormeasure.colorimetry.XYZ2CCT, CIE 1960 UCS, MCSL compatibility table');
    if strcmp(model{1},'CR-100')
        verifyEqual(testCase,meter.XYZ,meter.instrumentXYZ);
        verifyEqual(testCase,meter.metadata.xyzSource,'instrument RM XYZ (2 degree)');
        verifyEmpty(testCase,meter.spectralData);
    else
        verifyEqual(testCase,meter.metadata.xyzSource, ...
            'MATLAB colormeasure.colorimetry.spectra2XYZ, CIE 1931 2 degree');
        % Independent official-CIE equal-energy references, as in science tests.
        if strcmp(model{1},'CR-250')
            expected = [72.98424536081358 72.98475543572048 72.97964793779360];
        else
            expected = [72.98381396481987 72.98472987293049 72.97766485260120];
        end
        verifyEqual(testCase,meter.XYZ,expected,'AbsTol',2e-11);
        verifyNotEqual(testCase,meter.XYZ,meter.instrumentXYZ);
    end
    fileName = fullfile(guard.Folder,[strrep(model{1},'-','') '.mat']);
    meter.Save(fileName);
    stored = load(fileName,'measurements');
    for name = {'XYZ','instrumentXYZ','CCT','Duv','metadata'}
        verifyEqual(testCase,stored.measurements.(name{1}),meter.(name{1}));
    end
    clear cleanup
end
end

function clearSchoolFunctions
clear spec2XYZ XYZ2CCT getObserverFunction
end

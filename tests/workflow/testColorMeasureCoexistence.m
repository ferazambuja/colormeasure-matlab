function tests = testColorMeasureCoexistence
% Name and process-state isolation against the original school files: the
% registry key this repository owns, and the qualified names beside the
% school's unqualified ones in both path orders.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testRegisteringNewSessionUsesOnlyTheColorMeasureKey(t)
key = 'ColorMeasureSessions'; colormeasuretest.preserveAppdata(t,key);
if isappdata(groot,key), rmappdata(groot,key); end
others = setdiff(fieldnames(getappdata(groot)),{key});
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
adapter = colormeasure.drivers.cs2000.demoAdapter();
session = colormeasure.session.Session(adapter,folder.Folder);
t.addTeardown(@()delete(session));
colormeasure.session.sessionRegistry('put',adapter.key,session,folder.Folder);
registry = colormeasure.session.sessionRegistry('get');
verifyEqual(t,registry.sessions,{session});
verifyEqual(t,registry.keys,{adapter.key});
verifyEmpty(t,setdiff(setdiff(fieldnames(getappdata(groot)),{key}),others),'no other root key is written');
verifyEqual(t,session.workspaceName,'colorMeasureCS2000DemoSession');
end

function testQualifiedPackagesCoexistWithSchoolInBothPathOrders(t)
root = colormeasuretest.projectRoot();
school = getenv('COLORMEASURE_TEST_SCHOOL_ROOT');
fixture = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
if isempty(school)
    school = fixture.Folder;
    writeSource(fullfile(school,'Devices','PR655','PR655.m'),'PR655');
    writeSource(fullfile(school,'Devices','Colorimetry_Research','CR250.m'),'CR250');
    writeSource(fullfile(school,'Devices','MinoltaCS2000','CS2000.m'),'CS2000');
end
oldNames = {'PR655','CR250','CS2000'};
oldFolders = {fullfile(school,'Devices','PR655'),fullfile(school,'Devices','Colorimetry_Research'), ...
    fullfile(school,'Devices','MinoltaCS2000')};
oldFiles = {'PR655.m','CR250.m','CS2000.m'};
newNames = {'colormeasure.drivers.pr.PR655','colormeasure.drivers.cr.CR250', ...
    'colormeasure.drivers.cs2000.CS2000','colormeasure.session.Session'};
newFiles = {fullfile('+drivers','+pr','PR655.m'),fullfile('+drivers','+cr','CR250.m'), ...
    fullfile('+drivers','+cs2000','CS2000.m'),fullfile('+session','Session.m')};
originalPath = path; cleanup = onCleanup(@()path(originalPath));
for newFirst = [false true]
    path(originalPath);
    if newFirst, addpath(fullfile(root,'src'),'-begin'); end
    for index = 1:numel(oldFolders), addpath(oldFolders{index},'-begin'); end
    if ~newFirst, addpath(fullfile(root,'src'),'-begin'); end
    for index = 1:numel(oldNames)
        verifyEqual(t,which(oldNames{index}),fullfile(oldFolders{index},oldFiles{index}));
    end
    for index = 1:numel(newNames)
        verifyEqual(t,which(newNames{index}),fullfile(root,'src','+colormeasure',newFiles{index}));
    end
end
end

function writeSource(filename,name)
folder = fileparts(filename); if ~isfolder(folder), mkdir(folder); end
file = fopen(filename,'w'); assert(file >= 0); cleanup = onCleanup(@()fclose(file));
fprintf(file,'classdef %s < handle\nend\n',name);
end

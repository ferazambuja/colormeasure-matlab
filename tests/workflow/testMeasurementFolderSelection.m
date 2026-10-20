function tests = testMeasurementFolderSelection
% Folder selection explains saving and preserves cancellation before launch.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function setup(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
key = 'MeasurementFolderSelectionTest';
colormeasuretest.preserveAppdata(t,key);
setappdata(groot,key,struct('answer','Choose folder','selection',folder.Folder, ...
    'events',{{}},'question',{{}},'picker',{{}}));
colormeasuretest.writeText(fullfile(folder.Folder,'questdlg.m'),sprintf([ ...
    'function answer = questdlg(varargin)\n' ...
    'key = ''MeasurementFolderSelectionTest''; state = getappdata(groot,key);\n' ...
    'state.events{end+1} = ''explain''; state.question = varargin;\n' ...
    'setappdata(groot,key,state); answer = state.answer;\nend\n']));
colormeasuretest.writeText(fullfile(folder.Folder,'uigetdir.m'),sprintf([ ...
    'function folder = uigetdir(varargin)\n' ...
    'key = ''MeasurementFolderSelectionTest''; state = getappdata(groot,key);\n' ...
    'state.events{end+1} = ''choose''; state.picker = varargin;\n' ...
    'setappdata(groot,key,state); folder = state.selection;\nend\n']));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder.Folder));
t.TestData.folder = folder.Folder;
end

function testPurposeAppearsBeforePickerAndSelectedFolderIsPreserved(t)
selected = colormeasure.ui.chooseMeasurementFolder(t.TestData.folder);
state = getappdata(groot,'MeasurementFolderSelectionTest');
verifyEqual(t,selected,t.TestData.folder);
verifyEqual(t,state.events,{'explain','choose'});
message = strjoin(state.question{1},' ');
verifySubstring(t,message,'save this measurement batch');
verifySubstring(t,message,'own subfolder with MAT files and supported CSV exports');
verifySubstring(t,message,'does not start a measurement');
verifyEqual(t,state.question(2:end), ...
    {'Measurement save folder','Choose folder','Cancel','Choose folder'});
verifyEqual(t,state.picker, ...
    {t.TestData.folder,'Choose where to save measurement batches'});
end

function testCancelDoesNotOpenNativePicker(t)
setAnswer('Cancel');
verifyEqual(t,colormeasure.ui.chooseMeasurementFolder(t.TestData.folder),0);
verifyEqual(t,getappdata(groot,'MeasurementFolderSelectionTest').events,{'explain'});
end

function testClosingIntroductionDoesNotOpenNativePicker(t)
setAnswer('');
verifyEqual(t,colormeasure.ui.chooseMeasurementFolder(t.TestData.folder),0);
verifyEqual(t,getappdata(groot,'MeasurementFolderSelectionTest').events,{'explain'});
end

function testNativePickerCancellationKeepsDesktopServiceContract(t)
state = getappdata(groot,'MeasurementFolderSelectionTest');
state.selection = 0; setappdata(groot,'MeasurementFolderSelectionTest',state);
io = colormeasure.ui.services();
verifyEqual(t,io.chooseFolder(t.TestData.folder),'');
verifyEqual(t,getappdata(groot,'MeasurementFolderSelectionTest').events,{'explain','choose'});
end

function testMissingStartingFolderUsesCurrentFolder(t)
colormeasure.ui.chooseMeasurementFolder(fullfile(t.TestData.folder,'missing'));
state = getappdata(groot,'MeasurementFolderSelectionTest');
verifyEqual(t,state.picker{1},pwd);
end

function testEmptyStartingFolderUsesCurrentFolder(t)
colormeasure.ui.chooseMeasurementFolder('');
state = getappdata(groot,'MeasurementFolderSelectionTest');
verifyEqual(t,state.picker{1},pwd);
end

function setAnswer(answer)
state = getappdata(groot,'MeasurementFolderSelectionTest');
state.answer = answer; setappdata(groot,'MeasurementFolderSelectionTest',state);
end

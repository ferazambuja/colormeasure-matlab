function tests = testMeasurementDeviceSwitching
% Instrument switching preserves separate batches and does not measure.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
t.TestData.root = colormeasuretest.projectRoot();
end


function setup(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder = folder.Folder;
key = 'ColorMeasureSessions';
old = getappdata(groot,key);
if isappdata(groot,key), rmappdata(groot,key); end
visible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
recovered = evalin('base','who(''colorMeasureRecovered_*'')');
t.addTeardown(@() restore(old,visible,recovered));
end

function testCatalogFindsBundledFamiliesWithoutChangingThePath(t)
previous = path; t.addTeardown(@() path(previous));
before = path;
[catalog,current,mode] = colormeasure.ui.deviceCatalog(struct('model','CR250','mode','interactive'));
verifyEqual(t,path,before);
verifyEqual(t,{catalog.model},{'PR655','CR100','CR250','CR300','CS2000'});
verifyEqual(t,catalog(current).model,'CR250'); verifyEqual(t,mode,'interactive');
io = struct('launchSession',@(adapter,~) adapter);
adapter = colormeasure.ui.launchDevice('CR100',io);
verifyEqual(t,adapter.key,'CR100');
verifyEqual(t,which('colormeasure.drivers.cr.uiAdapter'),fullfile(t.TestData.root,'src','+colormeasure','+drivers','+cr','uiAdapter.m'));
end

function testCustomAdapterDoesNotAcquireAMisleadingSelector(t)
[~,current,mode] = colormeasure.ui.deviceCatalog(struct('model','','mode','','key','CustomPR655Demo'));
verifyEmpty(t,current); verifyEmpty(t,mode);
s = open(t,'CustomPR655Demo');
verifyEqual(t,char(get(colormeasuretest.field(s.window,'InstrumentSelector'),'Visible')),'off');
verifyEqual(t,char(get(colormeasuretest.field(s.window,'BatchIdentity'),'Visible')),'on');
verifyError(t,@() colormeasure.ui.switchDevice(s,'PR655'),'Measurement:DeviceSession');
end

function testGenericLauncherRestoresRetainedCustomConnectionSettings(t)
for model={'CR250','CS2000'}
    config=struct('BaudRate',9600,'ResponseTimeout',17);
    target=open(t,model{1},config);target.measure('Retained sample','');target.hide();
    before=target.measurements;files=target.files;
    io=struct('chooseFolder',@(~) error('Test:UnexpectedFolder','Restore must not choose a folder.'));
    [restored,name]=colormeasure.ui.launchDevice(model{1},io);
    verifyEqual(t,restored,target);verifyEqual(t,name,target.workspaceName);
    verifyEqual(t,target.configuration,config);
    verifyEqual(t,target.measurements,before);verifyEqual(t,target.files,files);
    verifyEqual(t,char(target.window.Visible),'on');
end
end

function testRetainedBatchSelectionUsesDeclaredModeAndNotKeySpelling(t)
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
a=adapter('PR655DemoBatch');a.key='ArbitrarySource';
source=colormeasure.ui.launchSession(a,io);source.show();
a=adapter('CR250DemoBatch');a.key='CR250DemoGallery';
target=colormeasure.ui.launchSession(a,io);target.show();target.measure('Keep this batch','');target.hide();
ordinary=open(t,'CR250');ordinary.hide();
before=target.measurements;keys=colormeasure.session.sessionRegistry('get').keys;
restored=colormeasure.ui.switchDevice(source,'CR250',struct('launchSession',@unexpectedLaunch));
verifyEqual(t,restored,target);verifyNotEqual(t,restored,ordinary);
verifyEqual(t,target.measurements,before);
verifyEqual(t,target.catalogIdentity,struct('model','CR250','mode','batch','key','CR250DemoGallery'));
verifyEqual(t,colormeasure.session.sessionRegistry('get').keys,keys);
end

function testARecognizableRegistryKeyDoesNotDeclareCatalogIdentity(t)
a=rmfield(adapter('PR655Demo'),'catalog');
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
s=colormeasure.ui.launchSession(a,io);s.show();
verifyEqual(t,char(get(colormeasuretest.field(s.window,'InstrumentSelector'),'Visible')),'off');
verifyError(t,@()colormeasure.ui.switchDevice(s,'CR250'),'Measurement:DeviceSession');
verifyEmpty(t,s.measurements);
end

function testAmbiguousCatalogIdentityDoesNotRestoreAnArbitraryBatch(t)
source=open(t,'PR655');io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
a=adapter('CR250');a.key='FirstRoom';a.configuration=struct('ResponseTimeout',17);
first=colormeasure.ui.launchSession(a,io);first.show();first.measure('First room','');first.finish();first.hide();
a.key='SecondRoom';a.configuration=struct('ResponseTimeout',25);
second=colormeasure.ui.launchSession(a,io);second.show();second.measure('Second room','');second.hide();
before={first.measurements,second.measurements};keys=colormeasure.session.sessionRegistry('get').keys;
verifyError(t,@()colormeasure.ui.switchDevice(source,'CR250',struct('launchSession',@unexpectedLaunch)), ...
    'Measurement:DeviceSessionAmbiguous');
verifyEqual(t,{first.measurements,second.measurements},before);
verifyEqual(t,colormeasure.session.sessionRegistry('get').keys,keys);
verifyEqual(t,char(source.window.Visible),'on');
verifyEqual(t,char(first.window.Visible),'off');verifyEqual(t,char(second.window.Visible),'off');
verifyFalse(t,source.finished);verifyFalse(t,second.finished);
end

function testRestoresExactTargetConfigurationWithoutCreatingAnotherBatch(t)
source = open(t,'PR655'); source.measure('Source','');
target = open(t,'CR250',struct('model','CR250','ResponseTimeout',17,'MeasurementTimeout',321));
target.measure('Target',''); target.hide();
before = target.measurements; files = target.files; config = target.configuration;
io = struct('launchSession',@unexpectedLaunch,'chooseFolder',@unexpectedFolder);
restored = colormeasure.ui.switchDevice(source,'CR250',io);
verifyEqual(t,restored,target); verifyEqual(t,target.configuration,config);
verifyEqual(t,target.measurements,before); verifyEqual(t,target.files,files);
verifyFalse(t,source.finished); verifyFalse(t,target.finished);
again = colormeasure.ui.switchDevice(source,'CR250',io);
verifyEqual(t,again,target);
registry = colormeasure.session.sessionRegistry('get'); verifyNumElements(t,registry.keys,2);
verifyEqual(t,evalin('base',target.workspaceName),target);
end

function testNewTargetUsesExistingParentPolicyAndDoesNotMeasure(t)
source = open(t,'PR655'); source.measure();
verifyNotEqual(t,source.destination,t.TestData.folder);
seen = ''; calls = 0;
io = colormeasure.ui.services(); io.chooseFolder = @choose; io.launchSession = @safeLaunch;
target = colormeasure.ui.switchDevice(source,'CR100',io);
verifyEqual(t,seen,t.TestData.folder); verifyEqual(t,calls,1);
verifyEmpty(t,target.measurements); verifyEmpty(t,target.files.mat);
verifyEqual(t,target.adapterKey,'CR100'); verifyEqual(t,char(get(target.window,'Visible')),'on');
verifyEqual(t,char(get(source.window,'Visible')),'on'); % Only the window callback hides its source.
    function folder = choose(previous)
        calls = calls+1; seen = previous; folder = t.TestData.folder;
    end
    function next = safeLaunch(adapter,services)
        adapter.listPorts = @(~) "VIRTUAL";
        adapter.connect = @(~) error('Test:UnexpectedConnect','Selection cannot connect.');
        next = colormeasure.ui.launchSession(adapter,services);
    end
end

function testCancellationLeavesSourceAndRegistryUnchanged(t)
source = open(t,'PR655'); source.measure();
before = source.measurements; keys = colormeasure.session.sessionRegistry('get').keys;
io = colormeasure.ui.services(); io.chooseFolder = @(~) '';
target = colormeasure.ui.switchDevice(source,'CR100',io);
verifyEmpty(t,target); verifyEqual(t,source.measurements,before);
verifyEqual(t,colormeasure.session.sessionRegistry('get').keys,keys);
verifyEqual(t,char(get(source.window,'Visible')),'on');
end

function testDirectSessionIsRetainedWithoutReplacingAnotherOwner(t)
io = colormeasure.ui.services();
% Switching publishes the direct session under its workspace name, which the
% registry-based restore cannot clear once the session is disposed.
colormeasuretest.preserveWorkspace(t,'pr655SwitchTest');
source = colormeasure.session.Session(adapter('PR655'),t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.dispose(source)); source.show(); source.show(); source.measure('Direct','');
target = open(t,'CR250'); target.hide();
registry = colormeasure.session.sessionRegistry('get'); previousFolder = registry.lastFolder;
verifyEqual(t,colormeasure.ui.switchDevice(source,'CR250'),target);
verifyEqual(t,colormeasure.ui.switchDevice(target,'PR655'),source);
registry = colormeasure.session.sessionRegistry('get');
verifyEqual(t,registry.lastFolder,previousFolder); verifyNumElements(t,registry.keys,2);
verifyEqual(t,source.measurements.name,'Direct');
other = colormeasure.session.Session(adapter('PR655'),t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.dispose(other)); other.show(); other.show();
verifyError(t,@() colormeasure.ui.switchDevice(other,'CR250'),'Measurement:DeviceSessionOwnership');
verifyEqual(t,char(get(other.window,'Visible')),'on');
verifyEqual(t,colormeasure.ui.switchDevice(target,'PR655'),source);
end

function testCancelledSwitchDoesNotRegisterDirectSource(t)
io = colormeasure.ui.services(); io.chooseFolder = @(~) '';
source = colormeasure.session.Session(adapter('PR655'),t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.dispose(source)); source.show(); source.show();
verifyEmpty(t,colormeasure.ui.switchDevice(source,'CR250',io));
registry = colormeasure.session.sessionRegistry('get'); verifyEmpty(t,registry.keys);
verifyEqual(t,char(get(source.window,'Visible')),'on');
end

function testStagedSelectionGuardsSourceActionsAndPreservesDrafts(t)
source = open(t,'PR655'); target = open(t,'CR250'); target.hide();
fig = source.window;
set(colormeasuretest.field(fig,'SampleName'),'String','Pending sample');
set(colormeasuretest.field(fig,'SampleNotes'),'Value',{'Keep the pending notes'});
stage(fig,'CR250');
for tag = {'MeasureButton','InstrumentSettingsButton','FinishButton','NewBatchButton', ...
        'RefreshPortsButton','SampleName','SampleNotes','SerialPort'}
    verifyEqual(t,char(get(colormeasuretest.field(fig,tag{1}),'Enable')),'off');
end
colormeasuretest.click(colormeasuretest.field(fig,'MeasureButton')); colormeasuretest.click(colormeasuretest.field(fig,'FinishButton'));
verifyEmpty(t,source.measurements); verifyFalse(t,source.finished);
verifyTrue(t,contains(get(colormeasuretest.field(fig,'CurrentStatus'),'String'),'Open'));
colormeasuretest.click(colormeasuretest.field(fig,'OpenInstrumentButton'));
verifyEqual(t,char(get(fig,'Visible')),'off'); verifyEqual(t,char(get(target.window,'Visible')),'on');
verifyEqual(t,get(fig,'Position'),get(target.window,'Position'));
stage(target.window,'PR655'); colormeasuretest.click(colormeasuretest.field(target.window,'OpenInstrumentButton'));
verifyEqual(t,char(get(source.window,'Visible')),'on');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleName'),'String'),'Pending sample');
verifyEqual(t,get(colormeasuretest.field(fig,'SampleNotes'),'Value'),{'Keep the pending notes'});
verifyEmpty(t,source.measurements); verifyEmpty(t,target.measurements);
verifyEqual(t,get(colormeasuretest.field(fig,'InstrumentSelector'),'Value'),1);
end

function testSettingsDraftRemainsAvailableAfterSwitching(t)
io = colormeasure.ui.services(); io.chooseFolder = @(~) t.TestData.folder;
source = colormeasure.ui.launchSession(colormeasure.drivers.cr.demoAdapter('CR250'),io); source.show();
target = open(t,'PR655Demo'); target.hide();
colormeasuretest.click(colormeasuretest.field(source.window,'InstrumentSettingsButton'));
settings = findall(groot,'Tag','InstrumentSettingsWindow'); assertNumElements(t,settings,1);
button = colormeasuretest.field(settings,'ReadInstrumentSettings'); button.ButtonPushedFcn(button,[]);
toggle = colormeasuretest.field(settings,'SettingsOverride'); toggle.Value = true;
toggle.ValueChangedFcn(toggle,[]);
data = colormeasuretest.field(settings,'InstrumentSettingsTable').Data;
verifyEmpty(t,fieldnames(source.settingsOverrides));
stage(source.window,'PR655'); colormeasuretest.click(colormeasuretest.field(source.window,'OpenInstrumentButton'));
verifyTrue(t,isgraphics(settings)); verifyEqual(t,char(settings.Visible),'off');
stage(target.window,'CR250'); colormeasuretest.click(colormeasuretest.field(target.window,'OpenInstrumentButton'));
colormeasuretest.click(colormeasuretest.field(source.window,'InstrumentSettingsButton'));
verifyEqual(t,findall(groot,'Tag','InstrumentSettingsWindow'),settings);
verifyTrue(t,toggle.Value); verifyEqual(t,colormeasuretest.field(settings,'InstrumentSettingsTable').Data,data);
verifyEmpty(t,fieldnames(source.settingsOverrides));
end

function testInstrumentHeaderFitsTheMinimumWindow(t)
source = open(t,'PR655'); fig = source.window;
position = get(fig,'Position'); position(3:4) = [960 650]; set(fig,'Position',position);
callback = get(fig,'SizeChangedFcn'); callback(fig,[]);
tags = {'InstrumentLabel','InstrumentSelector','OpenInstrumentButton','CurrentStatus','BatchDestination'};
for first = 1:numel(tags)
    a = getpixelposition(colormeasuretest.field(fig,tags{first}),true);
    verifyGreaterThanOrEqual(t,a(1:2),[0 0]);
    verifyLessThanOrEqual(t,a(1:2)+a(3:4),position(3:4));
    for second = first+1:numel(tags)
        b = getpixelposition(colormeasuretest.field(fig,tags{second}),true);
        overlap = min(a(1:2)+a(3:4),b(1:2)+b(3:4))-max(a(1:2),b(1:2));
        verifyFalse(t,all(overlap>0),['Overlap: ' tags{first} ' / ' tags{second}]);
    end
end
verifyEqual(t,char(get(colormeasuretest.field(fig,'BatchIdentity'),'Visible')),'off');
verifyTrue(t,contains(colormeasuretest.field(fig,'BatchDestination').Tooltip,source.startedAtUTC));
end

function testCancelledOrFailedOpenResetsSelectionAndKeepsSourceVisible(t)
for fail = [false true]
    io = colormeasure.ui.services(); io.chooseFolder = @(~) t.TestData.folder;
    io.createView = @(s) colormeasure.ui.Window(s,@(~,~) true,@cancelOrFail);
    source = colormeasure.ui.launchSession(adapter('PR655'),io); source.show();
    fig = source.window; stage(fig,'CR250'); colormeasuretest.click(colormeasuretest.field(fig,'OpenInstrumentButton'));
    verifyEqual(t,char(get(fig,'Visible')),'on'); verifyEqual(t,get(colormeasuretest.field(fig,'InstrumentSelector'),'Value'),1);
    verifyEqual(t,char(get(colormeasuretest.field(fig,'MeasureButton'),'Enable')),'on');
    verifyEmpty(t,source.measurements); verifyFalse(t,source.finished);
    delete(source); colormeasure.session.sessionRegistry('get');
end
    function value = cancelOrFail(~,~)
        if fail, error('Test:Open','Selected window failed.'); end
        value = [];
    end
end

function testBusyAndUnfinishedFinalizationPreventSwitching(t)
io = colormeasure.ui.services(); io.chooseFolder = @(~) t.TestData.folder;
a = adapter('PR655'); a.read = @duringRead;
source = colormeasure.ui.launchSession(a,io); source.show(); source.measure();
verifyNumElements(t,source.measurements,1);
source.finish();
verifyTrue(t,source.finished); verifyTrue(t,source.finishing);
verifyEqual(t,char(get(colormeasuretest.field(source.window,'InstrumentSelector'),'Enable')),'on');
stage(source.window,'CR250');
verifyEqual(t,char(get(colormeasuretest.field(source.window,'NewBatchButton'),'Enable')),'off');
colormeasuretest.click(colormeasuretest.field(source.window,'NewBatchButton'));
stage(source.window,'PR655');
verifyEqual(t,char(get(colormeasuretest.field(source.window,'NewBatchButton'),'Enable')),'on');
target = open(t,'CR250');
verifyEqual(t,colormeasure.ui.switchDevice(source,'CR250'),target);
io.saveMat = @(varargin) error('Test:Save','Save is unavailable.');
pending = colormeasure.session.Session(adapter('CR300'),t.TestData.folder,io);
t.addTeardown(@() colormeasuretest.disposeSession(pending)); pending.show(); pending.measure(); pending.finish();
verifyTrue(t,pending.finishing); verifyFalse(t,pending.finished);
verifyEqual(t,char(get(colormeasuretest.field(pending.window,'InstrumentSelector'),'Enable')),'off');
verifyEmpty(t,colormeasure.ui.switchDevice(pending,'CR250'));
    function reading = duringRead(~)
        verifyTrue(t,source.busy);
        verifyEqual(t,char(get(colormeasuretest.field(source.window,'InstrumentSelector'),'Enable')),'off');
        verifyEmpty(t,colormeasure.ui.switchDevice(source,'CR250'));
        stage(source.window,'CR250'); colormeasuretest.click(colormeasuretest.field(source.window,'OpenInstrumentButton'));
        verifyEqual(t,get(colormeasuretest.field(source.window,'InstrumentSelector'),'Value'),1);
        reading = struct('XYZ',[1 2 3]);
    end
end

function testDemoRestorationNeverUsesPhysicalSession(t)
source = open(t,'PR655Demo'); real = open(t,'CR250'); demo = open(t,'CR250Demo');
real.measure('Physical fixture','');
target = colormeasure.ui.switchDevice(source,'CR250',struct('launchSession',@unexpectedLaunch));
verifyEqual(t,target,demo); verifyNotEqual(t,target,real);
verifyEmpty(t,demo.measurements); verifyNumElements(t,real.measurements,1);
end

function testChartSwitchSavesPausedSourceAndKeepsSeparateTarget(t)
io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;
source=colormeasure.ui.launchSession(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),io);source.show();
source.startChart(colormeasure.chart.definition('custom','Source grid',1,2));source.measure();
target=open(t,'PR655Demo');target.hide();before=source.measurements;
stage(source.window,'PR655');colormeasuretest.click(colormeasuretest.field(source.window,'OpenInstrumentButton'));
verifyTrue(t,source.chart.paused);verifyFalse(t,source.chart.unsaved);verifyFalse(t,source.finished);
verifyEqual(t,source.measurements,before);verifyEmpty(t,target.chart);verifyEmpty(t,target.measurements);
verifyTrue(t,load(source.files.mat).batchInfo.chart.paused);
verifyEqual(t,char(source.window.Visible),'off');verifyEqual(t,char(target.window.Visible),'on');
stage(target.window,'CR250');colormeasuretest.click(colormeasuretest.field(target.window,'OpenInstrumentButton'));
verifyTrue(t,source.chart.paused);verifyEqual(t,char(source.window.Visible),'on');verifyEqual(t,source.measurements,before);
end

function testChartPauseSaveFailurePreventsSwitchAndKeepsRecoveryVisible(t)
fail=false;io=colormeasure.ui.services();io.chooseFolder=@(~)t.TestData.folder;io.saveMat=@save;
source=colormeasure.ui.launchSession(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),io);source.show();
source.startChart(colormeasure.chart.definition('custom','Source grid',1,2));
target=open(t,'PR655Demo');
for visibility={'off','on'}
    fail=false;source.resumeChart();target.window.Visible=visibility{1};fail=true;
    stage(source.window,'PR655');colormeasuretest.click(colormeasuretest.field(source.window,'OpenInstrumentButton'));
    verifyEqual(t,char(source.window.Visible),'on');verifyEqual(t,char(target.window.Visible),visibility{1});
    verifyTrue(t,source.chart.unsaved);verifyTrue(t,source.chart.paused);verifyEmpty(t,source.measurements);
    retry=colormeasuretest.field(source.window,'RetrySaveButton');verifyEqual(t,retry.Enable,'on');
    verifyEqual(t,colormeasuretest.field(source.window,'InstrumentSelector').Value,3);
    fail=false;colormeasuretest.click(retry);verifyFalse(t,source.chart.unsaved);verifyEmpty(t,source.measurements);
end
    function save(varargin)
        if fail,error('ChartTest:Save','Synthetic pause save failure');end
        colormeasure.session.saveMat(varargin{:});
    end
end

function testGalleryButtonOpensSyntheticGalleryAndRestoresIt(t)
source = open(t,'PR655DemoGallery');
verifyEqual(t,get(colormeasuretest.field(source.window,'OpenInstrumentButton'),'String'),'Open gallery');
target = colormeasure.ui.switchDevice(source,'CR250');
verifyEqual(t,target.adapterKey,'CR250DemoGallery');
verifyNumElements(t,target.measurements,numel(colormeasure.simulation.syntheticProfiles()));
verifyTrue(t,all([target.measurements.isSynthetic]));
count = numel(target.measurements);
verifyEqual(t,colormeasure.ui.switchDevice(source,'CR250'),target);
verifyNumElements(t,target.measurements,count);
batchFolder = target.files.folder;
verifyTrue(t,isfolder(batchFolder));
disposeCreatedSessions();
verifyFalse(t,isfolder(batchFolder),'The real gallery must not leave its saved test batch in tempdir.');
end

function testNewInteractiveDemoWaitsForMeasure(t)
% Substitute the folder dialogs; the real demo factory and serial guards
% remain active. No physical adapter may be opened or enumerated.
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
file = fopen(fullfile(folder.Folder,'uigetdir.m'),'w');
assert(file>=0);
fprintf(file,['function folder = uigetdir(varargin)\n' ...
    'folder = getappdata(groot,''MeasurementSelectorTestFolder'');\nend\n']);
fclose(file);
colormeasuretest.writeText(fullfile(folder.Folder,'questdlg.m'),sprintf([ ...
    'function answer = questdlg(varargin)\n' ...
    'answer = ''Choose folder'';\nend\n']));
setappdata(groot,'MeasurementSelectorTestFolder',t.TestData.folder);
t.addTeardown(@() rmappdata(groot,'MeasurementSelectorTestFolder'));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder.Folder));
source = open(t,'PR655Demo');
target = colormeasure.ui.switchDevice(source,'CR100');
verifyEqual(t,target.adapterKey,'CR100Demo');
verifyEmpty(t,target.measurements); verifyEmpty(t,target.files.mat);
verifyEqual(t,target.port,'CR_SYNTHETIC_ONLY');
verifyEqual(t,target.destination,t.TestData.folder);
verifyFalse(t,source.finished);
end

function s = open(t,key,configuration)
a = adapter(key);
if nargin > 2, a.configuration = configuration; end
io = colormeasure.ui.services(); io.chooseFolder = @(~) t.TestData.folder;
s = colormeasure.ui.launchSession(a,io); s.show();
end

function a = adapter(key)
a = struct('key',key,'label',[key ' fixture'],'workspaceName',[lower(key) 'SwitchTest'], ...
    'listPorts',@(~) "VIRTUAL",'connect',@(~) [],'release',@(~) [], ...
    'read',@(~) struct('XYZ',[1 2 3]), ...
    'toTable',@(m,~) table((1:numel(m))','VariableNames',{'Index'}));
% These fixture identities are declared independently of key parsing.
identities={'PR655','PR655','measure';'CR100','CR100','measure'; ...
    'CR250','CR250','measure';'CR300','CR300','measure';'CS2000','CS2000','measure'; ...
    'PR655Demo','PR655','interactive';'CR250Demo','CR250','interactive'; ...
    'PR655DemoGallery','PR655','gallery';'CR250DemoGallery','CR250','gallery'; ...
    'PR655DemoBatch','PR655','batch';'CR250DemoBatch','CR250','batch'};
index=find(strcmp(identities(:,1),key),1);
if ~isempty(index),a.catalog=struct('model',identities{index,2},'mode',identities{index,3});end
end

function stage(fig,model)
catalog = colormeasure.ui.deviceCatalog();
set(colormeasuretest.field(fig,'InstrumentSelector'),'Value',find(strcmp({catalog.model},model),1));
colormeasuretest.click(colormeasuretest.field(fig,'InstrumentSelector'));
end

function varargout = unexpectedLaunch(varargin) %#ok<STOUT>
error('Test:UnexpectedLaunch','A retained batch must be restored directly.');
end

function value = unexpectedFolder(varargin) %#ok<STOUT>
error('Test:UnexpectedFolder','A retained batch must keep its destination.');
end

function restore(previous,visible,recovered)
disposeCreatedSessions();
if isempty(previous)
    if isappdata(groot,'ColorMeasureSessions'), rmappdata(groot,'ColorMeasureSessions'); end
else
    setappdata(groot,'ColorMeasureSessions',previous);
end
set(groot,'DefaultFigureVisible',visible);
created = setdiff(evalin('base','who(''colorMeasureRecovered_*'')'),recovered);
for index = 1:numel(created), evalin('base',['clear ' created{index}]); end
end

function disposeCreatedSessions()
% setup isolates the registry, so these batches belong only to this test.
% Dispose before restoring the previous registry, including on test failure.
registry = colormeasure.session.sessionRegistry('get');
for index = 1:numel(registry.sessions)
    s = registry.sessions{index}; name = s.workspaceName;
    colormeasuretest.disposeBatch(s);
    if isvarname(name), evalin('base',['clear ' name]); end
end
end

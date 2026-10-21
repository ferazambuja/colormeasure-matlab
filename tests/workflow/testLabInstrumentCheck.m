function tests=testLabInstrumentCheck
% Guided check uses production synthetic meters; never serial hardware.
% Fernando Voltolini de Azambuja, 2026.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.folder=f.Folder;
previous=getappdata(groot,'ColorMeasureSessions');
t.addTeardown(@()setappdata(groot,'ColorMeasureSessions',previous));
setappdata(groot,'ColorMeasureSessions',[]);
end
function testAllBundledFamiliesSaveReloadAndArchive(t)
models={'PR655','CR100','CR250','CR300','CS2000'};
for k=1:numel(models)
    [a,io,interaction]=fixture(models{k});
    [r,s]=run(t,models{k},a,io,interaction);
    verifyEqual(t,r.status,'passed',models{k});
    verifyTrue(t,s.finished); verifyNumElements(t,s.measurements,3);
    verifyTrue(t,all(strcmp({r.steps.status},'passed')));
    verifyNotEqual(t,r.mode,'physical');
    extracted=fullfile(r.folder,'unpacked');
    paths=unzip(r.archive,extracted);
    verifyTrue(t,any(endsWith(paths,'report.json')));
    verifyTrue(t,any(endsWith(paths,'measurements.csv')));
    snapshots=paths(endsWith(paths,'diagnostic.mat'));
    data=load(snapshots{1});
    verifyEqual(t,data.measurements,s.measurements);
    verifyEqual(t,data.report.status,'passed');
    json=jsondecode(fileread(fullfile(r.folder,'report.json')));
    verifyEqual(t,json.status,'passed');
end
end
function testDefaultReportsUseDesktopWithHomeFallback(t)
original=char(java.lang.System.getProperty('user.home'));
cleanup=onCleanup(@()java.lang.System.setProperty('user.home',original));
for desktop=[true false]
    userFolder=fullfile(t.TestData.folder,sprintf('user-%d',desktop)); mkdir(userFolder);
    if desktop, mkdir(fullfile(userFolder,'Desktop')); end
    java.lang.System.setProperty('user.home',userFolder);
    [a,io,interaction]=fixture('CR250');
    [r,s]=colormeasure.checkInstrument('CR250',Adapter=a,Services=io,Interaction=interaction);
    t.addTeardown(@()colormeasuretest.disposeSession(s));
    expected=userFolder;
    if desktop, expected=fullfile(expected,'Desktop'); end
    expected=fullfile(expected,'ColorMeasurement-Reports');
    verifyEqual(t,fileparts(r.folder),expected);
    verifyEqual(t,fileparts(r.archive),expected);
    verifyTrue(t,isfile(r.archive)); verifyEqual(t,r.status,'passed');
    colormeasuretest.disposeSession(s);
end
end

function testCancellationKeepsPriorReadingAndSkipsRemainingChecks(t)
[a,io,interaction]=fixture('CR250'); calls=0;
interaction.confirm=@confirm;
[r,s]=run(t,'CR250',a,io,interaction);
verifyEqual(t,r.status,'cancelled');verifyNumElements(t,s.measurements,1);
verifyFalse(t,s.finished);verifyEqual(t,calls,3);
verifyEqual(t,{r.steps(5:end).status},{'skipped','skipped','skipped'});
data=load(fullfile(r.folder,'diagnostic.mat'));
verifyEqual(t,data.measurements,s.measurements);verifyTrue(t,isfile(r.archive));
    function yes=confirm(~)
        calls=calls+1;yes=calls<3;
    end
end
function testSettingsAndReadFailuresAreRetainedWithoutRetry(t)
for stage={'settings','reading'}
    [a,io,interaction]=fixture('CR100');calls=0;
    if strcmp(stage{1},'settings'), a.settings.read=@fail;else,a.read=@fail;end
    [r,s]=run(t,'CR100',a,io,interaction);
    verifyEqual(t,r.status,'failed'); verifyEqual(t,calls,1);
    verifyEmpty(t,s.measurements);verifyFalse(t,s.finished);
    verifySubstring(t,fileread(fullfile(r.folder,'report.txt')),'LabCheck:Injected');
    verifyTrue(t,isfile(r.archive));
    colormeasuretest.disposeSession(s);
end
    function value=fail(~) %#ok<STOUT>
        calls=calls+1;error('LabCheck:Injected','Retain this original failure.');
    end
end
function testSaveFailureRetainsReadingAndStops(t)
[a,io,interaction]=fixture('CR250');io.saveMat=@failSave;
[r,s]=run(t,'CR250',a,io,interaction);
verifyEqual(t,r.status,'failed');verifyNumElements(t,s.measurements,1);
verifyEqual(t,s.savedCount,0);verifyNotEmpty(t,s.saveError);verifyFalse(t,s.finished);
data=load(fullfile(r.folder,'diagnostic.mat'));
verifyEqual(t,data.measurements,s.measurements);verifyTrue(t,isfile(r.archive));
end
function testFailedArchiveKeepsFilesWithoutClaimingTheZip(t)
[a,io,interaction]=fixture('CR250'); %#ok<ASGLU> a and io are used by evalc below.
interaction.notes=@blockArchive;r=[];s=[];
output=evalc('[r,s]=run(t,''CR250'',a,io,interaction);');
verifyTrue(t,s.finished);verifyEqual(t,r.status,'report-error');verifyFalse(t,isfile(r.archive));
verifyTrue(t,isfolder(r.archive));
verifyEqual(t,count(output,'Could not complete report ZIP:'),1);
verifyFalse(t,contains(output,'Report ZIP:'));
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.zip')));
json=jsondecode(fileread(fullfile(r.folder,'report.json')));verifyEqual(t,json.status,'report-error');
    function text=blockArchive()
        % A folder at the ZIP path makes the archive step fail.
        found=dir(fullfile(t.TestData.folder,'instrument-check-*'));
        mkdir(fullfile(t.TestData.folder,[found(1).name '.zip']));text='';
    end
end
function testFailedArchiveKeepsRecoveryAndPrivacyGuidance(t)
[a,io,interaction]=fixture('CR250'); %#ok<ASGLU> a and io are used by evalc below.
interaction.confirm=@(~)false;interaction.notes=@blockArchive;r=[];s=[];
output=evalc('[r,s]=run(t,''CR250'',a,io,interaction);');
verifyEqual(t,r.status,'report-error');verifyFalse(t,s.finished);
verifyFalse(t,contains(output,'Report ZIP:'));
verifyEqual(t,count(output,'Open the retained batch for recovery'),1);
verifyEqual(t,count(output,'Issue attachments are public'),1);
    function text=blockArchive()
        found=dir(fullfile(t.TestData.folder,'instrument-check-*'));
        mkdir(fullfile(t.TestData.folder,[found(1).name '.zip']));text='';
    end
end
function testExistingReportArchiveIsNeverReplaced(t)
[a,io,interaction]=fixture('CR250'); %#ok<ASGLU> a and io are used by evalc below.
interaction.notes=@occupyArchive;r=[];s=[];
marker='Existing report ZIP; do not replace.';
output=evalc('[r,s]=run(t,''CR250'',a,io,interaction);');
verifyTrue(t,s.finished);verifyEqual(t,r.status,'report-error');
verifyEqual(t,fileread(r.archive),marker);
verifyEqual(t,count(output,'Could not complete report ZIP:'),1);
verifyFalse(t,contains(output,'Report ZIP:'));
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.zip')));
data=load(fullfile(r.folder,'diagnostic.mat'));
verifyEqual(t,data.measurements,s.measurements);verifyEqual(t,data.report.status,'report-error');
    function text=occupyArchive()
        found=dir(fullfile(t.TestData.folder,'instrument-check-*'));
        path=fullfile(t.TestData.folder,[found(1).name '.zip']);
        fid=fopen(path,'w');assert(fid>=0);fwrite(fid,marker,'char');fclose(fid);text='';
    end
end
function testRelativeReportDestinationUsesMatlabCurrentFolder(t)
anchor=java.io.File('.');anchor.getCanonicalPath();
previous=pwd;cleanup=onCleanup(@()cd(previous));
cd(t.TestData.folder);mkdir('reports');
[a,io,interaction]=fixture('CR250');
[r,s]=colormeasure.checkInstrument('CR250',Destination='reports', ...
    Adapter=a,Services=io,Interaction=interaction);
t.addTeardown(@()colormeasuretest.disposeSession(s));
verifyEqual(t,fileparts(r.folder),fullfile(t.TestData.folder,'reports'));
verifyEqual(t,fileparts(r.archive),fullfile(t.TestData.folder,'reports'));
verifyTrue(t,isfile(r.archive));verifyEqual(t,r.status,'passed');
end
function testDanglingReportArchiveLinkIsNeverReplaced(t)
assumeFalse(t,ispc,'This symbolic-link fixture uses the POSIX ln command.');
[a,io,interaction]=fixture('CR250'); %#ok<ASGLU> a and io are used by evalc below.
target=fullfile(t.TestData.folder,'unrelated.zip');
interaction.notes=@occupyArchive;r=[];s=[];
output=evalc('[r,s]=run(t,''CR250'',a,io,interaction);');
verifyEqual(t,r.status,'report-error');verifyTrue(t,s.finished);
verifyTrue(t,java.nio.file.Files.isSymbolicLink(java.io.File(r.archive).toPath()));
verifyFalse(t,isfile(target));
verifyFalse(t,contains(output,'Report ZIP:'));
verifyEmpty(t,dir(fullfile(t.TestData.folder,'*.part.zip')));
    function text=occupyArchive()
        found=dir(fullfile(t.TestData.folder,'instrument-check-*'));
        path=fullfile(t.TestData.folder,[found(1).name '.zip']);
        [status,message]=system(sprintf('ln -s ''%s'' ''%s''',target,path));
        assert(status==0,'LabCheck:LinkFixture','Cannot create symbolic-link fixture: %s',message);
        text='';
    end
end
function testUnconfirmedReleaseStopsAfterSettings(t)
[a,io,interaction]=fixture('CR250');a.release=@failRelease;
[r,s]=run(t,'CR250',a,io,interaction);
verifyEqual(t,r.status,'failed');verifyEmpty(t,s.measurements);
verifyTrue(t,s.chartIoUnconfirmed);verifyFalse(t,s.finished);
verifyTrue(t,all(strcmp({r.steps(3:end).status},'skipped')));
end
function testExistingBatchIsNeverReplaced(t)
[a,io,interaction]=fixture('CR250');
previous=colormeasure.session.Session(a,t.TestData.folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(previous));
colormeasure.session.sessionRegistry('put',a.key,previous,t.TestData.folder);
[r,s]=run(t,'CR250',a,io,interaction);
verifyEqual(t,r.status,'failed');verifyEmpty(t,s);
verifyEqual(t,r.steps(1).identifier,'Measurement:CheckExistingSession');
registry=colormeasure.session.sessionRegistry('get');verifyEqual(t,registry.sessions{1},previous);
verifyEmpty(t,previous.measurements);
end
function testWindowSkippedAndFailedRemainHonest(t)
for result={'skipped','failed'}
    [a,io,interaction]=fixture('CR250');interaction.inspect=@(~)result{1};
    [r,s]=run(t,'CR250',a,io,interaction);
    if strcmp(result{1},'skipped'),expected='incomplete';else,expected='failed';end
    verifyEqual(t,r.status,expected);verifyEqual(t,r.steps(7).status,result{1});
    verifyTrue(t,s.finished);colormeasuretest.disposeSession(s);
end
end
function [r,s]=run(t,model,a,io,interaction)
[r,s]=colormeasure.checkInstrument(model,Destination=t.TestData.folder, ...
    Adapter=a,Services=io,Interaction=interaction);
if ~isempty(s),t.addTeardown(@()colormeasuretest.disposeSession(s));end
end
function [a,io,interaction]=fixture(model)
if strcmp(model,'PR655')
    a=colormeasure.drivers.pr.uiAdapter();
    meter=colormeasure.drivers.pr.DemoInstrument(1,0);
    a.catalog.mode='interactive'; a.key='PR655CheckSynthetic';
    a.connect=@(~)meter;a.release=@(~)[];a.listPorts=@(~)"PR_SYNTHETIC_ONLY";
elseif strcmp(model,'CS2000')
    a=colormeasure.drivers.cs2000.demoAdapter();
else
    a=colormeasure.drivers.cr.demoAdapter(model);
end
io=colormeasure.session.services();
interaction=struct('confirm',@(~)true,'choosePort',@(ports)char(ports(1)), ...
    'inspect',@(~)'passed','notes',@()'Synthetic software check; no physical equipment.');
end
function failSave(varargin)
error('LabCheck:Save','Injected batch save failure.');
end
function failRelease(~)
error('LabCheck:Release','Injected unconfirmed cleanup.');
end

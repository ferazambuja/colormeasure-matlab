function [report, session] = checkInstrument(model, options)
% CHECKINSTRUMENT Guide an instrument check and collect a local feedback ZIP.
%   [report, session] = colormeasure.checkInstrument() asks for one instrument,
%   and its port. Reports default to Desktop/ColorMeasurement-Reports (or the
%   user home folder when Desktop is absent). Every reading requires confirmation. Repeat
%   separately for each available instrument. This checks communication, saving
%   and the window, not calibration or optical accuracy. No automatic upload,
%   port probing, calibration, settings sweep or acquisition retry is performed.
%   Keep session alive after a failure; use its normal recovery controls.
%   Destination, Adapter, Services and Interaction support software checks using
%   synthetic adapters and noninteractive callbacks; they are not hardware proof.
%   Fernando Voltolini de Azambuja, 2026.
arguments
    model (1,:) char = ''
    options.Destination (1,:) char = ''
    options.Adapter (1,1) struct = struct()
    options.Services (1,1) struct = colormeasure.ui.services()
    options.Interaction (1,1) struct = struct()
end
session = []; report = struct();
catalog = colormeasure.ui.deviceCatalog();
% Instrument entries identify their owning driver folder.
catalog = catalog(~cellfun(@isempty,{catalog.folder}));
if isempty(model)
    [index, accepted] = listdlg('PromptString','Which instrument will you check?', ...
        'ListString',{catalog.label},'SelectionMode','single','ListSize',[360 160]);
    if ~accepted, return; end
else
    index = find(strcmpi({catalog.model},model),1);
    assert(~isempty(index),'Measurement:CheckModel','Choose a model from colormeasure.ui.deviceCatalog.');
end
model = catalog(index).model;
parent = options.Destination;
if isempty(parent)
    userFolder = char(java.lang.System.getProperty('user.home'));
    parent = fullfile(userFolder,'Desktop');
    if ~isfolder(parent), parent=userFolder; end
    parent = fullfile(parent,'ColorMeasurement-Reports');
    [created,message] = mkdir(parent);
    assert(created,'Measurement:CheckReportFolder', ...
        'Cannot create the report folder: %s. %s',parent,message);
end
% MATLAB's current folder can differ from Java's cached working directory.
parentPath=java.io.File(parent);
if ~parentPath.isAbsolute(),parent=fullfile(pwd,parent);end
folder = colormeasure.session.createMeasurementFolder(parent, ...
    ['instrument-check-' model],datetime('now','TimeZone','UTC'));
archivePath = [folder '.zip'];
interaction = struct('confirm',@confirm,'choosePort',@choosePort, ...
    'inspect',@inspectWindow,'notes',@askNotes);
names = fieldnames(options.Interaction);
for k=1:numel(names)
    assert(isfield(interaction,names{k})&&isa(options.Interaction.(names{k}),'function_handle'), ...
        'Measurement:CheckInteraction','Unknown or invalid interaction callback: %s.',names{k});
    interaction.(names{k}) = options.Interaction.(names{k});
end
stepNames = {'preparation','settings','reading-1','reading-2','reading-3','save-reload','window'};
steps = struct('name',stepNames,'status','skipped','detail','Not reached.', ...
    'identifier','','timeUTC','');
report = struct('schemaVersion',1,'startedAtUTC',nowText(),'completedAtUTC','', ...
    'model',model,'mode','physical','matlab',version,'platform',computer, ...
    'package',struct(),'status','interrupted','steps',steps, ...
    'port','','notes','','folder',folder,'archive',archivePath, ...
    'limitation','Communication and workflow check only; no calibration or optical-accuracy verdict.');
current = 1; archiveAttempted = false;
cleanup = onCleanup(@() archiveReport());
try
    report.package=packageIdentity();
    checkpoint();
    registry = colormeasure.session.sessionRegistry('get');
    adapter = options.Adapter;
    if ~isempty(fieldnames(adapter)), report.mode='injected-adapter'; end
    if isempty(fieldnames(adapter)), adapter = catalog(index).factory(); end
    if isfield(adapter,'catalog')&&isfield(adapter.catalog,'mode')&& ...
            ~strcmp(adapter.catalog.mode,'measure')
        report.mode = ['synthetic-' char(adapter.catalog.mode)];
    end
    assert(~any(strcmp(registry.keys,adapter.key)), ...
        'Measurement:CheckExistingSession', ...
        ['This instrument already has a retained batch. Save it and resolve cleanup first. ' ...
        'Restart MATLAB before running this check; the check will not replace that batch.']);
    session = colormeasure.session.Session(adapter,folder,options.Services);
    colormeasure.session.sessionRegistry('put',adapter.key,session,folder);
    guide = session.preparation;
    text = [guide.summary newline strjoin(guide.details,newline) newline newline ...
        'Prepare and warm up the instrument according to its guide. Use a stable, safe target. ' ...
        'This check uses the normal automatic acquisition profile, which may change instrument settings. ' ...
        'It will read settings and request three separate readings. Ready to continue?'];
    startStep(1); requireConfirmation(text); passStep('Operator confirmed preparation.');
    startStep(2);
    port = interaction.choosePort(session.ports);
    if isempty(port), cancelled(); end
    session.selectPort(port); report.port = char(port);
    assert(session.refreshInstrumentSettings()&&isempty(session.measurements)&& ...
        ~session.chartIoUnconfirmed,'Measurement:CheckSettings', ...
        'Settings read or connection cleanup failed. See the session log.');
    passStep('Settings read without acquiring a reading; connection cleanup confirmed.');
    for reading=1:3
        startStep(reading+2);
        requireConfirmation(sprintf(['Reading %d of 3: keep the same target steady. ' ...
            'Start this measurement now? Cancel stops the check without another reading.'],reading));
        ok = session.measure(sprintf('Lab check %d',reading),'Guided instrument check');
        assert(ok&&numel(session.measurements)==reading,'Measurement:CheckReading', ...
            'Reading failed or was not retained. See the session log.');
        assert(~session.chartIoUnconfirmed,'Measurement:CheckCleanup', ...
            'Reading retained, but instrument cleanup is unconfirmed. Use the normal recovery controls.');
        assert(session.savedCount==reading&&isempty(session.saveError), ...
            'Measurement:CheckSave','Reading retained, but saving failed. Use the normal recovery controls.');
        passStep(sprintf('Reading %d retained and saved; connection cleanup confirmed.',reading));
    end
    startStep(6); session.finish();
    assert(session.finished&&~session.needsRecovery,'Measurement:CheckFinish', ...
        'Batch did not finish cleanly. See the session log and recovery controls.');
    saved = load(session.files.mat,'measurements','batchInfo');
    assert(isequaln(saved.measurements,session.measurements),'Measurement:CheckMat', ...
        'Reloaded MAT readings differ from the retained readings.');
    actual = readtable(session.files.csv,'TextType','string','VariableNamingRule','preserve');
    expected = adapter.toTable(session.measurements,session.info);
    assert(height(actual)==height(expected)&& ...
        isequal(actual.Properties.VariableNames,expected.Properties.VariableNames), ...
        'Measurement:CheckCsv','CSV shape or columns differ from the driver table.');
    passStep('Finished batch; MAT data reloaded exactly and CSV rows and columns verified.');
    startStep(7);
    before = session.measurements;
    outcome = interaction.inspect(session);
    assert(ischar(outcome)&&any(strcmp(outcome,{'passed','failed','skipped'})), ...
        'Measurement:CheckWindow','Window inspection returned an invalid result.');
    assert(isequaln(before,session.measurements),'Measurement:CheckWindow', ...
        'Readings changed while inspecting the finished window.');
    report.steps(current).status = outcome;
    report.steps(current).detail = ['Operator window check: ' outcome '.'];
    if strcmp(outcome,'failed')
        report.status='failed';
    elseif strcmp(outcome,'skipped')
        report.status='incomplete';
    else
        report.status='passed';
    end
catch err
    report.steps(current).identifier = err.identifier;
    report.steps(current).detail = err.message;
    if strcmp(err.identifier,'Measurement:CheckCancelled')
        report.steps(current).status='cancelled'; report.status='cancelled';
    else
        report.steps(current).status='failed'; report.status='failed';
    end
end
try
    report.notes = char(interaction.notes());
catch err
    report.notes = ['Notes unavailable: ' err.message];
end
report.completedAtUTC = nowText();
archiveReport(); clear cleanup

    function startStep(index)
        current = index;
        report.steps(current).status='running'; report.steps(current).detail='Started; no result yet.';
        report.steps(current).timeUTC=nowText(); checkpoint();
    end
    function passStep(detail)
        report.steps(current).status='passed'; report.steps(current).detail=detail; checkpoint();
    end
    function requireConfirmation(text)
        if ~interaction.confirm(text), cancelled(); end
    end
    function checkpoint()
        measurements=struct([]); sessionInfo=struct(); sessionLog=struct([]);
        settings=struct([]); settingsReceipt=struct([]);
        if ~isempty(session)&&isvalid(session)
            measurements=session.measurements; sessionInfo=session.info; sessionLog=session.log;
            settings=session.settingsSnapshot; settingsReceipt=session.lastSettingsReceipt;
        end
        colormeasure.session.saveMatFile(fullfile(folder,'diagnostic.mat'), ...
            struct('report',report,'measurements',measurements,'sessionInfo',sessionInfo, ...
            'sessionLog',sessionLog,'settings',settings,'settingsReceipt',settingsReceipt),true);
        writeText(fullfile(folder,'report.json'),jsonencode(report,PrettyPrint=true));
        lines={['Instrument check: ' model],['Result: ' report.status], ...
            ['Mode: ' report.mode],['MATLAB: ' report.matlab],['Platform: ' report.platform], ...
            ['Port: ' report.port],report.limitation,''};
        for j=1:numel(report.steps)
            step=report.steps(j);
            lines{end+1}=sprintf('%s: %s | %s %s',step.name,step.status,step.identifier,step.detail); %#ok<AGROW>
        end
        lines{end+1}=['Notes: ' report.notes];
        lines{end+1}=''; lines{end+1}='Session log:';
        for j=1:numel(sessionLog)
            lines{end+1}=sprintf('%s [%s] %s',sessionLog(j).timeUTC,sessionLog(j).level,sessionLog(j).message); %#ok<AGROW>
        end
        writeText(fullfile(folder,'report.txt'),strjoin(lines,newline));
    end
    function archiveReport()
        % One attempt: the cleanup must not retry and repeat a failure.
        if archiveAttempted, return; end
        archiveAttempted=true;
        try
            checkpoint();
            % Only this newly reserved folder is included. Existing measurement data
            % and other folders are never gathered into the feedback archive.
            [reportParent,stem]=fileparts(folder);
            staged=[tempname(reportParent) '.part.zip'];
            stagedCleanup=onCleanup(@()removeStagedArchive(staged));
            zip(staged,{stem},reportParent);
            % Default copy refuses any occupied path, including dangling links,
            % without requiring hard-link support from the destination filesystem.
            java.nio.file.Files.copy(java.io.File(staged).toPath(), ...
                java.io.File(archivePath).toPath());
            clear stagedCleanup
            fprintf('\nInstrument check: %s\nReport ZIP:\n%s\n',report.status,archivePath);
            fprintf('Reports include readings, instrument serial/settings, and paths that can show your user name.\n');
            fprintf('Issue attachments are public; you can share only the result and error. Nothing was uploaded.\n');
            if ~isempty(session)&&isvalid(session)&&~session.finished
                fprintf('Open the retained batch for recovery: colormeasure.app(''%s'')\n',model);
            end
        catch archiveError
            fprintf(2,'Could not complete report ZIP: %s\nRetained files: %s\n',archiveError.message,folder);
            report.status='report-error';
            try
                checkpoint();
            catch
                % The destination may itself be unavailable; console output
                % above remains the fallback. Never report a ZIP as complete.
            end
        end
        fprintf('Share feedback: https://github.com/ferazambuja/colormeasure-matlab/issues/new?template=instrument-test.yml\n');
    end
end

function removeStagedArchive(filename)
if isfile(filename),delete(filename);end
end

function value=nowText()
value=colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
end
function cancelled()
error('Measurement:CheckCancelled','Operator cancelled; remaining checks were not run.');
end
function yes=confirm(text)
yes=strcmp(questdlg(text,'Lab instrument check','Continue','Cancel','Cancel'),'Continue');
end
function port=choosePort(ports)
assert(~isempty(ports),'Measurement:CheckPort','No serial ports found. Check the cable, driver and instrument guide.');
[index,accepted]=listdlg('PromptString','Select the connected instrument port (no automatic probing):', ...
    'ListString',cellstr(ports),'SelectionMode','single','ListSize',[420 180]);
port=''; if accepted, port=char(ports(index)); end
end
function outcome=inspectWindow(session)
fprintf(['\nInspect Data, plots, Compare and Settings in the finished batch.\n' ...
    'Close the measurement window when done; closing hides it and keeps the readings.\n']);
session.show(); waitfor(session.window,'Visible','off');
session.show(); session.hide();
answer=questdlg('Did the window, data and plots work, and did closing preserve your batch?', ...
    'Window check','Yes','No','Skip','Skip');
outcome='skipped';
if strcmp(answer,'Yes'),outcome='passed';elseif strcmp(answer,'No'),outcome='failed';end
end
function text=askNotes()
answer=inputdlg({'Instrument model/serial, target/setup, and any issue or skipped check (optional):'}, ...
    'Instrument test feedback',[5 85],{''});
text='';if ~isempty(answer),text=answer{1};end
end
function identity=packageIdentity()
file=fullfile(colormeasure.root(),'package-manifest.json');
identity=struct('sourceCommit','','manifestSHA256','','description','Source checkout; no packaged version manifest.');
if isfile(file)
    data=jsondecode(fileread(file));
    identity.sourceCommit=data.sourceCommit;
    identity.manifestSHA256=colormeasure.fileDigest(file);
    identity.description='MATLAB app and drivers package';
end
end
function writeText(filename,text)
[fid,message]=fopen(filename,'w','n','UTF-8');
assert(fid>=0,'Measurement:CheckReport','Cannot write report: %s',message);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',text);
end

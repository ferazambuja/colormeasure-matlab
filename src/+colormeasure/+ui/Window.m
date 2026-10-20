classdef Window < handle
    % WINDOW Native controls, spectra, chromaticity, results and event history.
    %   Rendering never changes session data or uncommitted sample fields.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = private)
        Figure
    end
    properties (Access = private)
        Session
        Listener
        Fields = struct()
        Log
        Results
        LogPanel
        LogVisible = false
        LowerView = 'readings'
        ReadingsOpen = true
        ReadingsExpanded = false
        SeenLogCount = 0
        LastSampleRevision = -1
        LastCount = -1
        LastAnnotationRevision = -1
        LastViewError = ''
        LayingOut = false
        Rendering = false
        RenderPending = false
        ConstructionComplete = false
        Sidebar
        MeasureTab
        ReadingTab
        CompareTab
        IlluminationTab
        PreparationPrompt
        PreparationAccepted = false
        SettingsView = []
        AnnotationView = []
        ChartView = []
        ChartSetup = []
        CleanupView = []
        ChartWorkspace = 'chart'
        LastChartRun = ''
        DeviceCatalog
        CurrentDevice = []
        DeviceMode = ''
        DeviceOpener
        VisibilityListener = []
        ShortcutHeld = false
        TextDraft = false
        SourceSnapshot = []
        ConstructorArguments = {}
    end
    methods
        function obj = Window(session,preparationPrompt,deviceOpener,deferVisibility)
            if isMATLABReleaseOlderThan('R2026b')
                error('Measurement:UIVersion', ...
                    'Color Measurement requires MATLAB R2026b or newer.');
            end
            if nargin<4,deferVisibility=false;end
            obj.Session = session;
            % Retain only supplied arguments; recreate default callbacks on refresh.
            if nargin>=2,obj.ConstructorArguments{1}=preparationPrompt;end
            if nargin>=3,obj.ConstructorArguments{2}=deviceOpener;end
            obj.SourceSnapshot=colormeasure.ui.sourceSnapshot();
            if nargin<2||isempty(preparationPrompt)
                preparationPrompt=@(guide,confirm)showPreparation(guide,confirm,@(event)obj.keyRelease(event),obj.Figure);
            end
            obj.PreparationPrompt=preparationPrompt;
            if nargin<3||isempty(deviceOpener),deviceOpener=@colormeasure.ui.switchDevice;end
            obj.DeviceOpener=deviceOpener;
            [obj.DeviceCatalog,obj.CurrentDevice,obj.DeviceMode] = colormeasure.ui.deviceCatalog( ...
                session.catalogIdentity);
            screen = get(groot, 'ScreenSize');
            width = max(960, min(1120, screen(3)-64));
            height = max(650, min(760, screen(4)-100));
            obj.Figure = figure('Name', session.label, 'NumberTitle', 'off', ...
                'MenuBar', 'none', 'ToolBar', 'none', 'WindowStyle', 'normal', ...
                'Position', [screen(1)+24 max(screen(2)+30,screen(2)+screen(4)-height-60) width height], ...
                'Tag', 'MeasurementSessionWindow', 'Visible', 'off', ...
                'Interruptible', 'off', 'BusyAction', 'cancel');
            cleanup=onCleanup(@() obj.cleanupPartial());
            obj.make('text','BatchIdentity','');
            obj.Fields.BatchDestination=uilabel(obj.Figure,'Text','','Tag','BatchDestination', ...
                'FontSize',13,'WordWrap','off','Interpreter','none');
            obj.make('text','CurrentStatus','');
            obj.make('text','RecoveryMessage','');
            set(obj.Fields.RecoveryMessage,'FontWeight','bold');
            obj.make('text','InstrumentLabel','Instrument');
            obj.make('popupmenu','InstrumentSelector',{'Current instrument'});
            obj.make('pushbutton','OpenInstrumentButton','Open');
            set(obj.Fields.InstrumentSelector,'Callback',@(~,~) obj.stageInstrument(), ...
                'TooltipString','Choose an instrument, then Open its separate batch.');
            set(obj.Fields.OpenInstrumentButton,'Callback',@(~,~) obj.openInstrument());
            if ~isempty(obj.CurrentDevice)
                set(obj.Fields.InstrumentSelector,'String',{obj.DeviceCatalog.label},'Value',obj.CurrentDevice);
                if strcmp(obj.DeviceMode,'gallery')
                    set(obj.Fields.OpenInstrumentButton,'String','Open gallery', ...
                        'TooltipString','Open this instrument''s synthetic gallery. A new gallery creates example readings without hardware.');
                else
                    set(obj.Fields.OpenInstrumentButton,'TooltipString', ...
                        'Open or restore the selected instrument''s batch. This does not take a measurement.');
                end
            end
            set(obj.Fields.CurrentStatus,'FontWeight','bold');
            set(obj.Fields.BatchIdentity,'HorizontalAlignment','right','FontSize',9);
            obj.Sidebar=uitabgroup(obj.Figure,'Units','pixels','Tag','MeasurementSidebar');
            obj.MeasureTab=uitab(obj.Sidebar,'Title','Measure','Tag','MeasureTab','AutoResizeChildren','off');
            obj.ReadingTab=uitab(obj.Sidebar,'Title','Data','Tag','ReadingTab','AutoResizeChildren','off');
            obj.CompareTab=uitab(obj.Sidebar,'Title','Compare','Tag','CompareTab');
            obj.IlluminationTab=uitab(obj.Sidebar,'Title','Color','Tag','IlluminationTab');
            obj.ReadingTab.Tooltip='Selected reading values, notes and metadata.';
            obj.IlluminationTab.Tooltip='Derived chromatic adaptation and reflectance/relighting views.';
            obj.make('pushbutton','ChartButton','Chart / ColorChecker…');
            set(obj.Fields.ChartButton,'Callback',@(~,~)obj.toggleChart(), ...
                'TooltipString','Choose a chart to measure one patch at a time.');
            obj.Fields.ChartWorkspaceSelector=uicontrol(obj.Figure,'Style','popupmenu', ...
                'Units','pixels','String',{'Chart','Plots'},'Value',1,'FontSize',13, ...
                'Tag','ChartWorkspaceSelector','Visible','off', ...
                'Callback',@(~,~)obj.selectWorkspace(),'BusyAction','queue');
            obj.make('text','NameLabel','Sample');
            obj.make('edit','SampleName','');
            obj.make('text','NotesLabel','Notes');
            obj.Fields.SampleNotes=uitextarea(obj.MeasureTab,'Tag','SampleNotes', ...
                'Value',{''},'FontSize',13,'WordWrap','on', ...
                'Placeholder','Optional notes for this sample', ...
                'Interruptible','off','BusyAction','cancel');
            obj.make('text','PortLabel','Port');
            obj.make('popupmenu','SerialPort',{'Select port'});
            obj.make('pushbutton','RefreshPortsButton','Refresh ports');
            obj.make('pushbutton','InstrumentHelpButton','Instrument help');
            set(obj.Fields.InstrumentHelpButton,'Callback',@(~,~) obj.instrumentHelp(), ...
                'TooltipString','Preparation guidance and instrument manual. No instrument commands are sent.');
            obj.make('pushbutton','InstrumentSettingsButton','Settings...');
            set(obj.Fields.InstrumentSettingsButton,'Callback',@(~,~) obj.instrumentSettings(), ...
                'TooltipString','Measurement settings and instrument help. Opening sends no instrument commands.');
            [~,~,shortcutHint]=colormeasure.ui.measureShortcut();
            obj.make('pushbutton','MeasureButton',['Measure  (' shortcutHint ')']);
            set(obj.Fields.MeasureButton,'FontWeight','bold');
            set(obj.Fields.MeasureButton,'TooltipString', ...
                ['Measure the next sample. ' colormeasure.ui.measureShortcut() ' from the idle Measure tab.']);
            obj.make('pushbutton','FinishButton','Finish batch');
            obj.make('pushbutton','NewBatchButton','New batch');
            obj.make('pushbutton','RetrySaveButton','Retry save');
            obj.make('pushbutton','SaveElsewhereButton','Another folder');
            obj.make('pushbutton','RetryChartCleanupButton','Retry cleanup');
            set(obj.Fields.RetryChartCleanupButton,'Callback',@(~,~)obj.retryChartCleanup(), ...
                'TooltipString','Retry closing this retained connection owner. No new connection or measurement is started.');
            obj.make('pushbutton','ConfirmChartCleanupButton','Confirm cleanup...');
            set(obj.Fields.ConfirmChartCleanupButton,'Callback',@(~,~)obj.confirmChartCleanup(), ...
                'TooltipString','Record your checks that the direct connection is closed and the instrument is idle. No measurement is taken.');
            obj.make('pushbutton','ToggleReadingsButton','Hide readings');
            obj.make('pushbutton','ExpandReadingsButton','Expand');
            set(obj.Fields.ToggleReadingsButton,'Callback',@(~,~)obj.toggleReadings(), ...
                'BusyAction','queue','TooltipString','Show or hide readings without changing plot selection.');
            set(obj.Fields.ExpandReadingsButton,'Callback',@(~,~)obj.expandReadings(), ...
                'BusyAction','queue','TooltipString','Give the readings table more or less space.');
            obj.make('pushbutton','ToggleLogButton','Show log');
            set(obj.Fields.ToggleLogButton,'Callback',@(~,~) obj.toggleLog(), ...
                'BusyAction','queue','TooltipString','Switch between the readings table and retained session log.');
            set(obj.Fields.SampleName,'TooltipString','Name of the next sample to measure.');
            set(obj.Fields.SampleNotes,'Tooltip','Optional notes for the next measurement.');
            obj.LogPanel=uipanel(obj.Figure,'Units','pixels','BorderType','none', ...
                'Tag','SessionLogPanel','Visible','off');
            obj.Log = colormeasure.ui.LogView(obj.LogPanel);
            obj.Results = colormeasure.ui.ResultsView(obj.Figure,obj.ReadingTab,obj.CompareTab,obj.IlluminationTab, ...
                @(index)obj.editReading(index));
            obj.ChartView=colormeasure.ui.ChartView(obj.Figure,session, ...
                @()obj.chartBlockReason(),@()obj.measureBlockReason(),@()obj.openChartSetup());
            set(obj.Sidebar,'SelectionChangedFcn', ...
                @(source,~) obj.selectTab(source.SelectedTab.Tag), ...
                'Interruptible','off','BusyAction','queue');
            actions = {'MeasureButton','measure'; 'FinishButton','finish'; ...
                'RefreshPortsButton','refreshPorts'; 'RetrySaveButton','retrySave'; ...
                'SaveElsewhereButton','saveElsewhere'; 'NewBatchButton','newBatch'};
            for index=1:size(actions,1)
                method=actions{index,2};
                set(obj.Fields.(actions{index,1}),'Callback',@(~,~) obj.invoke(method));
            end
            % Session guards and disabled action controls protect acquisition.
            % Short inspection callbacks may run at the driver's yield points.
            set(obj.Fields.MeasureButton,'Interruptible','on');
            set(obj.Fields.SampleName,'Callback',@(~,~) obj.inputs(),'KeyPressFcn',@(~,event) obj.noteTextDraft(event));
            set(obj.Fields.SampleNotes,'ValueChangedFcn',@(~,~) obj.inputs(),'ValueChangingFcn',@(~,~) obj.noteTextDraft());
            set(obj.Fields.SerialPort,'Callback',@(~,~) obj.inputs());
            set(obj.Figure,'CloseRequestFcn',@(~,~) obj.hide(), ...
                'SizeChangedFcn',@(~,~) obj.resize(), ...
                'ThemeChangedFcn',@(~,~) obj.refreshTheme(), ...
                'WindowKeyPressFcn',@(~,event)obj.keyPress(event), ...
                'WindowKeyReleaseFcn',@(~,event)obj.keyRelease(event), ...
                'WindowButtonDownFcn',@(~,~)obj.resetShortcut());
            obj.VisibilityListener=addlistener(obj.Figure,'Visible','PostSet',@(~,~)obj.visibilityChanged());
            obj.Listener = addlistener(session,'Changed',@(~,~) obj.render());
            % Timer completion can notify while a graphics setter yields.
            % Admit that notification, then coalesce it in render().
            obj.Listener.Recursive = true;
            obj.render();
            visible=get(groot,'DefaultFigureVisible');
            if strcmp(visible,'on'),set(obj.Figure,'WindowState','maximized');end
            if deferVisibility,visible='off';end
            set(obj.Figure,'Visible',visible);
            obj.ConstructionComplete=true;
        end

        function render(obj)
            if ~isgraphics(obj.Figure) || ~isvalid(obj.Session), return; end
            if obj.Rendering, obj.RenderPending=true; return; end
            obj.Rendering=true; cleanup=onCleanup(@()obj.releaseRender());
            obj.RenderPending=true;
            while isvalid(obj) && obj.RenderPending && isgraphics(obj.Figure) && isvalid(obj.Session)
                obj.RenderPending=false;
                try
                    s=obj.Session;
                    % Explicit sample edits replace both fields, even when one
                    % committed value stays the same. Other notifications preserve drafts.
                    revision=s.sampleRevision;name=s.name;notes=s.notes;
                    if obj.LastSampleRevision~=revision
                        set(obj.Fields.SampleName,'String',name);
                        set(obj.Fields.SampleNotes,'Value',regexp(notes,'\r\n|\n|\r','split'));
                        obj.LastSampleRevision=revision;
                    end
                    choices=cellstr(s.ports(:)); index=find(strcmp(choices,s.port),1);
                    if isempty(index), index=0; end
                    set(obj.Fields.SerialPort,'String',[{'Select port'};choices],'Value',index+1, ...
                        'TooltipString',s.port);
                    pending=obj.devicePending();
                    chart=s.chart;
                    editable=~s.busy && ~s.finishing && ~s.finished && ~pending;
                    hasSelector=~isempty(obj.CurrentDevice);
                    set([obj.Fields.InstrumentLabel obj.Fields.InstrumentSelector ...
                        obj.Fields.OpenInstrumentButton],'Visible',colormeasure.ui.onOff(hasSelector));
                    set(obj.Fields.InstrumentSelector,'Enable',colormeasure.ui.onOff(~s.busy && (~s.finishing || s.finished)));
                    openTip='Open or restore the selected instrument batch. This does not take a measurement.';
                    if strcmp(obj.DeviceMode,'gallery')
                        openTip='Open this instrument''s synthetic gallery. A new gallery creates example readings without hardware.';
                    end
                    set(obj.Fields.OpenInstrumentButton,'Enable',colormeasure.ui.onOff(~s.busy && ...
                        (~s.finishing || s.finished) && pending),'TooltipString',openTip);
                    set(obj.Fields.BatchIdentity,'Visible',colormeasure.ui.onOff(~hasSelector));
                    set([obj.Fields.SampleName obj.Fields.SampleNotes obj.Fields.SerialPort ...
                        obj.Fields.RefreshPortsButton],'Enable',colormeasure.ui.onOff(editable));
                    guided=~isempty(chart)&&~chart.paused;
                    % All setup paths, including startChart on an open window,
                    % enter the same primary chart layout exactly once per run.
                    % Later reading-table inspection keeps the user's choice.
                    if ~isempty(chart)&&~strcmp(obj.LastChartRun,chart.runId)
                        obj.ChartWorkspace='chart';obj.ReadingsOpen=false;obj.LastChartRun=chart.runId;
                    elseif isempty(chart)
                        obj.LastChartRun='';
                    end
                    taskReady=isempty(chart)||~chart.paused||isempty(chart.pendingContext);
                    taskLabel='Chart / ColorChecker…';taskTip='Choose a chart to measure one patch at a time.';
                    if guided
                        taskLabel='Samples';taskTip='Pause the chart and measure individual samples. Chart progress is kept.';
                    elseif ~isempty(chart)
                        taskLabel='Resume chart';taskTip='Return to measuring chart patches.';
                    end
                    if ~taskReady,taskTip='Review changed settings before resuming this chart.';end
                    set(obj.Fields.ChartButton,'String',taskLabel,'Enable',colormeasure.ui.onOff(editable&& ...
                        obj.chartEditable()&&taskReady),'TooltipString',taskTip);
                    if guided,set(obj.Fields.SampleName,'Enable','off');end
                    obj.ChartView.update(chart);
                    [~,~,hint]=colormeasure.ui.measureShortcut();
                    measureLabel='Measure';
                    if guided,measureLabel=['Measure ' colormeasure.chart.coordinate(chart.currentCell(1),chart.currentCell(2))];end
                    measureBlock=obj.measureBlockReason();
                    measureTip=['Measure the next sample. ' colormeasure.ui.measureShortcut() ' from the idle Measure tab.'];
                    if ~isempty(measureBlock),measureTip=measureBlock;end
                    set(obj.Fields.MeasureButton,'Enable',colormeasure.ui.onOff(editable && index>0&&isempty(measureBlock)), ...
                        'String',[measureLabel '  (' hint ')'],'TooltipString',measureTip);
                    hasSettings = ~isempty(s.settingsCatalog);
                    set(obj.Fields.InstrumentHelpButton,'Visible',colormeasure.ui.onOff(~hasSettings && ~isempty(obj.preparation())), ...
                        'Enable',colormeasure.ui.onOff(~s.busy && ~pending));
                    settingsLabel = 'Settings...';
                    overrides = numel(fieldnames(s.settingsOverrides));
                    if overrides > 0, settingsLabel = sprintf('Settings (%d)',overrides); end
                    settingsTip = sprintf('Measurement settings. %d active overrides; sent when Measure starts.',overrides);
                    if overrides == 1, settingsTip = 'Measurement settings. 1 active override; sent when Measure starts.'; end
                    set(obj.Fields.InstrumentSettingsButton,'Visible',colormeasure.ui.onOff(hasSettings), ...
                        'Enable',colormeasure.ui.onOff(~s.busy && ~pending),'String',settingsLabel, ...
                        'TooltipString',settingsTip);
                    set(obj.Fields.FinishButton,'Enable',colormeasure.ui.onOff(~s.busy && ~s.finished && ~pending));
                    newBatchReason='';
                    if s.chartIoUnconfirmed
                        newBatchReason='Connection cleanup is unconfirmed. Resolve it before starting a new batch.';
                    elseif s.needsRecovery
                        newBatchReason='Save needs attention. Use Retry save or Another folder before starting a new batch.';
                    end
                    set(obj.Fields.NewBatchButton,'Enable',colormeasure.ui.onOff(~s.busy && s.finished && ~pending && ...
                        ~s.chartIoUnconfirmed&&~s.needsRecovery), ...
                        'TooltipString',newBatchReason);
                    stopPending=s.chartIoUnconfirmed&&~s.busy;
                    ownedCleanup=s.directCleanupCanRetry&&~s.busy;
                    set(obj.Fields.RetryChartCleanupButton,'Visible',colormeasure.ui.onOff(ownedCleanup), ...
                        'Enable',colormeasure.ui.onOff(ownedCleanup));
                    declaration=stopPending&&~s.directCleanupCanRetry;
                    set(obj.Fields.ConfirmChartCleanupButton,'Visible',colormeasure.ui.onOff(declaration), ...
                        'Enable',colormeasure.ui.onOff(declaration));
                    recovery=s.needsRecovery&&(~stopPending||~isempty(s.saveError)||~isempty(s.exportError));
                    csvRecovery=s.chartCsvNeedsRetry;
                    companionRecovery=s.companionRecoveryAvailable;
                    companionNotice=~isempty(chart)&&~isempty(chart.csvUnavailableReason);
                    set(obj.Fields.RecoveryMessage,'Visible',colormeasure.ui.onOff(recovery||stopPending|| ...
                        companionRecovery||csvRecovery||companionNotice));
                    set(obj.Fields.RetrySaveButton,'Visible',colormeasure.ui.onOff(recovery||csvRecovery));
                    elsewhere=recovery||companionRecovery;
                    set(obj.Fields.SaveElsewhereButton,'Visible',colormeasure.ui.onOff(elsewhere));
                    retryLabel='Retry save';retryTip='Retry saving the retained batch without measuring again.';
                    if csvRecovery&&~recovery
                        retryLabel='Retry CSV';retryTip='Retry chart CSV from saved data. No new measurement is taken.';
                    end
                    set(obj.Fields.RetrySaveButton,'String',retryLabel,'TooltipString',retryTip);
                    if recovery||stopPending||companionRecovery||csvRecovery||companionNotice
                        [message,details]=obj.recoveryMessage();
                        set(obj.Fields.RecoveryMessage,'String',message,'TooltipString',details);
                    end
                    % A destination refusal before acquisition has no payload
                    % to retry; Another folder is the actionable recovery.
                    retained=~isempty(s.measurements)||~isempty(chart);
                    set(obj.Fields.RetrySaveButton,'Enable',colormeasure.ui.onOff(~s.busy && ...
                        (csvRecovery||(retained&&(recovery||~s.finished)))));
                    elsewhereReason='Save the retained batch in a new folder without measuring again.';
                    set(obj.Fields.SaveElsewhereButton,'Enable',colormeasure.ui.onOff(~s.busy && (~s.finished||recovery||companionRecovery)), ...
                        'TooltipString',elsewhereReason);
                    opened=s.startedAtUTC;
                    stamp=colormeasure.session.displayTime(opened);
                    set(obj.Fields.BatchIdentity,'String',['Opened ' stamp], ...
                        'TooltipString',['UTC: ' opened]);
                    folder=s.destination;
                    set(obj.Fields.BatchDestination,'Text',['Folder: ' folder], ...
                        'Tooltip',sprintf('%s\nOpened %s\nUTC: %s',folder,stamp,opened));
                    obj.renderStatus();
                    obj.renderLogToggle();
                    [resultPosition,logPosition]=obj.layout();
                    count=numel(s.measurements);
                    if obj.LastCount~=count || obj.LastAnnotationRevision~=s.annotationRevision
                        obj.Results.update(s.measurements,s.viewData(),resultPosition);
                        obj.LastCount=count;
                        obj.LastAnnotationRevision=s.annotationRevision;
                    end
                    obj.Results.setEditingEnabled(~s.busy && (~s.finishing||s.finished));
                    if obj.LogVisible, obj.Log.update(s.log,logPosition); end
                    obj.LastViewError='';
                catch err
                    obj.viewError(err);
                    break
                end
            end
        end

        function resize(obj)
            % SizeChangedFcn can interrupt acquisition regardless of BusyAction.
            % This path only lays out existing controls; no acquisition, saving,
            % adapter calls, draft commits, or session notifications.
            if obj.LayingOut || ~isgraphics(obj.Figure), return; end
            try
                [~,logPosition]=obj.layout();
                if obj.LogVisible, obj.Log.update(obj.Session.log,logPosition); end
                obj.renderStatus();
            catch err
                obj.viewError(err);
            end
        end

        function restored=restore(obj)
            % MATLAB reloads methods without rerunning constructors. Retained
            % anonymous callbacks can then become unresolvable. Rebuild only
            % the presentation at this explicit restore boundary.
            % https://www.mathworks.com/help/matlab/matlab_oop/modifying-and-reloading-classes.html
            restored=obj;
            current=colormeasure.ui.sourceSnapshot();
            assert(~isempty(obj.SourceSnapshot)&&isequal(obj.SourceSnapshot.runtime,current.runtime), ...
                'Measurement:ViewRuntimeChanged', ...
                ['The retained window predates this source check or runtime code changed. ' ...
                'Readings remain in session.measurements and session.files. Finish/save the batch ' ...
                'using its session handle, then restart MATLAB with one installation.']);
            if ~isgraphics(obj.Figure)||~isequal(obj.SourceSnapshot.presentation,current.presentation)
                % A folder chooser can lose its owner while the same runtime
                % is busy choosing a destination. Recreate only the unchanged
                % presentation; acquisition and source replacement stay locked.
                choosingFolder=~isgraphics(obj.Figure)&& ...
                    isequal(obj.SourceSnapshot.presentation,current.presentation)&& ...
                    strcmp(obj.Session.activity,'Choosing save folder');
                assert(~obj.Session.busy||choosingFolder, ...
                    'Measurement:ViewRefreshBusy', ...
                    'Finish the current measurement before restoring updated UI code. Readings are retained.');
                assert(~(~isempty(obj.SettingsView)&&isvalid(obj.SettingsView))&& ...
                    ~(~isempty(obj.AnnotationView)&&isvalid(obj.AnnotationView))&& ...
                    ~(~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup))&& ...
                    ~(~isempty(obj.CleanupView)&&isvalid(obj.CleanupView))&& ...
                    ~obj.continuationOpen(), ...
                    'Measurement:ViewRefreshDraft', ...
                    'Save or cancel the open editor before restoring updated UI code. Readings and drafts are retained.');
                name=obj.Session.name;notes={obj.Session.notes};
                if isgraphics(obj.Figure)
                    name=get(obj.Fields.SampleName,'String');notes=obj.Fields.SampleNotes.Value;
                end
                obj.Listener.Enabled=false;
                if isvalid(obj.VisibilityListener),obj.VisibilityListener.Enabled=false;end
                try
                    constructorArguments=obj.ConstructorArguments;constructorArguments(end+1:2)={[]};
                    % A replacement cannot receive operator input until its
                    % retained state is restored and ownership is transferred.
                    restored=colormeasure.ui.Window(obj.Session,constructorArguments{:},true);
                    set(restored.Fields.SampleName,'String',name);restored.Fields.SampleNotes.Value=notes;
                    restored.TextDraft=obj.TextDraft;
                    restored.PreparationAccepted=obj.PreparationAccepted;
                    % Copy only views offered by this presentation.
                    if ismember(obj.LowerView,{'readings','log'}),restored.LowerView=obj.LowerView;end
                    restored.ReadingsOpen=obj.ReadingsOpen;
                    restored.ChartWorkspace=obj.ChartWorkspace;
                    restored.ReadingsExpanded=obj.ReadingsExpanded;restored.LogVisible=obj.LogVisible;
                    restored.resize();
                catch problem
                    if restored~=obj&&isvalid(restored),delete(restored);end
                    obj.Listener.Enabled=true;
                    if isvalid(obj.VisibilityListener),obj.VisibilityListener.Enabled=true;end
                    rethrow(problem);
                end
                delete(obj);
            end
        end

        function delete(obj)
            obj.closeContinuation();
            if ~isempty(obj.CleanupView)&&isvalid(obj.CleanupView),delete(obj.CleanupView);obj.CleanupView=[];end
            if ~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup),delete(obj.ChartSetup);end
            if ~isempty(obj.ChartView)&&isvalid(obj.ChartView),delete(obj.ChartView);end
            if ~isempty(obj.AnnotationView)&&isvalid(obj.AnnotationView),delete(obj.AnnotationView);end
            if ~isempty(obj.VisibilityListener),delete(obj.VisibilityListener);end
            if ~isempty(obj.Listener), delete(obj.Listener); end
            if ~isempty(obj.Log) && isvalid(obj.Log), delete(obj.Log); end
            if ~isempty(obj.Results) && isvalid(obj.Results), delete(obj.Results); end
            if ~isempty(obj.SettingsView) && isvalid(obj.SettingsView), delete(obj.SettingsView); end
            if isgraphics(obj.Figure)
                set(obj.Figure,'CloseRequestFcn','','SizeChangedFcn','','ThemeChangedFcn','', ...
                    'WindowKeyPressFcn','','WindowKeyReleaseFcn','','WindowButtonDownFcn',''); delete(obj.Figure);
            end
        end
    end
    methods (Access = private)
        function editReading(obj,index)
            if ~isempty(obj.AnnotationView)&&isvalid(obj.AnnotationView)
                delete(obj.AnnotationView);
            end
            obj.AnnotationView=colormeasure.ui.ReadingAnnotationView(obj.Session,index,obj.Figure);
        end
        function releaseRender(obj)
            if isvalid(obj),obj.Rendering=false;end
        end
        function cleanupPartial(obj)
            if isvalid(obj) && ~obj.ConstructionComplete, delete(obj); end
        end
        function [resultPosition,logPosition]=layout(obj)
            obj.LayingOut=true; cleanup=onCleanup(@() obj.releaseLayout());
            p=get(obj.Figure,'Position'); width=max(960,p(3)); height=max(650,p(4));
            if ~isempty(obj.Session.chart),height=max(750,height);end
            if width~=p(3) || height~=p(4), set(obj.Figure,'Position',[p(1:2) width height]); end
            left=272; top=height-38;
            obj.place('BatchIdentity',[width-350 height-26 334 18]);
            obj.place('InstrumentLabel',[width-436 height-26 96 20]);
            obj.place('InstrumentSelector',[width-336 height-30 220 26]);
            obj.place('OpenInstrumentButton',[width-110 height-30 94 26]);
            % Keep the folder beside the selector; its tooltip retains the full path.
            obj.place('BatchDestination',[16 height-26 width-468 20]);
            % A shared footer stays visible while any inspection tab is open.
            sideHeight=top-58;
            set(obj.Sidebar,'Position',[16 58 left sideHeight]);
            obj.place('CurrentStatus',[24 16 left-16 36]);
            localTop=sideHeight-34;
            obj.place('ChartButton',[8 localTop-26 left-24 28]);
            localTop=localTop-38;
            nameLabel='Sample';notesLabel='Notes';
            nameTip='Name of the next sample to measure.';notesTip='Optional notes for this sample';
            chart=obj.Session.chart;
            if ~isempty(chart)&&~chart.paused
                nameLabel='Patch';nameTip='Fixed chart coordinate. Select another cell in Chart; reading annotations can be edited separately.';
            end
            set(obj.Fields.NameLabel,'String',nameLabel);set(obj.Fields.NotesLabel,'String',notesLabel);
            set(obj.Fields.SampleName,'TooltipString',nameTip);obj.Fields.SampleNotes.Placeholder=notesTip;
            obj.place('NameLabel',[8 localTop-22 70 20]);
            obj.place('SampleName',[80 localTop-26 left-96 28]);
            obj.place('NotesLabel',[8 localTop-58 70 20]);
            obj.place('SampleNotes',[80 localTop-110 left-96 78]);
            obj.place('PortLabel',[8 localTop-140 70 20]);
            obj.place('SerialPort',[80 localTop-144 left-96 28]);
            obj.place('RefreshPortsButton',[80 localTop-176 left-96 26]);
            obj.place('InstrumentHelpButton',[8 localTop-176 (left-32)/2 26]);
            obj.place('InstrumentSettingsButton',[8 localTop-176 (left-32)/2 26]);
            if ~isempty(obj.preparation()) || ~isempty(obj.Session.settingsCatalog)
                obj.place('RefreshPortsButton',[left/2 localTop-176 (left-32)/2 26]);
            end
            obj.place('MeasureButton',[8 localTop-222 left-24 38]);
            half=(left-32)/2;
            obj.place('FinishButton',[8 localTop-270 half 32]);
            obj.place('NewBatchButton',[16+half localTop-270 half 32]);
            resultsLeft=308;resultsWidth=width-resultsLeft-16;
            % Recovery actions stay reachable from every inspection tab. Make
            % room only for current save and cleanup recovery facts.
            recoveryInset=40*strcmp(obj.Fields.RecoveryMessage.Visible,'on');
            % Only visible actions consume space. At the minimum window width
            % all three actions still leave room for a wrapped status message.
            right=resultsLeft+resultsWidth;
            actions={'SaveElsewhereButton','RetrySaveButton','ConfirmChartCleanupButton','RetryChartCleanupButton'};
            actionWidths=[128 116 146 146];
            for n=1:numel(actions)
                if strcmp(obj.Fields.(actions{n}).Visible,'on')
                    right=right-actionWidths(n);
                    obj.place(actions{n},[right 18 actionWidths(n) 28]);
                    right=right-8;
                end
            end
            obj.place('RecoveryMessage',[resultsLeft 16 right-resultsLeft 34]);
            obj.LogVisible=strcmp(obj.LowerView,'log');
            tableVisible=strcmp(obj.LowerView,'readings')&&obj.ReadingsOpen;
            lowerHeight=0;
            if tableVisible||obj.LogVisible
                lowerHeight=min(150,120+max(0,height-750)*.12);
                if obj.LogVisible,lowerHeight=max(230,lowerHeight);end
                if obj.ReadingsExpanded,lowerHeight=min(330,height*.36);end
            end
            if tableVisible&&~obj.ReadingsExpanded
                % Borrow temporary recovery space from the compact table
                % before reducing the plot area. Retain room
                % for the header and two readings; Expand still offers more.
                lowerHeight=max(80,lowerHeight-recoveryInset);
            end
            lowerPosition=[resultsLeft 16+recoveryInset resultsWidth max(1,lowerHeight)];
            bar=16+recoveryInset+lowerHeight;
            obj.place('ToggleReadingsButton',[resultsLeft bar+4 110 26]);
            logWidth=max(112,obj.Fields.ToggleLogButton.Extent(3)+20);
            obj.place('ToggleLogButton',[resultsLeft+118 bar+4 logWidth 26]);
            obj.place('ExpandReadingsButton',[resultsLeft+126+logWidth bar+4 68 26]);
            pageLeft=resultsLeft+270+logWidth;
            set(obj.Fields.ExpandReadingsButton,'Visible',colormeasure.ui.onOff(tableVisible||obj.LogVisible));
            sizeLabel='Expand';if obj.ReadingsExpanded,sizeLabel='Compact';end
            set(obj.Fields.ExpandReadingsButton,'String',sizeLabel);
            readingLabel='Readings';if tableVisible,readingLabel='Hide readings';end
            set(obj.Fields.ToggleReadingsButton,'String',readingLabel);
            bottom=bar+56;
            resultPosition=struct('plots',[resultsLeft bottom resultsWidth top-bottom], ...
                'table',lowerPosition,'details',[8 8 left-20 sideHeight-42], ...
                'pageLabel',[pageLeft bar+5 resultsLeft+resultsWidth-pageLeft 20], ...
                'editButton',[resultsLeft+202+logWidth bar+4 60 26], ...
                'summary',[resultsLeft bar+34 resultsWidth 20]);
            chartOffered=~isempty(chart)&&obj.Sidebar.SelectedTab==obj.MeasureTab;
            obj.place('ChartWorkspaceSelector',[resultsLeft top-28 150 26]);
            set(obj.Fields.ChartWorkspaceSelector,'Visible',colormeasure.ui.onOff(chartOffered), ...
                'Value',1+strcmp(obj.ChartWorkspace,'plots'));
            if chartOffered,resultPosition.plots(4)=resultPosition.plots(4)-38;end
            obj.Results.layout(resultPosition);
            showChart=chartOffered&&strcmp(obj.ChartWorkspace,'chart');
            obj.ChartView.layout(resultPosition.plots);obj.ChartView.show(showChart);
            obj.Results.showPlotWorkspace(~showChart);
            obj.Results.showTable(tableVisible);
            set(obj.LogPanel,'Position',lowerPosition,'Visible',colormeasure.ui.onOff(obj.LogVisible));
            logPosition=[0 0 resultsWidth lowerHeight];
        end
        function toggleReadings(obj)
            % Inspection does not commit drafts, answer prompts or restart a deadline.
            if strcmp(obj.LowerView,'readings'),obj.ReadingsOpen=~obj.ReadingsOpen;
            else,obj.LowerView='readings';obj.ReadingsOpen=true;end
            obj.render();
        end
        function expandReadings(obj)
            obj.ReadingsExpanded=~obj.ReadingsExpanded;obj.resize();
        end
        function toggleLog(obj)
            if strcmp(obj.LowerView,'log'),obj.LowerView='readings';obj.ReadingsOpen=true;
            else,obj.LowerView='log';end
            obj.render();
        end
        function renderLogToggle(obj)
            entries=obj.Session.log;
            if strcmp(obj.LowerView,'log')
                obj.SeenLogCount=numel(entries);
                label='Show readings';
            else
                unseen=entries(min(obj.SeenLogCount+1,numel(entries)+1):end);
                issues=sum(ismember({unseen.level},{'warning','error'}));
                label='Show log';
                if issues==1
                    label='Show log (1 issue)';
                elseif issues>1
                    label=sprintf('Show log (%d issues)',issues);
                end
            end
            set(obj.Fields.ToggleLogButton,'String',label);
        end
        function renderStatus(obj)
            s=obj.Session; value=s.status;
            detail=value;cleanupPending=s.chartIoUnconfirmed && ~s.busy;
            if obj.devicePending()
                hint='Select Open to switch instruments';
                if ~cleanupPending,value=hint;end
                detail=[hint ' | ' detail];
            end
            if ~s.busy && (s.needsRecovery || contains(s.activity,'failed'))
                indices=find(strcmp({s.log.level},'error'),1,'last');
                if ~isempty(indices), detail=[detail ' | ' s.log(indices).message]; end
            end
            set(obj.Fields.CurrentStatus,'TooltipString',detail);
            value=regexprep(value,'\s+',' ');
            if ~isempty(value),value(1)=upper(value(1));end
            p=get(obj.Fields.CurrentStatus,'Position');capacity=max(40,2*floor(p(3)/7));
            if numel(value)>capacity, value=[value(1:capacity-3) '...']; end
            set(obj.Fields.CurrentStatus,'String',value);
        end
        function [message,details]=recoveryMessage(obj)
            s=obj.Session;companions={};causes={};
            chartFailure=~isempty(s.chart)&&~isempty(s.chart.csvUnavailableReason);
            if chartFailure
                text='Chart CSV is stale.';
                if isempty(s.files.chartCsv),text='Chart CSV export unavailable.';end
                companions{end+1}=text;causes{end+1}=['Chart CSV: ' s.chart.csvUnavailableReason];
            end
            if s.chartIoUnconfirmed&&~s.busy
                message='Connection cleanup unconfirmed. Retained data preserved.';
                if s.directCleanupCanRetry
                    details='Use Retry cleanup to close the retained connection owner. No measurement starts. ';
                else
                    details=['The app can no longer reach the instrument connection. Check that no MATLAB batch or other program still uses the instrument port and that the instrument is not measuring, ' ...
                        'then use Confirm cleanup... to record your checks. ' ...
                        'This declaration does not operate or validate the instrument. '];
                end
                details=[details 'Retry save and Another folder preserve data but cannot confirm connection cleanup.'];
                if ~isempty(s.saveError),details=[details newline s.saveError];end
                if ~isempty(s.exportError),details=[details newline s.exportError];end
            elseif ~isempty(s.saveError)
                if isempty(s.measurements)
                    message='Save needs attention.';
                else
                    message='MAT save failed.';
                end
                if ~isempty(s.measurements)
                    message=[message ' Readings retained.'];
                else
                    message=[message ' See log.'];
                end
                details=s.saveError;
            elseif ~isempty(s.exportError)
                message='CSV export failed. MAT saved.';
                details=s.exportError;
            else
                message=[strjoin(companions,' ') ' MAT saved.'];details='';
            end
            details=strjoin([{details} causes],newline);details=strtrim(details);
            if ~s.needsRecovery
                if s.chartCsvNeedsRetry
                    action='Retry CSV uses saved data without measuring again.';
                else
                    action='Repeating Retry cannot resolve this refusal. Inspect the cause.';
                end
                details=[details newline action];
                if s.companionRecoveryAvailable
                    details=[details newline 'Another folder saves retained data to a different destination without measuring again.'];
                end
            end
        end
        function releaseLayout(obj)
            if isvalid(obj), obj.LayingOut=false; end
        end
        function make(obj,style,tag,text)
            parent=obj.Figure;
            if ~isempty(obj.MeasureTab) && ~ismember(tag, ...
                    {'ToggleLogButton','ToggleReadingsButton','ExpandReadingsButton', ...
                    'RecoveryMessage', ...
                    'RetrySaveButton','SaveElsewhereButton','ConfirmChartCleanupButton','RetryChartCleanupButton'})
                parent=obj.MeasureTab;
            end
            obj.Fields.(tag)=uicontrol(parent,'Style',style,'Tag',tag,'String',text, ...
                'Units','pixels','HorizontalAlignment','left','FontSize',10, ...
                'Interruptible','off','BusyAction','cancel');
        end
        function place(obj,name,position)
            set(obj.Fields.(name),'Position',position);
        end
        function noteTextDraft(obj,event)
            % Keys typed into a field are a draft until that field commits
            % (Enter, Tab or a click elsewhere); the shortcut waits for it.
            if ~isvalid(obj)||~isgraphics(obj.Figure),return;end
            if nargin<2||colormeasure.ui.isTextEditKey(event),obj.TextDraft=true;end
        end
        function inputs(obj)
            if ~isvalid(obj)||~isgraphics(obj.Figure)||~isvalid(obj.Session),return;end
            obj.TextDraft=false;
            if obj.Session.busy || obj.Session.finished || obj.Session.finishing || obj.devicePending(), return; end
            name=get(obj.Fields.SampleName,'String'); notes=get(obj.Fields.SampleNotes,'Value');
            if iscell(notes) || (ischar(notes) && size(notes,1)>1)
                notes=strjoin(cellstr(notes),newline);
            end
            choices=get(obj.Fields.SerialPort,'String'); index=get(obj.Fields.SerialPort,'Value');
            port=''; if index>1, port=choices{index}; end
            obj.Session.setSample(name,notes);
            obj.Session.selectPort(port);
        end
        function invoke(obj,method)
            persistence=ismember(method,{'retrySave','saveElsewhere'});
            if obj.Session.busy || (obj.devicePending() && ~persistence), return; end
            if strcmp(method,'measure')
                reason=obj.measureBlockReason();
                if ~isempty(reason),obj.showMeasureBlock(reason);return;end
            end
            returnFocus=strcmp(method,'saveElsewhere') && ...
                colormeasure.ui.canFocus(obj.Fields.SaveElsewhereButton,obj.Figure) && ...
                isequal(colormeasure.ui.currentFigure(),obj.Figure);
            try
                if strcmp(method,'measure') && ~obj.confirmPreparation(),return;end
                % Save the current batch independently of a pending instrument
                % selection or uncommitted sample draft. Never acquire here.
                if ~persistence,obj.inputs();end
                if strcmp(method,'finish')&&~isempty(obj.Session.chart)
                    if ~colormeasure.ui.confirmChartFinish(obj.Session),return;end
                    obj.Session.finish(AllowIncompleteChart=true);
                else
                    obj.Session.(method)();
                end
            catch err
                if isvalid(obj) && isvalid(obj.Session), obj.Session.reportError(err); end
            end
            if returnFocus,obj.restoreFolderFocus();end
        end
        function restoreFolderFocus(obj)
            % Native folder sheets can return keyboard input to the desktop.
            % Restore the invoking batch only while it still owns this view.
            % Cancellation/error keeps recovery visible; successful saving
            % returns to sample entry, or table inspection on another tab.
            if ~obj.canReturnFolderFocus(),return;end
            targets=[obj.Fields.SaveElsewhereButton obj.Fields.SampleName obj.Fields.ToggleReadingsButton];
            for target=targets
                if ~colormeasure.ui.canFocus(target,obj.Figure),continue;end
                figure(obj.Figure);
                drawnow;
                % Rendering or queued lifecycle callbacks can replace, hide
                % or disable the view while drawnow yields.
                if obj.canReturnFolderFocus() && colormeasure.ui.canFocus(target,obj.Figure)
                    % Classic controls use uicontrol to restore keyboard focus.
                    % https://www.mathworks.com/help/matlab/ref/uicontrol.html
                    uicontrol(target);
                end
                return
            end
        end
        function yes=canReturnFolderFocus(obj)
            yes=isvalid(obj) && isvalid(obj.Session) && isgraphics(obj.Figure) && ...
                isequal(obj.Session.window,obj.Figure) && strcmp(obj.Figure.Visible,'on') && ...
                ~obj.Session.busy && ~obj.Session.finished;
            if yes
                current=colormeasure.ui.currentFigure();
                yes=isempty(current) || isequal(current,obj.Figure);
            end
        end
        function value=preparation(obj)
            value=obj.Session.preparation;
            if ~isstruct(value)||~isscalar(value),value=struct([]);end
        end
        function accepted=confirmPreparation(obj)
            accepted=true; preparation=obj.preparation();
            if obj.PreparationAccepted||isempty(preparation)|| ...
                    ~isfield(preparation,'required')||~isequal(preparation.required,true),return;end
            accepted=isequal(obj.PreparationPrompt(preparation,true),true);
            % This records the operator's choice, not a measured readiness state.
            obj.PreparationAccepted=accepted;
        end
        function instrumentHelp(obj)
            if obj.Session.busy || obj.devicePending(),return;end
            preparation=obj.preparation();
            if isempty(preparation),return;end
            obj.PreparationPrompt(preparation,false);
        end
        function instrumentSettings(obj)
            if obj.Session.busy || obj.devicePending(), return; end
            if isempty(obj.SettingsView) || ~isvalid(obj.SettingsView)
                help = [];
                if ~isempty(obj.preparation()), help = @() obj.instrumentHelp(); end
                obj.SettingsView = colormeasure.ui.SettingsView(obj.Session,help,obj.Fields.InstrumentSettingsButton);
            else
                obj.SettingsView.show();
            end
        end
        function refreshTheme(obj)
            if ~isempty(obj.Results),obj.Results.refreshTheme();end
        end
        function keyPress(obj,event)
            if ~isvalid(obj)||~isgraphics(obj.Figure)||~isvalid(obj.Session),return;end
            [~,modifiers]=colormeasure.ui.measureShortcut();
            if ~strcmp(event.Key,'m')||~isequal(sort(cellstr(string(event.Modifier(:)))),modifiers)||obj.ShortcutHeld,return;end
            % CurrentObject is the last clicked control, not keyboard focus:
            % it can still name an edit field after Tab has committed it.
            if obj.TextDraft
                % Typing must not be turned into a measurement; say so instead
                % of ignoring the key silently.
                set(obj.Fields.CurrentStatus,'String',['Finish editing the field (Tab out of it), then press ' ...
                    colormeasure.ui.measureShortcut() ' to measure.']);
                return
            end
            if ~strcmp(obj.Figure.Visible,'on')||obj.Sidebar.SelectedTab~=obj.MeasureTab|| ...
                    obj.Session.busy||obj.Session.finishing||obj.Session.finished,return;end
            if ~isempty(findall(groot,'Type','figure','WindowStyle','modal','Visible','on')),return;end
            if ~isempty(obj.SettingsView)&&isvalid(obj.SettingsView)&&isgraphics(obj.SettingsView.Figure)&& ...
                    strcmp(obj.SettingsView.Figure.Visible,'on'),return;end
            reason=obj.measureBlockReason();
            if ~isempty(reason),obj.showMeasureBlock(reason);return;end
            if strcmp(get(obj.Fields.MeasureButton,'Enable'),'on')
                obj.ShortcutHeld=true;obj.invoke('measure');
            end
        end
        function showMeasureBlock(obj,reason)
            % Explain an intentional acquisition refusal without changing the
            % session, latching the shortcut or inventing an operation error.
            if ~isvalid(obj)||~isgraphics(obj.Figure)||~isgraphics(obj.Fields.CurrentStatus),return;end
            set(obj.Fields.CurrentStatus,'String',reason, ...
                'TooltipString',[colormeasure.ui.measureShortcut() ' did not measure: ' reason]);
        end
        function resetShortcut(obj)
            obj.ShortcutHeld=false;
        end
        function keyRelease(obj,event)
            if isvalid(obj)&&strcmp(event.Key,'m'),obj.ShortcutHeld=false;end
        end
        function visibilityChanged(obj)
            if ~isgraphics(obj.Figure)||~strcmp(obj.Figure.Visible,'off'),return;end
            obj.closeContinuation();
            if ~isempty(obj.CleanupView)&&isvalid(obj.CleanupView),delete(obj.CleanupView);obj.CleanupView=[];end
            if ~isempty(obj.AnnotationView)&&isvalid(obj.AnnotationView),delete(obj.AnnotationView);end
            if ~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup),delete(obj.ChartSetup);obj.ChartSetup=[];end
            obj.ShortcutHeld=false;
        end
        function hide(obj)
            if ~isempty(obj.SettingsView) && isvalid(obj.SettingsView), delete(obj.SettingsView); end
            obj.Session.hide();
        end
        function value=devicePending(obj)
            value=~isempty(obj.CurrentDevice) && ...
                get(obj.Fields.InstrumentSelector,'Value')~=obj.CurrentDevice;
        end
        function reason=measureBlockReason(obj)
            reason=obj.hostBlockReason();
            if ~isempty(reason),return;end
            s=obj.Session;
            if ~s.busy&&s.chartIoUnconfirmed
                reason='Connection cleanup is unconfirmed. Resolve it before another measurement.';return
            end
            chart=obj.Session.chart;
            if ~isempty(chart)&&~chart.paused
                if chart.unsaved,reason='Chart progress is not saved. Use Retry save before another reading.';
                elseif ~isempty(chart.pendingContext),reason='Review changed settings in Chart before another reading.';
                elseif ~chart.eligible,reason=chart.reason;
                end
            end
        end
        function reason=hostBlockReason(obj)
            reason='';
            if obj.devicePending()
                reason='Select Open to switch instruments, or select the current instrument to continue this batch.';
                return
            end
        end
        function reason=chartBlockReason(obj)
            % ChartView owns chart readiness and the action that resolves a
            % pending context. The host selection guard belongs here.
            reason=obj.hostBlockReason();
        end
        function yes=chartEditable(obj)
            s=obj.Session;chart=s.chart;
            yes=~s.busy&&~s.finishing&&~s.finished&&~obj.devicePending()&& ...
                ~s.chartIoUnconfirmed&&~s.needsRecovery&&isempty(obj.chartBlockReason())&& ...
                (isempty(chart)||~chart.unsaved);
        end
        function toggleChart(obj)
            s=obj.Session;
            if ~obj.chartEditable(),obj.render();return;end
            if ~isempty(s.chart)&&s.chart.paused&&~isempty(s.chart.pendingContext)
                obj.render();return
            end
            try
                if ~isempty(s.chart)&&~s.chart.paused
                    s.pauseChart();
                    obj.ChartWorkspace='plots';
                elseif isempty(s.chart)
                    obj.openChartSetup();
                    return
                else
                    if s.chart.paused,s.resumeChart();end
                    obj.ChartWorkspace='chart';
                end
            catch problem
                s.reportError(problem);
            end
            obj.render();
        end
        function openChartSetup(obj)
            s=obj.Session;
            if s.finished
                if ~s.busy&&~s.needsRecovery&&~s.chartIoUnconfirmed&&~isempty(s.chart)
                    obj.continueChart(s);
                end
                return
            end
            if ~obj.chartEditable(),obj.render();return;end
            if isempty(obj.ChartSetup)||~isvalid(obj.ChartSetup)
                obj.ChartSetup=colormeasure.ui.ChartSetupView(s,obj.Figure,@()obj.chartSetupClosed(), ...
                    @()obj.openSavedChart());
            end
        end
        function openSavedChart(obj)
            if ~isvalid(obj)||~isscalar(obj.Figure)||~isgraphics(obj.Figure),return;end
            s=obj.Session;picker=@uigetfile;io=s.services;
            if isfield(io,'pickChartContinuation'),picker=io.pickChartContinuation;end
            try
                registry=colormeasure.session.sessionRegistry('get');sources={};labels={'Open a saved MAT file…'};
                if ~isempty(s.chart)
                    sources{end+1}=s;
                    labels{end+1}=sprintf('This batch · %s · started %s',s.label,s.startedAtLocal);
                end
                for n=1:numel(registry.sessions)
                    candidate=registry.sessions{n};
                    if ~isvalid(candidate)||isempty(candidate.chart)||candidate==s,continue;end
                    sources{end+1}=candidate; %#ok<AGROW>
                    labels{end+1}=sprintf('%s · started %s',candidate.label,candidate.startedAtLocal); %#ok<AGROW>
                end
                if ~isempty(sources)
                    if isfield(io,'chooseChartContinuationSource')
                        index=io.chooseChartContinuationSource(labels);
                    else
                        [index,accepted]=listdlg('ListString',labels,'SelectionMode','single', ...
                            'Name','Choose a chart to inspect','PromptString', ...
                            'Choose a saved file or another retained batch. No reading is taken.', ...
                            'ListSize',[660 260],'OKString','Inspect','CancelString','Cancel');
                        if ~accepted,index=[];end
                    end
                    if isempty(index),return;end
                    assert(isnumeric(index)&&isscalar(index)&&isfinite(index)&&fix(index)==index&& ...
                        index>=1&&index<=numel(labels),'Measurement:ChartContinuationSource', ...
                        'Choose one saved file or retained chart batch.');
                    if index>1,obj.continueChart(sources{index-1});return;end
                end
                [filename,folder]=picker({'*.mat','Saved measurement batch (*.mat)'}, ...
                    'Open a saved chart for inspection and continuation',s.saveParent);
                if ~isvalid(obj)||~isgraphics(obj.Figure)||isequal(filename,0),return;end
                obj.continueChart(fullfile(folder,filename));
            catch problem
                if isvalid(obj)&&isvalid(s),s.reportError(problem);end
            end
        end
        function confirmChartCleanup(obj)
            if ~isvalid(obj)||obj.Session.busy||~obj.Session.chartIoUnconfirmed|| ...
                    obj.Session.directCleanupCanRetry,return;end
            try
                if ~isempty(obj.CleanupView)&&isvalid(obj.CleanupView),figure(obj.CleanupView.Figure);return;end
                s=obj.Session;
                obj.CleanupView=colormeasure.ui.ChartCleanupView(obj.Figure, ...
                    'The app can no longer reach this batch''s instrument connection, so it cannot confirm that the connection closed.', ...
                    @(text)s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true,Declaration=text),s);
            catch problem
                if isvalid(obj)&&isvalid(obj.Session),obj.Session.reportError(problem);end
            end
        end
        function retryChartCleanup(obj)
            if ~isvalid(obj)||obj.Session.busy||~obj.Session.directCleanupCanRetry,return;end
            try
                obj.Session.retryDirectCleanup();
            catch problem
                if isvalid(obj)&&isvalid(obj.Session),obj.Session.reportError(problem);end
            end
        end
        function continueChart(obj,source)
            if obj.continuationOpen(),return;end
            if ~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup),obj.ChartSetup.Figure.Visible='off';end
            cleanup=onCleanup(@()obj.restoreChartSetup());
            try
                colormeasure.ui.continueChart(obj.Session,source);
            catch problem
                if isvalid(obj)&&isvalid(obj.Session)
                    obj.Session.reportError(problem);
                    if ~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup),obj.ChartSetup.showContinuationError(problem);end
                end
            end
        end
        function restoreChartSetup(obj)
            if ~isvalid(obj)||~isscalar(obj.Figure)||~isgraphics(obj.Figure)||strcmp(obj.Figure.Visible,'off')|| ...
                    obj.Session.finished||obj.Session.finishing,return;end
            if ~isempty(obj.ChartSetup)&&isvalid(obj.ChartSetup)
                obj.ChartSetup.Figure.Visible='on';figure(obj.ChartSetup.Figure);
                target=findobj(obj.ChartSetup.Figure,'Tag','GuidedChartOpenSaved');
                if colormeasure.ui.canFocus(target,obj.ChartSetup.Figure),focus(target);end
            else
                obj.render();
                if ~isempty(obj.ChartView)&&isvalid(obj.ChartView)&& ...
                        colormeasure.ui.canFocus(obj.ChartView.Grid,obj.Figure),focus(obj.ChartView.Grid);end
            end
        end
        function yes=continuationOpen(obj)
            yes=false;
            if ~isscalar(obj.Figure)||~isgraphics(obj.Figure)||~isappdata(obj.Figure,'ChartContinuationPreview'),return;end
            view=getappdata(obj.Figure,'ChartContinuationPreview');
            yes=isa(view,'colormeasure.ui.ChartContinuationView')&&isscalar(view)&&isvalid(view);
        end
        function closeContinuation(obj)
            if obj.continuationOpen()
                view=getappdata(obj.Figure,'ChartContinuationPreview');
                rmappdata(obj.Figure,'ChartContinuationPreview');delete(view);
            end
        end
        function chartSetupClosed(obj)
            if ~isvalid(obj)||~isgraphics(obj.Figure),return;end
            obj.ChartSetup=[];obj.render();
            target=obj.Fields.ChartButton;
            if ~isempty(obj.Session.chart)&&~obj.Session.chart.paused,target=obj.ChartView.Grid;end
            if colormeasure.ui.canFocus(target,obj.Figure),focus(target);end
        end
        function selectWorkspace(obj)
            choices={'chart','plots'};obj.ChartWorkspace=choices{get(obj.Fields.ChartWorkspaceSelector,'Value')};
            obj.resize();
        end
        function selectTab(obj,tab)
            obj.Results.showContext(tab);obj.resize();
        end
        function stageInstrument(obj)
            if isempty(obj.CurrentDevice), return; end
            if obj.Session.busy || (obj.Session.finishing && ~obj.Session.finished)
                set(obj.Fields.InstrumentSelector,'Value',obj.CurrentDevice);
            end
            if obj.devicePending() && ~isempty(obj.SettingsView) && isvalid(obj.SettingsView) && isgraphics(obj.SettingsView.Figure)
                set(obj.SettingsView.Figure,'Visible','off');
            end
            obj.render();
        end
        function openInstrument(obj)
            if isempty(obj.CurrentDevice) || obj.Session.busy || ...
                    (obj.Session.finishing && ~obj.Session.finished) || ~obj.devicePending()
                return
            end
            selected=get(obj.Fields.InstrumentSelector,'Value');
            position=get(obj.Figure,'Position');
            windowState=get(obj.Figure,'WindowState');
            try
                target=obj.DeviceOpener(obj.Session,obj.DeviceCatalog(selected).model);
                set(obj.Fields.InstrumentSelector,'Value',obj.CurrentDevice);
                obj.render();
                if isempty(target), return; end
                if ~isa(target,'colormeasure.session.Session') || ~isscalar(target) || ~isvalid(target) || ...
                        ~isgraphics(target.window) || ~strcmp(get(target.window,'Visible'),'on')
                    error('Measurement:DeviceWindow','The selected instrument window could not be opened.');
                end
                if target==obj.Session, return; end
                if strcmp(windowState,'maximized')
                    set(target.window,'WindowState','maximized');
                else
                    set(target.window,'WindowState','normal','Position',position);
                end
                % Preserve source drafts, view selections and preparation state.
                if ~isempty(obj.SettingsView) && isvalid(obj.SettingsView) && isgraphics(obj.SettingsView.Figure)
                    set(obj.SettingsView.Figure,'Visible','off');
                end
                obj.Session.hide();
                figure(target.window);
            catch err
                if isvalid(obj) && isvalid(obj.Session)
                    set(obj.Fields.InstrumentSelector,'Value',obj.CurrentDevice);
                    obj.Session.reportError(err);
                end
            end
        end
        function viewError(obj,err)
            if isgraphics(obj.Figure)
                set(obj.Fields.CurrentStatus,'String',['Display unavailable: ' err.message]);
            end
            if ~strcmp(obj.LastViewError,err.message)
                obj.LastViewError=err.message;
                warning('Measurement:Display','Display update: %s. Session data is retained.',err.message);
            end
        end
    end
end
function accepted=showPreparation(preparation,confirm,onKeyRelease,owner)
position=colormeasure.ui.dialogPosition(owner,[520 520]);
dialog=uifigure('Name',preparation.title,'Position',position, ...
    'WindowStyle','modal','Tag','PreparationDialog','Visible','off');
% The cleanup owner has no nested callbacks: otherwise the live dialog can
% retain its workspace and defer cleanup after the response has returned.
cleanup=onCleanup(@() deletePreparationDialog(dialog));
accepted=runPreparationDialog(dialog,preparation,confirm,onKeyRelease);
end
function accepted=runPreparationDialog(dialog,preparation,confirm,onKeyRelease)
accepted=false;
completed=false;
dialog.CloseRequestFcn=@(~,~)dismiss(false);
dialog.WindowKeyReleaseFcn=@(~,event)onKeyRelease(event);
dialog.WindowKeyPressFcn=@(~,event)cancelKey(event);
layout=uigridlayout(dialog,[3 3],'ColumnWidth',{'1x','1x','1x'}, ...
    'RowHeight',{'fit','1x',32},'Padding',[16 16 16 16], ...
    'RowSpacing',12,'ColumnSpacing',8);
summary=uilabel(layout,'Text',preparation.summary,'WordWrap','on', ...
    'FontSize',13,'Tag','PreparationSummary');
summary.Layout.Row=1;summary.Layout.Column=[1 3];
paragraphs={};headings={};
if isfield(preparation,'details')&&~isempty(preparation.details)
    paragraphs=cellstr(string(preparation.details(:)));
end
if isfield(preparation,'headings'),headings=preparation.headings;end
[html,lines]=colormeasure.ui.helpHtml(preparation.title,paragraphs,headings,dialog.Theme.BaseColorStyle);
details=colormeasure.ui.createHelpPane(layout,'PreparationDetails');
if isa(details,'matlab.ui.control.HTML')
    colormeasure.ui.setDialogHelp(details,html,@()dismiss(false));
else
    details.Value=lines;
end
details.Layout.Row=2;details.Layout.Column=[1 3];
dialog.ThemeChangedFcn=@(~,~) refreshHelp();
manual=uibutton(layout,'Text','Open manual','Tag','PreparationManual', ...
    'ButtonPushedFcn',@(~,~) web(preparation.url,'-browser'));
manual.Layout.Row=3;manual.Layout.Column=1;
if ~isfield(preparation,'url')||isempty(preparation.url),manual.Enable='off';end
cancel=uibutton(layout,'Text','Cancel','Tag','PreparationCancel', ...
    'ButtonPushedFcn',@(~,~) dismiss(false));
cancel.Layout.Row=3;cancel.Layout.Column=2;
if confirm
    ready=uibutton(layout,'Text','Ready','Tag','PreparationReady', ...
        'ButtonPushedFcn',@(~,~) dismiss(true));
    ready.Layout.Row=3;ready.Layout.Column=3;
else
    cancel.Text='Close';cancel.Layout.Column=[2 3];
end
dialog.Visible='on';drawnow nocallbacks;
% Showing or focusing can dispatch a response before uiwait starts. Keep the
% controls alive until this function returns, and retain the first response.
if completed||~isgraphics(dialog),return;end
focus(cancel);
if ~completed&&isgraphics(dialog),uiwait(dialog);end
    function cancelKey(event)
        if colormeasure.ui.isCloseKey(event)
            dismiss(false);
        end
    end
    function refreshHelp()
        if ~isgraphics(details)||~isa(details,'matlab.ui.control.HTML'),return;end
        markup=colormeasure.ui.helpHtml(preparation.title,paragraphs,headings,dialog.Theme.BaseColorStyle);
        colormeasure.ui.setDialogHelp(details,markup,@()dismiss(false));
    end
    function dismiss(ready)
        if completed,return;end
        accepted=ready;
        completed=true;
        if isgraphics(dialog),uiresume(dialog);end
    end
end
function deletePreparationDialog(dialog)
if isgraphics(dialog),delete(dialog);end
end

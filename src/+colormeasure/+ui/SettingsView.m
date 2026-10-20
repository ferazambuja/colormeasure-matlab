classdef SettingsView < handle
    % SETTINGSVIEW Optional instrument overrides, staged without device I/O.
    % Family catalogs own settings, limits and help. The native driver validates
    % the complete request on each connection before sending settings commands.
    % Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = private)
        Figure
    end
    properties (Access = private)
        Session
        Listener
        Fields = struct()
        Draft = struct()
        NumberText = struct()
        NumberMode = struct()
        Baseline = struct()
        DraftConflict = false
        Controls = struct([])
        SelectedId = ''
        Rendering = false
        Owner=[]
        HelpAction
        ConstructionComplete = false
        ContentGrid
    end
    methods
        function obj = SettingsView(session, helpAction, owner)
            if nargin<3,owner=[];end
            obj.Owner=owner;
            obj.Session = session;
            obj.Draft = session.settingsOverrides;
            obj.Baseline = obj.Draft;
            if nargin < 2, helpAction = []; end
            obj.HelpAction = helpAction;
            obj.Figure = uifigure('Name','Measurement settings', ...
                'Position',colormeasure.ui.dialogPosition(owner,[720 690]),'Visible','off', ...
                'Tag','InstrumentSettingsWindow','Interruptible','off', ...
                'AutoResizeChildren','off', ...
                'BusyAction','cancel','CloseRequestFcn',@(~,~) obj.closeRequested(), ...
                'WindowKeyPressFcn',@(~,event)obj.keyPress(event));
            cleanup = onCleanup(@() obj.cleanupPartial());
            outer = uigridlayout(obj.Figure,[3 1], ...
                'RowHeight',{'1x',30,40},'Padding',[16 12 16 12],'RowSpacing',8);
            grid = uigridlayout(outer,[6 1], ...
                'RowHeight',{64,32,120,72,152,48}, ...
                'Padding',0,'RowSpacing',8,'Scrollable','on');
            obj.ContentGrid=grid;
            obj.Figure.SizeChangedFcn=@(~,~)obj.resizeContent();
            uilabel(grid,'Text',['Measure uses the model''s automatic acquisition settings. ' ...
                'Optional overrides are sent when Measure starts. Accessory and calibration ' ...
                'selections are retained unless explicitly changed.'], ...
                'WordWrap','on','Tag','SettingsIntroduction');
            toolbar = uigridlayout(grid,[1 3],'ColumnWidth',{160,'1x',130}, ...
                'Padding',0);
            obj.Fields.Read = uibutton(toolbar,'Text','Read settings', ...
                'Tag','ReadInstrumentSettings','ButtonPushedFcn',@(~,~) obj.readSettings(), ...
                'Tooltip','Connect, read the instrument configuration and release the port. No measurement.');
            obj.Fields.Observation = uilabel(toolbar,'Text','Not read from instrument', ...
                'Tag','SettingsObservation','WordWrap','on');
            obj.Fields.Help = uibutton(toolbar,'Text','Instrument help', ...
                'Tag','SettingsInstrumentHelp','ButtonPushedFcn',@(~,~) obj.showHelp());
            if isempty(helpAction)
                obj.Fields.Help.Visible = 'off';
                toolbar.ColumnWidth = {160,'1x',0};
            end
            obj.Fields.Table = uitable(grid,'Tag','InstrumentSettingsTable', ...
                'ColumnName',{'Setting','Last read','Override'},'RowName',{}, ...
                'ColumnEditable',[false false false], ...
                'ColumnWidth',{'auto','auto','auto'}, ...
                'CellSelectionCallback',@(~,event) obj.selectRow(event));
            editor = uigridlayout(grid,[2 3],'ColumnWidth',{200,140,'1x'}, ...
                'RowHeight',{28,28},'Padding',0,'RowSpacing',4);
            obj.Fields.Override = uicheckbox(editor,'Text','Override this setting', ...
                'Tag','SettingsOverride','ValueChangedFcn',@(~,~) obj.toggleOverride());
            obj.Fields.Choice = uidropdown(editor,'Items',{'Not available'}, ...
                'Tag','SettingsChoice','ValueChangedFcn',@(~,~) obj.changeValue());
            obj.Fields.Choice.Layout.Row = 1; obj.Fields.Choice.Layout.Column = [2 3];
            obj.Fields.NumberMode = uidropdown(editor,'Items',{'Choose a mode'}, ...
                'ItemsData',0,'Value',0,'Visible','off','Tag','SettingsNumberMode', ...
                'ValueChangedFcn',@(~,~)obj.changeNumberMode());
            obj.Fields.NumberMode.Layout.Row=1;obj.Fields.NumberMode.Layout.Column=2;
            % Creation order is keyboard order: choose the value mode,
            % then enter its value. Hidden editors are skipped by MATLAB.
            obj.Fields.Number = uieditfield(editor,'text','Tag','SettingsNumber', ...
                'Placeholder','Enter a value', ...
                'ValueChangedFcn',@(~,~) obj.changeValue());
            obj.Fields.Number.Layout.Row = 1; obj.Fields.Number.Layout.Column = [2 3];
            obj.Fields.Availability = uilabel(editor,'Text','','WordWrap','on', ...
                'Tag','SettingsAvailability');
            obj.Fields.Availability.Layout.Row = 2;
            obj.Fields.Availability.Layout.Column = [1 3];
            obj.Fields.Details=colormeasure.ui.createHelpPane(grid,'SettingsExplanation');
            obj.Figure.ThemeChangedFcn = @(~,~) obj.renderHelp();
            uilabel(grid,'Text',['After clearing overrides, select Use for next readings to restore automatic settings on the next reading. ' ...
                'Other settings, including accessories and corrections, remain on the instrument.'], ...
                'WordWrap','on','Tag','SettingsClearExplanation');
            buttons = uigridlayout(outer,[1 3],'ColumnWidth',{150,'1x',190},'Padding',0);
            obj.Fields.Cancel = uibutton(buttons,'Text','Cancel', ...
                'Tag','CancelInstrumentSettings','ButtonPushedFcn',@(~,~) obj.closeRequested());
            obj.Fields.Clear = uibutton(buttons,'Text','Clear overrides', ...
                'Tag','ClearInstrumentOverrides','ButtonPushedFcn',@(~,~) obj.clearDraft());
            obj.Fields.Use = uibutton(buttons,'Text','Use for next readings','FontWeight','bold', ...
                'Tag','UseInstrumentSettings','ButtonPushedFcn',@(~,~) obj.useDraft());
            obj.Fields.Message = uilabel(outer,'Text','','Tag','SettingsMessage', ...
                'WordWrap','on');
            obj.Listener = addlistener(session,'Changed',@(~,~) obj.render());
            obj.render();
            obj.resizeContent();
            obj.Figure.Visible = get(groot,'DefaultFigureVisible');
            obj.ConstructionComplete = true;
            clear cleanup
        end

        function show(obj)
            if isgraphics(obj.Figure)
                obj.Figure.Visible = 'on';
                figure(obj.Figure);
            end
        end

        function delete(obj)
            if ~isempty(obj.Listener), delete(obj.Listener); end
            if isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn = [];
                delete(obj.Figure);
            end
        end
    end
    methods (Access = private)
        function resizeContent(obj)
            if isempty(obj.ContentGrid)||~isgraphics(obj.ContentGrid),return;end
            heights=obj.ContentGrid.RowHeight;
            % Keep several settings rows available. Short windows scroll the
            % optional content; commit/cancel and validation stay outside it.
            heights{3}=max(120,obj.Figure.Position(4)-518);
            obj.ContentGrid.RowHeight=heights;
        end
        function keyPress(obj,event)
            if colormeasure.ui.isCloseKey(event)
                obj.closeRequested();
            end
        end
        function closeRequested(obj)
            owner=obj.Owner;delete(obj);
            if ~isempty(owner)&&isgraphics(owner)
                fig=ancestor(owner,'figure');
                if colormeasure.ui.canFocus(owner,fig)
                    figure(fig);uicontrol(owner);
                end
            end
        end
        function cleanupPartial(obj)
            if isvalid(obj) && ~obj.ConstructionComplete, delete(obj); end
        end

        function render(obj)
            if obj.Rendering || ~isvalid(obj.Session) || ~isgraphics(obj.Figure), return; end
            obj.Rendering = true;
            cleanup = onCleanup(@() obj.endRender());
            obj.Controls = obj.Session.settingsCatalog;
            committed = obj.Session.settingsOverrides;
            obj.DraftConflict = false;
            if ~isequaln(committed,obj.Baseline)
                if isequaln(obj.Draft,obj.Baseline) || isequaln(obj.Draft,committed)
                    obj.Draft = committed;
                    obj.NumberText = struct();obj.NumberMode=struct();
                    obj.Baseline = committed;
                else
                    obj.DraftConflict = true;
                    obj.Fields.Message.Text = 'Overrides changed in MATLAB. Reload overrides or cancel to keep those changes.';
                end
            end
            controls = obj.Controls;
            data = cell(numel(controls),3);
            snapshot = obj.Session.settingsSnapshot;
            for row = 1:numel(controls)
                control = controls(row);
                data{row,1} = control.label;
                data{row,2} = 'Not read';
                if isstruct(snapshot) && isscalar(snapshot) && isfield(snapshot,'values') && ...
                        isfield(snapshot.values,control.id)
                    data{row,2} = displayValue(control,snapshot.values.(control.id));
                    [~,contextName]=colormeasure.session.settingsControlForValues(control,snapshot.values,false);
                    if ~isempty(contextName),data{row,2}=sprintf('%s (%s)',data{row,2},contextName);end
                end
                data{row,3} = '';
                if isfield(obj.Draft,control.id)
                    data{row,3} = displayValue(control,obj.Draft.(control.id),true);
                    if hasEditor(control,'automaticNumber')&&isfield(obj.NumberMode,control.id)&& ...
                            obj.NumberMode.(control.id)==2&&isfinite(obj.Draft.(control.id))&&isreal(obj.Draft.(control.id))
                        data{row,3}=sprintf('%s: %.15g %s',control.editor.fixedLabel,obj.Draft.(control.id),control.editor.unit);
                    end
                end
            end
            obj.Fields.Table.Data = data;
            if isempty(controls)
                obj.SelectedId = '';
            elseif isempty(obj.SelectedId) || ~any(strcmp({controls.id},obj.SelectedId))
                obj.SelectedId = controls(1).id;
            end
            editable = ~obj.Session.busy && ~obj.Session.finishing && ~obj.Session.finished;
            obj.Fields.Read.Enable = colormeasure.ui.onOff(editable && ~isempty(obj.Session.port)&&~obj.Session.chartIoUnconfirmed);
            obj.Fields.Read.Tooltip='Connect, read the instrument configuration and release the port. No measurement.';
            if obj.Session.chartIoUnconfirmed
                obj.Fields.Read.Tooltip='Resolve the unconfirmed connection cleanup in the main window before reading settings.';
            end
            obj.Fields.Use.Enable = colormeasure.ui.onOff(editable && ~obj.DraftConflict);
            obj.Fields.Clear.Enable = colormeasure.ui.onOff(editable);
            obj.Fields.Clear.Text = 'Clear overrides';
            obj.Fields.Clear.Tooltip = 'Clear this draft. No commands are sent.';
            if obj.DraftConflict
                obj.Fields.Clear.Text = 'Reload overrides';
                obj.Fields.Clear.Tooltip = 'Discard this draft and load the session overrides. No commands are sent.';
            end
            obj.Fields.Cancel.Enable = colormeasure.ui.onOff(~obj.Session.busy);
            observation = 'Not read from instrument';
            if isstruct(snapshot) && isscalar(snapshot) && isfield(snapshot,'readAtUTC')
                observation = ['Last read: ' colormeasure.session.displayTime(snapshot.readAtUTC)];
                identity = identityText(snapshot);
                if ~isempty(identity), observation = [identity ' | ' observation]; end
            end
            obj.Fields.Observation.Text = observation;
            obj.Fields.Observation.Tooltip = [observation ' | Port: ' obj.Session.port];
            obj.renderEditor(editable);
        end

        function endRender(obj)
            if isvalid(obj), obj.Rendering = false; end
        end

        function renderEditor(obj,editable)
            index = [];
            if ~isempty(obj.Controls), index = find(strcmp({obj.Controls.id},obj.SelectedId),1); end
            hasControl = ~isempty(index);
            obj.Fields.Override.Enable = colormeasure.ui.onOff(editable && hasControl);
            obj.Fields.Number.Visible = 'off'; obj.Fields.Choice.Visible = 'off';obj.Fields.NumberMode.Visible='off';
            obj.Fields.Number.Layout.Column=[2 3];
            if ~hasControl
                obj.Fields.Override.Value = false;
                obj.Fields.Availability.Text = 'Settings are unavailable for this adapter.';
                obj.renderHelp();
                return
            end
            control = colormeasure.session.settingsControlForValues(obj.Controls(index),obj.Draft);
            active = isfield(obj.Draft,control.id);
            obj.Fields.Override.Value = active;
            obj.Fields.Override.Enable = colormeasure.ui.onOff(editable && (control.available || active));
            obj.Fields.Availability.Text = '';
            if ~control.available
                obj.Fields.Availability.Text = 'No override is available for this setting.';
                if hasEditor(control,'dependentNumber'),obj.Fields.Availability.Text=control.help.meaning;end
                if isempty(obj.Session.settingsSnapshot)
                    obj.Fields.Availability.Text = [obj.Fields.Availability.Text ...
                        ' Read settings to check the connected instrument.'];
                end
            end
            if control.available && strcmp(control.type,'number') && ...
                    isfinite(control.minimum) && isfinite(control.maximum)
                obj.Fields.Availability.Text = sprintf('Bounds: %.15g to %.15g. See the setting constraints below.',control.minimum,control.maximum);
            end
            obj.Fields.Override.Tooltip = control.label;
            value = [];
            if active, value = obj.Draft.(control.id); end
            snapshot = obj.Session.settingsSnapshot;
            if ~active && isstruct(snapshot) && isscalar(snapshot) && ...
                    isfield(snapshot,'values') && isfield(snapshot.values,control.id)
                value = snapshot.values.(control.id);
            end
            if hasEditor(control,'automaticNumber')
                mode=0;
                if active&&isfield(obj.NumberMode,control.id)
                    mode=obj.NumberMode.(control.id);
                elseif isnumeric(value)&&isscalar(value)&&isreal(value)&&isfinite(value)
                    mode=2;if isequal(value,control.editor.automaticValue),mode=1;end
                end
                obj.Fields.NumberMode.ItemsData=[];
                obj.Fields.NumberMode.Items={'Choose a mode',control.editor.automaticLabel,control.editor.fixedLabel};
                obj.Fields.NumberMode.ItemsData=0:2;
                obj.Fields.NumberMode.Value=mode;obj.Fields.NumberMode.Visible='on';
                obj.Fields.NumberMode.Enable=colormeasure.ui.onOff(editable&&active&&control.available);
                obj.Fields.Number.Layout.Column=3;
                obj.Fields.Number.Placeholder=['Value (' control.editor.unit ')'];
                obj.Fields.Number.Value='';
                if mode==2
                    if isnumeric(value)&&isscalar(value)&&isfinite(value)&&isreal(value)
                        obj.Fields.Number.Value=sprintf('%.15g',value);
                    end
                    if active&&isfield(obj.NumberText,control.id),obj.Fields.Number.Value=obj.NumberText.(control.id);end
                    obj.Fields.Number.Visible='on';
                    obj.Fields.Number.Enable=colormeasure.ui.onOff(editable&&active&&control.available);
                end
                precision='Use a period for decimals, without commas.';
                if isfield(control.editor,'integer')&&control.editor.integer
                    precision='Enter whole numbers, without separators.';
                end
                obj.Fields.Availability.Text=sprintf('%s uses an automatic value. %s: %g to %g %s. %s', ...
                    control.editor.automaticLabel,control.editor.fixedLabel,control.editor.fixedMinimum, ...
                    control.maximum,control.editor.unit,precision);
                if active&&mode==0
                    obj.Fields.Availability.Text=sprintf('Choose %s or %s to complete this override.', ...
                        control.editor.automaticLabel,control.editor.fixedLabel);
                end
            elseif strcmp(control.type,'choice') && ~isempty(control.choices)
                labels = choiceLabels(control.choices);
                selected = colormeasure.session.settingsChoiceIndex(control.choices,value);
                if isempty(selected), selected = 0; end
                % Editor index zero is the placeholder. Real values, including
                % wire zero, are looked up without relying on unique labels.
                obj.Fields.Choice.ItemsData = [];
                obj.Fields.Choice.Items = [{'Choose a value'} labels];
                obj.Fields.Choice.ItemsData = 0:numel(control.choices);
                obj.Fields.Choice.Value = selected;
                obj.Fields.Choice.Visible = 'on';
                obj.Fields.Choice.Enable = colormeasure.ui.onOff(editable && active && control.available);
                if active && selected == 0 && control.available
                    obj.Fields.Availability.Text = 'Choose a value to complete this override, or clear its checkbox.';
                end
            else
                text = '';
                if isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value), text = sprintf('%.15g',value); end
                if active&&isfield(obj.NumberText,control.id)
                    text=obj.NumberText.(control.id);
                    if ~isreal(value)||~isfinite(value)
                        obj.Fields.Availability.Text=['Enter a finite real number using a period for decimals, without commas. ' ...
                            'Your entry is kept so you can correct it.'];
                    end
                end
                obj.Fields.Number.Placeholder='Enter a value';
                obj.Fields.Number.Value = text;
                obj.Fields.Number.Visible = 'on';
                obj.Fields.Number.Enable = colormeasure.ui.onOff(editable && active && control.available);
            end
            obj.renderHelp();
        end

        function renderHelp(obj)
            if ~isgraphics(obj.Figure) || ~isfield(obj.Fields,'Details'), return; end
            index = [];
            if ~isempty(obj.Controls), index = find(strcmp({obj.Controls.id},obj.SelectedId),1); end
            title = 'Instrument settings';
            paragraphs = {'Settings are unavailable for this adapter.'};
            headings = {};
            if ~isempty(index)
                control = colormeasure.session.settingsControlForValues(obj.Controls(index),obj.Draft); help = control.help;
                title = control.label;
                paragraphs = {help.meaning; help.whenToUse; help.tradeoff; help.normal; ...
                    cellstr(string(help.source))};
                headings = {'';'When to use';'Tradeoff';'Normal operation';'Sources'};
            end
            [html,plain] = colormeasure.ui.helpHtml(title,paragraphs,headings, ...
                obj.Figure.Theme.BaseColorStyle);
            if isa(obj.Fields.Details,'matlab.ui.control.HTML')
                % Assigning HTMLSource reloads the document. Retain scroll and text
                % selection when other session state or settings values change.
                colormeasure.ui.setDialogHelp(obj.Fields.Details,html,@()obj.closeRequested());
            elseif ~isequal(obj.Fields.Details.Value,plain)
                obj.Fields.Details.Value = plain;
            end
        end

        function selectRow(obj,event)
            if isempty(event.Indices), return; end
            index = event.Indices(1,1);
            if index >= 1 && index <= numel(obj.Controls)
                obj.SelectedId = obj.Controls(index).id;
                obj.render();
            end
        end

        function toggleOverride(obj)
            if obj.Session.busy || obj.Session.finished || obj.Session.finishing, return; end
            if obj.Fields.Override.Value
                obj.changeValue();
            elseif isfield(obj.Draft,obj.SelectedId)
                obj.Draft = rmfield(obj.Draft,obj.SelectedId);
                if isfield(obj.NumberText,obj.SelectedId),obj.NumberText=rmfield(obj.NumberText,obj.SelectedId);end
                if isfield(obj.NumberMode,obj.SelectedId),obj.NumberMode=rmfield(obj.NumberMode,obj.SelectedId);end
            end
            obj.render();
        end

        function changeValue(obj)
            if obj.Rendering || obj.Session.busy || obj.Session.finished || obj.Session.finishing, return; end
            index = find(strcmp({obj.Controls.id},obj.SelectedId),1);
            if isempty(index) || ~obj.Controls(index).available || ~obj.Fields.Override.Value, return; end
            control = colormeasure.session.settingsControlForValues(obj.Controls(index),obj.Draft);
            if ~control.available,return;end
            if hasEditor(control,'automaticNumber')
                mode=obj.Fields.NumberMode.Value;obj.NumberMode.(control.id)=mode;
                if mode==1
                    obj.Draft.(control.id)=control.editor.automaticValue;
                    if isfield(obj.NumberText,control.id),obj.NumberText=rmfield(obj.NumberText,control.id);end
                else
                    obj.NumberText.(control.id)=obj.Fields.Number.Value;
                    obj.Draft.(control.id)=colormeasure.ui.parseNumber(obj.Fields.Number.Value);
                end
            elseif strcmp(control.type,'choice')
                choice = obj.Fields.Choice.Value;
                if choice == 0
                    obj.Draft.(control.id) = []; % Incomplete draft; cannot be applied.
                else
                    obj.Draft.(control.id) = control.choices(choice).value;
                end
            else
                obj.NumberText.(control.id) = obj.Fields.Number.Value;
                obj.Draft.(control.id) = colormeasure.ui.parseNumber(obj.Fields.Number.Value);
            end
            obj.Fields.Message.Text = 'Draft only. Use for next readings to keep these overrides.';
            obj.render();
        end

        function changeNumberMode(obj)
            if obj.Rendering||obj.Session.busy||obj.Session.finished||obj.Session.finishing,return;end
            if ~obj.Fields.Override.Value,return;end
            index=find(strcmp({obj.Controls.id},obj.SelectedId),1);
            if isempty(index)||~hasEditor(obj.Controls(index),'automaticNumber')||~obj.Controls(index).available,return;end
            % The explicit-value mode starts with an empty value rather than
            % a guessed minimum or a stale value from the previous selection.
            obj.Fields.Number.Value='';obj.changeValue();
        end

        function clearDraft(obj)
            if obj.Session.busy || obj.Session.finished || obj.Session.finishing, return; end
            obj.NumberText=struct();obj.NumberMode=struct();
            if obj.DraftConflict
                obj.Draft = obj.Session.settingsOverrides;
                obj.Baseline = obj.Draft;
                obj.Fields.Message.Text = 'Session overrides loaded. Instrument settings have not changed.';
                obj.render();
                return
            end
            obj.Draft = struct();
            obj.Fields.Message.Text = 'Overrides cleared in this draft. Select Use for next readings to apply.';
            obj.render();
        end

        function readSettings(obj)
            if obj.Session.busy || obj.Session.finished || obj.Session.finishing||obj.Session.chartIoUnconfirmed, return; end
            try
                success = obj.Session.refreshInstrumentSettings();
                if ~isvalid(obj) || ~isgraphics(obj.Figure), return; end
                if success
                    obj.Fields.Message.Text = 'Instrument settings read. No measurement was taken.';
                else
                    obj.Fields.Message.Text = 'Settings could not be read. See the session log.';
                end
            catch problem
                if ~isvalid(obj) || ~isgraphics(obj.Figure), return; end
                obj.Fields.Message.Text = problem.message;
            end
            obj.render();
        end

        function useDraft(obj)
            if obj.Session.busy || obj.Session.finished || obj.Session.finishing, return; end
            obj.render();
            if obj.DraftConflict, return; end
            try
                for control = reshape(obj.Controls,1,[])
                    if hasEditor(control,'automaticNumber')&&isfield(obj.Draft,control.id)&& ...
                            isfield(obj.NumberMode,control.id)&&obj.NumberMode.(control.id)==0
                        obj.SelectedId=control.id;obj.render();
                        if strcmp(obj.Figure.Visible,'on'),focus(obj.Fields.NumberMode);end
                        error('Measurement:SettingValue','Choose %s or %s before using this override.', ...
                            control.editor.automaticLabel,control.editor.fixedLabel);
                    end
                    if hasEditor(control,'automaticNumber')&&isfield(obj.Draft,control.id)&& ...
                            isfield(obj.NumberMode,control.id)&&obj.NumberMode.(control.id)==2&& ...
                            isreal(obj.Draft.(control.id))&&obj.Draft.(control.id)<control.editor.fixedMinimum
                        obj.SelectedId=control.id;obj.render();
                        if strcmp(obj.Figure.Visible,'on'),focus(obj.Fields.Number);end
                        error('Measurement:SettingValue','%s requires at least %g %s. Choose %s for an automatic value.', ...
                            control.editor.fixedLabel,control.editor.fixedMinimum,control.editor.unit,control.editor.automaticLabel);
                    end
                    if strcmp(control.type,'choice') && isfield(obj.Draft,control.id) && ...
                            isempty(colormeasure.session.settingsChoiceIndex(control.choices,obj.Draft.(control.id)))
                        obj.SelectedId=control.id;obj.render();
                        if strcmp(obj.Figure.Visible,'on'),focus(obj.Fields.Choice);end
                        error('Measurement:SettingValue','Choose a value for %s before using these overrides.',control.label);
                    end
                end
                for name=reshape(fieldnames(obj.NumberText),1,[])
                    value=obj.Draft.(name{1});
                    if ~isreal(value)||~isfinite(value)
                        obj.SelectedId=name{1};obj.render();
                        if strcmp(obj.Figure.Visible,'on'),focus(obj.Fields.Number);end
                        error('Measurement:SettingValue', ...
                            'Enter a finite real number for the selected setting. Use a period for decimals, without commas.');
                    end
                end
                obj.Session.setInstrumentSettings(obj.Draft);
                if isvalid(obj), obj.closeRequested(); end
            catch problem
                if ~isvalid(obj) || ~isgraphics(obj.Figure), return; end
                obj.Fields.Message.Text = problem.message;
            end
        end

        function showHelp(obj)
            if ~obj.Session.busy && ~isempty(obj.HelpAction), obj.HelpAction(); end
        end
    end
end

function value = displayValue(control,raw,isDraft)
if nargin < 3, isDraft = false; end
if isempty(raw) || (isnumeric(raw) && isscalar(raw) && ~isfinite(raw)) || ...
        (isstring(raw) && any(ismissing(raw)))
    value = 'Unavailable';
    if isDraft
        value = 'Enter a value';
        if strcmp(control.type,'choice'), value = 'Choose a value'; end
    end
    return
end
value = char(strjoin(string(raw),', '));
if hasEditor(control,'automaticNumber')&&isnumeric(raw)&&isscalar(raw)
    if isequal(raw,control.editor.automaticValue),value=control.editor.automaticLabel;
    else,value=sprintf('%s: %s %s',control.editor.fixedLabel,value,control.editor.unit);end
end
if strcmp(control.type,'choice') && ~isempty(control.choices)
    index = colormeasure.session.settingsChoiceIndex(control.choices,raw);
    if ~isempty(index)
        labels = choiceLabels(control.choices);value = labels{index};
    elseif ~isDraft
        value = ['Unknown (' value ')'];
    end
end
end

function labels = choiceLabels(choices)
names = {choices.label};labels = names;
for k = 1:numel(choices)
    if nnz(strcmp(names,names{k}))>1
        labels{k}=sprintf('%s (ID %s)',names{k},char(string(choices(k).value)));
    end
end
end

function value = identityText(report)
value = '';
if ~isfield(report,'identity') || ~isstruct(report.identity) || ~isscalar(report.identity), return; end
identity = report.identity;
for name = {'model','deviceType','serialNumber'}
    if isfield(identity,name{1})
        entry = identity.(name{1});
        if (ischar(entry) && isrow(entry)) || (isstring(entry) && isscalar(entry) && ~ismissing(entry))
            value = strtrim([value ' ' char(entry)]);
        end
    end
end
end

function yes=hasEditor(control,kind)
yes=isfield(control,'editor')&&isfield(control.editor,'kind')&&strcmp(control.editor.kind,kind);
end

classdef ChartSetupView < handle
    % CHARTSETUPVIEW A cancellable chart-definition draft; no acquisition.
    properties (SetAccess=private)
        Figure
    end
    properties (Access=private)
        Session
        Owner
        Fields
        Closed
        Constructed=false
        CustomDraft=struct('Name','Custom chart','Rows','4','Columns','6')
        PreviousPreset=''
        OpenSaved = []
    end
    methods
        function obj=ChartSetupView(session,owner,closed,openSaved)
            obj.Session=session;obj.Owner=owner;obj.Closed=closed;
            if nargin>=4,obj.OpenSaved=openSaved;end
            obj.Figure=uifigure('Name','Set up guided chart','Visible','off', ...
                'Tag','GuidedChartSetup','WindowStyle','modal', ...
                'Position',colormeasure.ui.dialogPosition(owner,[620 530]), ...
                'CloseRequestFcn',@(~,~)obj.close(), ...
                'WindowKeyPressFcn',@(~,event)obj.keyPress(event));
            cleanup=onCleanup(@()obj.cleanupPartial());
            obj.Figure.Theme=owner.Theme;
            root=uigridlayout(obj.Figure,[3 1],'RowHeight',{'1x',48,32}, ...
                'Padding',[16 16 16 16],'RowSpacing',10);
            obj.Fields.Draft=uipanel(root,'BorderType','none','Tag','GuidedChartDraft');obj.Fields.Draft.Layout.Row=1;
            grid=uigridlayout(obj.Fields.Draft,[7 2], ...
                'ColumnWidth',{118,'1x'},'RowHeight',{52,32,32,32,32,32,52}, ...
                'Padding',0,'RowSpacing',10);
            help=uilabel(grid,'Text', ...
                ['Choose the physical chart or enter a custom grid. Coordinates identify where ' ...
                'you intend to measure; the app cannot detect which patch is under the instrument.'], ...
                'WordWrap','on','FontSize',13);help.Layout.Column=[1 2];
            label=uilabel(grid,'Text','Chart','FontSize',13);label.Layout.Row=2;
            obj.Fields.Preset=uidropdown(grid, ...
                'Items',{'ColorChecker Classic · 4 × 6','ColorChecker Digital SG · 10 × 14','Custom grid'}, ...
                'ItemsData',{'classic','sg','custom'},'Tag','GuidedChartPreset','FontSize',13, ...
                'ValueChangedFcn',@(~,~)obj.refresh());obj.Fields.Preset.Layout.Row=2;obj.Fields.Preset.Layout.Column=2;
            for pair={'Name','Chart name';'Rows','Rows';'Columns','Columns'}.'
                name=pair{1};label=uilabel(grid,'Text',pair{2},'FontSize',13);
                row=3+find(strcmp({'Name','Rows','Columns'},name),1)-1;
                label.Layout.Row=row;label.Layout.Column=1;obj.Fields.([name 'Label'])=label;
                obj.Fields.(name)=uieditfield(grid,'text','FontSize',13,'Tag',['GuidedChart' name]);
                obj.Fields.(name).Layout.Row=row;obj.Fields.(name).Layout.Column=2;
            end
            obj.Fields.Name.Value='Custom chart';obj.Fields.Rows.Value='4';obj.Fields.Columns.Value='6';
            obj.Fields.Saved=uibutton(grid,'Text','Continue chart…','FontSize',13, ...
                'Tag','GuidedChartOpenSaved','Enable',colormeasure.ui.onOff(~isempty(obj.OpenSaved)), ...
                'Tooltip','Inspect a saved file, this chart or another retained batch, then continue a selected pass or start an empty pass.', ...
                'ButtonPushedFcn',@(~,~)obj.openSaved());
            obj.Fields.Saved.Layout.Row=6;obj.Fields.Saved.Layout.Column=[1 2];
            bound=uilabel(grid,'Text', ...
                ['Up to 140 cells total. Custom dimensions must be positive whole numbers. ' ...
                'Measurement starts only when you press Measure in the main window.'], ...
                'WordWrap','on','FontSize',13);bound.Layout.Row=7;bound.Layout.Column=[1 2];
            obj.Fields.Error=uilabel(root,'Text','','WordWrap','on','FontSize',13, ...
                'Interpreter','none','Tag','GuidedChartSetupError');obj.Fields.Error.Layout.Row=2;
            buttons=uigridlayout(root,[1 2],'Padding',0,'ColumnWidth',{'1x','1x'});
            buttons.Layout.Row=3;
            uibutton(buttons,'Text','Cancel','FontSize',13,'Tag','GuidedChartSetupCancel', ...
                'ButtonPushedFcn',@(~,~)obj.close());
            obj.Fields.Start=uibutton(buttons,'Text','Start chart','FontSize',13,'FontWeight','bold', ...
                'Tag','GuidedChartSetupStart','ButtonPushedFcn',@(~,~)obj.start());
            obj.refresh();obj.Constructed=true;obj.Figure.Visible=owner.Visible;
            obj.restoreFocus(obj.Fields.Preset);
        end
        function delete(obj)
            if isscalar(obj.Figure)&&isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn='';delete(obj.Figure);
            end
        end
        function showContinuationError(obj,problem)
            if ~obj.live(),return;end
            obj.Fields.Error.Text=problem.message;obj.Fields.Error.Tooltip=problem.message;
        end
    end
    methods (Access=private)
        function openSaved(obj)
            if ~obj.live()||isempty(obj.OpenSaved),return;end
            obj.OpenSaved();
        end
        function yes=live(obj)
            yes=isvalid(obj)&&isscalar(obj.Figure)&&isgraphics(obj.Figure)&& ...
                isscalar(obj.Owner)&&isgraphics(obj.Owner)&&isvalid(obj.Session);
        end
        function restoreFocus(obj,control)
            if obj.live()&&strcmp(obj.Figure.Visible,'on')&&strcmp(obj.Owner.Visible,'on')
                figure(obj.Figure);focus(control);
            end
        end
        function clearError(obj)
            obj.Fields.Error.Text='';obj.Fields.Error.Tooltip='';
        end
        function refresh(obj)
            if strcmp(obj.PreviousPreset,'custom')
                for name={'Name','Rows','Columns'},obj.CustomDraft.(name{1})=obj.Fields.(name{1}).Value;end
            end
            kind=obj.Fields.Preset.Value;custom=strcmp(kind,'custom');
            if custom
                values=obj.CustomDraft;
            else
                d=colormeasure.chart.definition(kind);
                values=struct('Name',d.name,'Rows',num2str(d.rows),'Columns',num2str(d.columns));
            end
            for name={'Name','Rows','Columns'}
                obj.Fields.(name{1}).Enable=colormeasure.ui.onOff(custom);
                obj.Fields.(name{1}).Value=values.(name{1});
            end
            obj.PreviousPreset=kind;
            obj.clearError();
        end
        function start(obj)
            try
                if obj.Session.busy||obj.Session.finishing||obj.Session.finished,return;end
                kind=obj.Fields.Preset.Value;
                if strcmp(kind,'custom')
                    rows=dimension(obj.Fields.Rows.Value);columns=dimension(obj.Fields.Columns.Value);
                    definition=colormeasure.chart.definition('custom',obj.Fields.Name.Value,rows,columns);
                else
                    definition=colormeasure.chart.definition(kind);
                end
                obj.Session.startChart(definition);
            catch problem
                obj.Fields.Error.Text=problem.message;obj.Fields.Error.Tooltip=problem.message;return;
            end
            obj.close();
        end
        function close(obj)
            owner=obj.Owner;closed=obj.Closed;delete(obj);
            closed();
            if isscalar(owner)&&isgraphics(owner)&&strcmp(owner.Visible,'on'),figure(owner);end
        end
        function keyPress(obj,event)
            if colormeasure.ui.isCloseKey(event),obj.close();end
        end
        function cleanupPartial(obj)
            if isvalid(obj)&&~obj.Constructed,delete(obj);end
        end
    end
end
function value=dimension(text)
assert(~isempty(regexp(strtrim(text),'^[0-9]+$','once')), ...
    'Measurement:ChartDimensions','Enter positive whole numbers for rows and columns (no decimal or comma).');
value=str2double(text);
end

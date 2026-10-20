classdef ChartCleanupView < handle
    % CHARTCLEANUPVIEW Record explicit operator checks; never operate a device.
    % A live batch records them through its Session. Continuing a saved chart
    % whose batch has ended passes them to the continuation instead.
    properties (Constant)
        Checks=['Check two things: no MATLAB batch or other program is still using the instrument''s port ' ...
            '(quitting them, or unplugging and reconnecting the instrument cable, closes it), and the instrument ' ...
            'is not measuring. Record both checks and explain what you did. This is your declaration; ' ...
            'the app does not operate or validate the instrument.']
    end
    properties (SetAccess=private)
        Figure
    end
    properties (Access=private)
        Session
        Owner
        Record
        Fields
        Listener=[]
        Constructed=false
        Applying=false
    end
    methods
        function obj=ChartCleanupView(owner,intro,record,session)
            % record(text) returns whether the declaration was retained and
            % saved. session is [] when no live batch owns the uncertainty.
            obj.Owner=owner;obj.Record=record;obj.Session=session;
            obj.Figure=uifigure('Name','Confirm completed connection cleanup','Visible','off', ...
                'Tag','ChartCleanupConfirmationDialog','WindowStyle','modal', ...
                'Position',colormeasure.ui.dialogPosition(owner,[640 450]), ...
                'CloseRequestFcn',@(~,~)obj.close(), ...
                'WindowKeyPressFcn',@(~,event)obj.keyPress(event));
            cleanup=onCleanup(@()obj.cleanupPartial());
            obj.Figure.Theme=owner.Theme;
            root=uigridlayout(obj.Figure,[6 1],'Padding',16,'RowSpacing',10, ...
                'RowHeight',{110,30,30,'1x',48,36});
            uilabel(root,'Text',[intro ' ' obj.Checks],'FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','ChartCleanupIntroduction');
            obj.Fields.Connection=uicheckbox(root,'Text','I confirmed the connection is closed.', ...
                'FontSize',13,'Value',false,'Tag','ChartCleanupConnectionClosed', ...
                'ValueChangedFcn',@(~,~)obj.refresh());
            obj.Fields.Idle=uicheckbox(root,'Text','I confirmed the instrument is idle.', ...
                'FontSize',13,'Value',false,'Tag','ChartCleanupInstrumentIdle', ...
                'ValueChangedFcn',@(~,~)obj.refresh());
            obj.Fields.Declaration=uitextarea(root,'Value',{''},'FontSize',13, ...
                'Tag','ChartCleanupDeclaration','Placeholder','Explain how you checked cleanup.', ...
                'Tooltip',sprintf('Maximum %d UTF-16 text units; text is never truncated.',colormeasure.chart.Run.MaxDeclarationCodeUnits), ...
                'ValueChangedFcn',@(~,~)obj.refresh());
            obj.Fields.Message=uilabel(root,'Text','','FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','ChartCleanupMessage');
            buttons=uigridlayout(root,[1 2],'Padding',0,'ColumnWidth',{120,'1x'});
            obj.Fields.Cancel=uibutton(buttons,'Text','Cancel','FontSize',13, ...
                'Tag','ChartCleanupCancel','ButtonPushedFcn',@(~,~)obj.close());
            obj.Fields.Confirm=uibutton(buttons,'Text','Record checked cleanup','FontSize',13, ...
                'Tag','ChartCleanupConfirm','Enable','off','ButtonPushedFcn',@(~,~)obj.accept());
            if ~isempty(session),obj.Listener=addlistener(session,'Changed',@(~,~)obj.refresh());end
            obj.Figure.UserData=obj;obj.Constructed=true;obj.refresh();
            obj.Figure.Visible=owner.Visible;
            if colormeasure.ui.canFocus(obj.Fields.Cancel,obj.Figure),focus(obj.Fields.Cancel);end
        end
        function delete(obj)
            if ~isempty(obj.Listener),delete(obj.Listener);end
            if isscalar(obj.Figure)&&isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn='';obj.Figure.WindowKeyPressFcn='';delete(obj.Figure);
            end
        end
    end
    methods (Access=private)
        function refresh(obj)
            if ~obj.Constructed||~obj.live()||obj.Applying,return;end
            valid=obj.Fields.Connection.Value&&obj.Fields.Idle.Value;
            reason='Confirm both checks and explain completed cleanup. No reading starts from this confirmation.';
            text=strtrim(strjoin(cellstr(obj.Fields.Declaration.Value),newline));
            if isempty(text),valid=false;
            else
                try
                    colormeasure.chart.declarationText(text,'Cleanup explanation');
                catch problem,valid=false;reason=problem.message;
                end
            end
            allowed=true;
            if ~isempty(obj.Session)
                allowed=~obj.Session.busy&&obj.Session.chartIoUnconfirmed&&~obj.Session.directCleanupCanRetry;
                if ~allowed,reason='This direct batch no longer has an idle unconfirmed connection to resolve.';end
                if obj.Session.directCleanupCanRetry,reason='Use Retry cleanup instead. A declaration cannot bypass a reachable connection.';end
            end
            obj.Fields.Confirm.Enable=colormeasure.ui.onOff(valid&&allowed);
            obj.Fields.Message.Text=reason;obj.Fields.Message.Tooltip=reason;
        end
        function accept(obj)
            if ~obj.live()||obj.Applying,return;end
            obj.refresh();if strcmp(obj.Fields.Confirm.Enable,'off'),return;end
            text=strtrim(strjoin(cellstr(obj.Fields.Declaration.Value),newline));
            obj.Applying=true;obj.Fields.Confirm.Enable='off';obj.Fields.Cancel.Enable='off';
            try
                saved=obj.Record(text);
                if ~obj.live(),return;end
                obj.Applying=false;
                if saved,obj.close();return;end
                obj.Fields.Cancel.Enable='on';obj.refresh();
                obj.Fields.Message.Text='Confirmation retained; saving needs attention. Cancel this dialog and use Retry save.';
                obj.Fields.Message.Tooltip=obj.Fields.Message.Text;
            catch problem
                if ~obj.live(),return;end
                obj.Applying=false;obj.Fields.Cancel.Enable='on';obj.refresh();
                obj.Fields.Message.Text=problem.message;obj.Fields.Message.Tooltip=problem.message;
            end
        end
        function close(obj)
            if isvalid(obj)&&~obj.Applying,delete(obj);end
        end
        function keyPress(obj,event)
            if obj.live()&&colormeasure.ui.isCloseKey(event),obj.close();end
        end
        function yes=live(obj)
            yes=isvalid(obj)&&isscalar(obj.Figure)&&isgraphics(obj.Figure)&& ...
                (isempty(obj.Session)||isvalid(obj.Session))&&isscalar(obj.Owner)&&isgraphics(obj.Owner);
        end
        function cleanupPartial(obj)
            if ~obj.Constructed,delete(obj);end
        end
    end
end

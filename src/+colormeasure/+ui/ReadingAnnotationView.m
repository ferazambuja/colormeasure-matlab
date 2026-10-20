classdef ReadingAnnotationView < handle
    % READINGANNOTATIONVIEW Edit one retained reading's operator annotations.
    % The session owns validation, persistence and recovery. The selected row
    % is captured when opened; later table selection cannot retarget the edit.
    properties (SetAccess=private)
        Figure
    end
    properties (Access=private)
        Session
        Index
        Baseline
        Owner
        Fields
        Listener
        Saving=false
    end
    methods
        function obj=ReadingAnnotationView(session,index,owner)
            obj.Session=session;obj.Index=index;obj.Owner=owner;
            obj.Baseline=session.measurements(index);
            obj.Figure=uifigure('Name',sprintf('Edit reading #%d',index), ...
                'Tag','ReadingAnnotationWindow','Visible','off','WindowStyle','modal', ...
                'Position',colormeasure.ui.dialogPosition(owner,[580 420]), ...
                'CloseRequestFcn',@(~,~)obj.close(),'WindowKeyPressFcn',@(~,event)obj.keyPress(event));
            cleanup=onCleanup(@()obj.cleanupPartial());
            obj.Figure.Theme=owner.Theme;
            grid=uigridlayout(obj.Figure,[7 1],'RowHeight',{28,30,24,'1x',42,32,32}, ...
                'Padding',[16 12 16 12],'RowSpacing',8);
            uilabel(grid,'Text','Sample name');
            obj.Fields.Name=uieditfield(grid,'text','Value',obj.Baseline.name, ...
                'Tag','ReadingAnnotationName');
            uilabel(grid,'Text','Notes');
            obj.Fields.Notes=uitextarea(grid,'Value',regexp(obj.Baseline.notes,'\r\n|\n|\r','split'), ...
                'Tag','ReadingAnnotationNotes','FontSize',13);
            uilabel(grid,'Text',['Changes apply to this reading only. Original annotations and instrument records are retained. ' ...
                'Measured values and acquisition settings stay unchanged.'],'WordWrap','on');
            obj.Fields.Message=uilabel(grid,'Text','','WordWrap','on','Tag','ReadingAnnotationMessage');
            buttons=uigridlayout(grid,[1 2],'Padding',0,'ColumnWidth',{'1x','1x'});
            uibutton(buttons,'Text','Cancel','Tag','CancelReadingAnnotations','ButtonPushedFcn',@(~,~)obj.close());
            obj.Fields.Save=uibutton(buttons,'Text','Save changes','FontWeight','bold', ...
                'Tag','SaveReadingAnnotations','ButtonPushedFcn',@(~,~)obj.save());
            obj.Listener=addlistener(session,'Changed',@(~,~)obj.refresh());
            obj.Figure.UserData=obj;obj.refresh();
            obj.Figure.Visible=owner.Visible;
        end
        function delete(obj)
            if ~isempty(obj.Listener),delete(obj.Listener);end
            if isgraphics(obj.Figure),obj.Figure.CloseRequestFcn='';delete(obj.Figure);end
        end
    end
    methods (Access=private)
        function refresh(obj)
            if obj.Saving||~isgraphics(obj.Figure),return;end
            s=obj.Session;
            ready=isvalid(s)&&~s.busy&&(~s.finishing||s.finished);
            if ready
                current=s.measurements(obj.Index);
                ready=strcmp(current.name,obj.Baseline.name)&&strcmp(current.notes,obj.Baseline.notes);
                if ~ready,obj.Fields.Message.Text='This reading changed in MATLAB. Cancel and reopen the editor.';end
                if ready,obj.Fields.Message.Text='';end
            else
                obj.Fields.Message.Text='Editing is paused while the batch is busy or needs recovery. Your draft is retained.';
            end
            obj.Fields.Save.Enable=colormeasure.ui.onOff(ready);
        end
        function save(obj)
            if ~isvalid(obj)||~isgraphics(obj.Figure),return;end
            obj.refresh();if strcmp(obj.Fields.Save.Enable,'off'),return;end
            notes=strjoin(cellstr(obj.Fields.Notes.Value),newline);
            try
                obj.Saving=true;
                obj.Session.editReading(obj.Index,obj.Fields.Name.Value,notes);
            catch problem
                obj.Saving=false;obj.Fields.Message.Text=problem.message;return
            end
            % Save failure is retained by Session and shown in the main
            % recovery strip; closing does not discard the accepted edit.
            obj.close();
        end
        function close(obj)
            owner=obj.Owner;delete(obj);
            if isgraphics(owner)&&strcmp(owner.Visible,'on'),figure(owner);end
        end
        function keyPress(obj,event)
            if colormeasure.ui.isCloseKey(event),obj.close();end
        end
        function cleanupPartial(obj)
            if ~isgraphics(obj.Figure)||~strcmp(obj.Figure.Tag,'ReadingAnnotationWindow'),return;end
            % The retained UserData is assigned only after construction.
            if isempty(obj.Figure.UserData),delete(obj);end
        end
    end
end

classdef ChartView < handle
    % CHARTVIEW Patch diagram; Session owns identity and acquisition.
    % Native colored cells keep one keyboard stop and scroll extreme grids.
    properties (SetAccess=private)
        Panel
        Grid
    end
    properties (Access=private)
        Session
        Fields
        State = struct([])
        DisplayCells = []
        Inspection = []
        LastRun = ''
        LastPass = 0
        ViewPass = 0
        BlockReason = @()''
        AcquisitionBlockReason = @()''
        Setup = []
        ColorKey = {}
        CellColors = []
        StyleKey = {}
        CellSize = 44
    end
    methods
        function obj=ChartView(parent,session,blockReason,acquisitionBlockReason,setup)
            obj.Session=session;
            if nargin>2,obj.BlockReason=blockReason;end
            if nargin>3,obj.AcquisitionBlockReason=acquisitionBlockReason;end
            if nargin>4,obj.Setup=setup;end
            obj.Panel=uipanel(parent,'Units','pixels','BorderType','none', ...
                'AutoResizeChildren','off','Visible','off','Tag','GuidedChartWorkspace');
            obj.Fields.Title=uilabel(obj.Panel,'Text','Guided chart','FontSize',16, ...
                'FontWeight','bold','Interpreter','none','Tag','GuidedChartTitle');
            obj.Fields.Progress=uilabel(obj.Panel,'Text','','FontSize',13, ...
                'Interpreter','none','Tag','GuidedChartProgress');
            obj.Fields.Pass=uidropdown(obj.Panel,'Items',{'Pass 1'},'ItemsData',1, ...
                'FontSize',13,'Tag','GuidedChartPass','Tooltip', ...
                'Inspect an earlier pass without changing the active measurement pass or patch.', ...
                'ValueChangedFcn',@(~,~)obj.selectPass());
            if ~isempty(obj.Setup)
                obj.Fields.Setup=uibutton(obj.Panel,'Text','Change chart…','FontSize',13, ...
                    'Tag','GuidedChartChange','Tooltip', ...
                    'Preview a different chart. After an attempt, finish this batch and start another before replacing its chart.', ...
                    'ButtonPushedFcn',@(~,~)obj.Setup());
            end
            obj.Fields.Left=uibutton(obj.Panel,'Text','Rotate left','FontSize',13, ...
                'Tag','GuidedChartRotateLeft','ButtonPushedFcn',@(~,~)obj.rotate(-90));
            obj.Fields.Right=uibutton(obj.Panel,'Text','Rotate right','FontSize',13, ...
                'Tag','GuidedChartRotateRight','ButtonPushedFcn',@(~,~)obj.rotate(90));
            obj.Fields.Pause=uibutton(obj.Panel,'Text','Pause chart','FontSize',13, ...
                'Tag','GuidedChartPause','ButtonPushedFcn',@(~,~)obj.pause());
            obj.createGrid();
            obj.Fields.Active=uilabel(obj.Panel,'Text','','FontSize',16,'FontWeight','bold', ...
                'Interpreter','none','Tag','GuidedChartActivePatch');
            obj.Fields.Detail=uilabel(obj.Panel,'Text','','FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','GuidedChartPatchDetail');
            obj.Fields.Notice=uilabel(obj.Panel,'Text', ...
                '○ To measure   ✓ Measured   * Next patch   ! Check reading', ...
                'FontSize',12,'WordWrap','on','Tag','GuidedChartNotice', ...
                'Tooltip','Chart colors help you locate patches. Open Data to inspect a reading''s measured values.');
            obj.Fields.Reference=uipanel(obj.Panel,'Units','pixels','Title','Chart color','FontSize',12, ...
                'Tag','GuidedChartReferencePreview','BackgroundColor',[.12 .12 .12]);
            obj.Fields.Context=uibutton(obj.Panel,'Text','Review changed settings…','FontSize',13, ...
                'Tag','GuidedChartReviewContext','Visible','off', ...
                'ButtonPushedFcn',@(~,~)obj.reviewContext());
        end
        function update(obj,state)
            if isempty(state),obj.State=state;obj.Panel.Visible='off';return;end
            newRun=~strcmp(obj.LastRun,state.runId);
            if newRun||obj.LastPass~=state.activePass
                obj.ViewPass=state.activePass;
            end
            % Keep native table inspection where the user left it. Acquisition
            % advances Session's active patch, not the table's keyboard cursor.
            pass=state.passes(obj.ViewPass);viewingActive=obj.ViewPass==state.activePass;
            blockReason=obj.BlockReason();
            acquisitionReason=obj.AcquisitionBlockReason();
            % Pause and context review resolve acquisition-only blockers.
            % Host and connection safety failures still prevent all chart edits.
            ready=~obj.Session.busy&&~obj.Session.finishing&&~obj.Session.finished&& ...
                ~obj.Session.chartIoUnconfirmed&&~obj.Session.needsRecovery&&~state.unsaved&&isempty(blockReason);
            closed=obj.Session.finishing||obj.Session.finished;
            chartOpen=~state.paused&&~closed;
            canTarget=ready&&chartOpen&&viewingActive&&isempty(state.pendingContext)&&state.eligible&&isempty(acquisitionReason);
            labels=arrayfun(@(index)sprintf('Pass %d',index),1:numel(state.passes),'UniformOutput',false);
            labels{state.activePass}=[labels{state.activePass} ' · active'];
            obj.Fields.Pass.Items=labels;obj.Fields.Pass.ItemsData=1:numel(labels);obj.Fields.Pass.Value=obj.ViewPass;
            obj.Fields.Pass.Visible=colormeasure.ui.onOff(numel(labels)>1);
            if ~isempty(obj.Setup)
                continuationReady=obj.Session.finished&&~obj.Session.busy&&~obj.Session.needsRecovery&& ...
                    ~obj.Session.chartIoUnconfirmed&&~state.unsaved&&isempty(blockReason);
                obj.Fields.Setup.Enable=colormeasure.ui.onOff(ready||continuationReady);
                if closed
                    obj.Fields.Setup.Text='Continue chart…';
                    obj.Fields.Setup.Tooltip='Inspect this saved chart and choose continuation into a new linked batch. Opening does not measure.';
                else
                    obj.Fields.Setup.Text='Change chart…';
                    obj.Fields.Setup.Tooltip='Preview a different chart. After an attempt, finish this batch and start another before replacing its chart.';
                end
            end
            d=state.definition;
            indices=reshape(1:numel(d.cells),d.columns,d.rows).';
            display=rot90(indices,-state.orientation/90);
            if newRun
                % A new chart gets a fresh native cursor at its first cell.
                if ~isempty(obj.LastRun)
                    obj.resetGrid();
                end
                index=display(1,1);obj.Inspection=[d.cells(index).row d.cells(index).column];
            elseif ~isequal(obj.DisplayCells,display)
                % Rotation keeps the visible keyboard position; it never
                % retargets acquisition to a different physical patch.
                rc=obj.Grid.Selection;
                if isempty(rc)||rc(1)>size(display,1)||rc(2)>size(display,2)
                    obj.resetGrid();rc=[1 1];
                end
                index=display(rc(1),rc(2));
                obj.Inspection=[d.cells(index).row d.cells(index).column];
            end
            obj.DisplayCells=display;
            obj.State=state;obj.LastRun=state.runId;obj.LastPass=state.activePass;
            active=(state.currentCell(1)-1)*d.columns+state.currentCell(2);
            colorKey={state.runId,obj.ViewPass,state.revision};
            if ~isequal(obj.ColorKey,colorKey)
                obj.CellColors=colormeasure.chart.colors(d,pass,obj.Session.measurements,state.referenceData,state);
                obj.ColorKey=colorKey;
            end
            obj.styleGrid(canTarget,active);
            inspected=(obj.Inspection(1)-1)*d.columns+obj.Inspection(2);
            [r,c]=find(obj.DisplayCells==inspected,1);obj.Grid.Selection=[r c];
            obj.Fields.Title.Text=d.name;obj.Fields.Title.Tooltip=d.name;
            status=sprintf('Pass %d · %d / %d measured · %d°',obj.ViewPass,pass.coverage,numel(d.cells),state.orientation);
            if obj.Session.saving
                saving='saving chart progress';
                if obj.Session.finished,saving='saving retained output';end
                status=[status ' · ' saving];
            elseif obj.Session.busy
                activity=lower(obj.Session.activity);
                if strcmp(obj.Session.activity,'Measuring'),activity='measurement in progress';end
                status=[status ' · ' activity];
            elseif ~canTarget
                status=[status ' · read only'];
            end
            if state.paused,status=[status ' · paused'];end
            if state.unsaved&&~obj.Session.busy&&~obj.Session.saving,status=[status ' · NOT SAVED'];end
            obj.Fields.Progress.Text=status;
            obj.Fields.Left.Enable=colormeasure.ui.onOff(ready&&viewingActive);
            obj.Fields.Right.Enable=colormeasure.ui.onOff(ready&&viewingActive);
            obj.Fields.Pause.Enable=colormeasure.ui.onOff(ready&&(~state.paused||isempty(state.pendingContext)));
            label='Pause chart';if state.paused,label='Resume chart';end
            obj.Fields.Pause.Text=label;
            obj.Fields.Context.Visible=colormeasure.ui.onOff(~isempty(state.pendingContext));
            obj.Fields.Context.Enable=colormeasure.ui.onOff(ready);
            activeName=colormeasure.chart.coordinate(state.currentCell(1),state.currentCell(2));
            [targetLabel,guidance,nextStep]=chartPresentation(obj.Session,state, ...
                viewingActive,canTarget,blockReason,acquisitionReason,activeName);
            if inspected==active&&viewingActive
                obj.Fields.Active.Text=[targetLabel ': ' activeName];
            else
                obj.Fields.Active.Text=sprintf('Inspecting %s · pass %d | %s %s · pass %d', ...
                    colormeasure.chart.coordinate(obj.Inspection(1),obj.Inspection(2)),obj.ViewPass,targetLabel,activeName,state.activePass);
            end
            obj.Grid.Tooltip=[guidance ' Arrow keys select a patch to inspect. ' ...
                '○ To measure; ✓ Measured; ! Check reading; * Next patch.'];
            cellInfo=pass.cells(inspected);
            identity=d.cells(inspected);
            sourceIdentity=sprintf('Application coordinate: %s · Source location: %s · Source ID: %s', ...
                colormeasure.chart.coordinate(identity.row,identity.column), ...
                identity.sourceLocation,sourceIdText(identity.sourceId));
            detail=[sourceIdentity newline sprintf('%d %s. ',cellInfo.attemptCount,attemptWord(cellInfo.attemptCount))];
            selected=cellInfo.selectedAttempt;
            if selected>0
                cellAttempts=find([pass.attempts.cellIndex]==inspected);
                selectedOrdinal=find(cellAttempts==selected,1);
                detail=[detail sprintf('Selected successful attempt %d of %d at this patch. ', ...
                    selectedOrdinal,numel(cellAttempts))];
                [~,readingFacts]=obj.Session.chartReading(obj.ViewPass,inspected);
                detail=[detail 'Name: ' readingFacts.name '. '];
                detail=[detail sprintf('Original batch: %s; reading #%d. ', ...
                    readingFacts.segmentId,readingFacts.readingIndex)];
            else
                detail=[detail 'Not measured. '];
            end
            if ~isempty(cellInfo.reason),detail=[detail cellInfo.reason ' '];end
            colors=obj.CellColors(inspected);
            obj.preview(obj.Fields.Reference,colors.reference);
            % The swatch is hidden without a color; its source and caveat stay in the tooltip.
            obj.Fields.Reference.Visible=colormeasure.ui.onOff(colors.reference.available);
            if colors.reference.available,detail=[detail colors.reference.reason ' '];
            else,detail=[detail 'Chart color unavailable: ' colors.reference.reason ' '];end
            if cellInfo.selectedAttempt>0&&~colors.measured.available
                detail=[detail 'Open Data to see this reading''s measured values. '];
            end
            detail=[detail guidance];
            % Keep the action readable in the two-line footer. Names, failure
            % reasons and scientific context remain complete in its tooltip.
            if selected>0
                origin='This batch';if readingFacts.inherited,origin='Earlier batch';end
                % The stored attempt ID spans the pass; the visible fraction
                % counts only attempts at this cell, including inherited ones.
                cellAttempts=find([pass.attempts.cellIndex]==inspected);
                selectedOrdinal=find(cellAttempts==selected,1);
                visibleDetail=sprintf('%s reading #%d · attempt %d/%d.',origin,readingFacts.readingIndex,selectedOrdinal,cellInfo.attemptCount);
            else
                visibleDetail=sprintf('Not measured · %d %s.',cellInfo.attemptCount,attemptWord(cellInfo.attemptCount));
            end
            if ismember(cellInfo.latestAttemptStatus,{'failed','cancelled','unresolved','interrupted'}),visibleDetail=[visibleDetail ' Retry issue.'];end
            detail=[detail sprintf('%d earlier-batch %s; %d new %s in this batch. ', ...
                cellInfo.inheritedAttemptCount,attemptWord(cellInfo.inheritedAttemptCount), ...
                cellInfo.newAttemptCount,attemptWord(cellInfo.newAttemptCount))];
            visibleDetail=[visibleDetail newline nextStep];
            obj.Fields.Detail.Text=visibleDetail;
            obj.Fields.Detail.Tooltip=[detail newline obj.colorContext('Chart color',colors.reference) ...
                newline obj.colorContext('Measured',colors.measured)];
        end
        function layout(obj,position)
            obj.Panel.Position=position;w=position(3);h=position(4);
            setupWidth=0;if ~isempty(obj.Setup),setupWidth=170;end
            obj.Fields.Title.Position=[0 h-26 max(180,w-190-setupWidth) 24];
            obj.Fields.Pass.Position=[w-180-setupWidth h-30 180 28];
            if ~isempty(obj.Setup),obj.Fields.Setup.Position=[w-160 h-30 160 28];end
            obj.Fields.Progress.Position=[0 h-50 w 22];
            obj.Fields.Left.Position=[0 h-84 106 30];
            obj.Fields.Right.Position=[114 h-84 106 30];
            obj.Fields.Pause.Position=[228 h-84 116 30];
            obj.Fields.Context.Position=[352 h-84 max(200,w-352) 30];
            obj.Grid.Position=[0 112 w max(80,h-200)];
            if ~isempty(obj.DisplayCells)
                % Native cell fills avoid icon/text clipping in dense charts.
                % Preserve coordinates/status and the same extreme-grid viewport.
                columns=size(obj.DisplayCells,2);
                width=max(44,min(100,floor((w-12)/columns)));
                obj.Grid.ColumnWidth=repmat({width},1,size(obj.DisplayCells,2));
                if obj.CellSize~=width
                    obj.CellSize=width;obj.StyleKey={};
                    if ~isempty(obj.State)
                        active=(obj.State.currentCell(1)-1)*obj.State.definition.columns+obj.State.currentCell(2);
                        obj.styleGrid(obj.targetAvailable(),active);
                    end
                end
            end
            obj.Fields.Active.Position=[0 84 max(100,w-132) 26];
            obj.Fields.Detail.Position=[0 50 max(100,w-132) 32];
            obj.Fields.Reference.Position=[max(0,w-120) 28 114 56];
            obj.Fields.Notice.Position=[0 0 w 26];
        end
        function show(obj,visible)
            obj.Panel.Visible=colormeasure.ui.onOff(visible&&~isempty(obj.State));
        end
        function delete(obj)
            if isscalar(obj.Panel)&&isgraphics(obj.Panel),delete(obj.Panel);end
        end
    end
    methods (Access=private)
        function resetGrid(obj)
            position=obj.Grid.Position;delete(obj.Grid);obj.createGrid();obj.Grid.Position=position;
            obj.StyleKey={};
        end
        function createGrid(obj)
            obj.Grid=uitable(obj.Panel,'Units','pixels','Data',{},'RowName',{},'ColumnName',{}, ...
                'ColumnEditable',false,'Multiselect','off','FontUnits','pixels','FontSize',13,'RowStriping','off', ...
                'Tag','GuidedChartGrid','CellSelectionCallback',@(~,event)obj.select(event), ...
                'ClickedFcn',@(~,event)obj.click(event),'KeyPressFcn',@(~,event)obj.keyPress(event), ...
                'Tooltip','Arrow keys move the inspected selection.');
            obj.Grid.BackgroundColor=[.12 .12 .12];obj.Grid.ForegroundColor=[1 1 1];
        end
        function styleGrid(obj,canTarget,active)
            key={obj.ColorKey,obj.DisplayCells,obj.CellSize,canTarget,active};
            if isequal(obj.StyleKey,key)||isempty(obj.CellColors),return;end
            obj.StyleKey=key;removeStyle(obj.Grid);
            display=obj.DisplayCells;
            pass=obj.State.passes(obj.ViewPass);
            text=cell(size(display));
            % Native rows grow with multiline text. Empty caption lines keep
            % wide preset cells near-square without an icon's fixed text slot.
            padding=repmat(newline,1,max(0,floor((obj.CellSize-12)/12)-2));
            for n=1:numel(display)
                cellInfo=pass.cells(display(n));mark='○';
                retryIssue=ismember(cellInfo.latestAttemptStatus,{'failed','cancelled','unresolved','interrupted'});
                if cellInfo.selectedAttempt>0,mark='✓';
                elseif retryIssue,mark='!';end
                if cellInfo.selectedAttempt>0&&retryIssue,mark='✓!';end
                activeMark='';if canTarget&&display(n)==active,activeMark='*';end
                text{n}=[colormeasure.chart.coordinate(cellInfo.row,cellInfo.column) newline mark activeMark padding];
            end
            if ~isequal(obj.Grid.Data,text),obj.Grid.Data=text;end
            for n=1:numel(display)
                index=display(n);entry=obj.CellColors(index);fill=[.12 .12 .12];
                if pass.cells(index).selectedAttempt>0
                    if entry.measured.available,fill=entry.measured.rgb;end
                elseif entry.reference.available
                    fill=.55*entry.reference.rgb+.45*[.18 .18 .18];
                end
                [r,c]=ind2sub(size(display),n);
                style=uistyle('BackgroundColor',fill,'FontColor',obj.contrastingText(fill));
                if canTarget&&index==active,style.FontWeight='bold';end
                addStyle(obj.Grid,style,'cell',[r c]);
            end
        end
        function preview(~,panel,value)
            rgb=[.12 .12 .12];if value.available,rgb=value.rgb;end
            panel.BackgroundColor=rgb;
            panel.ForegroundColor=colormeasure.ui.ChartView.contrastingText(rgb);
            panel.UserData=value;
        end
    end
    methods (Static,Access=private)
        function foreground=contrastingText(rgb)
            linear=rgb/12.92;bright=rgb>.04045;
            linear(bright)=((rgb(bright)+.055)/1.055).^2.4;
            foreground=[1 1 1];
            if dot(linear,[.2126 .7152 .0722])>.179,foreground=[0 0 0];end
        end
    end
    methods (Access=private)
        function text=colorContext(~,label,value)
            if ~value.available,text=[label ': unavailable. ' value.reason];return;end
            context=value.context;
            text=sprintf('%s: approximate sRGB preview. %s; %s; %s; units %s; white XYZ [%.5g %.5g %.5g].', ...
                label,context.observerId,context.illuminant,context.xyzScale, ...
                context.xyzUnits,context.whiteXYZ);
            if value.clipped,text=[text ' Display gamut clipped.'];
            else,text=[text ' No display gamut clipping.'];end
        end
        function yes=targetAvailable(obj)
            s=obj.Session;state=obj.State;
            yes=~isempty(state)&&obj.ViewPass==state.activePass&&state.eligible&&~s.busy&&~s.finishing&&~s.finished&& ...
                ~s.chartIoUnconfirmed&&~s.needsRecovery&&~state.unsaved&&~state.paused&&isempty(state.pendingContext)&& ...
                isempty(obj.BlockReason())&&isempty(obj.AcquisitionBlockReason());
        end
        function select(obj,event)
            if isempty(event.Indices)||isempty(obj.State),return;end
            rc=event.Indices(1,:);index=obj.DisplayCells(rc(1),rc(2));
            d=obj.State.definition;obj.Inspection=[d.cells(index).row d.cells(index).column];
            obj.update(obj.Session.chart);
        end
        function click(obj,event)
            info=event.InteractionInformation;
            if isempty(info.Row)||isempty(info.Column)||isempty(obj.State),return;end
            % Click coordinates also identify a cell that was already inspected;
            % no selection-change event is required to activate it.
            obj.select(struct('Indices',[info.Row info.Column]));
            obj.activate();
        end
        function keyPress(obj,event)
            % Table callbacks are dispatched only while this grid has focus.
            % Inspection movement is native; activation requires an explicit key.
            if ~isempty(event.Modifier)||~ismember(event.Key,{'space','return'}),return;end
            obj.activate();
        end
        function activate(obj)
            if isempty(obj.State)||isempty(obj.Inspection),return;end
            s=obj.Session;
            if obj.targetAvailable()
                try
                    s.selectChartCell(obj.Inspection(1),obj.Inspection(2));
                catch problem
                    s.reportError(problem);
                end
            end
            obj.update(s.chart);
        end
        function selectPass(obj)
            obj.ViewPass=obj.Fields.Pass.Value;
            obj.update(obj.Session.chart);
        end
        function rotate(obj,delta)
            if strcmp(obj.Fields.Left.Enable,'off'),return;end
            try
                obj.Session.rotateChart(mod(obj.State.orientation+delta,360));
            catch problem
                obj.Session.reportError(problem);
            end
        end
        function pause(obj)
            if strcmp(obj.Fields.Pause.Enable,'off'),return;end
            try
                if obj.State.paused,obj.Session.resumeChart();else,obj.Session.pauseChart();end
            catch problem
                obj.Session.reportError(problem);
            end
        end
        function reviewContext(obj)
            if strcmp(obj.Fields.Context.Enable,'off')||isempty(obj.State.pendingContext),return;end
            s=obj.Session;pending=obj.State.pendingContext;
            if isempty(pending.differences),details=pending.reason;
            else,details=strjoin({pending.differences.message},newline);end
            if isfield(s.services,'confirmChartContext'),accepted=s.services.confirmChartContext(s,obj.State.pendingContext);
            else
                answer=questdlg(sprintf(['Acquisition settings changed:\n%s\n\nStart a new chart pass? ' ...
                    'Earlier attempts stay retained. New coverage starts empty.'],details), ...
                    'Chart settings changed','Start new pass','Decide later','Decide later');
                accepted=strcmp(answer,'Start new pass');
            end
            if isequal(accepted,true)
                try
                    s.acceptChartContext();
                catch problem
                    s.reportError(problem);
                end
            end
        end
    end
end
function text=sourceIdText(value)
if isempty(value),text='Not supplied';else,text=char(string(value));end
end

function [label,guidance,next]=chartPresentation(s,state,viewingActive,canTarget,hostReason,acquisitionReason,activeName)
% Distinguish acquisition lifetime from inspection and recoverable blockers.
label='Active patch';
if s.saving
    label='Chart target';next='Saving chart progress. Wait for saving to complete.';
    if s.finished,label='Retained chart patch';next='Saving retained output. Wait for saving to complete.';end
elseif s.finished
    label='Retained chart patch';next='Batch closed. Retained chart inspection only.';
    if s.busy
        next=[s.activity '. Wait for this action to complete. Retained chart inspection only.'];
    elseif s.chartIoUnconfirmed&&isempty(s.saveError)&&isempty(s.exportError)
        next='Batch closed and saved. Connection cleanup is unconfirmed. Resolve it before another batch.';
    elseif s.chartIoUnconfirmed
        next='Batch closed. Use the recovery controls to save retained output and resolve connection cleanup.';
    elseif s.needsRecovery
        next='Batch closed. Use the recovery controls to save retained output.';
    end
elseif s.chartIoUnconfirmed&&~s.busy
    label='Blocked chart target';next='Connection cleanup is unconfirmed. Resolve it before another measurement.';
elseif s.needsRecovery&&~s.busy
    label='Blocked chart target';next='Use the recovery controls before measuring or changing chart progress.';
    if state.unsaved,next='Use Retry save before continuing.';end
elseif s.finishing
    label='Chart target';next=[s.activity '. Wait for saving to complete.'];
    if strcmp(s.activity,'Finishing'),next='Finishing batch. Wait for saving to complete.';end
elseif s.busy
    label='Chart target';next=[s.activity '. Wait for this action to complete.'];
    if strcmp(s.activity,'Measuring')
        next='Measurement in progress. Wait for it to finish.';
    end
elseif state.unsaved
    label='Blocked chart target';next='Use the recovery controls before measuring or changing chart progress.';
elseif ~isempty(hostReason)
    label='Blocked chart target';next=['Acquisition unavailable. ' hostReason];
elseif ~isempty(state.pendingContext)
    label='Blocked chart target';next='Review changed settings before another chart reading.';
    if state.paused
        label='Paused chart patch';next=[next ' The chart stays paused; when available, Measure takes free samples.'];
    end
elseif ~state.paused&&~viewingActive
    next=sprintf('Earlier pass: inspection only. Acquisition follows active pass %d.',state.activePass);
elseif ~state.eligible
    label='Unavailable chart target';next=['Acquisition unavailable. ' state.reason];
elseif ~isempty(acquisitionReason)
    label='Blocked chart target';next=['Resolve the acquisition setup. ' acquisitionReason];
elseif state.paused
    label='Paused chart patch';next='Paused. Resume chart to acquire chart patches. When available, Measure takes free samples.';
elseif canTarget
    next=['Position on ' activeName ', then Measure.'];
else
    label='Blocked chart target';next='Chart acquisition is unavailable. Inspect the retained data.';
end
guidance=next;
if s.finished&&~s.needsRecovery&&~s.saving&&~s.busy
    guidance='Acquisition is closed. Retained chart inspection only.';
elseif canTarget
    guidance=[next ' Click a patch, or press Space or Enter with the grid focused, to make it Active (*). Measure advances the target; inspection stays selected.'];
elseif ~viewingActive&&~s.finished&&~s.finishing
    guidance=[guidance sprintf(' Select active pass %d to change its target when acquisition is available.',state.activePass)];
end
end

function word=attemptWord(count)
word='attempts';if count==1,word='attempt';end
end

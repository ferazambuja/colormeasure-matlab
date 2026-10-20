classdef ChartContinuationView < handle
    % CHARTCONTINUATIONVIEW Inspect Core's decision before linking a chart.
    % Opening, refreshing and cancelling this preview never start acquisition.
    % Session owns source validation, continuity, retention and acceptance.
    properties (SetAccess=private)
        Figure
    end
    properties (Access=private)
        Owner
        Preview
        Apply
        Refresh
        Closed
        Fields
        Constructed=false
        Accepting=false
        DeclarationValues=struct()
        DeclarationText=struct()
        DeclarationErrors=struct()
        DeclarationKey=''
        DeclarationsOpen=false
        SelectedPassId=''
        ComparisonCurrent=true
        SourceCleanup=''
        SourceCleanupIdentity=struct([])
        CleanupView=[]
    end
    methods
        function obj=ChartContinuationView(owner,preview,sourceLabel,apply,refresh,closed)
            obj.Owner=owner;obj.Preview=preview;obj.Apply=apply;
            obj.Refresh=refresh;obj.Closed=closed;
            obj.Figure=uifigure('Name','Continue chart','Visible','off', ...
                'Tag','ChartContinuationPreview','WindowStyle','modal', ...
                'Position',colormeasure.ui.dialogPosition(owner,[1040 790]), ...
                'CloseRequestFcn',@(~,~)obj.close(), ...
                'WindowKeyPressFcn',@(~,event)obj.keyPress(event));
            cleanup=onCleanup(@()obj.cleanupPartial());
            obj.Figure.Theme=owner.Theme;
            root=uigridlayout(obj.Figure,[9 1],'Padding',[16 16 16 16], ...
                'RowHeight',{30,32,74,64,0,'1x',64,40,36},'RowSpacing',8);
            obj.Fields.Root=root;
            obj.Fields.Title=uilabel(root,'Text','','FontSize',16,'FontWeight','bold', ...
                'Interpreter','none','Tag','ChartContinuationTitle');
            obj.Fields.Source=uilabel(root,'Text',['Chart to inspect: ' sourceLabel], ...
                'FontSize',13,'WordWrap','on','Interpreter','none','Tag','ChartContinuationSource');
            obj.Fields.Source.Tooltip=obj.Fields.Source.Text;
            summary=uigridlayout(root,[2 1],'Padding',0,'RowHeight',{38,28},'RowSpacing',8);
            summary.Layout.Row=3;
            obj.Fields.Summary=uilabel(summary,'Text','','FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','ChartContinuationSummary');
            passes=uigridlayout(summary,[1 2],'Padding',0,'ColumnWidth',{100,'1x'});
            passes.Layout.Row=2;
            uilabel(passes,'Text','Source pass','FontSize',13);
            obj.Fields.Pass=uidropdown(passes,'Items',{'Loading…'},'ItemsData',{''},'Value','', ...
                'FontSize',13,'Tag','ChartContinuationPass','ValueChangedFcn',@(~,~)obj.selectPass());
            obj.Fields.Explanation=uilabel(root,'Text', ...
                ['Continue selected pass keeps its selected readings and coverage. Start new pass keeps earlier history ' ...
                'and starts coverage at zero. Both choices start a new batch. The current batch and any other unfinished ' ...
                'live source batch are finished and saved first; their windows are hidden. Files selected from disk are ' ...
                'not rewritten. No reading is taken until you select Measure.'], ...
                'FontSize',13,'WordWrap','on','Interpreter','none');
            obj.Fields.Explanation.Layout.Row=4;
            obj.Fields.Explanation.Tooltip=obj.Fields.Explanation.Text;
            declarations=uigridlayout(root,[1 3],'Padding',0,'ColumnWidth',{230,'1x',230},'RowSpacing',0);
            declarations.Layout.Row=5;
            identity=uigridlayout(root,[5 2],'Padding',0,'ColumnWidth',{230,'1x'}, ...
                'RowHeight',{0,28,40,'1x',0},'RowSpacing',4,'Visible','off');
            identity.Layout.Row=6;
            obj.Fields.Identity=identity;
            obj.Fields.Declarations=uibutton(declarations,'Text','Confirm observed setup…','FontSize',13, ...
                'Tag','ChartContinuationDeclarations','ButtonPushedFcn',@(~,~)obj.toggleDeclarations());
            obj.Fields.Declarations.Layout.Column=1;
            obj.Fields.DeclarationChoice=uidropdown(identity,'Items',{'No observable declarations'}, ...
                'ItemsData',{''},'Value','','FontSize',13,'Tag','ChartContinuationDeclarationChoice', ...
                'ValueChangedFcn',@(~,~)obj.selectDeclaration());
            obj.Fields.DeclarationChoice.Layout.Row=2;obj.Fields.DeclarationChoice.Layout.Column=1;
            obj.Fields.DeclarationEnabled=uicheckbox(identity,'Text','I checked this condition on both setups', ...
                'Value',false,'FontSize',13,'Tag','ChartContinuationDeclarationEnabled', ...
                'ValueChangedFcn',@(control,~)obj.commitDeclaration(control));
            obj.Fields.DeclarationEnabled.Layout.Row=2;obj.Fields.DeclarationEnabled.Layout.Column=2;
            obj.Fields.DeclarationValue=uieditfield(identity,'text','Value','','FontSize',13, ...
                'Tag','ChartContinuationDeclarationValue','Placeholder','Enter the condition you observed', ...
                'ValueChangedFcn',@(control,~)obj.commitDeclaration(control));
            obj.Fields.DeclarationValue.Layout.Row=3;obj.Fields.DeclarationValue.Layout.Column=2;
            obj.Fields.DeclarationBoolean=uidropdown(identity, ...
                'Items',{'Choose observed condition…','Yes / present','No / absent'}, ...
                'ItemsData',{'','yes','no'},'Value','','FontSize',13, ...
                'Tag','ChartContinuationDeclarationBoolean','Visible','off', ...
                'ValueChangedFcn',@(control,~)obj.commitDeclaration(control));
            obj.Fields.DeclarationBoolean.Layout.Row=3;obj.Fields.DeclarationBoolean.Layout.Column=2;
            obj.Fields.DeclarationKnown=uilabel(identity,'Text','','FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','ChartContinuationDeclarationKnown');
            obj.Fields.DeclarationKnown.Layout.Row=3;obj.Fields.DeclarationKnown.Layout.Column=1;
            obj.Fields.IdentityHelp=uilabel(identity,'Text', ...
                ['Declare only identity or physical conditions you can check for both setups. This records ' ...
                'operator-declared evidence, not instrument readback. If a condition is unclear, start a new pass. ' ...
                'Cancel and use Read settings to inspect unobserved instrument settings.'], ...
                'FontSize',13,'WordWrap','on');obj.Fields.IdentityHelp.Layout.Row=4;
            obj.Fields.IdentityHelp.Layout.Column=[1 2];
            obj.Fields.Acknowledgment=uicheckbox(declarations,'Text', ...
                'I reviewed the reported capability or version change.', ...
                'Value',false,'FontSize',13,'Tag','ChartContinuationAcknowledgment', ...
                'ValueChangedFcn',@(~,~)obj.updateActions());
            obj.Fields.Acknowledgment.Layout.Column=2;
            obj.Fields.SourceCleanup=uibutton(declarations,'Text','Confirm cleanup...','FontSize',13, ...
                'Tag','ChartContinuationCleanup','Visible','off', ...
                'ButtonPushedFcn',@(~,~)obj.confirmSourceCleanup());
            obj.Fields.SourceCleanup.Layout.Column=3;
            obj.Fields.Differences=uitable(root,'Data',{}, ...
                'ColumnName',{'Setting','Source pass','Current setup','Assessment'}, ...
                'ColumnWidth',{150,230,230,250},'RowName',{}, ...
                'FontSize',13,'ColumnEditable',false,'Multiselect','off', ...
                'Tag','ChartContinuationDifferences','Tooltip', ...
                'Read-only comparison. Selecting a row does not select a patch or take a measurement.');
            obj.Fields.Differences.Layout.Row=6;
            obj.Fields.Decision=uitextarea(root,'Value',{''},'Editable','off', ...
                'FontSize',13,'WordWrap','on','Tag','ChartContinuationDecision');
            obj.Fields.Decision.Layout.Row=7;
            obj.Fields.Error=uilabel(root,'Text','','FontSize',13,'WordWrap','on', ...
                'Interpreter','none','Tag','ChartContinuationError');
            obj.Fields.Error.Layout.Row=8;
            buttons=uigridlayout(root,[1 4],'Padding',0,'ColumnSpacing',10, ...
                'ColumnWidth',{96,170,'1x','1x'});
            obj.Fields.Buttons=buttons;
            buttons.Layout.Row=9;
            obj.Fields.Cancel=uibutton(buttons,'Text','Cancel','FontSize',13, ...
                'Tag','ChartContinuationCancel','ButtonPushedFcn',@(~,~)obj.close());
            obj.Fields.Refresh=uibutton(buttons,'Text','Refresh comparison','FontSize',13, ...
                'Tag','ChartContinuationRefresh','ButtonPushedFcn',@(~,~)obj.refresh(obj.Fields.Refresh));
            obj.Fields.NewPass=uibutton(buttons,'Text','Start new pass','FontSize',13, ...
                'Tag','ChartContinuationNewPass','ButtonPushedFcn',@(~,~)obj.accept('new-pass'));
            obj.Fields.Continue=uibutton(buttons,'Text','Continue selected pass','FontSize',13, ...
                'FontWeight','bold','Tag','ChartContinuationContinue', ...
                'ButtonPushedFcn',@(~,~)obj.accept('continue'));
            obj.DeclarationValues=preview.declarationValues;
            obj.SelectedPassId=preview.source.passId;
            obj.present();obj.Constructed=true;obj.Figure.Visible=owner.Visible;
            obj.restoreFocus(obj.Fields.Cancel);
        end
        function delete(obj)
            if ~isempty(obj.CleanupView)&&isvalid(obj.CleanupView),delete(obj.CleanupView);end
            if isscalar(obj.Figure)&&isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn='';delete(obj.Figure);
            end
        end
    end
    methods (Access=private)
        function present(obj)
            p=obj.Preview;d=p.definition;
            obj.Fields.Title.Text=p.sourceTitle;obj.Fields.Title.Tooltip=p.sourceTitle;
            obj.Fields.Summary.Text=sprintf( ...
                '%s × %s · %d of %s measured in the selected pass · %s.', ...
                colormeasure.session.counted(d.rows,'row','rows'), ...
                colormeasure.session.counted(d.columns,'column','columns'),p.sourceCoverage, ...
                colormeasure.session.counted(p.total,'patch','patches'), ...
                colormeasure.session.counted(p.sourceAttemptCount,'retained attempt','retained attempts'));
            obj.Fields.Summary.Tooltip=obj.Fields.Summary.Text;
            passes=p.chart.passes;labels=cell(1,numel(passes));
            for n=1:numel(passes)
                labels{n}=sprintf('Pass %d · %d of %s measured',n,nnz(passes(n).selectedAttempt), ...
                    colormeasure.session.counted(p.total,'patch','patches'));
                if n==p.chart.activePass,labels{n}=[labels{n} ' · most recent active pass'];end
            end
            obj.Fields.Pass.Items=labels;obj.Fields.Pass.ItemsData={passes.id};
            obj.Fields.Pass.Value=obj.SelectedPassId;
            obj.Fields.Pass.Tooltip=['Retained pass ID: ' obj.SelectedPassId '. Selecting a pass only refreshes this preview.'];
            rows=cell(0,4);
            keys=union(p.sourceContext.requiredMaterial,p.currentContext.requiredMaterial,'stable');
            for n=1:numel(keys)
                key=keys{n};before=contextFact(p.sourceContext,key);after=contextFact(p.currentContext,key);
                assessment='Review reported facts';
                if any(strcmp({p.differences.key},key)),assessment='Different conditions';end
                if strcmp(before.certainty,'unknown')||strcmp(after.certainty,'unknown'),assessment='Not established';end
                if isfield(p.declarationValues,key),assessment='Operator-declared evidence';end
                label=colormeasure.chart.settingLabel(key);index=[];
                if ~isempty(p.declarableFacts),index=find(strcmp({p.declarableFacts.key},key),1);end
                if ~isempty(index),label=p.declarableFacts(index).label;end
                rows(end+1,:)={label,factText(before),factText(after),assessment}; %#ok<AGROW>
            end
            obj.Fields.Differences.Data=rows;
            lines={};
            if ~obj.ComparisonCurrent
                lines{end+1}='Comparison is unavailable. Refresh it successfully before continuing or starting a new pass.';
            elseif p.continueEligible
                lines{end+1}='Continue selected pass is available. Review the reported setup before choosing it.';
            elseif p.newPassEligible
                lines{end+1}='Continue selected pass is unavailable. Use a new pass to keep different or unestablished conditions separate.';
            elseif isempty(p.blockedReason)
                lines{end+1}='Continue selected pass and Start new pass are unavailable.';
            end
            if ~isempty(p.blockedReason),lines{end+1}=p.blockedReason;end
            if p.cleanupDeclarationRequired&&~obj.cleanupReady()
                lines{end+1}=['The batch that saved this chart ended while a measurement or its connection cleanup ' ...
                    'was unfinished. Select Confirm cleanup... and record your checks before continuing.'];
            elseif p.cleanupDeclarationRequired
                lines{end+1}='Cleanup checks recorded. They are saved with the new batch.';
            end
            if ~isempty(p.unknowns),lines{end+1}=['Not established: ' informationText(p.unknowns)];end
            if ~isempty(p.versionNotes),lines{end+1}=['Application or driver changes: ' informationText(p.versionNotes)];end
            obj.Fields.Decision.Value=lines;
            facts=p.declarableFacts;hasFacts=~isempty(facts);
            obj.Fields.Declarations.Visible=colormeasure.ui.onOff(hasFacts);
            if hasFacts
                obj.Fields.DeclarationChoice.Items={facts.label};obj.Fields.DeclarationChoice.ItemsData={facts.key};
                if isempty(obj.DeclarationKey)||~ismember(obj.DeclarationKey,{facts.key}),obj.DeclarationKey=facts(1).key;end
                obj.Fields.DeclarationChoice.Value=obj.DeclarationKey;
                obj.loadDeclaration();
            end
            expanded=hasFacts&&obj.DeclarationsOpen;
            obj.Fields.Declarations.Text='Confirm observed setup…';
            if expanded,obj.Fields.Declarations.Text='Show comparison';end
            obj.Fields.Identity.Visible=colormeasure.ui.onOff(expanded);
            obj.Fields.Differences.Visible=colormeasure.ui.onOff(~expanded);
            obj.Fields.Explanation.Visible=colormeasure.ui.onOff(~expanded);
            obj.Fields.DeclarationChoice.Visible=colormeasure.ui.onOff(expanded);
            obj.Fields.DeclarationEnabled.Visible=colormeasure.ui.onOff(expanded);
            obj.Fields.DeclarationKnown.Visible=colormeasure.ui.onOff(expanded);
            obj.Fields.IdentityHelp.Visible=colormeasure.ui.onOff(expanded);
            if ~expanded,obj.Fields.DeclarationValue.Visible='off';obj.Fields.DeclarationBoolean.Visible='off';end
            obj.Fields.Acknowledgment.Visible=colormeasure.ui.onOff(p.requiredAcknowledgment);
            obj.Fields.SourceCleanup.Visible=colormeasure.ui.onOff(p.cleanupDeclarationRequired);
            obj.Fields.SourceCleanup.Text='Confirm cleanup...';
            if p.cleanupDeclarationRequired&&obj.cleanupReady(),obj.Fields.SourceCleanup.Text='Cleanup checks recorded';end
            heights=obj.Fields.Root.RowHeight;
            heights{4}=64;if expanded,heights{4}=0;end
            heights{5}=0;if hasFacts||p.requiredAcknowledgment||p.cleanupDeclarationRequired,heights{5}=32;end
            obj.Fields.Root.RowHeight=heights;
            obj.updateActions();
            obj.Fields.Continue.Tooltip=strjoin(lines,newline);
            obj.Fields.NewPass.Tooltip= ...
                'Keep the saved history and begin an empty pass in a new batch. This does not measure a patch.';
            if ~p.newPassEligible,obj.Fields.NewPass.Tooltip=p.blockedReason;end
        end
        function refresh(obj,control)
            if ~obj.live()||obj.Accepting,return;end
            obj.ComparisonCurrent=false;obj.updateActions();
            try
                assert(isempty(fieldnames(obj.DeclarationErrors)), ...
                    'Measurement:ChartContinuationDeclaration','%s',obj.declarationErrorText());
                candidate=obj.Refresh(obj.DeclarationValues,obj.SelectedPassId);
                if ~isequaln(candidate.versionNotes,obj.Preview.versionNotes)|| ...
                        ~isequaln(candidate.differences,obj.Preview.differences)
                    obj.Fields.Acknowledgment.Value=false;
                end
                if ~isequaln(sourceCleanupIdentity(candidate),sourceCleanupIdentity(obj.Preview))
                    obj.clearSourceCleanup();
                end
                obj.Preview=candidate;obj.ComparisonCurrent=true;obj.present();obj.clearError();
                obj.restoreFocus(control);
            catch problem
                obj.SelectedPassId=obj.Preview.source.passId;
                obj.present();
                obj.showError(problem,control);
            end
        end
        function accept(obj,action)
            if ~obj.live()||obj.Accepting,return;end
            p=obj.Preview;
            allowed=p.newPassEligible;
            if strcmp(action,'continue'),allowed=p.continueEligible;end
            allowed=allowed&&obj.cleanupReady()&&obj.ComparisonCurrent&&isempty(fieldnames(obj.DeclarationErrors))&& ...
                isequaln(obj.DeclarationValues,p.declarationValues)&& ...
                strcmp(obj.SelectedPassId,p.source.passId)&& ...
                (~strcmp(action,'continue')||~p.requiredAcknowledgment||obj.Fields.Acknowledgment.Value);
            if ~allowed,return;end
            obj.Accepting=true;
            obj.Fields.Continue.Enable='off';obj.Fields.NewPass.Enable='off';
            obj.Fields.Refresh.Enable='off';obj.Fields.Cancel.Enable='off';
            try
                cleanup='';if p.cleanupDeclarationRequired,cleanup=obj.SourceCleanup;end
                obj.Apply(p,action,p.declarationValues,obj.Fields.Acknowledgment.Value,cleanup);
                if ~obj.live(),return;end
                obj.Accepting=false;obj.close();
            catch problem
                if ~obj.live(),return;end
                obj.Accepting=false;obj.ComparisonCurrent=false;obj.present();
                obj.Fields.Refresh.Enable='on';obj.Fields.Cancel.Enable='on';
                obj.showError(problem,obj.Fields.Refresh);
            end
        end
        function showError(obj,problem,control)
            if ~obj.live(),return;end
            obj.Fields.Error.Text=problem.message;obj.Fields.Error.Tooltip=problem.message;
            obj.restoreFocus(control);
        end
        function updateActions(obj)
            if ~obj.live(),return;end
            p=obj.Preview;acknowledged=~p.requiredAcknowledgment||obj.Fields.Acknowledgment.Value;
            valid=obj.ComparisonCurrent&&obj.cleanupReady()&&isempty(fieldnames(obj.DeclarationErrors))&& ...
                isequaln(obj.DeclarationValues,p.declarationValues)&&strcmp(obj.SelectedPassId,p.source.passId);
            obj.Fields.Continue.Enable=colormeasure.ui.onOff(p.continueEligible&&valid&&acknowledged&&~obj.Accepting);
            obj.Fields.NewPass.Enable=colormeasure.ui.onOff(p.newPassEligible&&valid&&~obj.Accepting);
        end
        function yes=cleanupReady(obj)
            yes=~obj.Preview.cleanupDeclarationRequired|| ...
                (~isempty(obj.SourceCleanup)&&isequaln(obj.SourceCleanupIdentity,sourceCleanupIdentity(obj.Preview)));
        end
        function confirmSourceCleanup(obj)
            if ~obj.live()||obj.Accepting||~obj.Preview.cleanupDeclarationRequired,return;end
            if ~isempty(obj.CleanupView)&&isvalid(obj.CleanupView),figure(obj.CleanupView.Figure);return;end
            identity=sourceCleanupIdentity(obj.Preview);
            obj.CleanupView=colormeasure.ui.ChartCleanupView(obj.Figure, ...
                ['The batch that saved this chart ended while a measurement or its connection cleanup was unfinished, ' ...
                'and it is no longer open.'],@(text)obj.recordSourceCleanup(text,identity),[]);
        end
        function saved=recordSourceCleanup(obj,text,identity)
            % Retained only in this preview until acceptance saves the new batch.
            assert(obj.live()&&~obj.Accepting&&obj.Preview.cleanupDeclarationRequired&& ...
                isequaln(identity,sourceCleanupIdentity(obj.Preview)), ...
                'Measurement:ChartContinuationSource', ...
                'The source changed after cleanup checks began. Refresh the comparison and confirm cleanup for the current source.');
            obj.SourceCleanup=text;obj.SourceCleanupIdentity=identity;saved=true;obj.present();
        end
        function clearSourceCleanup(obj)
            previous=obj.CleanupView;obj.CleanupView=[];
            obj.SourceCleanup='';obj.SourceCleanupIdentity=struct([]);
            if ~isempty(previous)&&isvalid(previous),delete(previous);end
        end
        function toggleDeclarations(obj)
            if ~obj.live()||obj.Accepting,return;end
            obj.DeclarationsOpen=~obj.DeclarationsOpen;obj.present();
            if obj.DeclarationsOpen,obj.restoreFocus(obj.Fields.DeclarationChoice);end
        end
        function selectDeclaration(obj)
            if ~obj.live()||obj.Accepting,return;end
            obj.DeclarationKey=obj.Fields.DeclarationChoice.Value;obj.loadDeclaration();
        end
        function selectPass(obj)
            if ~obj.live()||obj.Accepting,return;end
            obj.SelectedPassId=obj.Fields.Pass.Value;
            obj.Fields.Acknowledgment.Value=false;
            obj.DeclarationValues=struct();obj.DeclarationText=struct();obj.DeclarationErrors=struct();
            obj.updateActions();obj.refresh(obj.Fields.Pass);
        end
        function loadDeclaration(obj)
            key=obj.DeclarationKey;facts=obj.Preview.declarableFacts;
            index=find(strcmp({facts.key},key),1);if isempty(index),return;end
            fact=facts(index);
            enabled=isfield(obj.DeclarationValues,key)||isfield(obj.DeclarationErrors,key);
            obj.Fields.DeclarationEnabled.Value=enabled;
            text='';if isfield(obj.DeclarationText,key),text=obj.DeclarationText.(key);
            elseif isfield(obj.DeclarationValues,key),text=informationText(obj.DeclarationValues.(key));end
            obj.Fields.DeclarationValue.Value=text;obj.Fields.DeclarationValue.Enable='on';
            obj.Fields.DeclarationBoolean.Value='';
            if isfield(obj.DeclarationValues,key)&&islogical(obj.DeclarationValues.(key))
                choice='no';if obj.DeclarationValues.(key),choice='yes';end
                obj.Fields.DeclarationBoolean.Value=choice;
            elseif isfield(obj.DeclarationText,key)&&ismember(obj.DeclarationText.(key),{'yes','no'})
                obj.Fields.DeclarationBoolean.Value=obj.DeclarationText.(key);
            end
            obj.Fields.DeclarationBoolean.Enable='on';
            logicalValue=strcmp(fact.valueType,'logical');
            obj.Fields.DeclarationValue.Visible=colormeasure.ui.onOff(obj.DeclarationsOpen&&~logicalValue);
            obj.Fields.DeclarationBoolean.Visible=colormeasure.ui.onOff(obj.DeclarationsOpen&&logicalValue);
            obj.Fields.DeclarationKnown.Text=sprintf('Saved: %s\nCurrent: %s', ...
                informationText(fact.sourceValue),informationText(fact.targetValue));
            obj.Fields.DeclarationKnown.Tooltip=obj.Fields.DeclarationKnown.Text;
        end
        function commitDeclaration(obj,control)
            if ~obj.live()||obj.Accepting,return;end
            key=obj.DeclarationKey;facts=obj.Preview.declarableFacts;
            index=find(strcmp({facts.key},key),1);if isempty(index),return;end
            fact=facts(index);
            text=obj.Fields.DeclarationValue.Value;
            if strcmp(fact.valueType,'logical'),text=obj.Fields.DeclarationBoolean.Value;end
            obj.DeclarationText.(key)=text;
            if isfield(obj.DeclarationErrors,key),obj.DeclarationErrors=rmfield(obj.DeclarationErrors,key);end
            if ~obj.Fields.DeclarationEnabled.Value
                if isfield(obj.DeclarationValues,key),obj.DeclarationValues=rmfield(obj.DeclarationValues,key);end
            else
                value=strtrim(text);valid=~isempty(value);
                if strcmp(fact.valueType,'number')
                    value=colormeasure.ui.parseNumber(text);valid=~isnan(value);
                elseif strcmp(fact.valueType,'logical')
                    selection=obj.Fields.DeclarationBoolean.Value;valid=ismember(selection,{'yes','no'});
                    if valid,value=strcmp(selection,'yes');end
                end
                if valid,obj.DeclarationValues.(key)=value;
                else
                    if isfield(obj.DeclarationValues,key),obj.DeclarationValues=rmfield(obj.DeclarationValues,key);end
                    help='enter the observed value.';
                    if strcmp(fact.valueType,'number'),help='enter a finite number. Use a period for decimals, without commas.';
                    elseif strcmp(fact.valueType,'logical'),help='choose Yes / present or No / absent explicitly.';end
                    obj.DeclarationErrors.(key)=[fact.label ': ' help];
                end
            end
            obj.loadDeclaration();obj.updateActions();
            if ~isempty(fieldnames(obj.DeclarationErrors))
                obj.Fields.Error.Text=obj.declarationErrorText();obj.Fields.Error.Tooltip=obj.Fields.Error.Text;
            else
                obj.refresh(control);
            end
        end
        function text=declarationErrorText(obj)
            text=strjoin(struct2cell(obj.DeclarationErrors),newline);
        end
        function clearError(obj)
            obj.Fields.Error.Text='';obj.Fields.Error.Tooltip='';
        end
        function keyPress(obj,event)
            % Return/Space belongs to the focused native control. The close key
            % closes the preview; it never accepts continuation or measures.
            if obj.live()&&colormeasure.ui.isCloseKey(event),obj.close();end
        end
        function yes=live(obj)
            yes=isvalid(obj)&&isscalar(obj.Figure)&&isgraphics(obj.Figure)&& ...
                isscalar(obj.Owner)&&isgraphics(obj.Owner);
        end
        function restoreFocus(obj,control)
            if obj.live()&&strcmp(obj.Owner.Visible,'on')&&colormeasure.ui.canFocus(control,obj.Figure)
                figure(obj.Figure);focus(control);
            end
        end
        function close(obj)
            if ~isvalid(obj)||obj.Accepting,return;end
            closed=obj.Closed;delete(obj);
            if ~isempty(closed),closed();end
        end
        function cleanupPartial(obj)
            if ~obj.Constructed,delete(obj);end
        end
    end
end

function identity=sourceCleanupIdentity(preview)
% Pass selection does not change the saved source or its uncertainty owner.
identity=struct('segmentId',preview.source.segmentId,'runId',preview.source.runId, ...
    'sourceSha256',preview.source.sourceSha256,'required',preview.cleanupDeclarationRequired, ...
    'retainedUncertainty',preview.sourceData.retainedUncertainty);
end

function text=factText(fact)
if strcmp(fact.certainty,'unknown'),text='Not established';return;end
text=informationText(fact.value);
text=sprintf('%s (%s)',text,strrep(fact.certainty,'_',' '));
end
function fact=contextFact(context,key)
fact=struct('value',[],'certainty','unknown');
if isfield(context.material,key),fact=context.material.(key);end
end
function text=informationText(value)
if isempty(value),text='Not reported';
elseif ischar(value),text=value;
elseif isstring(value)||iscellstr(value),text=strjoin(cellstr(value),'; ');
elseif isnumeric(value)||islogical(value),text=mat2str(value);
elseif isstruct(value)
    keys=fieldnames(value);parts=cell(1,numel(value));
    for n=1:numel(value)
        fields=cell(1,numel(keys));
        for k=1:numel(keys),fields{k}=[colormeasure.chart.settingLabel(keys{k}) ': ' informationText(value(n).(keys{k}))];end
        parts{n}=strjoin(fields,'; ');
    end
    text=strjoin(parts,' | ');
elseif iscell(value),text=strjoin(cellfun(@informationText,value,'UniformOutput',false),'; ');
else,text=char(string(value));
end
end

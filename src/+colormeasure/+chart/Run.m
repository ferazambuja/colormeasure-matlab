classdef Run < handle
    % RUN Guided-chart identity, attempts and selected reading references.
    % Session is the sole owner. Snapshots contain ordinary data only; there
    % is no acquisition or UI logic here. Cell indices use row-major-v1.
    properties (Constant)
        MaxDeclarationCodeUnits=2048
        % The separately retained full frontend saves 'guided-chart' format 6.
        % Skip 6 when this changes, so each product refuses the other's charts
        % by version before reading their different pass and context fields.
        FormatVersion=5
        MaxInheritedSegments=16
    end
    properties (SetAccess=private)
        Snapshot
    end
    methods
        function obj=Run(definition,segmentId,context)
            definition=colormeasure.chart.validateDefinition(definition);
            obj.Snapshot=struct('format','guided-chart','version',obj.FormatVersion, ...
                'runId',uuid(),'segmentId',segmentId,'definition',definition, ...
                'parentSegmentId','','sources',colormeasure.chart.emptySources(), ...
                'referenceData',colormeasure.chart.referenceData(definition), ...
                'orientation',0,'traversal','row-major-v1','currentCell',[1 1], ...
                'paused',false,'activePass',1,'passes',newPass(context,numel(definition.cells)), ...
                'pendingContext',struct([]),'revision',1,'savedRevision',0);
        end
        function changed=select(obj,row,column)
            validateattributes(row,{'numeric'},{'real','finite','scalar','integer','positive','<=',obj.Snapshot.definition.rows});
            validateattributes(column,{'numeric'},{'real','finite','scalar','integer','positive','<=',obj.Snapshot.definition.columns});
            cell=double([row column]);
            % Re-activation is inspection, not a saved chart-state change.
            changed=~isequal(obj.Snapshot.currentCell,cell);
            if ~changed,return;end
            obj.Snapshot.currentCell=cell;obj.touch();
        end
        function rotate(obj,degrees)
            assert(isnumeric(degrees)&&isscalar(degrees)&&isreal(degrees)&& ...
                isfinite(degrees)&&ismember(degrees,[0 90 180 270]), ...
                'Measurement:ChartOrientation','Use orientation 0, 90, 180 or 270 degrees.');
            obj.Snapshot.orientation=double(degrees);obj.touch();
        end
        function pause(obj,paused)
            obj.Snapshot.paused=paused;obj.touch();
        end
        function changed=checkContext(obj,context)
            pass=obj.pass();difference=colormeasure.chart.contextDifference(pass.context,context);
            changed=~isempty(difference);
            if ~changed
                pending=obj.Snapshot.pendingContext;
                if ~isempty(pending)&&~isfield(pending,'requiresDecision')&&strcmp(pending.proposed.phase,'intended')
                    obj.Snapshot.pendingContext=struct([]);obj.touch();
                end
                return
            end
            if isempty(pass.attempts)
                obj.Snapshot.passes(obj.Snapshot.activePass).context=context;
            else
                pending=obj.Snapshot.pendingContext;
                proposed=struct('previous',pass.context, ...
                    'proposed',context,'differences',difference,'reason','Acquisition context changed.');
                if ~isempty(pending)&&isfield(pending,'requiresDecision')
                    proposed.requiresDecision=true;
                    proposed.reason=pending.reason;
                    if isfield(pending,'interpretationError'),proposed.interpretationError=true;end
                end
                if isequaln(pending,proposed),return;end
                obj.Snapshot.pendingContext=proposed;
            end
            obj.touch();
        end
        function acceptContext(obj)
            assert(~isempty(obj.Snapshot.pendingContext),'Measurement:ChartContext','No chart context change is pending.');
            obj.Snapshot.passes(end+1)=newPass(obj.Snapshot.pendingContext.proposed,numel(obj.Snapshot.definition.cells));
            obj.Snapshot.activePass=numel(obj.Snapshot.passes);
            obj.Snapshot.currentCell=[1 1];obj.Snapshot.pendingContext=struct([]);obj.touch();
        end
        function index=begin(obj,context,name,notes,time)
            assert(~obj.Snapshot.paused&&isempty(obj.Snapshot.pendingContext), ...
                'Measurement:ChartContext','Resume the chart and resolve its context before acquisition.');
            obj.checkContext(context);
            assert(isempty(obj.Snapshot.pendingContext),'Measurement:ChartContext', ...
                'Acquisition settings changed. Start a new chart pass or return to free samples.');
            pass=obj.pass();cellIndex=obj.cellIndex();
            attempt=struct('cellIndex',cellIndex,'row',obj.Snapshot.currentCell(1), ...
                'column',obj.Snapshot.currentCell(2),'context',context, ...
                'acceptedContext',struct([]),'name',name,'notes',notes, ...
                'startedAtUTC',time,'completedAtUTC','','status','started','reason','', ...
                'readingIndices',[],'segmentId',obj.Snapshot.segmentId);
            pass.attempts(end+1)=attempt;index=numel(pass.attempts);
            obj.Snapshot.passes(obj.Snapshot.activePass)=pass;obj.touch();
        end
        function rejectContext(obj,index,readings,reason,time)
            % Keep acquired data references without inventing accepted facts.
            pass=obj.pass();attempt=pass.attempts(index);
            attempt.readingIndices=readings;attempt.status='unresolved';attempt.reason=reason;
            attempt.acceptedContext=struct([]);attempt.completedAtUTC=time;
            pass.attempts(index)=attempt;obj.Snapshot.passes(obj.Snapshot.activePass)=pass;
            obj.Snapshot.pendingContext=struct('previous',pass.context,'proposed',attempt.context, ...
                'differences',struct([]),'reason',reason,'requiresDecision',true,'interpretationError',true);
            obj.touch();
        end
        function complete(obj,index,readings,status,reason,context,time)
            pass=obj.pass();attempt=pass.attempts(index);
            if ~strcmp(attempt.status,'started'),return;end % Persistence retry is idempotent.
            attempt.readingIndices=readings;attempt.status=status;attempt.reason=reason;
            attempt.acceptedContext=context;attempt.completedAtUTC=time;
            difference=colormeasure.chart.contextDifference(attempt.context,context);
            baseline=colormeasure.chart.contextDifference(pass.context,context);
            missing=~ismember({baseline.key},{difference.key});difference=[difference baseline(missing)];
            % Returned settings/identity must not silently fill an incompatible pass.
            [eligible,eligibilityReason]=colormeasure.chart.eligibility(context);
            if strcmp(status,'completed')&&~isempty(obj.Snapshot.sources)&& ...
                    strcmp(obj.Snapshot.continuation.action,'continue')&& ...
                    strcmp(pass.id,obj.Snapshot.continuation.sourcePassId)
                continuity=colormeasure.chart.continuity(pass.context,context,obj.Snapshot.continuation.declarations);
                if ~continuity.continueEligible
                    eligible=false;
                    eligibilityReason='Reading retained; inherited coverage requires known matching acquisition facts. Start a new pass.';
                    difference=[difference continuity.differences];
                end
            end
            if strcmp(status,'completed')&&(~isempty(difference)||~eligible)
                attempt.status='unresolved';attempt.reason='Returned acquisition context differs; choose a new pass before continuing.';
                if ~eligible,attempt.reason=eligibilityReason;end
                obj.Snapshot.pendingContext=struct('previous',pass.context,'proposed',context,'differences',difference,'reason','Acquisition context changed.');
            end
            if strcmp(attempt.status,'completed')&&isscalar(readings)
                pass.selectedAttempt(attempt.cellIndex)=index;
                pass.context=context;
            elseif strcmp(attempt.status,'completed')
                attempt.status='unresolved';attempt.reason='A chart spot must return exactly one reading.';
                obj.Snapshot.pendingContext=struct('previous',pass.context,'proposed',context, ...
                    'differences',struct([]),'reason',attempt.reason);
            end
            if strcmp(attempt.status,'unresolved')&&isempty(obj.Snapshot.pendingContext)
                obj.Snapshot.pendingContext=struct('previous',pass.context,'proposed',context, ...
                    'differences',struct([]),'reason',attempt.reason);
            end
            if strcmp(attempt.status,'unresolved'),obj.Snapshot.pendingContext.requiresDecision=true;end
            pass.attempts(index)=attempt;obj.Snapshot.passes(obj.Snapshot.activePass)=pass;
            if strcmp(attempt.status,'completed')
                missing=find(pass.selectedAttempt==0);
                after=missing(missing>attempt.cellIndex);
                if ~isempty(after),next=after(1);elseif ~isempty(missing),next=missing(1);else,next=attempt.cellIndex;end
                obj.Snapshot.currentCell=[floor((next-1)/obj.Snapshot.definition.columns)+1,mod(next-1,obj.Snapshot.definition.columns)+1];
            end
            obj.touch();
        end
        function value=pass(obj)
            value=obj.Snapshot.passes(obj.Snapshot.activePass);
        end
        function cells=cells(obj,passIndex)
            % Derived, read-only coverage for inspection of any retained pass.
            validateattributes(passIndex,{'numeric'},{'scalar','real','finite','integer','positive','<=',numel(obj.Snapshot.passes)});
            pass=obj.Snapshot.passes(passIndex);definition=obj.Snapshot.definition;
            cells=repmat(struct('row',0,'column',0,'coordinate','','status','empty', ...
                'selectedAttempt',0,'readingIndex',NaN,'segmentId','','inherited',false,'latestAttemptStatus','', ...
                'inheritedAttemptCount',0,'newAttemptCount',0,'attemptCount',0,'reason',''),1,numel(definition.cells));
            for index=1:numel(cells)
                cell=definition.cells(index);attempts=find([pass.attempts.cellIndex]==index);
                selected=pass.selectedAttempt(index);
                item=cells(index);item.row=cell.row;item.column=cell.column;item.coordinate=cell.coordinate;
                item.selectedAttempt=selected;item.attemptCount=numel(attempts);
                if ~isempty(attempts)
                    inherited=~strcmp({pass.attempts(attempts).segmentId},obj.Snapshot.segmentId);
                    item.inheritedAttemptCount=nnz(inherited);item.newAttemptCount=nnz(~inherited);
                end
                if selected>0
                    item.status='measured';item.readingIndex=pass.attempts(selected).readingIndices(1);
                    item.segmentId=pass.attempts(selected).segmentId;
                    item.inherited=~strcmp(item.segmentId,obj.Snapshot.segmentId);
                end
                if ~isempty(attempts)
                    item.reason=pass.attempts(attempts(end)).reason;
                    item.latestAttemptStatus=pass.attempts(attempts(end)).status;
                end
                % Only the segment that started an attempt can complete it.
                % An inherited started attempt ended without a retained reading.
                if strcmp(item.latestAttemptStatus,'started')&&~strcmp(pass.attempts(attempts(end)).segmentId,obj.Snapshot.segmentId)
                    item.latestAttemptStatus='interrupted';
                    item.reason='The earlier batch ended before this attempt completed; no reading was retained.';
                end
                if selected==0&&~isempty(attempts),item.status=item.latestAttemptStatus;end
                cells(index)=item;
            end
        end
        function value=cellIndex(obj)
            value=(obj.Snapshot.currentCell(1)-1)*obj.Snapshot.definition.columns+obj.Snapshot.currentCell(2);
        end
        function markSaved(obj)
            obj.Snapshot.savedRevision=obj.Snapshot.revision;
        end
        function touch(obj)
            obj.Snapshot.revision=obj.Snapshot.revision+1;
        end
    end
    methods (Static)
        function obj=fromContinuation(chart,source,segmentId,context,action,declarations,passIndex)
            % The source envelope is frozen before this fresh owner exists.
            obj=colormeasure.chart.Run(chart.definition,segmentId,context);
            value=chart;value.segmentId=segmentId;value.parentSegmentId=source.segmentId;
            value.sources=[chart.sources source];
            value.pendingContext=struct([]);value.paused=false;
            value.activePass=passIndex;
            if passIndex~=chart.activePass
                selected=chart.passes(passIndex).selectedAttempt;cell=find(selected==0,1);
                if isempty(cell),cell=1;end
                value.currentCell=[floor((cell-1)/value.definition.columns)+1,mod(cell-1,value.definition.columns)+1];
            end
            value.revision=chart.revision+1;value.savedRevision=0;
            value.continuation=struct('sourceSegmentId',source.segmentId, ...
                'sourcePassId',chart.passes(passIndex).id,'action',action,'declarations',declarations);
            decision=colormeasure.chart.continuity(chart.passes(passIndex).context,context,declarations);
            value.continuation.declarationEvidence=decision.declarations;
            value.continuation.sourcePendingPassId=chart.passes(chart.activePass).id;
            value.continuation.sourcePendingContext=chart.pendingContext;
            if strcmp(action,'new-pass')
                value.passes(end+1)=newPass(context,numel(value.definition.cells));
                value.activePass=numel(value.passes);value.currentCell=[1 1];
            end
            obj.Snapshot=value;
        end
    end
end
function pass=newPass(context,count)
pass=struct('id',uuid(),'context',context,'attempts',struct('cellIndex',{},'row',{},'column',{}, ...
    'context',{},'acceptedContext',{},'name',{},'notes',{},'startedAtUTC',{},'completedAtUTC',{}, ...
    'status',{},'reason',{},'readingIndices',{},'segmentId',{}), ...
    'selectedAttempt',zeros(1,count));
end
function value=uuid()
value=char(java.util.UUID.randomUUID());
end

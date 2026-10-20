classdef Session < handle
    % SESSION Live, instrument-neutral batch with explicit acquisition actions.
    %   Construction does not wait for UI input. Methods are also callable from
    %   the Command Window; measurements and info remain ordinary MATLAB structs.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = private)
        measurements = struct([])
        files = struct('folder', '', 'mat', '', 'csv', '', 'chartCsv', '', 'previousFolders', {{}})
        savedCount = 0
        name = 'Sample 001'
        notes = ''
        sampleRevision = 0
        annotationRevision = 0
        readingAnnotations = struct('readingIndex',{}, ...
            'originalName',{},'originalNotes',{},'name',{},'notes',{},'editedAtUTC',{})
        port = ''
        ports = strings(0, 1)
        label
        startedAtUTC
        startedAtLocal = ''
        localTimeZone = ''
        finishing = false
        finished = false
        saving = false
        log = struct('timeUTC', {}, 'level', {}, 'message', {})
        activity = 'No port available'
        saveError = ''
        exportError = ''
        settingsOverrides = struct()
        settingsSnapshot = struct([])
        lastSettingsReceipt = struct([])
    end
    properties (Dependent, SetAccess = private)
        busy
        info
        status
        needsRecovery
        chartCsvNeedsRetry
        companionRecoveryAvailable
        window
        destination
        saveParent
        configuration
        workspaceName
        adapterKey
        preparation
        settingsCatalog
        chartIoUnconfirmed
        directCleanupCanRetry
        services
        catalogIdentity
        chart
    end
    properties (Access = private)
        Adapter
        Busy = false
        IO
        Parent
        View = []
        FinishRequested = false
        MatFinalized = false
        PendingPrevious = {}
        SavedAnnotationRevision = 0
        SegmentId
        ChartRun = []
        ChartAttempt = 0
        ChartIoUnconfirmed = false
        ChartIoConfirmations = struct('segmentId',{},'runId',{},'confirmedAtUTC',{}, ...
            'declaration',{},'connectionClosed',{},'instrumentIdle',{})
        ChartFreeSample = struct('name','Sample 001','notes','')
        ChartNotes = ''
        ChartCsvRevision = -1
        ChartCsvDigest = ''
        ChartCsvAuthenticated = false
        ChartExportError = ''
        ChartCsvRetryable = false
        ChartCsvRelocatable = false
        CompanionSourceChanged = false
        FinishChartAllowed = false
        SavedSnapshot = []
        ContinuationOwner = []
        ContinuationTargetReading = struct([])
        DirectInstrument = []
        DirectRelease = []
        DirectReleaseAttempted = false
        SavedCleanupCount = 0
    end
    events
        Changed
    end
    methods


        function yes=get.chartCsvNeedsRetry(obj)
            yes=~isempty(obj.ChartExportError)&&obj.ChartCsvRetryable;
        end
        function yes=get.companionRecoveryAvailable(obj)
            % Only causes that a new saved destination can resolve offer it.
            yes=obj.ChartCsvRelocatable||obj.CompanionSourceChanged;
        end


        function value=get.chartIoUnconfirmed(obj)
            % Retained I/O intent is distinct from saving/export recovery.
            value=obj.ChartIoUnconfirmed||~isempty(obj.DirectRelease);
        end
        function yes=get.directCleanupCanRetry(obj)
            % Inspect retained ownership only; do not reconnect or query I/O.
            yes=~isempty(obj.DirectRelease)&&~isempty(obj.DirectInstrument);
            if yes&&isa(obj.DirectInstrument,'handle'),yes=isvalid(obj.DirectInstrument);end
            if yes&&isa(obj.DirectInstrument,'handle')&&ismethod(obj.DirectInstrument,'canRetryConnectionCleanup')
                yes=obj.DirectInstrument.canRetryConnectionCleanup();
            end
        end


        function value=get.services(obj)
            value=obj.IO;
        end

        function value=get.catalogIdentity(obj)
            % The catalog entry this batch belongs to, as the adapter declares it.
            value=struct('model','','mode','','key',obj.Adapter.key);
            if isfield(obj.Adapter,'catalog')
                value.model=char(obj.Adapter.catalog.model);
                value.mode=char(obj.Adapter.catalog.mode);
            end
        end

        function value=get.chart(obj)
            % Ordinary read-only chart state; Session owns every association.
            value=struct([]);
            if isempty(obj.ChartRun),return;end
            value=obj.chartSnapshot();
            pass=obj.ChartRun.pass();
            count=numel(value.definition.cells);
            value.total=count;value.coverage=nnz(pass.selectedAttempt);
            for p=1:numel(value.passes)
                value.passes(p).coverage=nnz(value.passes(p).selectedAttempt);
                value.passes(p).cells=obj.ChartRun.cells(p);
            end
            value.unsaved=value.revision~=value.savedRevision;
            value.csvRevision=obj.ChartCsvRevision;value.csvCurrent=obj.chartCsvCurrent();
            value.csvUnavailableReason=obj.ChartExportError;
            % Rendering uses retained direct facts without instrument I/O.
            [value.eligible,value.reason]=colormeasure.chart.eligibility(pass.context);
            value.cells=value.passes(value.activePass).cells;
            if ~isempty(value.pendingContext)
                value.eligible=false;value.reason='Acquisition context changed. Start a new pass or return to free samples.';
            elseif value.unsaved && ~isempty(obj.saveError)
                value.eligible=false;value.reason='Save the retained chart before continuing.';
            end
        end

        function saved=startChart(obj,definition)
            arguments
                obj
                definition (1,1) struct
            end
            obj.assertChartEditable(false);
            definition=colormeasure.chart.validateDefinition(definition);
            obj.assertChartReplaceable();
            context=obj.chartContext();[eligible,reason]=colormeasure.chart.eligibility(context);
            assert(eligible,'Measurement:ChartIneligible','%s',reason);
            % Complete construction and validation before mutating the draft.
            run=colormeasure.chart.Run(definition,obj.SegmentId,context);
            if isempty(obj.ChartRun)||obj.ChartRun.Snapshot.paused,obj.ChartFreeSample=struct('name',obj.name,'notes',obj.notes);end
            obj.ChartNotes=obj.notes;
            obj.ChartRun=run;
            obj.ChartCsvRevision=-1;
            obj.useChartName();saved=obj.saveChartState();
        end

        function preview=prepareChartContinuation(obj,source,options)
            % Preview is read-only. A source path never restores connections,
            % callbacks or processes; final acceptance consumes this witness.
            arguments
                obj
                source
                options.Declarations (1,1) struct=struct()
                options.PassId (1,:) char=''
            end
            obj.assertContinuationOwnerReady();
            data=colormeasure.chart.continuationSource(source);
            target=obj.continuationContext();
            passIndex=data.chart.activePass;
            if ~isempty(options.PassId),passIndex=find(strcmp({data.chart.passes.id},options.PassId));end
            assert(isscalar(passIndex),'Measurement:ChartContinuationSource','Choose one retained source pass.');
            pass=data.chart.passes(passIndex);
            decision=chartPassContinuity(pass,target,options.Declarations);
            [eligible,reason]=colormeasure.chart.eligibility(target);
            [blocked,cleanupRequired]=obj.continuationBlock(data);
            if isempty(blocked)&&numel(data.chart.sources)>=colormeasure.chart.Run.MaxInheritedSegments
                blocked=sprintf('This chart already contains the maximum %d inherited segments. Inspect it or start a separate chart.', ...
                    colormeasure.chart.Run.MaxInheritedSegments);
            end
            if isempty(blocked)&&~eligible,blocked=reason;end
            preview=decision;
            preview.source=struct('segmentId',data.chart.segmentId,'runId',data.chart.runId, ...
                'revision',data.chart.revision,'sourceSha256',data.sourceSha256,'passId',pass.id);
            preview.chart=data.chart;preview.definition=data.definition;
            preview.sourceCoverage=nnz(pass.selectedAttempt);preview.total=numel(data.definition.cells);
            preview.sourceAttemptCount=numel(pass.attempts);
            preview.sourceTitle=data.definition.name;preview.blockedReason=blocked;
            preview.cleanupDeclarationRequired=cleanupRequired;
            preview.continueEligible=decision.continueEligible&&isempty(blocked);
            if ~isempty(colormeasure.chart.pendingDecision(data.chart,pass.id))
                preview.continueEligible=false;
                preview.unknowns{end+1}='The selected source pass retains an unresolved acquisition-context decision. Start a new empty pass.';
            end
            preview.newPassEligible=eligible&&isempty(blocked);
            preview.sourceInput=source;preview.sourceData=data;
            preview.sourceContext=pass.context;preview.currentContext=target;
            preview.sourcePassIndex=passIndex;
            preview.targetOwner=obj;
            preview.targetToken=obj.continuationToken();
            preview.declarationValues=options.Declarations;
        end

        function saved=confirmChartIoStopped(obj,options)
            % An explicit direct-owner declaration resolves uncertainty; it
            % neither operates the instrument nor certifies physical cleanup.
            arguments
                obj
                options.ConfirmConnectionClosed (1,1) logical=false
                options.ConfirmInstrumentIdle (1,1) logical=false
                options.Declaration = ''
            end
            assert(~obj.busy&&obj.chartIoUnconfirmed, ...
                'Measurement:ConnectionCleanup','An idle direct batch with unconfirmed I/O is required.');
            assert(~obj.directCleanupCanRetry,'Measurement:ConnectionCleanup', ...
                'Retry cleanup through the retained connection owner before making a manual declaration.');
            assert(options.ConfirmConnectionClosed&&options.ConfirmInstrumentIdle, ...
                'Measurement:ConnectionCleanup','Confirm the connection is closed and the instrument is idle.');
            declaration=colormeasure.chart.declarationText(options.Declaration,'Cleanup declaration', ...
                'Measurement:ConnectionCleanup');
            if obj.finished
                obj.Busy=true;obj.activity='Retaining cleanup declaration';obj.changed();
            else
                assert(obj.beginOperation('Retaining cleanup declaration'),'Measurement:ConnectionCleanup', ...
                    'Wait for the current action before confirming cleanup.');
            end
            cleanup=onCleanup(@()obj.endOperation());
            runId='';if ~isempty(obj.ChartRun),runId=obj.ChartRun.Snapshot.runId;end
            obj.ChartIoConfirmations(end+1)=struct('segmentId',obj.SegmentId,'runId',runId, ...
                'confirmedAtUTC',colormeasure.session.utcText(obj.IO.now()),'declaration',declaration, ...
                'connectionClosed',true,'instrumentIdle',true);
            obj.DirectInstrument=[];obj.DirectRelease=[];obj.DirectReleaseAttempted=false;
            obj.ChartIoUnconfirmed=false;obj.MatFinalized=false;
            obj.addLog('warning','Connection cleanup retained as an operator declaration; no instrument validation was performed.');
            saved=obj.persistMat();obj.activity=obj.idleActivity();obj.changed();
        end

        function saved=retryDirectCleanup(obj)
            % Retry only this retained owner's release, never acquisition.
            assert(~obj.busy&&obj.directCleanupCanRetry,'Measurement:ConnectionCleanup', ...
                'An idle retained connection owner is required for cleanup retry.');
            obj.Busy=true;obj.activity='Retrying connection cleanup';obj.changed();
            cleanup=onCleanup(@()obj.endOperation());
            obj.releaseDirectInstrument(false);
            obj.MatFinalized=false;saved=obj.persistMat();obj.activity=obj.idleActivity();obj.changed();
        end

        function receiver=freshChartContinuationSession(obj)
            % Construct an unpublished direct owner only after the UI has consent.
            obj.assertContinuationOwnerReady();
            receiver=colormeasure.session.Session(obj.Adapter,obj.Parent,obj.IO);
            receiver.ContinuationOwner=obj;
            receiver.port=obj.port;receiver.settingsOverrides=obj.settingsOverrides;
            receiver.settingsSnapshot=obj.settingsSnapshot;receiver.lastSettingsReceipt=obj.lastSettingsReceipt;
            if ~isempty(obj.measurements),receiver.ContinuationTargetReading=obj.measurements(end);end
        end

        function [saved,session]=acceptChartContinuation(obj,preview,options)
            % One new segment owns future acquisitions. Ancestors stay frozen
            % in ordinary data; a failed save uses retrySave without reattaching.
            arguments
                obj
                preview (1,1) struct
                options.Action (1,:) char='continue'
                options.Declarations (1,1) struct=struct()
                options.AcknowledgeVersionChange (1,1) logical=false
                options.ConfirmConnectionClosed (1,1) logical=false
                options.ConfirmInstrumentIdle (1,1) logical=false
                options.CleanupDeclaration=''
            end
            identifier='Measurement:ChartContinuationStale';
            assert(any(strcmp(options.Action,{'continue','new-pass'})), ...
                'Measurement:ChartContinuationAction','Choose continue or new-pass.');
            obj.assertContinuationOwnerReady();
            assert(isempty(obj.measurements)&&isempty(obj.ChartRun)&& ...
                ~obj.finished&&~obj.finishing&&isempty(obj.files.folder), ...
                'Measurement:ChartContinuationReceiver','Use a fresh unpublished session with no retained readings or chart.');
            required={'sourceInput','sourceData','sourcePassIndex','source','targetOwner','targetToken','declarationValues'};
            assert(all(isfield(preview,required))&&isa(preview.targetOwner,'colormeasure.session.Session')&& ...
                isvalid(preview.targetOwner)&&~isempty(obj.ContinuationOwner)&& ...
                obj.ContinuationOwner==preview.targetOwner, ...
                identifier,'The continuation preview belongs to another target. Preview it again.');
            owner=obj.ContinuationOwner;owner.assertContinuationOwnerReady();
            assert(isequaln(owner.continuationToken(),preview.targetToken), ...
                identifier,'The current target changed during preview. Preview it again.');
            assert(isequaln(options.Declarations,preview.declarationValues),identifier, ...
                'Preview the observable declarations before accepting them.');
            data=colormeasure.chart.continuationSource(preview.sourceInput);
            assert(isequaln(data,preview.sourceData),identifier,'The source changed during preview. Preview it again.');
            if ~data.live&&~owner.finished&&~isempty(owner.files.mat)
                currentPath=char(java.io.File(owner.files.mat).getCanonicalPath());
                assert(~strcmp(data.path,currentPath),'Measurement:ChartContinuationSource', ...
                    'This MAT belongs to the unfinished current batch. Choose its live session or finish it before using the saved file.');
            end
            [blocked,cleanupRequired]=obj.continuationBlock(data);
            assert(isempty(blocked),'Measurement:ChartContinuationBlocked','%s',blocked);
            sourceCleanup=struct('segmentId',{},'runId',{},'confirmedAtUTC',{},'declaration',{}, ...
                'connectionClosed',{},'instrumentIdle',{});
            if cleanupRequired
                assert(options.ConfirmConnectionClosed&&options.ConfirmInstrumentIdle,'Measurement:ConnectionCleanup', ...
                    'Confirm the connection is closed and the instrument is idle before continuing this chart.');
                declaration=colormeasure.chart.declarationText(options.CleanupDeclaration,'Cleanup declaration', ...
                    'Measurement:ConnectionCleanup');
                sourceCleanup=struct('segmentId',data.retainedUncertainty.segmentId,'runId',data.retainedUncertainty.runId, ...
                    'confirmedAtUTC',colormeasure.session.utcText(obj.IO.now()),'declaration',declaration, ...
                    'connectionClosed',true,'instrumentIdle',true);
            else
                assert(~options.ConfirmConnectionClosed&&~options.ConfirmInstrumentIdle&& ...
                    isempty(options.CleanupDeclaration),'Measurement:ConnectionCleanup', ...
                    'This source has no unresolved connection cleanup to declare.');
            end
            assert(numel(data.chart.sources)<colormeasure.chart.Run.MaxInheritedSegments,'Measurement:ChartContinuationSource', ...
                'This chart already contains the maximum %d inherited segments. Inspect it or start a separate chart.', ...
                colormeasure.chart.Run.MaxInheritedSegments);
            context=owner.continuationContext();
            assert(isequaln(obj.continuationContext(),context)&& ...
                isequaln(obj.settingsOverrides,owner.settingsOverrides)&& ...
                isequaln(obj.settingsSnapshot,owner.settingsSnapshot)&&strcmp(obj.port,owner.port), ...
                identifier,'The replacement setup changed after construction. Create a fresh replacement.');
            passIndex=find(strcmp({data.chart.passes.id},preview.source.passId));
            assert(isscalar(passIndex)&&isequal(passIndex,preview.sourcePassIndex),identifier,'The selected source pass changed. Preview it again.');
            decision=chartPassContinuity(data.chart.passes(passIndex),context,options.Declarations);
            [eligible,reason]=colormeasure.chart.eligibility(context);
            assert(eligible,'Measurement:ChartIneligible','%s',reason);
            assert(~strcmp(options.Action,'continue')||decision.continueEligible, ...
                'Measurement:ChartContinuationContext','Identity or material context is unresolved. Inspect the source or start a new empty pass.');
            assert(~strcmp(options.Action,'continue')||isempty(colormeasure.chart.pendingDecision(data.chart,preview.source.passId)), ...
                'Measurement:ChartContinuationContext','The source pass retains a context decision. Start a new empty pass.');
            assert(~strcmp(options.Action,'continue')||~decision.requiredAcknowledgment||options.AcknowledgeVersionChange, ...
                'Measurement:ChartContinuationContext','Acknowledge the reported capability change before continuing.');
            % Validate all refusal conditions before explicit finalization.
            if data.live
                source=preview.sourceInput;
                source.finishChartHandover();
                assert(source.finished&&~source.needsRecovery,'Measurement:ChartContinuationBlocked', ...
                    'Recover saving the source before continuing.');
                finalized=colormeasure.chart.continuationSource(source);
                assert(isequaln(data.measurements,finalized.measurements)&&isequaln(data.chart,finalized.chart)&& ...
                    isequaln(data.batchInfo.readingAnnotations,finalized.batchInfo.readingAnnotations), ...
                    identifier,'The source changed while it was finalized. Preview it again.');
                data=finalized;
            end
            if ~owner.finished
                owner.finishChartHandover();
                assert(owner.finished&&~owner.needsRecovery,'Measurement:ChartContinuationBlocked', ...
                    'Recover saving the current batch before continuing.');
            end
            finalSource=colormeasure.chart.continuationSource(preview.sourceInput);
            assert(isequaln(data,finalSource),identifier, ...
                'The source changed while the current batch was finalized. Preview it again.');
            assert(~isempty(data.sourceSha256),'Measurement:ChartContinuationSource', ...
                'Continuation requires the saved source MAT byte witness.');
            sourceInfo=data.batchInfo;sourceInfo.chart.sources=colormeasure.chart.emptySources();
            envelope=struct('segmentId',data.chart.segmentId,'parentSegmentId',data.chart.parentSegmentId, ...
                'measurements',data.measurements,'batchInfo',sourceInfo,'sourceSha256',data.sourceSha256);
            run=colormeasure.chart.Run.fromContinuation(data.chart,envelope,obj.SegmentId,context, ...
                options.Action,options.Declarations,passIndex);
            obj.ChartRun=run;obj.ChartFreeSample=data.chart.freeSample;
            if ~isempty(sourceCleanup)
                obj.ChartIoConfirmations(end+1)=sourceCleanup;
                obj.addLog('warning',['Source connection cleanup retained as an operator declaration; ' ...
                    'no instrument validation was performed.']);
            end
            obj.ChartNotes=data.chart.chartSample.notes;
            if passIndex~=data.chart.activePass,obj.ChartNotes='';end
            obj.notes=obj.ChartNotes;obj.useChartName();
            obj.ContinuationOwner=[];
            saved=obj.saveChartState();session=obj;
        end

        function [reading,facts]=chartReading(obj,passIndex,cellIndex)
            % Resolve selected original observations for read-only inspection.
            assert(~isempty(obj.ChartRun),'Measurement:ChartMissing','Start a guided chart first.');
            validateattributes(passIndex,{'numeric'},{'scalar','real','finite','integer','positive','<=',numel(obj.ChartRun.Snapshot.passes)});
            pass=obj.ChartRun.Snapshot.passes(passIndex);
            validateattributes(cellIndex,{'numeric'},{'scalar','real','finite','integer','positive','<=',numel(pass.selectedAttempt)});
            selected=pass.selectedAttempt(cellIndex);reading=struct([]);facts=struct([]);
            if selected==0,return;end
            [reading,facts]=colormeasure.chart.resolveReading(obj.ChartRun.Snapshot,obj.measurements,pass.attempts(selected));
        end

        function saved=selectChartCell(obj,row,column)
            obj.assertChartEditable(true);
            if ~obj.ChartRun.select(row,column),saved=true;return;end
            if ~obj.ChartRun.Snapshot.paused,obj.useChartName();end
            saved=obj.saveChartState();
        end

        function saved=rotateChart(obj,degrees)
            obj.assertChartEditable(true);obj.ChartRun.rotate(degrees);saved=obj.saveChartState();
        end

        function saved=pauseChart(obj)
            obj.assertChartEditable(true);
            if obj.ChartRun.Snapshot.paused,saved=true;return;end
            obj.ChartNotes=obj.notes;
            obj.ChartRun.pause(true);
            obj.name=obj.ChartFreeSample.name;obj.notes=obj.ChartFreeSample.notes;
            obj.sampleRevision=obj.sampleRevision+1;saved=obj.saveChartState();
        end

        function saved=resumeChart(obj)
            obj.assertChartEditable(true);
            if ~obj.ChartRun.Snapshot.paused,saved=true;return;end
            obj.ChartRun.checkContext(obj.chartContext());
            if ~isempty(obj.ChartRun.Snapshot.pendingContext)&& ...
                    obj.ChartRun.Snapshot.revision~=obj.ChartRun.Snapshot.savedRevision
                obj.saveChartState();
            end
            assert(isempty(obj.ChartRun.Snapshot.pendingContext),'Measurement:ChartContext', ...
                'Acquisition context changed. Start a new chart pass before resuming.');
            obj.ChartFreeSample=struct('name',obj.name,'notes',obj.notes);
            obj.notes=obj.ChartNotes;
            obj.ChartRun.pause(false);obj.useChartName();saved=obj.saveChartState();
        end

        function saved=acceptChartContext(obj)
            obj.assertChartEditable(true);obj.ChartRun.acceptContext();
            if ~obj.ChartRun.Snapshot.paused,obj.useChartName();end
            saved=obj.saveChartState();
        end

        function value = get.busy(obj)
            value=obj.Busy;
        end

        function value = get.adapterKey(obj)
            value = obj.Adapter.key;
        end

        function value = get.workspaceName(obj)
            value = '';
            if isfield(obj.Adapter,'workspaceName')
                value = obj.Adapter.workspaceName;
            end
        end

        function obj = Session(adapter, destination, io)
            if nargin < 3
                io = colormeasure.session.services();
            end
            % Fail here, with the documented field names, rather than at the
            % first reading, export or window action.
            adapter = colormeasure.session.validateAdapter(adapter);
            obj.Adapter = adapter;
            obj.SegmentId = char(java.util.UUID.randomUUID());
            obj.IO = io;
            obj.Parent = destinationPath(destination);
            obj.label = adapter.label;
            started = obj.IO.now();
            obj.startedAtUTC = colormeasure.session.utcText(started);
            [obj.startedAtLocal, obj.localTimeZone] = colormeasure.session.localTimeText(started);
            obj.addLog('info', sprintf('Session opened. Save destination: %s', obj.Parent));
            if isfield(adapter,'configurationSummary') && ~isempty(adapter.configurationSummary)
                obj.addLog('info', ['Connection settings: ' char(adapter.configurationSummary)]);
            end
            obj.refreshPorts();
            colormeasure.session.liveSession(obj.SegmentId,obj);
        end

        function value = get.info(obj)
            value = colormeasure.session.batchTiming(obj.measurements);
            value.segmentId = obj.SegmentId;
            value.chartIoConfirmations=obj.ChartIoConfirmations;
            value.continuationGuard=struct('version',1, ...
                'operationActive',obj.ChartAttempt>0||obj.chartIoUnconfirmed, ...
                'cleanupPending',obj.chartIoUnconfirmed);
            if ~isempty(obj.ChartRun)
                value.chart = obj.chartSnapshot();
                value.pendingSample=struct('name',obj.name,'notes',obj.notes);
            end
            value.instrument = obj.label;
            value.acquisitionComplete = (obj.finishing || obj.finished);
            value.previousFolders = obj.files.previousFolders;
            value.sessionStartedAtUTC = obj.startedAtUTC;
            value.sessionStartedAtLocal = obj.startedAtLocal;
            value.sessionLocalTimeZone = obj.localTimeZone;
            value.configuration = obj.configuration;
            value.catalogIdentity = obj.catalogIdentity;
            value.readingAnnotations = obj.readingAnnotations;
            value.annotationRevision = obj.annotationRevision;
        end

        function value = get.status(obj)
            count = numel(obj.measurements);
            unit = 'readings';
            saved=obj.savedCount;
            if count == 1
                unit = 'reading';
            end
            if obj.busy
                activity=obj.activity;
                value = sprintf('%s | %d %s', activity, count, unit);
                return
            end
            parts={};
            if obj.chartIoUnconfirmed,parts{end+1}='Cleanup unconfirmed';end
            if obj.finished,parts{end+1}='Finished';end
            if ~isempty(obj.saveError),parts{end+1}='Save needs attention';end
            if ~isempty(obj.exportError),parts{end+1}='CSV export needs attention';end
            if ~isempty(obj.saveError)
                detail = sprintf('%d of %d %s saved', saved, count, unit);
                if saved==0&&~isempty(obj.SavedSnapshot)&&~isempty(obj.files.previousFolders)
                    detail=[detail ' here; earlier MAT saved ' ...
                        colormeasure.session.counted(numel(obj.SavedSnapshot.measurements),'reading','readings')];
                end
            elseif obj.finished||~isempty(obj.exportError)
                detail = sprintf('%d %s saved', saved, unit);
            elseif obj.chartIoUnconfirmed
                detail = sprintf('%d %s retained',count,unit);
            else
                activity = obj.activity;
                if strcmp(activity, 'Awaiting Measure')
                    activity = 'Ready';
                end
                detail = sprintf('%s | %d %s', activity, count, unit);
            end
            value = strjoin([parts {detail}],' | ');
        end

        function value = get.needsRecovery(obj)
            value = ~isempty(obj.saveError) || ~isempty(obj.exportError) || ...
                (obj.chartIoUnconfirmed&&~obj.busy);
        end


        function value = get.window(obj)
            value = [];
            if ~isempty(obj.View) && isvalid(obj.View)
                value = obj.View.Figure;
            end
        end

        function value = get.destination(obj)
            value = obj.Parent;
            if ~isempty(obj.files.folder)
                value = obj.files.folder;
            end
        end

        function value = get.saveParent(obj)
            % New batches share the selected destination, not a batch subfolder.
            value = obj.Parent;
        end

        function value = get.configuration(obj)
            value = struct();
            if isfield(obj.Adapter,'configuration'), value = obj.Adapter.configuration; end
        end

        function value = get.preparation(obj)
            % Plain family-owned help data; reading it never operates equipment.
            % The optional UI decides when to present a preparation reminder.
            value = struct([]);
            if isfield(obj.Adapter,'preparation')
                value = obj.Adapter.preparation;
            end
        end

        function value = get.settingsCatalog(obj)
            % Catalog access is presentation-only: never query the instrument.
            value = struct([]);
            if ~isempty(obj.settingsSnapshot) && isfield(obj.settingsSnapshot, 'controls')
                value = obj.settingsSnapshot.controls;
            elseif obj.hasSettings() && isfield(obj.Adapter.settings, 'catalog')
                value = obj.Adapter.settings.catalog;
            end
        end

        function success = setInstrumentSettings(obj, overrides)
            % Replace staged overrides. Actual capabilities are checked again
            % by the adapter immediately before acquisition.
            success = false;
            if obj.busy || obj.finished || obj.finishing
                return
            end
            if ~isempty(obj.ChartRun),obj.assertChartEditable(true);end
            colormeasure.session.validateSettingsOverrides(overrides, obj.settingsCatalog);
            obj.settingsOverrides = overrides;
            if ~isempty(obj.ChartRun)
                obj.ChartRun.checkContext(obj.chartContext());obj.saveChartState();
            end
            success = true;
            obj.changed();
        end

        function success = refreshInstrumentSettings(obj)
            % Explicit readback connects and releases without an exposure.
            success = false;
            if obj.busy || obj.finished || obj.finishing
                return
            end
            if ~isempty(obj.ChartRun),obj.assertChartEditable(true);end
            if ~obj.hasSettings() || ~isfield(obj.Adapter.settings, 'read') || ...
                    ~isa(obj.Adapter.settings.read, 'function_handle')
                error('Measurement:SettingsUnavailable', ...
                    'This instrument adapter does not provide settings readback.');
            end
            if ~obj.beginOperation('Reading instrument settings')
                return
            end
            cleanup = onCleanup(@() obj.endOperation());
            obj.settingsSnapshot = struct([]);
            try
                obj.checkPort();
                instrument = obj.connectInstrument();
                closeInstrument=@()obj.releaseDirectInstrument(false);
                release=onCleanup(@()obj.releaseDirectInstrument(true));
                report = obj.Adapter.settings.read(instrument);
                closeInstrument();
                clear release
                if ~isvalid(obj), return; end
                validateSettingsReport(report);
                obj.settingsSnapshot = report;
                if ~isempty(obj.ChartRun),obj.ChartRun.checkContext(obj.chartContext());obj.persistMat();end
                success = true;
                obj.activity = obj.idleActivity();
                obj.addLog('info', 'Instrument settings read; no measurement acquired.');
            catch err
                clear release
                if isvalid(obj)
                    obj.settingsSnapshot = struct([]);
                    obj.activity = 'Settings read failed';
                    obj.addLog('error', sprintf('Settings read failed (%s): %s. Retry explicitly.', ...
                        err.identifier, err.message));
                    if ~isempty(obj.ChartRun),obj.persistMat();end
                end
            end
        end

        function show(obj)
            if isempty(obj.View) || ~isvalid(obj.View)
                if ~isfield(obj.IO, 'createView') || ~isa(obj.IO.createView, 'function_handle')
                    error('Measurement:ViewUnavailable', ...
                        ['No window is configured. Supply io.createView when constructing ' ...
                        'the session, or use its measurement methods directly.']);
                end
                if ~isempty(obj.View) && isvalid(obj.View)
                    delete(obj.View);
                end
                % The optional presentation layer owns window construction.
                obj.View = obj.IO.createView(obj);
            else
                % Presentation owns restoration, including its source lifetime.
                obj.View = obj.View.restore();
                % Admit input only after the session owns the restored view.
                set(obj.View.Figure,'Visible','on');figure(obj.View.Figure);
                obj.changed(); % Refresh connection state that changed while hidden.
            end
        end

        function hide(obj)
            % Visibility is independent of acquisition and finalization.
            if ~isempty(obj.View) && isvalid(obj.View) && isgraphics(obj.View.Figure)
                set(obj.View.Figure, 'Visible', 'off');
            end
        end

        function session = newBatch(obj)
            % Keep the completed session/view until a replacement is ready.
            session = [];
            if obj.busy || ~obj.finished
                return
            end
            obj.assertChartIoReady();
            assert(~obj.needsRecovery&&obj.snapshotSaved(),'Measurement:SaveRecovery', ...
                'Retry save or use Another folder before starting a new batch.');
            if ~isfield(obj.IO, 'launchSession') || ~isa(obj.IO.launchSession, 'function_handle')
                error('Measurement:LauncherUnavailable', ...
                    ['No session launcher is configured. Construct a new colormeasure.session.Session ' ...
                    'for another batch, or supply io.launchSession.']);
            end
            adapter=obj.Adapter;
            session = obj.IO.launchSession(adapter, obj.IO, obj.Parent, true);
            if ~isempty(session) && session ~= obj
                obj.closeView();
            end
        end

        function data = viewData(obj)
            % Presentation belongs to the adapter, not the acquisition core.
            data = struct([]);
            if isfield(obj.Adapter, 'viewData')
                data = obj.Adapter.viewData(obj.measurements);
                data = colormeasure.session.validateViewData(data, numel(obj.measurements));
            end
        end

        function setSample(obj, name, notes)
            if obj.busy || obj.finished || obj.finishing
                return
            end
            if ~isempty(obj.ChartRun),obj.assertChartEditable(true);end
            name = strtrim(char(name));
            if obj.chartActive()
                assert(isempty(name)||strcmp(name,obj.name),'Measurement:ChartName', ...
                    'The active chart sample name is its coordinate. Edit a retained reading to change its annotation.');
            end
            if ~isempty(name)
                obj.name = name;
            end
            obj.notes = char(notes);
            % An explicit command can intentionally reset a pending UI draft
            % to the same committed values. The view must observe that intent.
            obj.sampleRevision = obj.sampleRevision + 1;
            if ~isempty(obj.ChartRun)
                obj.ChartRun.touch();
                if obj.chartActive(),obj.ChartNotes=obj.notes;
                else,obj.ChartFreeSample=struct('name',obj.name,'notes',obj.notes);end
                obj.saveChartState();
            end
            obj.changed();
        end

        function saved = editReading(obj, index, name, notes)
            % Edit operator annotations only. Chart coordinates,
            % acquisition settings and measured values remain unchanged.
            assert(~obj.busy && (~obj.finishing || obj.finished), 'Measurement:AnnotationBusy', ...
                'Finish the current operation or resolve batch recovery before editing a reading.');
            validateattributes(index,{'numeric'},{'scalar','real','finite','integer','positive', ...
                '<=',numel(obj.measurements)},mfilename,'reading index');
            assert(colormeasure.session.isText(name) && colormeasure.session.isText(notes), ...
                'Measurement:AnnotationText','Supply a sample name and notes as text.');
            name=strtrim(char(name));notes=char(notes);
            assert(~isempty(name) && ~contains(name,{newline,char(13)}), ...
                'Measurement:AnnotationName','Enter a nonempty sample name on one line.');
            reading=obj.measurements(index);
            if strcmp(name,reading.name) && strcmp(notes,reading.notes)
                saved=obj.snapshotSaved() && isempty(obj.saveError) && isempty(obj.exportError);return
            end
            entry=find([obj.readingAnnotations.readingIndex]==index,1);
            editedAt=colormeasure.session.utcText(obj.IO.now());
            if isempty(entry)
                item=struct('readingIndex',index, ...
                    'originalName',reading.name,'originalNotes',reading.notes, ...
                    'name',name,'notes',notes,'editedAtUTC',editedAt);
                obj.readingAnnotations(end+1)=item;
            else
                obj.readingAnnotations(entry).name=name;
                obj.readingAnnotations(entry).notes=notes;
                obj.readingAnnotations(entry).editedAtUTC=editedAt;
            end
            obj.measurements(index).name=name;obj.measurements(index).notes=notes;
            obj.annotationRevision=obj.annotationRevision+1;
            obj.files.csv='';
            if ~isempty(obj.ChartRun),obj.ChartRun.touch();end
            obj.MatFinalized=false;
            % A finished batch stays closed to acquisition while its revised
            % MAT/CSV is saved. Existing recovery controls handle either failure.
            if obj.finished,obj.finished=false;obj.finishing=true;end
            obj.beginOperation('Saving annotations');
            cleanup=onCleanup(@()obj.endOperation());
            obj.addLog('info',sprintf('Name and notes updated for reading #%d.',index));
            saved=obj.persistMat();
            if saved && obj.finishing
                obj.completeFinish();saved=obj.finished;
            end
            obj.activity=obj.idleActivity();
        end

        function selectPort(obj, port)
            if obj.busy || obj.finished || obj.finishing
                return
            end
            port = char(port);
            if ~isempty(obj.ChartRun),obj.assertChartEditable(true);end
            if ~strcmp(obj.port, port)
                obj.settingsSnapshot = struct([]);
                obj.lastSettingsReceipt = struct([]);
            end
            obj.port = port;
            obj.activity = obj.idleActivity();
            obj.changed();
        end

        function refreshPorts(obj)
            if ~obj.beginOperation('Refreshing ports')
                return
            end
            cleanup = onCleanup(@() obj.endOperation());
            previousPort = obj.port;
            try
                obj.ports = colormeasure.session.availablePorts(obj.Adapter.listPorts('all'), ...
                    obj.Adapter.listPorts('available'), obj.IO.isMac);
                if ~ismember(string(obj.port), obj.ports)
                    obj.port = '';
                    if isscalar(obj.ports)
                        obj.port = char(obj.ports(1));
                    end
                end
                if ~strcmp(obj.port, previousPort)
                    obj.settingsSnapshot = struct([]);
                    obj.lastSettingsReceipt = struct([]);
                end
                obj.activity = obj.idleActivity();
                obj.addLog('info', sprintf('%d available port(s). %s.', numel(obj.ports), obj.activity));
            catch err
                obj.ports = strings(0, 1);
                obj.port = '';
                obj.settingsSnapshot = struct([]);
                obj.lastSettingsReceipt = struct([]);
                obj.activity = 'Port discovery failed';
                obj.addLog('error', err.message);
            end
        end

        function success = measure(obj, name, notes)
            success = false;
            if obj.busy || obj.finished || obj.finishing
                return
            end
            if nargin >= 2
                if nargin < 3
                    notes = obj.notes;
                end
                obj.setSample(name, notes);
            end
            if ~obj.beginOperation('Checking setup')
                return
            end
            cleanup = onCleanup(@() obj.endOperation());
            stage = 'Setup';
            try
                obj.assertChartIoReady();
                obj.prepareChartAttempt();
                if isfield(obj.Adapter,'prepareSample')
                    obj.Adapter.prepareSample(obj.chartSampleIntent());
                end
                obj.checkPort();
                if isempty(obj.files.folder)
                    obj.files.folder = colormeasure.session.createMeasurementFolder(obj.Parent, 'batch', obj.IO.now());
                end
                obj.addLog('info', sprintf('Measuring %s on %s.', obj.name, obj.port));
                stage = 'Connection';
                obj.activity = 'Connecting';
                obj.settingsSnapshot = struct([]);
                obj.lastSettingsReceipt = struct([]);
                obj.changed();
                instrument = obj.connectInstrument();
                closeInstrument=@()obj.releaseDirectInstrument(false);
                release=onCleanup(@()obj.releaseDirectInstrument(true));
                receipt = struct([]);
                if obj.hasSettings()
                    stage = 'Instrument settings';
                    obj.activity = 'Applying instrument settings';
                    obj.changed();
                    % Empty overrides still request the family automatic
                    % acquisition profile. Native expert APIs remain separate.
                    receipt = obj.Adapter.settings.apply(instrument, obj.settingsOverrides);
                    validateSettingsReceipt(receipt);
                    receipt.policy = 'automatic-with-overrides';
                    receipt.overrides = obj.settingsOverrides;
                    obj.lastSettingsReceipt = receipt;
                    if ~isempty(receipt.after)
                        obj.settingsSnapshot = receipt.after;
                    end
                    if strcmp(receipt.status, 'failed')
                        error('Measurement:SettingsApplyFailed', ...
                            'Instrument settings could not be applied (%s): %s', ...
                            receipt.error.identifier, receipt.error.message);
                    end
                end
                if obj.chartActive()
                    obj.ChartRun.checkContext(obj.chartContext());
                    assert(isempty(obj.ChartRun.Snapshot.pendingContext),'Measurement:ChartContext', ...
                        'The instrument setup differs. Start a new chart pass before measuring.');
                end
                obj.activity = 'Measuring';
                stage = 'Reading';
                obj.changed();
                started = obj.IO.now();
                reading = obj.Adapter.read(instrument);
                completed = obj.IO.now();
                try
                    closeInstrument();
                catch releaseError
                    obj.addLog('warning',['Reading retained; instrument release is unconfirmed: ' releaseError.message]);
                end
                clear release
                if ~isvalid(obj)
                    return
                end
                reading = colormeasure.session.validateReading(reading);
                reading = colormeasure.session.stampReading(reading, obj.name, obj.notes, obj.port, ...
                    started, completed, seconds(completed - started), obj.localTimeZone);
                % Every current direct reading carries a receipt, empty when unavailable.
                reading.instrumentSettings = receipt;
                if isempty(obj.measurements)
                    obj.measurements = reading;
                else
                    reading = colormeasure.session.validateReading(reading, obj.measurements);
                    obj.measurements(end+1) = reading;
                end
            catch err
                % Release even when read throws; preserve the acquisition error.
                clear release
                if isvalid(obj)
                    obj.activity = [stage ' failed'];
                    if strcmp(err.identifier, 'Measurement:SaveFolder')
                        obj.saveError = err.message;
                    end
                    next='The sample is unchanged; retry explicitly.';
                    if obj.chartIoUnconfirmed
                        next='The sample is unchanged. Resolve connection cleanup before retrying.';
                    end
                    obj.addLog('error', sprintf('%s failed (%s): %s %s', ...
                        stage, err.identifier, sentence(err.message), next));
                    if obj.ChartAttempt>0
                        obj.completeChartAttempt([], 'failed', err.message, []);obj.persistMat();
                        obj.activity=[stage ' failed'];obj.changed();
                    elseif ~isempty(obj.ChartRun)
                        obj.persistMat();obj.activity=[stage ' failed'];obj.changed();
                    end
                end
                return
            end
            % Commit the reading before persistence can fail.
            success = true;
            obj.addLog('info', sprintf('Completed %s (%s).', reading.name, ...
                colormeasure.session.counted(numel(obj.measurements), 'reading', 'readings')));
            % A completed reading can carry a device warning, for example
            % unverified settings restoration. Retain/save it without retrying
            % the exposure; make the warning visible in the ordinary log.
            if isfield(reading, 'warnings') && ...
                    (iscellstr(reading.warnings) || isstring(reading.warnings))
                messages = string(reading.warnings(:));
                for index = 1:numel(messages)
                    if ~ismissing(messages(index)) && strlength(strtrim(messages(index))) > 0
                        obj.addLog('warning', sprintf('%s: %s', reading.name, messages(index)));
                    end
                end
            end
            obj.completeChartAttempt(numel(obj.measurements),'completed','',reading);
            obj.advanceSample(reading.name, reading.notes);
            obj.persistMat();
            obj.activity = obj.idleActivity();
        end

        function retrySave(obj)
            if ~obj.busy&&obj.snapshotSaved()&&isempty(obj.saveError)&&~obj.needsRecovery
                % CSV-only retry uses the authenticated saved snapshot.
                % A finished batch never reopens acquisition or rewrites MAT.
                if ~obj.chartCsvNeedsRetry,return;end
                obj.Busy=true;obj.activity='Updating CSV';obj.changed();
                cleanup=onCleanup(@()obj.endOperation());
                obj.updateChartCsv();obj.activity=obj.idleActivity();return
            end
            if ~obj.hasData()||obj.busy,return;end
            if obj.finished
                obj.Busy=true;obj.activity='Saving retained batch';obj.changed();
            elseif ~obj.beginOperation('Saving MAT')
                return;
            end
            cleanup = onCleanup(@() obj.endOperation());
            current = obj.snapshotSaved() && isempty(obj.saveError);
            if (obj.finishing||obj.finished) && obj.MatFinalized && current
                obj.completeFinish();
            elseif obj.persistMat() && (obj.finishing||obj.finished)
                obj.completeFinish();
            end
            obj.activity = obj.idleActivity();
        end

        function saveElsewhere(obj, folder)
            if obj.busy
                return
            end
            if nargin < 2 && (~isfield(obj.IO, 'chooseFolder') || ~isa(obj.IO.chooseFolder, 'function_handle'))
                error('Measurement:FolderPickerUnavailable', ...
                    ['Specify the destination with session.saveElsewhere(folder). ' ...
                    'Interactive folder selection requires an io.chooseFolder callback.']);
            end
            wasFinished=obj.finished;
            if wasFinished
                % Saving another copy of retained data does not resume it.
                obj.Busy=true;obj.activity='Choosing save folder';obj.changed();
            elseif ~obj.beginOperation('Choosing save folder')
                return
            end
            cleanup = onCleanup(@() obj.endOperation());
            try
                if nargin < 2
                    folder = obj.IO.chooseFolder(obj.Parent);
                end
                if isempty(folder)
                    obj.activity = obj.idleActivity();
                    return
                end
                folder = destinationPath(folder);
                if ~obj.hasData()
                    if ~isempty(obj.files.folder)
                        [~, ~] = rmdir(obj.files.folder);
                    end
                    obj.Parent = char(folder);
                    obj.files.folder = '';
                    obj.saveError = '';
                    obj.exportError = '';
                    obj.addLog('info', sprintf('Save destination changed to %s.', folder));
                else
                    newFolder = colormeasure.session.createMeasurementFolder(folder, 'batch', obj.IO.now());
                    previous = obj.files.folder;
                    if ~isempty(previous)
                        obj.files.previousFolders{end+1} = previous;
                        obj.PendingPrevious{end+1} = previous;
                    end
                    obj.files.folder = newFolder;
                    obj.files.mat = '';
                    obj.files.csv = '';
                    obj.files.chartCsv = '';
                    obj.savedCount = 0;
                    obj.MatFinalized = false;
                    obj.Parent = char(folder);
                    obj.addLog('info', sprintf('Saving at %s. Earlier snapshots remain at %s.', newFolder, previous));
                    if obj.persistMat()
                        if (obj.finishing||wasFinished)
                            obj.completeFinish();
                        end
                    end
                end
            catch err
                obj.addLog('error', sprintf('Cannot change save destination: %s', err.message));
            end
            obj.activity = obj.idleActivity();
        end

        function finish(obj,options)
            arguments
                obj
                options.AllowIncompleteChart (1,1) logical=false
            end
            if obj.finished
                return
            end
            if ~isempty(obj.ChartRun)
                pass=obj.ChartRun.pass();incomplete=any(pass.selectedAttempt==0);
                assert(~incomplete||options.AllowIncompleteChart, ...
                    'Measurement:ChartIncomplete','The active chart pass is incomplete. Choose Finish incomplete or keep measuring.');
                obj.FinishChartAllowed=options.AllowIncompleteChart;
            end
            if obj.busy
                obj.FinishRequested = true;
                obj.addLog('info', 'Finish requested; waiting for the active operation.');
                return
            end
            obj.finishing = true;
            if ~obj.beginOperation('Finishing')
                return
            end
            cleanup = onCleanup(@() obj.endOperation());
            if ~obj.hasData()
                if ~isempty(obj.files.folder)
                    [~, ~] = rmdir(obj.files.folder);
                end
                obj.finished = true;
                obj.activity = 'Finished';
                obj.addLog('info', 'Finished without acquiring any readings.');
                return
            end
            if (~obj.MatFinalized || ~obj.snapshotSaved()) && ~obj.persistMat()
                return
            end
            obj.completeFinish();
        end

        function reportError(obj, err)
            obj.activity = 'Action failed';
            obj.addLog('error', sprintf('Action failed (%s): %s', err.identifier, err.message));
        end

        function delete(obj)
            % Explicit deletion is destructive, unlike Finish. Preserve unsaved
            % completed structs; a destructor cannot postpone object invalidation.
            try
                if ~obj.snapshotSaved()
                    index = 1;
                    recoveredName = sprintf('colorMeasureRecovered_%d', index);
                    while evalin('base', sprintf('exist(''%s'', ''var'')', recoveredName))
                        index = index + 1;
                        recoveredName = sprintf('colorMeasureRecovered_%d', index);
                    end
                    recovered=struct('measurements', obj.measurements, 'info', obj.info, 'log', obj.log);
                    assignin('base', recoveredName, recovered);
                    message='Unsaved batch data retained in workspace variable %s.';
                    warning('Measurement:UnsavedSession',message,recoveredName);
                end
                obj.closeView();
            catch err
                warning('Measurement:Cleanup', 'Session cleanup: %s', err.message);
            end
        end
    end

    methods (Access = private)
        function instrument=connectInstrument(obj)
            % A native owner may mark a refusal only after confirmed cleanup.
            % Unmarked errors retain uncertainty even without a returned handle.
            % Retain the returned owner until its release actually succeeds.
            obj.assertChartIoReady();
            obj.beginChartIo();
            try
                instrument=obj.Adapter.connect(obj.port);
                obj.DirectInstrument=instrument;obj.DirectRelease=obj.Adapter.release;
                obj.DirectReleaseAttempted=false;
            catch problem
                if any(cellfun(@(cause)strcmp(cause.identifier,'Measurement:ConnectCleanupConfirmed'),problem.cause))
                    obj.confirmChartIo();
                end
                rethrow(problem);
            end
        end
        function assertChartIoReady(obj)
            if ~obj.chartIoUnconfirmed,return;end
            if obj.directCleanupCanRetry
                reason='Connection cleanup is unconfirmed. Use Retry cleanup to close the retained connection.';
            else
                reason=['Connection cleanup is unconfirmed and the app can no longer reach the instrument connection. ' ...
                    'Check that no MATLAB batch or other program still uses the instrument port and that the instrument is not measuring, then use Confirm cleanup... to record your checks.'];
            end
            error('Measurement:ConnectionCleanupUnconfirmed','%s',reason);
        end
        function beginChartIo(obj)
            % Retained charts need durable active intent before any I/O,
            % including calibration, settings and paused free samples.
            obj.assertChartIoReady();
            obj.ChartIoUnconfirmed=true;obj.MatFinalized=false;
            % Ordinary batches still retain uncertainty in their live owner,
            % without changing their acquisition-first persistence flow.
            if isempty(obj.ChartRun),return;end
            if ~obj.persistMat(false)
                obj.ChartIoUnconfirmed=false; % Dispatch has not happened.
                error('Measurement:ChartSave','Save the operation intent before acquiring: %s',obj.saveError);
            end
        end
        function confirmChartIo(obj)
            % Clear only after a normal owned release, or the native owner's
            % typed confirmation that a failed connection left no host I/O.
            obj.ChartIoUnconfirmed=false;
        end
        function releaseDirectInstrument(obj,fallback)
            if isempty(obj.DirectRelease),return;end
            % The interruption fallback makes at most one attempt. A failed
            % explicit release remains owned until an explicit cleanup retry.
            if fallback&&obj.DirectReleaseAttempted,return;end
            obj.DirectReleaseAttempted=true;
            release=obj.DirectRelease;release(obj.DirectInstrument);
            obj.DirectInstrument=[];obj.DirectRelease=[];obj.DirectReleaseAttempted=false;
            obj.confirmChartIo();
        end
        function assertContinuationOwnerReady(obj)
            assert(~obj.busy&&~obj.saving&&~(obj.finishing&&~obj.finished), ...
                'Measurement:ChartContinuationBlocked','Finish the operation and confirm cleanup before continuing a chart.');
            obj.assertChartIoReady();
            assert(~obj.needsRecovery, ...
                'Measurement:ChartContinuationBlocked','Recover the retained batch before continuing a chart.');
        end

        function [reason,declarationRequired]=continuationBlock(~,data)
            % Fork prevention belongs to continuation acceptance, not to the
            % shared read-only reader used for retained chart inspection.
            % Retained uncertainty needs its live owner while one exists in
            % this MATLAB session; otherwise only an operator declaration
            % (the same checks as Confirm cleanup...) can resolve it.
            reason=data.blockedReason;declarationRequired=false;
            if data.live,return;end
            owner=colormeasure.session.liveSession(data.chart.segmentId);
            if ~isempty(data.retainedUncertainty)
                if isempty(owner)
                    reason='';declarationRequired=true;
                elseif ~owner.chartIoUnconfirmed&&(owner.needsRecovery||~isempty(owner.files.mat))
                    % The owner's later save replaces this copy. Its saved
                    % chart is admitted only after that batch finishes.
                    current='its current saved chart';
                    if ~owner.needsRecovery,current=[current ' at ' owner.files.mat];end
                    next=['choose ' current];
                    if ~owner.finished
                        next=['continue from that open batch, or finish it and choose ' current ','];
                    end
                    if owner.needsRecovery
                        reason=['The open batch has resolved its connection cleanup but still needs save recovery. ' ...
                            'Recover saving there (Retry save or Another folder), then ' next ' instead of this earlier copy.'];
                    else
                        reason=['The open batch has already saved its resolved connection cleanup. ' ...
                            upper(next(1)) next(2:end) ' instead of this earlier copy.'];
                    end
                else
                    reason=['The batch that saved this chart is still open. Resolve its connection cleanup there ' ...
                        '(Retry cleanup or Confirm cleanup...) and let it save before continuing.'];
                end
            elseif isempty(reason)&&~isempty(owner)&&~owner.finished
                reason='This saved segment still belongs to an unfinished live batch. Choose that live batch or finish it before continuing the saved copy.';
            end
        end

        function value=continuationContext(obj)
            value=colormeasure.chart.context(obj.chartFacts());
        end

        function token=continuationToken(obj)
            % Facts and current direct binding belong to the existing owner.
            token=struct('context',obj.continuationContext(), ...
                'adapterKey',obj.adapterKey,'configuration',obj.configuration,'port',obj.port, ...
                'settingsOverrides',obj.settingsOverrides,'settingsSnapshot',obj.settingsSnapshot, ...
                'sampleRevision',obj.sampleRevision,'annotationRevision',obj.annotationRevision, ...
                'readings',obj.measurements,'files',obj.files,'finished',obj.finished);
        end

        function value=chartSnapshot(obj)
            % Persist both drafts with the chart revision; this is retention,
            % not an acquisition-resume or disk-loading interface.
            value=obj.ChartRun.Snapshot;
            value.pendingSample=struct('name',obj.name,'notes',obj.notes);
            value.freeSample=obj.ChartFreeSample;
            cell=value.currentCell;
            value.chartSample=struct('name',colormeasure.chart.coordinate(cell(1),cell(2)),'notes',obj.ChartNotes);
        end
        function finishChartHandover(obj)
            % Finalize the durable source before transferring its retained chart.
            obj.finish(AllowIncompleteChart=true);
        end
        function yes=chartActive(obj)
            yes=~isempty(obj.ChartRun)&&~obj.ChartRun.Snapshot.paused;
        end
        function assertChartEditable(obj,requireChart)
            assert(~obj.busy&&~obj.finishing&&~obj.finished, ...
                'Measurement:ChartBusy','Finish the operation before changing the chart.');
            if requireChart,assert(~isempty(obj.ChartRun),'Measurement:ChartMissing','Start a guided chart first.');end
            assert(isempty(obj.saveError), ...
                'Measurement:ChartSave','Save or recover the retained batch before changing the chart.');
            assert(~obj.ChartIoUnconfirmed,'Measurement:ChartContinuationBlocked', ...
                'Connection cleanup is unconfirmed. Resolve it before changing the chart.');
        end
        function assertChartReplaceable(obj)
            if ~isempty(obj.ChartRun)
                assert(all(arrayfun(@(p)isempty(p.attempts),obj.ChartRun.Snapshot.passes)), ...
                    'Measurement:ChartDefinition','Start another batch to replace a chart after an attempt.');
            end
        end
        function saved=saveChartState(obj)
            assert(obj.beginOperation('Saving chart'),'Measurement:ChartBusy', ...
                'Finish the operation before saving chart changes.');
            cleanup=onCleanup(@()obj.endOperation());
            obj.MatFinalized=false;
            saved=obj.persistMat();obj.activity=obj.idleActivity();obj.changed();
        end
        function useChartName(obj)
            cell=obj.ChartRun.Snapshot.currentCell;
            obj.name=colormeasure.chart.coordinate(cell(1),cell(2));
            obj.sampleRevision=obj.sampleRevision+1;
        end
        function value=chartContext(obj,reading)
            if nargin<2,reading=struct([]);end
            value=colormeasure.chart.context(obj.chartFacts(),reading);
        end
        function facts=chartFacts(obj)
            facts=struct('adapterKey',obj.adapterKey,'label',obj.label, ...
                'catalogIdentity',obj.catalogIdentity,'configuration',obj.configuration, ...
                'settingsOverrides',obj.settingsOverrides,'settingsSnapshot',obj.settingsSnapshot, ...
                'lastSettingsReceipt',obj.lastSettingsReceipt,'settingsCatalog',obj.settingsCatalog);
            if ~isempty(obj.measurements),facts.latestReading=obj.measurements(end);end
            if isempty(obj.measurements)&&~isempty(obj.ContinuationTargetReading)
                facts.latestReading=obj.ContinuationTargetReading;
            end
        end
        function intent=chartSampleIntent(obj)
            intent=struct([]);
            if ~obj.chartActive(),return;end
            pass=obj.ChartRun.pass();cellIndex=obj.ChartRun.cellIndex();
            count=nnz([pass.attempts.cellIndex]==cellIndex);
            % A prepared attempt already contributes to the count.
            if obj.ChartAttempt==0,count=count+1;end
            intent=struct('cell_index',cellIndex,'attempt',count);
        end

        function index=prepareChartAttempt(obj)
            index=0;
            if isempty(obj.ChartRun),return;end
            assert(isempty(obj.saveError)&&obj.ChartRun.Snapshot.revision==obj.ChartRun.Snapshot.savedRevision, ...
                'Measurement:ChartSave','Save the retained chart before acquiring another cell.');
            if ~obj.chartActive(),return;end
            context=obj.chartContext();[eligible,reason]=colormeasure.chart.eligibility(context);
            assert(eligible,'Measurement:ChartIneligible','%s',reason);
            obj.ChartRun.checkContext(context);
            if ~isempty(obj.ChartRun.Snapshot.pendingContext)
                obj.persistMat();error('Measurement:ChartContext','Acquisition settings changed. Start a new pass or use free samples.');
            end
            index=obj.ChartRun.begin(context,obj.name,obj.notes,colormeasure.session.utcText(obj.IO.now()));
            obj.ChartAttempt=index;
        end
        function completeChartAttempt(obj,indices,status,reason,reading)
            if obj.ChartAttempt==0,return;end
            time=colormeasure.session.utcText(obj.IO.now());
            try
                context=obj.chartContext(reading);
                obj.ChartRun.complete(obj.ChartAttempt,indices,status,reason,context,time);
            catch problem
                % The direct reading is already retained. Context
                % interpretation cannot prevent saving or fabricate coverage.
                reason=['Reading retained; chart context could not be verified: ' problem.message];
                obj.ChartRun.rejectContext(obj.ChartAttempt,indices,reason,time);
                obj.addLog('warning',reason);
            end
            pass=obj.ChartRun.pass();
            if strcmp(pass.attempts(obj.ChartAttempt).status,'completed')
                % Match ordinary sample advancement: consume this reading's
                % notes once, retaining them on the immutable attempt/reading.
                obj.notes='';obj.ChartNotes='';
            end
            obj.ChartAttempt=0;
            if obj.chartActive(),obj.useChartName();end
        end
        function exportChart(obj)
            if isempty(obj.ChartRun),return;end
            csv=fullfile(obj.files.folder,'chart-selected.csv');
            stage='source';
            try
                obj.assertCompanionSource();
                if strcmp(obj.files.chartCsv,csv)&&~isempty(obj.ChartCsvDigest)&&isfile(csv)
                    stage='output';actual=colormeasure.fileDigest(csv);
                    assert(strcmp(actual,obj.ChartCsvDigest),'Measurement:CompanionOutputChanged', ...
                        ['Chart CSV changed outside this session. The file was preserved. ' ...
                        'Use Another folder to save a new copy of the retained chart.']);
                    if obj.ChartCsvRevision==obj.ChartRun.Snapshot.revision
                        obj.ChartCsvAuthenticated=true;obj.ChartExportError='';
                        obj.ChartCsvRetryable=false;obj.ChartCsvRelocatable=false;
                        return
                    end
                end
                stage='projection';saved=obj.SavedSnapshot;
                data=colormeasure.chart.selectedTable(saved.measurements,saved.batchInfo,obj.Adapter,ForCsv=true);
                stage='publication';
                digest=obj.IO.exportCsv(saved.measurements,saved.batchInfo,csv,@(~,~)data);
                assert(colormeasure.session.isText(digest)&& ...
                    ~isempty(regexp(char(digest),'^[0-9a-f]{64}$','once')), ...
                    'Measurement:CsvPublication','The CSV writer must return its staged publication digest.');
            catch problem
                obj.ChartExportError=problem.message;
                obj.ChartCsvAuthenticated=false;
                recovery=colormeasure.session.companionFailure(problem,stage);
                obj.ChartCsvRetryable=recovery.retryable;obj.ChartCsvRelocatable=recovery.relocatable;
                rethrow(problem);
            end
            obj.files.chartCsv=csv;obj.ChartCsvRevision=obj.ChartRun.Snapshot.revision;
            obj.ChartCsvDigest=digest;obj.ChartCsvAuthenticated=true;
            obj.ChartExportError='';obj.ChartCsvRetryable=false;obj.ChartCsvRelocatable=false;
        end

        function yes=chartCsvCurrent(obj)
            % Render the last authenticated disposition without filesystem I/O.
            % An explicit export/reuse action checks the saved byte witness.
            yes=~isempty(obj.ChartRun)&&~isempty(obj.files.chartCsv)&&obj.ChartCsvAuthenticated&& ...
                obj.ChartCsvRevision==obj.ChartRun.Snapshot.revision&&isempty(obj.ChartExportError);
        end

        function updateChartCsv(obj)
            % This optional companion never owns ordinary export/Finish recovery.
            try
                obj.exportChart();
            catch problem
                obj.addLog('error',['Chart CSV update failed: ' problem.message]);
            end
        end

        function yes=hasData(obj)
            yes=~isempty(obj.ChartRun)||~isempty(obj.measurements)||~isempty(obj.ChartIoConfirmations);
        end

        function yes=snapshotSaved(obj)
            yes=obj.savedCount==numel(obj.measurements)&& ...
                obj.SavedAnnotationRevision==obj.annotationRevision&& ...
                obj.SavedCleanupCount==numel(obj.ChartIoConfirmations);
            if ~isempty(obj.ChartRun),yes=yes && obj.ChartRun.Snapshot.savedRevision==obj.ChartRun.Snapshot.revision;end
        end

        function advanceSample(obj, usedName, usedNotes)
            % Offer the next default sample only when the operator's draft is
            % the one just consumed; a recovery must not replace a newer draft.
            if obj.chartActive()
                obj.useChartName();return
            end
            if strcmp(obj.name, usedName) && strcmp(obj.notes, usedNotes)
                obj.name = sprintf('Sample %03d', numel(obj.measurements) + 1);
                obj.notes = '';
                obj.sampleRevision = obj.sampleRevision + 1;
                if ~isempty(obj.ChartRun)
                    obj.ChartFreeSample=struct('name',obj.name,'notes',obj.notes);
                    obj.ChartRun.touch();
                end
            end
        end

        function value = hasSettings(obj)
            value = isfield(obj.Adapter, 'settings') && ...
                isstruct(obj.Adapter.settings) && isscalar(obj.Adapter.settings);
        end

        function checkPort(obj)
            available = string(obj.Adapter.listPorts('available'));
            if isempty(obj.port) || ~ismember(string(obj.port), available)
                obj.settingsSnapshot = struct([]);
                error('Measurement:PortUnavailable', 'Select an available meter port and try again.');
            end
        end

        function value = idleActivity(obj)
            if obj.finished
                value = 'Finished';
            elseif obj.finishing
                value = 'Finishing';
            elseif isempty(obj.ports)
                value = 'No port available';
            elseif isempty(obj.port) || ~ismember(string(obj.port), obj.ports)
                value = 'Select instrument port';
            else
                value = 'Awaiting Measure';
            end
        end

        function started = beginOperation(obj, activity)
            started = ~obj.busy && ~obj.finished;
            if started
                obj.Busy = true;
                obj.activity = activity;
                obj.changed();
            end
        end

        function endOperation(obj)
            if ~isvalid(obj)
                return
            end
            finishRequested = obj.FinishRequested;
            obj.FinishRequested = false;
            if finishRequested
                % Freeze acquisition before publishing the idle state. A save
                % failure pauses finalization; it does not cancel Finish.
                obj.finishing = true;
                obj.activity = 'Finishing';
            end
            obj.Busy = false;
            obj.changed();
            if finishRequested
                if obj.needsRecovery
                    obj.addLog('warning', 'Finish paused: saving needs attention. The session and recovery controls remain available.');
                else
                    obj.finish(AllowIncompleteChart=obj.FinishChartAllowed);
                end
            end
        end

        function success = persistMat(obj,companions)
            if nargin<2,companions=true;end
            success = false;
            previousBusy=obj.Busy;previousActivity=obj.activity;obj.Busy=true;
            actionCleanup=onCleanup(@()obj.endPersistence(previousBusy,previousActivity));
            obj.saving = true;
            cleanup = onCleanup(@() obj.endMatSave());
            obj.activity = 'Saving MAT';obj.changed();
            try
                if isempty(obj.files.folder)
                    obj.files.folder=colormeasure.session.createMeasurementFolder(obj.Parent,'batch',obj.IO.now());
                end
                snapshot=obj.info;
                if ~isempty(obj.ChartRun),snapshot.chart.savedRevision=snapshot.chart.revision;end
                retained=obj.measurements;
                obj.IO.saveMat(retained, obj.files.folder, snapshot);
                if ~isempty(obj.ChartRun),obj.ChartRun.markSaved();end
                obj.savedCount = numel(obj.measurements);
                obj.SavedAnnotationRevision = obj.annotationRevision;
                obj.SavedCleanupCount=numel(obj.ChartIoConfirmations);
                obj.files.mat = fullfile(obj.files.folder, 'measurements.mat');
                obj.saveError = '';
                obj.MatFinalized = obj.finishing;
                obj.SavedSnapshot=struct('measurements',retained,'batchInfo',snapshot,'sourceDigest','');
                obj.CompanionSourceChanged=false;
                obj.addLog('info', sprintf('MAT saved (%s): %s', ...
                    colormeasure.session.counted(obj.savedCount, 'reading', 'readings'), obj.files.mat));
                success = true;
                previous = obj.PendingPrevious;obj.PendingPrevious = {};
                for index = 1:numel(previous),obj.markPrevious(previous{index});end
            catch err
                obj.saveError = err.message;
                obj.addLog('error', sprintf('%s. %s available in this session. Retry save or use Another folder.', ...
                    obj.saveError, colormeasure.session.counted(numel(obj.measurements), 'reading remains', 'readings remain')));
            end
            clear cleanup
            if success&&~companions,obj.ChartCsvAuthenticated=false;end
            if success&&companions&&~isempty(obj.ChartRun)&& ...
                    ~(obj.finishing||obj.finished||obj.FinishRequested)
                % Chart CSV failure preserves last-good bytes and does not fail MAT.
                obj.updateChartCsv();
            end
            clear actionCleanup
        end

        function endPersistence(obj,previousBusy,previousActivity)
            if ~isvalid(obj),return;end
            obj.Busy=previousBusy;
            if ~previousBusy
                obj.activity=previousActivity;
                % This save owns the action boundary when startup/context
                % refusal called it directly. Honor Finish queued by callbacks
                % just as an ordinary acquisition/retry owner would.
                obj.endOperation();
            else
                obj.changed();
            end
        end


        function endMatSave(obj)
            if isvalid(obj)
                obj.saving = false;
                obj.changed();
            end
        end


        function digest=assertCompanionSource(obj)
            % CSV exports use the same authoritative saved snapshot.
            % Bind its digest once, before either companion can be replaced.
            assert(~isempty(obj.SavedSnapshot)&&~isempty(obj.files.mat), ...
                'Measurement:CompanionSource','Save the authoritative MAT before exporting companions.');
            digest=colormeasure.fileDigest(obj.files.mat);
            if isempty(obj.SavedSnapshot.sourceDigest)
                obj.SavedSnapshot.sourceDigest=digest;
            else
                if ~strcmp(digest,obj.SavedSnapshot.sourceDigest),obj.CompanionSourceChanged=true;end
                assert(strcmp(digest,obj.SavedSnapshot.sourceDigest), ...
                    'Measurement:CompanionSourceChanged', ...
                    ['The authoritative MAT changed outside this session. Companion updates were refused. ' ...
                    'Keep this batch and use Another folder to save its retained data.']);
            end
        end

        function completeFinish(obj)
            obj.activity = 'Exporting CSV';
            obj.changed();
            try
                obj.updateChartCsv();
                obj.assertCompanionSource();
                if isempty(obj.measurements)
                    obj.exportError='';
                    obj.finished=true; obj.activity='Finished';
                    obj.addLog('info','Batch finished without acquired readings to export.');
                else
                    obj.files.csv='';
                    csv = fullfile(obj.files.folder, 'measurements.csv');
                    reason='';
                    if isfield(obj.Adapter,'csvAvailability')
                        reason=obj.Adapter.csvAvailability(obj.measurements);
                        assert((ischar(reason)&&(isempty(reason)||isrow(reason)))|| ...
                            (isstring(reason)&&isscalar(reason)&&~ismissing(reason)), ...
                            'Measurement:AdapterContract','csvAvailability must return an empty value or text reason.');
                    end
                    if strlength(string(reason))>0
                        obj.files.csv='';obj.exportError='';obj.finished=true;obj.activity='Finished';
                        obj.addLog('info',char(reason));
                    else
                        obj.IO.exportCsv(obj.measurements, obj.info, csv, obj.Adapter.toTable);
                        obj.files.csv = csv;
                        obj.exportError = '';
                        obj.finished = true;
                        obj.activity = 'Finished';
                        obj.addLog('info', sprintf('CSV exported: %s', csv));
                        obj.addLog('info', sprintf('Batch finished. %s accessible in the session.', ...
                            colormeasure.session.counted(numel(obj.measurements), 'complete reading remains', 'complete readings remain')));
                    end
                end
            catch err
                obj.exportError = err.message;
                obj.addLog('error', sprintf('%s. The complete MAT is saved; retry the export or use Another folder.', err.message));
            end
            obj.activity = obj.idleActivity();
        end

        function markPrevious(obj, folder)
            % The original volume may be unavailable. Marking is best effort;
            % successful persistence at the new location must not depend on it.
            try
                notice = fullfile(folder, 'relocated_to.txt');
                fid = fopen(notice, 'a');
                if fid == -1
                    error('Measurement:RelocationNotice', 'The previous folder could not be updated.');
                end
                cleanup = onCleanup(@() closeOpenFile(fid));
                fprintf(fid, '%s\nNew batch snapshot: %s\nEarlier measurement files are retained.\n\n', ...
                    colormeasure.session.utcText(obj.IO.now()), obj.files.mat);
                [detail, code] = ferror(fid);
                closed = fclose(fid);
                clear cleanup % Dispose before listeners can reuse the closed identifier.
                if code ~= 0 || closed ~= 0
                    error('Measurement:RelocationNotice', 'Could not finish writing the relocation notice: %s', detail);
                end
                obj.addLog('info', sprintf('Relocation notice written at %s.', notice));
            catch err
                obj.addLog('warning', sprintf('Earlier snapshots at %s could not be marked: %s', folder, err.message));
            end
        end

        function addLog(obj, level, message)
            entry = struct('timeUTC', colormeasure.session.utcText(obj.IO.now()), 'level', level, 'message', message);
            obj.log(end+1) = entry;
            obj.changed();
        end

        function changed(obj)
            notify(obj, 'Changed');
        end

        function closeView(obj)
            if ~isempty(obj.View) && isvalid(obj.View)
                delete(obj.View);
            end
            obj.View = [];
        end
    end
end

function folder = destinationPath(value)
% Resolve a relative destination once; later cd calls must not redirect saves.
if ~((ischar(value) && isrow(value)) || ...
        (isstring(value) && isscalar(value) && ~ismissing(value))) || ...
        strlength(string(value)) == 0
    error('Measurement:SaveFolder', 'Specify one nonempty save folder.');
end
folder = java.io.File(char(value));
% Java's user.dir does not follow MATLAB cd. Use MATLAB's folder explicitly.
if ~folder.isAbsolute(), folder = java.io.File(fullfile(pwd,char(value))); end
folder = char(folder.getCanonicalPath());
end

function closeOpenFile(fid)
% The checked close may already have run. Cleanup is a fallback only.
try
    fclose(fid);
catch
    % A closed identifier needs no further cleanup.
end
end

function validateSettingsReport(report)
fields = {'values', 'controls', 'identity', 'readAtUTC', 'responses'};
if ~isstruct(report) || ~isscalar(report) || ~all(isfield(report, fields)) || ...
        ~isstruct(report.values) || ~isscalar(report.values) || ~isstruct(report.controls) || ...
        ~colormeasure.session.isText(report.readAtUTC) || ~isPlainData(report)
    error('Measurement:InvalidSettingsReport', ...
        'The settings read hook must return an ordinary settings report struct.');
end
if strlength(string(report.readAtUTC))>0
    try
        colormeasure.session.utcValue(report.readAtUTC);
    catch problem
        wrapped=MException('Measurement:InvalidSettingsReport', ...
            'Settings readAtUTC must be empty or a valid UTC instant: %s',problem.message);
        throw(addCause(wrapped,problem));
    end
end
colormeasure.session.validateSettingsCatalog(report.controls, 'Measurement:InvalidSettingsCatalog');
end

function validateSettingsReceipt(receipt)
fields = {'requested', 'before', 'after', 'commands', 'acknowledgements', 'status', 'error'};
if ~isstruct(receipt) || ~isscalar(receipt) || ~all(isfield(receipt, fields)) || ...
        ~isPlainData(receipt) || ~isstruct(receipt.requested) || ~isscalar(receipt.requested) || ...
        ~((ischar(receipt.status) && isrow(receipt.status)) || ...
          (isstring(receipt.status) && isscalar(receipt.status))) || ...
        ~any(strcmp(receipt.status, {'applied', 'unchanged', 'failed'})) || ...
        ~isstruct(receipt.error) || ~isscalar(receipt.error) || ...
        ~all(isfield(receipt.error, {'identifier', 'message'}))
    error('Measurement:InvalidSettingsReceipt', ...
        'The settings apply hook must return an ordinary settings receipt struct.');
end
if ~isempty(receipt.before), validateSettingsReport(receipt.before); end
if ~isempty(receipt.after), validateSettingsReport(receipt.after); end
end

function value = isPlainData(data)
value = colormeasure.session.isPlainData(data);
end

function text=sentence(text)
% Keep an exception's existing sentence ending without doubled punctuation.
text=strtrim(text);
if ~isempty(text)&&~ismember(text(end),'.!?'),text=[text '.'];end
end

function decision=chartPassContinuity(pass,target,declarations)
% Later enrichment cannot certify an earlier selected observation's missing
% identity or scale. Every inherited selected row needs its own known basis.
decision=colormeasure.chart.continuity(pass.context,target,declarations);
for index=reshape(find(pass.selectedAttempt>0),1,[])
    attempt=pass.attempts(pass.selectedAttempt(index));
    row=colormeasure.chart.continuity(attempt.acceptedContext,target,declarations);
    decision.requiredAcknowledgment=decision.requiredAcknowledgment||row.requiredAcknowledgment;
    decision.versionNotes=unique([decision.versionNotes row.versionNotes],'stable');
    missing=~ismember({row.declarableFacts.key},{decision.declarableFacts.key});
    decision.declarableFacts=[decision.declarableFacts row.declarableFacts(missing)];
    if row.continueEligible,continue;end
    decision.continueEligible=false;
    decision.unknowns=[decision.unknowns row.unknowns];
    missing=~ismember({row.differences.key},{decision.differences.key});
    decision.differences=[decision.differences row.differences(missing)];
end
decision.unknowns=unique(decision.unknowns,'stable');
end

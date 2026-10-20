function tests=testChartContinuation
% Current-schema linked continuation uses the public Session owner only.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end
function testLivePreviewDoesNotFinishOrWrite(t)
[s,e]=source(t);before=s.info;bytes=colormeasuretest.readBytes(s.files.mat);saves=e('saves');
p=s.prepareChartContinuation(s);
verifyTrue(t,p.continueEligible,strjoin(p.unknowns,'; '));verifyTrue(t,p.newPassEligible);verifyFalse(t,s.finished);
verifyEqual(t,s.info,before);verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),1);
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),bytes);verifyEqual(t,p.sourceCoverage,1);
end
function testPreviousChartSchemaRefusesPreviewWithoutChangingCurrentOwnerOrSource(t)
[s,sourceState]=source(t);[target,targetState]=known(t,'VIRTUAL-CR250-001');
base=load(s.files.mat);before=target.info;sourceBefore=s.info;
hooks=0;
for defect={'previousVersion','retiredPassField','retiredPlacement','retiredAttemptField','missingAttemptField','extraChartField','extraSourceField'}
    [data,identifier]=incompatibleChart(base,defect{1});
    path=fullfile(t.TestData.folder,[defect{1} '.mat']);save(path,'-struct','data');
    bytes=colormeasuretest.readBytes(path);saves=targetState('saves');sourceSaves=sourceState('saves');
    verifyError(t,@()target.prepareChartContinuation(path),identifier);
    if strcmp(defect{1},'previousVersion')
        problem=colormeasuretest.captureError(@()target.prepareChartContinuation(path));
        verifySubstring(t,problem.message,'This saved chart format is unsupported.');
        verifyFalse(t,contains(problem.message,'missing material fact'));
        adapter=struct('viewData',@forbidden);
        verifyError(t,@()colormeasure.chart.selectedTable(data.measurements,data.batchInfo,adapter),identifier);
        verifyEqual(t,hooks,0);
        loaded=load(path);verifyEqual(t,loaded.measurements,data.measurements);
    end
    verifyFalse(t,target.finished);verifyFalse(t,s.finished);
    verifyEqual(t,target.info,before);verifyEqual(t,s.info,sourceBefore);
    verifyEqual(t,targetState('saves'),saves);verifyEqual(t,sourceState('saves'),sourceSaves);
    verifyEqual(t,targetState('connects'),1);verifyEqual(t,targetState('reads'),1);
    verifyEqual(t,colormeasuretest.readBytes(path),bytes);
end
    function value=forbidden(varargin) %#ok<STOUT> Schema refusal must precede presentation.
        hooks=hooks+1;error('Fixture:OldChartHook','Old chart reached native presentation.');
    end
end
function testIncompatibleSchemaRefusesBothContinuationActionsBeforeFinishing(t)
[s,sourceState]=source(t);s.finish(AllowIncompleteChart=true);
[target,targetState]=known(t,'VIRTUAL-CR250-001');base=load(s.files.mat);
for defect={'previousVersion','retiredPassField','retiredPlacement','retiredAttemptField','missingAttemptField','extraChartField','extraSourceField'}
    for action={'continue','new-pass'}
        path=fullfile(t.TestData.folder,[defect{1} '-' action{1} '.mat']);save(path,'-struct','base');
        preview=target.prepareChartContinuation(path);r=receiver(t,target);
        [data,identifier]=incompatibleChart(base,defect{1});save(path,'-struct','data');
        bytes=colormeasuretest.readBytes(path);before=target.info;sourceBefore=s.info;
        saves=targetState('saves');sourceSaves=sourceState('saves');reads=targetState('reads');
        verifyError(t,@()r.acceptChartContinuation(preview,Action=action{1}),identifier);
        verifyFalse(t,target.finished);verifyFalse(t,r.finished);
        verifyEqual(t,target.info,before);verifyEqual(t,s.info,sourceBefore);
        verifyEmpty(t,r.chart);verifyEmpty(t,r.measurements);verifyEmpty(t,r.files.folder);
        verifyEqual(t,targetState('saves'),saves);verifyEqual(t,sourceState('saves'),sourceSaves);
        verifyEqual(t,targetState('reads'),reads);
        verifyEqual(t,colormeasuretest.readBytes(path),bytes);
    end
end
end
function testSamePassRetainsHistoryAndAddsOnlyNewAcquisitions(t)
[s,e]=source(t);s.finish(AllowIncompleteChart=true);path=s.files.mat;
bytes=colormeasuretest.readBytes(path);old=s.info;preview=s.prepareChartContinuation(path);
r=receiver(t,s);[saved,returned]=r.acceptChartContinuation(preview);
verifyTrue(t,saved);verifyEqual(t,returned,r);verifyEmpty(t,r.measurements);
verifyEqual(t,r.chart.runId,s.chart.runId);verifyNotEqual(t,r.chart.segmentId,s.chart.segmentId);
verifyEqual(t,r.chart.coverage,1);verifyTrue(t,r.chart.cells(1).inherited);
verifyTrue(t,r.measure());verifyEqual(t,numel(r.measurements),1);verifyEqual(t,e('reads'),2);
verifyEqual(t,r.chart.coverage,2);verifyEqual(t,colormeasuretest.readBytes(path),bytes);
verifyEqual(t,s.info,old);verifyEqual(t,r.chart.sources.measurements,s.measurements);
[reading,facts]=r.chartReading(1,1);verifyEqual(t,reading,s.measurements(1));verifyTrue(t,facts.inherited);
verifyEqual(t,facts.segmentId,s.chart.segmentId);verifyEqual(t,facts.readingIndex,1);
end
function testFinishedPassCanBeRereadWithoutErasingOriginalSelection(t)
[s,~]=source(t);s.measure();s.finish();before=s.chart;
p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);
r.selectChartCell(1,1);verifyTrue(t,r.measure());
verifyEqual(t,r.chart.coverage,2);verifyEqual(t,r.chart.passes.attempts(1),before.passes.attempts(1));
verifyEqual(t,r.chart.passes.selectedAttempt(1),3);verifyEqual(t,r.chart.sources.batchInfo.chart.passes.selectedAttempt,[1 2]);
verifyFalse(t,r.chart.cells(1).inherited);verifyEqual(t,r.chart.cells(1).inheritedAttemptCount,1);
end
function testTransitiveHistoryIsFlatAndMovedMatNeedsNoSource(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);r.measure();r.finish();
p=r.prepareChartContinuation(r);n=receiver(t,r);n.acceptChartContinuation(p);
verifyNumElements(t,n.chart.sources,2);verifyEqual(t,{n.chart.sources.parentSegmentId},{'',s.chart.segmentId});
verifyTrue(t,all(arrayfun(@(item)isempty(item.batchInfo.chart.sources),n.chart.sources)));
copy=fullfile(t.TestData.folder,'moved.mat');copyfile(n.files.mat,copy);
delete(s.files.mat);delete(r.files.mat);data=colormeasure.chart.continuationSource(copy);
table=colormeasure.chart.selectedTable(data.measurements,data.batchInfo,struct());
verifyEqual(t,table.SegmentId,string({s.chart.segmentId,r.chart.segmentId}).');
verifyEqual(t,table.ReadingIndex,[1;1]);verifyTrue(t,all(isfinite(table.X)));

end
function testChangedIdentityOffersEmptyPassAndNeverPoolsCoverage(t)
[s,~]=source(t);[target,~]=known(t,'OTHER-UNIT');
p=target.prepareChartContinuation(s);verifyFalse(t,p.continueEligible);verifyTrue(t,p.newPassEligible);
r=receiver(t,target);before=s.info;
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationContext');verifyEqual(t,s.info,before);
r.acceptChartContinuation(p,Action='new-pass');verifyEqual(t,r.chart.activePass,2);verifyEqual(t,r.chart.coverage,0);
verifyEqual(t,r.chart.passes(1).coverage,1);verifyEmpty(t,r.measurements);
end
function testSourceChangeAndTargetChangeRefuseBeforeFinishing(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);
s.editReading(1,'Updated','annotation');
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationStale');verifyFalse(t,s.finished);verifyEmpty(t,r.chart);
% Portable annotations bind their original append index and current text;
% they do not carry an identity that direct instruments never provide.
portable=colormeasure.chart.continuationSource(s.files.mat);
verifyEqual(t,portable.batchInfo.readingAnnotations,s.readingAnnotations);
[reading,facts]=s.chartReading(1,1);verifyEqual(t,reading,s.measurements);
verifyEqual(t,facts.readingIndex,1);verifyEqual(t,facts.segmentId,s.chart.segmentId);
verifyFalse(t,isfield(facts,'observationId'));
before=colormeasuretest.readBytes(s.files.mat);base=load(s.files.mat);
for defect={'index','text'}
    data=base;
    if strcmp(defect{1},'index'),data.batchInfo.readingAnnotations.readingIndex=0;
    else,data.batchInfo.readingAnnotations.name='Different annotation';end
    path=fullfile(t.TestData.folder,['invalid-annotation-' defect{1} '.mat']);save(path,'-struct','data');
    verifyError(t,@()colormeasure.chart.continuationSource(path),'Measurement:ChartContinuationSource');
end
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),before);
p=s.prepareChartContinuation(s);r=receiver(t,s);s.setInstrumentSettings(struct('speed',2));
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationStale');verifyFalse(t,s.finished);
end
function testSaveFailureRetriesWithoutReattachingOrAcquiring(t)
[s,e]=source(t);r=receiver(t,s);
s.finish(AllowIncompleteChart=true);p=s.prepareChartContinuation(s);e('failSave')=true;
verifyFalse(t,r.acceptChartContinuation(p));verifyTrue(t,r.needsRecovery);verifyEqual(t,r.chart.coverage,1);
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationBlocked');
reads=e('reads');state=r.chart;e('failSave')=false;r.retrySave();
verifyFalse(t,r.needsRecovery);verifyEqual(t,e('reads'),reads);verifyEqual(t,r.chart.segmentId,state.segmentId);
verifyEqual(t,numel(r.chart.sources),1);verifyFalse(t,r.chart.unsaved);
end
function testEarlierPassUsesItsOwnContextAndTargetCell(t)
[s,~]=source(t);first=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();
[target,~]=known(t,'VIRTUAL-CR250-001');
p=target.prepareChartContinuation(s,PassId=first);verifyTrue(t,p.continueEligible);
verifyEqual(t,p.source.passId,first);verifyEqual(t,p.sourceCoverage,1);
latest=target.prepareChartContinuation(s);verifyFalse(t,latest.continueEligible);
r=receiver(t,target);r.acceptChartContinuation(p);verifyEqual(t,r.chart.activePass,1);
verifyEqual(t,r.chart.currentCell,[1 2]);verifyEqual(t,r.chart.sources.batchInfo.chart.activePass,2);
verifyEmpty(t,r.notes);verifyEmpty(t,r.chart.continuation.sourcePendingContext);
verifyEqual(t,r.chart.continuation.sourcePendingPassId,s.chart.passes(2).id);
verifyError(t,@()r.prepareChartContinuation(r,PassId='missing'),'Measurement:ChartContinuationSource');
[other,~]=known(t,'VIRTUAL-CR250-001');other.setInstrumentSettings(struct('speed',2));other.measure();
older=other.prepareChartContinuation(s,PassId=first);verifyFalse(t,older.continueEligible);
newest=other.prepareChartContinuation(s);verifyTrue(t,newest.continueEligible);
end
function testPreviewAttemptCountBelongsToChosenPass(t)
[s,e]=source(t);first=s.chart.passes.id;s.selectChartCell(1,1);verifyTrue(t,s.measure());
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();verifyTrue(t,s.measure());
[target,~]=known(t,'VIRTUAL-CR250-001');before=s.info;saves=e('saves');reads=e('reads');
earlier=target.prepareChartContinuation(s,PassId=first);latest=target.prepareChartContinuation(s);
verifyEqual(t,earlier.sourceAttemptCount,2);verifyEqual(t,latest.sourceAttemptCount,1);
verifyEqual(t,earlier.source.passId,first);verifyEqual(t,latest.source.passId,s.chart.passes(2).id);
verifyEqual(t,sum(arrayfun(@(pass)numel(pass.attempts),s.chart.passes)),3);
verifyEqual(t,s.info,before);verifyEqual(t,e('saves'),saves);verifyEqual(t,e('reads'),reads);
end
function testPendingDecisionRequiresNewPassInsteadOfSilentClearing(t)
[s,~]=source(t);s.setInstrumentSettings(struct('speed',2));
p=s.prepareChartContinuation(s);verifyFalse(t,p.continueEligible);verifyTrue(t,p.newPassEligible);
r=receiver(t,s);verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationContext');
r.acceptChartContinuation(p,Action='new-pass');verifyEqual(t,r.chart.coverage,0);
verifyNotEmpty(t,r.chart.continuation.sourcePendingContext);
end
function testReturnedUnknownScaleRetainsReadingWithoutInheritedCoverage(t)
[s,e]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);
e('loseScale')=true; %#ok<NASGU> The acquisition closure reads this Map mutation.
verifyTrue(t,r.measure());verifyNumElements(t,r.measurements,1);
verifyEqual(t,r.chart.passes.attempts(end).acceptedContext.material.xyzScale.certainty,'unknown');
verifyEqual(t,r.chart.coverage,1);verifyEqual(t,r.chart.passes.attempts(end).status,'unresolved');
verifyNotEmpty(t,r.chart.pendingContext);verifyTrue(t,r.chart.cells(1).inherited);
end
function testDiskSourceCannotBeRewrittenByItsUnfinishedOwner(t)
[s,e]=source(t);path=s.files.mat;p=s.prepareChartContinuation(path);r=receiver(t,s);
before=colormeasuretest.readBytes(path);saves=e('saves');
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationSource');
verifyEqual(t,colormeasuretest.readBytes(path),before);verifyEqual(t,e('saves'),saves);
verifyFalse(t,s.finished);verifyEmpty(t,r.chart);verifyEmpty(t,r.measurements);
end
function testUnfinishedManualLiveOwnerBlocksOriginalAndCopiedDiskSources(t)
[s,e]=source(t);[target,targetState]=known(t,'VIRTUAL-CR250-001');
copy=fullfile(t.TestData.folder,'unfinished-copy.mat');copyfile(s.files.mat,copy);
before=s.info;targetBefore=target.info;saves=e('saves');targetSaves=targetState('saves');
for input={s.files.mat,copy}
    bytes=colormeasuretest.readBytes(input{1});p=target.prepareChartContinuation(input{1});
    verifyEmpty(t,p.sourceData.blockedReason);
    verifyFalse(t,p.continueEligible);verifyFalse(t,p.newPassEligible);
    verifySubstring(t,p.blockedReason,'unfinished live batch');verifySubstring(t,p.blockedReason,'finish it');
    r=receiver(t,target);
    verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationBlocked');
    verifyEmpty(t,r.chart);verifyEmpty(t,r.measurements);verifyEmpty(t,r.files.folder);
    verifyEqual(t,colormeasuretest.readBytes(input{1}),bytes);
end
verifyFalse(t,s.finished);verifyFalse(t,target.finished);verifyEqual(t,s.info,before);verifyEqual(t,target.info,targetBefore);
verifyEqual(t,e('saves'),saves);verifyEqual(t,targetState('saves'),targetSaves);
verifyEqual(t,e('reads'),1);verifyEqual(t,targetState('reads'),1);
end
function testFinishedOrDeletedOwnerAllowsOriginalAndCopiedDiskSources(t)
for state={'finished','deleted'}
    [s,e]=source(t);copy=fullfile(t.TestData.folder,['released-' state{1} '.mat']);copyfile(s.files.mat,copy);
    path=s.files.mat;segmentId=s.info.segmentId;
    if strcmp(state{1},'finished')
        s.finish(AllowIncompleteChart=true);verifyTrue(t,s.finished);
    else
        colormeasuretest.disposeSession(s);verifyFalse(t,isvalid(s));
        verifyEmpty(t,colormeasure.session.liveSession(segmentId));
    end
    for input={path,copy}
        [target,targetState]=known(t,'VIRTUAL-CR250-001');bytes=colormeasuretest.readBytes(input{1});
        p=target.prepareChartContinuation(input{1});
        verifyEmpty(t,p.blockedReason);verifyTrue(t,p.continueEligible);verifyTrue(t,p.newPassEligible);
        r=receiver(t,target);verifyTrue(t,r.acceptChartContinuation(p));
        verifyEqual(t,r.chart.parentSegmentId,segmentId);verifyEqual(t,r.chart.coverage,1);
        verifyEmpty(t,r.measurements);verifyEqual(t,targetState('reads'),1);
        verifyEqual(t,colormeasuretest.readBytes(input{1}),bytes);
    end
    verifyEqual(t,e('reads'),1);
end
end
function testMaximumInheritedSegmentsBlockBothPreviewActions(t)
[current,sourceState]=source(t);[target,targetState]=known(t,'VIRTUAL-CR250-001');
% Build the boundary with real public handovers. A fixed target supplies its
% existing accepted facts, so no extra acquisition or synthetic ancestry is needed.
for count=1:colormeasure.chart.Run.MaxInheritedSegments
    p=target.prepareChartContinuation(current);verifyTrue(t,p.continueEligible,strjoin(p.unknowns,'; '));
    next=receiver(t,target);verifyTrue(t,next.acceptChartContinuation(p));current=next;
end
verifyNumElements(t,current.chart.sources,16);verifyEqual(t,current.chart.coverage,1);
bytes=colormeasuretest.readBytes(current.files.mat);p=target.prepareChartContinuation(current);
verifyEmpty(t,p.sourceData.blockedReason);verifyTrue(t,colormeasure.chart.eligibility(p.currentContext));
verifyFalse(t,p.continueEligible);verifyFalse(t,p.newPassEligible);
verifySubstring(t,p.blockedReason,'maximum 16 inherited segments');
r=receiver(t,target);verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationSource');
verifyFalse(t,current.finished);verifyEmpty(t,r.chart);verifyEmpty(t,r.measurements);
verifyEqual(t,colormeasuretest.readBytes(current.files.mat),bytes);
verifyEqual(t,sourceState('reads'),1);verifyEqual(t,targetState('reads'),1);
end
function testSavedMatHeaderBoundRefusesBeforeTargetHooksAndAllowsExactLimit(t)
[s,sourceState]=source(t);s.finish(AllowIncompleteChart=true);[target,targetState]=known(t,'VIRTUAL-CR250-001');
path=char(java.io.File(s.files.mat).getCanonicalPath());limit=256*1024^2;
original=builtin('whos','-file',path);wanted=ismember({original.name},{'measurements','batchInfo'});
assertEqual(t,nnz(wanted),2);assertTrue(t,all(strcmp({original(wanted).class},'struct')));
assertLessThan(t,sum([original(wanted).bytes]),limit);
unrelated=fullfile(t.TestData.folder,'unrelated-header.mat');copyfile(path,unrelated);
key='CM_TEST_CHART_CONTINUATION_WHOS';colormeasuretest.preserveAppdata(t,key);
state=containers.Map('KeyType','char','ValueType','any');state('path')=path;state('reportedTotal')=limit+1;state('calls')=0;
setappdata(groot,key,state);folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
file=fullfile(folder,'whos.m');
% Only the header byte count changes. This exercises the load admission
% boundary over a small valid MAT, not a large-file or memory allocation test.
stub=strjoin(["function varargout=whos(varargin)"; ...
    "if nargin==0||~strcmp(varargin{1},'-file')"; ...
    "    quote=char(39);"; ...
    "    args=cellfun(@(value)[quote strrep(char(value),quote,[quote quote]) quote],varargin,'UniformOutput',false);"; ...
    "    query=['builtin(' quote 'whos' quote];"; ...
    "    if ~isempty(args),query=[query ',' strjoin(args,',')];end"; ...
    "    query=[query ')'];"; ...
    "    if nargout==0,evalin('caller',query);else,[varargout{1:nargout}]=evalin('caller',query);end"; ...
    "    return"; ...
    "end"; ...
    "if nargout==0,builtin('whos',varargin{:});return;end"; ...
    "[varargout{1:nargout}]=builtin('whos',varargin{:});"; ...
    "key='CM_TEST_CHART_CONTINUATION_WHOS';"; ...
    "if nargin~=2||nargout~=1||~isappdata(groot,key),return;end"; ...
    "state=getappdata(groot,key);"; ...
    "if ~strcmp(varargin{2},state('path')),return;end"; ...
    "value=varargout{1};wanted=find(ismember({value.name},{'measurements','batchInfo'}));"; ...
    "value(wanted(1)).bytes=state('reportedTotal')-sum([value(wanted(2:end)).bytes]);"; ...
    "varargout{1}=value;state('calls')=state('calls')+1;"; ...
    "end"],newline);
colormeasuretest.writeText(file,stub);t.applyFixture(matlab.unittest.fixtures.PathFixture(folder));assertEqual(t,which('whos'),file);
header=whos('-file',path);verifyEqual(t,rmfield(header,'bytes'),rmfield(original,'bytes'));
verifyEqual(t,sum([header(wanted).bytes]),limit+1);calls=state('calls');
verifyEqual(t,whos('-file',unrelated),builtin('whos','-file',unrelated));verifyEqual(t,state('calls'),calls);
verifyEqual(t,whos('limit'),builtin('whos','limit'));
before=target.info;sourceBefore=s.info;bytes=colormeasuretest.readBytes(path);
keys={'reads','connects','releases','saves'};counts=cellfun(@(name)targetState(name),keys);
caught=colormeasuretest.captureError(@()target.prepareChartContinuation(path));assertNotEmpty(t,caught);
verifyEqual(t,caught.identifier,'Measurement:ChartContinuationSource');
verifyEqual(t,caught.message,'A saved chart must contain bounded ordinary measurements and batchInfo structs (maximum 256 MiB).');
verifyEqual(t,state('calls'),calls+1);verifyEqual(t,target.info,before);
verifyEqual(t,cellfun(@(name)targetState(name),keys),counts);
state('reportedTotal')=limit;header=whos('-file',path);verifyEqual(t,sum([header(wanted).bytes]),limit);
calls=state('calls');preview=target.prepareChartContinuation(path);
verifyEqual(t,state('calls'),calls+1);verifyEmpty(t,preview.blockedReason);
verifyTrue(t,preview.continueEligible);verifyTrue(t,preview.newPassEligible);
verifyEqual(t,target.info,before);verifyEqual(t,cellfun(@(name)targetState(name),keys),counts);
verifyEqual(t,s.info,sourceBefore);verifyEqual(t,sourceState('reads'),1);verifyEqual(t,colormeasuretest.readBytes(path),bytes);
end
function testPermanentSourceBlockSurvivesIneligibleTarget(t)
[s,e]=source(t);e('failRelease')=true; %#ok<NASGU> The release closure reads this Map mutation.
verifyTrue(t,s.measure());
retained=colormeasure.chart.continuationSource(s);verifySubstring(t,retained.blockedReason,'connection cleanup was unfinished');
[target,targetState]=colormeasuretest.continuationBatch(t.TestData.folder,colormeasure.session.services(),'ambient');
t.addTeardown(@()colormeasuretest.disposeSession(target));verifyTrue(t,target.measure());
p=target.prepareChartContinuation(s);[eligible,targetReason]=colormeasure.chart.eligibility(p.currentContext);
verifyFalse(t,eligible);verifyNotEmpty(t,targetReason);verifyNotEqual(t,targetReason,retained.blockedReason);
verifyEqual(t,p.blockedReason,retained.blockedReason);verifyFalse(t,p.continueEligible);verifyFalse(t,p.newPassEligible);
verifyFalse(t,s.finished);verifyFalse(t,target.finished);verifyEqual(t,targetState('reads'),1);
end
function testDiskWitnessIsRecheckedAfterTargetFinalization(t)
[s,~]=source(t);s.finish(AllowIncompleteChart=true);path=s.files.mat;
[target,e]=known(t,'VIRTUAL-CR250-001');p=target.prepareChartContinuation(path);r=receiver(t,target);
e('duringSave')=@mutateSource;
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationStale');
verifyEmpty(t,r.chart);verifyEmpty(t,r.measurements);verifyTrue(t,target.finished);
verifyEqual(t,e('reads'),1);
    function mutateSource()
        data=load(path);data.batchInfo.instrument='Externally edited';save(path,'-struct','data');
    end
end
function testLiveWitnessIsRecheckedAfterAnotherTargetFinishes(t)
[s,~]=source(t);[target,e]=known(t,'VIRTUAL-CR250-001');
p=target.prepareChartContinuation(s);r=receiver(t,target);
e('duringSave')=@()s.editReading(1,'Changed during target Finish','');
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ChartContinuationStale');
verifyEqual(t,e('reads'),1);verifyEmpty(t,r.chart);verifyTrue(t,s.finished);
end
function testKnownReturnedDifferenceRetainsAcceptedFactsAndBlocksPooling(t)
[s,e]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);
e('duringRead')=@()changeReturnedIdentity();verifyTrue(t,r.measure());
attempt=r.chart.passes.attempts(end);verifyEqual(t,attempt.status,'unresolved');
verifyEqual(t,attempt.acceptedContext.material.serial.value,'CHANGED-AFTER-PREVIEW');
verifyEqual(t,e('serial'),'CHANGED-AFTER-PREVIEW');
verifyEqual(t,r.chart.coverage,1);verifyNumElements(t,r.measurements,1);
verifyTrue(t,any(strcmp({r.chart.pendingContext.differences.key},'serial')));
verifyTrue(t,all(isfield(r.chart.pendingContext.differences,{'key','kind','before','after','message'})));
    function changeReturnedIdentity()
        e('serial')='CHANGED-AFTER-PREVIEW';
    end
end
function testSerialEncodingCannotBeInferredOrDeclared(t)
[s,~]=source(t);before=s.chart.passes.context;after=before;
after.material.serialEncoding.value='bytes-hex';d=colormeasure.chart.continuity(before,after);
verifyFalse(t,d.continueEligible);verifyEqual(t,d.differences.key,'serialEncoding');
after.material.serialEncoding=struct('value',[],'certainty','unknown','source','not reported');
d=colormeasure.chart.continuity(before,after,struct('serial','VIRTUAL-CR250-001'));
verifyFalse(t,d.continueEligible);verifyTrue(t,any(contains(d.unknowns,'serialEncoding')));
verifyError(t,@()colormeasure.chart.continuity(before,after,struct('serialEncoding','native-text')), ...
    'Measurement:ChartContinuationContext');
end
function testSelectedScienceAndIdentityMustMatchOriginalReadings(t)
[s,~]=source(t);base=load(s.files.mat);path=fullfile(t.TestData.folder,'changed-context.mat');
for defect={'units','scale','observer','serial','readback'}
    data=base;
    switch defect{1}
        case 'serial',data.measurements.instrumentMetadata.identity.serialNumber='OTHER';
        case 'readback'
            % Claim readback for a fact the original reading never reported.
            material=data.batchInfo.chart.passes.attempts.acceptedContext.material;
            keys=fieldnames(material);keys=keys(cellfun(@(key)strcmp(material.(key).certainty,'unknown'),keys));
            data.batchInfo.chart.passes.attempts.acceptedContext.material.(keys{1})= ...
                struct('value','invented','certainty','readback','source','fabricated');
        otherwise
            key=defect{1};if strcmp(key,'units'),key='xyzUnits';elseif strcmp(key,'scale'),key='xyzScale';end
            data.batchInfo.chart.passes.context.material.(key).value='edited';
            data.batchInfo.chart.passes.attempts.acceptedContext.material.(key).value='edited';
    end
    save(path,'-struct','data');
    verifyError(t,@()s.prepareChartContinuation(path),'Measurement:ChartReference',defect{1});
end
end
function testDurableIntentPrecedesDirectAndPausedFreeAcquisition(t)
[s,e]=source(t);e('duringRead')=@inspectMarker;
verifyTrue(t,s.measure());verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
s.pauseChart();verifyTrue(t,s.measure());
verifyFalse(t,load(s.files.mat).batchInfo.continuationGuard.operationActive);
verifyEqual(t,e('reads'),3);
    function inspectMarker()
        data=load(s.files.mat);verifyTrue(t,data.batchInfo.continuationGuard.operationActive);
        retained=colormeasure.chart.continuationSource(s.files.mat);
        verifySubstring(t,retained.blockedReason,'measurement or its connection cleanup was unfinished');
    end
end
function testMarkerSaveFailurePreventsAnyInstrumentIo(t)
[s,e]=source(t);reads=e('reads');connects=e('connects');e('failSave')=true;
verifyFalse(t,s.measure());verifyEqual(t,e('reads'),reads);verifyEqual(t,e('connects'),connects);
verifyTrue(t,s.needsRecovery);verifyFalse(t,s.busy);verifyNumElements(t,s.measurements,1);
end
function testMissingOriginalOwnerCannotBeHiddenInAnAncestor(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);
data=load(r.files.mat);data.batchInfo.chart.sources.batchInfo= ...
    rmfield(data.batchInfo.chart.sources.batchInfo,'configuration');
path=fullfile(t.TestData.folder,'missing-source-owner.mat');save(path,'-struct','data');
verifyError(t,@()r.prepareChartContinuation(path),'Measurement:ChartReference');
end
function testFailedReleaseCannotClearTheDurableStopGuard(t)
[s,e]=source(t);e('failRelease')=true;
verifyTrue(t,s.measure());verifyNumElements(t,s.measurements,2);
data=load(s.files.mat);verifyTrue(t,data.batchInfo.continuationGuard.operationActive);
verifyTrue(t,s.needsRecovery);
verifyEqual(t,s.status,'Cleanup unconfirmed | 2 readings retained');
verifyError(t,@()s.prepareChartContinuation(s),'Measurement:ConnectionCleanupUnconfirmed');
verifyEqual(t,e('releases'),2);
end
function testFreshOrdinaryDemoOffersNewPassWithoutAutomaticExposure(t)
[s,~]=source(t);a=colormeasure.drivers.cr.demoAdapter('CR250','interactive');
target=colormeasure.session.Session(a,t.TestData.folder);t.addTeardown(@()colormeasuretest.disposeSession(target));
p=target.prepareChartContinuation(s);verifyFalse(t,p.continueEligible);verifyTrue(t,p.newPassEligible);
verifyEmpty(t,target.measurements);verifyFalse(t,s.finished);
verifyTrue(t,any(contains(p.unknowns,'xyzScale')));
r=receiver(t,target);r.acceptChartContinuation(p,Action='new-pass');verifyEmpty(t,r.measurements);verifyEqual(t,r.chart.coverage,0);
end
function testCurrentSchemaRequiredAndMalformedRefsRefuseWithoutTargetMutation(t)
[s,~]=source(t);[target,~]=known(t,'VIRTUAL-CR250-001');
base=load(s.files.mat);path=fullfile(t.TestData.folder,'bad.mat');before=target.info;
for defect={'version','reading','quantity','parent','guard'}
    data=base;identifier='Measurement:ChartReference';
    switch defect{1}
        case 'version',data.batchInfo.chart.version=1;identifier='Measurement:ChartExport';
        case 'reading',data.batchInfo.chart.passes.attempts.readingIndices=99;
        case 'quantity',data.measurements.XYZ=[1 NaN 3];
        case 'parent',data.batchInfo.chart.parentSegmentId='missing';
        case 'guard',data.batchInfo=rmfield(data.batchInfo,'continuationGuard');identifier='Measurement:ChartContinuationSource';
    end
    save(path,'-struct','data');
    verifyError(t,@()target.prepareChartContinuation(path),identifier,defect{1});
    verifyEqual(t,target.info,before);verifyFalse(t,s.finished);
end
end
function testUnconfirmedStopIsStickyInSavedSource(t)
[s,~]=source(t);data=load(s.files.mat);data.batchInfo.continuationGuard.cleanupPending=true;
path=fullfile(t.TestData.folder,'unconfirmed.mat');save(path,'-struct','data');
p=s.prepareChartContinuation(path);verifyFalse(t,p.newPassEligible);verifyFalse(t,p.continueEligible);
verifySubstring(t,p.blockedReason,'Continue from that open batch, or finish it and choose its current saved chart at');
verifySubstring(t,p.blockedReason,s.files.mat);
verifyFalse(t,p.cleanupDeclarationRequired);r=receiver(t,s);
verifyError(t,@()r.acceptChartContinuation(p,Action='new-pass'),'Measurement:ChartContinuationBlocked');verifyFalse(t,s.finished);
% Both named routes work: the open batch now, and its saved chart once finished.
[target,~]=known(t,'VIRTUAL-CR250-001');
verifyTrue(t,target.prepareChartContinuation(s).continueEligible);
verifySubstring(t,target.prepareChartContinuation(s.files.mat).blockedReason,'unfinished live batch');
s.finish(AllowIncompleteChart=true);
p=target.prepareChartContinuation(path);verifyFalse(t,p.continueEligible);
verifySubstring(t,p.blockedReason,['Choose its current saved chart at ' s.files.mat]);
verifyFalse(t,contains(p.blockedReason,'open batch, or'));
verifyTrue(t,target.prepareChartContinuation(s.files.mat).continueEligible);
end
function testEndedOwnerCleanupNeedsRecordedDeclaration(t)
% A finished batch saved with unconfirmed cleanup stays refused while it is
% open; once no owner remains (as after a restart) only the operator's two
% checks resolve it, and the new batch saves them for its ancestor.
[s,e]=source(t);e('failRelease')=true; %#ok<NASGU> The release closure reads this Map mutation.
verifyTrue(t,s.measure());s.finish(AllowIncompleteChart=true);path=s.files.mat;
verifyTrue(t,load(path).batchInfo.continuationGuard.cleanupPending);
segment=s.info.segmentId;runId=s.chart.runId;
[target,~]=known(t,'VIRTUAL-CR250-001');
p=target.prepareChartContinuation(path);verifySubstring(t,p.blockedReason,'still open');
verifyFalse(t,p.cleanupDeclarationRequired);verifyFalse(t,p.newPassEligible);
colormeasuretest.disposeSession(s);
p=target.prepareChartContinuation(path);verifyEmpty(t,p.blockedReason);
verifyTrue(t,p.cleanupDeclarationRequired);verifyTrue(t,p.continueEligible);
r=receiver(t,target);
verifyError(t,@()r.acceptChartContinuation(p),'Measurement:ConnectionCleanup');
verifyError(t,@()r.acceptChartContinuation(p,ConfirmConnectionClosed=true, ...
    ConfirmInstrumentIdle=true,CleanupDeclaration=' '),'Measurement:ConnectionCleanup');
verifyEmpty(t,r.chart);verifyFalse(t,target.finished);
note='Unplugged and reconnected the cable; the display shows no measurement.';
r.acceptChartContinuation(p,ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true,CleanupDeclaration=note);
record=load(r.files.mat).batchInfo.chartIoConfirmations;
verifyEqual(t,{record.segmentId,record.runId,record.declaration},{segment,runId,note});
verifyTrue(t,record.connectionClosed&&record.instrumentIdle);
verifyTrue(t,any(contains({r.log.message},'operator declaration')));
next=colormeasure.chart.continuationSource(r.files.mat);
verifyEmpty(t,next.blockedReason);verifyEmpty(t,next.retainedUncertainty);
% A declaration held by the middle generation resolves the ancestor when
% a third generation continues. The uncertain source cannot clear itself.
r.finish(AllowIncompleteChart=true);
sourceBytes=colormeasuretest.readBytes(path);middleBytes=colormeasuretest.readBytes(r.files.mat);
preview=target.prepareChartContinuation(r.files.mat);third=receiver(t,target);
third.acceptChartContinuation(preview);
thirdData=colormeasure.chart.continuationSource(third.files.mat);
verifyNumElements(t,thirdData.chart.sources,2);verifyEmpty(t,thirdData.blockedReason);
verifyEmpty(t,thirdData.retainedUncertainty);
verifyEmpty(t,thirdData.batchInfo.chartIoConfirmations);
verifyEqual(t,thirdData.chart.sources(2).batchInfo.chartIoConfirmations,record);
verifyEqual(t,colormeasuretest.readBytes(path),sourceBytes);
verifyEqual(t,colormeasuretest.readBytes(r.files.mat),middleBytes);
self=load(path);self.batchInfo.chartIoConfirmations=record;
selfPath=fullfile(t.TestData.folder,'self-declaration.mat');save(selfPath,'-struct','self');
verifySubstring(t,colormeasure.chart.continuationSource(selfPath).blockedReason,'was unfinished');
original=colormeasuretest.readBytes(r.files.mat);base=load(r.files.mat);
for defect={'run','empty-time','blank-time','nontext-time'}
    data=base;
    switch defect{1}
        case 'run',data.batchInfo.chartIoConfirmations.runId='OTHER-RUN';
        case 'empty-time',data.batchInfo.chartIoConfirmations.confirmedAtUTC='';
        case 'blank-time',data.batchInfo.chartIoConfirmations.confirmedAtUTC=' ';
        case 'nontext-time',data.batchInfo.chartIoConfirmations.confirmedAtUTC=42;
    end
    edited=fullfile(t.TestData.folder,['bad-declaration-' defect{1} '.mat']);save(edited,'-struct','data');
    rejected=colormeasure.chart.continuationSource(edited);
    verifySubstring(t,rejected.blockedReason,'was unfinished',defect{1});
    verifyEqual(t,colormeasuretest.readBytes(r.files.mat),original);
end
data=load(r.files.mat);data.batchInfo.chartIoConfirmations=data.batchInfo.chartIoConfirmations([]);
edited=fullfile(t.TestData.folder,'undeclared-ancestor.mat');save(edited,'-struct','data');
verifySubstring(t,colormeasure.chart.continuationSource(edited).blockedReason,'was unfinished');
end
function testResolvedOpenOwnerPointsToItsCurrentMatInsteadOfStaleCopy(t)
[s,e]=source(t);e('failRelease')=true;verifyTrue(t,s.measure());
s.finish(AllowIncompleteChart=true);
stale=fullfile(t.TestData.folder,'earlier-unconfirmed.mat');copyfile(s.files.mat,stale);
bytes=colormeasuretest.readBytes(stale);reads=e('reads');
s.confirmChartIoStopped(ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    Declaration='Closed the connection and checked that the instrument is idle.');
folder=fullfile(t.TestData.folder,'resolved');mkdir(folder);e('failSave')=true;s.saveElsewhere(folder);
assertFalse(t,s.chartIoUnconfirmed);assertTrue(t,s.finished);assertTrue(t,s.needsRecovery);
[target,state]=known(t,'VIRTUAL-CR250-001');before=target.info;
preview=target.prepareChartContinuation(stale);
verifyFalse(t,preview.continueEligible);verifyFalse(t,preview.newPassEligible);
verifyFalse(t,preview.cleanupDeclarationRequired);
verifySubstring(t,preview.blockedReason,'needs save recovery');
verifySubstring(t,preview.blockedReason,'Recover saving there (Retry save or Another folder), then choose its current saved chart');
r=receiver(t,target);verifyError(t,@()r.acceptChartContinuation(preview),'Measurement:ChartContinuationBlocked');
verifyEmpty(t,r.chart);verifyFalse(t,target.finished);verifyEqual(t,target.info,before);
verifyEqual(t,colormeasuretest.readBytes(stale),bytes);
e('failSave')=false;s.retrySave();assertFalse(t,s.needsRecovery);
preview=target.prepareChartContinuation(stale);
verifyFalse(t,preview.continueEligible);verifyFalse(t,preview.newPassEligible);
verifyFalse(t,preview.cleanupDeclarationRequired);
verifySubstring(t,preview.blockedReason,'already saved its resolved connection cleanup');
verifySubstring(t,preview.blockedReason,s.files.mat);
verifyTrue(t,target.prepareChartContinuation(s.files.mat).continueEligible);
verifyEqual(t,target.info,before);verifyEqual(t,state('reads'),1);verifyEqual(t,e('reads'),reads);
verifyEqual(t,colormeasuretest.readBytes(stale),bytes);
end
function testInterruptedAcquisitionContinuesAfterDeclaration(t)
% A copy taken mid-acquisition models a crash: the started attempt can never
% complete, so the continuing chart shows it as interrupted and measures anew.
[s,e]=source(t);snapshot=fullfile(t.TestData.folder,'interrupted.mat');
e('duringRead')=@()copyfile(s.files.mat,snapshot);verifyTrue(t,s.measure());
verifyEqual(t,e('reads'),2);colormeasuretest.disposeSession(s);
saved=load(snapshot).batchInfo;verifyTrue(t,saved.continuationGuard.operationActive);
verifyEqual(t,saved.chart.passes.attempts(end).status,'started');
[target,~]=known(t,'VIRTUAL-CR250-001');p=target.prepareChartContinuation(snapshot);
verifyTrue(t,p.cleanupDeclarationRequired);verifyEmpty(t,p.blockedReason);
r=receiver(t,target);
verifyError(t,@()r.acceptChartContinuation(p,ConfirmConnectionClosed=true),'Measurement:ConnectionCleanup');
r.acceptChartContinuation(p,ConfirmConnectionClosed=true,ConfirmInstrumentIdle=true, ...
    CleanupDeclaration='Restarted MATLAB; the instrument display is idle.');
cell=r.chart.cells(2);verifyEqual(t,cell.status,'interrupted');verifyEqual(t,cell.selectedAttempt,0);
verifySubstring(t,cell.reason,'no reading was retained');
verifyEmpty(t,colormeasure.chart.continuationSource(r.files.mat).blockedReason);
verifyTrue(t,r.measure());verifyEqual(t,r.chart.cells(2).status,'measured');
end
function testPortableHistoryRejectsCyclesDuplicateIdsAndEditedAttempts(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);r.acceptChartContinuation(p);base=load(r.files.mat);
for defect={'cycle','duplicate','attempt','pass','definition'}
    data=base;
    switch defect{1}
        case 'cycle',data.batchInfo.chart.sources.parentSegmentId=data.batchInfo.segmentId;
        case 'duplicate',data.batchInfo.chart.sources(2)=data.batchInfo.chart.sources(1);
        case 'attempt',data.batchInfo.chart.passes.attempts.notes='Edited frozen history';
        case 'pass',data.batchInfo.chart.passes.id='Reassigned frozen pass';
        case 'definition',data.batchInfo.chart.sources.batchInfo.chart.definition.name='Reinterpreted';
    end
    path=fullfile(t.TestData.folder,['bad-' defect{1} '.mat']);save(path,'-struct','data');
    verifyError(t,@()r.prepareChartContinuation(path),'Measurement:ChartReference',defect{1});
    if strcmp(defect{1},'attempt')
        verifySnapshotRefusal(t,data,'frozen history');
    elseif strcmp(defect{1},'pass')
        verifySnapshotRefusal(t,data,'immediate parent''s order');
    end
end
end
function testLinkedContinuationRecordAndEvidenceBindFrozenParent(t)
[s,~]=source(t);declarations=struct('serial','VIRTUAL-CR250-001');
p=s.prepareChartContinuation(s,Declarations=declarations);r=receiver(t,s);
r.acceptChartContinuation(p,Declarations=declarations);base=load(r.files.mat);
colormeasure.chart.validateSnapshot(base.batchInfo,base.measurements);
for defect={'missing','extra','shape','source','pass','pendingPass','pendingContext','action', ...
        'unsupportedDeclaration','changedDeclaration','declarationShape','missingEvidence', ...
        'evidenceFields','evidenceKey','evidenceValue','evidenceCertainty','evidenceScope','duplicateEvidence'}
    data=base;record=data.batchInfo.chart.continuation;
    message='complete current continuation record';
    switch defect{1}
        case 'missing',data.batchInfo.chart=rmfield(data.batchInfo.chart,'continuation');
        case 'extra',record.extra=true;
        case 'shape',record=repmat(record,1,2);
        case 'source',record.sourceSegmentId='not-the-parent';message='immediate frozen parent';
        case 'pass',record.sourcePassId='missing-pass';message='immediate frozen parent capture';
        case 'pendingPass',record.sourcePendingPassId='missing-pass';message='immediate frozen parent capture';
        case 'pendingContext',record.sourcePendingContext=struct('edited',true);message='immediate frozen parent capture';
        case 'action',record.action='restart';message='immediate frozen parent';
        case 'unsupportedDeclaration',record.declarations=struct('xyzScale','confirmed');message='continuation declarations are invalid';
        case 'changedDeclaration',record.declarations.serial='OTHER';message='continuation declarations are invalid';
        case 'declarationShape',record.declarations=struct([]);message='ordinary scalar record';
        case 'missingEvidence',record.declarationEvidence=record.declarationEvidence([]);message='operator-declared scope';
        case 'evidenceFields',record.declarationEvidence.extra=true;message='operator-declared scope';
        case 'evidenceKey',record.declarationEvidence.key='accessory';message='operator-declared scope';
        case 'evidenceValue',record.declarationEvidence.value='OTHER';message='operator-declared scope';
        case 'evidenceCertainty',record.declarationEvidence.certainty='readback';message='operator-declared scope';
        case 'evidenceScope',record.declarationEvidence.scope='current target';message='operator-declared scope';
        case 'duplicateEvidence',record.declarationEvidence=[record.declarationEvidence record.declarationEvidence];message='operator-declared scope';
    end
    if ~strcmp(defect{1},'missing'),data.batchInfo.chart.continuation=record;end
    verifySnapshotRefusal(t,data,message);
end
root=load(s.files.mat);root.batchInfo.chart.continuation=base.batchInfo.chart.continuation;
verifySnapshotRefusal(t,root,'original chart must not claim');
end
function testContinuationPendingPassBindsCapturedActivePass(t)
[s,~]=source(t);first=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();
[target,~]=known(t,'VIRTUAL-CR250-001');p=target.prepareChartContinuation(s,PassId=first);
r=receiver(t,target);r.acceptChartContinuation(p);data=load(r.files.mat);
verifyNotEqual(t,data.batchInfo.chart.continuation.sourcePendingPassId,first);
data.batchInfo.chart.continuation.sourcePendingPassId=first;
verifySnapshotRefusal(t,data,'immediate frozen parent capture');
end
function testCurrentAttemptsCannotEnterAnotherInheritedPass(t)
[s,~]=source(t);first=s.chart.passes.id;
s.setInstrumentSettings(struct('speed',2));s.acceptChartContext();s.measure();
[target,~]=known(t,'VIRTUAL-CR250-001');p=target.prepareChartContinuation(s,PassId=first);
r=receiver(t,target);r.acceptChartContinuation(p);verifyTrue(t,r.measure());base=load(r.files.mat);
colormeasure.chart.validateSnapshot(base.batchInfo,base.measurements);
data=base;data.batchInfo.chart.activePass=2;
verifySnapshotRefusal(t,data,'active inherited pass');
data=base;passes=data.batchInfo.chart.passes;attempt=passes(1).attempts(end);
verifyEqual(t,attempt.segmentId,data.batchInfo.segmentId);verifyEqual(t,attempt.name,'B1');
passes(1).attempts(end)=[];passes(1).selectedAttempt(2)=0;
passes(2).attempts(end+1)=attempt;passes(2).selectedAttempt(2)=numel(passes(2).attempts);
data.batchInfo.chart.passes=passes;
verifySnapshotRefusal(t,data,'Current-segment attempts in inherited passes');
data=base;data.batchInfo.chart.passes(1).attempts(1)=[];
verifySnapshotRefusal(t,data,'frozen history');
end
function testNewPassContinuationCannotReactivateInheritedPass(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);
r.acceptChartContinuation(p,Action='new-pass');data=load(r.files.mat);
colormeasure.chart.validateSnapshot(data.batchInfo,data.measurements);
data.batchInfo.chart.activePass=1;
verifySnapshotRefusal(t,data,'active inherited pass');
end
function testUnclassifiedDescendantRoutesRefuseContinuationAndDeclaration(t)
[s,~]=source(t);preview=s.prepareChartContinuation(s);r=receiver(t,s);
verifyTrue(t,r.acceptChartContinuation(preview,Action='new-pass'));verifyTrue(t,r.measure());
r.finish(AllowIncompleteChart=true);originalPath=r.files.mat;base=load(originalPath);
colormeasuretest.disposeSession(r);original=colormeasuretest.readBytes(originalPath);
verifyNumElements(t,base.batchInfo.chart.passes,2);verifyNumElements(t,base.batchInfo.chart.sources,1);
[target,state]=known(t,'VIRTUAL-CR250-001');before=target.info;reads=state('reads');
ancestor=base.batchInfo.chart.sources(1);
root=struct('measurements',ancestor.measurements,'batchInfo',ancestor.batchInfo);
for owner=0:2
    for uncertain=[false true]
        for route={'UNCLASSIFIED','PR','ARGYLL'}
            data=base;passIndex=owner;
            if owner==0,data=root;passIndex=1;end
            % Material facts remain CR; recognized routes must not relabel
            % the original, inherited or current pass through its top-level field.
            verifyEqual(t,data.batchInfo.chart.passes(passIndex).context.material.route.value,'CR');
            data.batchInfo.chart.passes(passIndex).context.route=route{1};
            data.batchInfo.continuationGuard.operationActive=uncertain;
            path=fullfile(t.TestData.folder,sprintf('retained-route-%d-%d-%s.mat',owner,uncertain,route{1}));
            save(path,'-struct','data');bytes=colormeasuretest.readBytes(path);
            verifyError(t,@()colormeasure.chart.continuationSource(path),'Measurement:ChartContinuationSource');
            verifyError(t,@()target.prepareChartContinuation(path),'Measurement:ChartContinuationSource');
            verifyEqual(t,colormeasuretest.readBytes(path),bytes);
            verifyEqual(t,target.info,before);verifyEqual(t,state('reads'),reads);
        end
    end
end
% Both ordinary continuation and cleanup declaration remain valid for the
% same classified descendant, including its inherited pass.
preview=target.prepareChartContinuation(originalPath);
verifyTrue(t,preview.continueEligible);verifyTrue(t,preview.newPassEligible);
verifyFalse(t,preview.cleanupDeclarationRequired);
base.batchInfo.continuationGuard.operationActive=true;
path=fullfile(t.TestData.folder,'classified-descendant-uncertainty.mat');save(path,'-struct','base');
preview=target.prepareChartContinuation(path);
verifyEmpty(t,preview.blockedReason);verifyTrue(t,preview.cleanupDeclarationRequired);
verifyTrue(t,preview.continueEligible);verifyTrue(t,preview.newPassEligible);
verifyEqual(t,colormeasuretest.readBytes(originalPath),original);
verifyEqual(t,target.info,before);verifyEqual(t,state('reads'),reads);
end

function testLaterNewPassRemainsValidAfterEitherContinuationAction(t)
for action={'continue','new-pass'}
    [s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);
    r.acceptChartContinuation(p,Action=action{1});verifyTrue(t,r.measure());
    r.setInstrumentSettings(struct('speed',2));r.acceptChartContext();verifyTrue(t,r.measure());
    data=load(r.files.mat);[chart,~,indices]=colormeasure.chart.validateSnapshot(data.batchInfo,data.measurements);
    verifyEqual(t,chart.continuation.action,action{1});
    verifyFalse(t,any(strcmp({chart.sources(end).batchInfo.chart.passes.id},chart.passes(chart.activePass).id)));
    verifyNotEmpty(t,indices{chart.activePass});
    preview=r.prepareChartContinuation(r);verifyTrue(t,preview.continueEligible,strjoin(preview.unknowns,'; '));
end
end
function testCorruptedCurrentAndInheritedAppendLinksRefuseBeforeExportHook(t)
[s,~]=source(t);p=s.prepareChartContinuation(s);r=receiver(t,s);
r.acceptChartContinuation(p);verifyTrue(t,r.measure());base=load(r.files.mat);
for owner={'current','inherited','duplicate-reading-id'}
    data=base;
    if strcmp(owner{1},'current')
        data.batchInfo.chart.passes.attempts(end).readingIndices=[1 1];
    elseif strcmp(owner{1},'inherited')
        data.batchInfo.chart.sources.batchInfo.chart.passes.attempts.readingIndices=2;
    else
        data.measurements.readingId='same-original-reading';
        data.batchInfo.chart.sources.measurements.readingId='same-original-reading';
        verifySnapshotRefusal(t,data,'Original reading identities must be unique');
    end
    hooks=0;adapter=struct('viewData',@viewData);
    verifyError(t,@()colormeasure.chart.selectedTable(data.measurements,data.batchInfo,adapter), ...
        'Measurement:ChartReference');verifyEqual(t,hooks,0);
end
% Native IDs are optional for other direct sources. Their original segment
% and append-index identity must still allow the healthy retained snapshot.
assertFalse(t,isfield(base.measurements,'readingId'));
assertFalse(t,isfield(base.batchInfo.chart.sources.measurements,'readingId'));
verifyWarningFree(t,@()colormeasure.chart.validateSnapshot(base.batchInfo,base.measurements));
distinct=base;distinct.measurements.readingId='current-original-reading';
distinct.batchInfo.chart.sources.measurements.readingId='inherited-original-reading';
verifyWarningFree(t,@()colormeasure.chart.validateSnapshot(distinct.batchInfo,distinct.measurements));
    function value=viewData(varargin)
        hooks=hooks+1;value=struct();
    end
end
function verifySnapshotRefusal(t,data,message)
caught=[];
try
    colormeasure.chart.validateSnapshot(data.batchInfo,data.measurements);
catch problem
    caught=problem;
end
assertNotEmpty(t,caught,'Expected the snapshot owner to refuse edited retained data.');
verifyEqual(t,caught.identifier,'Measurement:ChartReference');verifySubstring(t,caught.message,message);
end
function testObservableDeclarationsDoNotWaiveVerifiedIdentityOrScale(t)
[s,~]=source(t);context=s.chart.passes.context;unknown=context;
unknown.material.serial=struct('value',[],'certainty','unknown','source','not reported');
decision=colormeasure.chart.continuity(context,unknown);verifyFalse(t,decision.continueEligible);
verifyEqual(t,decision.declarableFacts.key,'serial');
decision=colormeasure.chart.continuity(context,unknown,struct('serial','VIRTUAL-CR250-001'));
verifyTrue(t,decision.continueEligible);verifyEqual(t,decision.declarations.certainty,'operator-declared');
verifyError(t,@()colormeasure.chart.continuity(context,unknown,struct('serial','OTHER')), ...
    'Measurement:ChartContinuationContext');
verifyError(t,@()colormeasure.chart.continuity(context,unknown,struct('xyzScale','confirmed')), ...
    'Measurement:ChartContinuationContext');
end
function pass=reassignedPass(pass,rewriteCoordinates)
pass.attempts(1).cellIndex=2;pass.selectedAttempt=[0 1];
if rewriteCoordinates
    pass.attempts(1).row=1;pass.attempts(1).column=2;pass.attempts(1).name='B1';
end
end
function [data,identifier]=incompatibleChart(data,defect)
identifier='Measurement:ChartExport';
switch defect
    case 'previousVersion'
        data.batchInfo.chart.version=4;
        for p=1:numel(data.batchInfo.chart.passes)
            pass=data.batchInfo.chart.passes(p);
            pass.context.material=rmfield(pass.context.material,'spectralGrid');
            for n=1:numel(pass.attempts)
                pass.attempts(n).acceptedContext.material=rmfield(pass.attempts(n).acceptedContext.material,'spectralGrid');
            end
            data.batchInfo.chart.passes(p)=pass;
        end
    case 'retiredPassField',data.batchInfo.chart.passes.referenceIllustration=struct([]);
    case 'retiredPlacement',data.batchInfo.chart.passes.positionReference=struct([]);
    case 'retiredAttemptField',data.batchInfo.chart.passes.attempts.positionCheck=struct([]);
    case 'missingAttemptField'
        data.batchInfo.chart.passes.attempts=rmfield(data.batchInfo.chart.passes.attempts,'context');
    case 'extraChartField',data.batchInfo.chart.referenceIllustration=struct([]);
    case 'extraSourceField'
        identifier='Measurement:ChartReference';
        data.batchInfo.chart.sources=struct('segmentId',{}, ...
        'parentSegmentId',{},'measurements',{},'batchInfo',{},'sourceSha256',{},'retired',{});
end
end
function [s,e]=source(t)
[s,e]=colormeasuretest.continuationBatch(t.TestData.folder);t.addTeardown(@()colormeasuretest.disposeSession(s));
s.startChart(colormeasure.chart.definition('custom','Linked grid',1,2));verifyTrue(t,s.measure());
end
function [s,e]=known(t,serial)
[s,e]=colormeasuretest.continuationBatch(t.TestData.folder);e('serial')=serial;
t.addTeardown(@()colormeasuretest.disposeSession(s));verifyTrue(t,s.measure());
end
function r=receiver(t,s)
r=s.freshChartContinuationSession();t.addTeardown(@()colormeasuretest.disposeSession(r));
end

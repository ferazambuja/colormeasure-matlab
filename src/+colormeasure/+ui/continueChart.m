function [session,action]=continueChart(target,source,options)
% CONTINUECHART Preview a linked chart before explicitly creating its segment.
% Core validates and classifies both disk and live sources. The UI publishes
% only an attached receiver; inspection and Cancel leave the source untouched.
arguments
    target (1,1) colormeasure.session.Session
    source
    options.IO struct=struct([])
end
session=[];action='';owner=target.window;
assert(isscalar(owner)&&isgraphics(owner),'Measurement:ChartContinuationWindow', ...
    'Open the current measurement window before continuing a chart.');
preview=target.prepareChartContinuation(source);
io=target.services;
if ~isempty(options.IO),io=options.IO;end
if isfield(io,'chooseChartContinuation')
    choice=io.chooseChartContinuation(preview);
    if isempty(choice),return;end
    acknowledged=false;
    if isfield(choice,'acknowledgeVersionChange'),acknowledged=choice.acknowledgeVersionChange;end
    passId=preview.source.passId;
    if isfield(choice,'passId'),passId=choice.passId;end
    preview=target.prepareChartContinuation(source, ...
        Declarations=choice.declarations,PassId=passId);
    cleanup='';if isfield(choice,'cleanupDeclaration'),cleanup=choice.cleanupDeclaration;end
    apply(preview,choice.action,choice.declarations,acknowledged,cleanup);
else
    if isa(source,'colormeasure.session.Session')
        kind='Another retained batch';if source==target,kind='This batch';end
        label=[kind ' · ' source.label ' · started ' source.startedAtLocal];
        if ~source.finished,label=[label ' · will be finished and saved on acceptance'];end
    else
        label=char(source);
    end
    view=colormeasure.ui.ChartContinuationView(owner,preview,label,@apply, ...
        @(declarations,passId)target.prepareChartContinuation(source, ...
            Declarations=declarations,PassId=passId),@()[]);
    setappdata(owner,'ChartContinuationPreview',view);
    cleanup=onCleanup(@()closePreview(owner,view));
    uiwait(view.Figure);
end
if isempty(session)||isempty(action),return;end
% The registry is changed only after Core has attached the accepted history.
% An unrelated retained owner cannot be silently replaced by this UI path.
try
    assertReceiverOwner(target,session,true);
    session.show();
    colormeasure.session.sessionRegistry('put',session.adapterKey,session,session.saveParent);
    if isvarname(session.workspaceName),assignin('base',session.workspaceName,session);end
catch problem
    retainRecovery(session);
    rethrow(problem);
end
if isgraphics(owner)
    if strcmp(owner.WindowState,'maximized'),session.window.WindowState='maximized';
    else,session.window.WindowState='normal';session.window.Position=owner.Position;end
    % Match the current window, not the receiver's original launch default.
    % A hidden launch may have been explicitly shown before continuation.
    session.window.Visible=owner.Visible;
end
% The attached receiver owns its first-save recovery. Old setup windows
% must not cover that recovery, even when the first save needs attention.
target.hide();
if isa(source,'colormeasure.session.Session')&&isvalid(source)&&source~=target,source.hide();end
if strcmp(session.window.Visible,'on'),figure(session.window);end

    function apply(candidate,selected,declarations,acknowledged,cleanup)
        % A nonblank cleanup text is the operator's two-check declaration.
        assert(ismember(selected,{'continue','new-pass'}), ...
            'Measurement:ChartContinuationAction','Choose Continue selected pass, Start new pass or Cancel.');
        receiver=target.freshChartContinuationSession();
        try
            assertReceiverOwner(target,receiver,false);
            declared=~isempty(cleanup);
            [~,attached]=receiver.acceptChartContinuation(candidate,Action=selected,Declarations=declarations, ...
                AcknowledgeVersionChange=acknowledged,ConfirmConnectionClosed=declared, ...
                ConfirmInstrumentIdle=declared,CleanupDeclaration=cleanup);
            assert(attached==receiver&&~isempty(receiver.chart), ...
                'Measurement:ChartContinuationAcceptance','The linked chart was not attached.');
        catch problem
            if isvalid(receiver)&&isempty(receiver.chart)&&isempty(receiver.measurements)
                delete(receiver);
            else
                % Never discard a segment after data or history is attached.
                retainRecovery(receiver);
            end
            rethrow(problem);
        end
        session=receiver;action=selected;
    end
end

function assertReceiverOwner(target,receiver,requireFinished)
registry=colormeasure.session.sessionRegistry('get');
index=find(strcmp(registry.keys,receiver.adapterKey),1);
if isempty(index),return;end
previous=registry.sessions{index};
assert(previous==target,'Measurement:ChartContinuationOwnership', ...
    'Another retained batch owns this instrument. Open its window before continuing a chart; no batch was replaced.');
if requireFinished
    assert(previous.finished&&~previous.busy&&~previous.chartIoUnconfirmed&&~previous.needsRecovery, ...
        'Measurement:ChartContinuationOwnership','Recover the original owner before publishing the linked batch.');
end
end
function closePreview(owner,view)
if isscalar(owner)&&isgraphics(owner)&&isappdata(owner,'ChartContinuationPreview')&& ...
        isequal(getappdata(owner,'ChartContinuationPreview'),view)
    rmappdata(owner,'ChartContinuationPreview');
end
if isvalid(view),delete(view);end
end
function retainRecovery(session)
% The ordinary launcher publishes later. Retain the exact accepted receiver
% first so UI/registry failure cannot make its saved history unreachable.
name=matlab.lang.makeValidName(['chartContinuation_' session.info.segmentId]);
assignin('base',name,session);
fprintf('Linked chart retained for recovery as %s.\n',name);
end

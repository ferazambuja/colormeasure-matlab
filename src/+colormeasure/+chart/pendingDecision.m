function value=pendingDecision(chart,passId)
%PENDINGDECISION Find retained unresolved decisions for one original pass.
% A later segment cannot erase an acquired interpretation decision by making
% another pass active. Planned, unacquired setting changes remain history.
value=struct([]);
if strcmp(chart.passes(chart.activePass).id,passId)&&~isempty(chart.pendingContext)
    value=chart.pendingContext;return
end
for source=reshape(chart.sources,1,[])
    saved=source.batchInfo.chart;pending=saved.pendingContext;
    required=~isempty(pending)&& ...
        ((isfield(pending,'requiresDecision')&&isequal(pending.requiresDecision,true))|| ...
        (isfield(pending,'interpretationError')&&isequal(pending.interpretationError,true)));
    if strcmp(saved.passes(saved.activePass).id,passId)&&required
        value=pending;return
    end
end
end

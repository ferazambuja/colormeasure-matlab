function recovery=companionFailure(problem,stage)
%COMPANIONFAILURE Classify recovery by the failed boundary, not retained history.
% Reading or publishing bytes can be retried or moved to another destination.
% Changed source identity needs a fresh saved copy. Deterministic selected-
% table or result-contract refusals need corrected data or code.
recovery=struct('retryable',false,'relocatable',false);
if any(strcmp(problem.identifier,{'Measurement:CompanionSource','Measurement:CompanionSourceChanged', ...
        'Measurement:CompanionOutputChanged'}))
    recovery.relocatable=~strcmp(problem.identifier,'Measurement:CompanionSource');
elseif strcmp(problem.identifier,'Measurement:FileDigest')
    recovery.retryable=true;recovery.relocatable=true;
elseif any(strcmp(stage,{'source','publication','output'}))
    recovery.retryable=true;recovery.relocatable=true;
end
end

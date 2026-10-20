function demoBatch(session, count, readingIdentifier, finishIdentifier)
%DEMOBATCH Headless synthetic batch: acquire, finish, and propagate failed work.
%   demoBatch(session, count, readingIdentifier, finishIdentifier) measures
%   count synthetic samples, finishes the batch and errors with the family's
%   identifiers when a reading fails or the batch does not finish saving.
%   Shared by the family demo sessions; each keeps its own identifiers.
%   Fernando Voltolini de Azambuja, 2026.
for index = 1:count
    if ~session.measure(sprintf('Sample %03d', index), 'SYNTHETIC DEMO')
        error(readingIdentifier, 'Synthetic reading %d failed: %s. Inspect the session log.', ...
            index, session.activity);
    end
end
session.finish();
if ~session.finished || session.needsRecovery
    error(finishIdentifier, 'Synthetic batch did not finish saving. MAT: %s CSV: %s', ...
        session.saveError, session.exportError);
end
end

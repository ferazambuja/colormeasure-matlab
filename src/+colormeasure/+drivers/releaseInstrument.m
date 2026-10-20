function releaseInstrument(instrument)
%RELEASEINSTRUMENT Confirm the native port owner's cleanup before destruction.
% Settings restoration warnings do not imply host I/O has stopped; Disconnect
% reports that separately. Session retains its guard when confirmation fails.
assert(isa(instrument,'handle')&&isscalar(instrument)&&isvalid(instrument), ...
    'Measurement:ConnectionCleanupUnconfirmed', ...
    'The original instrument owner is unavailable; connection cleanup is unconfirmed.');
closed=instrument.Disconnect();
assert(isequal(closed,true),'Measurement:ConnectionCleanupUnconfirmed', ...
    'The instrument connection owner could not confirm connection cleanup.');
delete(instrument);
end

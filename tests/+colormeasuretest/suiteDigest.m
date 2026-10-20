function value = suiteDigest(names)
%SUITEDIGEST SHA-256 of test names in order, one name per line.
% Concurrent workers each discover the suite. Equal digests show that they
% discovered the same tests in the same order, and a merged result list with
% that digest ran exactly those tests, once each, in suite order.
% Fernando Voltolini de Azambuja, 2026.
engine = java.security.MessageDigest.getInstance('SHA-256');
text = unicode2native(strjoin(cellstr(names),newline),'UTF-8');
if ~isempty(text), engine.update(typecast(text,'int8')); end
value = lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2).',1,[]));
end

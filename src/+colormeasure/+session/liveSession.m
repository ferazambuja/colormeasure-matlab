function owner=liveSession(segmentId,session)
%LIVESESSION Find a live segment owner without retaining sessions or doing I/O.
% Weak references cover CLI-created sessions as well as registered windows.
key='colormeasureLiveSessions';entries=getappdata(groot,key);
if isempty(entries),entries={};end
entries=entries(cellfun(@(entry)isscalar(entry.reference.Handle)&& ...
    isvalid(entry.reference.Handle),entries));
if nargin==2
    entries{end+1}=struct('segmentId',segmentId,'reference',matlab.lang.WeakReference(session));
end
setappdata(groot,key,entries);owner=[];
matches=cellfun(@(entry)strcmp(entry.segmentId,segmentId),entries);
assert(nnz(matches)<=1,'Measurement:ChartContinuationSource','The live segment identity is ambiguous.');
if any(matches),owner=entries{find(matches,1)}.reference.Handle;end
end

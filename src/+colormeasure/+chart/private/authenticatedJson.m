function value=authenticatedJson(path,expectedDigest,limit)
%AUTHENTICATEDJSON Read bounded, immutable packaged chart JSON by exact digest.
[file,message]=fopen(path,'rb');
assert(file>=0,'colormeasure:Chart:Resource','Cannot read bundled chart data %s: %s. Reinstall the complete application.',path,message);
cleanup=onCleanup(@()fclose(file));
assert(fseek(file,0,'eof')==0,'colormeasure:Chart:Resource','Cannot seek bundled chart data %s.',path);
count=ftell(file);
assert(count>=1&&count<=limit&&fseek(file,0,'bof')==0, ...
    'colormeasure:Chart:Resource','Bundled chart data %s is empty or exceeds its supported size (%d bytes).',path,limit);
[bytes,actual]=fread(file,[1 count],'*uint8');
[message,status]=ferror(file);
assert(actual==count&&status==0,'colormeasure:Chart:Resource','Cannot read complete bundled chart data %s: %s.',path,message);
assert(fseek(file,0,'eof')==0&&ftell(file)==count,'colormeasure:Chart:Resource','Bundled chart data %s changed while reading.',path);
hash=java.security.MessageDigest.getInstance('SHA-256');
digest=lower(reshape(dec2hex(typecast(hash.digest(typecast(bytes,'int8')),'uint8'),2).',1,[]));
% Only the computed digest is normalized. The pinned lowercase digest must
% match exactly; strcmpi would silently accept a changed manifest spelling.
assert(strcmp(digest,expectedDigest),'colormeasure:Chart:Resource', ...
    'Bundled chart data %s is damaged or unsupported. Reinstall the complete application.',path); %#ok<STCI>
try
    text=native2unicode(bytes,'UTF-8');
    assert(isequal(reshape(unicode2native(text,'UTF-8'),1,[]),bytes), ...
        'colormeasure:Chart:Resource','Bundled chart data %s is not valid UTF-8.',path);
    value=jsondecode(text);
catch cause
    problem=MException('colormeasure:Chart:Resource','Bundled chart data %s is not valid UTF-8 JSON.',path);
    throw(addCause(problem,cause));
end
end

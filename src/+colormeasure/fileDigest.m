function digest=fileDigest(file)
%FILEDIGEST SHA-256 of an exact, bounded-stream file read; refuses read errors.
[stream,message]=fopen(file,'rb');
assert(stream>=0,'Measurement:FileDigest','Cannot read %s: %s.',file,message);
cleanup=onCleanup(@()fclose(stream));
assert(fseek(stream,0,'eof')==0,'Measurement:FileDigest','Cannot seek %s.',file);
fileBytes=ftell(stream);
assert(fileBytes>=0&&fseek(stream,0,'bof')==0,'Measurement:FileDigest','Cannot determine length of %s.',file);
hash=java.security.MessageDigest.getInstance('SHA-256');remaining=fileBytes;
while remaining>0
    requested=min(remaining,65536);[bytes,count]=fread(stream,requested,'*uint8');
    [message,status]=ferror(stream);
    assert(status==0&&count==requested,'Measurement:FileDigest','Incomplete read of %s: %s.',file,message);
    hash.update(typecast(bytes,'int8'));remaining=remaining-count;
end
assert(fseek(stream,0,'eof')==0&&ftell(stream)==fileBytes, ...
    'Measurement:FileDigest','File length changed while reading %s.',file);
digest=lower(reshape(dec2hex(typecast(hash.digest(),'uint8'),2).',1,[]));
end

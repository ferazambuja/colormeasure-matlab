function value = sha256(bytes)
%SHA256 Lowercase hexadecimal digest of unchanged bytes.
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(bytes(:)),'int8'));
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

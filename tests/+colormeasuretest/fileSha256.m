function value = fileSha256(filename)
%FILESHA256 Hash the file's bytes without normalizing text or line endings.
value=colormeasuretest.sha256(colormeasuretest.readBytes(filename));
end

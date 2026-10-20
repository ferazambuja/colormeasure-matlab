function bytes = readBytes(filename)
%READBYTES Read unchanged file bytes for publication and identity assertions.
file=fopen(filename,'rb');
assert(file>=0,'measurement:TestRead','Cannot read %s.',filename);
cleanup=onCleanup(@()fclose(file));
bytes=fread(file,Inf,'*uint8');
end

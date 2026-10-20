function writeText(filename, value)
%WRITETEXT Write a UTF-8 test report or fixture with owned descriptor cleanup.
file=fopen(filename,'w','n','UTF-8');
if file<0,error('measurement:TestReportWrite','Cannot write %s',filename);end
cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s',value);
end

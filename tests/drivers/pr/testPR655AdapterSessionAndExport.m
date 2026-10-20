function tests = testPR655AdapterSessionAndExport
% The PR adapter, its session MAT and CSV, the export protections and the
% batch plot, using the real parser with simulated replies. The launcher
% (measurePR655) is exercised in testLauncherWorkspaceNames.
tests = functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
sentinel=figure('Visible','off','Name','PR-655 measurement batch');
t.TestData.unrelatedPlot=sentinel;
t.addTeardown(@() colormeasuretest.dispose(sentinel));
end


function teardownOnce(t)
verifyTrue(t,isgraphics(t.TestData.unrelatedPlot),'Test cleanup deleted an unrelated plot.');
end
function setup(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); t.TestData.folder=f.Folder;
v=get(groot,'DefaultFigureVisible'); set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',v));
end
function testAdapterRetainsCompleteSpectraAndMetadata(t)
s=createSession(t,true); s.measure('Tile 001','Position 1');
r=s.measurements;
verifyEqual(t,r.lambda,(380:4:780)'); verifyEqual(t,r.radiance,ones(101,1));
verifySize(t,r.XYZ,[1 3]); verifyEqual(t,r.name,'Tile 001');
verifyEqual(t,r.notes,'Position 1'); verifyEqual(t,r.deviceType,'PR-655');
verifyFalse(t,r.isSynthetic);
verifyNotEmpty(t,r.xyzMethod); verifyNotEmpty(t,r.spectralUnits);
verifyEqual(t,r.instrumentMetadata.serialNumber,'655 SESSION-1');
verifyEqual(t,r.instrumentMetadata.softwareVersion,'2.22D');
verifyEqual(t,r.instrumentMetadata.lastMeasurementExposure.exposureMilliseconds,25);
loaded=load(s.files.mat); verifyEqual(t,loaded.measurements,s.measurements);
verifyEqual(t,loaded.measurements.instrumentMetadata,r.instrumentMetadata);
% The actual parser/session has instrument metadata, not demo-only fields.
% Keep the stored-field freeze executable on this producer as well.
verifyEqual(t,fieldnames(loaded.measurements),{'radiance';'lambda';'XYZ';'xyzMethod'; ...
    'totalRadiance';'deviceType';'unitsCode';'peakWavelength';'instrumentTotalRadiance'; ...
    'integratedPhotonRadiance';'isSynthetic';'instrumentMetadata';'spectralUnits';'name';'notes';'port'; ...
    'startedAtUTC';'completedAtUTC';'startedAtLocal';'localTimeZone';'completedAtLocal'; ...
    'durationSeconds';'matlabVersion';'instrumentSettings'});
state=colormeasuretest.pr.state(); verifyTrue(t,state.closed);
verifyEqual(t,state.commands{end},'Q');
verifyEmpty(t,s.files.csv);
end
function testCurrentSpectrumFieldRejectsMissingOrInvalidValues(t)
invalid={struct('spectralData',[1;2]),struct('radiance',[]), ...
    struct('radiance',NaN),struct('radiance',Inf),struct('radiance',1+1i), ...
    struct('radiance','1'),struct('radiance',true),struct('radiance',ones(2))};
for k=1:numel(invalid)
    verifyError(t,@()colormeasure.drivers.pr.spectrumOf(invalid{k}),'PR655:SpectrumField');
end
verifyEqual(t,colormeasure.drivers.pr.spectrumOf(struct('radiance',[1;2])),[1;2]);
end

function testDefaultSessionSavesUnavailableMetadataWithoutExtraQueries(t)
s=createSession(t); s.measure('Sample 001','Default acquisition');
r=s.measurements;
verifyEmpty(t,r.instrumentMetadata.serialNumber);
verifyEqual(t,r.instrumentMetadata.queries.serialNumber.status,'notQueried');
loaded=load(s.files.mat); verifyEqual(t,loaded.measurements,s.measurements);
state=colormeasuretest.pr.state();
verifyEqual(t,state.commands,{'Q','PHOTO','D111','B00','M5','B100','Q'});
end
function testFinalCsvContainsEachSpectrumAndQuotedNotes(t)
s=createSession(t);
s.measure('Sample, 001',sprintf('First line\nSecond line'));
s.measure('Sample 002','');
s.finish(); csv=readtable(s.files.csv);
verifyEqual(t,height(csv),202);
verifyEqual(t,csv.MeasurementIndex,[ones(101,1);2*ones(101,1)]);
verifyEqual(t,csv.Wavelength_nm,repmat((380:4:780)',2,1));
verifyEqual(t,string(csv.MeasurementName(1:101)),repmat("Sample, 001",101,1));
verifyEqual(t,string(csv.Notes(1:101)),repmat(string(sprintf('First line\nSecond line')),101,1));
verifyEqual(t,csv.SpectralReading,ones(202,1));
end
function testCsvRetainsExplicitSyntheticProvenanceWithOtherwiseIdenticalRows(t)
s=createSession(t);s.measure('Same sample','');
native=s.measurements;synthetic=native;synthetic.isSynthetic=true;
nativeTable=colormeasure.drivers.pr.batchTable(native,s.info);
syntheticTable=colormeasure.drivers.pr.batchTable(synthetic,s.info);
verifyClass(t,nativeTable.IsSynthetic,'logical');
verifyFalse(t,any(nativeTable.IsSynthetic));verifyTrue(t,all(syntheticTable.IsSynthetic));
verifyEqual(t,removevars(nativeTable,'IsSynthetic'),removevars(syntheticTable,'IsSynthetic'));
verifyEqual(t,nativeTable.DeviceType,syntheticTable.DeviceType);
nativeFile=fullfile(t.TestData.folder,'native.csv');
syntheticFile=fullfile(t.TestData.folder,'synthetic.csv');
colormeasure.session.exportCsv(native,s.info,nativeFile,@colormeasure.drivers.pr.batchTable);
colormeasure.session.exportCsv(synthetic,s.info,syntheticFile,@colormeasure.drivers.pr.batchTable);
nativeLines=regexp(fileread(nativeFile),'\r\n|\n|\r','split');
syntheticLines=regexp(fileread(syntheticFile),'\r\n|\n|\r','split');
nativeLines=nativeLines(~cellfun(@isempty,nativeLines));
syntheticLines=syntheticLines(~cellfun(@isempty,syntheticLines));
verifyEqual(t,nativeLines(1),syntheticLines(1));verifyTrue(t,endsWith(nativeLines{1},',IsSynthetic'));
verifyTrue(t,all(endsWith(nativeLines(2:end),',0')));
verifyTrue(t,all(endsWith(syntheticLines(2:end),',1')));
withoutFlag=@(line)line(1:end-1);
verifyEqual(t,cellfun(withoutFlag,nativeLines(2:end),'UniformOutput',false), ...
    cellfun(withoutFlag,syntheticLines(2:end),'UniformOutput',false));
end

function testCsvRefusesUnknownOrMalformedSyntheticProvenanceWithoutReplacingFiles(t)
s=createSession(t);s.measure();
filename=colormeasure.drivers.pr.exportPR655Csv(s.files.mat);
beforeCsv=colormeasuretest.readBytes(filename);beforeMat=colormeasuretest.readBytes(s.files.mat);
invalid={rmfield(s.measurements,'isSynthetic')};
for value={[],[true false],1,NaN,'true',struct('unknown',true)}
    reading=s.measurements;reading.isSynthetic=value{1};invalid{end+1}=reading; %#ok<AGROW>
end
for index=1:numel(invalid)
    reading=invalid{index};
    verifyError(t,@()colormeasure.drivers.pr.batchTable(reading,s.info),'PR655:ExportProvenance');
    verifyError(t,@()colormeasure.session.exportCsv(reading,s.info,filename, ...
        @colormeasure.drivers.pr.batchTable),'Measurement:CsvSaveFailed');
    verifyEqual(t,colormeasuretest.readBytes(filename),beforeCsv);
    verifyEqual(t,colormeasuretest.readBytes(s.files.mat),beforeMat);
end
verifyEmpty(t,dir(fullfile(s.files.folder,'*.part.*')));
end

function testCsvCanBeRegeneratedWithoutAnInstrument(t)
s=createSession(t); s.measure();
filename=colormeasure.drivers.pr.exportPR655Csv(s.files.mat);
verifyTrue(t,isfile(filename));
verifyEqual(t,height(readtable(filename)),101);
other=fullfile(t.TestData.folder,'custom.csv');
verifyEqual(t,colormeasure.drivers.pr.exportPR655Csv(s.files.mat,other),other);
end

function testCsvExportRequiresTheCurrentBatchVariables(t)
s=createSession(t);s.measure();
filename=fullfile(t.TestData.folder,'incomplete.mat');
measurements=s.measurements;save(filename,'measurements');
destination=fullfile(t.TestData.folder,'preserved.csv');
fid=fopen(destination,'w');fwrite(fid,'Existing export');fclose(fid);
before=colormeasuretest.readBytes(destination);
verifyError(t,@()colormeasure.drivers.pr.exportPR655Csv(filename,destination),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(destination),before);
batchInfo=s.info;save(filename,'batchInfo');
verifyError(t,@()colormeasure.drivers.pr.exportPR655Csv(filename,destination),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(destination),before);
end

function testCsvExportRejectsOtherFileTypesWithoutReplacingThem(t)
s=createSession(t); s.measure();
for extension={'.mat','.m'}
    filename=fullfile(t.TestData.folder,['preserve' extension{1}]);
    fid=fopen(filename,'w'); fwrite(fid,'Existing file must survive.'); fclose(fid);
    before=colormeasuretest.readBytes(filename);
    verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv(s.files.mat,filename),'Measurement:CsvSaveFailed');
    verifyEqual(t,colormeasuretest.readBytes(filename),before);
    verifyError(t,@() colormeasure.session.exportCsv(s.measurements,s.info,filename,@colormeasure.drivers.pr.batchTable), ...
        'Measurement:CsvSaveFailed');
    verifyEqual(t,colormeasuretest.readBytes(filename),before);
end
end

function testCsvExportCannotReplaceItsSourceThroughEquivalentPaths(t)
s=createSession(t); s.measure(); original=colormeasuretest.readBytes(s.files.mat);
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv(s.files.mat,s.files.mat),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(s.files.mat),original);
% A MAT file may have a CSV suffix, so checking the extension alone is unsafe.
source=fullfile(t.TestData.folder,'source.csv'); copyfile(s.files.mat,source);
before=colormeasuretest.readBytes(source);
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv(source,source),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(source),before);
subfolder=fullfile(t.TestData.folder,'child'); mkdir(subfolder);
equivalent=fullfile(subfolder,'..','source.csv');
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv(source,equivalent),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(source),before);
separate=fullfile(t.TestData.folder,'separate.csv');
colormeasure.drivers.pr.exportPR655Csv(source,separate); verifyEqual(t,height(readtable(separate)),101);
verifyEqual(t,colormeasuretest.readBytes(source),before);
end

function testCsvExportDetectsSourceHardLink(t)
s=createSession(t); s.measure();
source=s.files.mat;
linked=fullfile(t.TestData.folder,'linked.csv');
sourceFile=java.io.File(source); linkedFile=java.io.File(linked);
try
    java.nio.file.Files.createLink(linkedFile.toPath(),sourceFile.toPath());
catch err
    assumeTrue(t,false,['This filesystem cannot create a test hard link: ' err.message]);
end
before=colormeasuretest.readBytes(source);
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv(source,linked),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(source),before); verifyEqual(t,colormeasuretest.readBytes(linked),before);
end

function testCsvExportProtectsSourcesResolvedOnMatlabPath(t)
s=createSession(t); s.measure();
working=fullfile(t.TestData.folder,'working'); mkdir(working);
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(working));
t.applyFixture(matlab.unittest.fixtures.PathFixture(t.TestData.folder));
source=fullfile(t.TestData.folder,'path_named_source.csv'); copyfile(s.files.mat,source);
verifyFalse(t,isfile('path_named_source.csv'));
before=colormeasuretest.readBytes(source);
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv('path_named_source.csv',source),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(source),before);
end

function testCsvExportResolvesOmittedMatExtensionBeforeProtectingSource(t)
s=createSession(t); s.measure();
working=fullfile(t.TestData.folder,'working'); mkdir(working);
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(working));
t.applyFixture(matlab.unittest.fixtures.PathFixture(t.TestData.folder));
source=fullfile(t.TestData.folder,'path_extension_source.mat'); copyfile(s.files.mat,source);
before=colormeasuretest.readBytes(source);
verifyError(t,@() colormeasure.drivers.pr.exportPR655Csv('path_extension_source',source),'PR655:ExportSource');
verifyEqual(t,colormeasuretest.readBytes(source),before);
% Default export belongs beside the resolved MAT, not in the current folder.
filename=colormeasure.drivers.pr.exportPR655Csv('path_extension_source');
verifyEqual(t,filename,fullfile(t.TestData.folder,'measurements.csv'));
verifyEqual(t,height(readtable(filename)),101);
end

function testValidCsvReplacementStillExportsLatestSnapshot(t)
s=createSession(t); s.measure('First','');
filename=fullfile(t.TestData.folder,'replace.CSV'); colormeasure.drivers.pr.exportPR655Csv(s.files.mat,filename);
verifyEqual(t,height(readtable(filename)),101);
s.measure('Second',''); colormeasure.drivers.pr.exportPR655Csv(s.files.mat,filename);
data=readtable(filename);
verifyEqual(t,height(data),202);
verifyEqual(t,string(data.MeasurementName(102)),"Second");
end

function testCsvPreservesTheCapturedLocalContext(t)
s=createSession(t); s.measure();
data=colormeasure.drivers.pr.batchTable(s.measurements,s.info);
verifyEqual(t, string(data.StartedAtUTC(1)), string(s.measurements.startedAtUTC));
verifyEqual(t, string(data.StartedAtLocal(1)), string(s.measurements.startedAtLocal));
verifyEqual(t, string(data.CompletedAtLocal(1)), string(s.measurements.completedAtLocal));
verifyEqual(t, string(data.LocalTimeZone(1)), string(s.measurements.localTimeZone));
verifyEqual(t, string(data.BatchCompletedAtLocal(1)), string(s.info.completedAtLocal));
verifyEqual(t, string(data.BatchLocalTimeZone(1)), string(s.info.localTimeZone));
verifyEqual(t, data.SpectralReading, s.measurements.radiance);
end

function testZeroReadingBatchExportsTheColumnHeader(t)
s=createSession(t); s.measure();
columns=colormeasure.drivers.pr.batchTable(s.measurements,s.info);
columns=columns.Properties.VariableNames;
measurements=s.measurements([]); batchInfo=s.info;
data=colormeasure.drivers.pr.batchTable(measurements,batchInfo);
verifyEqual(t,height(data),0);
verifyClass(t,data.IsSynthetic,'logical');
verifyEqual(t,data.Properties.VariableNames,columns);
source=fullfile(t.TestData.folder,'empty.mat'); save(source,'measurements','batchInfo');
filename=colormeasure.drivers.pr.exportPR655Csv(source,fullfile(t.TestData.folder,'empty.csv'));
verifyEqual(t,strtrim(fileread(filename)),strjoin(columns,','));
end
function testFailedExportPreservesExistingCsv(t)
s=createSession(t); s.measure(); filename=colormeasure.drivers.pr.exportPR655Csv(s.files.mat);
before=colormeasuretest.readBytes(filename);
bad=s.measurements; bad.notes=struct('notText',true);
verifyError(t,@() colormeasure.session.exportCsv(bad,s.info,filename,@colormeasure.drivers.pr.batchTable),'Measurement:CsvSaveFailed');
verifyEqual(t,colormeasuretest.readBytes(filename),before);
verifyEmpty(t,dir(fullfile(s.files.folder,'*.part.*')));
end
function testMatDirectoryIsNotOverwritten(t)
s=createSession(t); s.measure();
folder=fullfile(t.TestData.folder,'blocked'); mkdir(folder); mkdir(fullfile(folder,'measurements.mat'));
verifyError(t,@() colormeasure.session.saveMat(s.measurements,folder,s.info),'Measurement:MatSaveFailed');
verifyTrue(t,isfolder(fullfile(folder,'measurements.mat')));
verifyEmpty(t,dir(fullfile(folder,'*.part.*')));
end
function testPlotColorsAreStableAndLabelsIndexed(t)
s=createSession(t); s.measure('A','');
fig=colormeasure.drivers.pr.plotBatch(s.measurements); t.addTeardown(@() colormeasuretest.dispose(fig));
first=findobj(fig,'Type','line','DisplayName','1: A'); color=first.Color;
s.measure('B','');
fig=colormeasure.drivers.pr.plotBatch(s.measurements,fig);
first=findobj(fig,'Type','line','DisplayName','1: A'); second=findobj(fig,'Type','line','DisplayName','2: B');
verifyEqual(t,first.Color,color); verifyNotEqual(t,second.Color,color);
verifyEqual(t,first.YData(:),s.measurements(1).radiance);
end
function testPlotRecreatedAfterUserClosesIt(t)
s=createSession(t); s.measure();
fig=colormeasure.drivers.pr.plotBatch(s.measurements); delete(fig);
s.measure(); fig=colormeasure.drivers.pr.plotBatch(s.measurements,fig); t.addTeardown(@() colormeasuretest.dispose(fig));
verifyTrue(t,isgraphics(fig,'figure'));
verifyNumElements(t,findobj(fig,'Type','line'),2);
end
function s=createSession(t,metadata)
if nargin<2, metadata=false; end
a=colormeasure.drivers.pr.adapter(); a.listPorts=@(~) "/dev/cu.usbmodem_VIRTUAL";
a.connect=@(port) connect(port,metadata);
s=colormeasure.session.Session(a,t.TestData.folder); t.addTeardown(@() delete(s));
end
function instrument=connect(port,metadata)
colormeasuretest.pr.configure('Ports',string(port));
instrument=colormeasuretest.pr.Driver(port,'Timeout',2,'Metadata',metadata,'Clock',colormeasuretest.FakeClock());
end

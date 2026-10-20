function tests=testChartResources
% Source-identical private loader in an isolated resource folder. Only the
% fixture root and expected manifest digest change; production resources stay
% untouched. This exercises refusal before resource values are interpreted.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
mkdir(fullfile(folder,'private'));
copyfile(fullfile(colormeasure.root(),'src','+colormeasure','+chart','private','authenticatedJson.m'),fullfile(folder,'private'));
write(fullfile(folder,'readChartResourceFixture.m'),uint8(sprintf( ...
    'function value=readChartResourceFixture(varargin)\nvalue=authenticatedJson(varargin{:});\nend\n')));
t.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
clear readChartResourceFixture readChartReferenceFixture
t.addTeardown(@clearReaders);t.TestData.folder=folder;
end
function testExactDigestAndSizeAreRequiredBeforeDecode(t)
path=fullfile(t.TestData.folder,'bounded.json');bytes=uint8('{"value":17}');write(path,bytes);
expected=colormeasure.fileDigest(path);
verifyEqual(t,readChartResourceFixture(path,expected,numel(bytes)),struct('value',17));
verifyError(t,@()readChartResourceFixture(path,repmat('0',1,64),numel(bytes)),'colormeasure:Chart:Resource');
verifyError(t,@()readChartResourceFixture(path,upper(expected),numel(bytes)),'colormeasure:Chart:Resource');
verifyError(t,@()readChartResourceFixture(path,expected,numel(bytes)-1),'colormeasure:Chart:Resource');
write(path,[bytes uint8(' ')]);
verifyError(t,@()readChartResourceFixture(path,expected,numel(bytes)+1),'colormeasure:Chart:Resource');
end
function testMalformedUtf8AndJsonNameTheFailedResource(t)
path=fullfile(t.TestData.folder,'unicode-reference.json');
for bytes={uint8([123 34 120 34 58 34 192 175 34 125]),uint8('{broken json')}
    write(path,bytes{1});expected=colormeasure.fileDigest(path);
    try
        readChartResourceFixture(path,expected,1024);verifyFail(t,'Malformed resource was accepted.');
    catch problem
        verifyEqual(t,problem.identifier,'colormeasure:Chart:Resource');
        verifySubstring(t,problem.message,'unicode-reference.json');
    end
end
write(path,unicode2native('{"name":"é φ"}','UTF-8'));
value=readChartResourceFixture(path,colormeasure.fileDigest(path),1024);
verifyEqual(t,value.name,'é φ');
end
function testMissingAndEmptyResourceDiagnosticsNameTheFile(t)
path=fullfile(t.TestData.folder,'missing-reference.json');
for create=[false true]
    if create,write(path,uint8([]));end
    try
        readChartResourceFixture(path,repmat('0',1,64),1024);verifyFail(t,'Absent or empty resource was accepted.');
    catch problem
        verifyEqual(t,problem.identifier,'colormeasure:Chart:Resource');
        verifySubstring(t,problem.message,'missing-reference.json');
    end
end
end
function testManifestMembershipMustBeUniqueEvenWhenAuthenticated(t)
definition=colormeasure.chart.definition('classic');
manifestPath=fullfile(colormeasure.root(),'resources','provenance','chart-reference-source.json');
manifest=jsondecode(fileread(manifestPath));
entry=manifest.files(strcmp({manifest.files.path},'resources/charts/classic-reference.json'));
for entries={repmat(entry,1,2),manifest.files(~strcmp({manifest.files.path},'resources/charts/classic-reference.json'))}
    manifest.files=entries{1};prepareReferenceReader(t,manifest);
    try
        readChartReferenceFixture(definition);verifyFail(t,'Ambiguous or missing membership was accepted.');
    catch problem
        verifyEqual(t,problem.identifier,'colormeasure:Chart:Resource');
        verifySubstring(t,problem.message,'Reference resource must be uniquely identified');
    end
end
end
function prepareReferenceReader(t,manifest)
folder=t.TestData.folder;
if ~isfolder(fullfile(folder,'resources','provenance')),mkdir(fullfile(folder,'resources','provenance'));end
if ~isfolder(fullfile(folder,'resources','charts')),mkdir(fullfile(folder,'resources','charts'));end
copyfile(fullfile(colormeasure.root(),'resources','charts','classic-reference.json'), ...
    fullfile(folder,'resources','charts','classic-reference.json'));
path=fullfile(folder,'resources','provenance','chart-reference-source.json');
write(path,unicode2native(jsonencode(manifest),'UTF-8'));
source=fileread(fullfile(colormeasure.root(),'src','+colormeasure','+chart','referenceData.m'));
source=strrep(source,'function value=referenceData(definition)','function value=readChartReferenceFixture(definition)');
source=strrep(source,'root=colormeasure.root();',['root=''' strrep(folder,'''','''''') ''';']);
source=regexprep(source,"manifestDigest = '[^']+';", ...
    ['manifestDigest = ''' colormeasure.fileDigest(path) ''';']);
write(fullfile(folder,'readChartReferenceFixture.m'),unicode2native(source,'UTF-8'));
clear readChartReferenceFixture
end
function write(path,bytes)
file=fopen(path,'wb');assert(file>=0);cleanup=onCleanup(@()fclose(file));
assert(fwrite(file,bytes,'uint8')==numel(bytes));
end
function clearReaders()
clear readChartResourceFixture readChartReferenceFixture
end

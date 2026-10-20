function tests=testChartColors
% Frozen local references and native chart quantity limits, without hardware.
tests=functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end
function setup(t)
t.TestData.folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
end
function testClassicRetainsSourceMappingsOriginalValuesAndNeutralLevels(t)
d=colormeasure.chart.definition('classic');r=colormeasure.chart.referenceData(d);
run=colormeasure.chart.Run(d,'fixture-segment',struct());
out=colormeasure.chart.colors(d,run.pass(),struct([]),r,run.Snapshot);
references=[out.reference];verifyTrue(t,all([references.available]));
verifyEqual(t,{r.cells.sourceLocation},{d.cells.sourceLocation});
verifyEqual(t,r.context.whiteXYZ,[96.4202880859375 100 82.49053955078125]);
verifySubstring(t,out(1).reference.reason,'specimen conditions unverified');
verifyEqual(t,r.cells(1).originalValues,[37.99 13.56 14.06]);
% Independent ICC-equation calculation, retained in docs/colorimetry/chart-colors.md.
verifyEqual(t,out(1).reference.rgb,[.4529991296455253 .317361616963215 .2641908975653957],'AbsTol',1e-12);
verifyEqual(t,colormeasure.colorimetry.XYZ2Lab(vertcat(r.cells.XYZ),r.context.whiteXYZ), ...
    vertcat(r.cells.originalValues),'AbsTol',1e-10);
neutrals=vertcat(out(19:24).reference);rgb=vertcat(neutrals.rgb);
verifyTrue(t,all(diff(rgb,1,1)<0,'all'));
verifyLessThan(t,max(rgb,[],2)-min(rgb,[],2),repmat(.017,6,1));
% Compare independently computed bytes, not the manifest field copied by the loader.
verifyEqual(t,r.resourceDigest,colormeasure.fileDigest(fullfile(colormeasure.root(),'resources','charts','classic-reference.json')));
end
function testSgKeepsAllRawValuesButNeverGuessesAReferenceBasis(t)
d=colormeasure.chart.definition('sg');r=colormeasure.chart.referenceData(d);
run=colormeasure.chart.Run(d,'fixture-segment',struct());out=colormeasure.chart.colors(d,run.pass(),struct([]),r,run.Snapshot);
references=[out.reference];verifyFalse(t,any([references.available]));
verifyTrue(t,all(isnan(vertcat(references.rgb)),'all'));verifyFalse(t,any([references.clipped]));
verifyEmpty(t,fieldnames(r.context));verifyEqual(t,{r.cells.sourceLocation},{d.cells.sourceLocation});
verifyEqual(t,vertcat(r.cells.XYZ),vertcat(r.cells.originalValues));
verifyTrue(t,all(contains({r.cells.reason},'no established illuminant')));
index=find(strcmp({d.cells.sourceLocation},'C07'));
verifyEqual(t,r.cells(index).XYZ,[26.445 26.691 42.354]);
verifyEqual(t,d.cells(index).sourceId,26);verifyEqual(t,d.cells(index).exportId,27);
verifyEqual(t,r.provenance.sourceSHA256,'687a880a00ea0f732ddcd0c249ed9198d8fe015168acc3c13915b085b54a4f21');
verifyEqual(t,colormeasure.fileDigest(fullfile(colormeasure.root(),r.provenance.originalFile)),r.provenance.sourceSHA256);
% SG obeys the same per-cell identity/availability validation as every chart.
r.cells(1).sourceLocation='other';
verifyError(t,@()colormeasure.chart.colors(d,run.pass(),struct([]),r,run.Snapshot),'colormeasure:Chart:Colors');
r.cells(1).sourceLocation=d.cells(1).sourceLocation;r.cells(1).available=1;
verifyError(t,@()colormeasure.chart.colors(d,run.pass(),struct([]),r,run.Snapshot),'colormeasure:Chart:Colors');
end
function testFrozenReferencesAreSavedSeparatelyBeforeReading(t)
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),t.TestData.folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));s.startChart(colormeasure.chart.definition('classic'));
saved=load(s.files.mat);verifyEmpty(t,saved.measurements);
verifyEqual(t,saved.batchInfo.chart.referenceData,s.chart.referenceData);
verifyNumElements(t,saved.batchInfo.chart.referenceData.cells,24);
end
function testNativeRadianceKeepsCoverageWithoutInventingReflectance(t)
a=colormeasure.drivers.pr.uiAdapter();a.key='PR655Demo';
a.catalog=struct('model','PR655','mode','interactive');
meter=colormeasure.drivers.pr.DemoInstrument(1,0);
a.connect=@(~)meter;a.release=@(~)[];a.listPorts=@(~)"DEMO";
a.prepareSample=@(intent)meter.prepareSample(intent);t.addTeardown(@()delete(meter));
s=colormeasure.session.Session(a,t.TestData.folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));s.startChart(colormeasure.chart.definition('classic'));s.measure();
state=s.chart;out=colormeasure.chart.colors(state.definition,state.passes(1),s.measurements,state.referenceData,state);
verifyEqual(t,state.coverage,1);verifyFalse(t,out(1).measured.available);
verifySubstring(t,out(1).measured.reason,'radiance/luminance');verifyTrue(t,out(1).reference.available);
end

function testExactCurrentChartOwnerAndVersionAreRequired(t)
d=colormeasure.chart.definition('classic');run=colormeasure.chart.Run(d,'fixture-segment',struct());
t.addTeardown(@()delete(run));state=run.Snapshot;pass=run.pass();
verifyError(t,@()colormeasure.chart.colors(d,pass,struct([]),state.referenceData), ...
    'colormeasure:Chart:Colors');
for version=[2 3]
    old=state;old.version=version;
    verifyError(t,@()colormeasure.chart.colors(d,pass,struct([]),state.referenceData,old), ...
        'colormeasure:Chart:Colors');
end
other=colormeasure.chart.Run(d,'other-segment',struct());t.addTeardown(@()delete(other));
verifyError(t,@()colormeasure.chart.colors(d,pass,struct([]),state.referenceData,other.Snapshot), ...
    'colormeasure:Chart:Colors');
end
function testReferenceAssociationAndWhiteNeverBecomeGuessedColors(t)
d=colormeasure.chart.definition('classic');run=colormeasure.chart.Run(d,'fixture-segment',struct());
t.addTeardown(@()delete(run));state=run.Snapshot;r=state.referenceData;
changed=r;changed.definitionId='other-chart';
verifyError(t,@()colormeasure.chart.colors(d,run.pass(),struct([]),changed,state),'colormeasure:Chart:Colors');
changed=r;changed.cells(1).sourceLocation='other-location';
verifyError(t,@()colormeasure.chart.colors(d,run.pass(),struct([]),changed,state),'colormeasure:Chart:Colors');
for white={[],[.9642 1 .8249]}
    changed=r;changed.context.whiteXYZ=white{1};
    out=colormeasure.chart.colors(d,run.pass(),struct([]),changed,state);
    verifyFalse(t,out(1).reference.available);verifyTrue(t,all(isnan(out(1).reference.rgb)));
    verifyNotEmpty(t,out(1).reference.reason);
end
end
function testCustomPaletteAndInvalidSelectedAttemptAreRefused(t)
d=colormeasure.chart.definition('custom','Two by three',2,3);
run=colormeasure.chart.Run(d,'fixture-segment',struct());t.addTeardown(@()delete(run));
out=colormeasure.chart.colors(d,run.pass(),struct([]),run.Snapshot.referenceData,run.Snapshot);
references=[out.reference];verifyFalse(t,any([references.available]));
r=colormeasure.chart.referenceData(colormeasure.chart.definition('classic'));
verifyError(t,@()colormeasure.chart.colors(d,run.pass(),struct([]),r,run.Snapshot),'colormeasure:Chart:Colors');
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),t.TestData.folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));s.startChart(d);s.measure();
state=s.chart;pass=state.passes(1);pass.selectedAttempt(1)=999;state.passes(1)=pass;
verifyError(t,@()colormeasure.chart.colors(d,pass,s.measurements,state.referenceData,state),'colormeasure:Chart:Colors');
end
function testSourceFormatReferenceVersionAndSelectedOutcomeAreGuarded(t)
% The classic preset carries a complete frozen reference set.
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250','interactive'),t.TestData.folder);
t.addTeardown(@()colormeasuretest.disposeSession(s));s.startChart(colormeasure.chart.definition('classic'));s.measure();
state=s.chart;pass=state.passes(1);d=state.definition;
verifyNotEmpty(t,state.referenceData);verifyEqual(t,pass.selectedAttempt(1),1);
foreign=s.measurements;foreign.operationId='foreign-operation';
verifyError(t,@()colormeasure.chart.colors(d,pass,foreign,state.referenceData,state),'Measurement:DirectSource');
owned=state;owned.passes(1).context.operationContext=struct('mode','foreign');
verifyError(t,@()colormeasure.chart.colors(d,owned.passes(1),s.measurements,state.referenceData,owned), ...
    'Measurement:DirectSource');
for field={'format','version'}
    r=state.referenceData;
    if strcmp(field{1},'format'),r.format='other-illustrations';else,r.version=2;end
    verifyError(t,@()colormeasure.chart.colors(d,pass,s.measurements,r,state),'colormeasure:Chart:Colors',field{1});
end
for defect={'status','cell'}
    changed=state;
    if strcmp(defect{1},'status'),changed.passes(1).attempts(1).status='failed';
    else,changed.passes(1).attempts(1).cellIndex=2;end
    verifyError(t,@()colormeasure.chart.colors(d,changed.passes(1),s.measurements,state.referenceData,changed), ...
        'colormeasure:Chart:Colors',defect{1});
end
end

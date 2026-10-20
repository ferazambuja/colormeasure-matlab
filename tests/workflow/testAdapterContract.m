function tests = testAdapterContract
% Adapter, reading and view-data contracts are enforced at the session boundary,
% and every bundled instrument adapter satisfies them without instrument I/O.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function setup(t)
% Keep each test independent of previously registered native sessions
% when checking device-catalog contracts.
colormeasuretest.isolateRegistry(t);
end

function testDirectAdapterRequiresEveryAcquisitionHook(t)
for name = {'key','label','listPorts','connect','read','release','toTable'}
    a = rmfield(directAdapter(), name{1});
    verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
end
a = directAdapter(); a.read = 'not a hook';
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.key = '';
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
verifyError(t, @() colormeasure.session.validateAdapter({}), 'Measurement:AdapterContract');
end

function testSessionConstructorRejectsIncompleteAdapterBeforeAnyAction(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
a = rmfield(directAdapter(), 'toTable');
verifyError(t, @() colormeasure.session.Session(a, folder), 'Measurement:AdapterContract');
s = colormeasure.session.Session(directAdapter(), folder);
t.addTeardown(@() delete(s));
verifyTrue(t, s.measure('Sample 001', ''));
end

function testOperationAdapterRejectsDirectHooksAndNonPlainContext(t)
context = struct('device', struct('model', 'Fixture'), 'mode', 'spot');
a = struct('key', 'operation', 'operationContext', context, 'read', @(~) struct());
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = struct('key', 'operation', 'operationContext', struct('handle', @(~) []));
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = struct('key', 'operation', 'operationContext', context);
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
end

function testOptionalHooksAreTypeChecked(t)
a = directAdapter(); a.viewData = 'text';
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.nextBatchAdapter = struct();
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.settings = struct('catalog', struct([]), 'read', @(~) struct());
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.settings = struct('catalog', struct('id', 'x'), 'read', @(~) [], 'apply', @(~, ~) []);
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
% A static catalog meets the readback rules at construction, not at a later
% window action: id, label and type alone cannot be rendered.
a = directAdapter(); a.settings = struct('catalog', struct('id', 'x', 'label', 'X', 'type', 'number'), ...
    'read', @(~) [], 'apply', @(~, ~) []);
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'later', @() []);
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.configuration = struct('client', @() []);
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.workspaceName = 42;
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
% Headings may title only the leading paragraphs; omitted headings are valid.
% More headings than paragraphs is a malformed preparation contract.
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'details', {{'One'}}, 'headings', {{'First'; 'Second'}});
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'details', {{'One'}}, 'headings', {{1}});
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'headings', {{'First'}});
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'details', {{'One'; 'Two'}}, 'headings', {{'First'}});
verifyEqual(t, colormeasure.session.validateAdapter(a), a);
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'details', {{'One'; 'Two'}}, 'headings', {{'First'; ''}});
verifyEqual(t, colormeasure.session.validateAdapter(a), a);
a = directAdapter(); a.preparation = struct('title', 'Prepare', 'details', ["One" "Two"], 'headings', ["First" "Second"]);
verifyEqual(t, colormeasure.session.validateAdapter(a), a);
% Operation-adapter fields refuse even when all direct hooks are present.
for field={'operationContext','operationClient','snapshot','viewOptions','projectOperations','eventValidator', ...
        'connectionReadiness','nextBatchAdapter'}
    a=directAdapter();a.(field{1})=struct();
    verifyError(t,@()colormeasure.session.validateAdapter(a),'Measurement:AdapterContract');
end
a = directAdapter();
help = struct('meaning', 'X.', 'whenToUse', 'Always.', 'tradeoff', 'None.', 'normal', 'Default.', 'source', 'Fixture');
a.settings = struct('catalog', colormeasure.session.settingsControl('x', 'X', 'number', ...
    struct('value', {}, 'label', {}), NaN, NaN, true, help), 'read', @(~) [], 'apply', @(~, ~) []);
a.preparation = struct('title', 'Prepare', 'required', false);
a.configuration = struct('baud', 9600);
a.workspaceName = 'fixtureSession';
verifyEqual(t, colormeasure.session.validateAdapter(a), a);
end

function testDemoHookRejectsMalformedCatalogWithoutCallingIt(t)
a=directAdapter();a.prepareSample=@(~)error('Fixture:HookCalled','Validation must not call a hook.');
verifyError(t,@()colormeasure.session.validateAdapter(a),'Measurement:AdapterContract');
for invalid={[],0,'demo',struct(),struct('model','CR250'), ...
        struct('model','CR250','mode',0),struct('model','CR250','mode','measure'), ...
        repmat(struct('model','CR250','mode','interactive'),1,2)}
    a.catalog=invalid{1};
    verifyError(t,@()colormeasure.session.validateAdapter(a),'Measurement:AdapterContract');
end
a.catalog=struct('model','CR250','mode','interactive');
verifyEqual(t,colormeasure.session.validateAdapter(a),a);
end

function testEveryBundledAdapterSatisfiesTheContractWithoutIO(t)
catalog = colormeasure.ui.deviceCatalog();
verifyNotEmpty(t, catalog);
for index = 1:numel(catalog)
    adapter = catalog(index).factory();
    verifyEqual(t, colormeasure.session.validateAdapter(adapter), adapter, catalog(index).model);
    verifyTrue(t, isfield(adapter, 'viewData'), catalog(index).model);
    verifyTrue(t, isfield(adapter, 'settings'), catalog(index).model);
    verifyEqual(t, adapter.catalog, struct('model',catalog(index).model,'mode','measure'));
end
end

function testReadingMustBePlainScalarStructWithConsistentFields(t)
verifyError(t, @() colormeasure.session.validateReading([]), 'Measurement:InvalidReading');
verifyError(t, @() colormeasure.session.validateReading(struct('a', {1, 2})), 'Measurement:InvalidReading');
verifyError(t, @() colormeasure.session.validateReading(struct('client', @() [])), 'Measurement:InvalidReading');
try
    colormeasure.session.validateReading(struct('XYZ', [1 2 3]), struct('XYZ', [0 0 0], 'name', 'A'));
    verifyFail(t, 'Mismatched fields must be rejected.');
catch problem
    verifyEqual(t, problem.identifier, 'Measurement:InvalidReading');
    verifySubstring(t, problem.message, 'Missing: name');
end
reading = struct('XYZ', [1 2 3], 'when', datetime('now', 'TimeZone', 'UTC'), 'notes', {{'a'}});
verifyEqual(t, colormeasure.session.validateReading(reading), reading);
verifyEqual(t, colormeasure.session.validateReading(reading, reading), reading);
end

function testSessionRejectsReadingsThatCannotBeSaved(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
a = directAdapter(); a.read = @(~) struct('XYZ', [1 2 3], 'connection', @() []);
s = colormeasure.session.Session(a, folder);
t.addTeardown(@() delete(s));
verifyFalse(t, s.measure('Sample 001', ''));
verifyEmpty(t, s.measurements);
verifySubstring(t, s.log(end).message, 'Measurement:InvalidReading');
end

function testViewDataShapesAreChecked(t)
verifyError(t, @() colormeasure.session.validateViewData([], 0), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('XYZ', ones(2, 3)), 3), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('XYZ', ones(2, 4)), 2), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('spectra', {{[]}}), 2), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('spectra', {{struct('x', 1)}}), 1), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('hasSpectra', 1), 0), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('observer', 7), 0), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('xyzComparisonKeys', {{'a'}}), 2), 'Measurement:InvalidViewData');
verifyError(t, @() colormeasure.session.validateViewData(struct('reflectanceRatioEligible', [1 0]), 2), 'Measurement:InvalidViewData');
data = struct('XYZ', ones(2, 3), 'spectra', {{struct('x', [1 2], 'y', [3 4]); []}}, 'hasSpectra', true, ...
    'observer', 'CIE 1931 2-degree observer', 'xyzComparisonKeys', {{'k'; ''}}, ...
    'xyzSources', {{[]; 'source'}}, 'reflectanceRatioEligible', [true; false]);
verifyEqual(t, colormeasure.session.validateViewData(data, 2), data);
verifyEqual(t, colormeasure.session.validateViewData(struct('XYZ', zeros(0, 3)), 0), struct('XYZ', zeros(0, 3)));
end

function testRetiredViewFieldsRefuse(t)
for field={'recordKinds','scalarQuantities','scalarUnits','scalarValues','stimulusIds', ...
        'stimulusDescriptions','operationStatuses','displayIds','displayUpdateDelayMs','instrumentReactionMs'}
    data=struct('XYZ',[1 2 3]);data.(field{1})=[];
    verifyError(t,@()colormeasure.session.validateViewData(data,1),'Measurement:InvalidViewData');
end
% Even a usable declared white cannot request a retired renderer interface.
for white={[],[.9642 1 .8249],[0 1 1]}
    data=struct('XYZ',[1 2 3],'previewWhiteXYZ',white{1});
    problem=colormeasuretest.captureError(@()colormeasure.session.validateViewData(data,1));
    assertNotEmpty(t,problem);
    verifyEqual(t,problem.identifier,'Measurement:InvalidViewData');
    verifySubstring(t,problem.message,'Select a Lab white in Compare');
    verifySubstring(t,problem.message,'derive an adapted color in Color');
end
end

function testFourReadingVectorsDriveReflectanceEligibilityAndRejectMatrices(t)
% A 2-by-2 declaration has four entries but is not a per-reading vector.
spectrum=struct('x',[400;500;600],'y',[1;2;1]);
data=struct('XYZ',ones(4,3),'spectra',{repmat({spectrum},4,1)}, ...
    'spectralQuantities',{repmat({'radiance'},4,1)}, ...
    'spectralComparisonKeys',{repmat({'same-grid-and-units'},4,1)}, ...
    'reflectanceRatioEligible',true(4,1));
perReading=setdiff(fieldnames(data),{'XYZ'});
for orientation={'row','column'}
    valid=data;
    for index=1:numel(perReading)
        name=perReading{index};
        if strcmp(orientation{1},'row'),valid.(name)=reshape(data.(name),1,[]);
        else,valid.(name)=reshape(data.(name),[],1);end
    end
    verifyEqual(t,colormeasure.session.validateViewData(valid,4),valid);
    [eligible,reason]=colormeasure.analysis.reflectanceRatioEligibility(valid,2,1);
    verifyTrue(t,eligible,reason);
    verifyEmpty(t,reason);
end
for index=1:numel(perReading)
    invalid=data;name=perReading{index};invalid.(name)=reshape(data.(name),2,2);
    verifyError(t,@()colormeasure.session.validateViewData(invalid,4),'Measurement:InvalidViewData',name);
end
empty=data;empty.XYZ=zeros(0,3);
for index=1:numel(perReading)
    name=perReading{index};empty.(name)=data.(name)([]);
end
verifyEqual(t,colormeasure.session.validateViewData(empty,0),empty);
end

function testSessionRejectsMalformedViewData(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
a = directAdapter(); a.viewData = @(m) struct('XYZ', ones(numel(m) + 1, 3));
s = colormeasure.session.Session(a, folder);
t.addTeardown(@() delete(s));
verifyTrue(t, s.measure('Sample 001', ''));
verifyError(t, @() s.viewData(), 'Measurement:InvalidViewData');
end

function testBundledAdaptersCompleteASyntheticBatchThroughTheSharedContract(t)
% Conformance: construct, acquire, present, compare and export every bundled
% instrument through the same session core using its synthetic demo.
catalog = colormeasure.ui.deviceCatalog();
for index = 1:numel(catalog)
    model = catalog(index).model;
    session = catalog(index).demoFactory('batch');
    t.addTeardown(@() colormeasuretest.disposeBatch(session));
    verifyTrue(t, session.finished, model);
    identity = session.catalogIdentity;
    verifyEqual(t, identity.model, model);
    verifyEqual(t, identity.mode, 'batch');
    verifyNumElements(t, session.measurements, 2, model);
    for reading = session.measurements
        verifyEqual(t, colormeasure.session.validateReading(reading, session.measurements), reading, model);
    end
    data = session.viewData();
    verifyEqual(t, colormeasure.session.validateViewData(data, 2), data, model);
    result = colormeasure.analysis.compareReadings(data, 1, 2, 0);
    verifyTrue(t, isstruct(result) && isscalar(result), model);
    verifyTrue(t, all(isfield(result, {'deltaE00','spectralRMS','colorReason','pairReason'})), model);
    verifyTrue(t, ischar(result.pairReason) && ischar(result.colorReason), model);
    verifyTrue(t, isfile(session.files.mat), model);
    verifyTrue(t, isfile(session.files.csv), model);
    exported = readtable(session.files.csv);
    verifyGreaterThanOrEqual(t, height(exported), 2, model);
end
end

function testSettingsControlConstructorChecksTheDocumentedShape(t)
help = struct('meaning', 'm', 'whenToUse', 'w', 'tradeoff', 't', 'normal', 'n', 'source', 's');
empty = colormeasure.session.settingsControl();
verifyEmpty(t, empty); verifyEqual(t, size(empty), [0 1]);
verifyEqual(t, sort(fieldnames(empty)), sort({'id';'label';'type';'choices';'minimum';'maximum';'available';'help'}));
control = colormeasure.session.settingsControl('speed', 'Speed', 'choice', ...
    struct('value', {0, 1}, 'label', {'Normal', 'Fast'}), NaN, NaN, true, help);
empty(end+1, 1) = control;
verifyNumElements(t, empty, 1); verifyEqual(t, empty.id, 'speed');
verifyError(t, @() colormeasure.session.settingsControl('', 'X', 'choice', struct('value', {}, 'label', {}), NaN, NaN, true, help), 'Measurement:SettingsControl');
verifyError(t, @() colormeasure.session.settingsControl('x', 'X', 'toggle', struct('value', {}, 'label', {}), NaN, NaN, true, help), 'Measurement:SettingsControl');
verifyError(t, @() colormeasure.session.settingsControl('x', 'X', 'number', struct('value', 1), 0, 1, true, help), 'Measurement:SettingsControl');
verifyError(t, @() colormeasure.session.settingsControl('x', 'X', 'number', struct('value', {}, 'label', {}), [0 1], 1, true, help), 'Measurement:SettingsControl');
verifyError(t, @() colormeasure.session.settingsControl('x', 'X', 'number', struct('value', {}, 'label', {}), 0, 1, 1, help), 'Measurement:SettingsControl');
verifyError(t, @() colormeasure.session.settingsControl('x', 'X', 'number', struct('value', {}, 'label', {}), 0, 1, true, rmfield(help, 'source')), 'Measurement:SettingsControl');
end

function testSettingsChoiceLabelsAreValidatedAcrossArrayShapes(t)
help = struct('meaning', 'm', 'whenToUse', 'w', 'tradeoff', 't', 'normal', 'n', 'source', 's');
choices = reshape(struct('value', {0, 1, 2, 3}, 'label', {'A', 'B', 'C', 'D'}), 2, 2);
control = colormeasure.session.settingsControl('speed', 'Speed', 'choice', choices, NaN, NaN, true, help);
verifyEqual(t, control.choices, choices);
a = directAdapter();
a.settings = struct('catalog', control, 'read', @(~) [], 'apply', @(~, ~) []);
verifyEqual(t, colormeasure.session.validateAdapter(a), a);
control.choices(2, 2).label = 7;
a.settings.catalog = control;
verifyError(t, @() colormeasure.session.validateAdapter(a), 'Measurement:AdapterContract');
verifyError(t, @() colormeasure.session.settingsControl('speed', 'Speed', 'choice', ...
    control.choices, NaN, NaN, true, help), 'Measurement:SettingsControl');
control.choices = repmat(choices(1), 0, 2);
colormeasure.session.validateSettingsCatalog(control, 'Measurement:SettingsControl');
end

function a = directAdapter()
a = struct('key', 'contract-fixture', 'label', 'Contract fixture', ...
    'listPorts', @(~) "VIRTUAL", 'connect', @(~) struct(), ...
    'read', @(~) struct('XYZ', [10 20 30], 'xyzMethod', 'fixture'), ...
    'release', @(~) [], 'toTable', @(m, ~) table((1:numel(m))', 'VariableNames', {'Index'}));
end

function testCatalogIdentityUsesTheSharedWorkflowVocabulary(t)
for mode=colormeasure.session.catalogModes()
    a=directAdapter();a.catalog=struct('model','Custom instrument','mode',mode{1});
    verifyEqual(t,colormeasure.session.validateAdapter(a),a);
end
for mode={'','emissive_spot','anything else'}
    a=directAdapter();a.catalog=struct('model','Custom instrument','mode',mode{1});
    verifyError(t,@()colormeasure.session.validateAdapter(a),'Measurement:AdapterContract');
end
a=directAdapter();a.catalog=struct('model','','mode','measure');
verifyError(t,@()colormeasure.session.validateAdapter(a),'Measurement:AdapterContract');
end

function testMissingScalarViewTextIsRefused(t)
verifyError(t,@()colormeasure.session.validateViewData(struct('observer',string(missing)),0), ...
    'Measurement:InvalidViewData');
verifyError(t,@()colormeasure.session.validateViewData(struct('observerNames',{{string(missing)}}),1), ...
    'Measurement:InvalidViewData');
end

function testRegistryIsolationRestoresOnlyOwnedBindingsAndKeepsPreviousSessions(t)
key='ColorMeasureSessions';name='registryCollision';unrelated='registryUnrelated';published='registryPublished';
colormeasuretest.preserveWorkspace(t,name);colormeasuretest.preserveWorkspace(t,unrelated);
colormeasuretest.preserveWorkspace(t,published);evalin('base',['clear ' published]);
assignin('base',name,42);assignin('base',unrelated,10);
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
a=directAdapter();a.workspaceName=name;
io=colormeasure.session.services();io.now=@()datetime(2026,10,5,'TimeZone','UTC');
previous=colormeasure.session.Session(a,folder,io);
t.addTeardown(@()colormeasuretest.disposeSession(previous));
colormeasure.session.sessionRegistry('put',a.key,previous,folder);
registry=getappdata(groot,key);
cleanup=colormeasuretest.isolateRegistry(t);
session=colormeasure.session.Session(a,folder,io);
colormeasure.session.sessionRegistry('put',a.key,session,folder);
assignin('base',name,session);assignin('base',unrelated,11);assignin('base',published,session);
verifyWarningFree(t,cleanup);
verifyFalse(t,isvalid(session));verifyTrue(t,isvalid(previous));
verifyEqual(t,evalin('base',name),42);verifyEqual(t,evalin('base',unrelated),11);
verifyEqual(t,evalin('base',sprintf('exist(''%s'',''var'')',published)),0);
verifyEqual(t,getappdata(groot,key),registry);
cleanup();verifyTrue(t,isvalid(previous)); % Early cleanup is idempotent.
end

function testRegistryIsolationRestoresBindingAfterDeletedHandleWasPruned(t)
name='registryPrunedCollision';colormeasuretest.preserveWorkspace(t,name);
assignin('base',name,struct('prior',17));
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
cleanup=colormeasuretest.isolateRegistry(t);
a=directAdapter();a.workspaceName=name;
session=colormeasure.session.Session(a,folder);
colormeasure.session.sessionRegistry('put',a.key,session,folder);assignin('base',name,session);
colormeasuretest.disposeSession(session);
verifyEmpty(t,colormeasure.session.sessionRegistry('get').sessions);
verifyWarningFree(t,cleanup);
verifyEqual(t,evalin('base',name),struct('prior',17));
end

function testRegistryIsolationRemovesOnlyNewRecoveryVariables(t)
name='colorMeasureRecovered_999999';colormeasuretest.preserveWorkspace(t,name);
assignin('base',name,42);before=evalin('base','who(''colorMeasureRecovered_*'')');
for deleted=[false true]
    folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    cleanup=colormeasuretest.isolateRegistry(t);
    io=colormeasure.session.services();io.saveMat=@(~,~,~)error('Fixture:Save','Disk unavailable');
    a=directAdapter();session=colormeasure.session.Session(a,folder,io);
    colormeasure.session.sessionRegistry('put',a.key,session,folder);
    session.measure('Unsaved sample','');assertNumElements(t,session.measurements,1);
    if deleted
        verifyWarning(t,@()delete(session),'Measurement:UnsavedSession');
        verifyNotEmpty(t,setdiff(evalin('base','who(''colorMeasureRecovered_*'')'),before));
        colormeasure.session.sessionRegistry('get');
    end
    verifyWarningFree(t,cleanup);verifyFalse(t,isvalid(session));
    verifyEqual(t,evalin('base','who(''colorMeasureRecovered_*'')'),before);
    verifyEqual(t,evalin('base',name),42);
end
end

function testRegistryIsolationRestoresEmptyOrAbsentAppdataExactly(t)
key='ColorMeasureSessions';
for present=[false true]
    if isappdata(groot,key),rmappdata(groot,key);end
    if present,setappdata(groot,key,[]);end
    cleanup=colormeasuretest.isolateRegistry(t);
    colormeasure.session.sessionRegistry('get');
    cleanup();
    verifyEqual(t,isappdata(groot,key),present);
    verifyEmpty(t,getappdata(groot,key));
end
end

function testBundledNativeUiPreparationTitlesEveryParagraph(t)
for model={'CR100','CR250','CR300'}
    a=colormeasure.drivers.cr.uiAdapter(model{1});
    verifyNumElements(t,a.preparation.headings,numel(a.preparation.details));
end
a=colormeasure.drivers.cs2000.uiAdapter();
verifyNumElements(t,a.preparation.headings,numel(a.preparation.details));
a=colormeasure.drivers.pr.uiAdapter();
verifyNumElements(t,a.preparation.headings,numel(a.preparation.details));
end

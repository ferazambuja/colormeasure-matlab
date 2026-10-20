function tests = testMultiDeviceWorkflow
% Full bundled UI integration using generated readings; no serial access.
tests = functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function setup(t)
% The launcher and catalog branch on retained batches: isolate the registry.
colormeasuretest.isolateRegistry(t);
visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
t.addTeardown(@() set(groot,'DefaultFigureVisible',visible));
end
function testEachDeviceHasAnIndependentKeyAndWorkspaceName(t)
models={'PR655','CR100','CR250','CR300','CS2000'};
expected={'colorMeasurePR655Session','colorMeasureCR100Session','colorMeasureCR250Session','colorMeasureCR300Session','colorMeasureCS2000Session'};
keys=cell(size(models));
io=struct('launchSession',@(adapter,~) adapter);
for index=1:numel(models)
    [adapter,name]=colormeasure.ui.launchDevice(models{index},io);
    keys{index}=adapter.key;
    verifyEqual(t,name,expected{index});
    verifyClass(t,adapter.read,'function_handle');
    verifyClass(t,adapter.toTable,'function_handle');
end
verifyEqual(t,numel(unique(keys)),numel(models));
end
function testAllFamilyBatchDemosSaveCompleteTwoReadingBatches(t)
for model={'PR655','CR100','CR250','CR300','CS2000'}
    [session,workspaceName]=colormeasure.ui.launchDevice(model{1},[],'batch');
    t.addTeardown(@() colormeasuretest.disposeBatch(session));
    verifyEqual(t,workspaceName,['colorMeasure' model{1} 'DemoBatch']);
    verifyEqual(t,session.workspaceName,workspaceName);
    verifyTrue(t,session.finished);verifyNumElements(t,session.measurements,2);
    verifyTrue(t,all([session.measurements.isSynthetic]));
    saved=load(session.files.mat);verifyEqual(t,saved.measurements,session.measurements);
    verifyTrue(t,saved.batchInfo.acquisitionComplete);
    verifyTrue(t,isfile(session.files.csv));
    csv=readtable(session.files.csv);
    expected=sum(arrayfun(@(reading) max(1,numel(reading.lambda)),session.measurements));
    verifyEqual(t,height(csv),expected);
    if strcmp(model{1},'CR100')
        verifyEmpty(t,session.measurements(1).lambda);
        verifyEmpty(t,session.measurements(1).spectralData);
    elseif strcmp(model{1},'CS2000')
        verifyEqual(t,session.measurements(1).lambda,(380:780)');
        verifyNumElements(t,session.measurements(1).spectralData,401);
    end
end
end
function testFamilyGalleriesRestoreWithoutMeasuringAndKeepPlotIdentity(t)
% CR250 and CR300 share one gallery code path; one spectral CR model suffices.
for model={'CR100','CR250','CS2000'}
    session=colormeasure.demo(model{1},'gallery');t.addTeardown(@() colormeasuretest.disposeBatch(session));
    verifyEqual(t,session.workspaceName,['colorMeasure' model{1} 'DemoGallery']);
    verifyNumElements(t,session.measurements,12);verifyFalse(t,session.finished);
    before=session.measurements;original=session.window;
    points=findobj(original,'Tag','ReadingChromaticity');verifyNumElements(t,points,12);
    colors=cell2mat(get(points,'Color'));verifyEqual(t,size(unique(colors,'rows'),1),12);
    spectra=findobj(original,'Tag','ReadingSpectrum');
    if strcmp(model{1},'CR100')
        verifyEmpty(t,spectra);
        viewData=session.viewData();
        verifyEqual(t,findobj(original,'Tag','SpectrumUnavailable').Text,viewData.noSpectrumReason);
    else
        verifyNumElements(t,spectra,12);
    end
    session.hide();restored=colormeasure.demo(model{1},'gallery');
    verifyEqual(t,restored,session);verifyEqual(t,session.window,original);
    verifyEqual(t,session.measurements,before);
    table=findobj(original,'Tag','ResultsTable');
    callback=table.CellSelectionCallback;callback(table,struct('Indices',[1 3;2 3]));
    white=findobj(original,'Tag','CompareWhite');white.Value=3;
    callback=white.ValueChangedFcn;callback(white,[]);
    result=findobj(original,'Tag','ComparisonResults').UserData;
    verifyTrue(t,isfinite(result.deltaE00)); % Declared, common synthetic scale.
    if strcmp(model{1},'CR100'),verifyTrue(t,isnan(result.spectralRMS));
    else,verifyTrue(t,isfinite(result.spectralRMS));end
    session.finish();saved=load(session.files.mat);
    verifyEqual(t,saved.measurements,before);
end
end

function testRealDriverMetadataControlsOperatorScaleDeclaration(t)
% Parse simulated replies through both actual drivers, then check that their
% presentation declarations compose with the shared comparison calculation.
for model={'CR100','CS2000'}
    if strcmp(model{1},'CR100')
        peer=colormeasuretest.cr.Port('CR-100');
        meter=colormeasure.drivers.cr.CR100('SIM','Transport',peer,'ResponseTimeout',0.1,'MeasurementTimeout',0.1);
        adapter=colormeasure.drivers.cr.uiAdapter('CR100');
    else
        peer=colormeasuretest.cs2000.Port();
        adapter=colormeasure.drivers.cs2000.uiAdapter('Transport',peer,'PortList',@(~) "SIM");
        meter=adapter.connect('SIM');
    end
    cleanup=onCleanup(@() adapter.release(meter));
    reading=adapter.read(meter);
    data=adapter.viewData(repmat(reading,1,3));
    data.XYZ(2,:)=data.XYZ(2,:)*0.9;
    data.XYZ(3,:)=data.XYZ(3,:)*2;
    before=colormeasure.analysis.compareReadings(data,1,2,3);
    verifyTrue(t,before.scaleDeclarationEligible);
    verifyTrue(t,isnan(before.deltaE00));
    verifyTrue(t,all(isfinite(before.deltaUV)));
    declaration=struct('confirmed',true,'referenceIndex',1,'sampleIndex',2, ...
        'white',3,'declaredAtUTC','2026-09-16T12:00:00Z');
    after=colormeasure.analysis.compareReadings(data,1,2,3,declaration);
    verifyTrue(t,isfinite(after.deltaE00));
    verifyEqual(t,after.scaleDeclaration.source,'operator');
    verifyEqual(t,after.deltaXYZ,data.XYZ(2,:)-data.XYZ(1,:));
    data.xyzScaleDeclarationKeys{3}='Different white convention';
    mismatch=colormeasure.analysis.compareReadings(data,1,2,3,declaration);
    verifyFalse(t,mismatch.scaleDeclarationEligible);
    verifyTrue(t,isnan(mismatch.deltaE00));
    clear cleanup
end
end

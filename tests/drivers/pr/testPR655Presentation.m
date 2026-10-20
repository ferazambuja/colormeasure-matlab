function tests = testPR655Presentation
% Integrated PR presentation using the real parser with simulated replies.
% Fernando Voltolini de Azambuja, 2026.
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
function testSessionShowsBothPlotsAndTableWithoutAnotherFigure(t)
before=findall(groot,'Type','figure');
s=createSession(t); s.show(); fig=s.window;
s.measure('Sample 001','First sample');
s.measure('Sample 002','Second sample');
for reading = s.measurements
    verifyEmpty(t,reading.instrumentMetadata.serialNumber);
    verifyEqual(t,reading.instrumentMetadata.queries.serialNumber.status,'notQueried');
    verifyFalse(t,reading.instrumentMetadata.metadataQueriesRequireReconnect);
end
state=colormeasuretest.pr.state();
% The UI restores automatic acquisition before each exposure. Settings
% readback is distinct from the optional saved instrument metadata queries.
verifyEqual(t,state.commands,{'Q','PHOTO','D111','D601','D602','SS1', ...
    'D601','D602','B00','M5','B100','Q'});
for reading = s.measurements
    verifyEqual(t,reading.instrumentSettings.policy,'automatic-with-overrides');
    verifyEmpty(t,fieldnames(reading.instrumentSettings.overrides));
    verifyEqual(t,reading.instrumentSettings.status,'applied');
end
verifyNumElements(t,findall(groot,'Type','figure'),numel(before)+1);
verifyEqual(t,s.window,fig);
spectrum=findobj(fig,'Tag','SpectrumAxes');
chromaticity=findobj(fig,'Tag','ChromaticityAxes');
verifyNumElements(t,spectrum,1); verifyNumElements(t,chromaticity,1);
verifyEqual(t,char(get(spectrum,'Visible')),'on');
verifyEqual(t,char(get(chromaticity,'Visible')),'on');
verifyNumElements(t,findobj(spectrum,'Tag','ReadingSpectrum'),2);
verifyNumElements(t,findobj(chromaticity,'Tag','ReadingChromaticity'),2);
curve=findobj(spectrum,'Tag','ReadingSpectrum','UserData',2);
verifyEqual(t,curve.YData(:),s.measurements(2).radiance);
control=findobj(fig,'Tag','ResultsTable');data=control.Data;
verifySize(t,data,[2 numel(control.ColumnName)]);
verifyTrue(t,ismember('Mode',control.ColumnName));
verifyEqual(t,data(:,3),{'Sample 001';'Sample 002'});
xyzColumns=cellfun(@(name)find(strcmp(control.ColumnName,name),1),{'X','Y','Z'});
verifyEqual(t,cell2mat(data(:,xyzColumns)),vertcat(s.measurements.XYZ));
end
function s=createSession(t)
a=colormeasure.drivers.pr.uiAdapter(); a.listPorts=@(~) "/dev/cu.usbmodem_VIRTUAL"; a.connect=@connect;
s=colormeasure.session.Session(a,t.TestData.folder,colormeasure.ui.services()); t.addTeardown(@() delete(s));
end
function instrument=connect(port,unitsCode)
if nargin<2,unitsCode=0;end
colormeasuretest.pr.configure('Ports',string(port),'UnitsCode',unitsCode,'D110','00000,655 PRESENTATION-1');
instrument=colormeasuretest.pr.Driver(port,'Timeout',2,'Clock',colormeasuretest.FakeClock());
end

function testCurrentProvenanceIsComparableWithoutMutation(t)
instrument=colormeasure.drivers.pr.DemoInstrument(1,0); t.addTeardown(@()delete(instrument));
a=colormeasure.drivers.pr.adapter(); current=a.read(instrument);
% Pins the stored xyzMethod literal that viewData compares; changing it is a deliberate data change.
pinned=current; pinned.xyzMethod='colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1';
verifyEqual(t,current.xyzMethod,pinned.xyzMethod);
records=[pinned current];
data=colormeasure.drivers.pr.viewData(records);
verifyEqual(t,data.observerId,'CIE1931_2deg');
verifyEqual(t,data.xyzComparisonKeys{1},data.xyzComparisonKeys{2});
verifyEqual(t,data.reflectanceRatioEligible,true(2,1));
verifyEqual(t,data.spectralQuantities,{'synthetic radiance';'synthetic radiance'});
verifyEqual(t,data.reflectanceRatioReasons,{'';''});
result=colormeasure.analysis.compareReadings(data,1,2,struct('illuminant','D65','Y',100));
verifyEqual(t,result.deltaE00,0,'AbsTol',1e-14);
verifyEqual(t,result.spectralRMS,0);

unknown=current;unknown.xyzMethod='Unknown spectral method';
data=colormeasure.drivers.pr.viewData([current unknown]);
verifyEmpty(t,data.observerId);verifyEmpty(t,data.locusXYZ);
result=colormeasure.analysis.compareReadings(data,1,2,0);
verifyNotEmpty(t,result.pairReason);
verifyEqual(t,data.reflectanceRatioEligible,[true;false]);
verifyNotEmpty(t,data.reflectanceRatioReasons{2});
end

function testRadiometricQuantitiesCompareButOnlyRadiancePermitsRatio(t)
quantities={'radiance','irradiance','radiant intensity','radiant flux'};
config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
for code=11:14
    instrument=connect('/dev/cu.usbmodem_VIRTUAL',code);
    cleanup=onCleanup(@()delete(instrument));
    adapter=colormeasure.drivers.pr.adapter(); reading=adapter.read(instrument);
    records=[reading reading];
    data=colormeasure.drivers.pr.viewData(records);
    verifyEqual(t,data.spectralQuantities,repmat(quantities(code-10),2,1));
    verifyEqual(t,data.reflectanceRatioEligible,repmat(code==11,2,1));
    verifyEqual(t,data.spectra{1}.y,reading.radiance);
    result=colormeasure.analysis.compareReadings(data,1,2,0);
    verifyEqual(t,result.spectralRMS,0); verifyEmpty(t,result.spectralReason);
    derived=colormeasure.analysis.deriveIllumination(data,2,config);
    verifyEqual(t,derived.available,code==11,derived.reason);
    if code==11
        verifyEmpty(t,data.reflectanceRatioReasons{1});
        verifyEqual(t,derived.spectrum.y,ones(size(reading.radiance)));
    else
        verifyTrue(t,contains(data.reflectanceRatioReasons{1},quantities{code-10}));
        verifyTrue(t,contains(derived.reason,'radiance'));
    end

    clear cleanup
end
end

function testDemoRatioEligibilityRequiresItsDeclaredMethodUnitsAndHeader(t)
config=struct('mode','reflectance','reference',1,'confirmedSetup',true, ...
    'assumePerfectReference',true,'targetIlluminant','D65');
for model={'PR-655','PR-670'}
    instrument=colormeasure.drivers.pr.DemoInstrument(10,0,model{1}); % Broadband reference.
    cleanup=onCleanup(@()delete(instrument));
    adapter=colormeasure.drivers.pr.adapter(); reading=adapter.read(instrument);
    data=colormeasure.drivers.pr.viewData(reading);
    verifyTrue(t,data.reflectanceRatioEligible);
    verifyEqual(t,data.spectralQuantities,{'synthetic radiance'});
    pair=colormeasure.drivers.pr.viewData([reading reading]);
    derived=colormeasure.analysis.deriveIllumination(pair,2,config);
    verifyTrue(t,derived.available,derived.reason);
    verifyEqual(t,derived.spectrum.y,ones(size(reading.radiance)));
    variants=repmat({reading},1,6);
    variants{1}.xyzMethod='Unverified method';
    variants{2}.spectralUnits='Unverified units';
    variants{3}.unitsCode=11; % The supported demo declares code 0.
    variants{4}.unitsCode=NaN;
    variants{5}.isSynthetic=false; % Real code 0 has no documented quantity.
    variants{6}=rmfield(reading,'unitsCode');
    for index=1:numel(variants)
        original=variants{index};
        data=colormeasure.drivers.pr.viewData(original);
        verifyFalse(t,data.reflectanceRatioEligible);
        verifyNotEmpty(t,data.reflectanceRatioReasons{1});
        verifyEqual(t,data.spectra{1}.y,original.radiance);
    end
    clear cleanup
end
end


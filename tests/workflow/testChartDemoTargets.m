function tests = testChartDemoTargets
% Guided demo targets are keyed by fixed cell and attempt, never acquisition order.
tests=functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testGuidedTargetSurvivesOutOfOrderAndRereading(t)
wavelength=(380:4:780)';
first=colormeasure.simulation.syntheticProfile(91,wavelength,intent(2,1));
same=colormeasure.simulation.syntheticProfile(4,wavelength,intent(2,1));
retry=colormeasure.simulation.syntheticProfile(7,wavelength,intent(2,2));
other=colormeasure.simulation.syntheticProfile(3,wavelength,intent(14,1));
verifyEqual(t,first,same);
verifyEqual(t,first.association,intent(2,1));
verifyEqual(t,retry.association,intent(2,2));
verifyEqual(t,first.index,2); verifyEqual(t,retry.index,2); verifyEqual(t,other.index,2);
verifyEqual(t,first.seed,2); verifyEqual(t,retry.seed,142); verifyEqual(t,other.seed,14);
verifyNotEqual(t,first.spectrum,retry.spectrum);
verifyEqual(t,first.spectrum/first.gain,retry.spectrum/retry.gain,'AbsTol',1e-18);
verifyEqual(t,first.spectrum/first.gain,other.spectrum/other.gain,'AbsTol',1e-18);
verifyGreaterThanOrEqual(t,[first.gain retry.gain other.gain],.995);
verifyLessThanOrEqual(t,[first.gain retry.gain other.gain],1.005);
end

function testOrdinarySamplerRetainsExactEarlierNumericalSequence(t)
wavelength=(380:4:780)';
profiles=colormeasure.simulation.syntheticProfiles();
for index=[1 2 13 140]
    source=profiles(mod(index-1,12)+1);
    spectrum=zeros(size(wavelength));
    for k=1:size(source.components,1)
        component=source.components(k,:);
        spectrum=spectrum+component(3)*exp(-0.5*((wavelength-component(1))/component(2)).^2);
    end
    stream=RandStream('mt19937ar','Seed',mod(index,2^32));
    gain=1+.005*(2*rand(stream)-1);
    actual=colormeasure.simulation.syntheticProfile(index,wavelength);
    verifyEqual(t,actual.spectrum,spectrum*gain);
    verifyEqual(t,actual.gain,gain); verifyEqual(t,actual.seed,index);
    verifyEmpty(t,actual.association);
end
end

function testGuidedTargetsDoNotChangeGlobalRandomState(t)
before=rng;
for cellIndex=[1 24 140]
    for attempt=[1 2 100]
        actual=colormeasure.simulation.syntheticProfile(1,(380:780)',intent(cellIndex,attempt));
        verifyEqual(t,actual.seed,140*(attempt-1)+cellIndex);
    end
end
verifyEqual(t,rng,before);
end

function testGuidedAttemptBoundUsesTheExactIntegerLimit(t)
value=colormeasure.simulation.syntheticProfile(1,(380:780)',intent(140,flintmax-1));
verifyEqual(t,value.association.attempt,flintmax-1);
verifyEqual(t,value.seed,mod(140+140*mod(flintmax-2,2^32),2^32));
verifyGreaterThanOrEqual(t,value.gain,.995); verifyLessThanOrEqual(t,value.gain,1.005);
verifyError(t,@()colormeasure.simulation.syntheticProfile(1,(380:780)',intent(1,flintmax)), ...
    'Measurement:DemoIntent');
end

function testInvalidIntentCannotBecomeSyntheticProvenance(t)
for value={[],{},1,struct('cell_index',1),struct('cell_index',1,'attempt',0), ...
        struct('cell_index',141,'attempt',1),struct('cell_index',true,'attempt',1), ...
        struct('cell_index',1,'attempt',NaN),struct('cell_index',1.5,'attempt',1), ...
        struct('cell_index',1,'attempt',1,'unexpected',0),repmat(intent(1,1),1,2)}
    verifyError(t,@()colormeasure.simulation.syntheticProfile(1,(380:780)',value{1}), ...
        'Measurement:DemoIntent');
end
end

function testCRAndCSDemoAdaptersKeepFreeCounterSeparate(t)
adapters={colormeasure.drivers.cr.demoAdapter('CR100'), ...
    colormeasure.drivers.cr.demoAdapter('CR250'), ...
    colormeasure.drivers.cr.demoAdapter('CR300'),colormeasure.drivers.cs2000.demoAdapter()};
for k=1:numel(adapters)
    adapter=adapters{k};
    verifyTrue(t,isfield(adapter,'prepareSample'));
    free=adapter.read([]);
    verifyEqual(t,free.syntheticProfileIndex,1); verifyEmpty(t,free.syntheticAssociation);
    adapter.prepareSample(intent(7,1)); first=adapter.read([]);
    adapter.prepareSample(intent(7,2)); retry=adapter.read([]);
    adapter.prepareSample(intent(2,1)); other=adapter.read([]);
    adapter.prepareSample(struct([])); next=adapter.read([]);
    verifyEqual(t,first.syntheticProfileIndex,7); verifyEqual(t,retry.syntheticProfileIndex,7);
    verifyEqual(t,other.syntheticProfileIndex,2); verifyEqual(t,next.syntheticProfileIndex,2);
    verifyEqual(t,first.syntheticAssociation,intent(7,1));
    verifyEqual(t,retry.syntheticAssociation,intent(7,2));
    verifyEqual(t,first.syntheticSeed,7); verifyEqual(t,retry.syntheticSeed,147);
    verifyEqual(t,next.syntheticSeed,2); verifyEmpty(t,next.syntheticAssociation);
    verifyEqual(t,first.XYZ/first.syntheticGain,retry.XYZ/retry.syntheticGain,'AbsTol',1e-11);
    verifyNotEqual(t,first.XYZ,retry.XYZ);
    if k==1
        verifyEmpty(t,first.lambda); verifyEmpty(t,first.spectralData);
    else
        verifyEqual(t,first.spectralData/first.syntheticGain, ...
            retry.spectralData/retry.syntheticGain,'AbsTol',1e-18);
    end
    verifyEqual(t,fieldnames(first),fieldnames(free));
end
end

function testPRDemoMeterKeepsFreeCounterSeparateOnBothModelGrids(t)
for model={'PR-655','PR-670'}
    meter=colormeasure.drivers.pr.DemoInstrument(1,0,model{1});
    cleanup=onCleanup(@()delete(meter));
    free=meter.measure();
    meter.prepareSample(intent(7,1)); first=meter.measure();
    meter.prepareSample(intent(7,2)); retry=meter.measure();
    meter.prepareSample(intent(2,1)); other=meter.measure();
    meter.prepareSample(struct([])); next=meter.measure();
    verifyEqual(t,free.syntheticProfileIndex,1); verifyEmpty(t,free.syntheticAssociation);
    verifyEqual(t,first.syntheticProfileIndex,7); verifyEqual(t,retry.syntheticProfileIndex,7);
    verifyEqual(t,other.syntheticProfileIndex,2); verifyEqual(t,next.syntheticProfileIndex,2);
    verifyEqual(t,first.syntheticAssociation,intent(7,1));
    verifyEqual(t,retry.syntheticAssociation,intent(7,2));
    verifyEqual(t,first.syntheticSeed,7); verifyEqual(t,retry.syntheticSeed,147);
    verifyEqual(t,next.syntheticSeed,2); verifyEmpty(t,next.syntheticAssociation);
    verifyEqual(t,first.radiance/first.syntheticGain,retry.radiance/retry.syntheticGain,'AbsTol',1e-18);
    verifyEqual(t,first.XYZ/first.syntheticGain,retry.XYZ/retry.syntheticGain,'AbsTol',1e-11);
    verifyEqual(t,first.totalRadiance/first.syntheticGain,retry.totalRadiance/retry.syntheticGain,'AbsTol',1e-12);
    verifyEqual(t,first.peakWavelength,retry.peakWavelength);
    verifyNotEqual(t,first.radiance,retry.radiance);
    verifyEqual(t,fieldnames(first),fieldnames(free));
    clear cleanup
end
end

function testDifferentAcquisitionIndicesHaveSameSyntheticXYZForSameIntent(t)
for model={'CR100','CR250','CR300'}
    first=colormeasure.drivers.cr.syntheticReading(model{1},1,intent(140,3));
    other=colormeasure.drivers.cr.syntheticReading(model{1},77,intent(140,3));
    verifyEqual(t,first,other);
end
first=colormeasure.drivers.cs2000.syntheticReading(1,intent(140,3));
other=colormeasure.drivers.cs2000.syntheticReading(77,intent(140,3));
verifyEqual(t,first,other);
end

function value=intent(cellIndex,attempt)
value=struct('cell_index',cellIndex,'attempt',attempt);
end

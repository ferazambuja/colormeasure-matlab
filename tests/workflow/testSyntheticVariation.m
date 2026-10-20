function tests = testSyntheticVariation
% Shared serial demos use one profile sampler, without changing MATLAB's RNG.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function testCycleHasSmallRepeatableVariationWithoutGlobalRandomState(t)
before = rng;
wavelengths = (380:4:780)';
first = colormeasure.simulation.syntheticProfile(1,wavelengths);
again = colormeasure.simulation.syntheticProfile(1,wavelengths);
nextCycle = colormeasure.simulation.syntheticProfile(13,wavelengths);
verifyEqual(t,rng,before);
verifyEqual(t,first,again);
verifyEqual(t,first.name,nextCycle.name);
verifyEqual(t,first.index,nextCycle.index);
verifyNotEqual(t,first.spectrum,nextCycle.spectrum);
ratio = nextCycle.spectrum ./ first.spectrum;
verifyLessThanOrEqual(t,max(abs(ratio-1)),.011);
verifyEqual(t,ratio,repmat(ratio(1),size(ratio)),'AbsTol',1e-12);
end

function testEveryShapeHasOnlyBoundedGainAndStaysNonnegative(t)
wavelengths = (380:780)';
profiles = colormeasure.simulation.syntheticProfiles();
for index = 1:24
    source = profiles(mod(index-1,12)+1);
    base = zeros(size(wavelengths));
    for k = 1:size(source.components,1)
        c = source.components(k,:);
        base = base+c(3)*exp(-.5*((wavelengths-c(1))/c(2)).^2);
    end
    actual = colormeasure.simulation.syntheticProfile(index,wavelengths);
    verifyGreaterThanOrEqual(t,min(actual.spectrum),0);
    gain = max(actual.spectrum)/max(base);
    verifyGreaterThanOrEqual(t,gain,.995);
    verifyLessThanOrEqual(t,gain,1.005);
    verifyEqual(t,actual.spectrum,base*gain,'AbsTol',1e-17);
end
end

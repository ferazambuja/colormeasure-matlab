function tests = testMeasurementSyntheticProfiles
tests = functiontests(localfunctions);
end
function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testNativeGridsKeepTheirSamplesAndKnownGaussian(t)
for wavelengths={(380:4:780)',(380:780)',(400:2:700)'}
    wave=wavelengths{1};
    profile=colormeasure.simulation.syntheticProfile(4,wave);
    verifySize(t,profile.spectrum,size(wave));
    base=.003*exp(-.5*((wave-450)/9).^2);
    gain=max(profile.spectrum)/max(base);
    verifyGreaterThanOrEqual(t,gain,.995);
    verifyLessThanOrEqual(t,gain,1.005);
    verifyEqual(t,profile.spectrum,base*gain,'AbsTol',1e-18);
    verifyEqual(t,profile.index,4);
end
end
function testProfilesWrapAndLowSignalRetainsItsShape(t)
profiles=colormeasure.simulation.syntheticProfiles();
verifyNumElements(t,profiles,12);
wave=(380:780)';
first=colormeasure.simulation.syntheticProfile(1,wave);
wrapped=colormeasure.simulation.syntheticProfile(13,wave);
verifyEqual(t,wrapped.index,first.index);
verifyEqual(t,wrapped.name,first.name);
verifyNotEqual(t,wrapped.spectrum,first.spectrum);
verifyEqual(t,wrapped.spectrum/max(wrapped.spectrum),first.spectrum/max(first.spectrum),'AbsTol',1e-15);
neutral=colormeasure.simulation.syntheticProfile(3,wave);
low=colormeasure.simulation.syntheticProfile(12,wave);
ratio=max(low.spectrum)/max(neutral.spectrum);
verifyGreaterThanOrEqual(t,ratio,.01*.995/1.005);
verifyLessThanOrEqual(t,ratio,.01*1.005/.995);
verifyEqual(t,low.spectrum,neutral.spectrum*ratio,'AbsTol',1e-19);
end

function tests = testSpectra
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end
function testCIEDataIdentity(t)
root = colormeasuretest.projectRoot();
% Hash the original bytes, not a newline-normalized text representation.
hash = colormeasuretest.fileSha256(fullfile(root,'resources','colorimetry','CIE_xyz_1931_2deg.csv'));
verifyEqual(t,hash,'fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1');
end
function testObserver(t)
[cmf,w]=colormeasure.colorimetry.observer();
verifyEqual(t,w,(360:830)'); verifySize(t,cmf,[471 3]);
verifyEqual(t,cmf(w==555,2),1);
end
function testFrozenSchoolResults(t)
root=fileparts(mfilename('fullpath'));
f=load(fullfile(root,'data','mcsl-spectra-reference.mat'));
assertTrue(t,isfield(f,'cases') && isstruct(f.cases) && ~isempty(f.cases), ...
    'The frozen reference must contain runnable numerical cases.');
assertTrue(t,all(isfield(f.cases,{'wavelength','spectra','XYZ','integral'})));
for k=1:numel(f.cases)
    x=f.cases(k); plan=colormeasure.colorimetry.XYZIntegrator(x.wavelength);
    verifyEqual(t,plan.convert(x.spectra),x.XYZ,'RelTol',3e-13,'AbsTol',1e-12);
    verifyEqual(t,colormeasure.colorimetry.spectra2XYZ(x.spectra,x.wavelength),x.XYZ,'RelTol',3e-13,'AbsTol',1e-12);
    verifyEqual(t,colormeasure.colorimetry.spectralIntegral(x.spectra,x.wavelength),x.integral,'AbsTol',1e-12);
    if size(x.spectra,1)~=size(x.spectra,2)
        verifyEqual(t,plan.convert(x.spectra.'),x.XYZ,'RelTol',3e-13,'AbsTol',1e-12);
    end
end
end
function testIndependentOneBinAndSigned(t)
w=(380:4:780)';s=zeros(size(w));s(w==556)=1;
[cmf,native]=colormeasure.colorimetry.observer();
scale=683*4/interp1(native,cmf(:,2),299792458/540e12*1e9);
verifyEqual(t,colormeasure.colorimetry.spectra2XYZ(s,w),scale*cmf(native==556,:),'RelTol',1e-14);
verifyEqual(t,colormeasure.colorimetry.spectra2XYZ(-s,w),-colormeasure.colorimetry.spectra2XYZ(s,w));
verifyEqual(t,colormeasure.colorimetry.spectra2XYZ(zeros(size(w)),w),zeros(1,3));
end
function testIntegralAndRMS(t)
w=(380:2:780)';verifyEqual(t,colormeasure.colorimetry.spectralIntegral(ones(size(w)),w),402);
[r,d]=colormeasure.colorimetry.spectralRMS([1 2 3 4],(1:4)',[1 2 3 6],1:4);
verifyEqual(t,r,1);verifyEqual(t,d,[0;0;0;2]);
verifyEqual(t,colormeasure.colorimetry.spectralRMS([1e300;1e300],[1;2],[0;0],[1;2]),1e300,'RelTol',eps);
verifyError(t,@()colormeasure.colorimetry.spectralRMS([1;2],[1;2],[1;2],[1;3]),'colormeasure:Colorimetry:Wavelength');
end
function testInvalidGridAndCache(t)
for w={[],1,[1 1],[2 1],[1 2 4],[0 1],[1 NaN],[1 Inf]}
 verifyError(t,@()colormeasure.colorimetry.XYZIntegrator(w{1}),'colormeasure:Colorimetry:Wavelength');
end
colormeasure.colorimetry.spectra2XYZ([1;1],[380;384]);
verifyError(t,@()colormeasure.colorimetry.spectra2XYZ([1;1],uint16([380;384])),'colormeasure:Colorimetry:Wavelength');
verifyError(t,@()colormeasure.colorimetry.spectra2XYZ([1;NaN],[380;384]),'colormeasure:Colorimetry:Spectrum');
verifyError(t,@()colormeasure.colorimetry.spectra2XYZ([1;2;3],[380;384]),'colormeasure:Colorimetry:SpectrumShape');
end
function testRMSFiniteRange(t)
w=(380:4:780)';z=zeros(size(w));
for magnitude=[1e-300,1e300,realmax/2,realmax]
    [value,residual]=colormeasure.colorimetry.spectralRMS(z,w,magnitude*ones(size(w)),w);
    verifyTrue(t,isfinite(value));
    verifyEqual(t,value/magnitude,1,'AbsTol',4*eps);
    verifyLessThanOrEqual(t,value,magnitude);
    verifyEqual(t,residual,magnitude*ones(size(w)));
end
verifyEqual(t,colormeasure.colorimetry.spectralRMS(z,w,z,w),0);
verifyError(t,@()colormeasure.colorimetry.spectralRMS(-realmax*ones(size(w)),w, ...
    realmax*ones(size(w)),w),'colormeasure:Colorimetry:NumericRange');
% Known result with both residual signs and an exactly representable RMS.
[value,residual]=colormeasure.colorimetry.spectralRMS([0 0 0 0],1:4,[1 -1 1 -1],1:4);
verifyEqual(t,value,1);verifyEqual(t,residual,[1;-1;1;-1]);
end
function testSingleAndEmpty(t)
w=(380:4:780)';p=colormeasure.colorimetry.XYZIntegrator(w);
verifyClass(t,p.convert(single(ones(size(w)))),'double');
verifySize(t,p.convert(zeros(numel(w),0)),[0 3]);
verifyEqual(t,p.Wavelength,w);
end

function testGridPrecisionPolicy(t)
verifyError(t,@()colormeasure.colorimetry.XYZIntegrator(single(380:0.1:780)),'colormeasure:Colorimetry:Wavelength');
verifyError(t,@()colormeasure.colorimetry.XYZIntegrator([1 1+1e-13 1+2.05e-13]),'colormeasure:Colorimetry:Wavelength');
plan=colormeasure.colorimetry.XYZIntegrator(380:0.1:780);
verifySize(t,plan.convert(ones(4001,1)),[1 3]);
end
function testInvalidObserverCannotPoisonCache(t)
root=colormeasuretest.projectRoot();
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
package=fullfile(f.Folder,'src','+colormeasure');
mkdir(fullfile(package,'+colorimetry'));mkdir(fullfile(f.Folder,'resources','colorimetry'));
copyfile(fullfile(root,'src','+colormeasure','root.m'),fullfile(package,'root.m'));
copyfile(fullfile(root,'src','+colormeasure','+colorimetry','observer.m'),fullfile(package,'+colorimetry','observer.m'));
writematrix(zeros(2,4),fullfile(f.Folder,'resources','colorimetry','CIE_xyz_1931_2deg.csv'));
t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(f.Folder,'src')));
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(f.Folder));
clear colormeasure.colorimetry.observer colormeasure.root
t.addTeardown(@clearObserver);
verifyEqual(t,which('colormeasure.colorimetry.observer'),fullfile(package,'+colorimetry','observer.m'));
verifyEqual(t,colormeasure.root(),f.Folder);
verifyError(t,@()colormeasure.colorimetry.observer(),'colormeasure:Colorimetry:ObserverData');
verifyError(t,@()colormeasure.colorimetry.observer(),'colormeasure:Colorimetry:ObserverData');
end

function clearObserver
clear colormeasure.colorimetry.observer colormeasure.root
end

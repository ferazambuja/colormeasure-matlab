function session = demoSession(model,mode,io,folder)
%DEMOSESSION Interactive, two-reading batch, or restorable 12-reading gallery.
% Services and destination are internal seams for disconnected failure tests.
if nargin<2, mode='interactive'; end
mode = validatestring(mode,{'interactive','batch','gallery'});
[key,~] = colormeasure.drivers.cr.modelInfo(model);
colormeasure.session.assertSessionCompatible();
if nargin<3, io = colormeasure.session.services(); end
if nargin<4, folder = fullfile(tempdir,'colormeasure',key); end
if ~isfolder(folder), mkdir(folder); end
adapter = colormeasure.drivers.cr.demoAdapter(key,mode);
fprintf('SYNTHETIC DEMO: no instrument connection, calibration, or measured reference.\n');
session = colormeasure.session.runDemo(adapter,mode,io,folder, ...
    struct('reading','CR:DemoMeasurement','finish','CR:DemoPersistence','retained','CR:DemoBatchRetained'));
end

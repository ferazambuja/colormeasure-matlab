% TESTLABINSTRUMENT Guided feedback check of one connected instrument.
% Open this file in MATLAB and select Run. A passed check reopens the app.
% No results are uploaded automatically.
% Fernando Voltolini de Azambuja, 2026.
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
[labInstrumentReport, labInstrumentSession] = colormeasure.checkInstrument();
if isfield(labInstrumentReport,'status') && strcmp(labInstrumentReport.status,'passed')
    labInstrumentSession.show();
    fprintf('Check complete. The app is open; select New batch for your own measurements.\n');
end

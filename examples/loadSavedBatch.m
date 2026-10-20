% LOADSAVEDBATCH Import a normal batch MAT into your own MATLAB workspace.
% Works without opening the UI or connecting an instrument. Keep raw records.
% Fernando Voltolini de Azambuja, 2026.
[file, folder] = uigetfile('measurements.mat', 'Choose a saved measurement batch');
if ~isequal(file,0)
    savedBatch = load(fullfile(folder,file),'measurements','batchInfo');
    assert(isfield(savedBatch,'measurements') && isfield(savedBatch,'batchInfo'), ...
        'Measurement:BatchFile','Choose measurements.mat, not diagnostic.mat or another MAT file.');
    measurements = savedBatch.measurements;
    batchInfo = savedBatch.batchInfo;
    % One row per reading. XYZ and units remain in the original records.
    if isempty(measurements)
        sampleNames = strings(0,1);
        completedAtUTC = strings(0,1);
        XYZ = zeros(0,3);
    else
        sampleNames = string({measurements.name}).';
        completedAtUTC = string({measurements.completedAtUTC}).';
        XYZ = vertcat(measurements.XYZ);
    end
    readingSummary = table(sampleNames,completedAtUTC,XYZ);
    disp(readingSummary);
    fprintf('%d readings loaded. Original fields remain in measurements and batchInfo.\n',numel(measurements));
end

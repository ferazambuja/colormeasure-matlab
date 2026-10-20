function saveMat(measurements, folder, batchInfo)
% SAVEMAT Stage a complete ordinary-struct batch before replacing its snapshot.
%   Staging reduces partial-write exposure; it is not a durability guarantee.
%   Fernando Voltolini de Azambuja, 2026.
filename = fullfile(folder, 'measurements.mat');
try
    colormeasure.session.saveMatFile(filename, ...
        struct('measurements',measurements,'batchInfo',batchInfo),true);
catch err
    wrapped = MException('Measurement:MatSaveFailed', 'MAT save failed: %s', err.message);
    throw(addCause(wrapped, err));
end
end

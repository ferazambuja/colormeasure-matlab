function process = startWorkerProcess(builder,folder,temporary)
%STARTWORKERPROCESS Configure and start a worker; remove its folder on failure.
% The caller learns a worker's temporary folder only from a started worker,
% so failed setup or startup removes the folder here and keeps the error. A
% started worker leaves the folder to the caller, which removes it later.
% BUILDER is a java.lang.ProcessBuilder, or a stand-in with the same calls.
% Fernando Voltolini de Azambuja, 2026.
try
    if ~isempty(temporary)
        environment = builder.environment();
        for variable = {'TMPDIR','TMP','TEMP'}, environment.put(variable{1},temporary); end
    end
    builder.redirectErrorStream(true);
    builder.redirectOutput(java.io.File(fullfile(folder,'matlab.log')));
    process = builder.start();
catch failure
    if ~isempty(temporary) && isfolder(temporary)
        [removed,message] = rmdir(temporary,'s');
        if ~removed
            warning('measurement:TestTempCleanup', ...
                'Cannot remove worker temporary folder %s: %s',temporary,message);
        end
    end
    rethrow(failure);
end
end

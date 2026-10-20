function problems=finishWorkers(processes,temporaries,cancellationFile)
%FINISHWORKERS Release every worker even when another worker cannot stop.
% Retain a live worker's temporary files. Report cleanup failures after all
% workers have been visited so one failure cannot skip the remaining workers.
% Each report names the worker's process and retained folder, so it can be
% stopped and removed by hand. PROBLEMS returns the reported lines.
% Fernando Voltolini de Azambuja, 2026.
problems={};
if nargin >= 3
    try
        if ~isfile(cancellationFile) && any(cellfun(@(p)~isempty(p) && p.isAlive(),processes))
            colormeasuretest.writeText(cancellationFile,'Finish the current test and stop.');
            started=tic;
            while any(cellfun(@(p)~isempty(p) && p.isAlive(),processes)) && toc(started)<30
                pause(0.1);
            end
        end
    catch failure
        problems{end+1}=sprintf('Cannot request cooperative worker cleanup: %s',failure.message);
    end
end
for k=1:numel(processes)
    stopped=true;
    try
        if ~isempty(processes{k}),stopped=stopIfRunning(processes{k});end
        if ~stopped
            problems{end+1}=sprintf('%s is still running%s.', ...
                workerName(k,processes{k}),retained(temporaries{k})); %#ok<AGROW>
        end
    catch failure
        stopped=false;
        problems{end+1}=sprintf('Cannot stop %s%s: %s', ...
            lower(workerName(k,processes{k})),retained(temporaries{k}),failure.message); %#ok<AGROW>
    end
    if stopped && ~isempty(temporaries{k}) && isfolder(temporaries{k})
        try
            [removed,message]=rmdir(temporaries{k},'s');
            if ~removed
                problems{end+1}=sprintf('Cannot remove worker %d temporary folder %s: %s', ...
                    k,temporaries{k},message); %#ok<AGROW>
            end
        catch failure
            problems{end+1}=sprintf('Cannot remove worker %d temporary folder %s: %s', ...
                k,temporaries{k},failure.message); %#ok<AGROW>
        end
    end
end
if ~isempty(problems)
    warning('measurement:TestWorkerCleanup','%s',strjoin(problems,newline));
end
end

function name=workerName(k,process)
name=sprintf('Worker %d',k);
try
    name=sprintf('Worker %d (process %d)',k,process.pid());
catch
    % Without a process identifier, the worker number still names it.
end
end

function text=retained(temporary)
text='';
if ~isempty(temporary),text=sprintf('; temporary files retained in %s',temporary);end
end

function stopped=stopIfRunning(process)
if process.isAlive()
    process.destroy();
    if ~process.waitFor(2,java.util.concurrent.TimeUnit.SECONDS)
        process.destroyForcibly();
        process.waitFor(2,java.util.concurrent.TimeUnit.SECONDS);
    end
end
stopped=~process.isAlive();
end

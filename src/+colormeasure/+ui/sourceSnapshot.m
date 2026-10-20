function snapshot=sourceSnapshot(folder)
%SOURCESNAPSHOT Bind a window to its exact presentation and runtime source.
% Checked only on window restoration, never in the measurement loop. UI-only
% changes can rebuild controls. Runtime changes require a new MATLAB process.
% Fernando Voltolini de Azambuja, 2026.
if nargin<1,folder=fileparts(fileparts(mfilename('fullpath')));end
files=dir(fullfile(folder,'**','*.m'));
paths=sort(string(fullfile({files.folder},{files.name})));
snapshot=struct('presentation',{{}},'runtime',{{}});
for n=1:numel(paths)
    record={char(paths(n)),fileread(paths(n))};
    group='runtime';
    if startsWith(paths(n),string(fullfile(folder,'+ui'))+filesep),group='presentation';end
    snapshot.(group)(end+1,:)=record;
end
end

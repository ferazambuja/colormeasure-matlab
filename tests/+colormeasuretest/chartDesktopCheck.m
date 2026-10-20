function chartDesktopCheck(output)
% CHARTDESKTOPCHECK One bounded synthetic scene for native keyboard checks.
% Run in a fresh owned MATLAB process. It records readbacks, never sets a
% control value after opening. All physical serial entry points are blocked.
assert(~isfolder(output),'UI:DesktopOutput','Choose a new check-output folder.');
mkdir(output);guards=fullfile(output,'hardware-guards');mkdir(guards);
for name=colormeasuretest.serialGuardNames()
    colormeasuretest.writeText(fullfile(guards,[name{1} '.m']),sprintf([ ...
        'function varargout = %s(varargin)\n' ...
        'error(''measurement:HardwareForbidden'',''Synthetic UI checks cannot call %s.'');\nend\n'],name{1},name{1}));
end
addpath(guards);guardCleanup=onCleanup(@()rmpath(guards));
for name=colormeasuretest.serialGuardNames(),assert(startsWith(which(name{1}),guards));end
folder=fullfile(output,'batch');mkdir(folder);
s=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250','interactive'), ...
    folder,colormeasure.ui.services());
cleanup=onCleanup(@()delete(s));
s.startChart(colormeasure.chart.definition('sg'));s.show();f=s.window;
f.Name='Guided chart SG — SYNTHETIC UI CHECK';
f.WindowState='normal';f.Position=[40 40 960 750];f.SizeChangedFcn(f,[]);
timeline={};last='';started=tic;
fprintf('NATIVE_CHART_READY: dedicated synthetic Session; serial APIs blocked.\n');
while isgraphics(f)&&strcmp(f.Visible,'on')&&toc(started)<300
    c=s.chart;notes=findobj(f,'Tag','SampleNotes');readings=s.measurements;
    names=cell(1,numel(readings));
    for index=1:numel(readings),names{index}=readings(index).name;end
    state=struct('seconds',toc(started),'currentCell',c.currentCell, ...
        'coverage',c.coverage,'orientation',c.orientation,'paused',c.paused, ...
        'unsaved',c.unsaved,'names',{names},'notes',s.notes, ...
        'notesEditor',{notes.Value},'status',s.status);
    signature=jsonencode(rmfield(state,'seconds'));
    if ~strcmp(signature,last),timeline{end+1}=state;last=signature;end %#ok<AGROW>
    pause(.1);
end
chart=s.chart;measurements=s.measurements;files=s.files;
save(fullfile(output,'state.mat'),'timeline','chart','measurements','files');
colormeasuretest.writeText(fullfile(output,'state.json'),jsonencode(timeline));
fprintf('NATIVE_CHART_CLOSED: %d readings, coverage %d, readback retained.\n',numel(measurements),chart.coverage);
end

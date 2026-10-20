function uiReloadChecks(folder)
%UIRELOADCHECKS Source-edit regressions in a disposable child installation.
% The test runner supplies a private source copy and blocks serial APIs.
root=colormeasure.root();set(groot,'DefaultFigureVisible','off');
ui=fullfile(root,'src','+colormeasure','+ui','Window.m');before=fileread(ui);cleanup=onCleanup(@()write(ui,before));
core=fullfile(root,'src','+colormeasure','+session','Session.m');coreBefore=fileread(core);cleanupCore=onCleanup(@()write(core,coreBefore));
reports=struct('name',{},'passed',{});
io=colormeasure.ui.services();destination=fullfile(folder,'reload-data');if ~isfolder(destination),mkdir(destination);end
io.chooseFolder=@(~)destination;
adapter=colormeasure.drivers.cr.demoAdapter('CR250');adapter.preparation.required=true;
preparationCalls=0;io.createView=@(session)colormeasure.ui.Window(session,@acknowledgePreparation);
s=colormeasure.ui.launchSession(adapter,io);release=onCleanup(@()delete(s));
colormeasuretest.click(findall(s.window,'Tag','MeasureButton'));assert(isscalar(s.measurements));saved=s.measurements;files=s.files;window=s.window;
field=findall(window,'Tag','SampleName');field.String='Uncommitted sample';notesField=findall(window,'Tag','SampleNotes');notesField.Value={'Uncommitted notes'};
after=strrep(before,'obj.Session = session;',sprintf('unused=@()[]; %%#ok<NASGU>\n            obj.Session = session;'));
write(ui,after);rehash;lastwarn('');s.show();[message,~]=lastwarn;assert(isempty(message),message);
check('UI source edit reconstructs current callbacks',~isequal(s.window,window)&&~isgraphics(window));
check('Readings and save destination retained',isequaln(s.measurements,saved)&&isequal(s.files,files));
check('Sample draft retained',strcmp(findall(s.window,'Tag','SampleName').String,'Uncommitted sample')&&isequal(findall(s.window,'Tag','SampleNotes').Value,{'Uncommitted notes'}));
check('Current Label/Text rendering warning free',isa(findall(s.window,'Tag','BatchDestination'),'matlab.ui.control.Label')&&isempty(message));
colormeasuretest.click(findall(s.window,'Tag','MeasureButton'));
check('Restored Measure callback works once',numel(s.measurements)==2&&strcmp(s.measurements(end).name,'Uncommitted sample'));
check('Preparation acknowledgment is retained without another prompt',preparationCalls==1);
close(s.window);check('Restored close hides without deleting readings',strcmp(s.window.Visible,'off')&&numel(s.measurements)==2);s.show();
write(core,[coreBefore newline '% Private runtime-change probe.']);rehash;
try
    s.show();error('Probe:MissingRefusal','Runtime change was accepted');
catch problem
    check('Runtime change refuses restoration',strcmp(problem.identifier,'Measurement:ViewRuntimeChanged'));
end
check('Runtime refusal retains readings',numel(s.measurements)==2);delete(s.window);
try
    s.show();error('Probe:MissingRefusal','Deleted figure bypassed runtime guard');
catch problem
    check('Deleting figure cannot bypass runtime refusal',strcmp(problem.identifier,'Measurement:ViewRuntimeChanged'));
end
write(core,coreBefore);rehash;s.show();
% An open editor keeps its draft: a presentation change cannot rebuild over it.
colormeasuretest.click(findall(s.window,'Tag','InstrumentSettingsButton'));
editor=findall(groot,'Tag','InstrumentSettingsWindow');assert(isscalar(editor));editedWindow=s.window;
draftSource=fileread(ui);write(ui,[draftSource newline '% Changed while an editor is open.']);rehash;
try
    s.show();error('Probe:MissingRefusal','Presentation was rebuilt over an open editor');
catch problem
    check('Open editor refuses reconstruction',strcmp(problem.identifier,'Measurement:ViewRefreshDraft')&& ...
        isgraphics(editor)&&isequal(s.window,editedWindow)&&numel(s.measurements)==2);
end
editor.CloseRequestFcn(editor,[]);s.show();
check('Closing the editor allows reconstruction',~isgraphics(editor)&&~isequal(s.window,editedWindow)&& ...
    numel(s.measurements)==2);
% A changed presentation must not use the narrow lost-owner picker exception.
pickerIO=colormeasure.ui.services();pickerIO.chooseFolder=@changedPicker;
picker=colormeasure.session.Session(colormeasure.drivers.cr.demoAdapter('CR250'),destination,pickerIO);
pickerRelease=onCleanup(@()delete(picker));picker.show();pickerWindow=picker.window;
pickerSource=fileread(ui);pickerRejected=false;
picker.saveElsewhere();
check('Source change during folder selection refuses reconstruction',pickerRejected);
check('Rejected picker reconstruction retains its busy phase until return',~picker.busy&&isempty(picker.measurements));
check('Picker source refusal adds no reading or save destination',isempty(picker.measurements)&&strcmp(picker.files.folder,''));
write(ui,pickerSource);rehash;
write(fullfile(folder,'reload-checks.json'),jsonencode(reports));fprintf('PRESENTATION_RELOAD_CHECKS=%d passed\n',numel(reports));
    function result=changedPicker(~)
        delete(pickerWindow);write(ui,[pickerSource newline '% Changed while choosing a folder.']);rehash;
        try
            picker.show();error('Probe:MissingRefusal','Changed presentation was rebuilt inside chooser');
        catch problem
            pickerRejected=strcmp(problem.identifier,'Measurement:ViewRefreshBusy')&& ...
                picker.busy&&strcmp(picker.activity,'Choosing save folder');
        end
        result='';
    end
    function accepted=acknowledgePreparation(~,~)
        preparationCalls=preparationCalls+1;accepted=true;
    end
    function check(name,passed)
        assert(passed,name);reports(end+1)=struct('name',name,'passed',true);fprintf('PASS: %s\n',name);
    end
end
function write(path,text)
fid=fopen(path,'w');assert(fid>0);cleanup=onCleanup(@()fclose(fid));fwrite(fid,text);
end

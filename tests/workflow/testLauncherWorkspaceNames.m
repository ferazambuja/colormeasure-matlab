function tests=testLauncherWorkspaceNames
% The launchers publish their session under the name the adapter declares
% (session.workspaceName), and the bundled adapters keep the documented
% naming convention, so a wrapper cannot drift from its adapter. Covered
% through a stubbed shared launcher: every measurement launcher, every
% interactive demo launcher, and the generic app and demo selectors. Batch
% and gallery demo modes populate a session before returning, so they are not
% driven through the stub. The CR and CS-2000 names are pinned on their demo
% adapters here; PR-655 keeps its literals in pr/demoSession, pinned by
% testPR655Demo and testMultiDeviceWorkflow. No window opens and no port is
% enumerated.
tests=functiontests(localfunctions);
end

function setup(t)
previousPath=path; t.addTeardown(@() path(previousPath));
colormeasuretest.setupPaths(t);
% The launcher and catalog branch on retained batches: isolate the registry.
colormeasuretest.isolateRegistry(t);
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
mkdir(fullfile(f.Folder,'+colormeasure','+ui'));
file=fopen(fullfile(f.Folder,'+colormeasure','+ui','launchSession.m'),'w');
assert(file>=0); cleanup=onCleanup(@() fclose(file));
fprintf(file,['function s=launchSession(a,varargin)\n' ...
    's=struct(''key'',a.key,''workspaceName'',a.workspaceName,''configuration'',a.configuration);\nend\n']);
clear cleanup
t.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(f.Folder));
clear colormeasure.ui.launchSession
t.addTeardown(@clearLaunch);
end

function testMeasurementLaunchersPublishTheAdapterName(t)
launchers={@colormeasure.drivers.pr.measurePR655,'colorMeasurePR655Session'; ...
    @colormeasure.drivers.cs2000.measureCS2000,'colorMeasureCS2000Session'; ...
    @colormeasure.drivers.cr.measureCR100,'colorMeasureCR100Session'; ...
    @colormeasure.drivers.cr.measureCR250,'colorMeasureCR250Session'; ...
    @colormeasure.drivers.cr.measureCR300,'colorMeasureCR300Session'};
for k=1:size(launchers,1)
    launch=launchers{k,1}; name=launchers{k,2}; colormeasuretest.preserveWorkspace(t,name);
    session=launch(); verifyEqual(t,session.workspaceName,name,func2str(launch));
    launch(); verifyEqual(t,evalin('base',name),session,func2str(launch));
end
end

function testInteractiveDemoLaunchersPublishTheAdapterName(t)
launchers={@colormeasure.drivers.pr.demoPR655,'colorMeasurePR655DemoSession'; ...
    @colormeasure.drivers.cs2000.demoCS2000,'colorMeasureCS2000DemoSession'; ...
    @colormeasure.drivers.cr.demoCR100,'colorMeasureCR100DemoSession'; ...
    @colormeasure.drivers.cr.demoCR250,'colorMeasureCR250DemoSession'; ...
    @colormeasure.drivers.cr.demoCR300,'colorMeasureCR300DemoSession'};
for k=1:size(launchers,1)
    launch=launchers{k,1}; name=launchers{k,2}; colormeasuretest.preserveWorkspace(t,name);
    session=launch('interactive'); verifyEqual(t,session.workspaceName,name,func2str(launch));
    launch('interactive'); verifyEqual(t,evalin('base',name),session,func2str(launch));
end
end

function testGenericSelectorsPublishTheAdapterName(t)
for model={'PR655','CR250','CS2000'}
    name=['colorMeasure' model{1} 'Session']; colormeasuretest.preserveWorkspace(t,name);
    session=colormeasure.app(model{1}); verifyEqual(t,session.workspaceName,name,model{1});
    colormeasure.app(model{1}); verifyEqual(t,evalin('base',name),session,model{1});
    demoName=['colorMeasure' model{1} 'DemoSession']; colormeasuretest.preserveWorkspace(t,demoName);
    session=colormeasure.demo(model{1},'interactive'); verifyEqual(t,session.workspaceName,demoName,model{1});
    colormeasure.demo(model{1},'interactive'); verifyEqual(t,evalin('base',demoName),session,model{1});
end
end

function testBundledAdaptersKeepTheDocumentedConvention(t)
catalog=colormeasure.ui.deviceCatalog();
for k=1:numel(catalog)
    model=catalog(k).model;
    verifyEqual(t,catalog(k).factory().workspaceName,['colorMeasure' model 'Session'],model);
end
for model={'CR100','CR250','CR300'}
    verifyEqual(t,colormeasure.drivers.cr.demoAdapter(model{1},'interactive').workspaceName,['colorMeasure' model{1} 'DemoSession']);
    verifyEqual(t,colormeasure.drivers.cr.demoAdapter(model{1},'batch').workspaceName,['colorMeasure' model{1} 'DemoBatch']);
    verifyEqual(t,colormeasure.drivers.cr.demoAdapter(model{1},'gallery').workspaceName,['colorMeasure' model{1} 'DemoGallery']);
end
verifyEqual(t,colormeasure.drivers.cs2000.demoAdapter('interactive').workspaceName,'colorMeasureCS2000DemoSession');
verifyEqual(t,colormeasure.drivers.cs2000.demoAdapter('batch').workspaceName,'colorMeasureCS2000DemoBatch');
verifyEqual(t,colormeasure.drivers.cs2000.demoAdapter('gallery').workspaceName,'colorMeasureCS2000DemoGallery');
end

function clearLaunch
clear colormeasure.ui.launchSession
end

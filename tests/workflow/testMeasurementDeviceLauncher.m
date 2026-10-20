function tests = testMeasurementDeviceLauncher
% Device selection routes to adapters without connecting or acquiring.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end

function setup(t)
% The launcher restores a retained batch by model, so the process registry
% is isolated: a batch another suite left behind must not change the branch.
colormeasuretest.isolateRegistry(t);
end

function testModelAliasesRouteToTheirFamilies(t)
io = struct('launchSession', @(adapter,~) adapter, ...
    'chooseDevice', @(~) error('Test:UnexpectedDialog','No chooser for an explicit model.'));
[adapter, name] = colormeasure.ui.launchDevice('PR-670', io);
verifyEqual(t, adapter.key, 'PR655'); verifyEqual(t, name, 'colorMeasurePR655Session');
assumeTrue(t, ~isempty(which('colormeasure.drivers.cs2000.uiAdapter')), 'The CS-2000 family is not installed.');
[adapter, name] = colormeasure.ui.launchDevice('CS-2000A', io);
verifyEqual(t, adapter.key, 'CS2000'); verifyEqual(t, name, 'colorMeasureCS2000Session');
end


function testPRRoutesThroughOrdinaryLauncherWithoutConnecting(t)
io = struct('launchSession', @(adapter,~) adapter, ...
    'chooseDevice', @(~) error('Test:UnexpectedDialog','No chooser for an explicit model.'));
[adapter, name] = colormeasure.ui.launchDevice('PR-655', io);
verifyEqual(t, adapter.key, 'PR655');
verifyEqual(t, name, 'colorMeasurePR655Session');
end

function testCancelHasNoSessionOrFolderPrompt(t)
io = struct('chooseDevice', @(~) 0, ...
    'launchSession', @(~,~) error('Test:UnexpectedLaunch','Cancel must not launch.'));
[session, name] = colormeasure.ui.launchDevice('', io);
verifyEmpty(t, session); verifyEmpty(t, name);
end

function testUnknownModelDoesNotLaunch(t)
io = struct('launchSession', @(~,~) error('Test:UnexpectedLaunch','Unknown model must not launch.'));
verifyError(t,@() colormeasure.ui.launchDevice('Unknown',io),'Measurement:Device');
verifyError(t,@() colormeasure.ui.launchDevice([1 2],io),'Measurement:Device');
end

function testChooserOnlyOffersInstalledModels(t)
seen = {};
io = struct('chooseDevice', @choose, 'launchSession', @(adapter,~) adapter);
adapter = colormeasure.ui.launchDevice('',io);
verifyEqual(t, adapter.key, 'PR655');
verifyTrue(t, any(contains(seen,'PR-655')));
verifyEqual(t, any(contains(seen,'CR-100')), ~isempty(which('colormeasure.drivers.cr.uiAdapter')));
verifyEqual(t, any(contains(seen,'CS-2000')), ~isempty(which('colormeasure.drivers.cs2000.uiAdapter')));
    function index = choose(labels)
        seen = labels; index = 1;
    end
end

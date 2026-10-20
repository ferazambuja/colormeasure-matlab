function preserveWorkspace(testCase,name)
%PRESERVEWORKSPACE Restore or clear a base-workspace variable at teardown.
if evalin('base',sprintf('exist(''%s'',''var'')',name))
    previous = evalin('base',name); testCase.addTeardown(@() assignin('base',name,previous));
else
    testCase.addTeardown(@() evalin('base',['clear ' name]));
end
end

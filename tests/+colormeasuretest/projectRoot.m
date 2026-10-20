function root = projectRoot()
%PROJECTROOT Resolve this test installation independently of the current folder.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

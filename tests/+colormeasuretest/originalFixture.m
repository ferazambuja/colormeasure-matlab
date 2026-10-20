function folder = originalFixture(family, name)
%ORIGINALFIXTURE Folder of a stub the original-school comparisons put on the path.
%   folder = colormeasuretest.originalFixture('cs2000', 'original-pause')
%   The stubs shadow MATLAB names (pause, serial, serialport) while the
%   unchanged school driver runs, so they live outside every discovered test
%   folder: suite discovery changes into each folder it scans, and a shadow
%   there makes MATLAB warn at startup that the name hides a builtin. Only
%   the comparison tests add a fixture folder to the path, for the school
%   driver's calls, and they remove it again.
folder = fullfile(colormeasuretest.projectRoot(), 'tests', 'original-fixtures', family, name);
end

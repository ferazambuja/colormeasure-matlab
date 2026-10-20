function root = parseSchoolRoot(varargin)
%PARSESCHOOLROOT Normalize an explicitly selected baseline before worker launch.
parser = inputParser;
parser.addParameter('SchoolRoot','');
parser.parse(varargin{:});
root = parser.Results.SchoolRoot;
assert((ischar(root) && (isrow(root) || isempty(root))) || ...
    (isstring(root) && isscalar(root) && ~ismissing(root)), ...
    'measurement:SchoolRoot','SchoolRoot must be one existing folder.');
root = char(root);
if isempty(root), return; end
folder = java.io.File(root);
if ~folder.isAbsolute(), folder = java.io.File(fullfile(pwd,root)); end
root = char(folder.getCanonicalPath());
assert(isfolder(root),'measurement:SchoolRoot','SchoolRoot does not exist: %s',root);
end

function root = schoolRoot()
%SCHOOLROOT Explicit reference selected for this isolated worker.
root = getenv('COLORMEASURE_TEST_SCHOOL_ROOT');
assert(~isempty(root) && isfolder(root),'measurement:SchoolRoot', ...
    'Original comparisons require an explicit existing SchoolRoot.');
end

function indices = shardIndices(count,shard)
%SHARDINDICES Suite positions one concurrent worker runs.
% Worker k of n runs every n-th test starting at k, so long files are spread
% across workers. Together the workers cover 1:count exactly once.
% Fernando Voltolini de Azambuja, 2026.
assert(isnumeric(count) && isscalar(count) && count >= 0 && count == fix(count) && ...
    isnumeric(shard) && numel(shard) == 2 && all(shard == fix(shard)) && ...
    shard(2) >= 1 && shard(1) >= 1 && shard(1) <= shard(2), ...
    'measurement:TestShards','Choose worker k of n, with 1 <= k <= n.');
indices = shard(1):shard(2):count;
end

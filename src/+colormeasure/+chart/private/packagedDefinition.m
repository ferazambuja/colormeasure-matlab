function value = packagedDefinition(kind)
%PACKAGEDDEFINITION Authenticate bundled chart data before interpreting it.
%   The generated manifest pins exact UTF-8 bytes, source mappings and tooling.
%   Definitions and their manifest are small bounded inputs. No runtime source
%   checkout, Python, network access or mutable catalog cache is involved.
manifestDigest = '15384ee4f01c00071da3d7f9a0a087c4cf9274fac7a8dac2ad52a11d2a9d229d'; % Updated by generateDefinitions.py.
root=colormeasure.root();
manifest=authenticatedJson(fullfile(root,'resources','provenance','chart-source.json'),manifestDigest,65536);
if ~isstruct(manifest)||~isscalar(manifest)||~all(isfield(manifest,{'format','version','files'}))|| ...
        ~strcmp(manifest.format,'chart-definitions')||~isequal(manifest.version,1)|| ...
        ~isstruct(manifest.files)||numel(manifest.files)~=2
    error('colormeasure:Chart:Resource','The bundled chart manifest has an unsupported structure.');
end
relative=['resources/charts/' kind '.json'];
index=find(strcmp({manifest.files.path},relative));
if numel(index)~=1
    error('colormeasure:Chart:Resource','The bundled chart manifest does not uniquely identify %s.',kind);
end
value=authenticatedJson(fullfile(root,'resources','charts',[kind '.json']),manifest.files(index).sha256,262144);
value.digest=manifest.files(index).sha256;
end

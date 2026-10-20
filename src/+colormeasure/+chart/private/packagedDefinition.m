function value = packagedDefinition(kind)
%PACKAGEDDEFINITION Authenticate bundled chart data before interpreting it.
%   The manifest pins exact UTF-8 bytes and source mappings.
%   Definitions and their manifest are small bounded inputs. No runtime source
%   checkout, Python, network access or mutable catalog cache is involved.
manifestDigest = 'facb34daaa9de277bbf14f435e66b8b4360475b97ad0b99017f7c5d10944415d'; % Pins the committed resource manifest.
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

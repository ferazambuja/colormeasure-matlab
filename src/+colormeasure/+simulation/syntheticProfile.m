function profile = syntheticProfile(index, wavelengths, intent)
% SYNTHETICPROFILE Sample an illustrative demo shape on the supplied grid.
%   Returns spectrum, name, description and the wrapped profile index (1:12).
%   Includes repeatable +/-0.5% brightness jitter using a private random stream.
%   This is illustrative variation, not a model of instrument noise. This
%   function does not assign units, calculate XYZ or access hardware.
%   Optional guided intent is one struct with cell_index (1:140) and attempt
%   (a positive integer at most 2^53-1). Its cell selects the fixed base shape;
%   its attempt selects seeded brightness variation. An empty struct keeps the
%   ordinary reading-index sequence and its exact existing numerical values.
%   Fernando Voltolini de Azambuja, 2026.
if nargin<3, intent=struct([]); end
association=guidedIntent(intent);
validateattributes(index, {'numeric'}, {'scalar','real','finite','integer','positive'});
validateattributes(wavelengths, {'numeric'}, {'vector','real','finite','positive','nonempty'});
wavelengths = double(wavelengths(:));
if any(diff(wavelengths) <= 0)
    error('Measurement:DemoGrid', 'Demo wavelengths must increase.');
end
profiles = colormeasure.simulation.syntheticProfiles();
readingIndex = index;
if isempty(association)
    seed=mod(readingIndex,2^32);
else
    index=association.cell_index;
    % Reduce before multiplying so every seed computation remains exact.
    seed=mod(index+140*mod(association.attempt-1,2^32),2^32);
end
index = mod(index-1, numel(profiles))+1;
source = profiles(index);
spectrum = zeros(size(wavelengths));
for componentIndex = 1:size(source.components,1)
    component = source.components(componentIndex,:);
    spectrum = spectrum + component(3) * ...
        exp(-0.5*((wavelengths-component(1))/component(2)).^2);
end
stream = RandStream('mt19937ar','Seed',seed);
gain = 1 + .005 * (2*rand(stream)-1);
spectrum = spectrum * gain;
profile = struct('spectrum',spectrum,'name',source.name, ...
    'description',source.description,'index',index,'association',association, ...
    'seed',seed,'gain',gain);
end

function value=guidedIntent(value)
if ~isstruct(value)
    error('Measurement:DemoIntent','Demo sample intent must be an empty struct or one guided cell and attempt.');
end
if isempty(value), value=struct([]); return; end
if ~isscalar(value)||~isequal(sort(fieldnames(value)),{'attempt';'cell_index'})|| ...
        ~positiveInteger(value.cell_index)||value.cell_index>140||~positiveInteger(value.attempt)
    error('Measurement:DemoIntent','Guided demo intent needs cell_index in 1:140 and a positive whole attempt at most 2^53-1.');
end
value=struct('cell_index',double(value.cell_index),'attempt',double(value.attempt));
end

function yes=positiveInteger(value)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&& ...
    value>=1&&value<=flintmax-1&&value==fix(value);
end

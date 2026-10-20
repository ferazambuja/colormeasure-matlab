function validateSettingsCatalog(controls, identifier)
%VALIDATESETTINGSCATALOG Refuse settings controls the settings editor cannot render.
%   One rule set for constructed controls, adapter catalogs and settings
%   readback: a unique variable-name id, a text label, type 'number' or
%   'choice', logical scalar availability, finite-or-NaN numeric limits with
%   minimum no greater than maximum, choices with a value and a text label,
%   and help with text meaning, whenToUse, tradeoff and normal plus a text
%   source. Errors carry the caller's identifier and name the failing rule.
%   Fernando Voltolini de Azambuja, 2026.
if ~isstruct(controls)
    error(identifier,'Settings controls must be a struct array.');
end
required = {'id','label','type','choices','minimum','maximum','available','help'};
if ~isempty(controls) && ~all(isfield(controls,required))
    error(identifier,'Settings controls need the fields %s.',strjoin(required,', '));
end
ids = cell(1,numel(controls));
for index = 1:numel(controls)
    reason = problem(controls(index));
    if ~isempty(reason)
        error(identifier,'Settings control at position %d: %s',index,reason);
    end
    ids{index} = char(controls(index).id);
end
if numel(unique(ids)) ~= numel(ids)
    error(identifier,'Settings control IDs must be unique.');
end
end

function reason = problem(control)
helpFields = {'meaning','whenToUse','tradeoff','normal','source'};
reason = '';
if ~colormeasure.session.isText(control.id) || ~isvarname(char(control.id))
    reason = 'the id must be a valid variable name.';
elseif ~colormeasure.session.isText(control.label)
    reason = 'the label must be text.';
elseif ~colormeasure.session.isText(control.type) || ~any(strcmp(control.type,{'number','choice'}))
    reason = 'the type must be number or choice.';
elseif ~islogical(control.available) || ~isscalar(control.available)
    reason = 'availability must be a logical scalar.';
elseif ~isLimit(control.minimum) || ~isLimit(control.maximum) || control.minimum > control.maximum
    reason = 'limits must be finite or NaN numeric scalars, with minimum no greater than maximum.';
elseif ~isstruct(control.choices) || ...
        ~(isempty(control.choices) || all(isfield(control.choices,{'value','label'}))) || ...
        ~all(arrayfun(@(choice) colormeasure.session.isText(choice.label),control.choices(:)))
    reason = 'choices must be structs with a value and a text label.';
elseif ~isstruct(control.help) || ~isscalar(control.help) || ~all(isfield(control.help,helpFields)) || ...
        ~all(cellfun(@(field) colormeasure.session.isText(control.help.(field)),helpFields(1:4))) || ...
        ~(colormeasure.session.isText(control.help.source) || isstring(control.help.source) || ...
        iscellstr(control.help.source))
    reason = 'help needs text meaning, whenToUse, tradeoff and normal, and a text source.';
end
end

function value = isLimit(candidate)
value = isnumeric(candidate) && isreal(candidate) && isscalar(candidate) && ...
    (isfinite(candidate) || isnan(candidate));
end

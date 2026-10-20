function yes = isSchemaOne(value)
%ISSCHEMAONE The current JSON schema marker is the number 1, never a boolean.
% MATLAB isequal(true,1) is true; JSON boolean and numeric values remain
% different contract types. All current operation boundaries share this rule.
% Fernando Voltolini de Azambuja, 2026.
yes = isnumeric(value) && isreal(value) && isscalar(value) && value == 1;
end

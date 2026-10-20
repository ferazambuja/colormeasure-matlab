function modes=catalogModes()
%CATALOGMODES Shared adapter lifecycle identities for the instrument catalog.
% Model identifiers may name custom instruments. A mode describes a real
% measurement or one of the bundled demonstration workflows, not an optical
% acquisition mode. Catalog consumers use this same vocabulary.
% Fernando Voltolini de Azambuja, 2026.
modes={'measure','interactive','gallery','batch'};
end

function requested = automaticSettings(overrides)
% AUTOMATICSETTINGS Normal acquisition policy, with explicit overrides.
%   SE0 adaptive exposure, SN1 one cycle, SS1 automatic synchronization.
%   Optical calibration, aperture, sensitivity, dark mode, units and observer
%   remain unchanged unless explicitly overridden. See docs/drivers/pr/settings.md.
%   Fernando Voltolini de Azambuja, 2026.
if ~isstruct(overrides)||~isscalar(overrides)
    error('PR655:InvalidSettings','Settings overrides must be a scalar struct.');
end
requested=struct('exposureMilliseconds',0,'cycles',1,'syncMode','auto');
names=fieldnames(overrides);
for index=1:numel(names),requested.(names{index})=overrides.(names{index});end
end

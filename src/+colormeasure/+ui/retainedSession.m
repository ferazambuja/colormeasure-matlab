function session = retainedSession(entry, mode)
%RETAINEDSESSION The registered batch a chooser entry would reopen, or [].
%   A native family's explicit catalog identity selects its measurement or
%   demo batch without deriving either from a registry key.
%   Fernando Voltolini de Azambuja, 2026.
if nargin<2,mode='measure';end
session = [];
registry = colormeasure.session.sessionRegistry('get');
for n=1:numel(registry.sessions)
    candidate=registry.sessions{n};if ~isvalid(candidate),continue;end
    identity=candidate.catalogIdentity;
    if strcmp(identity.model,entry.model)&&strcmp(identity.mode,mode)
        if ~isempty(session)
            error('Measurement:DeviceSessionAmbiguous', ...
                ['More than one retained %s batch exists for %s mode. Open the intended ' ...
                'batch directly; no batch was changed.'],entry.label,mode);
        end
        session=candidate;
    end
end
end

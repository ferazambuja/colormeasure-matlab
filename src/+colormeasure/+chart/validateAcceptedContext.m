function validateAcceptedContext(info,reading,accepted,pass)
% Rebuild observed facts through the existing chart owner. A source's new
% adapter and editable projection columns cannot reinterpret old readings.
identifier='Measurement:ChartReference';
assert(all(isfield(accepted,{'material','route','phase'}))&&strcmp(accepted.phase,'accepted')&& ...
    isfield(pass,'material'),'Measurement:ChartReference','Selected contexts must retain their original material facts.');
facts=struct('configuration',info.configuration,'settingsOverrides',struct());
colormeasure.chart.assertDirectSource(info,reading);
facts.catalogIdentity=info.catalogIdentity;
receipt=struct();if isfield(reading,'instrumentSettings')&&~isempty(reading.instrumentSettings),receipt=reading.instrumentSettings;end
facts.lastSettingsReceipt=receipt;
if isfield(receipt,'overrides'),facts.settingsOverrides=receipt.overrides;end
if isfield(receipt,'after')&&~isempty(receipt.after)
    facts.settingsSnapshot=receipt.after;facts.settingsCatalog=receipt.after.controls;
end
observed=colormeasure.chart.context(facts,reading);
assert(strcmp(accepted.route,observed.route),identifier,'Selected acquisition routes must match the original reading owner.');
keys=fieldnames(observed.material);
for n=1:numel(keys)
    key=keys{n};actual=observed.material.(key);
    for retained={accepted,pass}
        assert(isfield(retained{1}.material,key),identifier,'The selected context is missing material fact %s.',key);
        claim=retained{1}.material.(key);
        assert(isstruct(claim)&&isscalar(claim)&&all(isfield(claim,{'value','certainty','source'})),identifier, ...
            'Selected material facts need value, certainty and source.');
        if ~strcmp(actual.certainty,'unknown')
            assert(~strcmp(claim.certainty,'unknown')&&isequaln(claim.value,actual.value),identifier, ...
                'The selected context %s disagrees with its original retained reading.',key);
        elseif isequaln(retained{1},accepted)&&strcmp(actual.certainty,'unknown')&&strcmp(claim.certainty,'readback')
            error(identifier,'The selected context claims unreported readback for %s.',key);
        end
    end
end
end


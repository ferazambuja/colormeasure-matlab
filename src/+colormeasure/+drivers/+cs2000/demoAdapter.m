function adapter = demoAdapter(mode)
%DEMOADAPTER Stateful profile sequence with no serial or instrument calls.
%   Fernando Voltolini de Azambuja, 2026.
if nargin == 0, mode = 'interactive'; end
mode = validatestring(mode,{'interactive','batch','gallery'});
adapter = colormeasure.drivers.cs2000.uiAdapter();
adapter.catalog = struct('model','CS2000','mode',mode);
adapter.key = 'CS2000Demo';
adapter.workspaceName = 'colorMeasureCS2000DemoSession';
adapter.label = 'CS-2000 measurements (synthetic demo)';
if strcmp(mode,'gallery')
    adapter.key = 'CS2000DemoGallery';
    adapter.workspaceName = 'colorMeasureCS2000DemoGallery';
    adapter.label = 'CS-2000 synthetic spectrum gallery';
elseif strcmp(mode,'batch')
    adapter.key = 'CS2000DemoBatch';
    adapter.workspaceName = 'colorMeasureCS2000DemoBatch';
end
adapter.listPorts = @(~) "CS2000_SYNTHETIC_ONLY";
adapter.configuration = struct('mode',mode,'source','synthetic profiles', ...
    'wavelengths','380:1:780 nm','profileSet','colormeasure.simulation.syntheticProfiles.v1');
adapter.configurationSummary = ['Synthetic CS-grid preview (' mode '); no physical connection.'];
adapter.preparation.required = false; % Same help, without a live-operation reminder.
adapter.connect = @(~) [];
adapter.read = @read;
adapter.prepareSample = @prepareSample;
adapter.release = @(~) [];
values = struct('speedMode',2,'integrationTimeSeconds',1,'internalNDMode',2, ...
    'syncMode',0,'frequencyHz',NaN,'measurementAngleDegrees',1, ...
    'closeupLens',0,'externalNDFilter',0,'userCalibrationChannel',0);
adapter.settings = struct('catalog',colormeasure.drivers.cs2000.settingsCatalog(values,'modern'), ...
    'read',@readSettings,'apply',@applySettings);
index = 0;
sampleIntent = struct([]);
    function prepareSample(intent)
        sampleIntent=intent;
    end

    function reading = read(~)
        readingIndex = index+1;
        reading = colormeasure.drivers.cs2000.syntheticReading(readingIndex,sampleIntent);
        if isempty(sampleIntent),index=readingIndex;end
    end

    function report = readSettings(~)
        % Virtual state only: no device identity, firmware or replies invented.
        stamp = colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
        report = struct('values',values, ...
            'controls',colormeasure.drivers.cs2000.settingsCatalog(values,'modern'), ...
            'identity',struct('model','CS-2000','synthetic',true), ...
            'readAtUTC',stamp,'responses',struct(), ...
            'speedLayout','modern','synthetic',true);
    end

    function receipt = applySettings(~,overrides)
        overrides = colormeasure.drivers.cs2000.validateSettingsChanges(overrides);
        requested = struct('speedMode',2,'integrationTimeSeconds',1, ...
            'internalNDMode',2,'syncMode',0);
        names = fieldnames(overrides);
        for k=1:numel(names), requested.(names{k})=overrides.(names{k}); end
        if ismember(requested.speedMode,[0 1 3]) && ~isfield(overrides,'integrationTimeSeconds')
            requested=rmfield(requested,'integrationTimeSeconds');
        end
        if requested.speedMode==3 && ~isfield(overrides,'internalNDMode')
            requested=rmfield(requested,'internalNDMode');
        end
        before=readSettings([]);
        receipt=struct('requested',requested,'before',before,'after',before, ...
            'commands',{{}},'acknowledgements',{{}},'status','failed', ...
            'error',struct('identifier','','message',''),'synthetic',true);
        try
            [planned,target]=colormeasure.drivers.cs2000.settingsPlan(requested,before);
            values=target;
            receipt.after=readSettings([]);
            receipt.commands=cellfun(@(s)['SIMULATED: ' s],planned,'UniformOutput',false);
            receipt.acknowledgements=repmat({'Synthetic state updated; no device communication.'},size(planned));
            receipt.status='applied';
            if isempty(planned), receipt.status='unchanged'; end
        catch err
            receipt.error=struct('identifier',err.identifier,'message',err.message);
        end
    end
end

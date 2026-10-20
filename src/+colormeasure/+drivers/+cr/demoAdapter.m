function adapter = demoAdapter(model,mode)
%DEMOADAPTER Synthetic model-shaped records without serial API calls.
% Fernando Voltolini de Azambuja, 2026.
if nargin<2, mode='interactive'; end
mode = validatestring(mode,{'interactive','batch','gallery'});
[key,label] = colormeasure.drivers.cr.modelInfo(model);
adapter = colormeasure.drivers.cr.uiAdapter(key);
adapter.catalog = struct('model',key,'mode',mode);
adapter.key = [key 'Demo'];
adapter.workspaceName = ['colorMeasure' key 'DemoSession'];
if strcmp(mode,'gallery')
    adapter.key = [key 'DemoGallery'];
    adapter.workspaceName = ['colorMeasure' key 'DemoGallery'];
elseif strcmp(mode,'batch')
    adapter.key = [key 'DemoBatch'];
    adapter.workspaceName = ['colorMeasure' key 'DemoBatch'];
end
adapter.label = [label ' measurements (SYNTHETIC DEMO)'];
adapter.preparation.required = false;
adapter.configuration = struct('model',key,'mode',mode,'synthetic',true);
adapter.configurationSummary = sprintf('%s; synthetic %s; no physical connection',label,mode);
adapter.listPorts = @(~) "CR_SYNTHETIC_ONLY";
adapter.connect = @(~) [];
adapter.read = @read;
adapter.prepareSample = @prepareSample;
adapter.release = @(~) [];
state = colormeasure.drivers.cr.demoSettingsReport(key);
adapter.settings = struct('catalog',state.controls,'read',@readSettings,'apply',@applySettings);
index = 0;
sampleIntent = struct([]);
    function prepareSample(intent)
        sampleIntent=intent;
    end

    function reading = read(~)
        readingIndex = index+1;
        reading = colormeasure.drivers.cr.syntheticReading(key,readingIndex,sampleIntent);
        if isempty(sampleIntent),index=readingIndex;end
    end

    function report = readSettings(~)
        report=colormeasure.drivers.cr.demoSettingsReport(key,state.values);
    end

    function receipt = applySettings(~,overrides)
        if ~isstruct(overrides)||~isscalar(overrides)
            error('CR:SettingsArgument','Settings must be one scalar struct.');
        end
        before=readSettings([]);
        requested=struct('exposureMode',0);
        if strcmp(key,'CR100'), requested.rangeMode=0; requested.mode=0; end
        names=fieldnames(overrides);
        for k=1:numel(names)
            id=names{k}; value=overrides.(id);
            found=find(strcmp({before.controls.id},id));
            if isempty(found)||~before.controls(found).available|| ...
                    ~isnumeric(value)||~isscalar(value)||~isreal(value)||~isfinite(value)
                error('CR:SettingsArgument','Unknown, read-only or invalid setting: %s.',id);
            end
            if (strcmp(before.controls(found).type,'choice')||strcmp(id,'exposureMultiplier')) && value~=fix(value)
                error('CR:SettingsArgument','%s requires an integer.',id);
            end
            requested.(id)=double(value);
        end
        receipt=struct('requested',requested,'before',before,'after',before, ...
            'commands',{{}},'acknowledgements',{{}},'status','failed', ...
            'error',struct('identifier','','message',''),'synthetic',true);
        try
            colormeasure.drivers.cr.validateSettingsCombination(requested,before,label);
            names=fieldnames(requested); values=before.values;
            for k=1:numel(names)
                id=names{k}; value=requested.(id);
                if isfield(values,id)&&isequal(values.(id),value), continue; end
                receipt.commands{end+1}=sprintf('SIMULATED: %s = %.15g',id,value);
                if strcmp(id,'maxAutoExposureMs')
                    receipt.acknowledgements{end+1}='Synthetic acknowledgement only; no current RS readback.';
                else
                    values.(id)=value;
                    receipt.acknowledgements{end+1}='Synthetic state updated; no device communication.';
                end
            end
            state=colormeasure.drivers.cr.demoSettingsReport(key,values);
            receipt.after=readSettings([]); receipt.status='applied';
            if isempty(receipt.commands), receipt.status='unchanged'; end
        catch err
            receipt.error=struct('identifier',err.identifier,'message',err.message);
        end
    end
end

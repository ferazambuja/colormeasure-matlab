classdef DemoInstrument < handle
    % DEMOINSTRUMENT Synthetic spectra for command sessions and software tests; never opens a port.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access = private)
        Index
        DelaySeconds
        Model = 'PR-655'
        Settings
        SampleIntent = struct([])
    end
    methods
        function obj = DemoInstrument(index, delaySeconds, model)
            if nargin < 2, delaySeconds = 0.5; end
            validateattributes(index, {'numeric'}, {'scalar','real','finite','integer','positive'});
            validateattributes(delaySeconds, {'numeric'}, {'scalar','real','finite','nonnegative'});
            obj.Index = index;
            obj.DelaySeconds = delaySeconds;
            if nargin >= 3
                if ~any(strcmp(model,{'PR-655','PR-670'}))
                    error('PR655:UnsupportedModel','Demo model must be PR-655 or PR-670.');
                end
                obj.Model=char(model);
            end
            obj.Settings=colormeasure.drivers.pr.demoSettings(obj.Model);
        end
        function prepareSample(obj,intent)
            % Session owns chart intent; only this disconnected meter uses it.
            obj.SampleIntent=intent;
        end
        function reading = measure(obj)
            pause(obj.DelaySeconds);
            step=4;if strcmp(obj.Model,'PR-670'),step=2;end
            wavelengths = (380:step:780)';
            profile = colormeasure.simulation.syntheticProfile(obj.Index, wavelengths, obj.SampleIntent);
            profileIndex = profile.index;
            spectrum = profile.spectrum;
            [~, peak] = max(spectrum);
            total = colormeasure.colorimetry.spectralIntegral(spectrum, wavelengths);
            stored = colormeasure.drivers.pr.storedText();
            % Model identity agrees with the settings report. The separate
            % isSynthetic flag and sample provenance identify this simulation.
            reading = struct('lambda', wavelengths, 'radiance', spectrum, ...
                'XYZ', colormeasure.colorimetry.spectra2XYZ(spectrum, wavelengths), ...
                'xyzMethod', stored.xyzMethod, ...
                'totalRadiance', total, ...
                'deviceType', obj.Model, 'unitsCode', 0, ...
                'peakWavelength', wavelengths(peak), 'instrumentTotalRadiance', total, ...
                'integratedPhotonRadiance', NaN, 'isSynthetic', true, ...
                'syntheticProfile', profile.name, 'syntheticProfileIndex', profileIndex, ...
                'syntheticAssociation',profile.association,'syntheticSeed',profile.seed, ...
                'syntheticGain',profile.gain);
            % Guided attempts use their own identity and do not consume the
            % ordinary free-sample sequence.
            if isempty(profile.association),obj.Index=obj.Index+1;end
        end
        function report = readSettings(obj)
            report=obj.Settings;
            report.readAtUTC=colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
        end
        function receipt = applyAutomaticSettings(obj,overrides)
            if nargin<2,overrides=struct();end
            receipt=obj.applySettings(colormeasure.drivers.pr.automaticSettings(overrides));
        end
        function receipt = applySettings(obj,overrides)
            colormeasure.drivers.pr.settingsCommands(overrides,obj.Model,[]);
            receipt=colormeasure.drivers.pr.settingsReceipt(overrides);
            if isempty(fieldnames(overrides)),return;end
            receipt.before=obj.readSettings();
            try
                [commands,ids]=colormeasure.drivers.pr.settingsCommands(overrides,obj.Model,receipt.before);
                for index=1:numel(ids)
                    value=overrides.(ids{index});if isstring(value),value=char(value);end
                    obj.Settings.values.(ids{index})=value;
                    receipt.commands{end+1}=commands{index};
                    receipt.acknowledgements(end+1)=struct('command',commands{index}, ...
                        'rawReply','Synthetic acknowledgement; no device command','status','simulated');
                end
                % Simulate the protocol's unobservable shutter state faithfully.
                obj.Settings.values.shutterMode='';
                capabilities=obj.Settings.identity.syntheticCapabilities;
                capabilities.sensitivityMode=obj.Settings.values.sensitivityMode;
                obj.Settings.controls=colormeasure.drivers.pr.settingsCatalog(obj.Model,capabilities);
                receipt.after=obj.readSettings();
                if ~isempty(commands),receipt.status='applied';end
            catch problem
                receipt.status='failed';
                receipt.error=struct('identifier',problem.identifier,'message',problem.message);
            end
        end
    end
end

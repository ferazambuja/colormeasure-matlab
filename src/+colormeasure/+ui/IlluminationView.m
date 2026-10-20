classdef IlluminationView < handle
    % ILLUMINATIONVIEW Explicit, derived color views over retained readings.
    %   Applying or exporting analysis never acquires or edits a measurement.
    %   Scientific guards and calculations belong to deriveIllumination.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access = private)
        Fields
        Measurements = struct([])
        Data = struct()
        LastCount = -1
        LastNames = {}
        ReferenceValues = []
        ReferenceFile = ''
        Result = struct([])
        OnResult
        OnSelection
        Derive
    end
    methods
        function obj = IlluminationView(parent,onResult,onSelection,derive)
            if nargin<2, onResult=[]; end
            if nargin<3, onSelection=[]; end
            if nargin<4, derive=@colormeasure.analysis.deriveIllumination; end
            obj.OnResult=onResult; obj.OnSelection=onSelection; obj.Derive=derive;
            outer=uigridlayout(parent,[3 2], 'RowHeight',{'1x',28,26}, ...
                'ColumnWidth',{'1x','1x'},'Padding',[6 6 6 6],'RowSpacing',5, ...
                'ColumnSpacing',5,'Tag','IlluminationLayout');
            obj.Fields.Outer=outer;
            body=uigridlayout(outer,[14 2],'ColumnWidth',{72,'1x'}, ...
                'Padding',[2 2 2 2],'RowSpacing',4,'ColumnSpacing',4, ...
                'Scrollable','on','Tag','IlluminationControls');
            body.Layout.Row=1; body.Layout.Column=[1 2]; obj.Fields.Body=body;
            obj.dropdown('Mode','View',1,{'Chromatic adaptation','Reflectance / relight'}, ...
                {'adaptation','reflectance'},'adaptation',@(~,~) obj.modeChanged());
            obj.dropdown('Sample','Sample',2,{'Select reading'},0,0,@(~,~) obj.sampleChanged());
            whiteNames={'Select white','D50','D65','A (tungsten)'};
            obj.dropdown('SourceWhite','Source white',3,whiteNames,[0 -1 -2 -3],0,@(~,~) obj.inputsChanged());
            obj.dropdown('DestinationWhite','To white',4,whiteNames,[0 -1 -2 -3],-2,@(~,~) obj.inputsChanged());
            obj.dropdown('Reference','Reference',5,{'Select white reading'},0,0,@(~,~) obj.inputsChanged());
            obj.dropdown('Target','Relight with',6,whiteNames(2:end),[-1 -2 -3],-2,@(~,~) obj.inputsChanged(false));
            obj.Fields.SourceWhite.Tooltip='Adapting white for the measured color; choose a preset or an intentional white reading.';
            obj.Fields.DestinationWhite.Tooltip='White of the intended adapting environment.';
            obj.Fields.Reference.Tooltip='White object measured under the sample''s illumination, geometry and settings.';
            obj.Fields.Target.Tooltip=['A selected reading is treated as illuminating light. ' ...
                'A white tile spectrum includes its reflectance and is not automatically the illuminant.'];
            obj.Fields.ReferenceDataLabel=uilabel(body,'Text','White data','FontSize',10);
            obj.place(obj.Fields.ReferenceDataLabel,7,1);
            obj.Fields.LoadReference=uibutton(body,'Text','Load CSV...', ...
                'Tag','IlluminationLoadReference','ButtonPushedFcn',@(~,~) obj.chooseReference(), ...
                'Tooltip','Two numeric columns: wavelength (nm), reference reflectance (fraction; 1 = 100%).', ...
                'Interruptible','off','BusyAction','queue');
            obj.place(obj.Fields.LoadReference,7,2);
            obj.Fields.ReferenceFile=uilabel(body,'Text','No reference data loaded.', ...
                'WordWrap','on','FontSize',10,'Tag','IlluminationReferenceFile');
            obj.place(obj.Fields.ReferenceFile,8,[1 2]);
            obj.Fields.Perfect=uicheckbox(body,'Text','Assume ideal white (R = 1)', ...
                'Value',false,'FontSize',10,'Tag','IlluminationPerfectReference', ...
                'Tooltip','An explicit ideal-white assumption gives a relative spectral ratio, not calibrated reflectance.', ...
                'ValueChangedFcn',@(~,~) obj.inputsChanged(), ...
                'Interruptible','off','BusyAction','queue');
            obj.place(obj.Fields.Perfect,9,[1 2]);
            obj.Fields.Confirmed=uicheckbox(body,'Text','Reflective object; same setup', ...
                'Value',false,'FontSize',10,'Tag','IlluminationConfirmedSetup', ...
                'Tooltip','Confirm a reflective, nonfluorescent object with stable illumination, geometry, settings and numerical scale for sample and reference; not an emissive display.', ...
                'ValueChangedFcn',@(~,~) obj.inputsChanged(false), ...
                'Interruptible','off','BusyAction','queue');
            obj.place(obj.Fields.Confirmed,10,[1 2]);
            obj.Fields.Hint=uilabel(body,'Text','','WordWrap','on','FontSize',10, ...
                'Tag','IlluminationHint'); obj.place(obj.Fields.Hint,11,[1 2]);
            preview=uigridlayout(body,[1 2],'ColumnWidth',{26,'1x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',6);
            obj.place(preview,12,[1 2]);
            obj.Fields.Swatch=uilabel(preview,'Text','','BackgroundColor',[.5 .5 .5], ...
                'Tag','IlluminationSwatch');
            obj.Fields.PreviewLabel=uilabel(preview,'Text','Approximate color preview','FontSize',10, ...
                'Tooltip','Destination changes coordinates; the preview is always adapted to display D65.');
            obj.Fields.Results=uitable(body,'ColumnName',{'Derived','Value'}, ...
                'ColumnWidth',{65,'1x'},'RowName',[],'ColumnEditable',false, ...
                'Tag','IlluminationResults'); obj.place(obj.Fields.Results,13,[1 2]);
            obj.Fields.Reason=uilabel(body,'Text','Select a sample and white, then Apply.', ...
                'WordWrap','on','FontSize',10,'Tag','IlluminationReason');
            obj.place(obj.Fields.Reason,14,[1 2]);
            obj.Fields.Apply=uibutton(outer,'Text','Apply view','Enable','off', ...
                'Tag','IlluminationApply','ButtonPushedFcn',@(~,~) obj.apply(), ...
                'Tooltip','Calculate a separate view from saved readings; never start an exposure.', ...
                'Interruptible','off','BusyAction','queue'); obj.place(obj.Fields.Apply,2,1);
            obj.Fields.Measured=uibutton(outer,'Text','Measured view','Enable','off', ...
                'Tag','IlluminationMeasured','ButtonPushedFcn',@(~,~) obj.showMeasured(), ...
                'Tooltip','Restore acquired plots. The applied analysis remains available to export.', ...
                'Interruptible','off','BusyAction','queue'); obj.place(obj.Fields.Measured,2,2);
            actions=uigridlayout(outer,[1 2],'ColumnWidth',{'1x',64},'Padding',[0 0 0 0]);
            obj.place(actions,3,[1 2]);
            obj.Fields.Export=uibutton(actions,'Text','Export analysis MAT...','Enable','off', ...
                'Tag','IlluminationExport','ButtonPushedFcn',@(~,~) obj.chooseExport(), ...
                'Tooltip','Save derived values, assumptions and source records to a new file.', ...
                'Interruptible','off','BusyAction','queue');
            obj.Fields.Help=uibutton(actions,'Text','Help','Tag','IlluminationHelp', ...
                'Tooltip','Adaptation whites, object reference and target light.', ...
                'ButtonPushedFcn',@(source,~)colormeasure.ui.showAnalysisHelp(outer,'color',source));
            obj.configureMode();
        end

        function update(obj,measurements,data,selection)
            obj.Measurements=measurements; obj.Data=data;
            count=numel(measurements);
            names=arrayfun(@(i) sprintf('#%d  %s',i,readingName(measurements(i),i)), ...
                1:count,'UniformOutput',false);
            if count~=obj.LastCount||~isequal(names,obj.LastNames)
                obj.LastNames=names;
                indices=1:count;
                names=names(indices);
                obj.setChoices('Sample',[{'Select reading'},names],[0 indices]);
                obj.setChoices('Reference',[{'Select white reading'},names],[0 indices]);
                whiteNames=[{'Select white','D50','D65','A (tungsten)'},names];
                obj.setChoices('SourceWhite',whiteNames,[0 -1 -2 -3 indices]);
                obj.setChoices('DestinationWhite',whiteNames,[0 -1 -2 -3 indices]);
                targets=cellfun(@(s) [s ' (illuminant SPD)'],names,'UniformOutput',false);
                obj.setChoices('Target',[{'D50','D65','A (tungsten)'},targets],[-1 -2 -3 indices]);
                if count<obj.LastCount, obj.inputsChanged(); end
                obj.LastCount=count;
            end
            if nargin>=4, obj.select(selection); end
            obj.updateAvailability();
        end

        function select(obj,index)
            if ~ismember(index,obj.Fields.Sample.ItemsData), return; end
            if obj.Fields.Sample.Value~=index
                obj.Fields.Sample.Value=index; obj.inputsChanged();
            end
        end

        function apply(obj)
            sample=obj.Fields.Sample.Value;
            if sample<1, obj.message('Select a sample reading.'); return; end
            config=obj.configuration();
            obj.clearResult();
            if strcmp(config.mode,'reflectance')
                [eligible,reason]=colormeasure.analysis.reflectanceRatioEligibility(obj.Data,sample,config.reference);
                if ~eligible,obj.message(reason);obj.revealResult();return;end
            end
            try
                result=obj.Derive(obj.Data,sample,config);
                if ~isfield(result,'available')||~isequal(result.available,true)
                    obj.message(result.reason); obj.revealResult(); return
                end
                result.sampleIndex=sample;
                indices=sample;
                for name={'sourceWhite','destinationWhite','reference','targetIlluminant'}
                    if isfield(config,name{1})
                        value=config.(name{1});
                        if isnumeric(value)&&isscalar(value)&&value>=1&&value<=numel(obj.Measurements)
                            indices(end+1)=value; %#ok<AGROW>
                        end
                    end
                end
                result.sourceIndices=unique(indices,'stable');
                result.sourceMeasurements=obj.Measurements(result.sourceIndices);
                obj.Result=result;
                fig=ancestor(obj.Fields.Outer,'figure');
                setappdata(fig,'IlluminationResult',result);
                rows={'X',colormeasure.ui.displayNumber(result.XYZ(1));'Y',colormeasure.ui.displayNumber(result.XYZ(2)); ...
                    'Z',colormeasure.ui.displayNumber(result.XYZ(3));'u''',colormeasure.ui.displayNumber(result.coordinates(1)); ...
                    'v''',colormeasure.ui.displayNumber(result.coordinates(2))};
                obj.Fields.Results.Data=rows; obj.Fields.Results.UserData=result;
                if isnumeric(result.rgb)&&isequal(size(result.rgb),[1 3])&& ...
                        all(isfinite(result.rgb))&&all(result.rgb>=0 & result.rgb<=1)
                    obj.Fields.Swatch.BackgroundColor=result.rgb;
                end
                obj.Fields.Swatch.Tooltip='Approximate sRGB preview; brightness normalized and out-of-gamut colors clipped.';
                obj.Fields.PreviewLabel.Text='Derived preview (approx.)';
                summary=result.label;
                if strcmp(result.mode,'adaptation')
                    summary=[summary '. White-chromaticity transform; acquired readings unchanged.'];
                else
                    target=config.targetIlluminant;
                    if isnumeric(target),target=sprintf('reading #%d as illuminant',target);end
                    summary=[summary '. Target: ' char(target) '.'];
                end
                if any(~isfinite(result.rgb)),summary=[summary ' Preview unavailable.'];end
                obj.message(summary);
                obj.Fields.Reason.Tooltip=strjoin([{result.label},reshape(result.details,1,[])],' ');
                obj.Fields.Measured.Enable='on'; obj.Fields.Export.Enable='on';
                if ~isempty(obj.OnResult), obj.OnResult(result); end
                obj.revealResult();
            catch problem
                obj.clearResult(); obj.message(problem.message); obj.revealResult();
            end
        end

        function showMeasured(obj)
            if ~isempty(obj.OnResult), obj.OnResult([]); end
            obj.Fields.Measured.Enable='off';
            if ~isempty(obj.Result)
                obj.message(['Measured plots restored. Analysis remains available to export. ' obj.Result.label]);
            end
        end

        function loadReference(obj,filename)
            values=readmatrix(filename);
            if ~isnumeric(values)||~isreal(values)||size(values,2)~=2||size(values,1)<2|| ...
                    any(~isfinite(values),'all')
                error('Measurement:ReferenceCSV', ...
                    'Use two numeric columns: wavelength (nm) and reflectance fraction (1 = 100%%).');
            end
            obj.ReferenceValues=values; obj.ReferenceFile=char(filename);
            obj.Fields.Perfect.Value=false;
            [~,name,extension]=fileparts(filename);
            obj.Fields.ReferenceFile.Text=sprintf('%s%s (%d rows)',name,extension,size(values,1));
            obj.Fields.ReferenceFile.Tooltip=char(filename);
            obj.inputsChanged();
        end

        function exportAnalysis(obj,filename)
            if isempty(obj.Result)
                error('Measurement:NoAnalysis','Apply an available color view before exporting.');
            end
            [~,~,extension]=fileparts(filename);
            if ~strcmpi(extension,'.mat')
                error('Measurement:AnalysisFile','Enter a new MAT filename.');
            end
            if isfile(filename)||isfolder(filename)
                error('Measurement:AnalysisFile','Enter a new filename; existing files are kept.');
            end
            % Stage the export and publish it exclusively, so a name taken
            % after this check is kept rather than written through or replaced.
            variables.analysis=obj.Result;
            try
                colormeasure.session.saveMatFile(filename,variables,false);
            catch problem
                text='Enter a new filename; existing files are kept.';
                if ~isfile(filename)&&~isfolder(filename)
                    text=['Analysis export failed: ' problem.message];
                end
                throw(addCause(MException('Measurement:AnalysisFile','%s',text),problem));
            end
            obj.message(['Analysis saved: ' char(filename)]);
        end

        function delete(obj)
            if ~isempty(obj.Fields)&&isfield(obj.Fields,'Outer')&&isgraphics(obj.Fields.Outer)
                delete(obj.Fields.Outer);
            end
        end
    end
    methods (Access = private)
        function dropdown(obj,key,label,row,items,values,value,callback)
            obj.Fields.([key 'Label'])=uilabel(obj.Fields.Body,'Text',label,'FontSize',10);
            obj.place(obj.Fields.([key 'Label']),row,1);
            control=uidropdown(obj.Fields.Body,'Items',items,'ItemsData',values, ...
                'Value',value,'Tag',['Illumination' key],'ValueChangedFcn',callback, ...
                'FontSize',10,'Interruptible','off','BusyAction','queue');
            obj.place(control,row,2); obj.Fields.(key)=control;
        end

        function setChoices(obj,key,names,values)
            control=obj.Fields.(key); value=control.Value;
            if ~ismember(value,values), value=values(1); end
            set(control,'Items',names,'ItemsData',values,'Value',value);
        end

        function modeChanged(obj)
            obj.configureMode(); obj.inputsChanged();
        end

        function configureMode(obj)
            reflectance=strcmp(obj.Fields.Mode.Value,'reflectance');
            rows={26,26,26,26,0,0,0,0,0,0,'fit',24,144,'fit'};
            if reflectance, rows={26,26,0,0,26,26,28,'fit',24,24,'fit',24,144,'fit'}; end
            obj.Fields.Body.RowHeight=rows;
            for name={'SourceWhite','SourceWhiteLabel','DestinationWhite','DestinationWhiteLabel'}
                obj.Fields.(name{1}).Visible=colormeasure.ui.onOff(~reflectance);
            end
            for name={'Reference','ReferenceLabel','Target','TargetLabel','ReferenceDataLabel','LoadReference', ...
                    'ReferenceFile','Perfect','Confirmed'}
                obj.Fields.(name{1}).Visible=colormeasure.ui.onOff(reflectance);
            end
            if reflectance
                obj.Fields.Hint.Text=['Reference must be measured under the same illumination and geometry. ' ...
                    'A target reading is treated as an illuminant spectrum.'];
            else
                obj.Fields.Hint.Text='Relative Bradford adaptation between white chromaticities; not a relit spectrum.';
            end
        end

        function sampleChanged(obj)
            obj.inputsChanged();
            if ~isempty(obj.OnSelection)&&obj.Fields.Sample.Value>0
                obj.OnSelection(obj.Fields.Sample.Value);
            end
        end

        function inputsChanged(obj,resetConfirmation)
            if nargin<2, resetConfirmation=true; end
            if resetConfirmation, obj.Fields.Confirmed.Value=false; end
            obj.clearResult(); obj.updateAvailability();
            if strcmp(char(obj.Fields.Apply.Enable),'on')
                obj.message('Select Apply to calculate this view. Acquired data stays unchanged.');
            end
            obj.Fields.LoadReference.Enable=colormeasure.ui.onOff(~obj.Fields.Perfect.Value);
        end

        function updateAvailability(obj)
            sample=obj.Fields.Sample.Value; enabled=sample>0;
            if enabled&&strcmp(obj.Fields.Mode.Value,'reflectance')
                [enabled,reason]=colormeasure.analysis.reflectanceRatioEligibility( ...
                    obj.Data,sample,obj.Fields.Reference.Value);
                if ~enabled
                    obj.message(reason);
                end
            elseif ~enabled
                obj.message('Select a sample reading.');
            end
            obj.Fields.Apply.Enable=colormeasure.ui.onOff(enabled);
        end

        function config=configuration(obj)
            config=struct('mode',obj.Fields.Mode.Value);
            if strcmp(config.mode,'adaptation')
                config.sourceWhite=whiteSelection(obj.Fields.SourceWhite.Value);
                config.destinationWhite=whiteSelection(obj.Fields.DestinationWhite.Value);
            else
                config.reference=obj.Fields.Reference.Value;
                config.targetIlluminant=whiteSelection(obj.Fields.Target.Value);
                config.confirmedSetup=obj.Fields.Confirmed.Value;
                config.assumePerfectReference=obj.Fields.Perfect.Value;
                if ~config.assumePerfectReference
                    config.referenceReflectance=obj.ReferenceValues;
                    config.referenceReflectanceFile=obj.ReferenceFile;
                end
            end
        end

        function clearResult(obj)
            obj.Result=struct([]);
            obj.Fields.Results.Data={}; obj.Fields.Results.UserData=[];
            obj.Fields.Swatch.BackgroundColor=[.5 .5 .5];
            obj.Fields.PreviewLabel.Text='Approximate color preview';
            obj.Fields.Measured.Enable='off'; obj.Fields.Export.Enable='off';
            fig=ancestor(obj.Fields.Outer,'figure');
            setappdata(fig,'IlluminationResult',[]);
            if ~isempty(obj.OnResult), obj.OnResult([]); end
        end

        function chooseReference(obj)
            [name,folder]=uigetfile('*.csv','White-reference reflectance: wavelength (nm), fraction');
            if isequal(name,0), return; end
            try
                obj.loadReference(fullfile(folder,name));
            catch problem
                obj.message(problem.message);
            end
        end

        function chooseExport(obj)
            folder=uigetdir(pwd,'Choose a folder for the separate color analysis');
            if isequal(folder,0),return;end
            stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
            answer=inputdlg('New MAT filename (existing files are kept):', ...
                'Export separate color analysis',1,{['color_analysis_' stamp '.mat']});
            if isempty(answer),return;end
            try
                name=strtrim(answer{1});[parent,base]=fileparts(name);
                if ~isempty(parent)||isempty(base)||any(strcmp(base,{'.','..'}))
                    error('Measurement:AnalysisFile','Enter a new MAT filename, without a folder path.');
                end
                obj.exportAnalysis(fullfile(folder,name));
            catch problem
                obj.message(problem.message);
            end
        end

        function message(obj,text)
            obj.Fields.Reason.Text=char(text); obj.Fields.Reason.Tooltip=char(text);
        end
        function revealResult(obj)
            % Reflow fit-height text before bringing the applied result into view.
            drawnow nocallbacks;
            scroll(obj.Fields.Body,'bottom');
        end
    end
    methods (Static, Access = private)
        function place(control,row,column)
            control.Layout.Row=row; control.Layout.Column=column;
        end
    end
end

function value=whiteSelection(value)
if value<0
    names={'D50','D65','A'}; value=names{-value};
end
end
function name=readingName(reading,index)
name=sprintf('Reading %d',index);
if isfield(reading,'name')&&(ischar(reading.name)||(isstring(reading.name)&&isscalar(reading.name)))
    name=char(reading.name);
end
end

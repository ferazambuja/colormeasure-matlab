classdef ComparisonView < handle
    % COMPARISONVIEW Two sample choices and a separate Lab reference white.
    %   Read-only: results never change acquired or saved measurements.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access=private)
        Fields
        Data=struct()
        Names={}
        LastCount=-1
        Pair=[0 0]
        OnPairChanged=[]
        SelectionIdentity={}
        ScaleDeclaration=[]
    end
    methods
        function obj=ComparisonView(parent,onPairChanged)
            if nargin>1,obj.OnPairChanged=onPairChanged;end
            grid=uigridlayout(parent,[9 2], ...
                'RowHeight',{28,28,28,0,0,26,'1x',45,28}, ...
                'ColumnWidth',{66,'1x'},'Padding',[8 8 8 8],'RowSpacing',4);
            obj.Fields.Grid=grid;
            labels={'A (ref.)','B (test)','Lab white'};
            tags={'CompareReference','CompareSample','CompareWhite'};
            for i=1:3
                label=uilabel(grid,'Text',labels{i}); label.Layout.Row=i; label.Layout.Column=1;
                control=uidropdown(grid,'Items',{'Select reading'},'ItemsData',0, ...
                    'Value',0,'Tag',tags{i},'ValueChangedFcn',@(~,~) obj.render(), ...
                    'Interruptible','off','BusyAction','queue');
                control.Layout.Row=i; control.Layout.Column=2;
                obj.Fields.(tags{i})=control;
            end
            obj.Fields.CompareReference.Tooltip='Reference sample for B − A differences; separate from Lab white.';
            obj.Fields.CompareSample.Tooltip='Test sample measured with the same setup as A.';
            obj.Fields.CompareWhite.Tooltip='White used for both CIELAB values and ΔE00; separate from sample A.';
            obj.Fields.WhiteYLabel=uilabel(grid,'Text','White Y','Visible','off');
            obj.Fields.WhiteYLabel.Layout.Row=4; obj.Fields.WhiteYLabel.Layout.Column=1;
            obj.Fields.WhiteY=uieditfield(grid,'numeric','AllowEmpty','on','Value',100, ...
                'Limits',[0 Inf],'LowerLimitInclusive','off', ...
                'Placeholder','Enter reference Y', ...
                'Tag','CompareWhiteY','Visible','off','ValueDisplayFormat','%g (XYZ scale)', ...
                'Tooltip',['Reference white Y on the sample XYZ scale (default 100). ' ...
                    'Adjust for the experiment. This does not normalize samples or verify their scale.'], ...
                'ValueChangedFcn',@(~,~) obj.render(), ...
                'Interruptible','off','BusyAction','queue');
            obj.Fields.WhiteY.Layout.Row=4; obj.Fields.WhiteY.Layout.Column=2;
            obj.Fields.ScaleConfirmation=uicheckbox(grid, ...
                'Text','Same XYZ scale (operator)', 'Value',false,'Visible','off', ...
                'Tag','ConfirmXYZScale', ...
                'Tooltip',['Confirm that A, B and the selected white use the same numerical XYZ scale. ' ...
                    'This is an operator declaration, not instrument validation.'], ...
                'ValueChangedFcn',@(~,~) obj.render(), ...
                'Interruptible','off','BusyAction','queue');
            obj.Fields.ScaleConfirmation.Layout.Row=5;
            obj.Fields.ScaleConfirmation.Layout.Column=[1 2];
            obj.Fields.Hint=uilabel(grid,'Text', ...
                'Same setup for A, B and white. Differences: B − A.', ...
                'WordWrap','on','FontSize',11);
            obj.Fields.Hint.Layout.Row=6; obj.Fields.Hint.Layout.Column=[1 2];
            obj.Fields.Table=uitable(grid,'ColumnName',{'Metric','Value'}, ...
                'ColumnWidth',{100,'1x'},'RowName',[],'ColumnEditable',false, ...
                'Tag','ComparisonResults');
            obj.Fields.Table.Layout.Row=7; obj.Fields.Table.Layout.Column=[1 2];
            obj.Fields.Reason=uilabel(grid,'WordWrap','on','FontSize',11, ...
                'Tag','ComparisonAvailability','Text','Select two readings to compare.');
            obj.Fields.Reason.Layout.Row=8; obj.Fields.Reason.Layout.Column=[1 2];
            actions=uigridlayout(grid,[1 2],'ColumnWidth',{'1x',64},'Padding',[0 0 0 0]);
            actions.Layout.Row=9;actions.Layout.Column=[1 2];
            obj.Fields.Copy=uibutton(actions,'Text','Copy comparison','Enable','off', ...
                'Tag','CopyComparison','ButtonPushedFcn',@(~,~) obj.copy(), ...
                'Interruptible','off','BusyAction','queue');
            obj.Fields.Help=uibutton(actions,'Text','Help','Tag','ComparisonHelp', ...
                'Tooltip','Choose a Lab reference white and its XYZ scale.', ...
                'ButtonPushedFcn',@(source,~)colormeasure.ui.showAnalysisHelp(grid,'compare',source));
        end
        function update(obj,measurements,data)
            obj.Data=data;
            names=arrayfun(@(i) sprintf('#%d  %s',i,measurements(i).name), ...
                1:numel(measurements),'UniformOutput',false);
            if obj.LastCount~=numel(measurements)||~isequal(obj.Names,names)
                obj.Names=names;
                indices=1:numel(measurements);
                for name={'CompareReference','CompareSample','CompareWhite'}
                    control=obj.Fields.(name{1}); value=control.Value;
                    if value>0&&~ismember(value,indices), value=0; end
                    if strcmp(name{1},'CompareWhite')
                        control.Items=[{'Select white','D50','D65','A (tungsten)'},obj.Names(indices)];
                        control.ItemsData=[0 -1 -2 -3 indices];
                    else
                        control.Items=[{'Select reading'},obj.Names(indices)];
                        control.ItemsData=[0 indices];
                    end
                    control.Value=value;
                end
                obj.LastCount=numel(measurements);
            end
            obj.render();
        end
        function choosePair(obj,indices)
            if ~isnumeric(indices)||~isreal(indices)||numel(indices)~=2|| ...
                    any(~isfinite(indices)|indices<1|fix(indices)~=indices)|| ...
                    ~all(ismember(indices,obj.Fields.CompareReference.ItemsData))
                return
            end
            obj.Fields.CompareReference.Value=indices(1);
            obj.Fields.CompareSample.Value=indices(2); obj.render(true);
            tab=ancestor(obj.Fields.Grid,'uitab');
            if ~isempty(tab),tab.Parent.SelectedTab=tab;end
        end
        function delete(obj)
            if isgraphics(obj.Fields.Grid),delete(obj.Fields.Grid);end
        end
    end
    methods (Access=private)
        function render(obj,explicitPair)
            if nargin<2,explicitPair=false;end
            a=obj.Fields.CompareReference.Value; b=obj.Fields.CompareSample.Value;
            w=obj.Fields.CompareWhite.Value;
            white=w;
            heights=obj.Fields.Grid.RowHeight;
            if w<0
                names={'D50','D65','A'};
                white=struct('illuminant',names{-w},'Y',obj.Fields.WhiteY.Value);
                heights{4}=28; heights{6}=0; obj.Fields.WhiteY.Visible='on'; obj.Fields.WhiteYLabel.Visible='on';
                obj.Fields.Hint.Visible='off';
            else
                heights{4}=0; heights{6}=26; obj.Fields.WhiteY.Visible='off'; obj.Fields.WhiteYLabel.Visible='off';
                obj.Fields.Hint.Visible='on';
                obj.Fields.Hint.Text='Same setup for A, B and white. Differences: B − A.';
            end
            identity={a,b,white};
            if ~isequaln(identity,obj.SelectionIdentity)
                obj.ScaleDeclaration=[];
                obj.Fields.ScaleConfirmation.Value=false;
                obj.SelectionIdentity=identity;
            end
            result=colormeasure.analysis.compareReadings(obj.Data,a,b,white);
            eligible=result.scaleDeclarationEligible;
            if eligible
                obj.Fields.ScaleConfirmation.Visible='on'; heights{5}=22;
            else
                obj.Fields.ScaleConfirmation.Visible='off'; heights{5}=0;
                obj.Fields.ScaleConfirmation.Value=false;
            end
            if eligible && obj.Fields.ScaleConfirmation.Value
                if isempty(obj.ScaleDeclaration)
                    stamp=colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
                    obj.ScaleDeclaration=struct('confirmed',true,'referenceIndex',a, ...
                        'sampleIndex',b,'white',white,'declaredAtUTC',stamp);
                end
                result=colormeasure.analysis.compareReadings(obj.Data,a,b,white,obj.ScaleDeclaration);
            else
                obj.ScaleDeclaration=[];
            end
            obj.Fields.Grid.RowHeight=heights;
            if w<0&&isempty(white.Y)
                result.colorReason='Enter White Y on the sample XYZ scale.';
            end
            rows={'ΔE00',colormeasure.ui.displayNumber(result.deltaE00);'Spectral RMS',colormeasure.ui.displayNumber(result.spectralRMS); ...
                'L* (A)',colormeasure.ui.displayNumber(result.Lab(1,1));'L* (B)',colormeasure.ui.displayNumber(result.Lab(2,1)); ...
                'a* (A)',colormeasure.ui.displayNumber(result.Lab(1,2));'a* (B)',colormeasure.ui.displayNumber(result.Lab(2,2)); ...
                'b* (A)',colormeasure.ui.displayNumber(result.Lab(1,3));'b* (B)',colormeasure.ui.displayNumber(result.Lab(2,3)); ...
                'ΔL*',colormeasure.ui.displayNumber(result.deltaLab(1));'Δa*',colormeasure.ui.displayNumber(result.deltaLab(2)); ...
                'Δb*',colormeasure.ui.displayNumber(result.deltaLab(3));'ΔC*',colormeasure.ui.displayNumber(result.deltaC); ...
                'ΔH*',colormeasure.ui.displayNumber(result.deltaH); ...
                'ΔX',colormeasure.ui.displayNumber(result.deltaXYZ(1));'ΔY',colormeasure.ui.displayNumber(result.deltaXYZ(2)); ...
                'ΔZ',colormeasure.ui.displayNumber(result.deltaXYZ(3));'Δu′',colormeasure.ui.displayNumber(result.deltaUV(1)); ...
                'Δv′',colormeasure.ui.displayNumber(result.deltaUV(2));'Δx',colormeasure.ui.displayNumber(result.deltaXY(1)); ...
                'Δy',colormeasure.ui.displayNumber(result.deltaXY(2))};
            obj.Fields.Table.Data=rows; obj.Fields.Table.UserData=result;
            reasons={result.pairReason,result.colorReason,result.spectralReason,result.chromaticityReason};
            reasons=reasons(~cellfun(@isempty,reasons));
            reasons=unique(reasons,'stable');
            if ~isempty(result.pairReason), reasons={result.pairReason}; end
            if any(result.Lab(:,1)>100)
                reasons=[{'Sample Y exceeds white Y (L* > 100). Check the reference.'},reasons];
            end
            if isfinite(result.spectralRMS)
                reasons{end+1}=sprintf('RMS: %s, %g–%g nm (%g nm step).', ...
                    result.spectralUnits,result.spectralRange,result.spectralStep);
            end
            text=strjoin(reasons,' ');
            obj.Fields.Reason.Text=text; obj.Fields.Reason.Tooltip=text;
            obj.Fields.Table.Tooltip=['Signed differences: B − A. ΔE00 uses kL=kC=kH=1. ' ...
                'ΔL*, Δa*, Δb*, ΔC* and signed ΔH* are Lab differences, not additive parts of ΔE00. ' ...
                'ΔH* is unavailable for an achromatic endpoint. No pass/fail threshold is applied.'];
            if a>0&&b>0
                lines={['A (reference): ' obj.Names{a}],['B (test): ' obj.Names{b}]};
                if w>0
                    lines{end+1}=['Lab white: ' obj.Names{w}];
                elseif w<0
                    lines{end+1}=sprintf('Lab white: %s; White Y: %s (sample XYZ scale)', ...
                        white.illuminant,colormeasure.ui.displayNumber(white.Y));
                    lines{end+1}='Standard reference only; no chromatic adaptation or reillumination.';
                    if isfield(result.whiteReference,'source')
                        lines{end+1}=['White source: ' result.whiteReference.source];
                        lines{end+1}=['White method: ' result.whiteReference.method];
                    end
                else
                    lines{end+1}='Lab white: not selected';
                end
                lines{end+1}=['Observer: ' result.observer];
                if ~isempty(result.scaleDeclaration)
                    lines{end+1}=['XYZ scale: operator declared the same scale for this comparison; ' ...
                        'not instrument-validated.'];
                    lines{end+1}=['Declared (UTC): ' result.scaleDeclaration.declaredAtUTC];
                end
                lines{end+1}='Signed differences: B - A. Delta E00: kL=kC=kH=1.';
                if w~=0,lines{end+1}=sprintf('White XYZ: %.9g, %.9g, %.9g',result.whiteXYZ);end
                for i=1:size(rows,1),lines{end+1}=[rows{i,1} ': ' rows{i,2}];end %#ok<AGROW>
                lines{end+1}=text;
                obj.Fields.Copy.UserData=strjoin(lines,newline);obj.Fields.Copy.Enable='on';
            else
                obj.Fields.Copy.UserData='';obj.Fields.Copy.Enable='off';
            end
            obj.Fields.Copy.Text='Copy comparison';
            changed=explicitPair||~isequal(obj.Pair,[a b]);obj.Pair=[a b];
            if ~isempty(obj.OnPairChanged),obj.OnPairChanged(result,changed);end
        end
        function copy(obj)
            if isempty(obj.Fields.Copy.UserData),return;end
            clipboard('copy',obj.Fields.Copy.UserData);obj.Fields.Copy.Text='Copied';
        end
    end
end

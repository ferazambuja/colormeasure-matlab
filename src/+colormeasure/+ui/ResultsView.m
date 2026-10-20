classdef ResultsView < handle
    % RESULTSVIEW Linked spectra, chromaticities and retained reading details.
    %   This view never acquires, saves, or edits a measurement. Adapter data
    %   supplies XYZ, optional spectra and an observer-labelled locus.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access = private)
        Fields
        Measurements = struct([])
        Data = struct()
        XYZ = zeros(0, 3)
        Coordinates = zeros(0, 2)
        Valid = false(0, 1)
        SpectrumLines = gobjects(0, 1)
        Points = gobjects(0, 1)
        Locus
        PurpleBoundary
        Selected = 0
        Mode = 1
        ModeLimits = {[0 .7 0 .6], [0 .8 0 .9]}
        Position = struct('plots',[308 244 636 340], ...
            'table',[16 16 928 190], 'details',[16 244 272 110])
        RowIndices = []
        FollowLatest = true
        SelectedSpectrumOnly = false
        MeasuredSpectraMode = 1
        DetailSelection = 0
        DetailMode = 0
        CachedLocus = []
        CachedLocusMode = 0
        TableDataCache = {}
        TableModeCache = 0
        TableSelectionCache = -1
        PageLabelCache = ''
        BackgroundMask = zeros(2)
        SelectedColumn = 3
        Comparison
        StyledCount = 0
        PairSelection = []
        PairResult = struct()
        ComparisonContext = false
        Illumination
        DerivedResult = struct([])
        EditReadingAction = []
        EditingEnabled = false
        PlotWorkspaceVisible = true
    end
    methods
        function obj = ResultsView(parent,readingParent,comparisonParent,illuminationParent,editReading)
            if nargin<2,readingParent=parent;end
            if nargin>=5,obj.EditReadingAction=editReading;end
            obj.Fields.PlotSurface=uipanel(parent,'BorderType','none','Units','normalized', ...
                'Position',[0 0 1 1],'Tag','ReadingPlotSurface');
            uistack(obj.Fields.PlotSurface,'bottom');
            obj.Fields.Spectrum = axes('Parent', obj.Fields.PlotSurface, 'Units', 'pixels', ...
                'Tag', 'SpectrumAxes', 'FontSize', 9, 'Box', 'on', ...
                'PositionConstraint', 'innerposition');
            obj.Fields.Chromaticity = axes('Parent', obj.Fields.PlotSurface, 'Units', 'pixels', ...
                'Tag', 'ChromaticityAxes', 'FontSize', 9, 'Box', 'on', ...
                'PositionConstraint', 'innerposition', 'DataAspectRatio', [1 1 1]);
            grid(obj.Fields.Spectrum, 'on'); grid(obj.Fields.Chromaticity, 'on');
            title(obj.Fields.Spectrum, '');
            xlabel(obj.Fields.Spectrum, 'Wavelength (nm)', 'FontSize', 9);
            ylabel(obj.Fields.Spectrum, 'Spectral reading', 'FontSize', 9);
            obj.Fields.Observer = uicontrol(parent, 'Style', 'text', ...
                'Tag', 'ResultObserver', 'HorizontalAlignment', 'left', 'String', '');
            obj.Fields.Mode = uicontrol(parent, 'Style', 'popupmenu', ...
                'Tag', 'CoordinateMode', 'String', {'CIE 1976 u''v''', 'CIE 1931 xy'}, ...
                'Value', 1, 'Callback', @(~,~) obj.changeMode(), ...
                'TooltipString', 'Coordinate system for the color plot and results table.', ...
                'Interruptible', 'off', 'BusyAction', 'queue');
            obj.Fields.Reset = uicontrol(parent, 'Style', 'pushbutton', ...
                'Tag', 'ResetView', 'String', 'Reset plots', ...
                'Callback', @(~,~) obj.resetView(), ...
                'TooltipString', 'Show the complete spectrum and chromaticity ranges.', ...
                'Interruptible', 'off', 'BusyAction', 'queue');
            obj.Fields.TablePanel = uipanel(parent, 'Units', 'pixels', ...
                'BorderType', 'none', 'Tag', 'ResultsTablePanel');
            obj.Fields.Latest = uicontrol(parent, 'Style', 'pushbutton', ...
                'Tag', 'LatestReading', 'String', 'Follow latest', ...
                'TooltipString', 'Select the newest reading and follow new measurements.', ...
                'Callback', @(~,~) obj.followLatest());
            obj.Fields.PageLabel = uicontrol(parent, 'Style', 'text', ...
                'Tag', 'ReadingPage', 'HorizontalAlignment', 'left');
            obj.Fields.SpectraMode = uicontrol(parent, 'Style', 'popupmenu', ...
                'Tag', 'SpectraMode', 'String', {'All spectra','Selected spectrum','Compare A / B'}, ...
                'TooltipString', 'Reduce spectrum clutter while keeping all readings in the batch.', ...
                'Value', 1, 'Callback', @(~,~) obj.changeSpectraMode(true));
            obj.Fields.LatestSummary = uicontrol(parent,'Style','text', ...
                'Tag','LatestReadingSummary','HorizontalAlignment','left','FontSize',10, ...
                'String','No readings yet');
            obj.Fields.Table = uitable(obj.Fields.TablePanel, 'Tag', 'ResultsTable', ...
                'RowName', [], 'ColumnEditable', false, ...
                'CellSelectionCallback', @(~,event) obj.selectFromTable(event,[]), ...
                'Interruptible', 'off', 'BusyAction', 'queue');
            obj.Fields.PreviewPanel=uipanel(obj.Fields.TablePanel,'Units','pixels', ...
                'BorderType','none','Tag','SelectedColorPreview','Visible','off');
            obj.Fields.PreviewName=uilabel(obj.Fields.PreviewPanel, ...
                'Text','No reading selected','FontSize',13,'FontWeight','bold', ...
                'WordWrap','on','Tag','SelectedColorName');
            obj.Fields.PreviewSwatch=uipanel(obj.Fields.PreviewPanel,'Units','pixels', ...
                'BorderType','line','BackgroundColor',[0 0 0], ...
                'Tag','SelectedColorSwatch','Visible','off');
            obj.Fields.PreviewUnavailable=uilabel(obj.Fields.PreviewPanel, ...
                'Text','No readings yet','WordWrap','on','HorizontalAlignment','center', ...
                'Tag','SelectedColorUnavailable');
            obj.Fields.PreviewNote=uilabel(obj.Fields.PreviewPanel, ...
                'Text',sprintf('Approximate sRGB\nBrightness normalized'), ...
                'FontSize',11,'WordWrap','on','Tag','SelectedColorNote');
            obj.Fields.EditReading=uicontrol(parent,'Style','pushbutton','String','Edit…', ...
                'Tag','EditReadingAnnotations','FontSize',10,'Enable','off','Visible','off', ...
                'TooltipString','Edit the selected reading''s sample name and notes; measured values remain unchanged.', ...
                'Callback',@(~,~)obj.editSelected(),'Interruptible','off','BusyAction','queue');
            obj.Fields.DetailsLabel = uicontrol(readingParent,'Style','text', ...
                'Tag','ReadingDetailsLabel','String','Selected reading', ...
                'HorizontalAlignment','left');
            obj.Fields.CopyDetails = uicontrol(readingParent,'Style','pushbutton', ...
                'Tag','CopyReadingDetails','String','Copy','Enable','off', ...
                'TooltipString','Copy the selected reading summary to the clipboard.', ...
                'Callback',@(~,~) obj.copyDetails(), ...
                'Interruptible','off','BusyAction','queue');
            obj.Fields.Properties = uitable(readingParent,'Tag','ReadingProperties', ...
                'ColumnName',{'Result','Value'},'ColumnWidth',{72,'auto'}, ...
                'RowName',[],'ColumnEditable',false,'FontSize',10);
            obj.Fields.Details = uitextarea(readingParent, ...
                'Tag', 'ReadingDetails', 'Editable', 'off', 'WordWrap', 'on', ...
                'FontSize', 13, 'Value', {'No notes for this reading.'}, ...
                'Tooltip', 'Sample notes. Copy includes results, notes and completion time.');
            obj.Fields.SpectrumEmpty = uilabel(parent, ...
                'Text', 'No spectra available', 'WordWrap', 'on', ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'Tag', 'SpectrumUnavailable');
            obj.Fields.ChromaEmpty = text(obj.Fields.Chromaticity, .5, .5, ...
                'No valid chromaticities', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'Tag', 'ChromaticityUnavailable');
            obj.Fields.ColorBackground = image('Parent',obj.Fields.Chromaticity, ...
                'CData',zeros(2,2,3),'AlphaData',zeros(2), ...
                'XData',[0 .7],'YData',[0 .6],'Tag','ChromaticityBackground', ...
                'HitTest','off','PickableParts','none');
            obj.Fields.ColorNote = text(obj.Fields.Chromaticity,.98,.98, ...
                'Approximate sRGB colors','Units','normalized','FontSize',8, ...
                'VerticalAlignment','top','HorizontalAlignment','right','Tag','ChromaticityColorNote', ...
                'HitTest','off','PickableParts','none','Visible','off');
            obj.Locus = line(obj.Fields.Chromaticity, NaN, NaN, 'Color', [.4 .4 .4], ...
                'LineWidth', 1, 'HitTest', 'off', 'Tag', 'SpectralLocus');
            obj.PurpleBoundary = line(obj.Fields.Chromaticity, NaN, NaN, ...
                'Color', [.4 .4 .4], 'LineStyle', '--', 'HitTest', 'off', 'Tag', 'PurpleBoundary');
            set([obj.Fields.Latest obj.Fields.SpectraMode], ...
                'Interruptible', 'off', 'BusyAction', 'queue');
            obj.applyCoordinateAxes(); obj.layout(obj.Position);
            obj.refreshTable();
            if nargin>=3
                obj.Comparison=colormeasure.ui.ComparisonView(comparisonParent, ...
                    @(result,changed) obj.updatePair(result,changed));
            end
            if nargin>=4
                obj.Illumination=colormeasure.ui.IlluminationView(illuminationParent, ...
                    @(result) obj.updateIllumination(result),@(index) obj.select(index));
            end
        end

        function update(obj, measurements, viewData, position)
            % Called only when retained readings change, not on status events.
            if nargin >= 4, obj.layout(position); end
            obj.Measurements = measurements;
            % Annotation changes can keep the same row count and selection.
            obj.DetailSelection=0;
            if ~isstruct(viewData) || ~isscalar(viewData), viewData = struct(); end
            obj.Data = viewData;
            if ~isempty(obj.Illumination)
                obj.Illumination.update(measurements,viewData,min(obj.Selected,numel(measurements)));
            end
            count = numel(measurements);
            obj.XYZ = NaN(count, 3);
            if isfield(viewData, 'XYZ') && isnumeric(viewData.XYZ) && ...
                    isequal(size(viewData.XYZ), [count 3])
                obj.XYZ = viewData.XYZ;
            end
            [obj.Coordinates, obj.Valid] = colormeasure.analysis.chromaticity(obj.XYZ, obj.modeName());
            oldCount = numel(obj.SpectrumLines);
            if count < oldCount
                delete(obj.SpectrumLines(isgraphics(obj.SpectrumLines)));
                delete(obj.Points(isgraphics(obj.Points)));
                obj.SpectrumLines = gobjects(0,1); obj.Points = gobjects(0,1);
                obj.Selected = 0; obj.DetailSelection = 0; oldCount = 0;
                obj.FollowLatest = true;
                obj.PairSelection=[];
                removeStyle(obj.Fields.Table); obj.StyledCount=0;
            end
            for index = oldCount+1:count
                color = readingColor(index);
                obj.SpectrumLines(index, 1) = gobjects(1);
                spectrum = obj.spectrum(index);
                if ~isempty(spectrum)
                    obj.SpectrumLines(index, 1) = line(obj.Fields.Spectrum, spectrum.x, spectrum.y, ...
                        'Color', color, 'LineWidth', 1.2, 'Tag', 'ReadingSpectrum', ...
                        'Visible', colormeasure.ui.onOff(~obj.SelectedSpectrumOnly), ...
                        'UserData', index, 'DisplayName', obj.readingName(index), ...
                        'ButtonDownFcn', @(source,~) obj.select(get(source, 'UserData')), ...
                        'Interruptible', 'off', 'BusyAction', 'queue');
                end
                obj.Points(index, 1) = line(obj.Fields.Chromaticity, NaN, NaN, ...
                    'Color', color, 'MarkerFaceColor', color, 'Marker', 'o', ...
                    'MarkerSize', 5, 'LineStyle', 'none', 'Tag', 'ReadingChromaticity', ...
                    'UserData', index, 'DisplayName', obj.readingName(index), ...
                    'ButtonDownFcn', @(source,~) obj.select(get(source, 'UserData')), ...
                    'Interruptible', 'off', 'BusyAction', 'queue');
            end
            if count==0
                set(obj.Fields.Details,'Value',{'No notes for this reading.'}, ...
                    'UserData',0);
                set(obj.Fields.CopyDetails,'Enable','off','String','Copy','UserData','');
                obj.DetailSelection=0; obj.DetailMode=0;
                obj.Fields.Properties.Data={};
            end
            obj.updateCoordinates(oldCount+1);
            for index=1:count
                if isgraphics(obj.SpectrumLines(index)),obj.SpectrumLines(index).DisplayName=obj.readingName(index);end
                if isgraphics(obj.Points(index)),obj.Points(index).DisplayName=obj.readingName(index);end
            end
            set(obj.Fields.Observer, 'String', obj.dataText('observer', 'Observer unspecified'));
            xlabel(obj.Fields.Spectrum, obj.dataText('spectralXLabel', 'Wavelength (nm)'), 'FontSize', 9);
            ylabel(obj.Fields.Spectrum, obj.dataText('spectralLabel', 'Spectral reading'), 'FontSize', 9);
            obj.layoutPair();
            obj.updateSpectrumAvailability();
            set(obj.Fields.SpectraMode,'Enable',colormeasure.ui.onOff(obj.hasSpectra()));
            % New readings stay visible until an explicit inspection pauses
            % following. A batch is indexed independently of duplicate names.
            if count > 0 && (obj.FollowLatest || obj.Selected == 0)
                obj.select(count, false);
            else
                obj.refreshTable();
                if obj.Selected>0,obj.showDetails();end
            end
            obj.bringSelectionToFront();
            if ~isempty(obj.Comparison),obj.Comparison.update(measurements,viewData);end
            obj.refreshIllumination();obj.applyPresentation();
        end

        function layout(obj, position)
            % Pure layout: independent areas let the host prioritize results.
            obj.Position = position;
            p=position.plots;x=p(1);width=p(3);top=p(2)+p(4);
            set(obj.Fields.SpectraMode,'Position',[x top-28 150 26]);
            set(obj.Fields.Mode,'Position',[x+156 top-28 156 26]);
            set(obj.Fields.Reset,'Position',[x+318 top-28 100 26]);
            set(obj.Fields.Latest,'Position',[x+width-104 top-28 104 26]);
            set(obj.Fields.Observer,'Position',[x top-50 width 18],'FontSize',8);
            obj.layoutPair();
            p=position.table;width=p(3);
            set(obj.Fields.TablePanel,'Position',p);
            % The host reserves space beside its actions. Standalone views
            % have no host toolbar and can use the full page-label row.
            pageLabel=[p(1) p(2)+p(4)+5 width 20];
            if isfield(position,'pageLabel'),pageLabel=position.pageLabel;end
            set(obj.Fields.PageLabel,'Position',pageLabel,'FontSize',9);
            summary=[p(1) p(2)+p(4)+34 p(3) 20];
            if isfield(position,'summary'),summary=position.summary;end
            set(obj.Fields.LatestSummary,'Position',summary);
            if isfield(position,'editButton')
                obj.Fields.EditReading.Position=position.editButton;
            end
            p=position.details;
            set(obj.Fields.DetailsLabel,'Position',[p(1) p(2)+p(4)-22 p(3)-66 20]);
            set(obj.Fields.CopyDetails,'Position',[p(1)+p(3)-58 p(2)+p(4)-24 58 24]);
            obj.layoutDetails();
            if obj.Selected > 0, obj.showDetails(); end
            obj.refreshTable();
            obj.refreshIllumination();obj.applyPresentation();
        end

        function showTable(obj, visible)
            % The host can show event history in the same area without
            % changing plot selection, inspected details, or table navigation.
            set(obj.Fields.TablePanel, 'Visible', colormeasure.ui.onOff(visible));
            set(obj.Fields.EditReading,'Visible',colormeasure.ui.onOff(visible&&~isempty(obj.EditReadingAction)));
        end
        function showPlotWorkspace(obj,visible)
            % Chart inspection shares the primary workspace, preserving plots.
            obj.PlotWorkspaceVisible=visible;obj.applyPresentation();
        end

        function setEditingEnabled(obj,enabled)
            obj.EditingEnabled=enabled;obj.updateEditAction();
        end

        function showContext(obj, tab)
            % Sidebar inspection changes only the plot presentation. Keep the
            % ordinary All/Selected preference separate from temporary A/B mode.
            obj.ComparisonContext=strcmp(tab,'CompareTab');
            if strcmp(tab,'MeasureTab')
                obj.Fields.SpectraMode.Value=obj.MeasuredSpectraMode;
                obj.changeSpectraMode(true);
            elseif strcmp(tab,'CompareTab')
                obj.Fields.SpectraMode.Value=obj.MeasuredSpectraMode;
                if obj.hasSpectra() && isfield(obj.PairResult,'referenceIndex') && ...
                        obj.PairResult.referenceIndex>0 && obj.PairResult.sampleIndex>0 && ...
                        obj.PairResult.referenceIndex~=obj.PairResult.sampleIndex
                    obj.Fields.SpectraMode.Value=3;
                end
                % Compare always returns to acquired data, including XYZ-only
                % devices and incomplete pairs. The derived export is retained.
                obj.changeSpectraMode(true);
            end
            obj.refreshPointSelection();
            obj.applyPresentation();
        end

        function refreshTheme(obj)
            % Only contrast changes. Preserve curves, coordinates, selection,
            % pending fields and all scroll positions during a theme switch.
            fig=ancestor(obj.Fields.Chromaticity,'figure');
            dark=strcmp(fig.Theme.BaseColorStyle,'dark');
            opacity=.28; edge=[.16 .16 .16];
            if dark, opacity=.42; edge=[.90 .90 .90]; end
            set(obj.Fields.ColorBackground,'AlphaData',opacity*double(obj.BackgroundMask));
            if ~isempty(obj.Points), set(obj.Points,'MarkerEdgeColor',edge); end
            if isfield(obj.Fields,'DifferenceLine')
                obj.Fields.DifferenceLine.Color=edge;obj.Fields.DifferenceZero.Color=edge;
            end
            if isfield(obj.Fields,'DerivedPoint'),obj.Fields.DerivedPoint.MarkerEdgeColor=edge;end
            if isfield(obj.Fields,'DerivedLabel'),obj.Fields.DerivedLabel.Color=edge;end
            if isfield(obj.Fields,'DerivedSpectrumLine'),obj.Fields.DerivedSpectrumLine.Color=edge;end
        end

        function delete(obj)
            if ~isempty(obj.Comparison)&&isvalid(obj.Comparison),delete(obj.Comparison);end
            if ~isempty(obj.Illumination)&&isvalid(obj.Illumination),delete(obj.Illumination);end
            names = fieldnames(obj.Fields);
            for index = 1:numel(names)
                value = obj.Fields.(names{index});
                if isgraphics(value), delete(value); end
            end
        end
    end
    methods (Access = private)
        function tableWidths(obj)
            p=obj.Position.table;width=p(3);
            available=width-156; % Marker, row index, duration, border/scrollbar.
            sample=min(220,max(120,round(available*.22)));
            mode=min(180,max(110,round(available*.18)));
            notes=0;if obj.notesColumn(),notes=min(220,max(110,round(available*.2)));end
            widths={14,28,sample};
            if notes>0,widths{end+1}=notes;end
            widths{end+1}=mode;
            value=min(80,max(50,floor((available-sample-mode-notes)/5)));
            widths=[widths,repmat({value},1,5),{96}];
            obj.Fields.Table.ColumnWidth=widths;
            % Use spare width only. The preview must not displace columns or
            % introduce a horizontal scrollbar in an otherwise fitting table.
            spare=width-sum(cell2mat(widths))-32;
            previewWidth=min([320 floor(width/4) spare]);
            showPreview=previewWidth>=160;
            tableWidth=width;
            if showPreview,tableWidth=width-previewWidth-12;end
            height=max(1,p(4));
            obj.Fields.Table.Position=[0 0 tableWidth height];
            obj.Fields.PreviewPanel.Visible=colormeasure.ui.onOff(showPreview);
            if showPreview
                obj.Fields.PreviewPanel.Position=[tableWidth+12 0 previewWidth height];
                obj.Fields.PreviewName.Position=[0 height-38 previewWidth 38];
                area=[0 40 previewWidth max(1,height-84)];
                obj.Fields.PreviewSwatch.Position=area;
                obj.Fields.PreviewUnavailable.Position=area;
                obj.Fields.PreviewNote.Position=[0 0 previewWidth 36];
            end
        end
        function yes=notesColumn(obj)
            % Narrow windows keep result columns readable. Full multiline
            % notes remain available in Data and the annotation editor.
            yes=obj.Position.table(3)>=850;
        end
        function applyPresentation(obj)
            obj.Fields.PlotSurface.Visible=colormeasure.ui.onOff(obj.PlotWorkspaceVisible);
            set([obj.Fields.Mode obj.Fields.SpectraMode obj.Fields.Reset obj.Fields.Observer obj.Fields.SpectrumEmpty], ...
                'Visible',colormeasure.ui.onOff(obj.PlotWorkspaceVisible));
            obj.Fields.Latest.Visible=colormeasure.ui.onOff(obj.PlotWorkspaceVisible);
            obj.updateSpectrumAvailability();
            if ~obj.PlotWorkspaceVisible,obj.Fields.SpectrumEmpty.Visible='off';end
        end
        function name = modeName(obj)
            if obj.Mode == 1, name = 'uv'; else, name = 'xy'; end
        end

        function selectFromTable(obj, event, displayedIds)
            if isempty(event.Indices), return; end
            % A queued event retains the reading IDs from its rendered
            % snapshot, even if acquisition appended rows in the meantime.
            rows=unique(event.Indices(:,1),'stable');
            obj.PairSelection=[];
            if numel(rows)==2 && ~isempty(obj.Comparison) && all(rows>=1&rows<=numel(displayedIds))
                obj.PairSelection=displayedIds(rows);
                obj.Comparison.choosePair(displayedIds(rows));

            end
            row=event.Indices(end,1);
            if row>=1 && row<=numel(displayedIds)
                obj.SelectedColumn=max(1,min(size(obj.Fields.Table.Data,2),event.Indices(end,2)));
                obj.select(displayedIds(row),true,false);
            end
        end

        function select(obj, index, pauseFollowing, reveal)
            if nargin<3, pauseFollowing=true; end
            if nargin<4, reveal=true; end
            if index < 1 || index > numel(obj.Measurements), return; end
            if reveal,obj.PairSelection=[];end
            if pauseFollowing, obj.FollowLatest=false; end
            previous = obj.Selected; obj.Selected = index;
            for value = unique([previous index])
                if value < 1, continue; end
                chosen = value == index;
                if isgraphics(obj.SpectrumLines(value))
                    set(obj.SpectrumLines(value), 'LineWidth', 1.2 + 1.4*chosen, ...
                        'Visible', colormeasure.ui.onOff(obj.spectrumVisible(value)));
                end
            end
            obj.bringSelectionToFront(); obj.updateSpectrumAvailability();
            obj.refreshTable(); obj.showDetails();obj.applyPresentation();
            if ~isempty(obj.Illumination), obj.Illumination.select(index); end
            if reveal, obj.revealReading(index); end
        end

        function bringSelectionToFront(obj)
            % Later append operations must not cover an inspected curve/point.
            if obj.Selected>0 && isgraphics(obj.SpectrumLines(obj.Selected))
                uistack(obj.SpectrumLines(obj.Selected),'top');
            end
            obj.refreshPointSelection();
        end

        function refreshPointSelection(obj)
            % The comparison pair and the inspected table row are distinct.
            % XYZ-only devices have no spectral selector, so use their tab.
            indices=obj.Selected;
            if (obj.Fields.SpectraMode.Value==3 || (obj.ComparisonContext && ~obj.hasSpectra())) && ...
                    isfield(obj.PairResult,'referenceIndex') && ...
                    obj.PairResult.referenceIndex>0 && obj.PairResult.sampleIndex>0
                indices=[obj.PairResult.referenceIndex obj.PairResult.sampleIndex];
            end
            indices=unique(indices(indices>0 & indices<=numel(obj.Points)));
            for index=1:numel(obj.Points)
                chosen=any(index==indices);
                set(obj.Points(index),'MarkerSize',5+4*chosen,'LineWidth',1+chosen);
            end
            if ~isempty(indices),uistack(obj.Points(indices),'top');end
        end

        function followLatest(obj)
            obj.FollowLatest=true;
            if ~isempty(obj.Measurements), obj.select(numel(obj.Measurements),false); end
        end

        function revealReading(obj,index)
            % Native clicks and ordinary refreshes preserve the viewport.
            scroll(obj.Fields.Table,'row',index);
        end

        function changeSpectraMode(obj,restoreMeasured)
            if obj.Fields.SpectraMode.Value~=3
                obj.MeasuredSpectraMode=obj.Fields.SpectraMode.Value;
            end
            if nargin>1&&restoreMeasured&&~isempty(obj.Illumination)&&~isempty(obj.DerivedResult)
                obj.Illumination.showMeasured();
            end
            obj.SelectedSpectrumOnly=get(obj.Fields.SpectraMode,'Value')==2;
            for index=1:numel(obj.SpectrumLines)
                if isgraphics(obj.SpectrumLines(index))
                    set(obj.SpectrumLines(index),'Visible', ...
                        colormeasure.ui.onOff(obj.spectrumVisible(index)));
                end
            end
            obj.refreshPair();
            obj.updateSpectrumAvailability();
        end

        function visible=spectrumVisible(obj,index)
            if obj.Fields.SpectraMode.Value==3
                visible=isfield(obj.PairResult,'referenceIndex') && ...
                    any(index==[obj.PairResult.referenceIndex obj.PairResult.sampleIndex]);
            else
                visible=~obj.SelectedSpectrumOnly||index==obj.Selected;
            end
        end

        function updatePair(obj,result,changed)
            if changed&&~isempty(obj.Illumination)&&~isempty(obj.DerivedResult)
                obj.Illumination.showMeasured();
            end
            obj.PairResult=result;
            if obj.hasSpectra()&&changed&&result.referenceIndex>0&&result.sampleIndex>0&& ...
                    result.referenceIndex~=result.sampleIndex
                obj.Fields.SpectraMode.Value=3;
            end
            obj.changeSpectraMode();
        end

        function refreshPair(obj)
            active=obj.hasSpectra()&&obj.Fields.SpectraMode.Value==3;
            if active&&~isfield(obj.Fields,'Difference')
                obj.Fields.Difference=axes('Parent',obj.Fields.Spectrum.Parent, ...
                    'Units','pixels','Tag','DifferenceAxes','FontSize',9,'Box','on', ...
                    'XLim',obj.Fields.Spectrum.XLim, ...
                    'PositionConstraint','innerposition');
                grid(obj.Fields.Difference,'on');
                xlabel(obj.Fields.Difference,'Wavelength (nm)','FontSize',9);
                ylabel(obj.Fields.Difference,'B − A','FontSize',9);
                obj.Fields.DifferenceLine=line(obj.Fields.Difference,NaN,NaN, ...
                    'Color',obj.Fields.Spectrum.XColor, ...
                    'LineWidth',1.4,'Tag','SpectralDifference');
                obj.Fields.DifferenceZero=yline(obj.Fields.Difference,0,':', ...
                    'Color',obj.Fields.Spectrum.XColor,'HandleVisibility','off');
                obj.Fields.DifferenceEmpty=text(obj.Fields.Difference,.5,.5,'Choose A and B', ...
                    'Units','normalized','HorizontalAlignment','center','FontSize',8, ...
                    'Tag','DifferenceUnavailable','Interpreter','none');
                linkaxes([obj.Fields.Spectrum obj.Fields.Difference],'x');
            end
            if isfield(obj.Fields,'PairLegend')&&isgraphics(obj.Fields.PairLegend)
                delete(obj.Fields.PairLegend);
            end
            for i=1:numel(obj.SpectrumLines)
                if isgraphics(obj.SpectrumLines(i)),obj.SpectrumLines(i).LineStyle='-';end
            end
            if isfield(obj.Fields,'Difference')
                obj.Fields.Difference.Visible=colormeasure.ui.onOff(active);
                set([obj.Fields.Difference.XLabel obj.Fields.Difference.YLabel],'Visible',colormeasure.ui.onOff(active));
                obj.Fields.DifferenceLine.Visible=colormeasure.ui.onOff(active);
                obj.Fields.DifferenceZero.Visible=colormeasure.ui.onOff(active);
                obj.Fields.DifferenceEmpty.Visible='off';
                if active
                    r=obj.PairResult;x=[];y=[];reason='Choose A and B in Compare.';
                    if isfield(r,'spectralWavelengths')
                        x=r.spectralWavelengths;y=r.spectralDifference;
                        reason=r.spectralReason;
                        if ~isempty(r.pairReason),reason=r.pairReason;end
                    end
                    set(obj.Fields.DifferenceLine,'XData',x,'YData',y);
                    obj.spectrumTicks(obj.Fields.Difference,~isempty(x));
                    obj.Fields.DifferenceZero.Visible=colormeasure.ui.onOff(~isempty(x));
                    set(obj.Fields.DifferenceEmpty,'Visible',colormeasure.ui.onOff(isempty(x)), ...
                        'String',strtrim(reason));
                    ids=[];
                    if isfield(r,'referenceIndex'),ids=[r.referenceIndex r.sampleIndex];end
                    ids=unique(ids(ids>0 & ids<=numel(obj.SpectrumLines)),'stable');
                    ids=ids(isgraphics(obj.SpectrumLines(ids)));
                    if ~isempty(ids)
                        labels=cell(size(ids));
                        for k=1:numel(ids)
                            role='A';if ids(k)==r.sampleIndex&&ids(k)~=r.referenceIndex,role='B';end
                            % Full names stay in the selectors and readings table.
                            labels{k}=sprintf('%s: #%d',role,ids(k));
                            if strcmp(role,'B'),obj.SpectrumLines(ids(k)).LineStyle='--';end
                        end
                        obj.Fields.PairLegend=legend(obj.Fields.Spectrum,obj.SpectrumLines(ids), ...
                            labels,'Location','northeast','FontSize',8,'Interpreter','none', ...
                            'AutoUpdate','off');
                    end
                end
            end
            obj.refreshPointSelection();
            obj.layoutPair();
        end

        function layoutPair(obj)
            p=obj.Position.plots;
            % Tick labels and units remain outside the data rectangles. Reserve
            % space from MATLAB's actual text extents, including long residual units.
            inset=obj.Fields.Spectrum.TightInset;
            chromaInset=obj.Fields.Chromaticity.TightInset;
            if isfield(obj.Fields,'DerivedSpectrum') && ~isempty(obj.DerivedResult) && ...
                    strcmp(obj.DerivedResult.mode,'reflectance')
                % The derived-spectrum title sits outside the curve area.
                % Reserve its labels just as for the acquired spectra.
                inset=max(inset,obj.Fields.DerivedSpectrum.TightInset);
            end
            left=max(46,ceil(inset(1)));bottom=max(32,ceil(inset(2)));
            chromaLeft=max(38,ceil(chromaInset(1)));
            chromaRight=max(12,ceil(chromaInset(3)));
            right=max(12,ceil(inset(3)));gap=16;
            if isfield(obj.Fields,'Difference')&&obj.Fields.SpectraMode.Value==3
                differenceInset=obj.Fields.Difference.TightInset;
                left=max(left,ceil(differenceInset(1)));
                bottom=max(bottom,ceil(differenceInset(2)));
            end
            % Scientific scale multipliers sit above the axes rectangle.
            % Keep their rendered extent below the observer row, with a gap.
            top=50+max(8,ceil(max(inset(4),chromaInset(4)))+4);
            x=p(1)+left;y=p(2)+bottom;h=max(80,p(4)-bottom-top);
            available=max(100,p(3)-left-right-chromaLeft-chromaRight-gap);
            chromaWidth=available*.43;w=available-chromaWidth;
            if ~obj.hasSpectra()
                obj.Fields.Chromaticity.Position=[x y max(100,p(3)-left-chromaRight) max(80,h-24)];
                obj.Fields.SpectrumEmpty.Position=[p(1)+8 p(2)+p(4)-74 p(3)-16 20];
                return
            end
            obj.Fields.Chromaticity.Position=[x+w+right+gap+chromaLeft y chromaWidth h];
            if obj.Fields.SpectraMode.Value==3&&isfield(obj.Fields,'Difference')
                residual=max(50,min(110,h*.27));gap=30;
                obj.Fields.Difference.Position=[x y w residual];
                obj.Fields.Spectrum.Position=[x y+residual+gap w max(35,h-residual-gap)];
                obj.Fields.Spectrum.XTickLabel=[];obj.Fields.Spectrum.XLabel.Visible='off';
            else
                obj.Fields.Spectrum.Position=[x y w h];
                obj.Fields.Spectrum.XTickLabelMode='auto';
                obj.Fields.Spectrum.XLabel.Visible=colormeasure.ui.onOff(obj.hasSpectra());
            end
            obj.Fields.SpectrumEmpty.Position=obj.Fields.Spectrum.Position;
            % A derived spectrum replaces the acquired one in place, including
            % after a window resize.
            if isfield(obj.Fields,'DerivedSpectrum')
                obj.Fields.DerivedSpectrum.Position=obj.Fields.Spectrum.Position;
            end
        end

        function updateSpectrumAvailability(obj)
            if ~obj.hasSpectra()
                unavailable=true;
                label=obj.dataText('noSpectrumReason','This instrument reports XYZ only.');
            elseif obj.Fields.SpectraMode.Value==3
                visible=false(size(obj.SpectrumLines));
                for i=1:numel(visible),visible(i)=isgraphics(obj.SpectrumLines(i))&&obj.spectrumVisible(i);end
                unavailable=~any(visible);label='Choose A and B in Compare';
                if isfield(obj.PairResult,'referenceIndex') && ...
                        obj.PairResult.referenceIndex>0 && obj.PairResult.sampleIndex>0
                    label='No spectra for the selected pair';
                end
            elseif obj.SelectedSpectrumOnly
                unavailable=obj.Selected<1 || ~isgraphics(obj.SpectrumLines(obj.Selected));
                label='No spectrum for this reading';
            else
                unavailable=~any(isgraphics(obj.SpectrumLines));
                label='No spectra available';
            end
            set(obj.Fields.SpectrumEmpty,'Visible',colormeasure.ui.onOff(unavailable),'Text',label);
            obj.spectrumTicks(obj.Fields.Spectrum,~unavailable);
            obj.updateSpectrumLabel();
            % XYZ-only instruments have no wavelength or spectral value axes.
            obj.Fields.Spectrum.Visible=colormeasure.ui.onOff(obj.hasSpectra());
            set([obj.Fields.Spectrum.Title obj.Fields.Spectrum.YLabel], ...
                'Visible',colormeasure.ui.onOff(obj.hasSpectra()));
            obj.Fields.Spectrum.XLabel.Visible=colormeasure.ui.onOff(obj.hasSpectra()&&obj.Fields.SpectraMode.Value~=3);
            obj.refreshIllumination();
        end

        function yes=hasSpectra(obj)
            yes=~isfield(obj.Data,'hasSpectra') || ~isequal(obj.Data.hasSpectra,false);
        end

        function spectrumTicks(~,axes,available)
            % An empty axes' default 0--1 bounds are not a measured wavelength
            % grid. Retain the labels but show numeric ticks only with data.
            if available
                set(axes,'XTickMode','auto','YTickMode','auto');
            else
                set(axes,'XTick',[],'YTick',[]);
            end
        end

        function updateSpectrumLabel(obj)
            % An all-reading overlay must never label older data with the
            % newest reading's units. Inspect one curve for its own label.
            indices=find(isgraphics(obj.SpectrumLines));
            indices=indices(arrayfun(@(index) obj.spectrumVisible(index),indices));
            labels=cell(numel(indices),1);
            for k=1:numel(indices)
                labels{k}=obj.rowText('spectralLabels',indices(k), ...
                    obj.dataText('spectralLabel','Spectral reading'));
            end
            labels=unique(labels,'stable');
            if numel(labels)>1
                label='Mixed quantities / units (see Data)';
            elseif isscalar(labels)
                label=labels{1};
            else
                label=obj.dataText('spectralLabel','Spectral reading');
            end
            ylabel(obj.Fields.Spectrum,label,'FontSize',9,'Interpreter','none');
        end

        function changeMode(obj)
            current = obj.Fields.Chromaticity;
            obj.ModeLimits{obj.Mode} = [get(current, 'XLim') get(current, 'YLim')];
            obj.Mode = get(obj.Fields.Mode, 'Value');
            [obj.Coordinates, obj.Valid] = colormeasure.analysis.chromaticity(obj.XYZ, obj.modeName());
            obj.applyCoordinateAxes(); obj.updateCoordinates(); obj.refreshTable();
            if obj.Selected > 0, obj.showDetails(); end
        end

        function applyCoordinateAxes(obj)
            ax = obj.Fields.Chromaticity;
            if obj.Mode == 1
                title(ax, '');
                xlabel(ax, 'u''', 'FontSize', 9); ylabel(ax, 'v''', 'FontSize', 9);
            else
                title(ax, '');
                xlabel(ax, 'x', 'FontSize', 9); ylabel(ax, 'y', 'FontSize', 9);
            end
            bounds = obj.ModeLimits{obj.Mode};
            set(ax, 'XLim', bounds(1:2), 'YLim', bounds(3:4), 'DataAspectRatio', [1 1 1]);
            set(ax,'YDir','normal','Layer','top');
        end

        function updateCoordinates(obj, first)
            if nargin < 2, first = 1; end
            for index = first:numel(obj.Points)
                set(obj.Points(index), 'XData', obj.Coordinates(index, 1), ...
                    'YData', obj.Coordinates(index, 2));
            end
            locusXYZ = [];
            if isfield(obj.Data, 'locusXYZ') && isnumeric(obj.Data.locusXYZ) && ...
                    size(obj.Data.locusXYZ, 2) == 3
                locusXYZ = obj.Data.locusXYZ;
            end
            if obj.CachedLocusMode ~= obj.Mode || ~isequaln(locusXYZ, obj.CachedLocus)
                locus = zeros(0, 2);
                if ~isempty(locusXYZ)
                    [locus, valid] = colormeasure.analysis.chromaticity(locusXYZ, obj.modeName());
                    locus = locus(valid, :);
                end
                if size(locus, 1) >= 2
                    set(obj.Locus, 'XData', locus(:,1), 'YData', locus(:,2));
                    set(obj.PurpleBoundary, 'XData', locus([end 1],1), 'YData', locus([end 1],2));
                else
                    set(obj.Locus, 'XData', NaN, 'YData', NaN);
                    set(obj.PurpleBoundary, 'XData', NaN, 'YData', NaN);
                end
                obj.CachedLocus = locusXYZ; obj.CachedLocusMode = obj.Mode;
                [rgb,mask,x,y]=colormeasure.ui.chromaticityBackground(locusXYZ,obj.modeName());
                obj.BackgroundMask=mask;
                set(obj.Fields.ColorBackground,'CData',rgb, ...
                    'XData',x([1 end]),'YData',y([1 end]));
                uistack(obj.Fields.ColorBackground,'bottom');
                set(obj.Fields.ColorNote,'Visible',colormeasure.ui.onOff(any(mask(:))));
            end
            obj.refreshTheme();
            set(obj.Fields.ChromaEmpty, 'Visible', colormeasure.ui.onOff(~any(obj.Valid)));
            obj.refreshIllumination();
        end

        function updateIllumination(obj,result)
            obj.DerivedResult=result;
            % Restore ordinary line/pair visibility before applying an optional
            % derived overlay. No acquired values, selection or zoom is edited.
            obj.changeSpectraMode();
            obj.refreshIllumination();
        end

        function refreshIllumination(obj)
            active=~isempty(obj.DerivedResult);
            if ~active
                for name={'DerivedPoint','DerivedLabel','DerivedSpectrum', ...
                        'DerivedSpectrumLine','DerivedSpectrumNote'}
                    if isfield(obj.Fields,name{1}),obj.Fields.(name{1}).Visible='off';end
                end
                if isfield(obj.Fields,'DerivedSpectrum')
                    set([obj.Fields.DerivedSpectrum.Title obj.Fields.DerivedSpectrum.XLabel ...
                        obj.Fields.DerivedSpectrum.YLabel],'Visible','off');
                end
                obj.Fields.ChromaEmpty.Visible=colormeasure.ui.onOff(~any(obj.Valid));
                return
            end
            r=obj.DerivedResult;
            if ~isfield(obj.Fields,'DerivedPoint')
                obj.Fields.DerivedPoint=line(obj.Fields.Chromaticity,NaN,NaN, ...
                    'Marker','p','MarkerSize',13,'LineWidth',1.8,'LineStyle','none', ...
                    'Tag','IlluminationChromaticity','HitTest','off','PickableParts','none');
                obj.Fields.DerivedLabel=text(obj.Fields.Chromaticity,NaN,NaN,'', ...
                    'FontSize',9,'FontWeight','bold','VerticalAlignment','bottom', ...
                    'Interpreter','none','Tag','IlluminationChromaticityLabel', ...
                    'HitTest','off','PickableParts','none');
            end
            [coordinates,valid]=colormeasure.analysis.chromaticity(r.XYZ,obj.modeName());
            rgb=[.5 .5 .5];
            if isequal(size(r.rgb),[1 3])&&all(isfinite(r.rgb))&&all(r.rgb>=0&r.rgb<=1),rgb=r.rgb;end
            edge=[.16 .16 .16];
            fig=ancestor(obj.Fields.Chromaticity,'figure');
            if strcmp(fig.Theme.BaseColorStyle,'dark'),edge=[.90 .90 .90];end
            set(obj.Fields.DerivedPoint,'XData',coordinates(1),'YData',coordinates(2), ...
                'MarkerFaceColor',rgb,'MarkerEdgeColor',edge,'Visible',colormeasure.ui.onOff(valid));
            set(obj.Fields.DerivedLabel,'Position',[coordinates 0], ...
                'String',sprintf('  Derived #%d',r.sampleIndex),'Color',edge,'Visible',colormeasure.ui.onOff(valid));
            if valid
                obj.Fields.ChromaEmpty.Visible='off';
                uistack(obj.Fields.DerivedPoint,'top');uistack(obj.Fields.DerivedLabel,'top');
            end
            if ~strcmp(r.mode,'reflectance'), return; end
            if ~isfield(obj.Fields,'DerivedSpectrum')
                ax=axes('Parent',obj.Fields.Spectrum.Parent,'Units','pixels', ...
                    'Tag','IlluminationSpectrumAxes','FontSize',9,'Box','on', ...
                    'PositionConstraint','innerposition');
                grid(ax,'on'); obj.Fields.DerivedSpectrum=ax;
                obj.Fields.DerivedSpectrumLine=line(ax,NaN,NaN,'LineWidth',1.8, ...
                    'Tag','IlluminationReflectance','HitTest','off');
                obj.Fields.DerivedSpectrumNote=title(ax,'Derived; acquired spectra unchanged', ...
                    'FontSize',8,'FontWeight','normal','Interpreter','none', ...
                    'Tag','IlluminationSpectrumNote','HitTest','off');
            end
            obj.Fields.DerivedSpectrum.Visible='on';obj.Fields.DerivedSpectrumNote.Visible='on';
            set(obj.Fields.DerivedSpectrumLine,'XData',r.spectrum.x,'YData',r.spectrum.y, ...
                'Color',edge,'Visible','on');
            label='Reflectance factor (fraction)'; heading='Derived reflectance factor';
            if isfield(r.config,'assumePerfectReference')&&r.config.assumePerfectReference
                label='Relative spectral ratio'; heading='Relative spectral ratio';
            end
            obj.Fields.DerivedSpectrumNote.String=sprintf('%s · #%d\nDerived; acquired spectra unchanged',heading,r.sampleIndex);
            xlabel(obj.Fields.DerivedSpectrum,'Wavelength (nm)','FontSize',9);
            ylabel(obj.Fields.DerivedSpectrum,label,'FontSize',9);
            set([obj.Fields.DerivedSpectrum.Title obj.Fields.DerivedSpectrum.XLabel ...
                obj.Fields.DerivedSpectrum.YLabel],'Visible','on');
            obj.layoutPair();
            obj.Fields.Spectrum.Visible='off';obj.Fields.SpectrumEmpty.Visible='off';
            set([obj.Fields.Spectrum.Title obj.Fields.Spectrum.XLabel obj.Fields.Spectrum.YLabel],'Visible','off');
            set(obj.SpectrumLines(isgraphics(obj.SpectrumLines)),'Visible','off');
            for name={'Difference','DifferenceLine','DifferenceZero','DifferenceEmpty','PairLegend'}
                if isfield(obj.Fields,name{1})&&isgraphics(obj.Fields.(name{1}))
                    obj.Fields.(name{1}).Visible='off';
                end
            end
            if isfield(obj.Fields,'Difference')
                set([obj.Fields.Difference.XLabel obj.Fields.Difference.YLabel],'Visible','off');
            end
        end

        function refreshTable(obj)
            if obj.Mode == 1, headings = {'u''', 'v'''}; else, headings = {'x', 'y'}; end
            count=numel(obj.Measurements);
            obj.RowIndices=1:count;
            notes=obj.notesColumn();
            columnsCount=10+notes;
            data = cell(numel(obj.RowIndices), columnsCount);
            for row = 1:numel(obj.RowIndices)
                index=obj.RowIndices(row);
                marker=''; if index==obj.Selected, marker='>'; end
                data(row,1:3)={marker,index,obj.readingName(index)};
                column=4;
                if notes
                    data{row,column}=notesPreview(textValue(obj.Measurements(index),'notes'));
                    column=column+1;
                end
                data{row,column}=obj.rowText('measurementModes',index,'Unavailable');
                column=column+1;
                    data(row,column:end)={ ...
                        displayValue(obj.XYZ(index, 1)), displayValue(obj.XYZ(index, 2)), ...
                        displayValue(obj.XYZ(index, 3)), ...
                        displayValue(obj.Coordinates(index, 1)), displayValue(obj.Coordinates(index, 2)), ...
                        displayValue(recordValue(obj.Measurements(index), 'durationSeconds', NaN))};
            end
            schema=[obj.Mode columnsCount notes];
            dataChanged=~isequaln(data,obj.TableDataCache) || ~isequal(schema,obj.TableModeCache);
            selectionChanged=obj.Selected~=obj.TableSelectionCache;
            if dataChanged
                displayedIds=obj.RowIndices;
                columns={'','#','Sample'};
                if notes,columns{end+1}='Notes';end
                columns{end+1}='Mode';
                    columns=[columns,{'X','Y','Z'},headings,{'Duration (s)'}];
                % Publish the schema before its data. Native tables rebuild
                % columns when Data changes; old headings otherwise survive
                % a resize that adds or removes the Notes column.
                set(obj.Fields.Table, 'ColumnName', columns, ...
                    'Data', data, ...
                    'CellSelectionCallback', @(~,event) obj.selectFromTable(event,displayedIds));
                obj.TableDataCache=data; obj.TableModeCache=schema;
            end
            if selectionChanged
                set(obj.Fields.Table,'UserData',obj.Selected);
                obj.TableSelectionCache=obj.Selected;
            end
            if dataChanged || selectionChanged, obj.syncNativeSelection(); end
            for index=obj.StyledCount+1:count
                [rgb,valid]=obj.readingPreview(index);
                if valid
                    icon=repmat(reshape(rgb,1,1,3),16,16,1);
                    icon([1 end],:,:)=.5;icon(:,[1 end],:)=.5;
                    addStyle(obj.Fields.Table,uistyle('Icon',icon,'IconAlignment','left'), ...
                        'cell',[index 3]);
                end
            end
            obj.StyledCount=count;
            obj.Fields.Table.Tooltip=['Sample swatches: approximate sRGB chromaticity, brightness normalized. ' ...
                'Select two rows to compare (Command-click on macOS, Ctrl-click on Windows).'];
            obj.tableWidths();
            obj.refreshPreview();
            obj.updateEditAction();
            state='Following latest';
            if ~obj.FollowLatest, state=sprintf('Inspecting #%d',obj.Selected); end
            if count==0
                label='No readings yet';
            else
                label=sprintf('Selected #%d of %d | %s',obj.Selected,count,state);
            end
            if ~strcmp(label,obj.PageLabelCache)
                selectedLabel='No readings';
                if count>0
                    action='Following';if ~obj.FollowLatest,action='Inspecting';end
                    selectedLabel=sprintf('%s %d of %d',action,obj.Selected,count);
                end
                set(obj.Fields.PageLabel,'String',selectedLabel,'TooltipString',label);
                obj.PageLabelCache=label;
            end
            set(obj.Fields.Latest,'Enable',colormeasure.ui.onOff(count>0),'UserData',obj.FollowLatest);
            summary='No readings yet';
            if count>0
                % Reuse table operands/formatting; inspecting an older row does
                % not turn it into the latest acquisition or alter units.
                units=obj.rowText('xyzUnitsByReading',count,textValue(obj.Measurements(count),'xyzUnits'));
                summary=sprintf('Latest #%d: %s | XYZ: %s %s | %s = %s, %s = %s', ...
                    count,obj.readingName(count),displayTriple(obj.XYZ(count,:)),units, ...
                    headings{1},string(displayValue(obj.Coordinates(count,1))), ...
                    headings{2},string(displayValue(obj.Coordinates(count,2))));
            end
            set(obj.Fields.LatestSummary,'String',summary,'TooltipString',summary);
        end

        function [rgb,valid,clipped]=readingPreview(obj,index)
            rgb=[NaN NaN NaN];valid=false;clipped=false;
            if index<1,return;end
            [rgb,valid,clipped]=colormeasure.colorimetry.previewColor(obj.XYZ(index,:));
            if isfield(obj.Data,'observerIds')
                valid=valid&&strcmp(obj.rowText('observerIds',index,''),'CIE1931_2deg');
            end
        end

        function refreshPreview(obj)
            index=obj.Selected;
            name='No reading selected';message='No readings yet';
            if index>0
                name=sprintf('Selected #%d: %s',index,obj.readingName(index));
                message='Color preview unavailable';
            end
            obj.Fields.PreviewName.Text=name;obj.Fields.PreviewName.Tooltip=name;
            [rgb,valid,clipped]=obj.readingPreview(index);
            obj.Fields.PreviewSwatch.Visible=colormeasure.ui.onOff(valid);
            if valid,obj.Fields.PreviewSwatch.BackgroundColor=rgb;end
            obj.Fields.PreviewUnavailable.Text=message;
            obj.Fields.PreviewUnavailable.Visible=colormeasure.ui.onOff(~valid);
            obj.Fields.PreviewNote.Visible=colormeasure.ui.onOff(valid);
            explanation=['Approximate sRGB chromaticity; brightness normalized. ' ...
                'This is not measured luminance or a calibrated appearance match.'];
            if clipped,explanation=[explanation ' Outside sRGB gamut; RGB values clipped.'];end
            obj.Fields.PreviewNote.Tooltip=explanation;
            obj.Fields.PreviewUnavailable.Tooltip= ...
                'Color previews require finite, nonnegative XYZ and a confirmed CIE 1931 2-degree observer.';
        end

        function syncNativeSelection(obj)
            row=find(obj.RowIndices==obj.Selected,1);
            current=get(obj.Fields.Table,'Selection');
            columns=size(obj.Fields.Table.Data,2);
            obj.SelectedColumn=max(1,min(columns,obj.SelectedColumn));
            invalidColumn=~isempty(current)&&any(current(:,2)>columns);
            if isempty(row)
                if ~isempty(current), set(obj.Fields.Table,'Selection',[]); end
            elseif numel(obj.PairSelection)==2
                if invalidColumn||~isequal(unique(current(:,1),'stable'),obj.PairSelection(:))
                    set(obj.Fields.Table,'Selection', ...
                        [obj.PairSelection(:),repmat(obj.SelectedColumn,2,1)]);
                end
            elseif isempty(current) || any(current(:,1)~=row) || invalidColumn
                % Preserve the clicked column and keyboard focus. This setter
                % does not dispatch CellSelectionCallback or acquire a reading.
                set(obj.Fields.Table,'Selection',[row obj.SelectedColumn]);
            end
        end

        function showDetails(obj)
            % Native wrapping handles resizing without replacing the text or
            % resetting a student's scroll position or text selection.
            if obj.DetailSelection == obj.Selected && obj.DetailMode == obj.Mode, return; end
            reading = obj.Measurements(obj.Selected);
            lines = {sprintf('Reading %d: %s', obj.Selected, obj.readingName(obj.Selected))};
            notes=textValue(reading,'notes');
            if ~isempty(notes), lines{end+1}=['Notes: ' notes]; end
            measurementMode=obj.rowText('measurementModes',obj.Selected,'Unavailable');
            lines{end+1}=['Mode: ' measurementMode];
            xyz=obj.XYZ(obj.Selected,:);
            if isreal(xyz) && all(isfinite(xyz))
                lines{end+1}=sprintf('XYZ: %.6g, %.6g, %.6g',xyz);
            else
                lines{end+1}='XYZ: Unavailable';
            end
            if obj.Valid(obj.Selected)
                coordinates=obj.Coordinates(obj.Selected,:);
                if obj.Mode==1
                    lines{end+1}=sprintf('u'' = %.6g   v'' = %.6g',coordinates);
                else
                    lines{end+1}=sprintf('x = %.6g   y = %.6g',coordinates);
                end
            else
                lines{end+1}='Chromaticity: Unavailable';
            end
            observer=obj.rowText('observerNames',obj.Selected, ...
                obj.dataText('observer','Unspecified'));
            lines{end+1}=['Observer: ' observer];
            xyzSource=obj.rowText('xyzSources',obj.Selected,textValue(reading,'xyzMethod'));
            xyzUnits=obj.rowText('xyzUnitsByReading',obj.Selected,textValue(reading,'xyzUnits'));
            spectrumUnits=obj.rowText('spectralUnitsByReading',obj.Selected,textValue(reading,'spectralUnits'));
            condition=obj.rowText('measurementConditions',obj.Selected,'');
            sampling=obj.rowText('spectralSampling',obj.Selected,'');
            samplingSource=obj.rowText('spectralSamplingSources',obj.Selected,'');
            grid=obj.spectrumGrid(obj.Selected);
            if ~isempty(xyzSource),lines{end+1}=['XYZ source: ' xyzSource];end
            if ~isempty(xyzUnits),lines{end+1}=['XYZ units: ' xyzUnits];end
            if ~isempty(spectrumUnits),lines{end+1}=['Spectral units: ' spectrumUnits];end
            if ~isempty(condition),lines{end+1}=['Measurement condition: ' condition];end
            if ~isempty(sampling),lines{end+1}=['Spectral sampling: ' sampling];end
            if ~isempty(samplingSource),lines{end+1}=['Sampling basis: ' samplingSource];end
            if ~isempty(grid),lines{end+1}=['Wavelength grid: ' grid];end
            duration=recordValue(reading,'durationSeconds',NaN);
            validDuration=isnumeric(duration) && isscalar(duration) && isreal(duration) && ...
                    isfinite(duration) && duration>=0;
            if validDuration
                lines{end+1}=sprintf('Duration: %.3g s',duration);
            end
            stamp=textValue(reading,'completedAtUTC');
            if ~isempty(stamp)
                % Display seconds; the complete timestamp remains in the struct.
                stamp=colormeasure.session.displayTime(stamp);
                lines{end+1}=['Completed: ' stamp];
                lines{end+1}=['Completed (UTC): ' textValue(reading,'completedAtUTC')];
            end
            instrument=textValue(reading,'deviceType');
            if ~isempty(instrument), lines{end+1}=['Instrument: ' instrument]; end
            synthetic=recordValue(reading,'isSynthetic',false);
            if isequal(synthetic,true) && ~contains(instrument,'synthetic','IgnoreCase',true)
                lines{end+1}='Source: Synthetic demo';
            end
            rows={'X',displayValue(xyz(1));'Y',displayValue(xyz(2)); ...
                'Z',displayValue(xyz(3))};
            if obj.Mode==1,labels={'u''','v'''};else,labels={'x','y'};end
            for k=1:2
                rows(end+1,:)={labels{k},displayValue(obj.Coordinates(obj.Selected,k))}; %#ok<AGROW>
            end
            if validDuration,rows(end+1,:)={'Duration',sprintf('%.3g s',duration)};end
            rows(end+1,:)={'Mode',measurementMode};
            if ~isempty(stamp)
                if numel(stamp)>=11
                    rows(end+1,:)={'Date',stamp(1:10)};
                    rows(end+1,:)={'Time',stamp(12:end)};
                else
                    rows(end+1,:)={'Time',stamp};
                end
            end
            if ~isempty(instrument)
                rows(end+1,:)={'Instrument',instrument};
            end
            observer=strrep(observer, ...
                'CIE 1931 2-degree observer','CIE 1931 · 2°');
            rows(end+1,:)={'Observer',observer};
            if ~isempty(xyzSource),rows(end+1,:)={'XYZ source',xyzSource};end
            if ~isempty(xyzUnits),rows(end+1,:)={'XYZ units',xyzUnits};end
            if ~isempty(spectrumUnits),rows(end+1,:)={'Spectrum units',spectrumUnits};end
            if ~isempty(condition),rows(end+1,:)={'Condition',condition};end
            if ~isempty(sampling),rows(end+1,:)={'Sampling',sampling};end
            if ~isempty(samplingSource),rows(end+1,:)={'Basis',samplingSource};end
            if ~isempty(grid),rows(end+1,:)={'Grid',grid};end
            if isequal(synthetic,true),rows(end+1,:)={'Source','Synthetic demo'};end
            obj.Fields.Properties.Data=rows;
            obj.Fields.Properties.Tooltip=strjoin(lines,newline);
            obj.Fields.DetailsLabel.String=sprintf('#%d %s',obj.Selected,obj.readingName(obj.Selected));
            obj.Fields.DetailsLabel.TooltipString=lines{1};
            if isempty(notes),noteLines={'No notes for this reading.'};else,noteLines=regexp(notes,'\r\n|\n|\r','split');end
            set(obj.Fields.Details,'Value',noteLines,'UserData',obj.Selected);
            obj.layoutDetails();
            set(obj.Fields.CopyDetails,'Enable','on','String','Copy', ...
                'UserData',strjoin(lines,newline));
            scroll(obj.Fields.Details,'top');
            obj.DetailSelection=obj.Selected; obj.DetailMode=obj.Mode;
        end

        function text=spectrumGrid(obj,index)
            % Report the retained grid only; output spacing is not bandwidth.
            text='';
            if ~isfield(obj.Data,'spectra')||~iscell(obj.Data.spectra)|| ...
                    numel(obj.Data.spectra)<index,return;end
            spectrum=obj.Data.spectra{index};
            if ~isstruct(spectrum)||~isscalar(spectrum)||~isfield(spectrum,'x'),return;end
            x=spectrum.x;
            if ~isnumeric(x)||~isvector(x)||~isreal(x)||isempty(x)|| ...
                    any(~isfinite(x))||any(diff(x)<=0),return;end
            x=double(x(:));
            text=sprintf('%.6g-%.6g nm; %d samples',x(1),x(end),numel(x));
            if numel(x)>1
                steps=diff(x);step=(x(end)-x(1))/(numel(x)-1);
                if all(abs(steps-step)<=64*eps(max(abs(x))))
                    text=sprintf('%s; spacing %.6g nm',text,step);
                else
                    text=[text '; nonuniform spacing'];
                end
            end
        end

        function layoutDetails(obj)
            % Keep short notes compact even in a tall window; spare sidebar
            % space is not a giant empty text box. Long notes scroll locally.
            p=obj.Position.details; noteHeight=32;
            if obj.Selected>0 && ~isempty(textValue(obj.Measurements(obj.Selected),'notes'))
                noteHeight=min(120,max(48,p(4)*.28));
            end
            infoHeight=min(300,max(32,p(4)-34-noteHeight));
            infoBottom=p(2)+p(4)-28-infoHeight;
            set(obj.Fields.Properties,'Position',[p(1) infoBottom p(3) infoHeight], ...
                'ColumnWidth',{70,max(80,p(3)-90)});
            set(obj.Fields.Details,'Position', ...
                [p(1) max(p(2),infoBottom-6-noteHeight) p(3) noteHeight]);
        end

        function copyDetails(obj)
            text=get(obj.Fields.CopyDetails,'UserData');
            if isempty(text), return; end
            clipboard('copy',text);
            set(obj.Fields.CopyDetails,'String','Copied');
        end

        function updateEditAction(obj)
            ready=obj.EditingEnabled && obj.Selected>0 && numel(obj.PairSelection)<2;
            obj.Fields.EditReading.Enable=colormeasure.ui.onOff(ready);
        end

        function editSelected(obj)
            if ~obj.EditingEnabled || obj.Selected<1 || numel(obj.PairSelection)>1 || isempty(obj.EditReadingAction),return;end
            obj.EditReadingAction(obj.Selected);
        end

        function spectrum = spectrum(obj, index)
            spectrum = [];
            if ~isfield(obj.Data, 'spectra') || ~iscell(obj.Data.spectra) || ...
                    index > numel(obj.Data.spectra), return; end
            candidate = obj.Data.spectra{index};
            if ~isstruct(candidate) || ~isscalar(candidate) || ...
                    ~isfield(candidate, 'x') || ~isfield(candidate, 'y'), return; end
            if isnumeric(candidate.x) && isnumeric(candidate.y) && isreal(candidate.x) && ...
                    isreal(candidate.y) && isvector(candidate.x) && isvector(candidate.y) && ...
                    ~isempty(candidate.x) && numel(candidate.x) == numel(candidate.y) && ...
                    all(isfinite(candidate.x)) && all(isfinite(candidate.y))
                spectrum = candidate;
            end
        end

        function name = readingName(obj, index)
            name = char(recordValue(obj.Measurements(index), 'name', sprintf('Reading %d', index)));
        end

        function value = dataText(obj, field, fallback)
            value = recordValue(obj.Data, field, fallback);
            if ~(ischar(value) || (isstring(value) && isscalar(value))), value = fallback; end
            value = char(value);
        end

        function value = rowText(obj, field, index, fallback)
            value=fallback;
            if isfield(obj.Data,field)
                values=obj.Data.(field);
                value=''; % A supplied per-reading array owns missing entries.
                if iscell(values)&&numel(values)>=index
                    candidate=values{index};
                elseif isstring(values)&&numel(values)>=index
                    candidate=values(index);
                else
                    return
                end
                if (ischar(candidate)&&(isrow(candidate)||isempty(candidate))) || ...
                        (isstring(candidate)&&isscalar(candidate)&&~ismissing(candidate))
                    value=char(candidate);
                end
            end
        end

        function resetView(obj)
            set(obj.Fields.Spectrum, 'XLimMode', 'auto', 'YLimMode', 'auto');
            if isfield(obj.Fields,'Difference'),obj.Fields.Difference.YLimMode='auto';end
            if isfield(obj.Fields,'DerivedSpectrum')
                set(obj.Fields.DerivedSpectrum,'XLimMode','auto','YLimMode','auto');
            end
            obj.ModeLimits = {[0 .7 0 .6], [0 .8 0 .9]};
            obj.applyCoordinateAxes();
        end
    end
end

function value = recordValue(record, field, fallback)
value = fallback;
if isfield(record, field), value = record.(field); end
end

function value = displayValue(value)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
    value = 'Unavailable';
end
end

function text=displayTriple(values)
text=char(strjoin(arrayfun(@(value)string(displayValue(value)),values),', '));
end

function text=notesPreview(value)
text=regexprep(value,'\s+',' ');
if numel(text)>100,text=[text(1:99) '…'];end
end

function color = readingColor(index)
hue = mod(0.58 + (index - 1)*0.618033988749895, 1);
color = hsv2rgb([hue .7 .8]);
end

function value = textValue(record,field)
value=recordValue(record,field,'');
if (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value))
    value=char(value);
else
    value='';
end
end

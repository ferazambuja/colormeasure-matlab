classdef LogView < handle
    % LOGVIEW Follow live events or inspect one message without losing history.
    %   Visible rows map to original event indices, independent of the filter
    %   and window width. Full messages remain available in the detail pane.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (Access = private)
        Fields = struct()
        Entries = struct('timeUTC', {}, 'level', {}, 'message', {})
        Summaries = cell(0, 1)
        VisibleEvents = []
        SelectedEvent = 0
        SelectionHidden = false
        Following = true
        RevealSelection = false
        Filter = 1
        LastFilter = 0
        LastWidth = 0
        DetailEvent = -1
        DetailHidden = false
        GlyphWidth
        RowHeight
        Position = [16 16 388 200]
        RenderedPosition = []
        RenderedSelection = -1
        RenderedFollowing = false
        RenderedHidden = false
        DetailVisible = false
        ForceLatest = false
    end
    methods
        function obj = LogView(parent)
            obj.make(parent, 'popupmenu', 'LogFilter', {'All events'; 'Warnings/errors'});
            obj.make(parent, 'checkbox', 'FollowLatest', 'Follow latest');
            obj.make(parent, 'pushbutton', 'JumpToLatest', 'Jump to latest');
            obj.make(parent, 'listbox', 'SessionLog', {''});
            obj.make(parent, 'text', 'LogDetailLabel', 'Selected message');
            obj.make(parent, 'pushbutton', 'CopyLogMessage', 'Copy');
            obj.Fields.LogDetails = uitextarea(parent,'Tag','LogDetails', ...
                'Editable','off','WordWrap','on','FontSize',13,'Value',{''});
            font = get(groot, 'FixedWidthFontName');
            set(obj.Fields.SessionLog, ...
                'Min', 0, 'Max', 2, 'Value', [], 'FontName', font, 'FontSize', 10);
            ruler = uicontrol(parent, 'Style', 'text', 'Visible', 'off', ...
                'Units', 'pixels', 'FontName', font, 'FontSize', 10, 'String', repmat('M', 1, 50));
            extent = get(ruler, 'Extent');
            obj.GlyphWidth = max(1, extent(3) / 50);
            obj.RowHeight = max(1, extent(4));
            delete(ruler);
            set(obj.Fields.LogFilter, 'Callback', @(~,~) obj.changeFilter());
            set(obj.Fields.FollowLatest, 'Value', 1, 'Callback', @(~,~) obj.changeFollow());
            set(obj.Fields.JumpToLatest, 'Callback', @(~,~) obj.jump());
            set(obj.Fields.SessionLog, 'Callback', @(~,~) obj.inspect());
            set(obj.Fields.CopyLogMessage, 'Callback', @(~,~) obj.copy());
            set(obj.Fields.FollowLatest, 'TooltipString', ...
                'Follow new events. Clear this or select a message to inspect history.');
            set(obj.Fields.SessionLog, 'TooltipString', ...
                'Select a message to pause following and show its full details.');
        end

        function update(obj, entries, position)
            count = numel(entries);
            previousCount = numel(obj.Summaries);
            resized = ~isequal(position, obj.RenderedPosition);
            filterChanged = obj.Filter ~= obj.LastFilter;
            if count == previousCount && ~resized && ~filterChanged && ...
                    obj.SelectedEvent == obj.RenderedSelection && ...
                    obj.Following == obj.RenderedFollowing && ~obj.ForceLatest
                % Sample edits, port changes and other session notifications
                % must not reset a native selection or the history viewport.
                obj.RevealSelection = false;
                return
            end
            % Native Value can change before its callback is dispatched. Keep
            % that original row identity before replacing the filtered list;
            % a measurement completion must not erase an inspection click.
            renderedRow = find(obj.VisibleEvents == obj.RenderedSelection, 1);
            if ~obj.ForceLatest && ~obj.RevealSelection && ...
                    ~isequal(get(obj.Fields.SessionLog, 'Value'), renderedRow)
                obj.adoptNativeSelection();
            end
            % Capture the old event at the top before changing native controls.
            anchor = 1;
            if ~isempty(obj.VisibleEvents)
                top = min(get(obj.Fields.SessionLog, 'ListboxTop'), numel(obj.VisibleEvents));
                anchor = obj.VisibleEvents(top);
            end
            obj.Entries = entries;
            obj.Position = position;
            [historyWidth, ~] = obj.contentWidths();
            for index = previousCount+1:count
                entry = entries(index);
                obj.Summaries{index,1} = sprintf('%s [%s] %s', ...
                    entry.timeUTC(12:19), upper(entry.level), regexprep(entry.message, '\s+', ' '));
            end
            changed = count ~= previousCount || filterChanged || historyWidth ~= obj.LastWidth;
            rowsChanged = false;
            if changed
                if obj.Filter == 1
                    visible = 1:count;
                else
                    visible = find(ismember({entries.level}, {'warning', 'error'}));
                end
                rowsChanged = ~isequal(visible, obj.VisibleEvents) || historyWidth ~= obj.LastWidth;
                obj.VisibleEvents = visible;
                if rowsChanged || isempty(obj.RenderedPosition)
                    width = max(4, floor((historyWidth-24) / obj.GlyphWidth));
                    lines = obj.Summaries(visible);
                    for index = 1:numel(lines)
                        if numel(lines{index}) > width
                            lines{index} = [lines{index}(1:width-3) '...'];
                        end
                    end
                    if isempty(lines), lines = {'No events match this filter.'}; end
                    set(obj.Fields.SessionLog, 'String', lines, 'UserData', visible);
                end
                obj.LastFilter = obj.Filter;
                obj.LastWidth = historyWidth;
            end
            obj.SelectionHidden = obj.SelectedEvent > 0 && ~ismember(obj.SelectedEvent, obj.VisibleEvents);
            selectedRow = find(obj.VisibleEvents == obj.SelectedEvent, 1);
            selectionChanged = obj.SelectedEvent ~= obj.RenderedSelection || ...
                obj.SelectionHidden ~= obj.RenderedHidden;
            if ~isequal(get(obj.Fields.SessionLog, 'Value'), selectedRow)
                set(obj.Fields.SessionLog, 'Value', selectedRow);
            end
            showDetails = obj.SelectedEvent > 0;
            layoutChanged = resized || showDetails ~= obj.DetailVisible;
            if layoutChanged, obj.layout(); end
            obj.renderDetails();
            if obj.Following ~= obj.RenderedFollowing
                set(obj.Fields.FollowLatest, 'Value', double(obj.Following));
            end
            % String/Value/layout can change ListboxTop. Restore only after
            % drawing, including height-only resizes. Native controls clamp the
            % last item to the bottom without estimating font row heights.
            needsScroll = rowsChanged || layoutChanged || selectionChanged || obj.ForceLatest;
            if needsScroll
                drawnow nocallbacks
                top = find(obj.VisibleEvents >= anchor, 1);
                if isempty(top), top = max(1, numel(obj.VisibleEvents)); end
                if obj.Following
                    top = max(1, numel(obj.VisibleEvents));
                elseif ~isempty(selectedRow) && (obj.RevealSelection || filterChanged)
                    % A visible click leaves the surrounding history still.
                    % Opening details or selecting off-screen may require a
                    % small scroll, just enough to reveal the selected row.
                    history = get(obj.Fields.SessionLog, 'Position');
                    rows = max(1, floor((history(4)-6) / obj.RowHeight));
                    if selectedRow < top
                        top = selectedRow;
                    elseif selectedRow >= top + rows
                        top = selectedRow - rows + 1;
                    end
                end
                if get(obj.Fields.SessionLog, 'ListboxTop') ~= top
                    set(obj.Fields.SessionLog, 'ListboxTop', top);
                    drawnow nocallbacks
                end
            end
            obj.RevealSelection = false;
            obj.ForceLatest = false;
            obj.RenderedPosition = position;
            obj.RenderedSelection = obj.SelectedEvent;
            obj.RenderedFollowing = obj.Following;
            obj.RenderedHidden = obj.SelectionHidden;
            obj.DetailVisible = showDetails;
        end

        function delete(obj)
            names = fieldnames(obj.Fields);
            for index = 1:numel(names)
                control = obj.Fields.(names{index});
                if isgraphics(control), delete(control); end
            end
        end
    end
    methods (Access = private)
        function make(obj, parent, style, tag, text)
            obj.Fields.(tag) = uicontrol(parent, 'Style', style, 'Tag', tag, ...
                'String', text, 'Units', 'pixels', 'HorizontalAlignment', 'left', ...
                'FontSize', 10, 'Interruptible', 'off', 'BusyAction', 'cancel');
        end

        function layout(obj)
            p = obj.Position; x = p(1); y = p(2); width = p(3); height = p(4);
            if width >= 370
                filterWidth = width - 234;
                set(obj.Fields.LogFilter, 'Position', [x y+height-28 filterWidth 28]);
                set(obj.Fields.FollowLatest, 'Position', [x+filterWidth+6 y+height-28 108 28]);
                set(obj.Fields.JumpToLatest, 'Position', [x+width-114 y+height-28 114 28]);
                available = height - 36;
            else
                % Compact views retain readable controls instead of shrinking
                % the filter to a few characters.
                set(obj.Fields.LogFilter, 'Position', [x y+height-28 width 28]);
                set(obj.Fields.FollowLatest, 'Position', [x y+height-60 108 28]);
                set(obj.Fields.JumpToLatest, 'Position', [x+width-114 y+height-60 114 28]);
                available = height - 68;
            end
            showDetails = obj.SelectedEvent > 0;
            set([obj.Fields.LogDetailLabel obj.Fields.CopyLogMessage obj.Fields.LogDetails], ...
                'Visible', colormeasure.ui.onOff(showDetails));
            detailHeight = 0;
            if showDetails
                if width >= 700
                    [historyWidth, detailWidth] = obj.contentWidths();
                    detailX = x + historyWidth + 12;
                    set(obj.Fields.LogDetailLabel, 'Position', ...
                        [detailX y+available-22 detailWidth-62 20]);
                    set(obj.Fields.CopyLogMessage, 'Position', ...
                        [detailX+detailWidth-56 y+available-24 56 24]);
                    set(obj.Fields.LogDetails, 'Position', ...
                        [detailX y detailWidth available-28]);
                    set(obj.Fields.SessionLog, 'Position', [x y historyWidth available]);
                    return
                end
                % The supported compact layout leaves three complete detail
                % rows and at least two history rows, including native borders.
                minimumBody = 3 * obj.RowHeight + 8;
                historyMinimum = 2 * obj.RowHeight + 8;
                bodyHeight = min(max(minimumBody, floor(available * 0.4)-28), ...
                    available-historyMinimum-36);
                detailHeight = 28 + max(1, bodyHeight);
                set(obj.Fields.LogDetailLabel, 'Position', [x y+detailHeight-22 width-62 20]);
                set(obj.Fields.CopyLogMessage, 'Position', [x+width-56 y+detailHeight-24 56 24]);
                set(obj.Fields.LogDetails, 'Position', [x y width detailHeight-28]);
                detailHeight = detailHeight + 8;
            end
            set(obj.Fields.SessionLog, 'Position', [x y+detailHeight width available-detailHeight]);
        end

        function renderDetails(obj)
            if obj.DetailEvent == obj.SelectedEvent && ...
                    obj.DetailHidden == obj.SelectionHidden
                return
            end
            if obj.SelectedEvent > 0 && ~obj.SelectionHidden
                entry = obj.Entries(obj.SelectedEvent);
                text = sprintf('%s [%s]\n%s', entry.timeUTC, upper(entry.level), entry.message);
                label = sprintf('Message %d', obj.SelectedEvent);
                set(obj.Fields.CopyLogMessage, 'Enable', 'on', 'UserData', text);
            else
                text = 'Selected message is hidden by the filter.';
                label = 'Selected message';
                set(obj.Fields.CopyLogMessage, 'Enable', 'off', 'UserData', '');
            end
            set(obj.Fields.LogDetailLabel, 'String', label);
            set(obj.Fields.LogDetails, 'Value', regexp(text,'\r\n|\n|\r','split'));
            scroll(obj.Fields.LogDetails,'top');
            obj.DetailEvent = obj.SelectedEvent;
            obj.DetailHidden = obj.SelectionHidden;
        end

        function [historyWidth, detailWidth] = contentWidths(obj)
            width = obj.Position(3);
            historyWidth = width; detailWidth = width;
            if width >= 700 && obj.SelectedEvent > 0
                historyWidth = floor((width-12) * 0.6);
                detailWidth = width-historyWidth-12;
            end
        end

        function inspect(obj)
            if ~obj.adoptNativeSelection(), return; end
            obj.update(obj.Entries, obj.Position);
        end

        function selected = adoptNativeSelection(obj)
            selected = false;
            rows = get(obj.Fields.SessionLog, 'Value');
            if isempty(rows) || isempty(obj.VisibleEvents), return; end
            rows = rows(rows >= 1 & rows <= numel(obj.VisibleEvents));
            if isempty(rows), return; end
            row = rows(end);
            previous = find(obj.VisibleEvents == obj.SelectedEvent, 1);
            if ~isempty(previous)
                % Multi-select mode permits an empty selection while following.
                % For modifier clicks, inspect the new endpoint, not the
                % largest index in MATLAB's sorted selection vector.
                [~, endpoint] = max(abs(rows - previous));
                row = rows(endpoint);
            end
            obj.SelectedEvent = obj.VisibleEvents(row);
            obj.SelectionHidden = false;
            obj.Following = false;
            obj.RevealSelection = true;
            selected = true;
        end

        function changeFollow(obj)
            obj.Following = logical(get(obj.Fields.FollowLatest, 'Value'));
            if obj.Following
                obj.SelectedEvent = 0;
                obj.SelectionHidden = false;
                obj.ForceLatest = true;
            end
            obj.update(obj.Entries, obj.Position);
        end

        function jump(obj)
            obj.Following = true;
            obj.SelectedEvent = 0;
            obj.SelectionHidden = false;
            obj.ForceLatest = true;
            obj.update(obj.Entries, obj.Position);
        end

        function changeFilter(obj)
            obj.Filter = get(obj.Fields.LogFilter, 'Value');
            obj.update(obj.Entries, obj.Position);
        end

        function copy(obj)
            text = get(obj.Fields.CopyLogMessage, 'UserData');
            if ~isempty(text), clipboard('copy', text); end
        end
    end
end


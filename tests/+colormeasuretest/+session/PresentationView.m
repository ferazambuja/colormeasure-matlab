classdef PresentationView < handle
    % Minimal injected view; the core tests do not depend on colormeasure.ui.
    properties (SetAccess = private)
        Figure
    end
    properties (Access = private)
        OnDelete
        CloseRequest
    end
    methods
        function obj = PresentationView(session, onDelete)
            obj.OnDelete = onDelete;
            obj.CloseRequest = @(~,~) session.hide();
            obj.Figure = figure('Visible', 'off', 'Name', 'Injected test view', ...
                'NumberTitle', 'off', 'CloseRequestFcn', obj.CloseRequest);
        end
        function obj=restore(obj)
            if ~isgraphics(obj.Figure)
                obj.Figure=figure('Visible','off','Name','Injected test view','NumberTitle','off', ...
                    'CloseRequestFcn',obj.CloseRequest);
            end
        end
        function delete(obj)
            if isgraphics(obj.Figure)
                delete(obj.Figure);
            end
            obj.OnDelete();
        end
    end
end

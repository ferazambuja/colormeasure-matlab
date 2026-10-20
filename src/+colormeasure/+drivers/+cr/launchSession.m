function session = launchSession(model,varargin)
%LAUNCHSESSION Thin shared-UI launcher; acquisition waits for explicit Measure.
session = colormeasure.ui.launchSession(colormeasure.drivers.cr.uiAdapter(model,varargin{:}));
end

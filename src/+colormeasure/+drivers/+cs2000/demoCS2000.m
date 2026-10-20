function varargout = demoCS2000(varargin)
%DEMOCS2000 Synthetic CS-2000 preview, with no real serial port enumeration.
%   colormeasure.drivers.cs2000.demoCS2000 opens an interactive session and waits for explicit Measure.
%   colormeasure.drivers.cs2000.demoCS2000('batch') saves two generated readings without a window.
%   colormeasure.drivers.cs2000.demoCS2000('gallery') opens twelve generated spectra; relaunch restores it.
%   Bare calls store colorMeasureCS2000DemoSession, colorMeasureCS2000DemoBatch or colorMeasureCS2000DemoGallery.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0,1); nargoutchk(0,1);
if nargout
    varargout{1} = colormeasure.drivers.cs2000.demoSession(varargin{:});
else
    colormeasure.drivers.cs2000.demoSession(varargin{:});
end
end

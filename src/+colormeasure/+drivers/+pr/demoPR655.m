function varargout = demoPR655(varargin)
% DEMOPR655 Open a live synthetic session; no physical serial port is opened.
%   demo = colormeasure.drivers.pr.demoPR655 returns immediately; colormeasure.drivers.pr.demoPR655('batch') runs two readings.
%   gallery = colormeasure.drivers.pr.demoPR655('gallery') shows twelve varied synthetic spectra in
%   the live UI. It saves to temporary storage and opens no physical port.
%   Repeated gallery calls restore the same session without adding readings.
%   The bare command stores colorMeasurePR655DemoSession. See the shared UI guide.
%   The bare batch command stores colorMeasurePR655DemoBatch instead.
%   The bare gallery command stores colorMeasurePR655DemoGallery instead.
%   Fernando Voltolini de Azambuja, 2026.
narginchk(0, 1); nargoutchk(0, 1);
if nargout
    varargout{1} = colormeasure.drivers.pr.demoSession(varargin{:});
else
    colormeasure.drivers.pr.demoSession(varargin{:});
end
end

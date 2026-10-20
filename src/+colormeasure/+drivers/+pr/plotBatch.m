function fig = plotBatch(measurements, fig)
% PLOTBATCH Overlay the complete batch with stable per-reading colors and labels.
%   Recreate the figure if it was closed between readings. DRAWSPECTRUM is
%   the axes-target helper for callers embedding a spectrum in another view.
%   Fernando Voltolini de Azambuja, 2026.

if nargin < 2 || isempty(fig) || ~isgraphics(fig, 'figure')
    fig = figure('Name', 'PR-655 measurement batch', 'NumberTitle', 'off');
end
ax = findobj(fig, 'Type', 'axes', 'Tag', 'PR655BatchSpectrum');
if isempty(ax), ax = axes('Parent', fig, 'Tag', 'PR655BatchSpectrum'); end
colormeasure.drivers.pr.drawSpectrum(measurements, ax(1));
drawnow;
end

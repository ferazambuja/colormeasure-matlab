% DEMODIRECTINSTRUMENTS Open a hardware-free PR, CR or CS measurement workflow.
% Open this file in MATLAB R2026b or newer and select Run. Keep src and
% resources beside it. No connected instrument or Python backend is needed.
% Read docs/beta-testing/README.md for the calibration, measurement and saving
% walkthroughs. Finish existing batches and restart MATLAB before changing
% installations; do not load another colormeasure copy in the same process.
% Fernando Voltolini de Azambuja, 2026.

% Leave empty for the picker, or use PR655, CR100, CR250, CR300 or CS2000.
directModel = '';
% Use interactive to collect readings yourself, or gallery for twelve examples.
directMode = 'interactive';
% Optional: also open twelve synthetic examples in a separate results window.
directShowGallery = false;
directGallery = [];
% Optional guided chart: classic, sg or custom; empty keeps free samples.
% Chart practice uses interactive mode. Custom size is [rows columns], <=140 cells.
directChartPreset = '';
directChartName = 'Practice chart';
directChartSize = [2 3];

if ~isempty(directChartPreset) && ~strcmpi(directMode, 'interactive')
    error('ColorMeasure:DemoChartMode', ...
        'Set directMode to interactive for guided chart practice.'); %#ok<UNRCH> Editable defaults can enable this guard.
end

demoProjectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(demoProjectRoot, 'src'));
directDemo = colormeasure.demo(directModel, directMode);

if ~isempty(directDemo)
    if ~isempty(directChartPreset)
        if isempty(fieldnames(directDemo.chart))
            if strcmpi(directChartPreset, 'custom')
                directChartDefinition = colormeasure.chart.definition('custom', ...
                    directChartName, directChartSize(1), directChartSize(2)); %#ok<UNRCH> Enabled by the custom preset.
            else
                directChartDefinition = colormeasure.chart.definition(directChartPreset);
            end
            directDemo.startChart(directChartDefinition);
        else
            fprintf('Existing chart retained. Start a new batch to use another chart.\n');
        end
    end
    if strcmp(directDemo.catalogIdentity.mode, 'gallery')
        directGallery = directDemo;
    elseif directShowGallery
        directGallery = colormeasure.demo(directDemo.catalogIdentity.model, 'gallery'); %#ok<UNRCH>
    end
    fprintf(['Synthetic demo only; no instrument is connected.\n' ...
        'For free samples, enter a name and notes, then select Measure.\n' ...
        'Inspect Data, Compare, Color and Settings; close/reopen to restore the batch.\n' ...
        'Finish batch saves MAT and CSV. New batch starts another collection.\n' ...
        'Inspect directDemo.measurements and directDemo.files in the workspace.\n' ...
        'Use directDemo.show() to return to your practice window.\n']);
    if ~isempty(fieldnames(directDemo.chart)) && (directDemo.finished || directDemo.finishing)
        fprintf(['This batch is closed to acquisition. Continue chart… previews a linked new batch; ' ...
            'New batch starts a separate collection.\n' ...
            'Continuation needs established instrument identity and XYZ scale. ' ...
            'If these Demo facts are unavailable, Start new pass keeps history and starts coverage at zero.\n']);
    elseif ~isempty(fieldnames(directDemo.chart))
        fprintf(['Guided chart: select a coordinate, add notes, then select Measure.\n' ...
            'Use Readings to review acquired rows; Chart/Plots switches the main workspace.\n' ...
            'Retry keeps earlier attempts. Historical references are subdued; qualified measured colors replace them.\n' ...
            'Unavailable colors stay neutral with status and a reason; inspect Reference and Measured separately.\n' ...
            'Each cell keeps an invented base target; repeats add bounded brightness variation.\n' ...
            'Pause and resume within this live session. Plain MATLAB load only inspects saved data.\n' ...
            'Continue chart… previews a saved file or retained batch before explicit linking.\n' ...
            'Same-pass continuation needs established identity and XYZ scale; otherwise start a new pass.\n' ...
            'Finish incomplete retains missing cells; Finish writes chart-selected.csv after MAT.\n' ...
            'Use Retry save or Another folder for save failures without measuring again.\n' ...
            'Inspect directDemo.chart and read docs/beta-testing/README.md.\n']);
    end
    if ~isempty(directGallery)
        fprintf(['directGallery contains %d synthetic readings for Data, Compare and Color.\n' ...
            'Select rows and change the gallery instrument to inspect other result types.\n' ...
            'Use directGallery.show() to restore its window; files use a temporary demo folder.\n'], ...
            numel(directGallery.measurements));
    end
end

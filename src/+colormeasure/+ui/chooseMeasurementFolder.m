function folder = chooseMeasurementFolder(previous)
% CHOOSEMEASUREMENTFOLDER Explain batch saving before the native folder picker.
%   Returns the selected parent folder, or 0 when either dialog is cancelled.
%   The introduction remains readable when the OS ignores the picker's title.
%   Fernando Voltolini de Azambuja, 2026.
if isempty(previous) || ~isfolder(previous), previous = pwd; end
folder = 0;
answer = questdlg({ ...
    'Choose where to save this measurement batch.', ...
    'Each batch gets its own subfolder with MAT files and supported CSV exports.', ...
    'Selecting a folder does not start a measurement.'}, ...
    'Measurement save folder', 'Choose folder', 'Cancel', 'Choose folder');
if ~strcmp(answer, 'Choose folder'), return, end
folder = uigetdir(previous, 'Choose where to save measurement batches');
end

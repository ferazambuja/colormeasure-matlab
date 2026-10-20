function adapter = adapter()
% ADAPTER Instrument-specific acquisition, provenance and CSV columns.
%   The shared measurement session has no dependency on PR spectral fields.
%   Fernando Voltolini de Azambuja, 2026.
timeout = 300;
adapter = struct('key', 'PR655', 'label', 'PR-655 measurements', ...
    'listPorts', @serialportlist, ...
    'connect', @(port) colormeasure.drivers.pr.PR655(port, 'Timeout', timeout), ...
    'read', @readMeasurement, 'release', @colormeasure.drivers.releaseInstrument, ...
    'toTable', @colormeasure.drivers.pr.batchTable);
adapter.catalog = struct('model', 'PR655', 'mode', 'measure');
% Retained with the batch and compared on restoration, like the other families.
adapter.configuration = struct('model', 'PR655', 'Timeout', timeout);
adapter.configurationSummary = sprintf('PR-655; measurement (M5) timeout %.6g s; no automatic retry', timeout);
adapter.preparation = colormeasure.drivers.pr.preparation();
end

function reading = readMeasurement(instrument)
reading = instrument.measure();
% The driver owns XYZ and its method provenance; retain both unchanged.
stored = colormeasure.drivers.pr.storedText();
reading.spectralUnits = stored.spectralUnits;
end

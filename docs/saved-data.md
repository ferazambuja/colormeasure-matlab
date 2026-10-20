# Saved data: files, structure and MATLAB examples

This guide covers direct PR, CR and CS-2000 instrument batches.
Use **measurements.mat** as the complete batch record. Use CSV for a convenient
table in MATLAB or a spreadsheet. Loading saved data does not open an instrument
or require the measurement window.

## What gets saved, and when

Choose a measurement destination in the app. The first reading or accepted chart
setup creates a new timestamped folder; a new batch gets a different folder.

```text
Your chosen folder/
  batch_20261015_143208_013/
    measurements.mat
    measurements.csv
    chart-selected.csv     # guided charts only
```

| File | Written when | Use it for |
| --- | --- | --- |
| `measurements.mat` | After each complete reading, chart setup/progress/edit and Finish | Full readings, settings/metadata, batch information and chart history |
| `measurements.csv` | Finish batch; refreshed after eligible edits to a finished batch | Acquisition-order numeric/text table |
| `chart-selected.csv` | After successful chart progress saves | Selected result or missing status for each chart cell and pass |

**Finish batch** finalizes the batch and exports CSV. A current MAT may exist
before the acquisition-order CSV. If saving fails, use **Retry save** or
**Another folder** before closing MATLAB.
Closing the window only hides it; it does not finish the batch or create a new one.

Record physical target, geometry, illumination and other experimental conditions
in the sample notes; they are not inferred automatically.

## Inside measurements.mat

The file has two top-level variables:

```matlab
saved = load('measurements.mat', 'measurements', 'batchInfo');
measurements = saved.measurements;   % struct array: one complete reading per element
batchInfo = saved.batchInfo;         % scalar struct describing the batch
```

A chart can be saved before it has readings, so `measurements` can be empty.
Do not combine records from different instruments or experiments by assuming
their units, observer or XYZ scale match.

| Reading field | Meaning |
| --- | --- |
| `name`, `notes` | Sample annotations; repeated names are allowed |
| `XYZ` | Three retained tristimulus values; inspect their source and units |
| `lambda` | Wavelength vector in nm; empty for CR-100 |
| `radiance` (PR) or `spectralData` (CR/CS) | Spectrum aligned with `lambda`; CR-100 has no spectrum |
| `deviceType`, `port` | Instrument model/identity label and selected serial port |
| `startedAtUTC`, `completedAtUTC`, `durationSeconds` | Host acquisition timing, not a claim about physical exposure duration |
| `startedAtLocal`, `completedAtLocal`, `localTimeZone` | Local timestamps and captured time zone |
| `instrumentSettings` | Capture settings, before/after readbacks and overrides when supported |
| `instrumentMetadata` | Device-reported identity/setup reports when the driver supplies them |
| `driverSnapshot` (CR/CS) | Preserved native driver record |
| `isSynthetic` | Explicit generated-data flag; keep demo and physical data separate |

Fields vary by instrument. Inspect `fieldnames(measurements)` and the saved
`xyzMethod`, `xyzUnits`, `spectralQuantity`, `spectralUnits`, observer and status
fields where supplied. PR also retains its native units code and XYZ-method
provenance. Preserve empty, unavailable and NaN values; do not turn them into zero.
CSV does not contain every raw report or native field retained in MAT.

`batchInfo` includes:

- `measurementCount`, instrument label and adapter `catalogIdentity`.
- Acquisition start/completion times and `elapsedSeconds`, including gaps between
  readings; separate session-open timestamps are also retained.
- `acquisitionComplete`, which describes acquisition completion, not CSV success
  or instrument calibration.
- Host-requested `configuration`, distinct from device-reported settings.
- `segmentId`, connection-cleanup/continuation guard and recorded cleanup declarations.
- `readingAnnotations` and `annotationRevision`, preserving annotation edit history.
- `chart` for guided runs: definition, cells, passes, attempts, selected results,
  references/context and linked source records; `pendingSample` also exists there.

The top-level `measurements` array holds this batch's local acquisitions. Continued
charts also retain inherited source records inside the chart snapshot. A selected
chart export can represent those sources: preserve its segment, pass and cell
identity, rather than joining unrelated files by sample name or row number.
A chart CSV is a selected summary, not the full attempt history. Keep the MAT.

## Load a batch into your script

This example needs only base MATLAB. Select `measurements.mat` from your batch folder.

```matlab
[file, folder] = uigetfile('measurements.mat', 'Choose a saved batch');
if ~isequal(file, 0)
    saved = load(fullfile(folder, file), 'measurements', 'batchInfo');
    readings = saved.measurements;
    batchInfo = saved.batchInfo;
    if ~isempty(readings)
        names = string({readings.name}).';
        XYZ = vertcat(readings.XYZ);       % N-by-3; units/scale stay in the records
        disp(table(names, XYZ));
        firstReading = readings(1);       % all original fields remain available
    end
end
```

The download includes `examples/loadSavedBatch.m`, a runnable picker example
that also handles an empty chart batch. Its workspace variables include
`measurements`, `batchInfo` and `readingSummary`. You can copy the loading lines
into your existing analysis script; setup does not need to launch the app.

## Plot one saved spectrum

After loading `readings` above:

```matlab
if ~isempty(readings)
    r = readings(1);
    if isempty(r.lambda)
        disp('This reading has no spectrum.');  % for example, CR-100
    else
        if isfield(r, 'radiance')
            spectrum = r.radiance;             % PR
        else
            spectrum = r.spectralData;         % CR-250/300 or CS-2000
        end
        plot(r.lambda(:), spectrum(:));
        xlabel('Wavelength (nm)');
        ylabel('Spectral reading (see saved units)');
        title(string(r.name));
    end
end
```

Use the saved quantity/units and setup to label a scientific plot. Do not treat
radiance as reflectance, or normalize each XYZ row before quantitative analysis.

## Import CSV correctly

Spectral CSVs use **long format**: one row per wavelength per reading. XYZ,
name and timing repeat across those rows. CR-100 uses one row per reading and
explicitly has no spectrum. `height(csvRows)` is therefore not the reading count;
use `MeasurementIndex` within that file.

```matlab
[file, folder] = uigetfile('*.csv', 'Choose measurements.csv');
if ~isequal(file, 0)
    csvRows = readtable(fullfile(folder, file), ...
        'Delimiter', ',', 'NumHeaderLines', 0, 'ReadVariableNames', true, ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    firstRows = csvRows(csvRows.MeasurementIndex == 1, :);
    disp(firstRows);
end
```

Common columns include `MeasurementIndex`, `MeasurementName`, `Wavelength_nm`
and `SpectralReading`. XYZ columns differ intentionally: PR uses
`Computed_X/Y/Z`, CR uses `X/Y/Z` plus `Instrument_X/Y/Z`, and CS uses
`Raw_X/Y/Z` with source and unit columns. Read the column names; do not assume
identical headers or units across families. Quoted text and line breaks are
preserved. Spreadsheet formula-like text is escaped at CSV export; the MAT
keeps the original text.

For `chart-selected.csv`, use the same explicit `readtable` options, then inspect
`PassId`, `SegmentId`, cell identity, `Status` and `UnavailableReason`. This is a
separate chart table, not the acquisition-order CSV above. A missing, stale or
identity-only chart CSV does not imply complete numerical chart results.

## Share a device test

Run `testLabInstrument` from the extracted folder and follow the prompts.
Open an [instrument test issue](https://github.com/ferazambuja/colormeasure-matlab/issues/new?template=instrument-test.yml)
and attach the ZIP from **Desktop → ColorMeasurement-Reports**, even if the
check fails. MATLAB prints its location and the feedback link. Attachments are
public; the [feedback guide](feedback.md) lists what the ZIP contains and how
to report without it.

After a passed check, select **New batch** in the reopened window to take
your own readings.

## Separate analysis files

A Color-view **Export analysis MAT...** saves derived results and their source
readings/references/assumptions in a separate new MAT. It does not change the
acquired measurement values or replace `measurements.mat`. Live comparison
results are likewise separate analysis; save them explicitly if needed.

For more detail, see the [session API](session/README.md) and
[instrument guides](../README.md#use-the-drivers-in-your-scripts).

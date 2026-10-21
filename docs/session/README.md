# Collect batches from MATLAB scripts

A Session collects named readings from one instrument and saves MAT/CSV files.
Use it when you want batch saving and recovery in your own script. For a
single driver call, start with the [instrument guides](../../README.md#use-the-drivers-in-your-scripts).
For clicking through measurements, use the [app guide](../ui/README.md).

## Start a session

Use MATLAB **R2026b or newer**, with the JVM enabled. From the extracted download
or repository folder, run `setupColorMeasure` once to add **src** to the path.
Choose an existing save destination:

```matlab
destination = uigetdir(pwd, 'Choose a measurement destination');
if isequal(destination, 0), return; end
adapter = colormeasure.drivers.cr.adapter('CR250');
session = colormeasure.session.Session(adapter, destination);
% If several ports were found, select the instrument's port explicitly:
% session.selectPort('/dev/cu.your-instrument');
session.measure('Sample 001', 'Reference tile');
% Reposition the target before the next call.
session.measure('Sample 002', 'Second sample');
session.finish();
readings = session.measurements;
```

Constructing the session lists ports but takes no reading. Each `measure` call
is synchronous. One available port is selected automatically; with several,
use `session.ports` and `session.selectPort(port)`.

| Instrument | Core acquisition adapter |
| --- | --- |
| PR-655 / tentative PR-670 | `colormeasure.drivers.pr.adapter()` |
| CR-100, CR-250, CR-300 | `colormeasure.drivers.cr.adapter('CR100')`, `adapter('CR250')` or `adapter('CR300')` in that namespace |
| CS-2000 / CS-2000A | `colormeasure.drivers.cs2000.adapter()` |

These core adapters preserve the instrument's acquisition settings. The app
uses each family's **uiAdapter**, which applies an automatic acquisition recipe
and supports staged overrides. See [instrument settings](#instrument-settings)
when choosing which behavior your script needs.

A successful `session.measure()` returns true when a complete reading was
retained. Saving and connection cleanup are separate: inspect
`session.needsRecovery`, `session.chartIoUnconfirmed` and `session.savedCount`.
Do not take another reading merely to recover saving.

## Interactive launchers

To open the app, run [openColorMeasure.m](../../openColorMeasure.m). With **src**
already on the path, you can also request a session handle:

```matlab
session = colormeasure.app('CR250');
```

Model keys are `PR655`, `CR100`, `CR250`, `CR300` and `CS2000`. Omitting the model
opens a picker. Opening or restoring the window takes no reading.

## Session API

Use the methods below to change state. `session.measurements` and `session.info`
return ordinary structs for analysis; changing a copied struct does not update
the live session.

### Actions

| Method | Action |
| --- | --- |
| `measure()` or `measure(name, notes)` | Take one reading, release the connection and attempt to save MAT |
| `setSample(name, notes)` | Set the next sample's annotations without measuring |
| `editReading(index, name, notes)` | Correct an acquired reading's annotations and save; index is its acquisition-order row |
| `selectPort(port)` | Choose a serial port; identity is checked on connection |
| `refreshPorts()` | Refresh the port list without opening a connection |
| `setInstrumentSettings(overrides)` | Stage settings for an adapter with settings support; `struct()` clears overrides |
| `refreshInstrumentSettings()` | Read settings without measuring, when the adapter supports it |
| `finish()` | End acquisition, finalize MAT and export CSV |
| `retrySave()` | Retry failed persistence without measuring |
| `saveElsewhere(folder)` | Save the retained batch in a new subfolder of another destination |
| `retryDirectCleanup()` | Retry an available connection owner's release, then save |
| `show()` | Open or restore this session's window |

Editing preserves acquired values and original annotations. For a finished
batch it also refreshes CSV and keeps acquisition closed. A failed save retains
the edit in memory. Resolve it before closing MATLAB.

The pending name and notes stay unchanged after a failed reading. A successful
reading advances the default sample name and clears its notes. Actions that
conflict with an operation in progress are refused.

### Read session state

| Property | Contents |
| --- | --- |
| `measurements` | Readings acquired in this batch, as a struct array |
| `info` | Batch timing, count, configuration, annotations and chart history |
| `name`, `notes`, `port`, `ports` | Next sample, chosen port and available ports |
| `files` | `folder`, `mat`, `csv`, `chartCsv` and `previousFolders` |
| `savedCount` | Readings in the most recent successful MAT save |
| `busy`, `saving` | An action is running; `saving` specifically describes writing MAT |
| `finishing`, `finished` | Acquisition is closing or has finished |
| `status`, `needsRecovery` | Status text and whether saving or connection cleanup needs attention |
| `chartIoUnconfirmed`, `directCleanupCanRetry` | Cleanup uncertainty and availability of an owned cleanup retry |
| `configuration`, `catalogIdentity` | Host-requested connection options and adapter identity |
| `settingsCatalog`, `settingsOverrides`, `settingsSnapshot`, `lastSettingsReceipt` | Available controls, staged overrides, last readback and last application result |
| `chart` | Chart state, or empty before setup |
| `log` | Event structs with `timeUTC`, `level` and `message` |

Properties remain readable after Finish. `delete(session)` destroys the handle;
preserve unsaved data before doing so. The event log is not automatically part
of the batch MAT; see [diagnostics](#diagnostics-and-provenance) to save it.

### Instrument settings

The core `adapter()` examples above do not add automatic settings. To use the
same recipe and controls as the app in a script, use a **uiAdapter**:

```matlab
adapter = colormeasure.drivers.cr.uiAdapter('CR250');
session = colormeasure.session.Session(adapter, destination);
session.refreshInstrumentSettings(); % Connect, read settings and release; no reading.
controls = session.settingsCatalog;
observedSettings = session.settingsSnapshot;
% Build overrides using the setting IDs and values in the instrument guide.
% session.setInstrumentSettings(overrides);
session.measure('Sample 001', '');
session.setInstrumentSettings(struct()); % Clear overrides for subsequent readings.
```

Equivalent factories are `colormeasure.drivers.pr.uiAdapter()` and
`colormeasure.drivers.cs2000.uiAdapter()`. The automatic recipe runs before each
reading even when overrides are empty. Accessory and calibration selections
remain unchanged unless explicitly overridden.

Readback is a dated observation. Staging overrides does not contact the device;
capabilities and coupled settings are checked again when applying them. If
application fails, no reading starts, but some settings may already have changed.
Inspect `lastSettingsReceipt` and the log before trying again.

See the [PR](../drivers/pr/settings.md), [CR](../drivers/cr/settings.md) and
[CS-2000](../drivers/cs2000/settings.md) settings references for IDs and values.

## Guided chart commands

A chart uses the same acquisition adapter and Session as individual samples:

```matlab
definition = colormeasure.chart.definition('classic');
% Other choices: definition('sg') or definition('custom', 'Practice chart', 2, 3).
session.startChart(definition);
session.selectChartCell(2, 2); % B2: row first, column second.
session.measure();
```

Setup takes no reading. Custom grids allow up to 140 cells. While the chart is
active, sample names follow canonical coordinates; use `setSample` to add notes
with that coordinate. Rotation changes display orientation, not patch identity.

| Method | Action |
| --- | --- |
| `startChart(definition)` | Start guided association; earlier individual readings stay outside chart coverage |
| `selectChartCell(row, column)` | Choose the next patch |
| `rotateChart(degrees)` | Set orientation to 0, 90, 180 or 270 degrees |
| `pauseChart()` / `resumeChart()` | Pause or resume patch association in this session |
| `acceptChartContext()` | Accept a staged setup change by starting an empty new pass |
| `finish(AllowIncompleteChart=true)` | Explicitly finish with missing patches |

A successful reading selects its attempt and advances to the next unmeasured
cell. A failed retake keeps the earlier successful selection. A pass groups
readings from one setup; material settings changes require a new pass. Ordinary
`finish()` requires complete coverage in the active pass.

The grid tracks patch names and attempts. Direct radiance/luminance readings do
not become reflectance or measured chart-color matches. See the
[chart walkthrough](../ui/README.md#measure-a-chart-one-patch-at-a-time).

### Continue a chart in a new session

The app's continuation dialog is the simplest route. It also works from a script
with a ready target Session and **src** on the path:

```matlab
target.show();
[continued, action] = colormeasure.ui.continueChart( ...
    target, '/path/to/saved/measurements.mat');
if ~isempty(continued)
    state = continued.chart;
    [reading, origin] = continued.chartReading(state.activePass, 1);
end
```

Cancel returns empty outputs. Acceptance creates a linked batch without taking
a reading. **Continue selected pass** keeps compatible coverage; **Start new
pass** keeps history and starts empty coverage. The dialog explains differences,
unknown conditions and required cleanup. See the
[window instructions](../ui/README.md#continue-a-saved-or-finished-chart).

Inherited readings stay in the saved chart's source records, rather than being
appended to `continued.measurements`. `chartReading(passIndex, cellIndex)` returns
a selected reading and its `origin`, including original `segmentId`,
`readingIndex` and `inherited` flag. Cell indices are one-based, canonical row
order, independent of rotation. An unread cell returns empty structs.

Never index the new batch's `measurements` with an inherited `readingIndex`.
The new MAT retains the required source records, so it can move without the
original folder or session.

For custom integrations, these lower-level methods implement the same workflow:

| Method | Use |
| --- | --- |
| `prepareChartContinuation(source, PassId=..., Declarations=...)` | Preview a saved MAT or live Session without accepting it |
| `freshChartContinuationSession()` | Create a fresh receiver after the operator chooses to continue |
| `[saved, continued] = receiver.acceptChartContinuation(preview, Action=...)` | Accept `'continue'` or `'new-pass'`, recheck the preview and save the linked batch |

Use the UI helper for visible windows. Lower-level callers must retain a receiver
when saving fails and recover it with `retrySave()` or `saveElsewhere(folder)`;
do not repeat acceptance. A changed source or target needs a fresh preview.
The acceptance options include `Declarations`, `AcknowledgeVersionChange`, and,
when the preview requires cleanup confirmation, `ConfirmConnectionClosed`,
`ConfirmInstrumentIdle` and `CleanupDeclaration`. Confirm only facts the operator
has checked; declarations cannot override reported differences or establish
calibration. Acceptance declarations must match the preview.

Continuation requires a supported, internally consistent saved chart. The
current format is version **5**, with at most **16 inherited segments**. At that
limit, start a separate chart for further acquisition. The disk loader refuses
files whose `measurements` and `batchInfo` variables total over **256 MiB** in
MATLAB's file metadata. Plain `load` still supports inspection of ordinary
structs; it does not create a live connection.

## Saved data

The [saved-data guide](../saved-data.md) describes the MAT fields, CSV columns,
timing and import examples. Each batch creates a unique timestamped subfolder
of the selected destination.

| File | Written when |
| --- | --- |
| `measurements.mat` | After completed readings, chart setup/edits/continuation and Finish; a retained chart also saves its operation state before instrument I/O |
| `measurements.csv` | At Finish, and after eligible edits to a finished batch |
| `chart-selected.csv` | After successful chart progress saves |

Use MAT as the complete record. Relative destinations resolve when selected;
later changes to MATLAB's Current Folder do not move the batch. For another
Windows drive, use the folder picker or a full path such as `D:\Measurements`.

### Chart records and selected-reading CSV

`batchInfo.chart` contains the definition, cells, passes, attempts, selected
reading references, annotations and linked source records. The top-level
`measurements` array contains this batch's acquisitions only.

`chart-selected.csv` has one row per cell per pass, including missing cells.
Important columns are:

| Columns | Meaning |
| --- | --- |
| `RunId`, `PassId`, `SegmentId` | Chart, setup pass and selected reading's source batch |
| `Coordinate`, `Row`, `Column` | Fixed patch position |
| `SourceLocation`, `SourceId`, `ExportId`, `PatchNumber`, `PatchName` | Preset mapping where supplied |
| `Status`, `SelectedAttempt`, `ReadingIndex` | Selection and link to the original segment's reading |
| `ReadingName`, `ReadingNotes`, `OriginalName`, `OriginalNotes` | Current and original annotations |
| `X`, `Y`, `Z`, `Quantities`, `Units`, `Context`, `UnavailableReason` | Available selected values, measurement context and explanations |

Use `PassId` and `Coordinate` together to select chart results. `SegmentId` and
`ReadingIndex` identify the original reading. Missing numeric CSV values are
empty, not zero. Full spectra and unselected attempts remain in MAT.

A chart CSV can be current but incomplete or contain unavailable values. Check
`Status` and `UnavailableReason` as well as `session.chart.csvCurrent`. That
property reflects the last export check, not continuous monitoring of the file.
If a later update fails, `files.chartCsv` keeps the last successful path, which
may now be stale. Follow the log and recovery actions.

### CSV text and spreadsheet formulas

CSV export prefixes text with an apostrophe when its first non-whitespace
character is `=`, `+`, `-` or `@`, or it starts with a tab or line break. This
helps spreadsheets treat it as literal text. For example, `-ND filter` becomes
`'-ND filter`. Numeric columns are unchanged, and MAT retains original text.

### Export a saved batch

To create CSV from a MAT without connecting an instrument, choose the matching
adapter. For CR-250:

```matlab
[file, folder] = uigetfile('measurements.mat', 'Choose a saved batch');
if ~isequal(file, 0)
    saved = load(fullfile(folder, file), 'measurements', 'batchInfo');
    adapter = colormeasure.drivers.cr.adapter('CR250');
    colormeasure.session.exportCsv(saved.measurements, saved.batchInfo, ...
        fullfile(folder, 'measurements_export.csv'), adapter.toTable);
end
```

Use the corresponding PR, CR model or CS-2000 adapter for other batches. The MAT
is unchanged. Choose a new CSV name to keep an earlier export; this command
replaces an existing destination after the new file is successfully written.

## Save recovery

If creating the batch folder fails before acquisition, choose a writable
folder with `session.saveElsewhere(folder)`, then retry the reading.

If MAT saving fails after acquisition, the completed reading stays in memory.
Compare `session.savedCount` with `numel(session.measurements)`, then use
`session.retrySave()` or `session.saveElsewhere(folder)` before closing MATLAB.

A CSV-only retry uses the saved MAT without another measurement or MAT rewrite.
Relocation keeps earlier files and records their folders in `files.previousFolders`.
A finished batch stays closed to acquisition during recovery.

A selected-chart CSV problem does not itself block acquisition. A changed file
is preserved; use another folder when retry cannot safely update it. MAT remains
the complete chart record.

### Unconfirmed connection cleanup

`session.chartIoUnconfirmed` applies to both ordinary and chart batches. It can
follow a failed connection attempt or release and prevents further acquisition
or settings readback until resolved.

If `session.directCleanupCanRetry` is true, call `session.retryDirectCleanup()`.
A release failure throws and keeps cleanup unresolved. If release succeeds, the
return value reports whether saving succeeded; a false result needs save recovery.

If no connection owner remains available, first check that no MATLAB batch or
other program uses the port and that the instrument is idle. Then record those
checks:

```matlab
saved = session.confirmChartIoStopped( ...
    ConfirmConnectionClosed=true, ConfirmInstrumentIdle=true, ...
    Declaration='Describe how you checked the closed connection and idle instrument.');
```

Replace the example explanation with what you actually checked. The explanation
must be nonblank and at most 2,048 UTF-16 code units. The method records a
declaration, not an instrument query. If saving returns false, recover saving.
The app offers the same workflow through **Confirm cleanup...**.

## Diagnostics and provenance

Each reading retains host timing, port, MATLAB version and native device data:

| Instrument | Identity and metadata |
| --- | --- |
| PR-655/670 | Verified model; optional identity/setup/exposure reports depend on the [metadata setting](../drivers/pr/api.md#device-reported-metadata) |
| CR-100/250/300 | Model, instrument ID/serial, firmware and capture metadata |
| CS-2000/2000A | Model, variation, serial, raw identity and capture metadata; firmware is not queried |

`instrumentMetadata` holds driver-reported metadata. `instrumentSettings` is the
separate settings-application receipt; it is empty when the adapter has no
settings hook. CR and CS also retain their native records in `driverSnapshot`.
Host-requested `batchInfo.configuration` does not prove actual exposure settings.

Record target, geometry, lighting and other setup details in notes. To save the
current log alongside diagnostics in a separate file:

```matlab
diagnostics = struct('measurements', session.measurements, ...
    'batchInfo', session.info, 'log', session.log, 'files', session.files);
[file, folder] = uiputfile('*.mat', 'Save diagnostics', 'measurement_diagnostics.mat');
if ~isequal(file, 0)
    save(fullfile(folder, file), 'diagnostics');
end
```

Choose a different filename from `measurements.mat`. Diagnostics reflect the
moment saved. Files and logs can include serial numbers and local paths;
review them before sharing publicly.

## Window integration

To add a window and the app's automatic settings to a custom session:

```matlab
io = colormeasure.ui.services();
session = colormeasure.session.Session(colormeasure.drivers.pr.uiAdapter(), destination, io);
session.show();
```

Standard launchers retain one batch per model. Closing the window hides it;
relaunching restores it. **New batch** keeps the connection options.

To change serial or timeout options, finish the batch, preserve its saved data,
call `delete(session)` and launch again with the family's supported options.
A launcher refuses to reuse a retained batch with different connection options.
See [adapter integration](adapters.md) for custom acquisition and presentation.

## Compare retained readings

Use the matching family's `viewData` adapter. This PR example compares readings
1 and 2 with reading 3 as their common Lab white:

```matlab
data = colormeasure.drivers.pr.viewData(session.measurements);
comparison = colormeasure.analysis.compareReadings(data, 1, 2, 3);
comparison.deltaE00
comparison.spectralRMS
```

Or choose a preset white with Y on the samples' XYZ scale:

```matlab
white = struct('illuminant', 'D65', 'Y', 100); % Example: white Y really is 100.
comparison = colormeasure.analysis.compareReadings(data, 1, 2, white);
```

Omit the fourth argument for metrics that do not need Lab white. Returned
results include Lab, signed B − A differences, reference metadata, spectral
support and separate explanations for unavailable metrics. Save the result
explicitly if needed; comparisons do not change measurement files.

For eligible CR-100 or CS data with unknown XYZ scale, the app offers an explicit
same-scale confirmation. The command API accepts an optional fifth declaration
struct with `confirmed`, `referenceIndex`, `sampleIndex`, `white` and
`declaredAtUTC`. Its indices and white must match the current comparison; it
cannot override known incompatible data. No declaration is added automatically.
See the [comparison instructions](../ui/README.md#compare-two-readings) and
[calculation reference](color-science.md).

## Troubleshooting after an update

Finish and save active batches before updating, then restart MATLAB. Existing
session objects can retain old classes and callbacks. Avoid `clear all` or
`clear classes` during an active batch.

If `Measurement:SessionCompatibility` appears, preserve unsaved readings before
restarting. If it persists, check for multiple installations:

```matlab
which('colormeasure.session.Session', '-all')
which('colormeasure.ui.launchSession', '-all')
```

## Tests

The [software testing reference](../testing/workflow.md) explains automated
checks. The [feedback guide](../feedback.md) is the shorter route for trying a
connected instrument and reporting results.

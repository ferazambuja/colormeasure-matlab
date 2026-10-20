# Instrument adapters and presentation services

This reference describes the direct serial adapter and presentation service
contracts for PR, CR and CS-2000 integrations and custom interfaces. For acquisition and saved data, use the
[session guide](README.md); for window controls, use the
[window guide](../ui/README.md).

## Acquisition and export

An adapter is a struct with these acquisition and export fields. See
[colormeasure.drivers.pr.adapter](../../src/+colormeasure/+drivers/+pr/adapter.m),
[colormeasure.drivers.cr.adapter](../../src/+colormeasure/+drivers/+cr/adapter.m), and
[colormeasure.drivers.cs2000.adapter](../../src/+colormeasure/+drivers/+cs2000/adapter.m).

| Field | Contract |
| --- | --- |
| `key`, `label` | Stable batch identity and readable session label; different CR models and synthetic sessions use distinct keys |
| `listPorts(mode)` | Serial names for `'all'` or `'available'` |
| `connect(port)` | Create and initialize the instrument connection |
| `read(instrument)` | Return one complete scalar struct; throw on acquisition failure |
| `release(instrument)` | Release the connection after success or failure. Return normally only when host I/O cleanup is confirmed; otherwise throw so the stop guard stays set. |
| `toTable(measurements, batchInfo)` | Return the table used for CSV export. Each reading carries the fields the session adds (sample name, notes, port, UTC and local times with the zone, duration and MATLAB version), and `batchInfo` is the batch record |
| `configuration` (optional) | Struct of host-requested options, retained with the batch and checked on restoration |
| `configurationSummary` (optional) | Readable connection summary added to the session log on opening |
| `catalog` (optional) | `model` and `mode` naming the `colormeasure.ui.deviceCatalog` entry this adapter belongs to, so the window selector and `switchDevice` recognise the batch without a key convention |

Bundled native adapters declare `catalog.model` and `catalog.mode='measure'`.
Their demos declare `interactive`, `batch` or `gallery`. This identifies the
launcher entry, not the connected meter's reported identity or measurement
mode. Batch keys remain storage/registry identities and are not parsed to
determine the selector's model or mode.

The session constructor checks these fields with
`colormeasure.session.validateAdapter` before any I/O, so a missing or mistyped
hook fails with `Measurement:AdapterContract` when the session is created, not
at the first reading or export. Each acquired reading is checked with
`colormeasure.session.validateReading` (`Measurement:InvalidReading`: one scalar
struct of ordinary data whose fields match the batch), and each `viewData`
result with `colormeasure.session.validateViewData` (`Measurement:InvalidViewData`).
The bundled adapters are exercised against these checks by
`tests/workflow/testAdapterContract.m`.

### Connection failure and cleanup

For a retained chart, Session saves its I/O intent before calling `connect`.
A connection exception does not by itself establish that the port stayed closed
or was released. The connection owner may attach the shared cleanup witness
only after proving that no port was opened or confirming cleanup of its owned
port. The original exception remains the failure reported to the caller.

[`confirmedConnectionFailure`](../../src/+colormeasure/+drivers/confirmedConnectionFailure.m)
adds the typed cause:

```matlab
problem=addCause(problem,MException('Measurement:ConnectCleanupConfirmed', ...
    'The connection owner confirmed no outstanding host I/O after this refusal.'));
```

An empty handle, a cleared field or a caught constructor error is insufficient.
Unmarked failures retain `session.chartIoUnconfirmed` and prevent another
acquisition or continuation. A returned connection is instead released through
the normal Session owner; confirmed release clears its retained intent. If
automatic cleanup remains unconfirmed and no returned connection owner remains
accessible, an explicit
[operator cleanup declaration](README.md#unconfirmed-connection-cleanup)
is a separate recovery route after the checks have been completed. It cannot
bypass an owner that remains available to retry cleanup.
This witness concerns host I/O cleanup, not physical instrument readiness or
measurement validity.

For a returned connection, Session treats the release hook's normal return as
cleanup confirmation. A warning-only destructor is therefore insufficient.
The bundled native adapters use
[`releaseInstrument`](../../src/+colormeasure/+drivers/releaseInstrument.m),
which checks the connection owner's explicit result before destroying its handle:

```matlab
closed=instrument.Disconnect();
assert(isequal(closed,true),'Measurement:ConnectionCleanupUnconfirmed', ...
    'The instrument connection owner could not confirm connection cleanup.');
delete(instrument);
```

An unconfirmed release preserves any complete reading, the returned owner and
the cleanup guard. Session does not automatically repeat a failed release.
`session.retryDirectCleanup()` explicitly retries only that retained owner's
release. After successful release, a failed save uses ordinary save recovery;
saving does not release again. A new reading is never needed to preserve the
retained result.

An optional `settings` struct supplies:

| Field | Contract |
| --- | --- |
| `catalog` | Plain control array; accessing it must not perform I/O |
| `read(instrument)` | Read current settings without acquisition and return a report |
| `apply(instrument, overrides)` | Apply the model's automatic acquisition profile plus overrides and return a receipt, including when `overrides` is empty |

Each control has `id`, `label`, `type` (`choice` or `number`), `choices` (structs
with `value` and `label`), `minimum`, `maximum`, `available`, and `help` (fields
`meaning`, `whenToUse`, `tradeoff`, `normal`, `source`). Build controls with
`colormeasure.session.settingsControl`. One rule set,
`colormeasure.session.validateSettingsCatalog`, checks a control when it is
constructed, the adapter's static catalog when the adapter is validated, and every
settings readback. IDs are unique variable names, labels and help texts are text,
and numeric limits are finite or `NaN` (when irrelevant) with minimum no greater
than maximum. Runtime catalogs may reflect device capabilities unavailable
before connection.

Catalogs may also supply plain `editor` metadata for a number: `automaticNumber`
separates a special automatic value from a bounded fixed duration;
`dependentNumber` supplies labels and limits for each value of another setting.
The family owns these meanings. `settingsControlForValues` resolves them against
the pending overrides without changing the original catalog. Its optional
`useDefault=false` mode displays observations without guessing a missing context.
The UI and staging validator use the same declared bounds; the driver remains
responsible for validating the actual connected instrument before any write.

A read report contains `values`, `controls`, `identity`, `readAtUTC`, and
`responses`. An application receipt contains `requested`, `before`, `after`,
`commands`, `acknowledgements`, `status` (`applied`, `unchanged`, or `failed`), and
`error` (`identifier`, `message`). `before` and `after` hold available read reports
or are empty when unknown. All are ordinary value data, including built-in
`datetime` and `duration` metadata, without driver objects or function handles.
`readAtUTC` remains a text timestamp. A failed receipt must retain any partial changes and prevent
acquisition. Argument validation may throw before I/O; after a partial application,
return a failed receipt so the session can retain it.

The driver owns command ordering, capability and combination validation,
readback, and any temporary acquisition settings or restoration. The settings
hook executes before `read(instrument)`; the core releases the instrument after
either success or failure. Successful receipts are saved inside each complete
reading. Every direct reading carries `instrumentSettings`, an empty struct
without a settings hook.

Readings in a batch must have consistent struct fields. Acquisition retains all
instrument fields and adds the [session metadata](README.md#saved-data). A failed read must throw instead
of returning an error record. Plotting and further color analysis are explicit
caller operations; acquisition never invokes a plotting hook.

### Direct saved-source witness

The current installation admits direct serial adapters only. Operation-client,
projection and TI2/TI3 service fields are refused before a Session or
acquisition is created; no no-op compatibility adapter is provided.

Session owns one MAT destination and a private `SavedSnapshot` containing the
ordinary values and batch metadata just written. Before exporting selected-chart
or ordinary CSV, `assertCompanionSource` binds and checks the saved MAT digest.
A later external MAT change refuses export from the retained snapshot and offers
a new destination. Each successful owned save resets that witness for its new
snapshot. This is an export check, not a filesystem watcher or a physical
measurement qualification.

Chart CSV has an independent staged publication digest. A changed last-good
chart CSV is preserved and cannot be called current or replaced by an ordinary
retry. MAT saving, required Finish CSV, and chart CSV recovery keep their
separate failure states. Retrying a current CSV snapshot never acquires again
or rewrites MAT; another destination writes the retained values and keeps the
previous files.

The implementation uses the same persistence owner for native readings and
chart history. Its successful-save state includes:

```matlab
obj.SavedSnapshot=struct('measurements',retained,'batchInfo',snapshot,'sourceDigest','');
obj.CompanionSourceChanged=false;
```

The scientific and numerical reading fields are not reconstructed by the view
or export retry. `name` and `notes` remain operator annotations; their original
and edited values stay in the saved annotation history.

### Optional presentation services

`Changed` notifies listeners when the session changes. A third constructor
argument can replace services from `colormeasure.session.services()` for testing or add
an optional presentation layer:

| Service | Purpose |
| --- | --- |
| `now()` | UTC clock |
| `saveMat(measurements, folder, batchInfo)` | Persist the complete batch |
| `exportCsv(measurements, batchInfo, filename, toTable)` | Export the adapter's table and return the SHA-256 of the staged bytes published. A replacement service must preserve this return value; chart CSV currentness uses it. See [CSV publication](README.md#export-a-saved-batch). |
| `isMac` | Select the macOS serial-alias preference |
| `createView(session)` | Optional view factory for `session.show()` |
| `launchSession(adapter, io, folder, forceNew)` | Optional replacement-session launcher for `session.newBatch()` |
| `chooseFolder(previous)` | Optional selector for argument-free `session.saveElsewhere()` |

The default services contain no window or folder-selector implementation. A
view is a handle with a `Figure` property, owned and deleted by its session.
Its `restore()` method prepares and returns the same or a replacement view.
A view that returns a replacement must delete the view it replaces only after
replacement construction and state restoration succeed. If either fails, it
must dispose of any incomplete replacement and retain the original view and its
state; `Session.show()` does not delete the previous view when assigning the
returned one.
A replacement stays hidden until `Session.show()` assigns ownership and shows
it. It must preserve the batch, refuse unsafe replacement while an operation
or unsaved editor is active, and must never acquire or reconnect. The shared
Window uses this boundary to recreate controls after UI-only source changes.
`show()`, `hide()` and `window` manage that optional view without changing the
acquisition lifecycle. `newBatch()` only invokes its launcher after Finish;
cancellation leaves the prior session readable. A launcher must preserve the
supplied services in replacement sessions and avoid capturing the old session.

An optional adapter `viewData(measurements)` hook supplies read-only presentation
data. It must not acquire measurements or mutate the readings. Its absence is
valid for acquisition, saving and export.

### Window integration

`colormeasure.ui.launchSession(adapter, io)` adds `colormeasure.ui.services(io)` to the core
services, chooses a folder and retains one session per adapter key. Explicit
service overrides are preserved. Folder cancellation returns `[]`; repeating a
launcher restores the existing batch without measuring. Closing hides the
window; Finish ends acquisition; New batch creates a replacement while leaving
old session handles readable. The registry survives ordinary function clearing
within one MATLAB process, not quitting MATLAB.

Restoration requires the requested adapter configuration to match the retained
session. Different options raise `Measurement:SessionConfiguration` instead of
silently using the earlier settings. **New batch** inherits the current adapter
configuration. To change public serial or timeout options, finish the existing
batch, retain its saved files or a copy of `session.measurements`, call
`delete(session)`, and relaunch with the new options supported by the family
launcher or adapter. Closing the window alone does not release the retained batch.

The root [colormeasure.app](../../src/+colormeasure/app.m) launcher selects among the
installed UI adapters without opening a port. Each model retains its own batch;
selecting another model never changes an existing batch's adapter. UI adapters
wrap the acquisition adapter and supply settings hooks, `viewData` and a `workspaceName` for
the bare launcher: [colormeasure.drivers.pr.uiAdapter](../../src/+colormeasure/+drivers/+pr/uiAdapter.m),
[colormeasure.drivers.cr.uiAdapter](../../src/+colormeasure/+drivers/+cr/uiAdapter.m), and
[colormeasure.drivers.cs2000.uiAdapter](../../src/+colormeasure/+drivers/+cs2000/uiAdapter.m).
These UI adapters apply the model's automatic acquisition recipe before each
reading, with staged overrides. A custom PR script can explicitly opt into
this presentation and automatic acquisition policy:

```matlab
io = colormeasure.ui.services();
session = colormeasure.session.Session(colormeasure.drivers.pr.uiAdapter(), destination, io);
session.show();
```

`measurementModes` optionally supplies one readable acquisition-mode or quantity
label per retained reading. Supply a cell vector with N text entries; derive
labels from the reading, not mutable session settings. The table and copied
summary show **Unavailable** when this field is absent. These labels do not
change acquired data or comparison eligibility.

The optional `viewData` callback returns a scalar struct. `XYZ` is an N×3 array
(or empty), `observer` identifies its calculation, and `spectra` is an N-element
cell vector of structs containing `x` and `y` vectors. Per-reading cell, logical
and numeric arrays must be vectors with N entries. Row and column vectors are
accepted unchanged; empty arrays represent an empty batch. `spectralXLabel` and
`spectralLabel` describe those axes. `locusXYZ` provides the matching observer's
spectral boundary for chromaticity display. Empty spectrum cells represent
readings without spectral data, including CR-100 readings.
If `hasSpectra=false`, the window omits the spectral axes and uses
`noSpectrumReason` to explain why. Optional `spectralLabels` supplies each
reading's units; a mixed overlay is labeled as mixed quantities rather than
borrowing the newest reading's units.

An optional adapter `preparation` struct supplies `title`, `summary`, `details`,
`url` and `required`. **Instrument help** displays it. When `required=true`, the
window asks for confirmation before the first requested reading in that batch;
cancellation leaves the pending sample intact. This is a presentation reminder,
not an instrument command, calibration claim or headless-acquisition gate.

Pair compatibility is declared independently by three N-element cell vectors:

| Field | Matching keys permit |
| --- | --- |
| `xyzComparisonKeys` | XYZ differences and, with a compatible white, Lab/ΔE |
| `chromaticityComparisonKeys` | xy and u′v′ differences |
| `spectralComparisonKeys` | Spectral RMS and residuals on matching wavelength grids |

Keys must describe the relevant observer/conversion, quantity, scale, instrument
and source conventions. A missing or empty domain key withholds that calculation.
Missing XYZ does not disable a
compatible spectral comparison, and an unknown XYZ scale need not disable
chromaticity. Per-reading `observerNames`, `observerIds`, and
`spectralUnitsByReading` take precedence over their scalar counterparts.

The results view also reads, when present, the per-reading cell arrays
`xyzSources`, `xyzUnitsByReading`, `measurementConditions`, `spectralSampling`
and `spectralSamplingSources` (one text entry per reading, shown in the
reading details), and these reading fields: `deviceType`, `isSynthetic`,
`xyzMethod`, `xyzUnits` and `spectralUnits`. A synthetic reading marked
`isSynthetic` is labelled as such; readings without these fields omit the
corresponding detail rows. `preparation.headings` titles the leading `details`
entries in order; later entries stay untitled, and the validator refuses more
headings than entries.

Illuminant presets require `observerId = 'CIE1931_2deg'` (or the matching
per-reading `observerIds`). Declare this only when the retained XYZ has that
observer. Presets also require an explicit White Y on the sample scale.
Unknown or other observers leave preset Lab/ΔE unavailable without withholding
other compatible metrics. Matching keys cannot establish that physical setup
or accessories stayed unchanged; the operator must check those conditions.
Missing capabilities show as unavailable. Presentation is read-only and must
not open instrument connections.
Chromaticity display uses `colormeasure.colorimetry`, available through the same
`src` path entry. Adapters without the hook remain usable for acquisition and export.

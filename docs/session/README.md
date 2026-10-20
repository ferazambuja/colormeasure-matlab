# Measurement sessions

The `colormeasure.session` package manages named batches, complete MAT snapshots,
CSV export and an event log. Instrument
adapters supply acquisition and CSV columns.
The session does not require a spectrum or a graphical interface.

## Start a session

Add the repository **src** folder to the MATLAB path, as described in the
[instrument guide](../../README.md#use-the-drivers-in-your-scripts). For example, after
[PR-655 setup](../drivers/pr/README.md#setup), use an existing destination folder:

```matlab
session = colormeasure.session.Session(colormeasure.drivers.pr.adapter(), destination);
```

The same constructor accepts these acquisition adapters:

| Instrument | Adapter |
| --- | --- |
| PR-655 / tentative PR-670 | `colormeasure.drivers.pr.adapter()` |
| CR-100, CR-250, CR-300 | `colormeasure.drivers.cr.adapter('CR100')`, `colormeasure.drivers.cr.adapter('CR250')`, `colormeasure.drivers.cr.adapter('CR300')` |
| CS-2000 / CS-2000A | `colormeasure.drivers.cs2000.adapter()` |

Construction discovers available ports and returns without measuring. Keep
the returned handle while acquiring. Each `measure` call is synchronous and
starts only when requested:

```matlab
session.measure('Sample 001', 'Reference tile');
measurements = session.measurements;
% Position the next sample before executing another measure call.
session.measure();
session.finish();
```

Create another `Session` for the next batch. Finishing preserves the existing
handle and data for inspection. A saved MAT can be loaded as ordinary structs;
it does not resume an instrument connection.

## Interactive launchers

An optional [measurement window](../ui/README.md) operates on the same session.
With **src** on the path, `colormeasure.app` opens an instrument
picker; `session = colormeasure.app('CR250')` selects a model directly. The keys
are `PR655`, `CR100`, `CR250`, `CR300`, and `CS2000`. Launching opens or restores that model's batch
and returns control to MATLAB; it never starts a reading.
Use the [window guide](../ui/README.md) for controls, screenshots and comparison
interpretation; the command-only constructor above stays window-free.

## Color calculations

The [acquisition science guide](color-science.md) documents spectrum-to-XYZ,
units and totals. The [standalone colorimetry reference](../colorimetry/science.md)
contains equation excerpts, primary citations and inherited numerical conventions.
Measurement records retain their calculation method and reported units. The
[adapter reference](adapters.md) describes how drivers supply that information.

## Session API

Use methods to change session state so names, ports and saving stay synchronized. Public properties are read-only; `session.measurements` and
`session.info` return ordinary structs suitable for analysis or copying.

### Actions

Correct a retained reading's operator annotations with:

```matlab
saved = session.editReading(1, 'White reference', 'Matched tile; repeated positioning');
```

The reading number is its acquisition-order index, independent of duplicate
names. The method changes only `name` and `notes`, then saves the MAT snapshot.
It returns whether persistence succeeded. Original annotations and the latest
edit timestamp remain in `session.readingAnnotations` and
`batchInfo.readingAnnotations`; raw device records, native reading IDs, chart
coordinates, measured values and acquisition settings remain unchanged.

For a finished batch, the method also updates its CSV and preserves the
acquisition lock. A MAT or CSV failure retains the edit in memory and exposes
the existing recovery controls. Call `session.retrySave()` or
`session.saveElsewhere(folder)` without measuring again. Editing is refused
during acquisition or unfinished finalization.
`session.setSample` still changes only the next sample. Editing a loaded MAT
struct does not automatically update its file; load/save it explicitly.

| Method | Effect |
| --- | --- |
| `session.measure()` | Acquire once using the pending name and notes; retain a complete reading, attempt instrument release and autosave MAT. Inspect cleanup and save status separately. |
| `session.measure(name, notes)` | Set the pending sample and acquire once. The logical return value reports acquisition success, separately from saving success. |
| `session.setSample(name, notes)` | Edit the pending sample without measuring. |
| `session.editReading(index, name, notes)` | Correct a retained reading, preserve its original annotations, and save MAT plus the finished batch CSV. |
| `session.selectPort(port)` | Select a port; availability is checked when measuring. |
| `session.refreshPorts()` | Refresh available serial ports without opening them. |
| `session.setInstrumentSettings(overrides)` | Replace staged instrument overrides without connecting or measuring; use `struct()` to clear them. |
| `session.refreshInstrumentSettings()` | Connect, read settings, and release without measuring; available only for adapters with settings support. |
| `session.retrySave()` | Retry the failed MAT save or CSV export. A chart-CSV-only retry reuses the authenticated saved MAT without rewriting it or acquiring, including after Finish. An acquisition-order CSV retry reuses the finalized MAT. |
| `session.saveElsewhere(folder)` | Write the acquired batch into a new subfolder of this destination. A finished batch stays closed to acquisition. |
| `session.finish()` | Finalize MAT and export CSV; retain the completed results for review. |
| `session.retryDirectCleanup()` | Retry release through the retained direct connection owner, then save. Does not reconnect or acquire; a failed release keeps the owner and guard. A false return means cleanup succeeded but saving needs recovery. |
| `session.confirmChartIoStopped(ConfirmConnectionClosed=true, ConfirmInstrumentIdle=true, Declaration=...)` | Record completed cleanup checks for an idle direct-instrument batch only when no returned connection owner remains accessible, then save. Applies to ordinary and guided-chart batches. Requires both confirmations and a nonblank explanation; does not close a connection or query the instrument. See [cleanup recovery](#unconfirmed-connection-cleanup). |

One available port is selected automatically. When several ports are available,
select the instrument explicitly. On macOS, paired `/dev/tty.*` and `/dev/cu.*`
entries are represented by the available callout (`cu`) entry.

Port discovery uses MATLAB's [`serialportlist`](https://www.mathworks.com/help/matlab/ref/serialportlist.html),
which lists serial names, not instrument models. The selected family's adapter
checks the instrument when **Measure** opens the connection. The launcher does
not try every manufacturer's protocol on each port. For example, CR provides
the read-only `RC Model` query, CS identification follows `RMTS,1` remote mode,
and PR uses a different remote handshake. See the
[CR protocol guide](../drivers/cr/api-and-protocol.md#discovery-and-identification),
[CS remote-mode notes](../drivers/cs2000/README.md#troubleshooting), and
[PR connection guide](../drivers/pr/api.md#connection-options).
These differences follow the manufacturer protocols: CR *Remote Communication
v1.36*, §4.3.2.2 ([download](https://www.colorimetryresearch.com/downloads));
CS *Communication Specifications Rev7*, §1.3.1, p.7
([manual](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf#page=7));
and PR remote control, printed pp.102–111
(Photo Research, *PR-655/PR-670 User Manual*, Rev. B, 2009-07-29).
The window uses the ordinary USB serial defaults and applies the selected
model's automatic acquisition recipe before each reading. Direct driver calls
and core acquisition adapters preserve existing settings. Custom connection
options belong in a script using the family driver or acquisition adapter.

A failed reading preserves its pending name and notes. Successful acquisition
advances the default sample number and clears the notes. Overlapping actions
are refused while busy. A Finish request during acquisition waits for that
reading; saving errors keep recovery available.

### Guided chart commands

A chart uses the same Session and acquisition adapter as free samples. Start
with a packaged layout or a named custom grid:

```matlab
definition = colormeasure.chart.definition('classic');
% definition = colormeasure.chart.definition('sg');
% definition = colormeasure.chart.definition('custom', 'Practice chart', 2, 3);
session.startChart(definition);
session.selectChartCell(2, 2); % B2: row first, column second.
session.setSample('B2', 'Second row; second column');
```

Setup saves the chart definition and state without acquiring. Custom dimensions
must be positive integers with at most 140 cells in total. The canonical
coordinate is generated from the row and column; for example,
`colormeasure.chart.coordinate(2, 2)` returns `'B2'`. Rotation changes the display,
not this identity. A chart definition cannot be replaced after attempts have
been recorded in that batch; start another batch instead.

| Method or property | Meaning |
| --- | --- |
| `session.startChart(definition)` | Begin guided association using a validated definition; existing free-sample readings stay outside chart coverage. |
| `session.chart` | Read-only ordinary snapshot; empty before setup. Includes the definition, current cell, orientation, passes, active pass, pause state, context decision and revision/saved revision. Inspection uses retained facts; it never reads correction files or calls the correction parser. |
| `session.selectChartCell(row, column)` | Set the active canonical cell for the next reading; it does not reposition the grid's inspection cursor. |
| `session.rotateChart(degrees)` | Rotate the diagram; accepted orientations are 0, 90, 180 and 270 degrees. |
| `session.pauseChart()` | Save and pause guided association in this live session. |
| `session.resumeChart()` | Resume the retained chart in this session when its acquisition/recovery state allows it. |
| `session.acceptChartContext()` | Accept a staged material context change by starting a new empty pass; retain earlier passes. |
| `session.finish(AllowIncompleteChart=true)` | Explicitly finalize with missing cells in the active pass. Ordinary `finish()` requires the active pass to be complete; earlier abandoned passes remain saved and exported for inspection. |

While guided association is active, `setSample` accepts notes but refuses a
name other than the current coordinate. Use the ordinary acquisition action
`session.measure()`. The session freezes the intended coordinate before the
reading starts and associates the completed result before saving it. A successful
selected attempt advances `chart.currentCell` in canonical row order; a failed
attempt does not. Inspection remains separate from this acquisition target.
A failed retry preserves an earlier selected reading. Software association
cannot verify where the instrument is physically aimed.

`editReading(index, name, notes)` uses this segment's immutable acquisition-order
index. Inherited readings belong to their original segment and are inspected
through `chartReading`, not indexed into the new `measurements` array. Changing
a current reading's name to `Foo` does not retarget its chart cell.
The original annotations and all acquired attempts remain retained. Material
settings changes start separate passes; completion counts never combine them.

Finish checks the active pass. Earlier passes stay saved and exported, including
their missing cells; they do not require a misleading return to acquisition.
Switching direct models pauses and saves the source chart and opens the other
model’s separate batch. The source remains retained. Resume it explicitly when
ready; a source save failure leaves recovery available.

### Measured-reference eligibility

The direct PR, CR and CS workflows retain native radiance/luminance readings
and naming-only chart contexts. Their chart measured-color interpretation is
unavailable; those readings do not become relative reflective measurements.
Placement checking and measured-reference setup are unavailable; no placement
configuration control or acceptance API is provided. Saved charts from other
acquisition formats are refused. Ordinary chart naming, coverage, historical
preset illustrations, MAT/CSV retention and continuation remain available.

The scientific [position-check reference](../colorimetry/position-checks.md)
describes the required quantity domain, white, scale and comparison limits.
Those formulas do not establish eligibility for the direct instrument data.

### Continue a chart in a new session

Linked continuation creates a new batch segment. It retains the source's chart
definition, passes, attempts and selected readings without adding inherited
readings to the new Session's `measurements`. The original saved MAT remains a
separate record. See the [window walkthrough](../ui/README.md#continue-a-saved-or-finished-chart)
for the normal interactive route.

For an existing ready `target` Session with a window, the same dialog is available
from MATLAB commands:

```matlab
target.show();
[continued, action] = colormeasure.ui.continueChart( ...
    target, '/path/to/saved/measurements.mat');
% Cancel returns an empty continued value and an empty action.
% Acceptance returns the newly linked Session; it takes no measurement.
if ~isempty(continued)
    state = continued.chart;
    [reading, origin] = continued.chartReading(state.activePass, 1);
end
```

`chartReading(passIndex, cellIndex)` uses a one-based canonical row-major cell
index, independent of diagram rotation. An unread cell returns empty structs.
For a selected reading, `origin` supplies its original `segmentId`,
`readingIndex`, `inherited` flag, annotations and
declared XYZ/quantity facts. Reading this state does not measure, save or access
the old device. Never use an inherited `readingIndex` as an index into
`continued.measurements`.

The lower-level Session methods share the same validation and acceptance path:

| Method | Responsibility |
| --- | --- |
| `target.prepareChartContinuation(source, PassId=..., Declarations=...)` | Read and validate a saved MAT path or retained live Session; compare a selected source pass with the target's current facts. Omit `PassId` to inspect the source's active pass. Returns coverage, source identities, differences, unknowns and action eligibility without finishing the source. |
| `target.freshChartContinuationSession()` | After explicit consent, construct a fresh unpublished receiver from the current target's adapter and services. Saved data supplies no live connection, process or callback. |
| `[saved, continued] = receiver.acceptChartContinuation(preview, Action=..., Declarations=..., AcknowledgeVersionChange=..., ConfirmConnectionClosed=..., ConfirmInstrumentIdle=..., CleanupDeclaration=...)` | Recheck the source, target and decisions; finish/save live owners through their existing guards; attach and save the new segment without acquiring. `Action` is `'continue'` or `'new-pass'`. When `preview.cleanupDeclarationRequired` is true, both confirmations and a nonblank `CleanupDeclaration` are required; otherwise they must be omitted. |

Use the UI helper when replacing a visible window: it also manages the retained
session registry, publication and recovery. A raw receiver must remain reachable
if `saved` is false. Retry that receiver's retained save with `retrySave()` or
`saveElsewhere(folder)`; do not call acceptance again or reacquire. A changed
source or target invalidates the preview and requires a fresh comparison.
If a selected disk MAT belongs to the unfinished current batch, finish that
batch first or use its live Session as the source. The disk route refuses this
collision before finalization could rewrite the chosen file, and checks its
byte witness again after finishing the current owner.
Live sources are also rechecked after finishing another target; a changed source
requires a fresh preview before attachment.
The window's **This batch** source choice selects that explicit live route;
preview and Cancel leave the batch unfinished.
Declarations supplied at acceptance must equal those already previewed. The
receiver uses the current direct adapter and its retained settings.

**Continue** retains the selected source pass's ID and coverage. It requires
established identity and compatible material facts, not merely the same model,
port, requested settings or capability digest. A changed capability snapshot
can require acknowledgment even when readable material facts agree. Required
unknowns, differing conditions or a pending acquisition-context decision prevent
same-pass continuation. **New pass** retains history and creates a new pass ID
with empty active coverage. Unresolved source decisions and sample drafts remain
in the inherited record; they are not silently accepted as new measurements.
Each selected inherited attempt must also have an established compatible basis.
Later readback or an enriched pass summary cannot supply identity or scale that
was missing from an earlier selected observation. Native serial identity retains
its encoding as well as its value; a display string alone is not the comparison.

Observable identity or fitted conditions may be recorded through `Declarations`
as operator-declared evidence. They cannot override reported facts, invent
scientific units, establish calibration or clear process ownership. A new
Session still needs normal readiness and current capability checks. A retained
active acquisition, unconfirmed connection cleanup or required save recovery
blocks continuation while the batch that saved it is open. If that owner already
resolved cleanup and saved elsewhere, the refusal points to its current MAT.
Continue from that open batch, or finish it and open that saved file instead;
an unfinished batch's saved copy is refused while it remains open. Restarting MATLAB is
not evidence of connection cleanup.

When a saved chart retains an unfinished acquisition or unconfirmed cleanup and
no batch in this MATLAB session owns it (for example after a restart), the
preview sets `cleanupDeclarationRequired`. Continuing then needs the same two
operator checks as [Confirm cleanup...](#unconfirmed-connection-cleanup).
The new segment saves them in its `batchInfo.chartIoConfirmations` under the
source's segment and run identities; later continuations accept that ancestor
only with such a record from a later segment. A source attempt left `started`
can no longer complete; the continuing chart shows it as interrupted, without
a reading.

For a retained chart, Session saves an active-I/O guard **before** dispatching
acquisition, settings readback or paused free-sample work. If that
MAT save fails, dispatch does not occur. An interruption therefore cannot leave
an earlier idle snapshot authorizing continuation. Direct release must be confirmed before the corresponding guard can be cleared.
An explicit [operator cleanup declaration](#unconfirmed-connection-cleanup)
can resolve a direct chart's guard only when no returned owner remains accessible
and the operator completes both checks;
saving again alone does not establish cleanup.

The reading resolver makes the source distinction explicit. Exact excerpt from
[`resolveReading`](../../src/+colormeasure/+chart/resolveReading.m):

```matlab
inherited=~strcmp(attempt.segmentId,chart.segmentId);
owner=measurements;
if inherited
    matches=find(strcmp({chart.sources.segmentId},attempt.segmentId));
    assert(isscalar(matches),identifier,'The original chart reading segment is missing or ambiguous.');
    owner=chart.sources(matches).measurements;
end
```

The new MAT contains a flat registry of inherited source segments and their
ordinary records, chart metadata, annotations and source-byte digests. References
retain their original segment and reading index. The MAT can therefore move without its
original path or old runtime. This retains observed and derived values; it does
not recalculate them or make incompatible measurement conditions equivalent.
Existing [quantity and color-science conventions](color-science.md) and
[relative chart-color limitations](../colorimetry/chart-colors.md) still apply.

Every current and inherited segment must retain its original
`batchInfo.configuration` and `batchInfo.catalogIdentity`, including its model
and nonempty catalog key.
These identify the acquisition owner used to validate the retained context;
each inherited segment is validated with its original direct owner and
configuration. A replacement adapter does not reinterpret earlier readings.

Current continuation accepts chart schema **5**, its current direct pass, attempt
and source fields, and its saved continuation guard.
Earlier development schemas are refused without automatic conversion; plain
MATLAB loading can still inspect their ordinary structs. Malformed IDs, cyclic
or inconsistent ancestry, broken selections and invalid quantities are refused.
A saved chart in the current format may retain at most **16 inherited segments**. It remains inspectable
at that limit, but another continuation is refused; start a separate chart for
further acquisition. The disk loader also refuses a MAT whose `measurements` and
`batchInfo` variables total more than **256 MiB** according to MATLAB's file
metadata. This bounds the retained variables, not the compressed file size.
See [`continuationSource`](../../src/+colormeasure/+chart/continuationSource.m)
and [`validateSnapshot`](../../src/+colormeasure/+chart/validateSnapshot.m).

### Read session state

| Property | Contents |
| --- | --- |
| `measurements` | Readings acquired in this segment, as a struct array. Use `chartReading` for selected inherited chart readings. |
| `info` | Count, timing, instrument label, configuration, acquisition completion flag, and earlier save folders |
| `configuration` | Adapter configuration captured for the batch; empty when not supplied |
| `adapterKey` | Adapter identity used to keep each instrument and demo mode in its own session |
| `preparation` | Optional device preparation guidance, read without connecting |
| `settingsCatalog` | Plain setting controls, from the last available readback or the adapter's static catalog; accessing it sends no commands |
| `settingsOverrides` | Staged overrides for subsequent readings; empty by default |
| `settingsSnapshot` | Last available settings readback report; empty when unknown or after a port change |
| `lastSettingsReceipt` | Latest settings application result, including a failed or partially applied operation |
| `workspaceName` | Preferred name for a launcher-published session; the core constructor does not publish it |
| `files` | `folder`, `mat`, `csv`, `chartCsv`, and `previousFolders`; `chartCsv` retains the last successfully written chart CSV path, including when a later update fails. Check `chart.csvCurrent` before treating it as current |
| `chartCsvNeedsRetry` | Whether the selected-chart CSV failure can be retried; false for deterministic projection and changed-source/output refusals. Does not itself block acquisition or starting another batch |
| `companionRecoveryAvailable` | A relocatable chart-CSV failure or changed saved-source identity can be addressed at another destination, independently of retryability |
| `log` | Event structs containing `timeUTC`, `level`, and `message` |
| `name`, `notes`, `port`, `ports` | Pending sample, selected port, and available ports |
| `savedCount` | Number of readings in the latest successful MAT save |
| `busy` | An action is running, including its optional companion updates |
| `saving` | MAT persistence is in progress. Becomes false before chart-CSV callbacks; it does not describe the entire busy interval |
| `finishing` | Finish stage has started; further acquisition is disabled |
| `finished` | Finish completed successfully. `files.csv` is empty when the adapter declares the acquisition-order CSV unavailable. A chart batch can still have `files.chartCsv`; MAT remains the complete record |
| `status`, `needsRecovery` | Current status text and whether saving or idle unconfirmed I/O needs attention, in ordinary or chart batches. This is not solely a disk-write failure flag |
| `chartIoUnconfirmed` | Direct connection cleanup is unconfirmed in an ordinary or chart batch, including a failed connect that returned no owner. A retained direct release owner also keeps this true. Saving again does not establish cleanup |
| `directCleanupCanRetry` | A retained direct connection owner remains accessible for `retryDirectCleanup()`. Reading this property does not query or reconnect the instrument |
| `startedAtUTC`, `startedAtLocal`, `localTimeZone`, `destination` | Session opening time and zone; actual batch folder once created, selected parent beforehand |

`measure()` returning true means a complete reading was appended. It does not
establish that release or saving succeeded. Check `chartIoUnconfirmed` for the
retained cleanup guard and `needsRecovery`, `savedCount` and the
log for recovery and persistence status. The properties
remain readable after Finish. Use `finish()` to end a batch;
`delete(session)` destroys the handle.

`saving` describes writing the authoritative MAT. Reading or authenticating
that saved file for CSV output does not set it. `busy` remains true
through chart-CSV actions. Reading the chart state reports retained facts; it
does not poll the filesystem.

### Instrument settings

For adapters with settings support, each `measure()` applies the model's
documented automatic acquisition profile plus any staged overrides before
acquiring. This also happens when no overrides are set. Accessory and calibration
selections remain unchanged unless explicitly overridden. Automatic controls vary
by model; the device guide describes the profile and available overrides.

Read the settings explicitly when needed, inspect the catalog, then stage a
struct whose field names are the desired control IDs:

```matlab
session.refreshInstrumentSettings(); % Connect and read; no measurement.
controls = session.settingsCatalog;
observedSettings = session.settingsSnapshot;
% Use the device guide's control IDs and values when constructing overrides.
session.setInstrumentSettings(overrides);
session.measure('Sample 001', '');
session.setInstrumentSettings(struct()); % Clear overrides for subsequent reads.
```

Staging checks known choices and bounds without instrument I/O. The driver checks
actual capabilities and coupled settings again before writing. The readback is an
observation with a timestamp, not a continuous monitor. Staging an override does
not change that observation or the instrument. A port change clears the observation;
it does not change the batch's immutable `configuration`.

If applying settings fails, including after a partial application, acquisition
does not start. Inspect `lastSettingsReceipt` and the event log, correct the
settings, and retry explicitly. An acknowledgement is distinct from readback
verification; the receipt preserves the driver reports and responses. There is no
automatic retry or rollback guarantee. A Finish request during application waits
for the active measurement action and then finalizes the batch.

Adapters without settings hooks retain their original acquisition behavior.

## Saved data

For a focused file-format guide and copyable loading/plotting examples, see
[Saved data: structure and MATLAB examples](../saved-data.md).

Relative destination paths are resolved against MATLAB's current folder when
selected, including `saveElsewhere(folder)`. Changing MATLAB's current folder
afterward does not change where the batch is saved.

On Windows, use the folder picker or a fully qualified path such as
`D:\Measurements` when choosing a destination on another drive. Avoid the
drive-relative form `D:Measurements`, which uses that drive's current directory.
See [Windows path formats](https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats).

The first acquisition or accepted chart setup creates a unique batch folder
below the chosen destination:

```text
Measurements/
    batch_20260916_143208_013/
        measurements.mat
        measurements.csv
        chart-selected.csv  (after a chart MAT save succeeds)
```

| File | When written | Contents |
| --- | --- | --- |
| `measurements.mat` | After every completed reading, accepted chart setup/edit or continuation, before device I/O when a chart is retained, and again at Finish | Current `measurements` and `batchInfo`, including the full retained chart history and inherited source records when present |
| `measurements.csv` | At Finish | Supporting table produced by the instrument adapter |
| `chart-selected.csv` | Updated after successful chart progress saves, excluding the pre-I/O guard save; Finish authenticates existing bytes before reuse at the same destination and revision | Selected reading or missing status for each cell of each pass, in canonical row order |

An active batch can therefore have a current MAT and chart CSV while its
acquisition-order `measurements.csv` is still awaiting Finish. The MAT is
the primary record and is sufficient to recover the acquired data. The event
log remains in `session.log`; it is separate from the saved measurement structs.

The session adds these fields to each adapter reading:

| Field | Meaning |
| --- | --- |
| `name`, `notes`, `port` | Sample description and selected connection |
| `startedAtUTC`, `completedAtUTC` | Start and end of the adapter's acquisition call, in UTC |
| `startedAtLocal`, `completedAtLocal`, `localTimeZone` | Acquisition-local ISO timestamps with numeric UTC offsets and captured time-zone name |
| `durationSeconds` | Elapsed time for that acquisition call |
| `matlabVersion` | MATLAB version used for acquisition |
| `instrumentSettings` | When supported, the settings application receipt for this reading, with `policy = 'automatic-with-overrides'` and the staged `overrides` |

`batchInfo` contains `measurementCount`, `startedAtUTC`, `completedAtUTC`, and
`elapsedSeconds`, plus `instrument`, `acquisitionComplete`, `previousFolders`, and
`sessionStartedAtUTC` (when the session opened). Every batch includes
`startedAtLocal`, `completedAtLocal`, `localTimeZone`, `sessionStartedAtLocal`,
and `sessionLocalTimeZone`. `batchInfo.configuration` copies the adapter's
host-requested configuration; it is distinct from device-reported capture metadata.
`batchInfo.catalogIdentity` retains the acquisition adapter's model-catalog
identity. Continued charts preserve these fields for each original segment.
UTC and elapsed seconds remain authoritative; local offsets can change across
a daylight-saving transition. With no readings, acquisition-time fields are
empty. When readings carry different time-zone names, `batchInfo.localTimeZone`
is empty; each reading retains its own zone and numeric UTC offset.
Elapsed batch time spans the first reading's start to the last reading's
completion, including gaps between readings. It excludes time waiting to finish.
The completion flag describes acquisition; CSV success is reported separately
by the session's files, state, and log.

### CSV text and spreadsheet formulas

The shared [CSV writer](../../src/+colormeasure/+session/exportCsv.m) prefixes
text cells with an apostrophe when their first non-whitespace character is
`=`, `+`, `-` or `@`, or when the text starts with a tab, carriage return or
line feed. This applies to ordinary `measurements.csv`, `chart-selected.csv`
and the PR-655 saved-session CSV exporter. For example, a reading named
`-ND filter` is written as `'-ND filter`; the source ID `=fixture()` is written
as `'=fixture()`. The prefix marks the value as literal spreadsheet text.

Numeric columns are unchanged. MAT records and the ordinary analysis table
retain the original names, notes and identifiers without this CSV prefix.
Use those records when exact source text matters; do not interpret the added
apostrophe as part of the original sample name or target identifier.

### Chart records and selected-reading CSV

Keep `measurements.mat` as the complete chart record. Its `batchInfo.chart`
retains the validated definition and source mapping, fixed cells, passes and
acquisition context,
attempts, selected-reading references, annotations, pause/orientation state and
saved revision. Direct readings retain their original records.

The saved chart includes three `{name, notes}` drafts: `pendingSample` is the
current name and notes committed to Session, `chartSample` holds the canonical chart coordinate and
pending chart notes, and `freeSample` preserves the free-sample draft across
pause/resume. These are pending annotations, not acquired readings. They support
inspection of retained intent and the explicit continuation workflow. Loading
those structs alone never reconnects an instrument.

The saved fields are `batchInfo.chart.format = 'guided-chart'` and
`batchInfo.chart.version = 5`. `batchInfo.segmentId` is the batch's UUID;
the chart uses the same segment ID. Chart-run and pass UUIDs identify the chart
and its separate acquisition setups. Reading references include their original
segment and append index. File paths and editable names are not reading IDs,
so moving the saved folder does not change a cell's association. A continued
chart also stores `parentSegmentId`, its flat `sources` registry and the explicit
continuation choice. The current `measurements` array contains only this
segment's acquisitions; inherited source arrays remain in `batchInfo.chart.sources`.

Passes retain accepted direct context, acquisition attempts and selected reading
identities. Placement configuration, pending placement decisions and imported
expected-color interpretations are absent. Earlier development chart formats
and retired fields are refused before continuation finishes the current batch.
Keep their original MAT files for plain `load` inspection; this installation
provides no automatic migration or continuation of those formats.

`chart-selected.csv` is updated after the chart progress MAT save succeeds. The
pre-I/O guard save defers companions until the outcome is retained. The CSV has one row
per canonical cell per pass, including missing cells. Coordinates, source
identifiers, current reading names, original annotations, selection and reading
identity remain separate. Numerical fields retain quantity and units. Missing
values stay empty; they are never fabricated zeros. Repeated readings remain
in MAT and their own segment's ordinary acquisition-order export; the chart summary selects one
retained attempt per cell. This CSV contains selected XYZ when available;
complete spectra and other instrument-specific fields remain in MAT and the
eligible acquisition-order export.

The 28 columns produced by
[`colormeasure.chart.selectedTable`](../../src/+colormeasure/+chart/selectedTable.m)
are grouped below:

| Columns | Meaning |
| --- | --- |
| `RunId`, `PassId`, `SegmentId`, `DefinitionId`, `DefinitionRevision` | Chart, acquisition pass and frozen definition identity. For a selected reading, `SegmentId` is its original source segment; for an unread cell, it is the current chart segment. |
| `Row`, `Column`, `Coordinate`, `SourceLocation`, `SourceId`, `SourceRow`, `ExportId`, `PatchNumber`, `PatchName` | Fixed cell and source mapping; optional preset/source metadata remains empty when unavailable |
| `Status`, `SelectedAttempt`, `ReadingIndex` | Selection and links to the original segment's acquisition records; `SegmentId` and `ReadingIndex` identify the selected reading |
| `ReadingName`, `ReadingNotes`, `OriginalName`, `OriginalNotes` | Current and original operator annotations |
| `X`, `Y`, `Z`, `Quantities`, `Units` | Selected XYZ, source spectral-quantity label and XYZ units when available |
| `Context`, `UnavailableReason` | The selected attempt's accepted context as JSON, including its own averaging/readback and correction provenance, and the reason a numerical result is unavailable. Without a selected successful reading, `Context` is empty. |

The default MATLAB table uses `NaN` for missing numeric entries. Session requests
`selectedTable(..., ForCsv=true)` for its chart export. That branch explicitly
converts missing numeric values to empty cells before the existing staged CSV
writer runs:

```matlab
missingValues=isnan(values);encoded=num2cell(values);
encoded(missingValues)=repmat({[]},nnz(missingValues),1);
data.(name{1})=encoded;
```

The CSV therefore has empty fields for missing numeric values, while finite
values remain numeric. `Status = "measured"` means a
reading was selected; inspect `UnavailableReason` as well before using its
numeric columns.

Chart CSV uses the same [text escaping](#csv-text-and-spreadsheet-formulas)
as ordinary measurement and PR-655 CSV exports. The practice target's raw ID
`=fixture()` therefore exports as `'=fixture()`; MAT retains the original ID.

For example, a renamed B2 reading has `Coordinate = "B2"` and
`ReadingName = "Foo"`; `OriginalName` retains the name acquired with that attempt.
Use `PassId` and `Coordinate` together when filtering the spreadsheet so that
different acquisition setups remain separate. `ReadingIndex` identifies the
row in the complete MAT readings, while `SelectedAttempt` identifies the
attempt within that pass. `X`, `Y`, `Z`, `Units` and `UnavailableReason` describe
the selected result's numerical availability.

Numerical availability is evaluated on each pass's selected readings. An
unavailable acquisition-order CSV does not automatically make every selected
chart pass unavailable. If a selected view cannot be represented numerically,
the chart export keeps its identity/status/annotation summary and explicit
unavailability reason. That summary is not a complete numerical color export.

Chart progress saves update MAT first, then refresh the selected-chart CSV.
Editing a finished reading's annotations also regenerates eligible acquisition
and chart summaries. Before reusing an existing chart CSV at the same
destination and chart revision, Finish checks its bytes against the digest
retained after publication. An externally edited file is preserved and the
update is refused; save to another folder to create a new copy. A missing file
can be recreated. A queued
Finish writes the chart summary once, then the acquisition-order CSV.

If a chart CSV update fails, `files.chartCsv` retains the last successful path;
that earlier file is no longer current. If no chart CSV was ever written, there
is no last-good file to inspect. MAT remains available, and this optional failure
does not itself block acquisition. `chartCsvNeedsRetry` is true only for a
retryable source-read, publication or output-read failure. After resolving that cause, `retrySave()`
retries CSV without rewriting MAT or acquiring again. Projection or changed-source refusals do not offer
repeated CSV retry: correct the reported cause, or use `saveElsewhere(folder)`
when another destination is needed. A finished batch stays closed to acquisition.

For a live session, `session.chart.csvCurrent` reports the last authenticated
state for the current chart revision, provided no export error has occurred;
`csvRevision` identifies that revision, and `csvUnavailableReason` holds a
chart-export failure. Reading these properties does not check the file again.
External edits or deletion are detected at the next explicit export/reuse
action, so the displayed state is not a continuous integrity check.
These indicators do not establish full coverage or numerical availability:
an incomplete or identity-only summary can be current. Check its per-row
`Status` and `UnavailableReason` separately.

To load a successfully exported chart CSV in MATLAB, specify its comma
delimiter and first-row column names explicitly:

```matlab
chartRows = readtable(session.files.chartCsv, ...
    'Delimiter', ',', 'NumHeaderLines', 0, ...
    'ReadVariableNames', true, 'TextType', 'string');
```

Use the saved CSV path in place of `session.files.chartCsv` when no live session
remains. Long quoted `Context` values can mislead automatic header detection;
these options prevent the first data row from becoming the column headings.

These files support inspection and spreadsheet analysis. Plain `load` does not
create a live Session or establish instrument readiness; use
[explicit linked continuation](#continue-a-chart-in-a-new-session) to acquire
in a new segment.

Classic's 4 × 6 layout and descriptive names follow the manufacturer's
[chart guide](https://calibrite.com/know-your-chart-a-color-perfectionists-guide-to-the-24-patch-colorchecker-classic/).
The application's column-letter/row-number convention is distinct from source
reference labels. The [preset provenance](../../resources/provenance/chart-source.json)
records source files, digests and mapping corrections.
For example, application B1 is Classic patch 2; the original reference file
calls that location A2. SG has 10 rows and 14 columns, with source locations
A1–N10. The saved mapping preserves these source identities explicitly.
Layout and names provide no measured values or claim about a particular chart's
condition, edition or accuracy. SG's raw source identifiers include a duplicate;
the saved mapping distinguishes that original `SourceId` from its unique
`ExportId`. Use the validated cell mapping, not source identifier alone, to
associate data.

### Load a MAT batch

```matlab
[file, folder] = uigetfile('*.mat', 'Open a measurement batch');
if ~isequal(file, 0)
    saved = load(fullfile(folder, file));
    measurements = saved.measurements;
    batchInfo = saved.batchInfo;
end
```

Saved records remain ordinary structs; loading them does not reconnect an
instrument. Instrument-specific fields and CSV columns are documented in the
[instrument guides](../../README.md#use-the-drivers-in-your-scripts).

### Unconfirmed connection cleanup

An idle direct-instrument batch with `session.chartIoUnconfirmed=true` cannot
acquire, read settings or continue. This applies to ordinary and guided-chart
batches after an unconfirmed release or an unmarked connection refusal. A
`serialport` constructor error can leave this state even when no connection
handle reached the Session: absence of a handle is not a cleanup confirmation.
Session automatically clears such a refusal only when the native owner supplies
an explicit
[cleanup witness](adapters.md#connection-failure-and-cleanup).

If the returned connection owner is still accessible,
`session.directCleanupCanRetry` is true. Use `session.retryDirectCleanup()`;
it retries only that owner's release, without reconnecting or measuring.
A release error keeps the owner, readings and guard. If release succeeds but
the method returns false, use `retrySave()` or `saveElsewhere(folder)` to save
the retained state; those save actions do not repeat release. A manual
declaration cannot bypass the available owner.
When no returned owner remains accessible, check that no MATLAB batch or other program still uses the instrument's
port (quitting them, or unplugging and reconnecting the instrument cable,
closes it) and that the instrument is not measuring. Once both checks are complete,
`session.confirmChartIoStopped(...)` records both confirmations and your
explanation, clears the retained guard, and attempts to save MAT. The explanation
must be nonblank and at most 2,048 UTF-16 code units. The method returns whether
the save succeeded; a false return retains the declaration in memory and needs
`retrySave()` or `saveElsewhere(folder)`.

`batchInfo.chartIoConfirmations` retains the segment identity, UTC time,
explanation and the two declared facts. Its `runId` names the chart when one
exists and is empty for an ordinary batch. This is an operator declaration, not
instrument readback or proof that software closed the port. Calling the method
does not perform cleanup, take a reading or reopen a finished batch. The
window provides the same action through
[**Confirm cleanup...**](../ui/README.md#unconfirmed-connection-cleanup).

### Save recovery

If the initial batch folder cannot be created, use `session.saveElsewhere(folder)` with
a writable destination, then retry the reading. No data has been acquired yet.

If a MAT write fails, completed readings remain in the session. An earlier MAT
may contain fewer readings; compare `session.savedCount` with
`numel(session.measurements)`. Use `session.retrySave()` or `session.saveElsewhere(folder)` before
closing MATLAB.

If the acquisition-order CSV export at Finish fails, the complete MAT remains available and the
session stays open for recovery. `retrySave()` retries the export without
rewriting the current, finalized MAT. A retry does not acquire another reading.
Changing destination retains earlier files, records their locations in
`files.previousFolders`, and attempts to leave a `relocated_to.txt` notice in
the preceding folder. Current paths are in `session.files`.

These recovery controls also apply after Finish. If a finished batch cannot
save its MAT or CSV at a new destination, it stays closed to acquisition but
retains `retrySave()` and `saveElsewhere(folder)`. Recover those files before
**New batch** or a launcher replacement with `forceNew`; both refuse to replace
a batch with pending authoritative save recovery or unresolved connection
cleanup. A selected-chart CSV failure is optional:
it preserves MAT and any last successful chart CSV, reports unavailable output
or a stale last-good file, and does not by itself block acquisition or a new batch.

MAT and CSV replacements are staged: the new file is written before replacing
the previous snapshot.

### Export a saved batch

After adding `src` to the MATLAB path, load the
session MAT and choose its matching adapter. For a CR-250 batch:

```matlab
[file, folder] = uigetfile('*.mat', 'Select a saved measurement batch');
if ~isequal(file, 0)
    saved = load(fullfile(folder, file), 'measurements', 'batchInfo');
    adapter = colormeasure.drivers.cr.adapter('CR250');
    colormeasure.session.exportCsv(saved.measurements, saved.batchInfo, ...
        fullfile(folder, 'measurements_export.csv'), adapter.toTable);
end
```

Use `colormeasure.drivers.pr.adapter()` for PR, `colormeasure.drivers.cr.adapter('CR100')` or `colormeasure.drivers.cr.adapter('CR300')`
for those CR models, and `colormeasure.drivers.cs2000.adapter()` for CS batches. Adapter construction
and [exportCsv](../../src/+colormeasure/+session/exportCsv.m) do not open an instrument. The export preserves the
MAT and its acquisition-completion flag. Choose a new CSV filename to retain an
earlier export; an existing destination is replaced after successful writing.
The optional return value from `exportCsv` is the SHA-256 of the exact bytes
published. The writer computes it on the staged file before replacing the
destination, so a staging or digest failure leaves the earlier CSV intact:

```matlab
writetable(data, staged, 'QuoteStrings','all');
digest=colormeasure.fileDigest(staged);
movefile(staged, filename, 'f');
```

Session retains that digest for chart CSV currentness. A custom `exportCsv`
service must return it as well; a successful write without that witness is not
accepted as a current chart export.

The PR [colormeasure.drivers.pr.exportPR655Csv](../drivers/pr/api.md#export-a-saved-session-to-csv)
command also provides a file-picker shortcut for PR batches.

## Diagnostics and provenance

`measurements.mat` contains the complete `measurements` structs and `batchInfo`.
The session adds the MATLAB version, port, acquisition timestamps, sample name
and notes. Each adapter supplies these identity fields:

| Device | Identity saved with each reading |
| --- | --- |
| PR-655/670 | Verified model. The extra identity, setup and exposure reports in `instrumentMetadata` use the [optional metadata setting](../drivers/pr/api.md#device-reported-metadata); disabled reports there are marked `notQueried`. Settings receipts can independently contain reports queried while applying settings. |
| CR-100/250/300 | Parsed model, instrument ID/serial, firmware and port. Identity is read when connecting; measurement/settings replies are retained separately. |
| CS-2000/A | Model, variation, serial, port and raw `IDDR` identity reply. Firmware is not queried. |

CR and CS read identity once per connection and copy it into each native reading.
The shared session reconnects for every acquisition. Recorded protocol-reference
versions describe the driver's documentation source, not detected firmware.
OS USB descriptions and hardware IDs are not currently collected; the saved
serial port and protocol-reported identity are distinct from USB descriptors.

Native `instrumentMetadata` is separate from the `instrumentSettings`
application receipt. Every native session reading contains this field; it is an
empty struct when the adapter does not provide settings application. Inspect each report's status before using an unavailable
value; a successful settings receipt does not establish every identity field.
The MAT retains all metadata attached to the reading. CSV exports selected columns
and does not include the full raw reports or every identity field.

The event log stays in `session.log` and is not included automatically. The
session does not record the repository revision. Record physical setup and other
experimental conditions in sample notes.

When the adapter provides `configurationSummary`, the session logs it on opening.
The structured `session.configuration` is also saved in `batchInfo.configuration`.
These fields record requested host options, such as serial settings and timeouts;
they do not prove which settings the instrument used for an exposure.

CR and CS adapters preserve the native driver result in `driverSnapshot` and
retain `instrumentMetadata`; display fields do not replace that source record.
Their units, observer and conversion declarations accompany the reading rather
than being inferred from the chosen model alone. CS cleanup warnings are retained
in the session log when a reading completes but restoration needs attention.
See the family guides for available metadata and its limits.

For diagnostics, copy the session data and log to a separate MAT. Leave unknown
provenance empty; fill it only from the actual checkout or instrument/setup record:

```matlab
diagnostics = struct('measurements', session.measurements, ...
    'batchInfo', session.info, 'log', session.log, 'files', session.files);
provenance = struct('softwareRevision', '', 'setupNotes', '');
[file, folder] = uiputfile('*.mat', 'Save diagnostics separately', 'measurement_diagnostics.mat');
if ~isequal(file, 0)
    save(fullfile(folder, file), 'diagnostics', 'provenance');
end
```

Choose a different filename from the batch's `measurements.mat`. This captures
only the readings and log entries present at that moment; save again to include
later activity. It does not change the acquisition record or reconnect the meter.

## Window integration

For a custom script that needs the window and the PR automatic acquisition
settings, construct a session with its UI adapter and presentation services:

```matlab
io = colormeasure.ui.services();
session = colormeasure.session.Session(colormeasure.drivers.pr.uiAdapter(), destination, io);
session.show();
```

The standard launchers retain one batch per instrument model. Closing the window
hides it; running the launcher again restores it. **New batch** inherits the
connection options. To change those options, finish the existing batch, retain
its saved files, call `delete(session)`, then relaunch with the supported options.
A launcher refuses to restore a batch requested with different connection
options instead of silently reusing the previous settings.

See [adapter and presentation contracts](adapters.md) to integrate another
instrument or customize the interface.

## Compare retained readings

The comparison is independent of acquisition and leaves records unchanged.
Choose two samples and a white reading collected under the same setup. This
example uses a PR session; use the corresponding family's `viewData` adapter
for CR or CS records:

```matlab
data = colormeasure.drivers.pr.viewData(session.measurements);
comparison = colormeasure.analysis.compareReadings(data, 1, 2, 3); % A, B, Lab white
comparison.deltaE00
comparison.spectralRMS
```

A standard illuminant can be selected instead, with explicit white Y on the
same scale as the samples:

```matlab
% Example only: these samples use a reference-white Y of 100.
white = struct('illuminant', 'D65', 'Y', 100); % also D50 or A
comparison = colormeasure.analysis.compareReadings(data, 1, 2, white);
```

Preset selection defines the common Lab white. It does not reilluminate the
samples, adapt XYZ, or normalize each sample. White Y has an editable default
of 100; keep it only when it matches the experiment's reference and sample XYZ
scale, or enter the appropriate finite positive value. The helper
`colormeasure.colorimetry.illuminantWhite('D65', 100)` returns the derived white XYZ and
source metadata. [Reference data and method](illuminant-whites.md).

For live CR-100 and CS readings whose XYZ scale is not established by retained
metadata, Lab/ΔE stays unavailable until an eligible pair and white receive an
explicit same-scale declaration in the window. This declaration is analysis
metadata, not a unit conversion or a change to the acquired records. Changing
either selected sample, the white or White Y clears it. Synthetic demos supply
their known synthetic scale and do not need this declaration.

For command-based analysis, an optional fifth argument to `compareReadings`
accepts a declaration struct with `confirmed`, `referenceIndex`, `sampleIndex`,
`white`, and `declaredAtUTC`. Set `confirmed` to true only after checking the
common scale. The indices and white must match the current arguments exactly,
automatic XYZ compatibility must be unavailable, and the adapter must supply
eligible `xyzScaleDeclarationKeys`. A declaration cannot override known
incompatibility. `result.scaleDeclarationEligible`
reports eligibility, and `result.scaleDeclaration` retains an accepted
declaration. No declaration is added automatically by the command API.

Omit the fourth argument to calculate metrics that do not need a Lab white.
The returned struct includes sample/white indices, `whiteReference` metadata,
white XYZ, observer, declared
comparison conventions, any explicit same-scale declaration, both samples'
`Lab` rows, signed differences (B − A),
spectral support and units, validated `spectralWavelengths` / `spectralDifference` vectors,
and separate explanations for unavailable metrics. It is an analysis result;
it is not written into the session's measurement files. To retain it together
with a source snapshot in a separate analysis file:

```matlab
measurements = session.measurements;
[file, folder] = uiputfile('*.mat', 'Save comparison', 'comparison.mat');
if ~isequal(file, 0)
    save(fullfile(folder, file), 'comparison', 'measurements');
end
```

See the [comparison guide](../ui/README.md#compare-two-readings) for white selection,
metric definitions and availability rules.
For equations, source excerpts and the viewing-context limits of CIEDE2000,
see [the scientific reference](color-science.md#cielab-reference-white-and-color-differences).

## Troubleshooting after an update

Finish the active batch before updating this installation, then restart MATLAB.
MATLAB can retain classes and callbacks from the previous version while session
objects exist. `clear functions` does not reliably replace those objects.
Do not use `clear all` or `clear classes` to reload code during an active batch:
they clear workspace state without safely replacing live session objects.

If a launcher reports `Measurement:SessionCompatibility`, preserve any unsaved
readings before restarting. Inspect `session.files` for saved files; a separate
backup can be made from `measurements = session.measurements`. Do not overwrite
the batch MAT with a differently structured backup.

If the error persists after restarting, check that both results point to the
intended installation:

```matlab
which('colormeasure.session.Session','-all')
which('colormeasure.ui.launchSession','-all')
```

See MathWorks' [class-path behavior](https://www.mathworks.com/help/matlab/matlab_oop/organizing-classes-in-folders.html)
and [`clear` restrictions](https://www.mathworks.com/help/matlab/ref/clear.html).

## Tests

The [shared testing guide](../testing/workflow.md) covers software checks and manual checks
of the window. Each [instrument guide](../../README.md#use-the-drivers-in-your-scripts)
provides its hardware checklist.

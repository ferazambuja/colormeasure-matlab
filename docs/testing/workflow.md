# Shared measurement tests

## Automated checks

Use MATLAB R2026b or newer. R2026b is the minimum supported release and the
current test runtime. The public launcher uses the same MATLAB installation
as its caller and records the actual version in each report; it does not select
a newer installation automatically. Software checks have run on R2026b and,
for earlier revisions, R2026a Update 5. Those historical R2026a results do not
establish support for the current application. Newer releases require their
own qualification.

Set MATLAB's Current Folder to the project root and run:

```matlab
addpath(fullfile(pwd, 'src'));
report = colormeasure.runTests;
```

The command discovers all five direct groups: `pr`, `cr`, `cs2000`,
`colorimetry` and `workflow`. It runs their instrument, session, window and colorimetry tests
in a separate MATLAB process. It prints the report location. To choose a new or
empty report folder outside the code folder instead:

```matlab
reportFolder = uigetdir(pwd, 'Choose an empty report folder');
if isequal(reportFolder, 0), return; end
report = colormeasure.runTests(reportFolder);
```

For a Windows destination on another drive, use the picker above or a fully
qualified path such as `D:\MeasurementTests`; avoid `D:MeasurementTests`.

To run selected groups with the same process isolation:

```matlab
report = colormeasure.runTests(tempname, 'Groups', {'pr', 'workflow'});
```

`selectedGroups` and `omittedGroups` name the included and excluded groups;
`availableGroups` lists the supported choices. `isPartialRun` is true when any
group was excluded. `softwarePassed` and `expectedTestCount` refer to the
selected scope. Selecting all groups does not itself establish completion.
The `workflow` group includes the shared public-runner checks for all native
families; selecting only a device group runs that family's driver tests.

On a computer with spare memory, a run can be split across several worker
processes:

```matlab
report = colormeasure.runTests(tempname, 'Workers', 3);
```

Each worker is a separate MATLAB process, needing about the memory of one MATLAB
session. Each has its own startup and finish hooks, serial-port guards and
temporary folder. Worker *k* of *n* runs every *n*-th test, starting at test
*k*. The report folder's top-level files merge the workers' results in the
usual test order. The `worker-1`, `worker-2` … folders keep each process's log
and partial results, and Code Analyzer runs in worker 1 only. A merged run
passes only when every worker discovered the same tests in the same order and
every discovered test ran exactly once, by name, and passed. `report.json`
records that order as `shard.suiteDigest`, a SHA-256 of the test names. The
default is one worker.

The report folder contains:

| File | Contents |
| --- | --- |
| `report.json`, `report.mat` | Selected and omitted groups, result, MATLAB version, suite counts and original-driver comparison availability |
| `test-results.csv`, `test-results.mat` | Each test's name, pass/fail/incomplete status and duration |
| `matlab.log` | Detailed test output and errors |
| `checkcode.txt`, `checkcode.json`, `checkcode.mat` | MATLAB Code Analyzer findings |

A failed, incomplete or missing test stops the command with an error; inspect
`matlab.log` and `test-results.csv`. Code Analyzer messages are reported for
review and do not by themselves fail the run. Existing reports are never
overwritten.

Comparisons with the original school drivers use an explicitly selected
reference checkout:

```matlab
schoolRoot = '/path/to/MCSL-Tools';
report = colormeasure.runTests(tempname, 'SchoolRoot', schoolRoot);
```

Without `SchoolRoot`, the report identifies original-driver comparisons as not
run. Bundled protocol, numerical-reference and workflow tests still run. A
supplied incomplete or modified baseline fails its pinned identity checks;
it is not silently skipped. The original source paths and hashes belong to
that external checkout. See the [PR](pr.md), [CR](cr.md) and
[CS-2000](cs2000.md) references for comparison coverage.

These are software and synthetic checks, not physical instrument validation.
The worker blocks serial access. It starts in a separate output folder with
empty `startup.m` and `finish.m` hooks, so ordinary personal startup/shutdown
scripts do not run around the checks. The caller's workspace and active
measurement windows remain intact. MATLAB's JVM must be enabled and the
installation/license must permit another process. A run still going after 60
minutes is stopped; partial reports are retained. This isolation does not
replace a trusted MATLAB installation or isolate administrator changes to
MATLAB's startup machinery. See MathWorks' [startup documentation](https://www.mathworks.com/help/matlab/ref/startup.html).

Session-lifecycle tests exercise workspace
clearing and restoration, so use the launcher above instead of running those
tests in a desktop with an active batch.

### Native keyboard and readable layout

Run visible interaction checks in an otherwise idle MATLAB session. Use
synthetic demos and keep physical equipment disconnected. Never use a desktop
with an active measurement session.

For the native file chooser, start MATLAB normally from its application icon.
Test the picker and return focus in that desktop; the isolated software worker
uses substitutes and cannot validate operating-system dialogs. A rendered
figure or a screenshot does not establish keyboard, picker or screen-reader
acceptance. Record the actual MATLAB release, OS and result with this check.

1. In a PR demo, open **Settings**, select Exposure, enable Override and choose
   Fixed. With the selector focused, press Tab: the duration field must receive
   focus next. Enter `0`, choose **Use for next readings**, then type `100`
   without clicking another field and Tab out. The correction must reach the
   duration field; no measurement starts. Cancel discards the draft.
2. Repeat keyboard entry, help scrolling and Escape dismissal in CR and CS
   demos. Table row changes must show the selected setting's own help. An
   unread choice remains unselected. Tab must skip hidden/disabled editors.
3. Check the main window at its minimum restored size (960 × 650), larger and maximized. Check settings at
   640 × 480 and their normal size. Primary actions and validation feedback
   must remain visible; optional help/table content may scroll.
   After resizing an already visible window, check that the complete
   chromaticity diagram and the spectrum's scientific multiplier remain
   visible without selecting **Reset plots**. Preserve the selected readings
   and any deliberate plot limits throughout this check.
4. Check both light and dark themes at the machine's actual display scale,
   recording each theme as a separate case. Record
   MATLAB, OS, logical window dimensions and display scale with results. Do not
   report untested scale factors, operating systems or screen readers as
   supported based on these checks.

### Saving and connection recovery

Run the software checks with injected failures and blocked serial APIs:

```matlab
reportFolder = fullfile(tempdir, 'colormeasure-recovery-checks');
colormeasure.runTests(reportFolder, 'Groups', {'workflow', 'pr'});
```

Choose a new report folder for each run. These checks cover MAT/CSV failures,
unconfirmed direct connection cleanup, and saving while another instrument is selected. They do
not exercise a physical disconnect or the operating system's file chooser.

For visible checks, use an isolated synthetic session with a failing save
callback supplied through the demo's I/O services. Keep the failed batch alive;
let the callback succeed for the retry. Do not induce faults in a laboratory
measurement session or change a physical instrument's connection for this test.

1. At the minimum window size, acquire one synthetic reading and inspect the
   injected save failure. The retained reading, recovery message, **Retry save**
   and **Another folder** must remain accessible on the Measure, Data and
   Compare tabs. Use pointer and keyboard input; invoking callbacks alone does
   not check reachability.
2. Edit the next sample's name and notes, select another instrument in the
   header, then choose **Retry save**. The current batch must save without
   another reading or a device switch. The sample field text and selected
   instrument must remain unchanged. Save callbacks do not force a sample
   commit; ordinary focus changes can commit fields normally. Repeat
   **Another folder** with an injected destination selection; check the native
   chooser separately.
   For that native check, test cancellation, a destination save failure and
   successful relocation using only test-owned folders. Wait for each callback
   to finish without clicking or raising the measurement window. After Cancel
   or failure, Space must reopen **Another folder**. After successful relocation
   on the Measure tab, typing must reach the sample-name field. On another tab,
   focus must return to an eligible control in the same window and keep that
   tab selected. A hidden/replaced owner must not regain focus; another active
   window must not lose it. Reload the relocated MAT file and compare readings
   and batch metadata, confirming no additional acquisition.
3. Inject a direct connection-release failure. The retained reading and cleanup
   diagnosis must remain available. With a reachable returned owner, **Retry
   cleanup** retries release without another reading. With no reachable owner,
   **Confirm cleanup...** records explicit connection-closed and idle checks;
   the declaration does not operate or validate the instrument.
4. Inject a changed chart CSV. Keep the external file and MAT unchanged. Retry
   stays hidden for this refusal, while **Another folder** offers a new copy
   of retained data without another measurement.
5. Enter a settings draft, press Escape and reopen it. Confirm the draft was
   discarded without acquiring. Change instruments only after resolving save
   recovery and cleanup; retain each instrument's independent batch.

Record exact source, window size, actual input and saved-data checks. Physical
calibration, disconnect behavior and native file choosers require separate
checks. Injected software states do not establish those outcomes.

### Standalone direct dependency boundary

The student tree contains no operational Python backend, TI2 import or TI3
publisher. Direct tests use the ordinary public five-group discovery and
hardware guards, including native saved-source and changed-file refusals.
Only this direct installation's five groups count toward its coverage.

## Numerical and presentation checks

[Comparison tests](../../tests/workflow/testMeasurementComparison.m) cover published
reference values through the XYZ/common-white route, compatibility declarations,
range limits and grid rules. [Background tests](../../tests/workflow/testChromaticityBackground.m)
check diagram geometry and masking; [result tests](../../tests/workflow/testMeasurementResults.m)
check display input handling and selection. The
[color library suite](../../tests/colorimetry) includes all 34 published
Sharma pairs and independent numerical cases. These are computational checks;
physical and perceptual validation require the appropriate experiments.

[Instrument-switching tests](../../tests/workflow/testMeasurementDeviceSwitching.m)
check model selection, independent batches, restoration of connection settings
and drafts, cancelled opening, and refusal while an operation is active.
Interactive demos stay in demo mode and wait for **Measure**; gallery mode
creates synthetic examples when opening a new gallery.

Native [settings tests](../../tests/workflow/testMeasurementSettingsUI.m) check
that unread, missing and unrecognized choices cannot become an override merely
by enabling its checkbox. An incomplete choice stays incomplete across row
changes and a later settings read; **Use for next readings** requires an
explicit selection. Known values, duplicate names with distinct IDs, and a
valid instrument value of zero retain their exact meaning. Cancel, clearing
overrides and reopening are checked without sending settings or measurements.
For a manual demo check, open a native device's **Settings...** before reading
settings, enable a choice override, and confirm that **Choose a value** remains
selected until you choose an entry. Cancel must leave the session unchanged.

## Device and UI procedures

- [PR-655](../beta-testing/PR655.md), [CR](../beta-testing/CR.md) and
  [CS-2000](../beta-testing/CS2000.md) instrument checks
- [Device identity checks](../beta-testing/DEVICE_IDENTITY.md)
- [Detailed UI checks](../beta-testing/UI.md)

Students can use the shorter [demo and device-test quick start](../beta-testing/README.md).

## Maintaining tests

Keep regression fixtures and the device checklist aligned with changes to
commands, saved fields, controls and supported device behavior. Run
`colormeasure.runTests` after changes that affect shared workflows. The runner
discovers test files automatically; it needs no manually maintained test count.
Preserve pinned original and published numerical references. For an intentional
behavior change, record the expected difference instead of regenerating a
reference to match the new output.

### Session compatibility

Session lifecycle checks also exercise older-class metadata refusal without
changing retained readings or registry state. This is a compatibility guard,
not support for hot-reloading an active session. For changes to that guard,
also reproduce the old-class/new-launcher transition in a separate disposable
MATLAB process using synthetic readings only: retain an older batch, introduce
the updated path, and verify `Measurement:SessionCompatibility` before a folder
prompt, acquisition or registry replacement. Test a new adapter key and demo
batch mode as well as restoration. Keep this experiment outside an active
desktop; a clean-process suite cannot establish class-switch behavior.

### Native exposure and interval presentation

Run the full software command above after changing a native settings editor.
`testNativeSettingsPresentation` checks channel identities and model-dependent
ranges; `testMeasurementSettingsUI` checks the actual draft controls and saved
wire values using simulated readback.

For a manual demo inspection:

1. In PR settings, confirm an unread exposure remains unselected when Override
   is enabled. Choose Adaptive, then Fixed: the fixed duration starts blank.
   Enter a value below the model minimum and verify it cannot be applied.
   Adaptive must retain `exposureMilliseconds = 0`. On PR-670, stage Extended
   sensitivity with a duration above 6000 ms; clearing that choice must restore
   the Standard limit unless Extended was actually read from the instrument.
2. In CS-2000 settings, select Manual in the draft and inspect the interval
   help. Switch to Multi and confirm its whole-second range. Last read must
   keep the observed speed and value throughout these edits. Cancel must leave
   session overrides unchanged. Normal/Fast must refuse an interval override.
3. Confirm Ch00 is labeled manufacturer calibration. Only a queried user
   channel has a reported name; all other channel names stay unread.

These are UI and simulation checks. Real capability readback, settings command
acknowledgments and resulting exposure behavior remain physical-device checks
in the instrument-specific test guides, requiring separate authorization.

## Retained-reading annotations

The automated workflow cases exercise editing names and multiline notes with
real MAT/CSV persistence and simulated acquisition. They verify original
annotations, immutable values, duplicate-name indexing, revision-aware save
retry, relocation, finished-batch MAT/CSV failure recovery and the acquisition
lock. Native tests verify that later persistence preserves
edits without changing measured values, original acquisition metadata or retained chart-coordinate identities.

For a desktop check, measure two demo samples, select one and choose **Edit…**.
Cancel a draft, then save a different name and multiline notes. Check Data,
plot labels, comparison selectors, the MAT and final CSV. Edit a finished batch
and confirm that Measure remains disabled. Resize the window: Mode remains
visible; narrow tables omit the Notes preview while Data retains full notes.
Try a command-window edit while the dialog is open; its stale draft must not
replace the command's changes. Native keyboard/focus and screen-reader behavior
require a normal desktop check; simulated callbacks do not establish them.

### Presentation source lifetime

[Source-lifetime tests](../../tests/workflow/testUiSourceSnapshot.m) run a
separate MATLAB process against a disposable source copy. They edit that
copy's UI class while its window is retained, restore the same batch, and
check fresh callbacks, sample drafts, requested settings, readings and files.
They also check active acquisition, cleanup and editor refusal, plus runtime-source
refusal after deleting the figure. The original installation is never edited;
serial APIs are blocked. These checks run in the normal workflow test group.

Programmatic callbacks establish software behavior. Real Tab, typing,
shortcuts, modal focus and window closing still need native desktop interaction
against the qualified installation. Keep that evidence separate from these
source-copy and rendering checks.

When a folder chooser loses its owner window, restoring that window may recreate
its controls only while the presentation source is unchanged. The controls stay
disabled until the chooser returns. Verify that cancelling preserves readings,
the save destination and recovery actions. A source change, active acquisition
or unconfirmed connection cleanup must still refuse reconstruction.

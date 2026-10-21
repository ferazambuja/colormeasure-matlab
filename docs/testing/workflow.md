# MATLAB software tests

This reference is for checking code changes. To try an instrument and send
feedback, use the shorter [device-test walkthrough](../beta-testing/README.md).

## Automated checks

Use MATLAB **R2026b or newer**, with the JVM enabled. Set **Current Folder** to
the extracted download or repository folder, then run:

```matlab
setupColorMeasure
report = colormeasure.runTests;
```

The command starts a separate MATLAB process, runs the five groups below and
prints the report location. Tests use simulated instrument responses and block
physical serial access. They do not establish calibration or optical accuracy.

| Group | Checks |
| --- | --- |
| `pr` | Photo Research driver and records |
| `cr` | Colorimetry Research drivers and records |
| `cs2000` | Konica Minolta driver and records |
| `colorimetry` | Numerical calculations and reference data |
| `workflow` | Shared sessions, app controls, saving, charts and the test launcher |

Run one suite at a time with the default single worker. For a focused change,
select the affected groups:

```matlab
report = colormeasure.runTests(tempname, 'Groups', {'pr', 'workflow'});
```

To choose a report destination, pass a new or empty folder. Existing reports
are preserved:

```matlab
reportFolder = uigetdir(pwd, 'Choose an empty report folder');
if ~isequal(reportFolder, 0)
    report = colormeasure.runTests(reportFolder);
end
```

Use the picker or a full Windows path such as `D:\MeasurementTests` for another
drive. `tempname` is convenient when you do not need to select a folder.

### Read the results

| Report file | Contents |
| --- | --- |
| `report.json`, `report.mat` | Included/omitted groups, MATLAB version, counts and overall result |
| `test-results.csv`, `test-results.mat` | Individual pass/fail/incomplete results and durations |
| `matlab.log` | Test output and errors |
| `checkcode.txt`, `checkcode.json`, `checkcode.mat` | MATLAB Code Analyzer findings |

A failed, incomplete or missing test makes the command error. Inspect the
report files before drawing a conclusion. Analyzer findings are reported for
review and do not by themselves fail the run.

`isPartialRun`, `selectedGroups` and `omittedGroups` describe scope.
`softwarePassed` applies to that scope. The runner discovers tests automatically;
there is no fixed test count to maintain.

The worker leaves your workspace and measurement windows intact, but use it
instead of running lifecycle tests directly in a desktop with an active batch.
The MATLAB installation and license must permit another process. A run over
60 minutes is stopped with partial reports retained.

### Optional original-driver comparisons

Some tests compare against the original MCSL-Tools drivers. If you have that
reference checkout, supply its root:

```matlab
schoolRoot = '/path/to/MCSL-Tools';
report = colormeasure.runTests(tempname, 'SchoolRoot', schoolRoot);
```

The checkout must match the pinned reference files. Without it, reports identify
these comparisons as not run; the bundled protocol, numerical and workflow
checks still run. See the [PR](pr.md), [CR](cr.md) and [CS-2000](cs2000.md)
test references for details.

## Numerical and presentation checks

The colorimetry suite includes published CIEDE2000 reference pairs and independent
numerical cases. Workflow tests cover comparison rules, chromaticity diagrams,
settings drafts, reading annotations, MAT/CSV recovery and chart continuation.

Automated UI callbacks and screenshots do not check real keyboard input, native
folder dialogs or screen-reader access. Check those separately in a normal
MATLAB desktop, using generated demo readings:

1. Open [demoDirectInstruments.m](../../demoDirectInstruments.m), click **Run**,
   and collect two readings. Inspect Data, plots and table selection.
2. Open Settings. Use Tab to reach controls, enter values, read help and cancel
   a draft. Reopen it to confirm cancellation discarded the draft.
3. Resize the main window down to 960 × 650 and settings to 640 × 480. Check
   that actions, errors and plot labels remain reachable. Try light/dark themes.
4. Edit a reading's name and notes. Finish the batch, inspect MAT/CSV, and check
   that a later edit leaves measurement disabled for that finished batch.
5. Try a chart, a repeat and an incomplete finish. Continue it into a new batch
   and inspect the selected results and saved source history.
6. Test folder-picker cancellation and focus return using test-owned folders.

Use a separate demo for injected save/cleanup failures. Keep failed data in
memory until recovery is checked; do not induce faults in a lab measurement.
Record MATLAB release, OS, actions and outcomes when reporting a UI problem.

## Maintaining tests

Update regression cases when changing commands, saved fields or controls. Run
the affected instrument groups and `workflow` for changes to native settings or
shared app behavior; include `colorimetry` for calculation changes. Preserve
published numerical and original-driver references. An intentional output
change needs an explanation, not a regenerated reference chosen to match it.

Source-lifetime tests use a disposable source copy to check window restoration
after presentation edits and refusal after runtime changes. They never edit the
installed project. Users updating the app should finish saving and restart
MATLAB; these tests do not make live updates a supported workflow.

Detailed procedures are available for [PR-655](../beta-testing/PR655.md),
[CR](../beta-testing/CR.md), [CS-2000](../beta-testing/CS2000.md),
[device identity](../beta-testing/DEVICE_IDENTITY.md) and
[UI interaction](../beta-testing/UI.md). Use those when investigating a specific
problem; they are not prerequisites for the first device test.

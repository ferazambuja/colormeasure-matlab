# Beta UI and analysis checks

> **TEMPORARY BETA VALIDATION GUIDE**
> Scope: [validation status and interpretation](README.md#validation-status-and-interpretation).

Temporary acceptance checks for this release. Start with the
[short demo guide](README.md). These checks use generated readings;
physical acquisition and optical comparisons belong to each instrument checklist.

Use MATLAB R2026b or newer and record the revision being checked. For the full
software gate, with the project as MATLAB's Current Folder:

```matlab
addpath(fullfile(pwd, 'src'));
report = colormeasure.runTests(tempname);
```

This runs every bundled group in an isolated worker with physical serial APIs
blocked. Original-school comparisons require the separate `SchoolRoot` option
in the [test guide](../testing/workflow.md#automated-checks). Inspect the recorded
groups and results before reporting a pass. The interaction steps below require
an otherwise idle desktop and are additional checks, not outcomes of this command.

## Illumination workflow

The normal software-check command includes numerical white mapping, reference
ratios, target-illuminant normalization, incompatible-input refusals, and UI
apply/reset/export behavior. Demos exercise these paths with synthetic data;
they cannot verify reference quality, actual illumination or optical accuracy.

The tests also distinguish spectral comparison from eligibility for a radiance
sample/reference ratio. Recognized PR, CR and CS radiance fixtures and spectral
demos must calculate; native reflectance, other quantities and missing or
inconsistent declarations must refuse in both the calculation and the window.
Matching spectra remain comparable when the ratio is unavailable.

For physical testing, retain the measured white and sample spectra, verify the
reference file belongs to that white and geometry, and compare against the lab's
established calculation or manufacturer workflow. A known gray sample should
retain its measured spectral behavior; do not infer a pass/fail tolerance from
the demo. Check that returning to **Measured view** leaves acquired values and
files unchanged. These checks supplement each device's testing guide.

## Window checks without hardware

### Switch instruments

For the new-batch and cancellation checks below, use a fresh MATLAB process
after saving any existing work. In a process with retained demo sessions, a
launcher restores that model's batch instead of asking for another folder.

Run `session = colormeasure.demo('PR655')` and choose a demo destination. This starts
an interactive demo with no readings. Check the following before using a gallery:

1. Acquire a reading with **Measure**, then type the next sample's name and
   notes without measuring again.
2. Select **CR-250** in **Instrument**. Confirm the current readings remain
   visible and acquisition controls are disabled until the selection is opened
   or changed back. Selecting a model alone must not connect or acquire.
3. Select **Open**, then cancel its folder picker. The PR window and its sample
   draft must remain available. Repeat and choose a folder to open an empty
   CR-250 demo batch.
4. Acquire a CR-250 demo reading. Switch back to PR with **Instrument → Open**.
   Its earlier reading, sample draft, port and staged settings must be retained.
   The two models must have separate batches and saved files.
5. Switch to a finished batch and inspect its results. **New batch** remains the
   explicit way to start another batch for that model. Closing and reopening a
   window must preserve its unfinished batch.

Repeat with CR-100, CR-300 and CS-2000. Switching from an interactive demo must
stay in demo mode and never acquire until **Measure** is selected. Gallery
windows instead use **Open gallery** and intentionally populate new examples.

### Inspect plots and analysis

Keep the repository `src` folder on the MATLAB path. Start a populated synthetic
collection for the device being tested:

```matlab
session = colormeasure.demo('CR250', 'gallery');
before = session.measurements;
```

Use `PR655`, `CR100`, `CR300` or `CS2000` to inspect another device.

1. In **Color**, select a sample, **Chromatic adaptation**, a source
   white and destination white. Changing controls alone must not acquire or
   calculate a reading. **Apply view** adds a separately labeled derived point.
   Acquired spectra stay unchanged.
2. On a spectral demo, select **Reflectance / relight**, a sample and the
   broadband reference reading. Explicitly choose the ideal-white assumption
   and confirm the setup to exercise the controls. The result must be labeled
   as a relative spectral ratio. These generated profiles do not validate an
   actual reflective-object setup. CR-100 must explain that it has no spectrum.
3. Change the target illuminant and apply again. Inspect derived XYZ and the
   spectral factor. **Measured view** restores the acquired plot; derived
   values never replace table rows.
4. Export to a new analysis MAT file and inspect `analysis.sourceMeasurements`,
   `analysis.config` and `analysis.provenance.quantityContext`. Both selected
   rows must retain their declared quantity and unit label, and the configuration
   must retain the setup confirmation. Selecting an existing filename
   must refuse to overwrite it. Changes to the selection invalidate the old
   result until **Apply view** runs again.
5. Verify `isequaln(before, session.measurements)` in MATLAB. Inspect scrolling
   and fixed action buttons at a compact window size. On CR/CS, open **Settings... →
   Instrument help** and check that the text is readable and scrollable; demos
   do not require live readiness confirmation.

The automated tests cover these calculations and preservation rules. The
instrument guides provide their hardware checks. Before interpreting real
object-color results, check a characterized white/reference under a stable,
recorded setup; a successful demo is not physical validation.

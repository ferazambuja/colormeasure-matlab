# PR-655 software tests

These checks exercise the driver and saved-data contracts.

<!-- BEGIN TEMPORARY-BETA-TESTING -->

For the current release's physical-device checklist, see [PR-655 beta hardware checks](../beta-testing/PR655.md).

<!-- END TEMPORARY-BETA-TESTING -->

## Software checks

With MATLAB's Current Folder at the project root, add `src` and run:

```matlab
addpath(fullfile(pwd, 'src'));
report = colormeasure.runTests;
```

This runs all instrument, session, window and colorimetry tests in a separate
MATLAB process. It blocks physical serial access and retains individual test
results, raw output and Code Analyzer findings. Failed, incomplete, missing or
empty tests fail the run. Existing report folders must be empty. The MATLAB JVM
and a license permitting a second process are required.

```matlab
report = colormeasure.runTests(fullfile(tempdir, 'measurement-checks'));
```

To include original-driver comparisons, supply a separate school checkout:

```matlab
schoolRoot = '/path/to/MCSL-Tools';
report = colormeasure.runTests(tempname, 'SchoolRoot', schoolRoot);
```

Without `SchoolRoot`, only the original-school comparison suites are omitted;
the report identifies that scope. With a supplied baseline, pinned source
identity checks reject missing or changed required files. The runner does not
infer the baseline from the standalone repository's location.

From a terminal at the project root:

```sh
matlab -batch "addpath(fullfile(pwd,'src')); colormeasure.runTests;"
```

Replace `matlab` with its installed executable if necessary. See the
[shared testing guide](workflow.md) for report files, process isolation and
interpretation. A software pass does not establish physical operation,
calibration or Windows behavior. Windows execution remains unvalidated.

## Compare with the original code

### Software comparison

`colormeasure.runTests(..., 'SchoolRoot', schoolRoot)` includes
`testPR655LegacyParity`. This suite executes the original driver from
**Devices/PR655** in the selected school checkout, preserving its measurement
logic and substituting a fake serial connection in a temporary copy. The reference is the school code at
[`ce4e63f19ad54617478ff84791483deec920532d`](https://github.com/RIT-MCSL/MCSL-Tools/tree/ce4e63f19ad54617478ff84791483deec920532d/Devices/PR655).
Frozen conversion functions and checked observer data keep the reference
independent of changes to the active conversion code. See the
[baseline sources and test scope](../../tests/drivers/pr/data/legacy/README.md).

| Item | Expected result and reason |
| --- | --- |
| Complete, original-compatible PR-655 reply | The same 101 wavelengths and spectral values, software total and history layout |
| Computed XYZ | Agreement within floating-point rounding; the original recomputes all columns, while current computes the latest column with `colormeasure.colorimetry.spectra2XYZ`, preserving the same integration convention; official CMF values differ by at most 1.11e-16 from the inherited table |
| Software total | Both use `sum(radiance) * 4` on the native PR-655 grid; neither changes to trapezoidal integration |
| Shorter valid header | current reads the fields correctly; the original fixed 39-character offset can corrupt the first spectral row. The test verifies this intended difference |
| Invalid or incomplete reply | current validates status, rows and completion before adding a reading; matching a partial or malformed original reading is not required |
| Metadata and timing | current retains header values and uses bounded waits/paced commands. Extra identity/setup queries require explicit opt-in; differences in elapsed time are expected |
| Units labels | current preserves the reported code and raw numbers; cautious units labels do not mean the spectrum was rescaled |
| Meter-reported total | New `instrumentTotalRadiance` is separate from the inherited software `totalRadiance`; equality between these two quantities is not an old/new requirement |

These comparisons check software behavior, not calibration. CIEDE2000 does not participate in acquisition XYZ or spectral totals.
The [library compatibility guide](../colorimetry/compatibility.md) lists
stricter input checks and deliberate differences; the [science guide](../colorimetry/science.md)
contains the equations, implementation excerpts and sources.

## Maintaining these checks

See the [shared test-maintenance guidance](workflow.md#maintaining-tests).

The protocol, session, settings and presentation suites build
the driver with a `colormeasuretest.FakeClock` through its `'Clock'` option,
and the fake serial port shares that clock: queued reply delays, deadlines and
the driver's own pacing advance on one simulated time base, so a timeout test
takes milliseconds and pins its deadline exactly. The simulated clock only
advances time: unlike `pause`, it does not service graphics or callback
events, so a test that needs the event queue serviced during a measurement
must call `drawnow` itself. One protocol test builds the driver without the
option and pins that the default is the wall clock; `testPR655LegacyParity`
keeps the wall clock too, as the original driver has no such seam.
PR-specific fixtures in `tests/drivers/pr/testPR655Settings.m` cover coupled settings,
partial application, contradictory readback and calibration-list counts.
Preserve the original comparison sources in [reference fixtures](../../tests/drivers/pr/data/legacy/README.md)
and record deliberate numerical differences separately.

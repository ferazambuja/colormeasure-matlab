# CR software-test reference

<!-- BEGIN TEMPORARY-BETA-TESTING -->

For current beta testing and physical-device procedures, see the
[CR beta checklist](../beta-testing/CR.md).

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

## Adapter and demo coverage

The direct-driver suite also checks `snapshot()` against native Save for all
three models, independent copies, empty/erased/disconnected histories and
command-free preparation guidance. These checks run without the shared UI;
adapter and window tests cover their additional integration behavior.

The one-shot example checks in `testCRInstrument` cover all three model choices,
default and custom host deadlines, complete saved results and exactly one `M`
command per call. Invalid options must fail before commands or saving. An
acquisition failure must release the connection and preserve an existing output
file. Keep these checks aligned with the options documented in the README.

`testCRAdapter` also checks model-specific preparation help without port
enumeration and disables the live reminder for every synthetic demo mode.
The shared Session tests check that accessing help performs no connection,
measurement, saving or window creation. Shared UI tests separately exercise
the first-measurement reminder, cancellation and reopening help; a headless
family pass does not establish that window behavior.

Keep the complete repository, including shared session and colorimetry code, for the full suite. Adapter checks instantiate actual drivers through `DriverFactory` and injected transports; they verify one exposure, snapshot/native Save equivalence, complete metadata retention, error cleanup, quantity-specific keys, and spectral versus CR-100 CSV rows. Synthetic checks exercise all three model records and two-reading batch saving without windows or physical enumeration, including failed first/second acquisition and failed final MAT/CSV persistence. CR launcher tests use a scoped shared-launch stub without opening actual UI windows. The shared UI suite separately checks real window interactions and restorable galleries.

`testCRUISettings` checks the separate UI automatic policy: only the UI adapter
has the settings hook; settings reads do not consume synthetic profiles;
virtual settings persist across connections; invalid coupled drafts leave
state unchanged; and applied settings receipts survive MAT saving/reloading.
An actual native driver with an injected transport verifies settings application
before exactly one exposure. No physical ports are used.

`testCRSettings` uses a mutable in-memory instrument to check current `RS`
setup independently of last-capture `RM` metadata. It covers capability IDs and
limits, fragmented/delayed lists, malformed and incomplete replies, model and
firmware gates, CR100 Colorimeter selection, both directions of its
range/exposure dependency, explicit overrides and unchanged-value skipping.
It verifies the final requested configuration, including fields that were
unchanged before another setter ran. Late capability and setup timeouts retain
previously received values and replies in the failed before/after report. The
failing exchange also retains its header, completed rows and partial tail as
incomplete/error raw data, without creating usable setting values; public read
methods still throw. Partial failures retain acknowledgements; failed
verification blocks `Measure` until a successful recovery. No failure
triggers a retry, reset, rollback or exposure. Maximum-auto-exposure receipts
remain acknowledged-only because no `RS` readback is documented. Saving a
receipt preserves its reports and raw responses without changing history.

For a focused run inside an already isolated test MATLAB with the package and
test directories on its path:

```matlab
projectRoot = colormeasure.root();
addpath(fullfile(projectRoot,'tests'));
results = runtests(fullfile(projectRoot,'tests','drivers','cr','testCRSettings.m'));
assertSuccess(results);
```

Use the full launcher command above for final validation; this focused command
does not replace its startup-hook and hardware guards.

## Reading the results

The printed folder contains:

| File | Purpose |
| --- | --- |
| `matlab.log` | Raw MATLAB output and failure diagnostics |
| `test-results.csv`, `test-results.mat` | Every discovered test name, outcome and duration; MAT also retains MATLAB test results |
| `checkcode.txt` | Actual Code Analyzer output, grouped by source file |
| `checkcode.json`, `checkcode.mat` | Every analyzed file and its structured messages |
| `report.json`, `report.mat` | MATLAB release, platform, bundle path, exact-repository Git metadata when available, original-comparison scope, start/end times and totals |
| `hardware-guards/` | Temporary serial API stubs used only by the test process |
| `startup.m`, `finish.m` | Empty worker-owned hooks that bypass personal startup/shutdown scripts |

Keep a report from the exact revision being evaluated. An uncommitted checkout
is identified by its dirty status; a revision alone does not describe those
edits. Read failures and Analyzer messages rather than accepting an old test
count. Do not commit generated reports or measurement files into the driver.
The worker attempts both tests and analysis even when tests fail. A MATLAB
startup failure or interruption can leave only a partial report and log. A copy
without its own Git metadata reports that metadata as unavailable instead of
naming an unrelated ancestor checkout. Read `originalComparison` alongside the
passing test count.

With an explicit `SchoolRoot`, the command also runs
[actual original-code comparisons](../drivers/cr/original-comparison.md), including pinned source/dependency hashes, matching numerical fixtures for all
three models, and observable intentional differences. It needs neither Git nor
a network connection to verify that baseline. The old fixed-byte waits have a
test-only poll bound; they cannot stall the suite indefinitely. The numerical
spectral comparison uses an explicitly synthetic legacy-parser layout; a
separate canonical CR/LF fixture records the original parsing failure.

The bundled numerical suite additionally checks its official CIE observer
data, retained MCSL reference spectra, CCT validity, coordinate transforms and
published CIEDE2000 reference pairs. Not every library function is used by the
CR driver. The CR integration tests establish its actual `spectra2XYZ`,
`spectralIntegral` and `XYZ2CCT` calls, saved source labels, stricter grid
validation and public error behavior. Read the [scientific guide](../drivers/cr/color-science.md)
for rounding tolerances and deliberate differences; software agreement does
not establish absolute instrument units or calibration.

Software checks establish parsing, simulated communication, history integrity,
saving and numerical behavior. They cannot establish that a real OS driver,
USB/serial link, firmware revision, accessory or physical measurement works.

## Maintaining the tests

Changes to adapters or shared presentation also require the shared workflow
checks in `colormeasure.runTests` and review of the [window guide](../drivers/cr/shared-ui.md).
Keep native Save comparisons separate from the session MAT format.

For every change to discovery, commands, deadlines, metadata, saved structure,
scientific interpretation or cleanup:

- Update the corresponding fixture and observable public-behavior assertion;
  add a failure case that demonstrates the defect being fixed.
- Update user/API/science documentation when an operator action or expected result changes.
- Run `colormeasure.runTests` from the changed checkout. Review newly discovered tests,
  named failures and raw Analyzer output; do not preserve a historical total.
- Update the original/current expectation table and executed comparisons when an
  intended match becomes a deliberate difference. Preserve the original
  baseline and its dependency hashes; a converter change requires a reviewed
  scientific-baseline decision, not automatic regeneration of hashes. These
  pins constrain the original-comparison fixture baseline, not runtime use of current.
- Remove obsolete fixtures and assertions only after identifying the behavior
  that supersedes them. Keep useful negative cases, including timeouts,
  unsupported replies, wrong models and malformed/incomplete spectra.
- Check for stale command examples, removed metadata fields, fixed port names,
  test lists/counts, old retry expectations and links to superseded sources.
  Retain protocol revisions and scientific references needed to explain the
  current implementation.
- Record new hardware questions as untested instead of broadening a previous
  lab result.

No manually maintained suite list is needed: newly added family and bundled
library tests and MATLAB sources are included on the next run. A change to
`src/+colormeasure/+colorimetry` also needs review and relevant tests for its other
consumers. Keep its source manifest and attribution current. The original
`Convert` files and original drivers remain the separately pinned comparison
baseline; updating the current library does not authorize modifying either.

### Runtime compatibility

For shared-launcher changes, check older loaded classes in a separate MATLAB
process with synthetic readings. A rejected launch must preserve retained
readings, files and active sessions, and must not acquire a new reading. Cover
batch, gallery and restore entry points. See
[updating an installation](../session/README.md#troubleshooting-after-an-update)
for the operator's recovery procedure.

### Test support interfaces

Native constructors accept `Transport`, `Clock` and `PortList` for isolated
tests. `Transport` supplies the simulated serial peer. `Clock` supplies the
time base for the transport's deadline loops (`now()` and `sleep(seconds)`);
a `colormeasuretest.FakeClock` shared with the fake port makes delayed replies
and timeouts deterministic. `PortList` is a no-argument
function returning available names; its normal default is
`serialportlist("available")`. An explicit port bypasses that lookup. Tests of
automatic selection inject both options so they exercise parsing and selection
without enumerating or opening operating-system ports.

The shared adapter also accepts `DriverFactory(model, port, constructorOptions...)`
and `PortList(scope)`. These let tests use native parsing with an in-memory
peer, or an entirely synthetic driver. Ordinary acquisition leaves these
options unset. See [colormeasure.drivers.cr.adapter](../../src/+colormeasure/+drivers/+cr/adapter.m) and the
[adapter checks](../../tests/drivers/cr/testCRAdapter.m) for their use.

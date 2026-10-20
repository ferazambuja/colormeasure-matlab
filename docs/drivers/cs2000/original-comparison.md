# Compare the original and current CS-2000 drivers

The original [CS2000.m](https://github.com/RIT-MCSL/MCSL-Tools/blob/ce4e63f19ad54617478ff84791483deec920532d/Devices/MinoltaCS2000/CS2000.m), base classes and variants belong to
`Devices/MinoltaCS2000` in the separate MCSL-Tools repository. The retained
baseline is revision `ce4e63f19ad54617478ff84791483deec920532d`.
This repository supplies `colormeasure.drivers.cs2000`.

## Selecting the driver

Add this repository's `src` folder:

```matlab
addpath(fullfile(pwd,'src')); % Current Folder: the project folder containing src
which colormeasure.drivers.cs2000.CS2000 -all
```

The qualified constructor resolves to
`src/+colormeasure/+drivers/+cs2000/CS2000.m`. The unqualified `CS2000` selects
an original driver only when its separate folder is on the path. Checking
resolution does not connect to an instrument.

To use this implementation in a script, call
`colormeasure.drivers.cs2000.CS2000(port)` with `src` on the path. Connection,
acquisition and persistence method names remain familiar to users of the
original driver.
Acquisition arrays have protected setters. Saved data is an ordinary value
struct for offline analysis; reading it does not change a live driver's history:

```matlab
saved = load('saved-measurement.mat', 'measurements');
plot(saved.measurements.wavelengths, saved.measurements.spectralData);
```

Code manipulating legacy `serial` internals must use constructor options
instead. Ordinary `Connect` preserves speed and display observer. A device
left in Manual mode keeps its selected integration time, potentially 120 seconds. The caller should inspect its configuration;
`MeasureManual()` provides an explicit temporary integration-time choice.
Requested XYZ still selects the 1931 2° block independently of display observer.
USB defaults to 115200 baud. For physical RS-232C, use
`colormeasure.drivers.cs2000.CS2000(port,'BaudRate',9600,'FlowControl','hardware')` when that matches
the instrument; USB ignores nominal baud per the specification.
Errors preserve complete history.

## Automated comparison without an instrument

From this repository's root in MATLAB:

```matlab
addpath(fullfile(pwd,'src'));
schoolRoot = '/path/to/MCSL-Tools';
report = colormeasure.runTests(tempname, 'SchoolRoot', schoolRoot);
```

Without `SchoolRoot`, bundled tests run and original comparisons are reported
as not run. A supplied baseline is checked rather than inferred from folder
layout. The [testing guide](../../testing/cs2000.md) describes the isolated worker.
The [baseline hash manifest](../../../tests/drivers/cs2000/fixtures/original-source.json) detects
edits to the original files before their results are accepted. The
[comparison tests](../../../tests/drivers/cs2000/repository/testCS2000OriginalComparison.m) execute the actual original `CS2000`,
`Spectroradiometer` and `Share/COMClass` code, together with the relevant
manual/strobe variants, rather than reproducing their parsing in a test.

The original transport expects the legacy `serial` API. During its tests,
a strict simulated `serial` class accepts only the fixture's sentinel name,
records commands and supplies queued replies. Every other port name is
rejected; no method forwards to a real serial API. The fixture models current
data and slot 99 separately. Tests disconnect and release original objects
before removing the fixture, then restore the rejecting serial guard. Current
uses its injected transport while OS port discovery and real serial APIs
remain guarded. The temporary legacy API/timing shadows are kept under
`tests/original-fixtures/cs2000/original-serial` and
`tests/original-fixtures/cs2000/original-pause`, and added only for the
specific comparison. This setup tests software behavior; it cannot establish
that an original command is accepted by any physical firmware.

### Expected matches and intentional differences

The ordinary successful fixtures supply the same two distinct spectra and
XYZ triplets to both versions. Distinct bins and readings expose ordering or
append mistakes that a constant spectrum could conceal. Where the input is
identical and no computation changes it, compare exact values and dimensions;
there is no reason to introduce an optical tolerance into simulated parsing.

| Comparison | Expected result and reason |
| --- | --- |
| Valid ordinary spectra and XYZ | Exact equality: 401 × N spectra, 3 × N XYZ, bin/reading order and signed finite values. Both retain the instrument's values without host color conversion, clipping or normalization. |
| Acquisition commands and slot 99 | Different by design. Original sends `STDS,99` and reads `STDR,99,...`, replacing stored slot 99. Current disables the measurement button with `MSWE,0` and reads the current result with `MEDR`; it sends no `STDS`. |
| Connection settings and handshake | Original uses `RMT,1`/`OK`, writes normal speed and observer 0, and assumes backlight settings. Current uses verified `RMTS,1`/`OK00`, validates identity, preserves speed/display observer and restores the readback backlight pair. Successful simulation of the old handshake does not validate it on current firmware. |
| Acquisition conditions | The first five fields should agree for a common valid reply. Original omits external ND from its assignments and shifts angle/channel. For `0,1,002000000,1,0,1,2,07`, current retains external ND 1, angle code 2 and calibration channel 7; original assigns angle 1 and channel 2. Current's correction follows the eight-field protocol. |
| Announced duration `002` | Original requests `pause(0.002)`; current interprets two seconds and waits for framed completion. A recording pause fixture observes the original argument without a timing-sensitive wall-clock assertion. |
| Spectrum failure after XYZ was read | Original can append XYZ before spectrum failure and leave histories misaligned. Current retains only the previous complete reading, with spectrum, XYZ and metadata committed together. A fully framed recoverable error keeps a synchronized current session usable. |
| Numeric expression `1+2` in a payload | Original `str2num` evaluates the expression; current's finite decimal parser rejects it without committing a reading. The fixture is a harmless expression, not arbitrary executable input. |
| Saved history | Original saves separate spectral/XYZ arrays. Current saves one native `measurements` snapshot with aligned per-reading metadata. Compare numerical arrays rather than expecting identical MAT-file layouts. |
| Manual acquisition | Original changes exposure mode, then reads slot 99 without first storing the new result there and does not append matching XYZ. A distinct pre-existing simulated slot value exposes stale data. Current reads the newly completed result, retains aligned history and restores the previous speed configuration. |
| Strobe acquisition | Original's flash-trigger calls are disabled, so its path performs ordinary acquisition without a verified flash trigger. Current provides ordinary `Measure()` only; there is no synchronized strobe workflow. The comparison preserves ordinary acquisition parity without an unsupported current strobe class. |

The original command-style `Save` does not safely quote paths containing
spaces. Use a simple filename in its current folder for original-driver
comparisons; current accepts full paths containing spaces.

The [protocol and scientific reference](protocol-and-data.md) cites the
manufacturer's command definitions and explains these changes. In particular,
Rev.7 pp.43–45 define current-result reading and conditions; its pp.85–86
acquisition flows and Japanese text establish button-disabled result
retention. Neither implementation recomputes XYZ from the spectrum. Equality
of raw arrays therefore tests parsing and retention, not instrument colorimetry
or optical calibration. New metadata has no original per-reading equivalent.

Inspect named outcomes in `test-results.csv` and raw diagnostics in
`matlab.log`; retain the report for the exact tested revision. A baseline hash
failure invalidates the original comparison. Do not update hashes or alter
the preserved original to make a current regression pass. When changing expected
behavior, update the fixture, observable assertions and this explanation
together. The [testing maintenance checklist](../../testing/cs2000.md#maintaining-the-tests)
also covers stale fixtures, examples and Analyzer output.

### Legacy serial interface

The original school driver opens its port through MathWorks' retired `serial`
class. The comparison substitutes a strict fake class of the same name that
accepts one sentinel port only and never opens hardware, so the school code
runs in software. A passing comparison therefore shows behavioural
correspondence with the pinned school code; it does not show that the school
code runs on a current MATLAB release, nor firmware behaviour, nor optical
equivalence. The Analyzer reports its SERIAL message on the three fixture
calls in `testCS2000OriginalComparison`; those three lines carry a local
suppression with the reason, and nothing is suppressed globally. The
comparison stays as long as the school snapshot uses the legacy interface.

<!-- BEGIN TEMPORARY-BETA-TESTING -->

## Physical-device comparison

The [CS-2000 beta checklist](../../beta-testing/CS2000.md#original-driver-comparison)
contains the original–current–original measurement procedure. It requires matching
settings and an explicit decision to allow the original driver's slot 99 and
connection-setting changes.

<!-- END TEMPORARY-BETA-TESTING -->

# Comparing the original and current CR drivers

## Select the implementation explicitly

The original CR drivers belong to `Devices/Colorimetry_Research` in the separate
MCSL-Tools repository. The retained comparison baseline is upstream revision
`ce4e63f19ad54617478ff84791483deec920532d`. This repository supplies the
`colormeasure.drivers.cr` implementation.

For software comparison, add only this repository's `src` and supply the school
checkout to the isolated runner:

```matlab
addpath(fullfile(pwd, 'src')); % Current Folder: the project folder containing src
schoolRoot = '/path/to/MCSL-Tools';
report = colormeasure.runTests(tempname, 'SchoolRoot', schoolRoot);
```

The runner selects the original sources explicitly and rejects an incomplete or
changed baseline. Without `SchoolRoot`, bundled tests still run and the report
identifies original comparisons as not run. Tests use simulated transports;
these commands do not connect to a meter.

In a separately prepared direct-driver experiment, fully qualified names select
this implementation:

```matlab
% Original driver, when its separate school folder is on the path:
% meter = CR250(portName);
% This repository's driver:
% meter = colormeasure.drivers.cr.CR250(portName);
```

Both constructors connect immediately. Never hold two connections to the same
instrument. `colormeasure.drivers.cr.measureToFile(model, portName, fileName)` acquires,
saves, disconnects and returns a struct; the original `CR_example.m` is a script
and is not interchangeable with that function. Model arguments are `CR100`,
`CR250` and `CR300`.

## What the automated comparison actually executes

[testCROriginalComparison.m](../../../tests/drivers/cr/repository/testCROriginalComparison.m) instantiates
and calls the preserved `CR100`, `CR250` and `CR300` classes, including their
`Measure` methods. It also calls the qualified current classes. The originals are
not copied into a rewritten reference implementation. Current calls the qualified
`colormeasure.colorimetry` functions under `src`; its runtime does not use the
school conversion functions. The original comparison temporarily adds those
functions to execute the actual preserved baseline, then restores the path.

A test-only `serialport` function supplies a registered in-memory peer for the
original constructors. It rejects every other call, including an ordinary
physical-looking port name, and never falls through to the real API. Its
`NumBytesAvailable` getter raises a fixture error after 40 polls in one command,
so the original unbounded byte-count loops cannot hang the checks. This bound
is a test harness feature, **not a fix or real timeout in the original code**.
The stub is active only during each comparison test, with path and warning
state restored afterward. Current receives its peer through `Transport` injection.

[original-source.json](../../../tests/drivers/cr/fixtures/original-source.json) pins SHA-256
hashes for the four original files and their actual shared calculation chain:
`spec2XYZ`, `getObserverFunction`, `ObsFunctions.mat`, `XYZ2CCT`, its private
`XYZ2uvY1960`, and `PlanckLocus.mat`. Verification works in a downloaded ZIP
without Git. The four originals and both MAT tables must match their raw
bytes exactly. Shared MATLAB calculation files use an executable-line
fingerprint: decode UTF-8, split CR/LF/CR+LF, omit empty/whitespace-only lines
and full-line comments (first non-whitespace character `%`), then join the
remaining lines with LF and no final LF. Every retained character, including
inline comments and spaces, is preserved. This permits full-line documentation
changes without allowing a calculation change. Raw SHA-256 values remain as
provenance for those shared files too; this rule is deliberately narrower than
a general MATLAB source parser.

This deliberately couples the original-comparison test to a known scientific
baseline. Selected numerical reference cases do not establish equivalence of
every converter input. A fingerprint failure after a converter edit means the
comparison baseline needs review; it is not a current runtime version restriction.

A changed conversion or reference table requires scientific review of the
comparison baseline and its expected differences. Regenerating the manifest
alone does not establish numerical agreement.

The spectral numerical comparison uses identical signed samples and grids:
380–780 nm at 2 nm for the CR-250 fixture and 1 nm for the CR-300 fixture.
These are **synthetic test grids, not verified captures or firmware claims**.
The original spectral parser cannot consume the canonical multi-line CR/LF
fixture on the validated MATLAB release: it uses every CR position as one
colon bound. A separate test demonstrates this failure while current succeeds.

To reach the original calculation and storage code, the numerical comparison
therefore supplies one header CR/LF, LF-separated samples and an extra final
LF to accommodate its unconditional `end-2` slice. Current receives the same numbers
in canonical CR/LF framing. This special legacy-parser layout is not a verified
instrument response. Passing it establishes calculation/storage agreement only;
it does not establish that original acquisition works on actual equipment.
No original production code is patched to make the comparison pass.

## Expected matches and intentional differences

| Case exercised with original code | Original outcome | Current outcome and reason |
| --- | --- | --- |
| CR-100 finite, ordinary XYZ | Retains `RM XYZ`, computes CCT/Duv | Same XYZ; CCT/Duv agree within rounding. Original XYZ is retained without normalization. |
| CR-250/CR-300 numerical spectral fixtures | Retains signed samples and grid; integrates XYZ and total; computes CCT/Duv | Same type-0 samples and integration/CCT conventions through `colormeasure.colorimetry`, within floating-point tolerances. The official CIE CSV differs from the inherited MAT representation by at most 1.11×10⁻¹⁶ in a table entry. A negative bin alone is not invalid integrated XYZ. Uses the legacy-parser layout described above. |
| Canonical multi-line CR/LF spectra | Parsing fails on the validated MATLAB release | Header and every sample are framed and parsed independently. This is an expected acquisition difference, not an accepted numeric mismatch. |
| Short valid XYZ reply (`1,1,1`) | Waits for 43 bytes; bounded fixture stops it | Completes using the terminated reply rather than its character count. |
| Repeated instrument error | Defaults to three exposures and appends a NaN reading | Defaults to one exposure, raises an error and appends nothing. Each retry can measure a different sample; opt-in current retries have their own tests. |
| Two-value XYZ payload | Appends a two-column XYZ row before CCT fails | Rejects the payload before any history update; connection stays usable. |
| Black XYZ | CCT `0`, Duv `Inf` | Both unavailable (`NaN`); XYZ remains unchanged. |
| Extreme source outside table | CCT clamps to 25000 K in the fixture | CCT/Duv are an unavailable pair. Current also rejects CCT outside its 1000–25000 K open interval or absolute Duv above 0.05; see the scientific reference. |
| Radiometric types 1–3 | Stores samples under `radiance` without querying quantity | Keeps identical samples in `spectralData` and integral in `integratedSpectrum`; records quantity/units. No quantity is relabeled as radiance. |
| Saving | Arrays saved; changes the global struct-warning state | Same common numeric fields, additional identity/metadata, and unchanged warning state. Saved structs are intentionally not identical schemas. |
| Empty erase | Indexing error | Safe no-op. |
| Direct spectral calculation with a nearly uniform grid | Original converter assumes the first interval without a uniform-grid check | Current enforces the library's uniform-grid check and raises `CR:InvalidSpectrum`; no grid adjustment or resampling. See the [concrete example](color-science.md#grid-validation). |

Numerical fixtures compare XYZ with absolute tolerance `1e-10`, CCT `1e-6 K`,
Duv `1e-10` and the integrated spectrum `1e-12`. These account for floating-point
rounding of equivalent calculations (including the bundled observer table
representation and scale-invariant CCT evaluation).
They are not laboratory acceptance limits or claims of measurement accuracy.
The independent CIE/Planck reference tests still run; agreeing with the old
implementation alone does not prove scientific correctness.

Current separately retains `instrumentXYZ` for spectrometers. Compare the original
`XYZ` with **current `XYZ`**, which is MATLAB-derived in both; do not substitute
`instrumentXYZ`, whose observer/calibration conventions can differ. Compare
original `radiance` with current `spectralData`; interpret the original name only
after checking the actual accessory and quantity. The [science reference](color-science.md)
documents observer, integration, units and CCT validity; the
[metadata guide](metadata.md) distinguishes instrument values and host values.
Additional identity, settings, timestamps and response provenance are expected
current additions, not values that can match an absent original field. New method
labels explicitly identify the `colormeasure.colorimetry` producer; they are compared as
provenance, not as numeric measurement differences. Existing saved readings
keep their original values and labels. The unchanged school originals and
`Convert` files are not migrated to the new library.

<!-- BEGIN TEMPORARY-BETA-TESTING -->

The physical original–current–original procedure is in the
[CR beta checklist](../../beta-testing/CR.md#original-and-current-physical-comparison).

<!-- END TEMPORARY-BETA-TESTING -->

## Maintaining the comparison

Keep this guide, the expectation table, fixtures and test names synchronized
with driver changes. Remove obsolete expectations only when their replacement
behavior is explicit. A new transport or schema change must say whether a
previous match remains required, becomes an intentional difference or cannot
be assessed. Preserve canonical-framing and negative cases even if an old
numerical fixture still passes. Report current named results from the full
runner rather than copying historical test counts.

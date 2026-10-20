# CR beta testing

> **Device-test checklist**
> Scope: [what the device test checks](README.md#what-the-device-test-checks).

This device-validation checklist covers CR-100, CR-250 and CR-300.
Use the [beta testing guide](README.md) for the download, software test
command and a window walkthrough without an instrument. The
[CR software-test reference](../testing/cr.md) describes the
automated checks and reports. Record physical results separately for each model,
firmware and accessory; a software pass does not establish device performance.

## Window checks without an instrument

With MATLAB Current Folder set to the project root, add `src`:

```matlab
addpath(fullfile(pwd, 'src'));
```


```matlab
demo = colormeasure.drivers.cr.demoCR250;             % explicit Measure; synthetic readings only
batch = colormeasure.drivers.cr.demoCR250('batch');   % two readings, MAT/CSV, no window
gallery = colormeasure.drivers.cr.demoCR250('gallery'); % twelve profiles in a restorable window
```

Use `colormeasure.drivers.cr.demoCR100` or `colormeasure.drivers.cr.demoCR300` equivalently. Every record is marked
`isSynthetic=true` with its profile name/index, synthetic units and method.
No demo enumerates or opens physical ports. Profiles are generated shapes,
not calibrated sources, illuminant standards or measured references.
Interactive mode waits for Measure. Batch mode writes under temporary storage
and returns successfully only after both readings and final MAT/CSV saving
succeed. A failed acquisition or final save raises `CR:DemoMeasurement` or
`CR:DemoPersistence` and retains the incomplete session under its named batch
workspace handle (for example, `colorMeasureCR250DemoBatch`) for inspection and recovery.
Gallery mode writes there too, populates once, and then allows explicit further
readings; relaunching restores without adding another twelve readings.

Real, interactive-demo, batch-demo and gallery identities are distinct for
each model. Bare demo commands assign, for example, `colorMeasureCR250DemoSession`,
`colorMeasureCR250DemoBatch` or `colorMeasureCR250DemoGallery`. CR-250 previews use a declared synthetic
380:2:780 nm grid; CR-300 previews use 380:1:780 nm. These are demo choices,
not claims about a connected firmware revision. CR-100 synthetic XYZ is generated
from an internal illustrative spectrum, but its records and display contain
no spectrum, matching the real colorimeter's data capability. Synthetic records
have empty instrument metadata/native snapshot, NaN instrument XYZ, and no
invented serial number, firmware or raw instrument reply.

Advanced settings use explicitly synthetic capabilities and persistent virtual
setup. **Read settings** does not consume a profile. Settings receipts are marked
synthetic; changing exposure, accessory or correction controls does not model
their optical effect on the generated profiles. No device reply or identity is
invented. The demos exercise controls, validation and saving, not instrument
precision, timing or calibration.

Run the [shared color-view checks](UI.md#window-checks-without-hardware)
with the corresponding model's gallery. Check adaptation, spectral capability
limits, separate analysis export and unchanged source measurements.

## Physical validation checklist


These steps are a checklist for a lab session, **not part of `colormeasure.runTests`**.
Use the [measurement guide](../drivers/cr/README.md), [API reference](../drivers/cr/api-and-protocol.md)
and [scientific reference](../drivers/cr/color-science.md) for the current contract.
Never test against an instrument used by another measurement session.

1. **Prepare and record context.** Run the software command first. Retain its
   revision and platform report with the lab notes. Record the model being
   tested and the connection type. Check the automatically captured identity
   and settings in the saved measurement metadata. Record firmware as reported
   by the instrument, and distinguish installed firmware from a manufacturer's
   available update. Do not update firmware as part of these tests.
   Follow the [model-specific preparation guide](../drivers/cr/preparation.md): confirm
   geometry, installed accessory/filter selection, stable source and intended
   low-light exposure/speed. Follow the CR model's own warm-up and zero
   instructions.
   Confirm the help identifies the chosen model, Cancel sends no measurement,
   and Ready continues one requested measurement. Reopening help must not
   acquire or change settings; no demo should demand physical preparation.
2. **Connect without acquiring.** With one idle authorized instrument connected,
   construct the matching class (`colormeasure.drivers.cr.CR100`, `colormeasure.drivers.cr.CR250` or `colormeasure.drivers.cr.CR300`). Construction
   selects an available candidate and verifies its identity; it does not call
   `Measure`. Inspect `identity`, including `identity.firmware` (the `RC Firmware`
   reply), before calling `Disconnect`.

   **CR-100 firmware:** the automatic recipe requires firmware **1.16 or newer**
   and a usable, unambiguous Colorimeter-mode capability/readback. If the version
   is older or cannot be interpreted, use native command-line `Measure` or
   `colormeasure.drivers.cr.measureToFile("CR100", ...)` with the instrument correctly configured;
   these preserve current acquisition settings. Record automatic-recipe and
   measurement-window checks as **not testable on this unit**, while continuing
   the applicable direct-command checks. Version 1.16 or newer alone does not
   establish support: a failed recipe still prevents the window from acquiring.
   See [mode requirements and manual references](../drivers/cr/settings.md#what-each-setting-means).
   Do not update firmware or bypass the recipe as part of this checklist.

   Repeat connection with its explicit port. Check the actual platform's port names and, on macOS, paired `tty`/`cu`
   aliases. Confirm the port is released after disconnect. Zero/multiple-port,
   wrong-model and unavailable-port cases remain simulated unless the operator
   can arrange them safely without contacting unrelated equipment.
3. **Acquire a stable target.** Acquire and save one reading through `colormeasure.drivers.cr.measureToFile`.
   Load the MAT file in a fresh workspace without reconnecting. Compare the
   instrument display or vendor application, used in a separate connection, to
   instrument XYZ and available original output values. Confirm that metadata
   preserves exact device-reported model, firmware and serial-number readback
   when provided; do not manually fill a missing reply. Compare last-capture
   aperture, accessory/filter, exposure and exposure mode, range, sync and
   calibration settings against supported device readbacks. Distinguish those
   settings from current settings changed after the capture. Confirm that
   unsupported, unavailable or unparsed metadata remains explicit and does not
   become an invented value. Check that a fully framed optional payload the
   driver cannot interpret retains the completed reading and exact raw reply;
   never induce malformed traffic on a physical connection for this check. A host timestamp is not a device exposure timestamp or
   device temperature; only report a temperature when a documented device
   command actually supplies one.
   Where the firmware and capabilities support the automatic recipe, read
   current setup before the separately authorized settings check. On CR100,
   verify the Colorimeter-mode
   acknowledgement and readback and both Fixed-range-D/Auto transitions.
   On each model, start from a known manual exposure, call the documented
   automatic recipe, inspect its receipt, then acquire only after success.
   Confirm inherited accessory/filter/correction, speed, synchronization and
   multiplier remain unchanged. Verify explicit overrides and reported bounds;
   compare capture metadata to actual settings used. Test CR300 multiplier
   meaning separately. Do not induce malformed replies or setter timeouts on
   hardware; those failure cases belong to the simulated suite. Record platform
   and firmware differences without replacing missing readback with an assumption.
4. **Inspect spectra and scientific meaning.** For CR-250/CR-300, verify returned
   wavelength endpoints, step and sample count agree with the header and that
   saving/reloading preserves the complete signed spectrum. Check the declared
   quantity and units against the installed accessory. Host spectral-density
   and XYZ unit labels remain provisional until their per-nm assumption is
   confirmed; record that limitation in comparisons. Compare instrument XYZ
   separately from MATLAB-derived XYZ; they use potentially different settings
   and calculation conventions. A black or out-of-range chromaticity may make
   CCT/Duv unavailable while leaving the original data valid. CR-100 has no
   spectral history. Do not resample or clip data to make comparisons agree.
   For authorized object-color work on CR-250/CR-300, keep a matched white
   reference/object pair and the reference's spectral factor data. Verify the
   original spectra remain unchanged by Reflectance / relight and its output
   is identified as derived. Check matched geometry/illumination and validate
   against a suitable reference procedure. An ideal-white assumption must stay
   labeled as a relative ratio; CR-100 must not offer spectral relighting.
5. **Repeat, erase, save.** Acquire two intentional readings and confirm every
   history has two aligned rows. `Erase` removes exactly the last row;
   `EraseAll` leaves empty histories; saving empty history and disconnected
   history should reload. Test a deliberately unwritable destination and retry
   saving to a writable location without acquiring a replacement reading.
6. **Exercise recoverable errors under operator control.** Where the instrument
   and target permit an ordinary documented measurement error, confirm that
   prior readings remain unchanged and an idle, synchronized connection can
   acquire again. Keep automatic retries disabled for this check. If enabling
   `repeatOnError`, remember that each retry is a new exposure of a potentially
   changed target. Verify its documented limit and per-call counter reset in
   simulations first; do not induce a physical error by moving or disconnecting
   equipment during an acquisition.
7. **Validate timeout recovery only when safe.** Observe a naturally slow
   acquisition or arrange a bounded timeout with the operator. Record elapsed
   times and whether late bytes remain on that OS/driver. Before reconnecting,
   independently confirm that the instrument is idle and the prior acquisition
   has ended. Use the documented opt-in drain only to abandon that old reply;
   it cannot cancel an exposure. Confirm that normal reconnect rejects pending
   input, deliberate draining is bounded, fresh identification succeeds, and
   no extra measurement occurs automatically. Do not unplug an active device.
8. **Compare original and current.** Follow the [A/B protocol](#original-and-current-physical-comparison)
   using original–current–original runs, a stable target and identical instrument
   settings. Retain repeats and exact software names. Do not confuse numerical
   fixture tolerance with instrument repeatability. If the original blocks or
   fails to parse, record that failure and mark physical numerical agreement
   untested instead of modifying the original or making values agree.
9. **Accessory/grid changes.** Only while idle, use the manufacturer's controls
   to change a supported setting or accessory if this is relevant to the lab.
   Check that subsequent metadata describes the new configuration. A changed
   spectral sample count within existing history must fail without appending a
   partial row; save and clear the old history before the next intentional reading.
   Equal-length changed grids are retained per row; verify each row's wavelengths.
   Do not assume all three models or accessories have the same spectral grid.

Record each step as passed, failed or not tested, with the saved artifact or
observed error and the instrument model/installed firmware. File an issue with
a minimal reproduction and sanitized device replies when an expectation fails.
Software success must never be relabeled as physical validation.

## Direct and window comparison

Compare the direct and window workflows on a stable source with the same
instrument settings. Apply the same automatic recipe and overrides explicitly
in the direct workflow before comparing it with the window. Check retained
identity and settings, distinct instrument/host XYZ, complete raw replies, plot
units, one exposure per click, MAT reload and CSV export. Confirm CR-100 has no
spectrum and verify the accessory-dependent quantity for CR-250/300. Check that
errors release the window's connection without automatic retries or hidden
input draining.

## Original and current physical comparison


This requires an authorized operator and idle equipment. It is not run by the
software test command. Do not induce failures, change firmware, disconnect an
active exposure or run both clients concurrently.

1. Run `colormeasure.runTests`, retain the report and record the software revision,
   MATLAB/OS, model, accessory and settings used. Check the device-reported
   identity retained in the current result. Keep device-reported firmware distinct
   from an available update.
2. Select an explicit port for **both** versions. Stabilize the same target,
   instrument position, warm-up, aperture, exposure/range, sync, calibration and
   other supported settings. Neither driver should silently be assigned another
   target or port. Close vendor software or another measurement connection first.
3. Run an **original → current → original** sequence, with repeated readings within
   each block. Disable `repeatOnError` in both versions so a hidden replacement
   exposure cannot bias the comparison. Pick and record the repeat count for
   the experiment rather than using a universal pass threshold. Do not include
   a failed/NaN original row as if it were a successful replicate.
4. Save each block to a distinct file. The original has no `Disconnect` method:
   after it has finished, explicitly release its `meter.port` and then the
   object; current uses `meter.Disconnect()`. Verify release before starting the next
   block. For example, after an original block has completed:
   `oldPort = meter.port; delete(oldPort); delete(meter); clear oldPort meter`.
   Never apply this cleanup while an exposure is still active.
5. The original can wait forever or fail on framing. Run original acquisition
   in its own non-desktop MATLAB process under operator supervision and set an
   external time limit appropriate to configured integration. If it stalls,
   stop that test, independently confirm device idle, then recover the connection
   according to the vendor instructions. Record the response/error and mark
   numerical agreement **not tested**. Do not edit originals or shorten replies
   from a real instrument to force a match.
6. Compare per-reading wavelength grids and signed samples before XYZ. If grids
   differ, retain each native grid and investigate settings/firmware; do not
   silently resample, clip or normalize either measurement. Compare like
   quantities and units, with the [field mapping](../drivers/cr/original-comparison.md#expected-matches-and-intentional-differences). Check saved/reloaded
   arrays, CCT validity and metadata separately.
7. Plot or tabulate within-version repeat variation, the original-before vs
   original-after drift, and the current vs original difference. Set any physical
   acceptance criterion from the instrument specification, lab requirements
   and observed repeatability. No software floating-point tolerance applies to
   independent real exposures. A drift or setting mismatch prevents attributing
   a difference to the driver alone.
8. Record each expected match as passed, failed or not tested, with the files
   and rationale. For intentional differences, cite the comparison table row and check
   the new meaning rather than declaring blanket parity. Repeat for each
   available model/accessory; one instrument's result does not validate another.


## Serial write deadline qualification

Use R2026b or newer for native connections. Software tests simulate blocked
and partial writes and verify that earlier readings survive without automatic
retries. They do not establish operating-system or physical-link behavior.
During an authorized bench session, record normal writes on the actual USB or
RS-232C path and confirm the configured write deadline. Only use an approved
isolated loopback or flow-control fixture to test blocked writes; do not cause
a partial command or unplug the instrument during acquisition. A failed write
requires checking that the instrument is idle before reconnecting, including
its remote/backlight state where applicable.

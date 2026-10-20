# PR instrument settings

PR-655 is the primary supported instrument. PR-670 settings are tentative and
require physical validation on that model. These functions use the connected
instrument's model and returned calibration IDs; the catalog itself performs
no serial I/O.

## Normal operation and overrides

Native `pr.measure()` and a core session constructed with `colormeasure.drivers.pr.adapter()`
preserve existing acquisition settings. A custom script can explicitly call
`pr.applyAutomaticSettings(overrides)` before measuring to select this recipe:

| Setting | Normal choice | Command |
| --- | --- | --- |
| Exposure | Adaptive | `SE0` |
| Cycles to average | One | `SN1` |
| Synchronization | Automatic | `SS1` |

Explicit overrides replace these choices. Readback-confirmed unchanged values
are not written again. Accessory, aperture, sensitivity, Smart Dark, units,
instrument observer, and measure-shutter selections are preserved unless
explicitly overridden.

The measurement window applies this recipe before each reading. Opening the
settings catalog sends no commands.

## Exposure in the measurement window

Choose **Adaptive** to let the instrument select exposure, or **Fixed** to enter
an explicit duration in milliseconds. Adaptive retains the protocol value `0`;
the window does not ask you to enter that special value. An unread exposure
starts at **Choose a mode** until you choose Adaptive or Fixed or read settings.
Selecting Fixed starts with an empty duration, not a guessed minimum.

Fixed exposure uses whole milliseconds: 3–6000 for PR-655 and 6–6000 for
PR-670 Standard sensitivity. A PR-670 exposure up to 30000 ms requires Extended
sensitivity, either read from the instrument or staged in the same draft.
Changing the mode or duration edits only the draft. **Use for next readings**
retains it; **Cancel** leaves the earlier override unchanged. The driver still
checks actual capabilities and coupled settings before sending commands.

## Native commands

```matlab
pr = colormeasure.drivers.pr.PR655('COM3');        % Use the actual instrument port
settings = pr.readSettings();  % Current setup and calibrated choices; no exposure
settings.values
settings.controls

receipt = pr.applySettings(struct('exposureMilliseconds', 0, 'cycles', 3));
if strcmp(receipt.status, 'failed')
    delete(pr);
    error('%s', receipt.error.message);
end
measurement = pr.measure();
delete(pr);
```

`applySettings(struct())` performs no serial I/O. To deliberately apply the
automatic recipe, call `pr.applyAutomaticSettings(struct())` and check its receipt
before measuring. Optional capture metadata and these explicit setting reads
are separate operations.

### Read report

`readSettings()` returns `values`, `controls`, `identity`, `readAtUTC`, and
`responses`. Unknown numeric values remain `NaN`; unknown choices remain empty.
Each response retains its command, raw reply, parsed fields and status. A failed
or unsupported report is not replaced with a default setting.
Numeric setup fields, list counts, calibration IDs and aperture bandwidths must
be finite real numbers. A malformed numeric report is retained with
`PR655:InvalidResponse`; the affected values or choices remain unavailable and
acquisition requires reconnection. Descriptive D602 frequency text is normalized
only when it contains a finite Hertz value; otherwise it remains `NaN`.

The explicit inspection uses `D601`/`D602` for current setup and `D110`/`D114`
for identity. `D112` supplies list lengths for `D116` accessories and, for
PR-670, `D117` apertures. Choices use returned IDs and names, not their positions
in a menu. The reader expects those counts of complete rows and treats malformed
or incomplete lists as unavailable; actual firmware framing still needs testing.

Applying basic overrides reads current setup before and after the change.
Dynamic accessory/aperture changes additionally discover calibrated choices.
Reports describe current settings; they do not prove fitted optics or provide
an atomic record of the conditions during an earlier exposure.

### Application receipt

Both application methods return `requested`, `before`, `after`, `commands`,
`acknowledgements`, `status`, and `error`.

- `unchanged`: an empty explicit request, or requested values already confirmed
  by readback.
- `applied`: the setting commands were acknowledged and any available readback
  did not contradict them. Acknowledgement is not independent verification.
- `failed`: validation, protocol, application, or readback failed. Earlier
  commands may already have changed the instrument; there is no automatic undo.

Invalid argument shapes or values can throw before any I/O. Coupled settings
and calibrated IDs are checked before the first setter. A failed application
must prevent the next exposure. After a failure involving setting writes, this
driver requires reconnection; retain the receipt and inspect the configuration
before continuing. Reconnection does not undo persistent instrument settings.

Duplicate add-on IDs across the resulting slots are rejected before any setter,
including duplicates against an inherited occupied slot (manual error -1007).

## Available controls

The routine catalog supplies per-control help under `meaning`, `whenToUse`,
`tradeoff`, `normal`, and `source`.

| ID | Values and use | Tradeoff and return to normal |
| --- | --- | --- |
| `exposureMilliseconds` | `0` selects adaptive exposure. Fixed integer milliseconds: PR-655 3–6000; PR-670 6–6000, or up to 30000 in Extended sensitivity. | Longer integration takes longer. Apply the automatic recipe without this override to restore adaptive exposure. |
| `cycles` | Integer 1–99; the instrument averages spectra before calculating derived results. | More cycles increase time. Apply the automatic recipe without this override to restore one cycle. |
| `syncMode` | `none`, `auto`, or `user`; synchronization adjusts adaptive exposure for periodic sources. | Auto detection takes time and may fail on weak or nonperiodic signals. Apply the automatic recipe without this override to restore automatic sync. |
| `syncFrequencyHz` | Integer 20–400, with `syncMode='user'`; no silent rounding. | The value must describe the source. Restore automatic sync to stop using the stored user frequency. |
| `primaryAccessoryId` | An ID reported as Primary by `D116`. | Must match the physical optics. The normal recipe preserves it; restoration requires selecting the fitted previous accessory. |
| `addon1Id`, `addon2Id`, `addon3Id` | IDs reported as Addon by `D116`. | No guessed None/clear code is sent. Clear an instrument slot through its setup menu until a clearing command is established. |
| `apertureId` | PR-670 only; an ID from `D117`. | Smaller apertures collect less light. The normal recipe preserves aperture; PR-655 has no software aperture selector. |
| `sensitivityMode` | PR-670 `standard` or `extended`. | Extended raises the exposure ceiling to 30 seconds. The normal recipe preserves it; select Standard explicitly to restore the shorter ceiling. |
| `smartDark` | PR-670 `0` for standard dark acquisition, `1` for Smart Dark reuse. | Smart Dark reuses dark data when exposure times match. The normal recipe preserves it; select `0` to disable reuse. |

A fixed exposure above 6000 ms requires known or explicitly requested Extended
sensitivity. Returning to Standard requires a known compatible exposure or an
explicit adaptive/shorter exposure in the same request. Lowering exposure is
ordered before lowering its ceiling; raising the ceiling comes first for a
longer exposure.

Catalog numeric bounds describe model capability: PR-670 allows staging up to
30000 ms even while its current range is Standard. A longer exposure and
`sensitivityMode='extended'` can therefore be requested together; native
validation still rejects a target exposure above 6000 ms in Standard mode.

The driver timeout remains the explicitly configured `Timeout` (300 seconds
by default). Long exposure/averaging combinations can exceed it. Expert code
can choose a larger timeout when connecting; settings help does not promise a
measurement completion time.

## Synchronization errors

Synchronization aligns adaptive exposure with periodic changes in the source.
A stationary image or visually steady lamp can still be modulated. The manual
lists these measurement errors (Rev B, printed p.122):

| Code | Meaning |
| --- | --- |
| `-3` | Cannot synchronize: frequency below 20 Hz, above 400 Hz, or signal too low. |
| `-9` | Synchronization error; the code does not identify the cause. |
| `-10` | Cannot automatically synchronize to the source. |

Retain the code, source/setup description and settings receipt. A failed reading
adds no spectrum, and the driver neither changes synchronization nor retries.
Check the source's modulation and signal level before choosing another mode.
For a known periodic source, a supported, known user frequency may be appropriate.
For a known nonmodulated source, or a deliberately labelled diagnostic repeat,
`syncMode='none'` is available. Disabling synchronization is not a general cure:
it can reduce repeatability on periodic sources, particularly at short exposures
(manual pp.35–36).

In a custom script, explicitly request the automatic recipe with that override:

```matlab
receipt = pr.applyAutomaticSettings(struct('syncMode', 'none'));
if strcmp(receipt.status, 'failed')
    error('%s', receipt.error.message);
end
% Confirm the target and changed conditions before running the next line.
measurement = pr.measure();
```

This selects adaptive exposure and one cycle as well as None. Preserve any other
intended overrides in the request. Record the changed setup with the repeat;
do not combine it with the earlier condition as an unchanged repeatability test.
Applying the automatic recipe without the override returns to Automatic.

In the measurement window, the equivalent override is under **Settings...** →
**Synchronization**: enable **Override this setting**, choose **None**, then
**Use for next readings**. Confirm the target before selecting **Measure**.
To return to Automatic, uncheck **Override this setting** for **Synchronization**,
then select **Use for next readings**. The window does not change modes or retry
in response to an acquisition error.

## Expert-only settings and protocol limits

`colormeasure.drivers.pr.settingsCatalog(model, capabilities, true)` also describes native-only
`photometricUnits` (`english`/`metric`), `instrumentObserver` (`2`/`10`), and
`shutterMode` (`closeAfter`/`alwaysOpen`). They are excluded from the initial
routine UI catalog and are not normalized by the automatic recipe.

- `SU1` selects metric photometric reporting. Its argument is not the returned
  M5 units code, and it does not establish spectral quantity or radiometric
  scale. The raw M5 unit code remains preserved.
- `SO2`/`SO10` affect native instrument reports. They do not change the workflow
  XYZ calculated from M5 with the CIE 1931 2-degree functions.
- `SZ0` requests shutter closure and dark acquisition; `SZ1` skips closure and
  dark acquisition. The manual recommends `SZ0`. D601/D602's DarkMode describes
  Smart Dark, not SZ shutter control, so shutter readback remains unknown.
- `SG` speed/gain is not exposed: the manual's prose and numeric labels conflict.
- Factory reset commands are not ordinary reset controls: the manual says they
  shut down the instrument. This API does not send them.
- `D601` reports zero exposure for adaptive mode. `D13`, available through
  optional capture metadata, reports the last exposure; these are different
  quantities.

## Demo behavior

`colormeasure.drivers.pr.DemoInstrument(1, 0, 'PR-655')` and
`colormeasure.drivers.pr.DemoInstrument(1, 0, 'PR-670')` support the same setting-validation,
read-report, and receipt interfaces. Reports and acknowledgements are labelled
synthetic. The demo records modes and changes the model's wavelength grid, but
does not model exposure-dependent noise, dark correction, calibration, or timing.
Its next spectrum advances only after a successful measurement; reading or
applying settings does not consume a sample.

See the [testing guide](../../testing/pr.md) for software checks and instrument procedures.

## Sources

- Photo Research, *PR-655/PR-670 User Manual*, Rev. B (2009-07-29): printed pp.35–36 for synchronization, pp.107–112 for setters, pp.118–121 for identity, calibration lists and setup reports, p.122 for errors, and p.106 for factory-reset shutdown. Settings inherit the prior configuration until changed (p.107).
- The manual labels synchronization `SS` but prints `SQf` in its syntax line.
  The implementation uses `SS0`/`SS1`/`SS3`, corroborated by
  [Psychtoolbox PR670setsyncfreq at the reviewed revision](https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/PsychHardware/PR670Toolbox/PR670setsyncfreq.m).

Implementation and help for these updates: Fernando Voltolini de Azambuja, 2026.

# CR acquisition settings

Use automatic exposure for ordinary light measurements. On CR100, first select
Colorimeter mode, then automatic exposure and electronic range. The automatic
recipe performs this sequence using the meter's reported IDs. Choose an explicit override when the experiment
requires it. These are driver policy choices, not a claim about factory defaults.
Accessory, filters and correction selections must match the actual optical
setup and remain unchanged unless explicitly overridden.

The native `Measure()` method retains its existing behavior: it acquires with
the instrument's current settings. Call `applyAutomaticSettings` first to use
the automatic recipe, or `applySettings` to change only named settings. Neither
settings method takes a measurement. See [preparation](preparation.md) before
operating equipment and the [API guide](api-and-protocol.md) for connection and
cleanup.

## Inspect, apply and measure

The static help catalog needs no connection:

```matlab
controls = colormeasure.drivers.cr.settingsControls("CR250");
disp(controls(strcmp({controls.id}, 'exposureMultiplier')).help);
```

Every static control starts with `available=false`, empty `choices`, and `NaN`
bounds. These mean that actual capabilities have not been read. They are not
device defaults, zero-valued settings or evidence that the model lacks a feature.
The `aperture` and CR100 `mode` controls are exceptions to later editing
availability: they remain read-only with `available=false`. Reported aperture
text is in `readSettings().values.aperture`, not an invented selectable option.
`applySettings` rejects these read-only IDs. Only the CR100 automatic recipe
internally selects the supported Colorimeter mode; temporal acquisition is not
enabled by this settings interface.

With an explicitly selected port, an idle instrument and an authorized
measurement setup, this example **changes exposure mode and then measures**:

```matlab
meter = colormeasure.drivers.cr.CR250(portName);
cleanup = onCleanup(@() meter.Disconnect());

capabilities = meter.readCapabilities(); % Supported options and limits
current = meter.readSettings();         % Current RS settings, not a capture

receipt = meter.applyAutomaticSettings(struct());
if strcmp(receipt.status, 'failed')
    error('CR:SettingsNotApplied', '%s', receipt.error.message);
end
meter.Measure();
measurements = meter.snapshot();
save('cr-reading-with-settings.mat', 'measurements', 'receipt');
clear cleanup % Closes the owned connection
```

Inspect each returned control's `available`, `choices`, `minimum` and `maximum`
before choosing an override. Each choice contains the actual `value` and `label`
reported for this instrument. Use those values rather than copying numeric IDs
from an example or assuming the same options across models or firmware.
Choice overrides accept numeric IDs, not labels. Numeric controls accept numeric
values in the stated units.

For example, to prepare a CR250 Slow-speed override from a successful current
report, without applying it yet:

```matlab
speed = current.controls(strcmp({current.controls.id}, 'speed'));
assert(isscalar(speed) && speed.available, 'Speed control is unavailable.');
selected = strcmp({speed.choices.label}, 'Slow');
assert(nnz(selected) == 1, 'The meter did not report one unambiguous Slow option.');
overrides = struct('speed', speed.choices(selected).value);
```

Passing `overrides` to either apply method on an idle, connected meter is the
explicit state-changing step; check the returned receipt before measuring.
The apply method revalidates current capabilities rather than trusting an
earlier report.

`applySettings(overrides)` changes only supported writable fields present in
`overrides`, without first selecting measurement mode or automatic exposure/range.
For example, an explicit change to
`exposureMultiplier` leaves exposure mode, synchronization, accessory and
correction selection inherited. Supply a multiplier within the reported limits
and use the model-specific meaning in the table below.

`applyAutomaticSettings(overrides)` starts from this recipe, then applies the
explicit overrides as one validated combination:

| Model | Automatic recipe | Other settings |
| --- | --- | --- |
| CR100 | Device-reported Colorimeter mode first, then Auto exposure mode and Auto range mode | Inherited unless explicitly overridden |
| CR250 | Device-reported Auto exposure mode | Inherited unless explicitly overridden |
| CR300 | Device-reported Auto exposure mode | Inherited unless explicitly overridden |

CR100 mode selection uses the Colorimeter ID returned by `RC Mode`, with
`SM Mode` documented since firmware 1.16. The setter's acknowledgement identifies
`SM Mode` exactly, and current mode is read back through `RS Mode`. Older firmware,
an unsupported mode query or an ambiguous/missing Colorimeter option causes
automatic application to fail before any setting write. The driver does not
assume that the existing mode is Colorimeter. Direct `Measure` retains its
existing current-settings behavior.

There is no automatic recipe for synchronization or speed, and the recipe does
not force the exposure multiplier to one. It does not call `SM Reset`, select
accessories or disable corrections. It leaves CR250/300 measurement mode unchanged.
`SM Reset` would also alter unrelated configuration; its CR100 reset table is
not a general recipe for all three models.

An optional measurement adapter can call `applyAutomaticSettings(overrides)`
before each reading. Clearing an override returns automatic-profile fields to
this recipe. It does not reset other persistent instrument settings. Direct
native acquisition remains under the caller's explicit control.

## What each setting means

**R** refers to the manufacturer's *Remote Communications Manual 1.36*;
**A** refers to *CRI App Manual 1.5.10*. Both are available through
[Colorimetry Research downloads](https://www.colorimetryresearch.com/downloads).
Page numbers below are the manuals' printed pages. Functional descriptions come
from these manuals; suggested uses and cautions about source stability are
practical guidance, not promises of a measured precision improvement.

| Setting ID and label | Models | Meaning and when to use | Tradeoff or dependency | Source |
| --- | --- | --- | --- | --- |
| `mode`: Measurement mode (read-only) | CR100 | Observe current mode. The ordinary automatic recipe selects the device-reported Colorimeter mode before exposure/range. | Not an `applySettings` override. Automatic application requires an unambiguous supported Colorimeter option and firmware ≥1.16. This interface does not acquire temporal data. | R §4.2.1.6, p.14; A §5.8, p.20 |
| `exposureMode`: Exposure mode | All | Auto chooses integration time; Fixed (the manual also calls it Manual) uses an explicit time. Prefer Auto ordinarily, Fixed for controlled exposure experiments. | CR100 Fixed exposure requires Fixed range D. That dependency is not applied to CR250/300. | R §§4.2.1.7–8, pp.14–15; A §§5.8/5.10, pp.20/23 |
| `exposureMs`: Exposure time (ms) | All | Integration time used in Fixed exposure mode. Set it when controlling integration is part of the experiment. | Must be within `RC MinExposure`/`MaxExposure`. Longer integration changes duration and temporal averaging; it is not the complete acquisition time. | R §4.2.1.8, p.15; §§4.3.2.20–21, p.46 |
| `rangeMode`: Electronic range mode | CR100 | Auto chooses the range; Fixed (the manual also calls it Manual) uses the selected range. Prefer Auto ordinarily. | Fixed exposure needs Fixed range D. An unsuitable range can cause over/under-range errors. | R §§4.2.1.10–11, p.16; A §5.8, p.20 |
| `range`: Electronic range | CR100 | A reported electronic range used with Fixed range mode. Useful for deliberate range comparisons. | Select the device's actual range ID. Do not infer sensitivity from numeric ID order. | R §4.2.1.11, p.16; §4.3.2.10, p.41 |
| `exposureMultiplier`: Exposure multiplier | CR100 | Makes exposure a multiple of its base value. Consider it when investigating variable low-light readings from a stable source. | Increases duration; not documented as a count of independently averaged readings. Bounds come from `RC MinExposureX`/`MaxExposureX`. | R §4.2.1.14, p.17; A §5.8, p.20 |
| `exposureMultiplier`: Averages | CR250 | Repeats and averages exposures. Useful for investigating random variation on a stable source. | More averages take longer and also average changes in the source. Preserve the current value unless overridden. | R §4.2.1.14, p.17; A §5.10, p.23 |
| `exposureMultiplier`: Exposure multiplier | CR300 | The generic protocol supplies a multiplier command and bounds. | The application manual's CR250 section describes averaging; it does not specify CR300 averaging semantics. The API uses a neutral label; confirm timing on the installed model. | R §4.2.1.14, p.17; A §5.10 is CR250-specific |
| `syncMode`: Synchronize with light source | All, when reported | Select synchronization to a detected or specified light modulation frequency. Relevant for periodically modulated sources. | Do not assume Auto is appropriate or detection will succeed. Fixed presets depend on capabilities/firmware; R documents their addition in 1.32. | R §§4.2.1.12–13, pp.16–17; §4.3.2.11, pp.42–43; A §5.8, p.20 |
| `syncFrequencyHz`: Synchronization frequency (Hz) | All, when reported | Established source frequency for Manual synchronization. | Requires Manual synchronization and a value within reported frequency limits. A display refresh label may not describe light modulation. | R §4.2.1.13, p.17; §§4.3.2.22–23, p.47 |
| `speed`: Measurement speed | CR250/300 | A reported spectroradiometer speed. A recommends Slow for low light on CR250. | No assumed Auto speed. Faster modes do not establish equal low-light precision. R restricts the command to spectroradiometers, firmware ≥1.17. | R §4.2.1.19, p.19; §4.3.2.26, p.48; A §5.10, p.23 |
| `accessory`: Attached accessory | All | Select the calibrated accessory physically fitted to the meter. Its type determines the measured quantity. | A change can alter units and applicable correction profiles. Software cannot establish which hardware is fitted. | R §4.2.1.1, p.12; §4.3.2.4, p.39; A pp.20/23 |
| `aperture`: Physical aperture (read-only) | All, when reported | `RS Aperture` reports the fitted aperture as text in `values.aperture`. Use it to check the measurement field against the intended geometry. | This API provides no setter. CR250/300 optical aperture is fixed when ordered. Physical aperture is separate from the CIE observer angle. | R §4.3.3.3, p.50; [CR250](https://www.colorimetryresearch.com/products/cr-250) and [CR300 specifications](https://www.colorimetryresearch.com/products/cr-300) |
| `filter1`, `filter2`, `filter3`: Attached ND filter | All, when reported | Select each calibrated filter physically installed. ND filters extend the measurable intensity range. | Software selection cannot install a filter. Do not infer a None ID: the manual's setter and reset examples conflict. | R §§4.2.1.2–4, pp.12–13; §4.2.1.23, p.21; [manufacturer ND guidance](https://www.colorimetryresearch.com/accessories/nd-filters) |
| `userCalibrationMode`: Existing correction mode | All, when reported | Enable a supported, existing correction prepared for the source/accessory/reference procedure. | Changes measurement results. Matrix is colorimeter-specific; selecting a profile neither creates nor validates calibration. | R §§4.2.1.16–18, pp.18–19; A §12.2.3, pp.77–78 |
| `matrixId`: Existing matrix correction | CR100 | Select an existing matrix when Matrix mode is active. | Accessory-dependent; a matching profile name alone does not establish calibration or suitability. No profile creation or overwrite. | R §4.2.1.17, p.18; §4.3.2.15, p.44; A §12.2.3, pp.77–78 |
| `matchId`: Existing match correction | All, when reported | Select an existing match when Match mode is active. | CR100 XYZ matching and CR250 spectral matching differ. Do not infer CR300 profile semantics from either. No profile creation or overwrite. | R §4.2.1.18, p.19; §4.3.2.16, p.45; A §§14.3.1.1–2, pp.83–84 |
| `maxAutoExposureMs`: Maximum automatic exposure (ms) | All, firmware ≥1.26 and supported bounds | Limit integration time in Auto exposure mode when the experiment needs a limit. | A lower limit may affect low-light results. No `RS` readback is documented: a successful setter is acknowledged only. It is not the host timeout or total acquisition deadline. | R §4.2.1.9, p.15; §4.3.1.10, p.26; A §5.8, p.20 |

The filter-clear ambiguity is specific: `SM Filter1 0` returns an error in R
§4.2.1.2, while the CR100 reset table calls zero “No filter selected.” The driver
does not fabricate a universal zero/None choice. Use only supported reported
choices; an unestablished clearing operation remains unavailable.

Synchronization, exposure and averaging can change the temporal sample of a
modulated or changing source. Treat them as measurement context, not merely
noise controls. Accessory changes can change physical quantity; preserve the
per-reading [quantity and calculation provenance](color-science.md). The
instrument's CMF selection does not change the host CIE 1931 2° integration
used for CR250/300 primary XYZ.

## Current settings, capture settings and receipts

`readCapabilities()` queries supported choices and bounds using the applicable
`RC` commands. Its report contains `controls`, `identity`, `readAtUTC` and
`responses`. It does not return a substitute for current settings.

A numeric control is available only when its `RC Min…` and `RC Max…` replies
are both positive numbers and the minimum does not exceed the maximum. A
complete, correctly framed limit reply that fails this, such as `0 msec`, a
zero `ExposureX` or a reversed pair, is kept in `responses` with status
`unparsed` and an `error` naming the problem. Only the control that the limits
bound becomes unavailable, with unknown bounds. The exposure limits bound both
`exposureMs` and `maxAutoExposureMs`. An explicit request for an unavailable
control is refused before the first setter. Selecting Fixed exposure or Manual
synchronization, or changing range while exposure is Fixed, also needs that
numeric control available and a known value within its limits: the request's
own value or the current readback. Other controls, and the automatic recipe
when its own choices are reported, are unaffected. Timeouts, framing
errors and malformed choice lists still fail the report.

`readSettings()` returns:

- `values`: current values keyed by the setting IDs above; unavailable values
  remain absent rather than becoming zero.
- `controls`: the actual catalog with availability, reported options and bounds.
- `identity`, `readAtUTC` and `responses`: the identified meter, host observation
  time and command responses supporting that report.

Current settings are obtained with `RS`. The `RM` metadata retained with a
measurement describes the **last capture**. Changing a setting afterward does
not update an earlier capture. In particular, `RM MaxAutoExposure` is not a
current-setting readback, and a previously acknowledged write does not become
an independently verified value.

Both apply methods return a receipt containing `requested`, `before`, `after`,
`commands`, `acknowledgements`, `status` and `error`. `error` contains `identifier`
and `message`. The status is exactly:

- `applied`: the requested application completed; inspect responses/readback to
  distinguish acknowledged-only values from independently observed settings.
- `unchanged`: no setting write was required because current readback already
  confirmed the requested values.
- `failed`: application failed, including a failure after earlier writes
  succeeded. Do not take a measurement on this receipt.

The complete requested combination is validated before the first setting write.
Argument validation before any I/O may throw. Readback-confirmed unchanged
values are skipped. A multi-command update is not atomic: there is no promised
rollback, automatic retry or automatic new exposure after an error. The receipt
retains successful commands, acknowledgements and available before/after reports
so partial application is visible. If a report fails partway through, its earlier
values and completed replies remain available; missing fields are not inferred.
A failing response record retains its command, header or unparsed reply in
`response`, completed table rows in `lines`, and unconsumed bytes in
`partialTail`. Its `status` is `incomplete` for a timeout or unread tail, or
`error` for another parsing failure; `error.identifier` and `error.message`
identify the failure. A successful header code does not make an incomplete
capability list available. These raw records are never substituted for parsed
settings. Public `readSettings` and `readCapabilities` still throw on transport failure.
Resolve the failure and inspect settings before proceeding. A timeout does not establish that a setter was rejected.
After a failed setter or readback, native `Measure` is blocked until a later
successful settings application covers every setting whose write was attempted
in the failed application, or a new connection is constructed and identified.
An empty `applySettings(struct())` request does not clear the block. The later
application may explicitly choose different target values; an `unchanged`
receipt is sufficient only when readback confirms all the required settings.
Recheck the physical setup and current settings before resuming; reconstruction
establishes a fresh identified connection and does not undo instrument changes.

An accessory change can alter the available matrix catalog. Do not combine a
changed accessory with Matrix-mode or matrix-profile changes in one request:
the destination accessory's catalog cannot be validated from the current
accessory's report. Apply the accessory separately, read the new capabilities
and settings, then select the applicable matrix. This preserves validation
before each set of writes instead of guessing which profile will exist.

For direct native use, retain the receipt beside the saved `snapshot`, as in the
example. An integrating measurement session retains successful receipts as
`instrumentSettings`, with its own `policy` and `overrides`, and retains failure
receipts without committing a reading. These are separate from the device's
capture metadata.

## Protocol coverage

This settings API covers the controls listed above and existing profile
selection. Coverage of the manufacturer's Remote 1.36 interface is summarized
below; use the manufacturer application for operations outside this API.

| Remote 1.36 family | Implemented | Not implemented |
| --- | --- | --- |
| Echo `E`, section 4.1 | Communication with echo already off. | Automatic echo toggle; the command is state-dependent. |
| Measurement setup `SM`, section 4.2.1 | Typed controls above; CR100 Colorimeter selection in the automatic recipe. | Temporal modes, sampling rate, flicker-search limits, reset, aperture setter and device CMF setter. |
| Hardware setup `SH`, section 4.2.2 | None; the manual reserves this family for expansion. | Hardware setup, heater and temperature commands. |
| Computation `SC CMF`, section 4.2.3 | None; MATLAB observer/integration is defined independently. | Device computation changes. |
| Measurement reads `RM`, section 4.3.1 | Native XYZ, spectrum, radiometric result and documented capture metadata. | Additional device colorimetric outputs, 10-degree outputs, device CCT/uv, temporal samples and sampling rate. |
| Configuration `RC`, section 4.3.2 | Identity and the control-specific choices and bounds above. | Instrument-type, aperture-option, calibration-factor and temporal-limit interfaces. |
| Current setup `RS`, section 4.3.3 | Ordinary settings, physical aperture and CR100 mode readbacks. | Temporal setup and current device CMF selection. |
| Acquisition `M`, section 4.3.4 | Blocking acquisition. | `MT`, `MA` and `MF`, reserved for future implementation in this manual. |
| Calibration creation `CC`, section 4.4 | None. | `CC Matrix` and XYZ-factor `CC Match` creation. These differ from selecting an existing profile and from CRIApp's spectral-match upload workflow. |
| App/utility operations | None. | Manufacturer application workspace/data manipulation, firmware update and backup/recovery. |

The setters' cross-references mention `RC MatrixCalib` and `RC MatchCalib`,
which report factors. For profile selection this API uses the separately
documented `RC Matrix` and `RC Match` ID/name lists in sections 4.3.2.15-16.
Profile IDs and names do not report the coefficients or uniquely identify a
calibration. Legacy matrix-mode settings also
remain distinct from the newer user-calibration API.
The `SM SyncFreq` and `RC MinExposureX` command examples resolve inconsistent
syntax lines in their respective sections. Counted capability lists must still
match their declared row count, including where a manual example is inconsistent.

The expert raw port requires the caller to handle validation, framing and
metadata retention. It does not add typed support for omitted commands. The
CR250/300 physical aperture is fixed when ordered.

Automated settings and recovery checks are described in the
[software-test reference](../../testing/cr.md).

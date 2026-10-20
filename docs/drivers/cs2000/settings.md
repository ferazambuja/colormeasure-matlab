# Current settings and automatic acquisition

`Connect` and native `Measure` preserve the instrument's existing speed and
synchronization. For automatic acquisition, explicitly call
`applyAutomaticSettings` before `Measure`. It selects **Multi-Normal, a 1-second
multi interval, internal ND Auto and No Sync**, including when the instrument
was left in Manual. This starting recipe follows the operating manual's
factory speed/ND and sync defaults (pp.26,29) and Rev.7's defaults table (p.75).
It is not an automatic determination of the best setup for every target.

Physical aperture, accessory compensation and existing user correction stay
unchanged unless an explicit writable override is supplied. Native
`MeasureManual` keeps its existing temporary manual-exposure behavior,
including internal ND Off and restoration of the previous speed configuration.
The new partial settings API can explicitly select Manual with ND On or Off.

## Read, apply and measure

Within a function, set `portName` to the selected instrument's serial port
(see [port selection](README.md#troubleshooting)), then connect with cleanup:

```matlab
meter = colormeasure.drivers.cs2000.CS2000(portName);
cleanup = onCleanup(@()delete(meter));
meter.Connect();
current = meter.readSettings();       % Current setup; does not expose the sensor.
disp(current.values);
receipt = meter.applyAutomaticSettings();
if strcmp(receipt.status,'failed')
    error('CS2000:SettingsNotApplied','%s',receipt.error.message);
end
meter.Measure();                     % Exactly one explicit acquisition.
measurements = meter.snapshot();
save('automatic-reading.mat','measurements','receipt');
```

`readSettings` requires a connection and sends current-setting queries, not
`MEAS` or `MEDR`. Establishing that connection still has the documented
remote-mode, measurement-key and backlight effects. Reading the static
`colormeasure.drivers.cs2000.settingsCatalog()` sends nothing and requires no connection.

`applySettings(changes)` changes only supplied fields. `applyAutomaticSettings`
merges supplied overrides with the automatic recipe. For example:

```matlab
% Fixed exposure is an explicit advanced override, not the normal recipe.
overrides = struct('speedMode',3,'integrationTimeSeconds',0.1, ...
    'internalNDMode',1,'syncMode',1,'frequencyHz',60);
receipt = meter.applyAutomaticSettings(overrides);
% Check receipt.status before calling Measure, as above.

% Select an existing populated correction without changing speed or sync:
receipt = meter.applySettings(struct('userCalibrationChannel',3));
```

Changing to Manual does not silently choose ND Off or reuse the recipe's
1-second Multi interval as a manual exposure. Supply a valid time and fixed
ND selection when they cannot be inherited from an existing Manual setup.
Normal/Fast do not accept an explicit integration time. Internal sync needs
a known frequency; No Sync and External do not accept a frequency override.

## Settings in the measurement window

The interval editor follows the speed requested for the next reading. It shows
**Manual exposure (s)** for Manual and **Multi averaging interval (s)** for
Multi-Normal or Multi-Fast. Without a speed override, the window's automatic
recipe selects Multi-Normal. Normal and Fast do not accept an interval override.
Stage a new speed and its interval together before **Use for next readings**;
Manual also needs a fixed internal ND selection. The driver checks the complete
configuration before writing.

**Last read** retains the observed value with its speed name, so a previous
manual exposure cannot be mistaken for the next Multi averaging interval.
Changing the draft neither updates that observation nor queries the instrument.

Ch00 is manufacturer calibration. **Read settings** obtains the current user
channel's name only. Other Ch01–Ch10 entries say **name not read**; that does not
mean they are empty or populated. Selecting a channel does not inspect it or
create a correction. Before applying a requested nonzero channel, the driver
checks that channel using the existing protocol preflight.

## Advanced fields and help

The value-only catalog supplies each field's label, choices/range, meaning,
use cases, tradeoffs, normal behavior and manufacturer sources. The observed
catalog removes unsupported Multi-Fast choices. Dependent fields remain
stageable so a caller can enter a new mode and its parameters together; the
driver validates the complete target against actual readback before writing.

| Field | Values and meaning | When useful and important dependency |
| --- | --- | --- |
| `speedMode` | 0 Normal, 1 Fast, 2 Multi-Normal, 3 Manual, 4 Multi-Fast | Normal favors low-light accuracy; Fast favors shorter low-light measurements. Multi averages periodic light with unknown/unstable frequency. Multi-Fast needs established modern support. |
| `integrationTimeSeconds` | Manual: 0.005–120 s, whole microseconds; Multi: 1–16 whole seconds | A fixed exposure is useful for controlled experiments. The Multi interval is not total measurement duration; dim sources can take longer. |
| `internalNDMode` | 0 Off, 1 On, 2 Auto | Auto chooses the built-in filter from brightness. Fixed ND can keep filter state consistent during a luminance sweep. Manual permits only Off/On; old nonmanual modes require Auto. |
| `syncMode` | 0 No Sync, 1 Internal, 2 External | Internal uses a known frequency; External needs the physical 5 V CMOS sync input. For unknown/unstable frequency the manufacturer recommends No Sync with Multi. There is no Auto-sync command. |
| `frequencyHz` | Internal only: 20.00–200.00 Hz, 0.01 Hz steps | Enter the known source repetition frequency, not an assumed display or mains frequency. This is not a measured refresh rate. |
| `measurementAngleDegrees` | Read-only: 1, 0.2, 0.1 degrees | Set the physical selector while idle and read again. The focused target must fill the measured area. Aperture is distinct from the 2°/10° colorimetric observer. |
| `closeupLens` | 0 Standard, 1 Close-up compensation | Match the physically attached optional lens and its registered factors. There is no accessory detection. |
| `externalNDFilter` | 0 None, 1 ND 1/10, 2 ND 1/100 compensation | Match the attached external filter and registered factors. This does not control the internal ND. Do not combine the optional close-up lens and external filter. |
| `userCalibrationChannel` | 0 manufacturer standard; 1–10 stored user corrections | Select the channel prescribed for the experiment. Empty channels are rejected. Selection does not author or validate calibration. |

An inherited close-up/external-ND combination is reported accurately and is
not silently changed by the automatic recipe. A requested accessory change
that would leave both selected is rejected. Software cannot establish which
accessories are physically attached. The manufacturer warns that this
combination gives inaccurate measurements (operating pp.43,45).

## Reports, failures and persistence

`readSettings` returns `values`, `controls`, `identity`, textual `readAtUTC`
and raw `responses`, plus `speedLayout` and the selected `userCalibration`
name/status. This observation is separate from the actual exposure conditions
in `metadata(k).conditions` and the pre-exposure acquisition snapshot. For
example, a 1-second Multi interval can produce a longer actual integration.

An application receipt contains `requested`, `before`, `after`, attempted
setting `commands`, their raw `acknowledgements`, `status` and `error`.
`preflight` retains a requested-channel name check when needed. `persistence`
explicitly records remote mode 1, persistent settings, and no automatic
restoration. The command list contains setting attempts, including an attempt
whose reply was lost; queries live in the reports and preflight record.

- `unchanged`: a fresh complete readback already matches; no setter was sent.
- `applied`: acknowledged changes were followed by a matching complete readback.
- `failed`: validation, an instrument error, timeout or mismatching readback
  stopped the operation. Before/after reports can be partial, and earlier
  commands may already have changed the instrument. Acknowledgements alone
  do not claim verified readback. No exposure, retry or automatic rollback follows.

Invalid argument types/ranges can throw before any I/O. Otherwise inspect the
receipt and do not acquire on `failed`. After any attempted setter fails, native
`Measure`/`MeasureManual` also refuse acquisition until a successful application
explicitly covers **every requested field** from the failed application, or a
new connection. Recovery may deliberately choose different values, including
values that fresh readback already confirms. Empty requests, unrelated changes
and incomplete recipes do not clear that guard, even if they need no writes.
An uncertain stream is closed without unsafe
restoration commands. A new connection is not proof of rollback: inspect the
instrument and explicitly choose the intended settings.

Changes under `RMTS,1` persist after disconnect, including a temporary change
that is later restored. Only changed, readback-confirmed values are written.
Disconnect restores its own backlight change, not the settings API's changes.
`RMTS,2` requires firmware ≥3.00.9301 and is not assumed or probed. It also
does not suppress calibration/data writes or promise rollback (Rev.7 pp.12–13).
`Connect` skips backlight writes when the during-measurement flag
is already Off; cleanup restores an actual backlight change. A change that an
uncertain stop left unrestored is restored by the next connection to the same
instrument that shares the driver's `UnrestoredBacklight` map.

Native `Save` retains measurement history; it does not implicitly attach a
separate settings receipt. The example above saves both, and `Load` accepts
the native `measurements` variable while leaving the receipt available in the
MAT file. Keep the receipt with results when settings provenance matters.

## Model support and remaining scope

CS-2000 ≤1.01.0000 uses short nonmanual speed replies and fixed Auto ND;
CS-2000 ≥1.10.0003 and CS-2000A use the modern layouts. A CS-2000 Manual
reply alone does not distinguish these generations. The common `SPMS,2,1`
form safely requests Multi-Normal/1 s/Auto on either, then SPMR verifies it.
Modern-only Multi-Fast/nonmanual fixed-ND changes are rejected unless the
identity/readback establishes support. No firmware version is guessed and no
unverified `VERR` query is sent.

This API covers current speed/sync/aperture/accessory/channel settings.
Calibration authoring/deletion and coefficient backup, stored device-memory
operations, target editing, LCD color/difference controls, instrument baud
changes, firmware discovery, remote mode 2, reset and instrument cancellation
remain outside it. The [protocol reference](protocol-and-data.md) and
[metadata inventory](metadata.md) describe acquisition and these boundaries.

Sources: [operating manual](https://www.konicaminolta.com/instruments/download/instruction_manual/display/pdf/cs-2000-2000a_instruction_eng.pdf)
pp.26–33 (speed/sync/internal ND), 43–48 (accessories/channel), 54–55 (aperture/focus);
[Rev.7](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf)
pp.12–13, 15–40, 75, 87–89 (persistence, commands, defaults and model layouts).

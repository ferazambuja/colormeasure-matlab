# CR device metadata and firmware

Use the [measurement guide](README.md) to acquire and save readings, and
the [API reference](api-and-protocol.md) for data shapes.

## What is saved

Connection identifies the requested model with `RC Model`, reads its serial
number with `RC ID`, and records the exact `RC Firmware` string. These values are
saved in `measurements.identity` and copied into each `metadata(k).identity`,
along with the chosen port and protocol reference. Firmware suffixes are kept.

After each acquisition, the driver reads **last-capture** settings using `RM`
commands. The manufacturer distinguishes these from `RS` current setup and
`RC` configured capabilities. This matters when automatic exposure or range
selection changes the settings actually used. Metadata collection does not
change settings or take another reading. [1, §§4.3.1–4.3.3]

```matlab
saved = load('cr-reading.mat', 'measurements');
reading = saved.measurements.metadata(1);
disp(reading.identity.firmware);
disp(reading.captureSettings.aperture);
disp(reading.captureSettings.exposureMs);
struct2table(reading.metadataResponses)
```

`captureSettings` contains text or numeric values. Every listed field also has
one `metadataResponses` entry with `field`, `command`, `value`, `unit`, `status`,
`code` and `response`. The raw response preserves information that cannot yet
be interpreted reliably. Read a query's raw reply from its
`metadataResponses` entry, using `field` or `command` to identify the query.

`acquiredAt` is host UTC time after receiving XYZ; `settingsReadAt` is host UTC
time after reading settings. Neither claims to be the exposure start or end.
The device's `RM Time` is stored separately. Its documented `NA` response is
marked unavailable, not replaced by a host timestamp. [1, §4.3.1.3]

## Calculation provenance

Device and host values are stored separately. `metadata(k).xyzSource` remains
`instrument RM XYZ (2 degree)` for CR-100. CR-250/CR-300 rows identify the host producer
as `MATLAB colormeasure.colorimetry.spectra2XYZ, CIE 1931 2 degree`; their unmodified `RM XYZ`
triplets are still in `instrumentXYZ`. All three models record
`cctSource = 'MATLAB colormeasure.colorimetry.XYZ2CCT, CIE 1960 UCS, MCSL compatibility table'`.
This is a host calculation from each model's primary `XYZ`; no `RM CCT` query
is issued. A supported device result is not necessarily a result requested by
this driver.

The method strings identify the producer and calculation convention. The
[source manifest](../../../resources/provenance/colorimetry-source.json)
records repository-relative colorimetry paths and hashes. The current repository
commit identifies the implementation used here. Equations and limitations are described in
the [scientific guide](color-science.md).

## Capture fields and commands

The command list is maintained in [metadataQueries.m](../../../src/+colormeasure/+drivers/+cr/metadataQueries.m);
numeric parsing is in [metadataValue.m](../../../src/+colormeasure/+drivers/+cr/metadataValue.m). Each command
returns a framed response such as `OK:0:RM Exposure:111.622 msec`.

| `captureSettings` field | Command | Value or unit | When queried | Manual §4.3.1 |
| --- | --- | --- | --- | --- |
| `deviceTime` | `RM Time` | Device text; may be unavailable | All three models | .3 |
| `accessory` | `RM Accessory` | Accessory name | All | .4 |
| `filters` | `RM Filter` | Comma-separated names, or `None` | All | .5 |
| `aperture` | `RM Aperture` | Aperture name, e.g. `5 deg` | All | .6 |
| `instrumentMode` | `RM Mode` | Mode name | All | .7 |
| `exposureMode` | `RM ExposureMode` | Mode name | All | .8 |
| `exposureMs` | `RM Exposure` | Milliseconds | All | .9 |
| `maxAutoExposureMs` | `RM MaxAutoExposure` | Milliseconds | All | .10 |
| `rangeMode` | `RM RangeMode` | Range-selection mode name | All | .11 |
| `range` | `RM Range` | Electronic range name | All | .12 |
| `syncMode` | `RM SyncMode` | Synchronization mode name | All | .13 |
| `syncFrequencyHz` | `RM SyncFreq` | Hz | Only for a documented available mode other than `None` | .14 |
| `exposureMultiplier` | `RM ExposureX` | Positive integer multiplier | All | .15 |
| `userCalibrationMode` | `RM UserCalibMode` | `None`, `Matrix` or `Match` | All | .17 |
| `legacyMatrixMode` | `RM MatrixMode` | `Enabled` or `Disabled` | Only if the newer calibration-mode command returns unsupported | .16 |
| `matrixId` | `RM Matrix` | Device text identifying the matrix | Matrix calibration, including legacy `Enabled` | .18 |
| `matchId` | `RM Match` | Device text identifying the match | Match calibration | .19 |
| `speed` | `RM Speed` | Speed name | CR-250 and CR-300 | .20 |
| `warnings` | `RM Warnings` | Warning payload retained as text | All | .34 |
| `cmfIndex` | `RM CMF` | Integer table index | CR-250 and CR-300 | .41 |

Aperture is a device-reported **name**; the code does not assume it is always
an angle or convert it into a spot diameter. Filters and electronic ranges
also keep their names. Warnings are not interpreted as a bitmask because the
manual does not specify that encoding. [1, §§4.3.1.5–6, .12, .34]

The manual forbids `RM SyncFreq` when synchronization is `None`, so that query
is skipped. Matrix and match IDs are conditional on calibration mode. The
warning under `RM Matrix` incorrectly names `Match`; the description of
`RM UserCalibMode` and the corresponding setup commands consistently associate
Matrix with `RM Matrix` and Match with `RM Match`. [1, §§4.3.1.14, .17–19;
4.3.3.14–15]

For spectral instruments, CMF index 0 denotes the default CIE 1931 table;
indices 1–3 denote user tables. Their names or contents cannot be inferred
from the index. The original `instrumentXYZ` can therefore differ from the
host's fixed CIE 1931 calculation. The driver never sends `SC CMF`: that
command recalculates and changes the current device measurement.
[1, §§4.2.3.1, 4.3.1.41; see also the [scientific guide](color-science.md).]

## Missing values and failures

| Status | Meaning |
| --- | --- |
| `available` | A successful reply was parsed; inspect its response code for any warning. |
| `unavailable` | The device returned the documented `NA` value. |
| `unparsed` | A complete, correctly framed reply has an unrecognized payload; the raw reply is retained and the typed value is unavailable. |
| `unsupported` | The command returned the framed invalid-command code `-500`. |
| `instrumentError` | A different framed negative device code was returned; raw error is retained. |
| `notApplicable` | A model or setting excludes the query, so it was not sent. |
| `dependencyUnavailable` | A needed mode was unavailable, so the dependent query was not sent. |

Unavailable text is `''`; unavailable numeric data is `NaN`. For skipped
commands, `response` is empty and `code` is `NaN`. Always use the status to
distinguish a missing value from a setting such as `None` or numeric zero.

Framed metadata errors and unparsed optional payloads are retained alongside
a completed reading. An unparsed number is `NaN`, and unparsed text is `''`.
For example, `RM Exposure:1 sec` is saved verbatim with status `unparsed`; the
driver does not guess a conversion from an undocumented suffix. The documented
sync modes are `None`, `Auto`, `Manual`, `NTSC`, `PAL` and `CINEMA`. An unknown
sync or calibration mode is unparsed, and dependent frequency or calibration-ID
queries are skipped with `dependencyUnavailable`. The legacy calibration query
is attempted only for an explicit unsupported-command reply, not a parse failure.
[1, §§4.3.2.11, .13–14]

A timeout or incomplete/malformed framing still fails the transaction and closes
the uncertain connection. Metadata collection never automatically repeats the
exposure. See [recovery instructions](api-and-protocol.md#errors-and-recovery).

These queries add sequential communication round trips after the measurement
outputs. Each sent query has its own `ResponseTimeout`; that is not one shared
deadline for the entire metadata stage. The catalogue has 20 entries, with
inapplicable queries skipped, so allow for roughly 20 ordinary reply deadlines
in addition to exposure and spectrum retrieval when planning an outer timeout.
A missing reply stops at that query's deadline instead of continuing through
the remaining commands. Fast, complete framed replies normally take much less
time.

Most listed queries date to firmware 1.04. `RM Mode` and `RM UserCalibMode`
date to 1.16, spectrometer `RM Speed` to 1.17, and `RM MaxAutoExposure` and
`RM CMF` to 1.26. The implementation records actual command support rather
than treating a version string as proof that a command works. [1]

## Temperature and other interface limits

The CRIApp manual lists **internal temperature during capture**, in °C and
°F, as displayable data. However, Remote Communications Manual 1.36 gives no
temperature read command, and the installed SDK headers expose no documented
temperature/transport API. Temperature is therefore not acquired or saved by
this driver. This is a gap in the verified interface, not evidence that the
instrument has no temperature sensor. A documented command and representative
replies are needed before adding it. [1; 2, §6.2.1, p.27; 3]

The driver records capture-relevant scalar metadata rather than requesting
every available result. Existing XYZ, radiometric values, spectra and their
wavelength headers remain separately retained. Additional device calculations
such as `RM xy`, `RM CCT` and `RM XYZ10` are not operating metadata and are not
collected. Temporal samples and sampling-rate settings belong to a temporal
acquisition, which this driver does not implement. Capability catalogues
(`RC Aperture`, `RC Accessory`, limits, etc.) describe available choices, not
the last capture. Full calibration tables are not backed up automatically.

## Public firmware information

Checked against the manufacturer's download page on **2026-09-16**: [3]

| Instrument | Latest publicly listed firmware | Published release date |
| --- | --- | --- |
| CR-100 | 1.39 | 2018-11-14 |
| CR-250 | 1.34 | 2017-05-24 |
| CR-300 | No model-specific firmware release listed | Not established |

These are public listings, not a guarantee that no newer service/custom release
exists. In particular, the CR-250 listing does not establish a CR-300 version.
The saved `identity.firmware` is the actual reply from the connected unit;
the driver neither requires equality with this table nor updates firmware.

The same page lists CRI desktop installer **1.5.13**, released 2018-10-31.
That is an application/SDK version, not instrument firmware. Recheck the
manufacturer's current guidance for the exact model before any firmware
maintenance; firmware installation is not part of acquisition or testing.

## Sources and maintenance

1. Colorimetry Research, *Remote Communications Manual*, version 1.36,
   distributed with the [manufacturer's CRI installer](https://www.colorimetryresearch.com/downloads).
   This reference uses its printed section numbers; examples establish reply
   syntax, not readings from a particular laboratory unit.
2. Colorimetry Research, *CRI App Manual*, version 1.5.10, §6.2.1 (Data View),
   distributed with the same installer. The measurement-field descriptions
   distinguish internal temperature from correlated color temperature.
3. [Official firmware/software downloads](https://www.colorimetryresearch.com/downloads)
   and [CRI App, Utility & SDK](https://www.colorimetryresearch.com/products/cri-app).

When adding or changing a metadata command, update `metadataQueries`, its
parser and simulated fixtures, this table, and the metadata checks in
[CR testing guide](../../testing/cr.md) together. Retain the source section, model limits,
reply example, units and unavailable behavior. Do not turn an undocumented
field into an assumed device value.

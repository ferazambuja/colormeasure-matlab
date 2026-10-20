# CS-2000 current metadata and firmware

Each reading retains instrument conditions, identity and acquisition metadata.
See the [measurement guide](README.md) for acquisition and saving, and the
[protocol reference](protocol-and-data.md) for the API and data format.
The command definitions below come from Konica Minolta's
[CS-2000/2000A Communication Specifications, Rev.7.00](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf),
KMSE A0E3-CS.07E, 21 July 2020. Page numbers are the printed numbers.

In the shared-window workflow the same complete `metadata(k)` appears as
`session.measurements(k).instrumentMetadata`, with the native data/metadata
also retained in `.driverSnapshot`. `.cleanupStatus` and `.warnings` record
connection restoration separately. The adapter adds no device metadata query
and never substitutes display-observer settings for the requested XYZ observer.
See [batch and native file formats](protocol-and-data.md#native-mat-batch-mat-and-csv).

## Identity and factory calibration

`Connect` reads `IDDR`: model, variation and seven-digit serial number (p.14).
The serial is retained as text, preserving leading zeros. Each reading copies this
identity into `metadata(k).identity`.

`DTCR` reads the date and time of factory calibration once per connection
(p.71), after `MSWE,0` has acknowledged disabling the remote measurement key. `identity.factoryCalibration` contains:

| Field | Meaning |
| --- | --- |
| `date`, `time` | Original `YYYYMMDD` and `HHMMSS` text |
| `dateTime` | Validated MATLAB datetime with no assumed time zone |
| `queriedAt` | Host UTC timestamp of this query |
| `response` | Original framed reply |
| `status`, `errorCode`, `errorIdentifier`, `errorMessage` | Availability/parse status and diagnostics; see [failures](#failures-and-persistence) |

The factory date is not the measurement time, a certificate, or a calibration
expiry date. Saving it does not establish calibration accuracy or traceability.
It is copied with the connection identity rather than queried for each exposure.

## Configuration versus actual capture conditions

Before each `MEAS,1`, the driver reads current synchronization, speed and
display observer into `metadata(k).acquisition.configurationBefore`. These
queries do not change settings. During `MeasureManual`, they run after the
temporary manual speed is selected. `queriedAt` is the host UTC time at the
start of the configuration snapshot, not an instrument exposure timestamp.

| Command | Saved value | Interpretation |
| --- | --- | --- |
| `SCMR` (p.15) | `.sync.syncMode`, `.sync.frequencyHz`, `.sync.response` | Modes 0 = no sync, 1 = internal, 2 = external. Only internal mode reports frequency: the integer is divided by 100 to obtain 20–200 Hz. Other modes use NaN for an unreported frequency. |
| `SPMR` (pp.17–19) | `.speed.speedMode`, `.speed.integrationTimeSeconds`, `.speed.internalNDMode`, `.speed.internalNDModeSource`, `.speed.response` | Requested mode/integration and ND selection, not the actual exposure result. Automatic integration uses NaN for the unreported requested time. |
| `OBSR` (p.70) | `.observerMetadata` | Current display observer, 0 = CIE 1931 2°, 1 = CIE 1964 10°. The acquisition still explicitly requests the 1931 XYZ block. |

`SPMR` mode 0 is Normal, 1 Fast, 2 Multi Integ Normal, 3 Manual and 4 Multi
Integ Fast. Multi-integration times are 1–16 seconds; Manual reports
microseconds, converted to seconds (0.005–120). ND codes are 0 = off, 1 = on,
2 = automatic; Manual permits only off/on. Legacy replies omit the ND field
for modes 0–2: Rev.7 specifies fixed Auto in those cases, recorded as
`internalNDModeSource='protocol-fixed-auto'`. An explicitly returned ND value
uses `'reported'`. The short legacy layout is not permitted for mode 4 or for
any verified CS-2000A/variation-2 identity, including custom names. Both ordinary
and manual acquisition parse that distinction. An invalid optional snapshot
is marked `unparsed`; manual acquisition still requires a valid pre-change
SPMR reply before it can set and later restore speed. For CS-2000/variation 1,
both documented layouts remain accepted because this driver does not retrieve firmware.
These shapes establish how to interpret the reply, not an exact firmware version.

The configuration field `integrationTimeSeconds` is a requested policy value:
the averaging interval in Multi modes or the fixed exposure in Manual mode.
Settings readbacks use that same definition. It does
not report the completed reading's exposure. For example, two Multi readings
can have actual exposures of 2 s and 3 s under the same requested 1 s interval.
They share the interval policy, while their separate actual exposures remain
in `conditions.integrationTime` and the raw `MEDR` replies.

`acquisition.manualIntegrationTimeRequestedSeconds` records the argument used
by `MeasureManual` for its temporary override. Ordinary `Measure` leaves this
manual-only field as NaN, including when the instrument is already configured
for Manual mode. Use `acquisition.configurationBefore.speed` to inspect the
active request policy for either acquisition route. A NaN manual-only argument
does not mean the Multi averaging interval is unknown.

After completion, `MEDR,0,0,1` supplies the **actual acquisition conditions**
(p.44). They remain in `metadata(k).conditions` and include all eight fields:
speed, synchronization, actual integration time, internal ND, close-up-lens
setting, external-ND setting, measurement angle and user-calibration channel.
`integrationTime` is seconds converted from the returned microseconds.
`measurementAngle` keeps the instrument code; `measurementAngleDegrees`
adds its documented mapping: 0 → 1°, 1 → 0.2°, 2 → 0.1°.

The actual conditions are authoritative for the captured reading. A
pre-measurement configuration snapshot cannot replace them. Accessory fields
describe instrument compensation settings, not an independent detection of
which physical lens or filter is mounted. Likewise, aperture angle alone
does not give a spot diameter without measurement distance.

```matlab
saved = load('white-measurement.mat', 'measurements');
reading = saved.measurements.metadata(end);
disp(reading.identity.serialNumber);
disp(reading.identity.factoryCalibration.dateTime);
disp(reading.conditions.measurementAngleDegrees);
disp(reading.conditions.integrationTime); % actual integration, seconds
disp(reading.acquisition.configurationBefore.sync);
```

## Calibration channel and backlight

After reading the actual conditions, the driver queries `UCPR,2,cc` only for
the channel used by that reading, from 01 to 10 (pp.28–29). Channel 00 means
factory-standard calibration and is not a valid UCPR channel. The resulting
`acquisition.userCalibration` contains `channel`, `status`, `name`,
`queriedAt`, `response`, `errorCode`, `errorIdentifier` and `errorMessage`:

- `factory-standard`: channel 00, no name query, empty name/reply and NaT time.
- `available`: a validated ten-character padded reply, with a trimmed name
  and the original padding preserved in `response`.
- `no-compensation-values`: documented `ER05`; no name is invented.
- `unavailable`: documented bare UCPR `ER17`, `ER30`, `ER32` or `ER34`,
  retained with its code and response. Parameter/internal-memory failures do
  not establish a calibration name or validate the calibration tables.
- `unparsed`: complete successful frame with an invalid name payload,
  retained with its original response and parser diagnostic.

This is a subsequent channel-name readback, not a field embedded in MEDR.
A name does not establish the calibration coefficients or their validity.
The driver does not download or modify the complete calibration tables.

Connection reads `BALR` to restore backlight settings on cleanup
(pp.63–64). That reply also appears in `acquisition.backlight`:
`originalSettings` is the pair of ordinary/during-measurement flags that
cleanup restores, `originalResponse` is the raw reply, and `commandedSettings`
is the pair the driver sends for acquisition, `[originalSettings(1),0]`.
After an uncertain stop left an earlier change to this instrument unrestored,
the during-measurement flag in `originalSettings` is that earlier original,
while `originalResponse` still shows this connection's reply. The commanded pair
is labeled as a host action, not an independently observed readback.

## Failures and persistence

Each metadata entry contains `identity`, `conditions`, `acquisition` and its
original UUID `readingId`. `Save` and `Load` preserve those fields alongside
the spectrum and XYZ. `Load` accepts only a current native `measurements`
snapshot (`schemaVersion` 2, including the original UUID `segmentId` and
the logical `measurementConditionsIndependent` provenance flag)
and validates it before changing the history. Missing or incompatible snapshot
structure and metadata raise `CS2000:FileFormat`; invalid spectral or XYZ data
raise `CS2000:Reading` or `CS2000:Unavailable`. File-reading failures retain
MATLAB's error identifiers. A loading or validation failure leaves the history
unchanged. Duplicate or already-retained reading IDs are refused before
appending. `Load` never fills metadata from the current instrument's settings
or assigns imported readings new acquisition identities.

The additional queries take time, each bounded by `ResponseTimeout`: one
DTCR query per connection, three configuration queries per acquisition, and
at most one calibration-name query afterward. These are ancillary metadata,
so a complete `OK00` frame with an invalid payload is retained with
`status='unparsed'`, its raw `response`, and `errorIdentifier`/`errorMessage`.
Unavailable numeric settings use NaN, calibration dates use NaT/empty text,
and names use empty text. No partial parsed value is accepted. Successful
replies have `status='available'` and empty error fields. Sync and speed keep
these fields in their respective structures.
`configurationBefore.observerMetadata` retains the observer query's `value`,
`status` and raw `response`, together with any parse error. Check `status`
before interpreting an optional value.

The per-command error rules are deliberately narrower than a catch-all:

| Reply/context | Result |
| --- | --- |
| UCPR bare `ER05` | `no-compensation-values`, with the code and raw response |
| UCPR bare `ER17`, `ER30`, `ER32`, `ER34` (p.29) | `unavailable`, with the code and raw response; completed measurement remains retained |
| `ER00` or `ER02` from any command | Stop; measurement state is uncertain, so close without further setting/remote-mode writes |
| Other undocumented query error, or required identity/measurement/conditions validation error | Reject the operation; retain earlier complete readings |
| Timeout, malformed frame, error carrying an unexpected payload, or extra pending input | Stop; preserve no partial new reading and do not issue unsafe restoration commands |

SCMR (p.15), SPMR (p.19), OBSR (p.70) and DTCR (p.71) document no
nonbusy error alternative that this driver can treat as missing metadata.
In particular, an `ER00` response to DTCR cannot safely be relabeled
“unsupported”: p.41 also uses `ER00` for commands during measurement.
Acknowledged `MSWE,0` improves ordering but does not resolve that ambiguity.

The SPMR read **before changing manual speed remains required**, because its
validated settings are needed for restoration. Optional snapshots never
replace actual `MEDR` conditions. A tolerated metadata failure does not retry
an exposure; the driver appends the completed spectrum/XYZ and its explicit
metadata status together. Save/Load retain these statuses and diagnostics.
See the [recovery and cleanup contract](protocol-and-data.md#slot-99-and-persistent-settings).

## Firmware, temperature and SDK limits

`identity.firmware` is empty. `IDDR` has no firmware field, and the English
and Japanese Rev.7 command lists do not define a firmware query. This driver
does not issue `VERR`: its CS-2000/2000A support and reply format are undocumented
in those specifications. The later [CS-3000 specification](https://www.konicaminolta.jp/instruments/media/cs-3000_communicationspecifications_jpn.pdf#page=22)
mentions that command but explicitly excludes CS-2000/2000A from its scope.

Read the installed firmware version from the startup display and record it in
experiment notes, following the manufacturer's [CS-2000 protocol FAQ](https://www.konicaminolta.jp/instruments/support/faq/detail/p331/).
The displayed version is a separate observation from the saved communication
readback. Firmware upgrades are outside the measurement workflow.

Rev.7 defines no temperature readback. `ER51`/`ER52` are fault codes, not
temperature values. The driver uses the documented ASCII interface and requires
no vendor SDK; see [protocol sources](protocol-and-data.md#sources-and-sdk-scope).

Other command scopes are summarized below:

| Available information or command | Acquisition path and explicit API scope |
| --- | --- |
| `STSR`, `UCCR`, `LNSR`, `NDFR` | Queried by the explicit `readSettings`/settings-application APIs. Their current-setup report is separate from actual MEDR exposure conditions; native `Measure` does not add these queries. |
| `CSMR`, `DIMR`, `TGSR` | Display color space, difference mode and target do not define the explicitly requested absolute XYZ block. |
| UCPR correction arrays, `ALFR`, `NFCR` | Bulk calibration/compensation exports are a separate backup workflow; they are not read for every exposure. |
| `BPSR` | Requires firmware ≥3.00.0000; this driver does not retrieve installed firmware and CS-2000 `VERR` support remains unresolved. Host serial configuration is not a device baud readback. |

The [settings guide](settings.md) defines current reports and application
receipts, including requested values, readbacks, partial failures and persistent
changes. Saving only native measurement history does not implicitly save an
independent settings receipt; retain both when using the settings API directly.

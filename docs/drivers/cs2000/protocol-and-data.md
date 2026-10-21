# CS-2000 driver API and protocol reference

Use `colormeasure.drivers.cs2000.CS2000` for command-line acquisition and retained native data.
The [measurement guide](README.md) gives a complete measure/save/load example.
For the app, open [openColorMeasure.m](../../../openColorMeasure.m), click
**Run** and choose **CS-2000**. For scripted launch options, add **src** to the
path and use `session = colormeasure.drivers.cs2000.measureCS2000(...)`.
The [window guide](batch-and-ui.md) describes its automatic settings and batch
workflow; the window requires MATLAB R2026b or newer.

For a demonstration without an instrument, see the
[quick start](../../beta-testing/README.md).

## API options and retained fields

Native `Connect`/`Measure` preserve speed/sync. The explicit
`readSettings`, `applySettings` and `applyAutomaticSettings` APIs provide
current readback and verified persistent changes without acquiring a sample.
The [settings guide](settings.md) defines their catalog, coupled values,
automatic recipe, receipts and partial-failure behavior. Apply the automatic
wrapper before `Measure` when automatic exposure is intended.

### Methods

Use `onCleanup(@()delete(meter))` immediately after construction inside a
function, as in the [one-reading example](../../../src/+colormeasure/+drivers/+cs2000/measureToFile.m).
A cleanup object left in a script's workspace does not automatically run when
that script encounters an error.

| Call | Behavior |
| --- | --- |
| `meter = colormeasure.drivers.cs2000.CS2000()` / `colormeasure.drivers.cs2000.CS2000(portName,...)` | Records options; does not list or open ports. Omitted/empty text selects automatically on `Connect`; a positive number such as `4` means Windows `COM4`. |
| `meter.Connect()` / `meter.isConnected()` | Selects a candidate when needed, opens it and verifies identity / reports a usable driver connection. |
| `meter.Measure()` | Starts one measurement cycle and appends one complete spectrum, XYZ and metadata entry; no automatic retry. |
| `current = meter.readSettings()` | Reads current speed/sync/aperture/accessory/channel settings and selected-channel name; no exposure or history change. |
| `receipt = meter.applyAutomaticSettings(overrides)` | Applies Multi-Normal/1 s/internal ND Auto/No Sync plus explicit overrides; preserves accessories/correction otherwise. Check status before measuring. |
| `receipt = meter.applySettings(changes)` | Applies only supplied settings; validates the complete target and verifies readback. Changes persist; a failed receipt can include partial application. |
| `controls = colormeasure.drivers.cs2000.settingsCatalog()` | Returns plain labels, choices and manufacturer-backed per-setting help without device access. |
| `info = colormeasure.drivers.cs2000.preparation()` | Returns preparation and warm-up guidance without connecting or measuring. |
| `meter.StoreMeasurementConditions()` | Queries the latest instrument conditions without adding a reading. |
| `meter.Save(outputFile)` / `meter.Load(outputFile)` | Saves one native `measurements` struct / validates and appends a current native snapshot without opening a port. |
| `values = meter.snapshot()` | Returns the same complete native value structure used by `Save`, without saving, changing history or opening a port. |
| `meter.Erase()` / `meter.EraseAll()` | Removes the last reading / clears history and latest conditions; safe when empty. Neither erases instrument memory. |
| `meter.Disconnect()` / `delete(meter)` | Restores connection-managed settings when possible and closes the owned port / also destroys the MATLAB object. |

Once selected, the port name stays with the object, including after a failed
handshake or disconnect. Reconnecting rechecks identity on that same name;
create a new object to select another port. `colormeasure.drivers.cs2000.CS2000manual()` supports the same omitted-port behavior.

`Erase()` preserves a separately queried conditions snapshot; conditions tied
to an erased reading revert to the previous retained reading.

### Variants

| Class | Use |
| --- | --- |
| `colormeasure.drivers.cs2000.CS2000` | Native `Measure` preserves instrument settings; the explicit automatic wrapper configures automatic acquisition before `Measure` |
| `colormeasure.drivers.cs2000.CS2000manual` | Set `integrationTime` in seconds (0.005–120, whole microseconds; default 2); `MeasureManual()` selects manual exposure and restores the prior speed configuration |
| `colormeasure.drivers.cs2000.CS2000Gonio` | Stage workflow using inherited acquisition; motion, mounting and network utilities require separate setup and checks |

### Connection options

Pass constructor options as quoted name/value pairs, for example
`colormeasure.drivers.cs2000.CS2000(port,'BaudRate',9600,'FlowControl','hardware')`.
`colormeasure.drivers.cs2000.CS2000manual` accepts the same options. When passing options
with automatic selection, supply an empty first argument, for example
`colormeasure.drivers.cs2000.CS2000("",'ResponseTimeout',20)`. The example function accepts the same
five public host options after its port and output filename:
`colormeasure.drivers.cs2000.measureToFile("",'reading.mat','ResponseTimeout',20)`.
It forwards only supplied public values so the real driver owns defaults and
validation; explicit empty values are not silently replaced by defaults.
`Transport` and `PortList` provide simulated connections for tests.

| Option | Default | Meaning and accepted values |
| --- | --- | --- |
| `ResponseTimeout` | 10 | Positive finite seconds for each command write and ordinary replies; also added to the announced measurement duration. |
| `PreMeasurementTimeout` | 35 | Finite seconds, at least 35, for the first `MEAS` reply. |
| `BaudRate` | 115200 | One of 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600 or 115200; must match physical RS-232C settings. |
| `FlowControl` | `'none'` | `'none'` or `'hardware'`; RS-232C requires hardware RTS/CTS. Framing is 8 data bits, no parity, 1 stop bit. |
| `ExpectedModel` | `''` | Normally accepts standard CS-2000/2000A identities. A supplied name requires an exact match, at most nine printable ASCII characters; it does not relax variation/serial validation. |
| `UnrestoredBacklight` | new map | A `containers.Map` with `'char'` keys and `'any'` values, from serial number to the backlight pair an uncertain stop left unrestored, readable as the driver's `unrestoredBacklight` property. Pass one driver's map to the next driver; its next connection to that instrument restores the pair at cleanup. An entry that is not two binary settings refuses that connection and stays in the map until corrected or removed. The application adapter shares one map across its connections. |
| `Transport` | `[]` | Injected simulated transport for software tests. Ordinary users leave this unset. |
| `Clock` | `[]` | Injected clock with `now()` and `sleep(seconds)` for the transport's deadline loops; software tests share a `colormeasuretest.FakeClock` between the driver and the fake port. Ordinary users leave this unset. |
| `PortList` | `@() serialportlist("available")` | Function returning a vector of available names; called only when `Connect` still needs to select a port. Software tests inject a list so they never enumerate OS ports. |

Before every command, R2026b's
[`EnableWriteTimeout`](https://www.mathworks.com/help/instrument/serialport.html)
is enabled and `serialPort.Timeout` is set to the current `responseTimeout`.
The first `MEAS` reply still uses its separate pre-measurement deadline. A write
exception can mean a partial command was transmitted. The driver does not
retry or send backlight/remote-release commands on that uncertain stream; it
closes the port and retains earlier readings. Establish instrument idle and
check its remote/backlight state before reconnecting. Port closure does not
cancel an exposure or guarantee that remote mode was released. Injected
transports must expose writable `Timeout` and `EnableWriteTimeout` properties.

`Connect` separately accepts `DiscardPendingInput` (logical, default false),
`DrainQuietPeriod` (positive seconds, default 0.25) and `DrainTimeout`
(seconds greater than the quiet period, default 2). The recovery conditions
and byte limit are described [below](#slot-99-and-persistent-settings).
`saveOnDelete` is a writable property, default false. If enabled, deleting
unsaved nonempty history attempts to save a generated temporary MAT file and
prints its path; it does not replace deliberate saving to a known location.

The arrays and complete MAT schema are described under
[scientific meaning](#scientific-meaning) and
[persistence](#retention-and-persistence). Each retained reading
has one `metadata` entry with these scalar structures:

| Structure | Fields and provenance |
| --- | --- |
| `conditions` | `speedMode`, `syncMode`, `internalNDFilter`, `closeupLens`, `externalNDFilter`, `measurementAngle` and `userCalibrationChannel` are instrument codes from `MEDR` (p.44); `integrationTime` is seconds converted from its microsecond field. `measurementAngleDegrees` maps its angle code to degrees. `observer=0` records the host's requested 1931 XYZ block, not a queried display setting. |
| `identity` | Instrument `model`, `variation`, `serialNumber` and raw `response`; host-selected `port` and implemented `protocolRevision`. `factoryCalibration` retains parsed/raw DTCR date/time or an explicit unparsed status. `firmware` is empty: retrieval is not established by the verified CS-2000 protocol; see the [firmware limits](metadata.md#firmware-temperature-and-sdk-limits). |
| `acquisition` | `acquiredAt` is a host UTC timestamp after data retrieval, not an instrument exposure timestamp. `announcedDurationSeconds`, `observer` and `xyzSource` describe the request/result; `spectralResponse`, `xyzResponse`, `conditionsResponse` and `measurementResponses` retain raw reply text. `configurationBefore`, `backlight` and `userCalibration` preserve their separately labeled readbacks/actions. `MeasureManual` also retains `manualIntegrationTimeRequestedSeconds`, `speedBeforeResponse` and `speedRestoreResponse`; ordinary `Measure` uses NaN/empty strings for those manual-only fields. The active requested exposure or averaging interval is in `configurationBefore.speed.integrationTimeSeconds`; the actual returned exposure is in `conditions.integrationTime`. |

The [metadata reference](metadata.md) defines every nested field, unit,
conditional query and unavailable value. Pre-measurement settings and actual
MEDR conditions remain distinct; no additional metadata query starts an exposure.

`metadata(k)` always refers to column k of `spectralData` and `XYZData`.
`identity` on the object is the current/latest connected identity; loaded
readings retain their own identities in metadata. `cleanupStatus` and
`recoveryStatus` are connection diagnostics, not fields in the saved
`measurements` schema; retain them separately if needed to diagnose a session.
Each `Connect` starts a new `recoveryStatus`, so it never reports an earlier
connection's drain.

## Sources and SDK scope

The driver follows Konica Minolta's
[CS-2000/CS-2000A communication specifications, revision 7.00](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf),
dated 21 July 2020, document KMSE A0E3-CS.07E. Page references below use its
printed page numbers. Cross-checks use the manufacturer's
[Japanese revision 7](https://www.konicaminolta.jp/instruments/media/cs-2000-2000a_communicationspecifications_jpn.pdf),
[legacy technical note](https://www.konicaminolta.jp/instruments/media/cs-2000_technicalnote.pdf),
[instrument manual](https://www.konicaminolta.com/instruments/download/instruction_manual/display/pdf/cs-2000-2000a_instruction_eng.pdf),
and [CS-S10w Professional manual](https://www.konicaminolta.com/instruments/download/instruction_manual/software/pdf/cs-s10w_v18pro_instruction255f_eng.pdf).

The driver uses the documented ASCII serial protocol; no vendor SDK is
required. The manufacturer's [display-software downloads](https://www.konicaminolta.com/instruments/download/software/display/index.html)
provide the USB driver and CS-S10w application.

`IDDR` reports product, variation and serial number, **not firmware** (p.14).
`DTCR` reports factory calibration date/time (p.71); it does not identify
firmware or establish calibration validity. Both replies are retained with
the connection identity. The [metadata inventory](metadata.md) distinguishes
public firmware information from values available through communication.
An identification response therefore cannot establish firmware compatibility.
Revision 7 distinguishes CS-2000 ≤1.01.0000 from ≥1.10.0003/CS-2000A for
speed-mode parameters and error-value output (pp.87–89). This driver
uses documented `RMTS` and `OK00`; the [original-driver comparison](original-comparison.md)
describes the earlier handshake. Command layouts depend on model and firmware.
Standard model names must match their documented variation codes. For a custom
name, the caller must supply the exact `ExpectedModel` constructor option;
variation must still be 1 or 2 and the serial number seven digits. Undefined
variations are rejected. This is an explicit identity choice, not evidence
that a custom unit implements every standard command.

## Transport and acquisition

Construction records settings without enumerating or opening ports. Omit the
port (`colormeasure.drivers.cs2000.CS2000()`, `colormeasure.drivers.cs2000.CS2000manual()`) or pass an empty scalar
string/character vector to request automatic selection on `Connect`. The
selector calls MATLAB's
[`serialportlist("available")`](https://www.mathworks.com/help/matlab/ref/serialportlist.html)
and requires exactly one unique name. On macOS only, exact `/dev/tty.NAME` and
`/dev/cu.NAME` pairs count as one endpoint, preferring `/dev/cu.NAME`. No other
name pattern is assumed to identify an instrument. Zero or multiple candidates
fail before opening a port; multiple-candidate errors list the names. Explicit
names and positive numeric COM port numbers bypass enumeration, including any
explicitly selected `tty.*` name.

`Connect` opens that one candidate, enters remote mode with `RMTS,1`, verifies
`IDDR` model, variation and serial, reads factory calibration date/time and
the backlight configuration, and
disables the remote measurement button. This is an active handshake with
settings side effects, not passive discovery or scanning. A wrong identity,
timeout or failed open stops that attempt without trying another candidate.
Native `Connect`/`Measure` preserve speed and display-observer settings. The
optional window separately applies its automatic acquisition recipe before each
reading; see the [window guide](batch-and-ui.md).

Once a name is selected, it is retained even if the handshake later fails.
Subsequent `Connect` calls on that object reuse the name and verify identity
again, without enumerating candidates again. A failure before any name is
chosen can be retried with a new list. Create a new object to choose a different
port. A retained port name does not guarantee that the physical instrument
attached to it has not changed; the observed identity is retained per reading.
Loading/saving history or deleting an unopened object does not discover or
open ports. `colormeasure.drivers.cs2000.CS2000Gonio` takes port, stage, home position and pan/tilt
controller arguments, followed by optional CS2000 connection options.
Its `Measure({panAngles, tiltAngles})` requires matched nonempty vectors of
finite real angles and a connected meter with verified settings before moving.
Physical travel limits remain the external stage controller's responsibility.

If motion or acquisition fails, the sequence stops without an automatic return
move or sequence save. Earlier completed readings remain in the object.
Save them with `meter.Save('partial.mat')`, or retain an in-memory copy with
`partial = meter.snapshot()`, before using `meter.EraseAll()` and starting a new
sequence; otherwise new readings append to the partial history. Position recovery
is an explicit operation through the stage controller. On success, the sequence
saves and clears its readings but does not return the stage automatically.
Automatic saves choose the next unused `csN.mat` name, skipping files and
folders that already use that name. Publication refuses a destination created
in the meantime, including a name occupied by a symbolic link.
A failed save keeps the completed readings and counter intact; use `meter.Save`,
which allows replacement, to save them deliberately before clearing the
history.

Available-port lists can become stale before opening. Serial drivers, OS
permissions and device enumeration remain OS-specific; selection does not
install drivers, determine RS-232C baud or establish firmware compatibility.

For USB, p.6 lists 115200, 8-N-1 and RTS/CTS but expressly says communication
works regardless of serial settings and that baud rate does not affect USB
speed. The driver uses 115200, 8-N-1 and no flow control by default for this
virtual COM connection. Physical RS-232C requires matching the instrument's
baud rate and hardware RTS/CTS, selected through constructor options.

Commands and replies are CR/LF-terminated ASCII (pp.7–8). Finite deadlines
bound replies, including fragmented responses. Unexpected buffered data is
treated as a transaction problem, not silently discarded. Numeric parsing
accepts finite decimal values without executing input. An error on a required
command, an unexpected/busy error, invalid acknowledgement, malformed required
measurement field, wrong block count or timeout aborts acquisition before
history changes. Documented nonbusy UCPR errors and optional metadata payload
failures retain explicit statuses with the completed reading, as described in
the [metadata reference](metadata.md#failures-and-persistence).

The main sequence is shown below. Backlight settings are read with `BALR`
and temporarily changed using `BALS` only when the during-measurement flag
was On; cleanup restores an actually changed pair. An already-Off flag sends
no redundant BALS during connection or cleanup.
Explicit manual acquisition also sets and restores speed mode.

```text
RMTS,1             enter remote mode; expect OK00
IDDR               identify product, variation and serial
MSWE,0             disable remote measurement button
DTCR               read optional factory calibration date/time once per connection
SCMR               read current synchronization mode/frequency
SPMR               read current speed/integration/ND configuration
OBSR               read current display observer
MEAS,1             start one acquisition
OK00,002           example reply: two seconds, not 0.002 seconds
OK00               second reply: measurement completed
MEDR,1,0,1         read 380–479 nm, 100 values
MEDR,1,0,2         read 480–579 nm, 100 values
MEDR,1,0,3         read 580–679 nm, 100 values
MEDR,1,0,4         read 680–780 nm, 101 values
MEDR,2,0,01        read CIE 1931 XYZ
MEDR,0,0,1         read the conditions of that acquisition
UCPR,2,cc          read name only for the actual user channel 01–10; skip 00
RMTS,0             exit remote mode after restoring settings
```

`MEAS` performs pre-measurement, reports a three-digit duration from 002 to
242 seconds, then sends a separate completion reply (p.41). This completes the
instrument's light measurement and automatic shutter-closed dark subtraction
(operating manual p.78); pre-measurement estimates duration and is distinct
from that dark phase. See [preparation and calibration](preparation.md).
Leading zeros
are integer padding. Pre-measurement takes about 1–10 seconds before the first
reply. That first reply has its own `PreMeasurementTimeout`, default/minimum
35 seconds, so it is not timed exactly at the upper end of the stated typical
interval. Completion has a deadline of the reported duration plus the response
allowance. Revision 7 recommends at least 10 seconds for ordinary replies,
20 seconds at 600 baud, and 35 seconds for `STDS`; it also expressly permits
35 seconds for other commands (p.8). The 35-second pre-measurement margin is
an implementation choice, not a special manufacturer minimum for `MEAS`.
The driver never starts an automatic replacement exposure; it could capture
a different stimulus.

The operating manual's p.78 describes a light measurement followed automatically
by a shutter-closed dark measurement of the same integration time. The instrument
subtracts dark internally before returning the completed result. That cycle is
distinct from pre-measurement; do not subtract a second dark reference or double
the protocol-announced duration. The [preparation guide](preparation.md) covers
the conditional 20-minute warm-up, optical setup and the complete measurement cycle.

Experienced users may query the connected object's public serial port when
no driver transaction is active:

```matlab
writeline(meter.serialPort, 'IDDR');
identityReply = readline(meter.serialPort);
```

Such direct use owns the complete command/reply exchange, including all
replies for multi-response commands. It must not overlap acquisition or leave
unread bytes. The next driver operation validates response boundaries.

## Slot 99 and persistent settings

Earlier code sent `STDS,99` on each measurement and used `STDR,99,...` to
read XYZ and spectrum, overwriting stored measurement 99. Direct `MEDR`
reads avoid this flash write when the current result remains available.

`MSWE,0` establishes the necessary condition: with the remote measurement
button disabled, data remain until the next acquisition. With it enabled,
reading all four spectral blocks **or** one colorimetric block clears the
result. English p.45 mistakenly says “disabled” in both cases; the flows on
pp.85–86 and the Japanese specification resolve the inconsistency. Explicit
button disablement lets spectrum, XYZ and conditions refer to the same
completed measurement.

Avoiding stored-reading writes does not eliminate settings persistence.
`RMTS,1` stores subsequent setting changes in flash (pp.8–9, 12–13), including
backlight and explicit manual-speed changes, even if later restored. Avoid
high-frequency reconnect or settings loops. `RMTS,2` suppresses many setting
writes only on firmware ≥3.00.9301; this driver does not assume that capability
without verified installed firmware.

The explicit [settings API](settings.md) reads the whole current configuration,
validates coupled targets and requested channel availability before any setter,
skips unchanged values and checks post-write readback. Its overrides persist
after disconnect and are not rolled back automatically. Failed receipts retain
partial reports and command replies; do not infer verification from an OK00
acknowledgement alone. Uncertain framing closes the connection under the same
no-unsafe-cleanup rules as acquisition.

`BALR` reports both ordinary and during-measurement backlight settings
(pp.63–64). Cleanup restores the recorded pair, rather than assuming
`BALS,1,0` turns everything on: it means on normally and off during
measurement. Initialization failure invokes cleanup. A fully framed instrument error or
host validation failure during acquisition preserves the connection when the
stream is synchronized, no measurement may still be active, and any temporary
manual-speed setting was restored. For example, `ER10` over-range can be
followed by another explicit acquisition after correcting the stimulus.
`ER00` is ambiguous: it denotes invalid command syntax but p.41 also says
any command other than `MEAS,0` during actual measurement returns `ER00`.
The driver therefore treats `ER00` from any command as uncertain and sends no
further speed, backlight or remote-mode commands before closing the port.
`ER02` from any command and `ER17` at measurement start likewise indicate
possible measurement activity and prevent subsequent commands. This includes
the optional metadata queries, where a busy reply must not trigger cleanup writes.
If remote mode remains after failed Connect or cleanup, an authorized operator
can press the physical ESC key **after confirming no measurement is active**
to cancel Remote Mode. While measuring, ESC instead interrupts/cancels that
measurement (Rev.7 §1.3.1, p.7). Check the display and settings before
reconnecting; quiet input alone does not establish idle state.
Page 42 lists
`ER17` for starting an already active measurement; p.45 explicitly defines
`MEDR`'s `ER02` as measurement in process. Other interpretations remain
command-specific: `MEDR`'s `ER17`, for example, is a parameter error rather
than a busy indication. A timeout, malformed frame, pending extra reply
or failed manual restoration also invokes cleanup. Cleanup attempts setting
restoration and remote-mode exit only when the stream is synchronized and no
measurement may still be active; otherwise it closes the owned port without
further commands. `cleanupStatus` records
`backlightRestored`, `speedRestored`, `remoteReleased`, `portClosed` and
diagnostic `details`; loss of communication can prevent instrument-side
restoration. An extra reply already buffered at the end of a transaction is
rejected; the driver cannot predict unsolicited bytes arriving in the future.

Default `Connect` does not discard unexpected input. After independently
establishing that the instrument is idle and the previous exchange is
abandoned, the caller may use:

```matlab
meter.Connect('DiscardPendingInput',true, ...
    'DrainQuietPeriod',0.25,'DrainTimeout',2);
```

Recovery is available only before opening a new session. It discards bytes
until the specified quiet interval, bounded by the total timeout and 65536
bytes, and then performs the usual remote-mode and identity handshake.
`recoveryStatus.discardedBytes` preserves discarded bytes;
`.quietObserved` records successful observation of that interval. Failure to
reach quiet closes the port without sending commands. Quiet is an observation
of host input, not proof of device idle, cancellation, backlight restoration
or remote release. Replies arriving after that interval remain a limitation.
This explicit path does not rely on platform-specific buffering on reopening
a `serialport` and is not an automatic retry. Tests model retained stale
bytes; actual OS-driver behavior after timeout remains unverified.

## Scientific meaning

| Data | Layout | Meaning |
| --- | --- | --- |
| `spectralData` | 401 × N | Instrument spectral radiance, 380:1:780 nm, W/(sr m² nm) |
| `XYZData` | 3 × N | Instrument CIE 1931 2° XYZ from `MEDR,2,0,01`, on the returned instrument scale |
| `wavelengths` | 401 × 1 | Fixed protocol grid, in nm |

The instrument manual's specifications establish spectral radiance and its
per-nm unit; CS-S10w's manual also describes ordered 401-sample spectral
files and spectral-radiance plot units. The English communication document
sometimes calls the data “spectral irradiance”; the measurement manuals and
instrument geometry establish spectral **radiance** for normal CS-2000 use.
Output spacing of 1 nm is not an assertion of 1 nm optical bandwidth.

Spectral replies have no wavelength header. Block numbers define the grid
and exact counts 100, 100, 100 and 101 (pp.43, 78). Validation checks each
count before concatenation, without interpolation, resampling or clipping.

XYZ comes from the instrument, not `spec2XYZ` or another host integration.
The [acquisition code](../../../src/+colormeasure/+drivers/+cs2000/CS2000.m) reads and validates the triplet directly:

```matlab
[payload,xyzRaw] = obj.request('MEDR,2,0,01');
XYZ = colormeasure.drivers.cs2000.numbers(payload,3).';
```

The numeric parser checks three finite values; the transpose stores them as
a column and performs no colour conversion.
Block `01` explicitly requests X/Y/Z; block `11` requests X10/Y10/Z10
(pp.43, 79). The display observer therefore does not change the requested
triplet. XYZ is not normalized to Y=1 or Y=100. User calibration, filter
compensation and geometry can affect its values; saved settings do not
independently verify physical accessories or calibration.

Y represents luminance. The instrument and CS-S10w support cd/m² and
foot-lambert display units. The sources inspected do not unambiguously
establish whether `MEDR` XYZ units are fixed or follow that selection, and
the driver has no verified unit query. It therefore retains the returned
scale without unit conversion. Check the actual instrument configuration and
manufacturer guidance before labeling absolute XYZ units; spectral-radiance
units are documented separately.

No host CCT, Duv or integrated total radiance is calculated. Subsequent
analysis must identify its own observer, integration/interpolation rules,
normalization, CCT/Duv method and applicability range. This avoids presenting
an unverified derived result as an instrument measurement.

Finite signed spectral bins and negative XYZ are retained. A negative bin
does not imply negative integrated XYZ. Zero and all-zero readings are also
retained, without inventing CCT for black. Nonfinite data or the documented
`-9.9999e9` calculation-error sentinel reject the whole transaction. Firmware
≤1.01.0000 can report calculation errors as zero (p.78), which is
indistinguishable from a genuine zero in that reply. Firmware confirmation
remains necessary; IDDR does not remove the ambiguity.

The eight condition fields are speed mode, sync mode, integration time in
microseconds, internal ND, close-up lens, external ND, angle and calibration
channel (p.44). External ND must not be omitted and shift the final fields.
Host integration-time metadata uses seconds and retains the original reply.

## Retention and persistence

`metadata(k)` contains `conditions`, `identity`, `acquisition` and the UUID
`readingId` for reading k. Raw replies are in `.acquisition`; `measurementConditions` describes the
latest acquisition or explicit `StoreMeasurementConditions()` query. That
query does not change the conditions retained in `metadata(k)`. `Erase` preserves
that separately queried snapshot, even when its values happen to equal the
last reading's conditions; `EraseAll` explicitly clears it. Spectrum, XYZ
and metadata are validated and
committed together. A failed transaction appends no placeholder or partial
history; acquisition arrays have protected setters.

`snapshot()` returns this complete native history as ordinary values without
opening a port, modifying history or saving. `Save` uses the same method, so
the shared-session adapter does not reconstruct protected provenance fields.
The adapter retains that native snapshot and the selected per-reading metadata
inside its batch record. Its row-oriented XYZ is only a shape conversion of
the instrument values. The [shared-session record reference](#shared-session-records) and
[file-format reference](#native-mat-batch-mat-and-csv) describe the retained
batch fields and native-to-batch differences.

`Save` writes one `measurements` struct with schema version 2,
`segmentId`, `spectralData`, `XYZData`, `wavelengths`, `metadata`, `identity`,
`measurementConditions` and the logical `measurementConditionsIndependent`
provenance flag. Per-reading conditions and any separately queried latest
conditions remain distinct. Each metadata entry retains its UUID `readingId`;
erasing or importing rows does not assign that acquisition a new identity.
`Load` requires the current schema and rejects repeated or already-retained
reading IDs before appending. Saving stages the complete MAT file before
publishing it and does not change warning state. An explicit `Save(fileName)`
replaces that selected file. Automatic Gonio saves refuse occupied destinations.

`snapshot()` exposes the same native structure directly:

```matlab
measurements = meter.snapshot();
```

The returned struct contains ordinary values. Reading or changing it cannot
mutate the driver's history or `isSaved`. Connection diagnostics such as
`cleanupStatus` remain separate. `Erase` and `EraseAll` maintain alignment;
`isSaved` becomes false on acquisition, conditions query, import or erasure and true
on successful Save. Automatic saving on deletion is opt-in.

`Load` appends the current native snapshot after validating spectrum/XYZ
alignment, finite values, wavelength grid and all metadata. It preserves
per-reading identities and the explicit latest-conditions provenance flag;
it does not replace the live connection's identity or open a port. The complete
native snapshot and its explicit provenance flag are required before history changes.
For offline analysis alone, use MATLAB `load` to read the value struct.

`colormeasure.drivers.cs2000.measureCS2000` exposes ordinary acquisition only through the shared window.
Manual and goniometer variants use separate APIs. Each batch reading owns a fresh
connection and retains its complete data before deletion; a restoration warning
does not erase a completed acquisition. The live view does not infer XYZ units
or recalculate XYZ from spectra. Comparison-only scale declarations are described in the batch/UI guide; they
do not change native readings or the firmware-query policy.

### Shared-session records

Each `session.measurements(k)` contains:

- `instrumentSettings`: automatic policy, staged overrides and application receipt,
  including before/after readback, commands, acknowledgements and status.

- `XYZ` (1×3), `deviceType`, `xyzMethod`, `xyzUnits` and `observerId` for the
  instrument-returned XYZ. The adapter does not recalculate XYZ, CCT or Duv.
- `lambda` and `spectralData` (401×1), `spectralQuantity='radiance'` and
  documented `spectralUnits='W/(sr m2 nm)'`. Signed finite values are retained;
  no clipping, normalization or wavelength resampling is applied.
- `instrumentMetadata`: the complete per-reading `conditions`, `identity` and
  `acquisition` structures. This retains actual geometry/integration settings,
  separate pre-exposure configuration, raw replies, metadata statuses,
  device-reported serial number and factory calibration time. Firmware remains
  empty; see [available metadata](metadata.md#firmware-temperature-and-sdk-limits).
- `driverSnapshot`: the complete native `snapshot()` with original 401×N and
  3×N shapes, metadata, identity, wavelength grid and independent-conditions
  flag. An ordinary shared-session connection contributes one reading.
- `cleanupStatus`, `warnings`, sample name/notes, port, host timestamps and
  MATLAB version. Snapshot and metadata are ordinary values, not live device handles.

### Native MAT, batch MAT and CSV

`meter.Save` writes one native `measurements` snapshot; `meter.snapshot()`
returns it without I/O or mutation. The shared session saves a reading array
and `batchInfo` instead. These shapes differ: native spectrum/XYZ histories
are column-oriented, while each batch reading contains one spectrum and one
XYZ row. Read either MAT file with MATLAB `load`; it does not connect a device
or change a live instrument history. `meter.Load` accepts only the native
snapshot, not a shared-session batch MAT.

Read a native file:

```matlab
native = load('native-reading.mat', 'measurements');
plot(native.measurements.wavelengths, native.measurements.spectralData);
```

Extract one reading's native snapshot from a batch into a file of its own:

```matlab
batch = load(session.files.mat, 'measurements', 'batchInfo');
measurements = batch.measurements(1).driverSnapshot;
save('batch-reading-1-native.mat', 'measurements');
```

The full batch MAT also retains UI names, timing and cleanup warnings that a
native snapshot alone does not contain. CSV is a long-format convenience
export, one row per wavelength per reading, with `Raw_X`, `Raw_Y`, `Raw_Z`,
source/unit fields and warning text. “Raw” means the retained record values;
synthetic rows are explicitly identified as generated. CSV does not replace
the MAT metadata/raw-response archive.

## Sources and attribution

Commit `6c463e5` records Mike's initial upload as “CS2000 code from Wyble.”
Tucker Downs integrated the device directory; Luke Hellwig added the example
and README. This update builds on their repository code and its existing
[license](../../../LICENSE.txt) and [contributor record](../../../OWNERS.txt), included
verbatim with this repository. Manufacturer sources guide protocol implementation; no vendor SDK
source or PDFs are redistributed in this directory.

See [automated tests](../../testing/cs2000.md) for regression coverage.

See the [quick start](../../beta-testing/README.md) for demo and device-test instructions.

# CR API and protocol reference

For the optional measurement window, add the repository `src` folder to the
MATLAB path and run:

```matlab
session = colormeasure.app('CR250'); % or 'CR100' / 'CR300'
```

See the [CR window guide](shared-ui.md) for that workflow. For direct acquisition,
start with the [measure/save/load example](README.md). This reference covers
`colormeasure.drivers.cr.CR100`, `colormeasure.drivers.cr.CR250` and `colormeasure.drivers.cr.CR300`, implemented by
[colormeasure.drivers.cr.Instrument](../../../src/+colormeasure/+drivers/+cr/Instrument.m). Host calculations use the bundled
[`colormeasure.colorimetry` library](../../colorimetry/README.md); their equations, units
and sources are in the [scientific guide](color-science.md).

## Models and operations

| Class | Acquired data | Host calculation |
| --- | --- | --- |
| `colormeasure.drivers.cr.CR100` | Instrument 2° XYZ and last-capture settings | CCT/Duv from instrument XYZ |
| `colormeasure.drivers.cr.CR250`, `colormeasure.drivers.cr.CR300` | Instrument XYZ, spectrum with its own wavelength header, radiometric values and last-capture settings including speed/CMF | CIE 1931 2° XYZ, band integral and CCT/Duv from the spectrum |

The two spectral models retain their exact model identity. The output grid
comes from each response; neither optical bandwidth nor the class name fixes
the number of samples. Related model names are not silently substituted.

| Call | Effect and return value |
| --- | --- |
| `meter = colormeasure.drivers.cr.CR100(portName, ...)`, `colormeasure.drivers.cr.CR250(...)`, `colormeasure.drivers.cr.CR300(...)` | Opens the selected port and checks model, serial number and firmware. Omitted/empty port selects exactly one available candidate; multiple candidates require an explicit name. Does not measure. Initialization failure closes the owned port. |
| `meter.Measure()` | Starts a blocking acquisition. Returns no value; appends one complete row on success and throws without appending on failure. Read the properties below for results. |
| `meter.readCapabilities()` | Reads device-configured choices and limits without acquiring. Returns controls, identity, UTC text timestamp and raw response records. |
| `meter.readSettings()` | Reads current `RS` setup separately from last-capture `RM` metadata. Includes read-only physical aperture and CR100 mode observations. |
| `meter.applySettings(changes)` | Applies only explicit supported changes, then verifies available readbacks. Returns a retained receipt. A failure after an attempted setter can leave partial changes and blocks acquisition until recovery; rejecting an invalid request before writes does not itself block acquisition. |
| `meter.applyAutomaticSettings(overrides)` | Selects CR100 Colorimeter mode and automatic range/exposure, or CR250/300 automatic exposure, then applies explicit overrides. Does not acquire or reset accessory/filter/correction selections. |
| `values = meter.snapshot()` | Returns an independent value struct containing the complete native history; no commands, file I/O or state changes. Works with empty history and after disconnect. |
| `meter.Save(fileName)` | Replaces the MAT file with a value struct named `measurements`, including all retained readings. The snapshot is staged in the destination folder before replacement. A staging failure leaves an existing file unchanged. Staging or replacement failures raise `CR:SaveFailed`; invalid filename arguments raise `CR:SavePath`. Staging reduces partial-write exposure but does not guarantee durability. `.mat` is added when the name has no extension. Does not create missing parent directories; works after disconnect. |
| `meter.Erase()` | Removes the last complete row; empty history is allowed. |
| `meter.EraseAll()` | Clears all readings while preserving the connection and identity. |
| `meter.Disconnect()` | Closes the owned port while preserving readable/savable history. Reconstruct an object to connect again. |
| `delete(meter)` | Closes the port and destroys the handle; save or copy results first. |
| `guide = colormeasure.drivers.cr.preparation(model)` | Returns concise model-specific operating guidance without connecting or acquiring. See [preparation](preparation.md). |
| `controls = colormeasure.drivers.cr.settingsControls(model)` | Returns operator help and a static, initially unavailable catalog without connecting. |
| `values = colormeasure.drivers.cr.measureToFile(model, portName, fileName, ...)` | Opens, measures, saves, closes and returns the saved struct. `model` is `"CR100"`, `"CR250"` or `"CR300"`. |

See [acquisition settings](settings.md) for dependencies, acknowledgement-only
values, automatic policy and failure receipts. Direct `Measure` and the short
example preserve current instrument settings; neither implicitly calls the
automatic-settings wrapper.

The short example accepts an empty port for automatic selection and forwards
`ResponseTimeout` and `MeasurementTimeout` name/value options. Omitted options
use driver defaults; invalid supplied values fail before any commands or saving.
For example, `colormeasure.drivers.cr.measureToFile("CR300", portName, fileName, 'MeasurementTimeout', 300)`
allows a longer host wait without changing the instrument exposure. Use the
class API for recovery options or repeated readings.
When an individual `Save` fails, the class still holds its readings; retry
Save with a writable filename instead of taking another exposure.

## Constructor options and mutable controls

Pass options as name/value pairs, for example:

```matlab
meter = colormeasure.drivers.cr.CR300(portName, 'ResponseTimeout', 10, 'MeasurementTimeout', 300);
```

| Option | Default | Meaning |
| --- | --- | --- |
| `ResponseTimeout` | 5 s | Finite positive deadline for each command write, ordinary replies and the declared spectrum lines after the header. |
| `MeasurementTimeout` | 120 s | Finite positive deadline for the `M` completion reply; allow for the selected exposure and averaging. |
| `DiscardPendingInput` | `false` | Explicitly abandon unread input before identification, only after the caller establishes that the old operation has ended. |
| `DrainQuietPeriod` | 0.25 s | Required period with no new input during an opted-in drain. Every new byte restarts it. |
| `DrainTimeout` | 2 s | Finite total drain deadline; must exceed `DrainQuietPeriod`. No identification command is sent if quiet is not reached. |

`meter.responseTimeout` and `meter.measurementTimeout` can be changed while
idle. Native connections require MATLAB R2026b or newer. Before every
command the driver sets `port.Timeout` to the current `responseTimeout` and
turns on [`EnableWriteTimeout`](https://www.mathworks.com/help/instrument/serialport.html).
The `M` write uses this ordinary write deadline, independently of its longer
measurement-completion wait. A write exception may leave a partial command;
the driver closes the port without retrying and retains earlier readings.
Establish instrument idle before reconstructing; closing the port does not
cancel an exposure. Injected transports must expose writable `Timeout` and
`EnableWriteTimeout` properties.

`meter.repeatOnError` defaults to false; setting it true permits up to
three **new exposures** for selected measurement errors. See the
[errors and recovery](#errors-and-recovery).
`meter.port` supports expert direct commands; the caller must consume every
reply before returning control to the driver. Software-test injection options
are documented under [test support interfaces](../../testing/cr.md#test-support-interfaces).

Host deadlines do not change instrument exposure or other measurement settings.
Result and metadata queries each have their own `ResponseTimeout`, so
`MeasurementTimeout` does not bound the complete `Measure` call. Choose it for
the configured exposure, averaging, speed and multiplier; the default is not a
guarantee for every configuration.

## Retained values

History properties have private setters. N is the successful reading count;
W is the sample count, which must remain constant until `EraseAll`. Equal-length
changed grids are retained on separate rows: use the corresponding `wl` row
when analyzing each spectrum. A changed sample count requires saving and clearing
the history before another reading. Spectra must meet the
[uniform-grid check](color-science.md#grid-validation).

| Property | Shape | Source and interpretation |
| --- | --- | --- |
| `XYZ` | N × 3 | Instrument XYZ for CR-100; host spectral integration for CR-250/300. Never normalized to Y=1 or Y=100. |
| `instrumentXYZ` | N × 3 | Original finite signed `RM XYZ` values, separate from host results. |
| `CCT`, `Duv` | N × 1 each | Host Ohno-method temperature in K and signed CIE 1960 UCS distance; NaN pair when unavailable. |
| `spectralData`, `wl` | N × W each | Original signed spectrum and wavelength in nm. No spectrum clipping or resampling. |
| `integratedSpectrum` | N × 1 | Host inclusive rectangle integral of the reported band. Quantity and conditional units are per-reading metadata. |
| `metadata` | N × 1 struct array | Per-reading identity, parsed capture settings, raw replies and availability statuses, capture attempts, host UTC timestamps, quantity information and original radiometric values. |
| `identity` | Scalar struct | Connected model, serial number, firmware, port and cited protocol version. |
| `recoveryStatus` | Scalar struct | Startup drain report: `attempted`, discarded `uint8` bytes in `discardedBytes`, `quietPeriod` and `timeout` in seconds, and `quietObserved`. An observed quiet interval does not establish that the instrument is idle. |

CR-100 has empty spectral properties and omits those fields from its saved
struct. `snapshot` retains schema version 2, a batch `segmentId`, identity, timeout/retry settings,
recovery status and the most recent `errorCode`; `Save` writes this same value
without the live port. Editing the returned struct does not change the driver's
history, including its nested metadata. Neither operation performs color
adaptation, reflectance calculations or new acquisition.

Each acquired row has a UUID `metadata(k).readingId` assigned once after the
complete reading is validated. Erasing other rows does not renumber that
identity. In `metadata(k)`, `xyzSource` identifies the calculation origin and
`cctSource` identifies the host CCT method. Spectral rows name
`colormeasure.colorimetry.spectra2XYZ`; CR-100 retains instrument XYZ as its source. All three
models name `colormeasure.colorimetry.XYZ2CCT` for CCT/Duv. See
[calculation provenance](metadata.md#calculation-provenance).

`radiometricType` and `radiometricQuantity` identify geometry;
`instrumentRadiometricValue` and `instrumentPhotonValue` retain both returned
numbers. `spectralDensityUnit` and `xyzUnit` are conditional on the inherited
per-nm assumption: both strings append `(provisional: assumes per nm)`, and
`spectralDensityUnitsConfirmed` is false. The instrument radiometric unit
remains separate and unchanged. Treat these provisional strings as display
labels. Select a quantity using `row.radiometricType` and separately check
`row.spectralDensityUnitsConfirmed` before making an absolute-unit claim. Raw
replies remain available alongside the parsed values. `acquiredAt` is a host
timestamp after reading XYZ; `settingsReadAt` is the host time after collecting last-capture
settings. Neither is an instrument-generated exposure timestamp.
`captureSettings.deviceTime` and its status preserve any timestamp actually
reported by `RM Time`, including an unavailable `NA` reply.

`metadata(k).identity` copies the verified connection identity, including the
device-reported serial number and exact firmware string. `captureSettings`
contains typed values, and `metadataResponses` retains each field's command,
value, unit, status, code and raw response. A missing value is not a zero
measurement. The [metadata reference](metadata.md) lists every queried field,
conditional command and unavailable-value behavior. See also
[quantity and unit definitions](color-science.md#quantities-and-units).

Metadata collection adds sequential read-command round trips. A framed
unsupported reply records an unavailable setting. A complete optional payload
that cannot be parsed records `unparsed`, the raw reply and an unavailable typed
value; the completed reading is retained. Missing replies or malformed framing
reject the new reading without a partial row or another exposure. See
[missing values and failures](metadata.md#missing-values-and-failures).

## Discovery and identification

MATLAB [`serialportlist("available")`](https://www.mathworks.com/help/matlab/ref/serialportlist.html)
returns available names, not instrument identities. Automatic selection uses
the same rule on Windows, macOS and Linux: exactly one available name, then
strict model verification through the existing framed command transport. It
does not infer a model from USB VID/PID values, filenames or enumeration order.
Exact macOS `/dev/tty.<name>` and `/dev/cu.<name>` aliases count as one endpoint;
the outgoing `cu.*` name is preferred when both are available. An explicit
name is preserved. Related or unsupported CR models remain rejected.
Multiple available ports stop before any candidate is opened; select one
explicitly rather than broadcasting CR commands to other laboratory devices.

Remote Communication v1.36 §§4.3.2.1, .2 and .12 documents `RC ID`, `RC Model`
and `RC Firmware` since firmware 1.04. Identification does not acquire or
change measurement settings. A failed identity check closes the connection
without acquiring. If a selected port becomes busy or disappears before opening,
the driver reports that error without switching to another candidate.

## Errors and recovery


A failed settings application can leave earlier changes applied. Inspect its
receipt rather than assuming rollback. A failed setter or readback blocks native
`Measure` until a later successful settings application or a newly constructed,
identified connection; recheck the setup before resuming. See
[settings receipts and recovery](settings.md#current-settings-capture-settings-and-receipts).

A failed acquisition raises an error and leaves every history unchanged. No
partial or placeholder row is appended. Wrap calls in `try/catch` if a sequence
should continue after a fully framed instrument error. A complete but invalid
required measurement payload, unsupported quantity code, changed history grid or calculation
overflow preserves the connection after checking that the exchange is fully
consumed. The failed reading is never appended. After a grid error, Save and
EraseAll allow acquisition on the same object with the new grid.

A timeout, malformed framing, inconsistent header, incomplete spectrum or
unexpected extra input closes the connection. First establish that the instrument
is idle and any outstanding measurement has finished. Then construct a new
meter. By default, unread input still raises `CR:PendingInput`. To explicitly
abandon an old response before fresh model/serial/firmware identification:

```matlab
% Only after independently confirming that the previous operation has ended:
meter = colormeasure.drivers.cr.CR250(portName, 'DiscardPendingInput', true, ...
    'DrainQuietPeriod', 0.25, 'DrainTimeout', 2);
meter.recoveryStatus.discardedBytes          % bytes explicitly abandoned
```

Draining waits for a quiet interval, restarts that interval on every byte and
has a finite total deadline. It sends no commands before that interval completes.
Silence does not prove that an exposure has ended, and later bytes can still
invalidate a new exchange. Draining is neither an instrument abort nor an
automatic retry. The manual reserves `MA` for future implementation; it is not
sent. An operating system may deliver buffered bytes after a quiet interval; a new
exchange must still pass the normal framing checks.

The default is one physical acquisition. To explicitly allow up to three new
captures for measurement errors -302 through -306:

```matlab
meter.repeatOnError = true;
meter.Measure();  % retries are new samples, not rereads; metadata records attempts
```

The attempt counter resets for each call. Transport failures, malformed data,
configuration errors and failed read commands are never retried. Final failure
throws without appending a row. In a measurement loop, retain failed request
indices and error messages separately; `size(meter.XYZ,1)` counts successful
readings. See the [original/current comparison](original-comparison.md) for
differences from the original driver's retry behavior.

For a recoverable, fully framed error, retained readings stay on the object.
If a save fails, call `meter.Save(newFileName)` again with a writable destination
without measuring again. Disconnect when finished. In custom functions, use the
function-scoped cleanup pattern in [measureToFile](../../../src/+colormeasure/+drivers/+cr/measureToFile.m); an
`onCleanup` variable in the Command Window does not run merely because a later
command throws.

## Direct serial commands

For direct commands on a connected meter, use the public serial port while
idle and consume the entire response before resuming driver calls:

```matlab
meter = colormeasure.drivers.cr.CR250(portName);
writeline(meter.port, 'RC Firmware');
firmwareReply = readline(meter.port);
meter.Disconnect();
```

A multiline command such as `RM Spectrum` requires reading the header and its
stated number of sample lines, then allowing 200 ms before another command.
Do not interleave direct commands with `Measure`. No direct settings command
is issued by direct `Measure`; the explicit settings APIs apply and record
requested changes. ECHO must be off; `E` toggles it in a manual terminal,
so only send it when its current state is known.

## Protocol and SDK sources

The implementation uses the [manufacturer's Remote Communication manual v1.36](https://www.colorimetryresearch.com/downloads)
(2018). The manual in the public Mac CRI installer 1.5.13 has SHA-256
`4aecfbdbb3a8f579b661c717ff61c7925a25093b30b5cc73327a6373c99bdd52`.
Sections 2.2 and 4.3 describe sequential ASCII commands, `OK`/`ER` status,
model identification, completed `M` measurements and header-counted spectra.
The receiver accepts CR, LF and CRLF, including a fragmented CRLF; commands
use CRLF. A 200 ms guard follows a spectrum (§4.3.1.37).

The inherited 115200 baud, 8 data bits, no parity, 1 stop bit and no-flow
settings are implementation assumptions: these serial parameters were not
found in the available manufacturer manuals. Confirm them on the target
firmware and connection. A completed error reply does not itself invalidate
framing; incomplete/uncertain exchanges close the port. The
[recovery instructions](#errors-and-recovery)
explain explicit draining and its limitations. `MA` is reserved for future
implementation in §4.3.4.3 and is not used as an abort command.

The
[CR-300 brochure](https://www.colorimetryresearch.com/static/files/products/colorimeters/CR300.pdf)
describes optical bandwidth and detector resolution, which do not establish
the command-output grid. Both spectral classes parse the returned grid.

This driver uses the ASCII protocol directly and does not load or redistribute
the [manufacturer's native SDK](https://www.colorimetryresearch.com/downloads).

Original driver contributors are credited in the source headers; adapted
library calculations, bundled data provenance and scientific references are in the
[scientific guide](color-science.md#implementation-provenance).
See also the repository [contributors](../../../OWNERS.txt) and
[license](../../../LICENSE.txt).

## Shared sessions and saved data

The [window guide](shared-ui.md) covers the model launchers. With `src` on the path, `session = colormeasure.drivers.cr.measureCR250` also opens the window
with custom connection options. The other model launchers are
`colormeasure.drivers.cr.measureCR100` and `colormeasure.drivers.cr.measureCR300`. They accept `ResponseTimeout` and
`MeasurementTimeout`, for example:

```matlab
session = colormeasure.drivers.cr.measureCR250('ResponseTimeout', 10, 'MeasurementTimeout', 180);
```

A model-specific launcher restores an active session only when it is called
with the same connection options. Changing those options, or omitting a retained batch's nondefault options, raises
`Measurement:SessionConfiguration`. **New batch** inherits them.
`colormeasure.app` restores a retained batch with its existing connection
options. A new batch for a model uses its defaults unless opened
through a model-specific launcher with explicit options. `session.show()` also
reopens the existing window. To change the deadlines, finish successfully and retain the
old batch before deleting its handle and relaunching:

```matlab
session.finish();
assert(session.finished && ~session.needsRecovery);
previousFiles = session.files;
previousReadings = session.measurements;
delete(session);
session = colormeasure.drivers.cr.measureCR250('ResponseTimeout', 10, 'MeasurementTimeout', 180);
```

These options change host waiting time, not the instrument's exposure settings.

For a command-only batch, keep `src` on the path and run:

```matlab
destination = uigetdir('', 'Choose a measurement folder');
if isequal(destination, 0), return; end
a = colormeasure.drivers.cr.adapter('CR250', 'ResponseTimeout', 5, 'MeasurementTimeout', 120);
session = colormeasure.session.Session(a, destination); % lists ports; does not measure
session.measure('Sample 001', 'Position A');   % starts one reading
session.finish();
```

`colormeasure.drivers.cr.adapter` preserves current acquisition settings. `colormeasure.drivers.cr.uiAdapter` applies
the window's automatic recipe and supplies its plots. Every session acquisition
opens a fresh native driver and releases it after success or failure, including
a framed error that a directly held driver could recover from without
reconnecting. Sessions do not automatically retry, switch ports or discard
pending input. Native `repeatOnError` stays false.

The session MAT contains a `measurements` struct array and batch context. Its
per-reading fields include:

| Field | Meaning |
| --- | --- |
| `XYZ`, `instrumentXYZ` | Separate `1×3` values. CR-100 primary XYZ is instrument-reported; CR-250/300 primary XYZ is the driver's host spectral calculation. |
| `xyzMethod`, `xyzUnits`, `observerId` | Producer, declared scale/unit convention and CIE 1931 2-degree observer identifier. |
| `lambda`, `spectralData` | Column views of the original grid/samples; empty for CR-100. No resampling, clipping or normalization. |
| `spectralQuantity`, `spectralUnits`, `spectralUnitsConfirmed` | Accessory-dependent quantity and explicitly provisional per-nm units for real spectra. |
| `CCT`, `Duv`, `cctSource` | Unchanged driver calculation, kelvin and signed CIE 1960 UCS distance; unavailable values stay NaN. |
| `instrumentSettings` | Automatic policy, staged overrides, before/after setup, commands, acknowledgements and application status. This is separate from the actual capture metadata. |
| `instrumentMetadata` | Complete last-reading metadata: identity, capture settings, availability statuses, original command replies, spectrum header/lines and driver timestamps. |
| `driverSnapshot` | Complete native value snapshot, with original array shapes, metadata, identity and configuration. No live handle. |
| `name`, `notes`, timing and port fields | Shared-session context; driver timestamps remain separately retained in metadata. |


The complete native `meter.snapshot()` is embedded in `driverSnapshot`; no live
handle is saved. Native `meter.Save(file)` writes one snapshot containing arrays
of all retained readings. The session MAT instead contains one adapter struct
per reading, including that reading's native snapshot.

CSV is a flattened export with one row per spectral sample and repeated XYZ,
units and context. CR-100 produces one row per reading with `HasSpectrum=false`
and unavailable wavelength/spectral values. See the [shared saved-data guide](../../session/README.md)
for batch fields and export controls.

Comparison eligibility uses source, quantity and unit conventions. Live CR-100
has no automatic absolute XYZ-scale key. A same-scale operator declaration can
be offered only when model, device-reported identity, accessory/filter/aperture
and relevant parsed calibration metadata agree for the selected readings and
white. Missing, unavailable or unparsed required metadata prevents that option.
Automatic-exposure differences alone do not prevent it. The declaration does
not establish absolute units, change measurements or substitute another XYZ
producer. Synthetic readings remain separate from physical readings.

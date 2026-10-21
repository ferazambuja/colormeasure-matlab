# CS-2000 measurement window

The window acquires spectra and instrument-calculated XYZ with
`colormeasure.drivers.cs2000.CS2000`. It provides the ordinary acquisition
workflow; manual and goniometer variants use separate APIs.

Open [openColorMeasure.m](../../../openColorMeasure.m) in MATLAB, click **Run**
and choose **CS-2000**. For scripted launch options, add **src** to the path and
use `session = colormeasure.drivers.cs2000.measureCS2000(...)`.
The window requires MATLAB R2026b or newer. The shared [window guide](../../ui/README.md)
covers choosing a destination, naming samples, starting each measurement,
inspecting results and finishing the batch. It also explains closing/restoring
the window and recovering a failed save. The [session API](../../session/README.md#session-api)
provides command-line access to the same batch.

## Preparation and automatic settings

Follow the [preparation guide](preparation.md) for warm-up and stable target
geometry. Preparation help appears before the first live measurement attempt
and is available through **Settings... → Instrument help**. Reconnecting the
serial port does not restart instrument warm-up. The recorded XYZ scale does
not establish cd/m², so the window cannot classify a reading against the
manual's low-luminance thresholds.

Each **Measure** connects, verifies identity and applies **Multi-Normal with a
1-second multi interval, internal ND Auto and No Sync**, followed by any staged
overrides. It completes the light/dark measurement cycle, retrieves the spectrum
and XYZ, then disconnects. Accessory and calibration-channel selections remain
unchanged unless overridden. This differs from native `Connect`/`Measure`,
which preserve the current acquisition settings, including manual integration.
The requested XYZ observer is always CIE 1931 2-degree.

The window's comparison white is an analysis reference; it does not replace
instrument calibration or a reference-plate measurement for object color.

## Connection options and side effects

`colormeasure.drivers.cs2000.measureCS2000` accepts `BaudRate`, `FlowControl`, `ResponseTimeout`,
`PreMeasurementTimeout` and `ExpectedModel`; see the
[connection options](protocol-and-data.md#connection-options) for their defaults.
For example, a physical RS-232C connection configured for 9600 baud and hardware
flow control uses:

```matlab
session = colormeasure.drivers.cs2000.measureCS2000('BaudRate',9600,'FlowControl','hardware');
```

Relaunching an existing session with different options is rejected; a finished
session also retains its configuration. To change options, first finish
successfully, verify saving and retain the existing data/paths, then explicitly
delete that finished handle and relaunch:

```matlab
session.finish();
assert(session.finished && ~session.needsRecovery);
previousFiles = session.files;
previousReadings = session.measurements;
delete(session);
session = colormeasure.drivers.cs2000.measureCS2000('BaudRate',9600,'FlowControl','hardware');
```

**New batch** inherits the current options and therefore is not a way to change
serial configuration.
`colormeasure.app` restores an existing compatible CS session with its retained
options. Defaults apply when it creates a new session. You can also restore the
window with `session.show()` or call
`colormeasure.drivers.cs2000.measureCS2000` with the same options.

Every connection enters remote mode, disables the measurement button and
temporarily disables the measurement backlight when it is not already off.
The UI sends only required setting changes; it does not change the display
observer or write slot 99. Cleanup restores the backlight when communication
permits. If an uncertain stop prevents that, the next connection to the same
instrument through the same adapter restores the original during-measurement
setting at cleanup. Direct driver callers must share the `UnrestoredBacklight`
map with the next driver. A fresh adapter or MATLAB restart loses that recovery
state; restore the during-measurement backlight at the instrument when the state
is unavailable. Acquisition-setting changes persist in the instrument after disconnect;
they are not rolled back by cleanup. A complete acquisition remains retained
if restoration is unverified; its `cleanupStatus` and `warnings` describe the problem. Inspect the device
before another attempt. Do not use retries to clear remote mode, drain delayed
responses automatically or treat a quiet buffer as proof that measurement ended.
See [recovery and cleanup](protocol-and-data.md#slot-99-and-persistent-settings)
for error-specific handling.

## Measurement settings

Ordinary **Measure** uses the automatic recipe above. Choose **Settings...** to
open **Measurement settings** for a specific experimental need. Opening
the dialog and editing a draft do not connect or write settings.

1. **Read settings** connects, identifies the device and reads current setup,
   including its physical aperture. It uses the normal connection/cleanup behavior
   described above, without an exposure.
2. Choose overrides and read the help beside each control. Manual exposure needs
   an explicit time and internal ND Off or On. Internal synchronization needs the
   source frequency. These values can be staged together. Multi modes are useful
   for periodic light with an unknown or unstable frequency. A close-up lens and
   an external ND filter cannot be combined.
3. **Use for next readings** stages the complete draft. The next **Measure** validates
   the combination, skips unchanged settings and verifies the result before
   acquisition. A failed or partial application stops the reading and retains
   its receipt; inspect the reported state before trying again.

The current setup and settings recorded with a selected reading are shown
separately. To remove overrides, clear them in the draft and choose **Use for
next readings**. Speed/time/ND/synchronization then return to the automatic
recipe on the next reading. Removing an accessory or calibration override leaves
its device state unchanged. Port changes invalidate current
readback. Physical aperture is displayed; use the instrument's selector to change it.

Settings applied under the supported remote mode persist in device memory. The
driver writes only changed values. See the [settings reference](settings.md)
for native APIs, control meanings, firmware-layout restrictions and manufacturer
sources. The button displays **Settings (n)** when overrides are staged. Preparation
guidance is under **Settings... → Instrument help**. For object color, open
**Color → View → Reflectance / relight**.

## Data, metadata and scientific interpretation

Each batch record retains the spectrum, instrument XYZ, sample details,
capture settings, metadata and the complete native driver snapshot. The
[batch record reference](protocol-and-data.md#shared-session-records) lists the
fields, array shapes and provenance.

Spectral units are documented separately from XYZ units. The verified protocol
does not establish whether raw XYZ follows the instrument's selectable unit
setting, and no retained unit readback proves that separate connections share
an unchanged scale. Live XYZ therefore uses the label
`instrument scale (absolute unit not established)` and has no automatic XYZ
comparison key. Known-observer chromaticity and fixed-unit spectral comparisons
are separate capabilities; they do not certify an absolute XYZ scale.

The comparison workflow can accept an explicit operator declaration that the
selected live pair and white use the same XYZ scale. Eligibility requires
consistent model/variation/serial, observer/source, lens/external-filter/angle
and calibration-channel metadata. Unknown or contradictory required fields
cannot be overridden; unavailable user-calibration names also withhold this
eligibility. Automatic exposure, internal ND and display-observer changes do
not themselves change the requested XYZ convention. The declaration belongs
only to the comparison result; it does not relabel raw XYZ, set verified units
or alter any saved measurement. A common positive scale cancels in sample-to-
white ratios for Lab; unequal scales do not. Consult the shared
[scientific reference](../../session/color-science.md)
for derived comparison methods and validity guards.

## Native MAT, batch MAT and CSV

`meter.Save` writes one native `measurements` value struct;
`meter.snapshot()` returns it without I/O or mutation. The shared session
saves a reading array and `batchInfo` instead. Read either file with MATLAB
`load`; native histories and shared-session reading arrays have different
shapes, described in the [data reference](protocol-and-data.md#native-mat-batch-mat-and-csv).

The complete batch MAT retains every reading and its metadata; CSV provides
one row per wavelength for exchange with other tools. See the
[file-format reference](protocol-and-data.md#native-mat-batch-mat-and-csv) for
fields and an example of extracting one native snapshot from a batch.

## Demonstration without an instrument

See the [quick start](../../beta-testing/README.md) to try the demo or
share device-test feedback.

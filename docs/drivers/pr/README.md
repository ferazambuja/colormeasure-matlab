# PR-655 measurements in MATLAB

For the app, open [openColorMeasure.m](../../../openColorMeasure.m) in MATLAB
**R2026b or newer**, click **Run** and choose **PR-655**. Follow the
[measurement-window guide](../../ui/README.md).
The steps below collect and save a batch from MATLAB commands.

- [Setup](#setup)
- [Collect a batch](#collect-a-batch)
- [Acquisition settings](#acquisition-settings)
- [Driver API and direct examples](api.md)
- [Troubleshooting](#troubleshooting)

## Setup

Use MATLAB R2026b or newer, with the meter recognized as a serial port. Open
the project root as Current Folder and add its runtime source folder once:

```matlab
addpath(fullfile(pwd, 'src'));
```

Keep the complete repository together, including `resources/colorimetry`.

Power on the PR-655, connect its USB cable, and wait for startup. Aim and focus
the meter at the target. Close other programs connected to it. Direct commands
and the core session below use the instrument's existing [settings](#acquisition-settings).

## Collect a batch

Choose a destination outside the code folder and create a session. This returns
immediately, without measuring or opening a window:

```matlab
destination = uigetdir(pwd, 'Choose where to save measurements');
if isequal(destination, 0), return; end
session = colormeasure.session.Session(colormeasure.drivers.pr.adapter(), destination);
```

A single available port is selected automatically. If several are available,
inspect `session.ports` and select the meter's identified port:

```matlab
session.ports
% session.selectPort('COM3');                 % Windows example
% session.selectPort('/dev/cu.usbmodem101');   % macOS example
```

Position the sample before each call. A successful reading advances the default
name to Sample 002, Sample 003, and so on. Names and notes can be supplied for
individual samples:

```matlab
session.measure('Sample 001', 'Reference tile, first position');
```

After positioning the next sample:

```matlab
session.measure();
measurements = session.measurements;  % Complete ordinary structs
xyz = vertcat(measurements.XYZ);
colormeasure.drivers.pr.plotBatch(measurements);        % Optional plot of the collected spectra
```

Each successful acquisition releases the connection and updates the same batch
MAT file in a new, automatically named subfolder. Finish the batch to finalize
that MAT and write the supporting CSV:

```matlab
session.finish();
session.files
```

The MAT holds every spectrum, XYZ, name, note and timestamp together. The CSV
provides one row per wavelength, including an explicit `IsSynthetic` flag,
for exchange with other tools. Start another
batch by constructing another session. Keep `session` available while collecting
so subsequent commands use the same batch. See the
[session API](../../session/README.md) for saving, timing and recovery.

### Load the saved batch

```matlab
saved = load(session.files.mat);
measurements = saved.measurements;
plot(measurements(1).lambda, measurements(1).radiance);
```

`colormeasure.drivers.pr.exportPR655Csv(session.files.mat)` exports a saved session separately when needed.
See the [export reference](api.md#export-a-saved-session-to-csv) for options
and the [session reference](../../session/README.md#save-recovery)
for save recovery.

## Acquisition settings

Command-line sessions use the instrument's existing exposure, averaging and
synchronization settings. Check them on the meter before measuring; accessory
selection must match the fitted optics.

The measurement window selects adaptive exposure, one cycle and automatic
synchronization before each reading. Its **Settings...** panel provides overrides.
For deliberate changes in a custom script, see the [settings reference](settings.md).

## Direct driver examples

The [driver reference](api.md) describes direct instrument commands,
returned fields and connection options. The [Live Editor example](../../../examples/pr/PR655_measurements.mlx)
walks through individual readings and saving.

For a single reading with a plot, add the examples folder explicitly:

```matlab
addpath(fullfile(colormeasure.root(), 'examples', 'pr'));
reading = measurePRExample();
```

This starts immediately, returns the reading and disconnects. It does not save;
use the batch workflow above for automatic saving.

## Troubleshooting

### Port diagnostics

In the **MATLAB Command Window**:

```matlab
serialportlist('all')       % Detected serial ports
serialportlist('available') % Ports currently available to open
```

These commands do not open a connection. A port present in `all` but missing
from `available` may be in use. Close the other program's connection. For a
custom script, finish the measurement and call `delete(pr)`.

Compare the list before and after connecting the USB cable to identify the
meter. Release any connection before unplugging and allow time for the port to
appear after reconnecting. Run `session.refreshPorts()` and select the identified port with
`session.selectPort(port)`. If several names change, do not assume the first is correct.

**Windows:** If MATLAB detects the meter, no manual driver setup is needed. If
the COM port is missing after power and cable checks, the
[official product page](https://novanta.com/precision-medicine/product/photo-research-pr-655/#tab-documents-downloads-2)
lists **Photo Research Installer for USB Driver** under **Documents & Downloads**.

**macOS:** In **Terminal**, list USB modem ports:

```sh
find /dev -maxdepth 1 -name 'cu.usbmodem*' -print
```

A typical name is `/dev/cu.usbmodem101`; the suffix varies. To include other
serial adapters and inspect USB devices:

```sh
find /dev -maxdepth 1 -name 'cu.*' -print
ioreg -p IOUSB -w 0
```

Compare before and after connecting. If a USB entry appears without a serial
port, retain both outputs when asking for driver help. If neither changes,
check power, cable, and the USB connection. For a busy port, replace this example
with its actual name and close the listed program's connection:

```sh
lsof /dev/cu.usbmodem101
```

### Connection and measurement errors

| Message or symptom | Action |
| --- | --- |
| `colormeasure.drivers.pr.PR655`, `colormeasure.colorimetry.spectra2XYZ`, or CIE observer data is missing in a custom script | Add `src` as shown in [driver setup](api.md#direct-acquisition) and retain `resources/colorimetry`. |
| `serialport` is undefined | Update MATLAB to a current release. |
| No port, busy port, or ambiguous port | Follow [port diagnostics](#port-diagnostics); select the identified port or pass it to `colormeasure.drivers.pr.PR655`. |
| Cannot open the port, `PR655:RemoteMode`, or initialization timeout | Check the port, completed startup, cable, and other connections. For RS232, check the [serial settings](api.md#connection-options). |
| `PR655:UnsupportedModel` | Confirm the selected port belongs to the meter. PR-650 is not supported. |
| `PR655:InstrumentError` | Retain the numeric code. Codes -3, -9 and -10 concern synchronization; follow [synchronization errors](settings.md#synchronization-errors). Code -8 means insufficient signal. |
| `PR655:Timeout` while measuring | Wait for the meter to finish and check exposure/sync settings. Custom scripts can increase `Timeout`. |
| `PR655:ReconnectRequired`, `Framing`, `InvalidResponse`, `InvalidSpectrum`, or `WavelengthGrid` | Wait for the meter to finish, release the connection, and reconnect. Retain the full error for diagnosis. |
| `PR655:BacklightRestore` | Check the screen and restore its brightness manually if needed; reconnect before another request. |

The session releases its connection after a failed reading. Correct the setup,
wait for the meter to finish, and call `session.measure()` to retry the pending sample.
Custom scripts must call `delete(pr)` and create a new connection after an
incomplete or malformed exchange. Include the full error, model, MATLAB
version, operating system, and connection type when asking for help.

For saving problems, see [session recovery](../../session/README.md#save-recovery).
The window updates plots automatically. Command-only sessions can plot explicitly
with `colormeasure.drivers.pr.plotBatch(session.measurements)`.

### After updating MATLAB code

If a launcher reports `Measurement:SessionCompatibility` or a missing Session
property, an older class may still be loaded. Finish and save any active batch,
then restart MATLAB with the intended installation on the path. See the
[session update guide](../../session/README.md#troubleshooting-after-an-update)
if the active session cannot finish normally.

## References

- [Color-science guide](../../session/color-science.md): implementation
  excerpts and primary CIE and BIPM references for acquired XYZ, units and spectral totals.
- Photo Research, *PR-655/PR-670 User Manual*, Rev. B (2009-07-29): printed pages 31–35 (setup),
  102–111 (remote control), 113 (unit codes), 116 (spectrum), 118 (model and sync), 122 (errors),
  and 126 (PR-655 specifications).
- [Psychtoolbox instrument routines](https://github.com/Psychtoolbox-3/Psychtoolbox-3/tree/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/PsychHardware/PR670Toolbox).
- MATLAB [`serialportlist`](https://www.mathworks.com/help/matlab/ref/serialportlist.html).

## Further information

To try the demo or share device-test feedback, use the
[quick start](../../beta-testing/README.md).

PR-670 support is tentative.

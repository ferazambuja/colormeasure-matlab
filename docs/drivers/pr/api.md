# PR-655 driver API

For a graphical workflow in MATLAB R2026b or newer, add the repository `src`
folder to the path and run `session = colormeasure.app('PR655')`. Follow
the [measurement-window guide](../../ui/README.md).
For a first command-line batch, see the [measurement guide](README.md).

The `colormeasure.drivers.pr.PR655` class owns the instrument connection. Its `measure` method
returns one reading and retains history in the object. Plotting and file saving
are caller operations. Named batches and automatic saving belong to the
[shared session API](../../session/README.md).

## Methods

| Call | Result |
| --- | --- |
| `pr = colormeasure.drivers.pr.PR655(portName, ...)` | Opens the port and verifies the model. Omit the port for single-candidate selection. |
| `reading = pr.measure()` | Starts one acquisition, returns a struct, and appends successful data to history. Preserves existing acquisition settings. |
| `report = pr.readSettings()` | Reads settings and capabilities without measuring. |
| `receipt = pr.applySettings(overrides)` | Applies supplied settings and checks readback; inspect the receipt before acquisition. |
| `receipt = pr.applyAutomaticSettings(overrides)` | Applies adaptive exposure, one cycle and automatic synchronization plus overrides. |
| `pr.getFlicker()` | Queries D14 Auto Sync frequency into `pr.flicker`; other synchronization modes yield NaN. |
| `delete(pr)` | Releases the connection and destroys the object; retain returned readings first. |

The [settings reference](settings.md) defines supported values, coupled settings,
application receipts and error handling.

## Direct acquisition

The driver also supports direct instrument commands without a batch session.
Add the repository's `src` folder to the MATLAB path:

```matlab
projectFolder = 'C:\path\to\measurement-project';
% projectFolder = '/path/to/measurement-project'; % macOS or Linux
addpath(fullfile(projectFolder, 'src'));
```

Run these sections individually. Each `pr.measure()` starts a reading
immediately; position the sample before running it. Capture the returned struct
from the first reading so the collection survives releasing or reconnecting the
instrument.

```matlab
pr = colormeasure.drivers.pr.PR655();                       % Automatic port selection
% pr = colormeasure.drivers.pr.PR655('COM3');                % Explicit Windows port
% pr = colormeasure.drivers.pr.PR655('/dev/cu.usbmodem101');  % Explicit macOS port
measurements = struct([]);
```

Repeat this section after positioning each sample:

```matlab
try
    reading = pr.measure();
    if isempty(measurements)
        measurements = reading;
    else
        measurements(end+1) = reading;
    end
catch err
    delete(pr);                     % Earlier structs stay in measurements
    rethrow(err);
end
```

The original history access remains available while connected: `pr.wl`,
`pr.radiance` (one spectrum per column), and `pr.XYZ` (one row per reading).
When finished, release the connection and save the ordinary struct collection:

```matlab
delete(pr);                         % The measurements variable remains valid
[file, folder] = uiputfile('*.mat', 'Save manual measurements', 'manual_measurements.mat');
if ~isequal(file, 0)
    save(fullfile(folder, file), 'measurements');
end
```

Cancel leaves the collection unsaved in the workspace. Save it before closing
MATLAB. After a failed reading, retain `measurements` and reconnect before retrying;
only successful readings are appended.
For autosaving after every reading, use the batch workflow in the measurement guide.

Plot from the retained structs at any time, including after disconnecting:

```matlab
figure; hold on
for index = 1:numel(measurements)
    reading = measurements(index);
    plot(reading.lambda, reading.radiance);
end
hold off
disp(vertcat(measurements.XYZ));
```


## Connection options

The session lists available serial ports, including serial adapters.
Availability is checked again before each reading. The driver verifies the
remote-mode reply and instrument model after connecting.

For `colormeasure.drivers.pr.PR655()` and `measurePRExample()`, automatic selection requires exactly one
available port. This includes Windows COM ports, macOS serial adapters, and Linux
`ttyACM`/`ttyUSB` ports. On macOS, an available `cu` alias is preferred over its
matching `tty` alias; a `tty`-only port remains a candidate. Multiple candidates
are listed in the error message and require an explicit choice. The driver does
not try each device in turn. A single port is only a candidate: the remote-mode
and model checks must still succeed before measurements are possible.

An explicit port bypasses discovery. `pr.portName` and `pr.deviceType` report the
selected connection and verified model. Automatic discovery uses MATLAB's
[`serialportlist('available')`](https://www.mathworks.com/help/matlab/ref/serialportlist.html).

Serial settings are **115200 baud, 8 data bits, no parity, 1 stop bit, no flow
control**. For physical RS232, the meter's settings must match.

Each raw reply line is limited to **4096 bytes before CR/LF** as an implementation
resource policy. This is not a manufacturer's maximum. Reads are bounded before
allocation; exceeding the limit raises `PR655:Framing` and requires reconnecting.
The limit applies separately to the header and each wavelength row, so a complete
valid spectrum may exceed 4096 bytes in total.

The default spectral-response timeout is **300 seconds**. Custom scripts can
change it when connecting:

```matlab
pr = colormeasure.drivers.pr.PR655('COM3', 'Timeout', 600);
```

Remote-mode initialization allows up to 10 seconds and other short control
replies up to 5 seconds, capped by `Timeout`. Each character write also has a
`min(5, Timeout)` second deadline. Character pacing and separate response waits
add time; this is not one deadline for the complete acquisition.
R2026b's [`EnableWriteTimeout`](https://www.mathworks.com/help/instrument/serialport.html)
is enabled before any command. A write exception can mean a partial command was
transmitted: the driver stops sending, retains earlier readings, requires a new
connection and sends neither backlight restoration nor `Q` on that connection.
Establish instrument idle before reconnecting; this does not cancel an exposure
or prove that remote mode was released. There is no automatic write retry.
Otherwise acquisition turns the backlight off and attempts to restore it to
100% afterward. Injected transports must expose writable `Timeout` and
`EnableWriteTimeout` properties.

`'Clock'` substitutes the wall clock behind those deadlines and the driver's
pacing (10 ms reply polls, 50 ms per command character, 0.5 s after leaving
remote mode) with an object exposing `now()` and `sleep(seconds)`. It exists
for deterministic software tests and changes no interval; leave it unset for
an instrument.

## Spectral data and units

The PR-655 returns **101 samples from 380 to 780 nm, every 4 nm**. The 4 nm value
is the sample spacing, not the optical bandwidth. Wavelengths are retained
without resampling.

| Field in one reading | Meaning |
| --- | --- |
| `lambda` / `radiance` | Column vectors of wavelengths in nm and unscaled spectral values from the meter |
| `xyzMethod` | Host calculation and observer identifier, also retained by direct driver calls |
| `XYZ` | One row of CIE 1931 2-degree XYZ calculated from the spectrum by `colormeasure.colorimetry.spectra2XYZ` |
| `totalRadiance` | Sum of spectral values multiplied by the wavelength step |
| `deviceType` / `unitsCode` | Reported model and raw M5 units code |
| `isSynthetic` | Logical generated-data flag: true for demo readings, false for parsed driver readings; not a physical-validation or calibration claim |
| `peakWavelength` | Header peak wavelength; the instrument may report zero |
| `instrumentTotalRadiance` / `integratedPhotonRadiance` | Integrated radiometric and photon values from the header |
| `instrumentMetadata` | Optional identity/setup reports and query status; fields remain unavailable and `notQueried` by default |

The session adapter adds `spectralUnits`; the session adds names, notes, port,
and timing; see
[saved data](../../session/README.md#saved-data).

The interface labels values as **instrument units**. The manual's Table 9 lists
quantity codes, but its M5 example uses `0`, which that table does not define.
The raw code is retained without assigning an unverified physical unit. Matching documented radiometric codes
permit same-convention magnitude and spectral comparisons. Undefined codes,
including `0`, do not establish a common XYZ or spectral scale. Recognized
chromaticity and the acquired readings remain available. See the
[comparison policy and sources](../../session/color-science.md#units-and-totals). Negative
finite spectral bins are retained; they do not necessarily produce negative
integrated XYZ. Negative integrated XYZ also remains in the saved record; interpretation and downstream analysis require appropriate input checks.

For spectral radiance in W/(m²·sr·nm), the compatibility-preserving `colormeasure.colorimetry.spectra2XYZ` calculation gives
Y a nominal cd/m² scale and `totalRadiance` is in W/(m²·sr). The inherited XYZ
scale has a small air/vacuum wavelength discrepancy, documented with its
[implementation and photometric reference](../../session/color-science.md#pr-spectrum-integration-and-provenance).
The driver preserves the units code and does not
convert other quantities into radiance. An illuminance/irradiance accessory
therefore does not make Y a luminance value.

The direct driver's history uses `pr.wl` for wavelengths, one spectrum per
column in `pr.radiance`, one XYZ row per reading in `pr.XYZ`, and a row vector
in `pr.totalRadiance`. Failed readings do not add partial data.
`pr.getFlicker()` stores the D14 Auto Sync frequency in `pr.flicker`, in Hz;
other sync modes produce NaN. It does not acquire a flicker waveform.

## Device-reported metadata

Additional post-measurement metadata queries are **disabled** in sessions and
the measurement window, which have no option to enable them. A direct
connection can request them explicitly when these reports are needed:

```matlab
pr = colormeasure.drivers.pr.PR655('', 'Metadata', true); % Connect only; does not measure
% Use an identified port instead of '' when automatic selection is ambiguous.
```

Position the sample before calling `pr.measure()`, and retain its returned struct
as in the manual workflow above. After the complete spectrum, the driver requests
serial number (`D110`), software version (`D114`), current setup (`D602`), last
exposure/gain (`D13`) and synchronization (`D14`). Identity is cached within one
connection; settings are refreshed after each reading.

The nested `instrumentMetadata` struct and aligned `pr.instrumentMetadata`
history are retained whether capture is enabled or disabled. With capture off,
values are unavailable and query records have status `notQueried`; model and M5
header values are still acquired normally. Explicit `pr.getFlicker()` remains
available and requests `D14` independently of this option.

These reports are separate replies, not an atomic capture-time settings record.
In Adaptive mode, D602's exposure is zero; `lastMeasurementExposure.exposureMilliseconds`
is the separate reported last exposure. Each reply has a receive deadline of
`min(5, pr.Timeout)` seconds; character pacing and cleanup add time.

Unsupported replies retain unavailable values plus their raw reply/status.
A timeout or malformed reply preserves the completed spectrum, **skips the
remaining metadata queries**, and requires reconnection before another direct
reading. Backlight restoration is attempted separately. No firmware version or
physical unit is inferred from missing metadata. See
Photo Research, *PR-655/PR-670 User Manual*, Rev. B (2009-07-29), printed pp.118–121.

## Reading and batch formats

| Operation | Direct `pr.measure()` records | `session.measurements` records |
| --- | --- | --- |
| Save/load a MAT | Manual `save`; retains the fields present | Complete batch MAT is autosaved with `batchInfo` |
| `colormeasure.drivers.pr.exportPR655Csv` | Not directly: names, timing and adapter metadata are missing | Supported from the saved session MAT |
| Pair comparison | Recognized chromaticity only; magnitude-unit declarations are missing | Each metric requires its matching domain declarations; Lab/ΔE00 also requires a common white |

Direct readings contain the spectrum, computed XYZ, its `xyzMethod` description
and instrument header values. The adapter/session adds units text, sample
name/notes, connection and acquisition timing. Retain the original records;
do not invent missing metadata to make them pass an export or analysis check.
For diagnostic logs and manually recorded setup information, see
[diagnostics and provenance](../../session/README.md#diagnostics-and-provenance).

## Examples

[PR655_measurements.mlx](../../../examples/pr/PR655_measurements.mlx) provides a section-by-section
Live Editor example for direct measurements and optional saving.

`measurePRExample` takes one reading, displays its XYZ and spectrum, and returns
the reading. It disconnects when finished and does not save a file:

```matlab
addpath(fullfile(colormeasure.root(), 'examples', 'pr'));
reading = measurePRExample();
% reading = measurePRExample('COM3');
```

Its plotting-error handling and connection cleanup are documented in
[the example source](../../../examples/pr/measurePRExample.m).

## Export a saved session to CSV

The source MAT must contain `measurements` and `batchInfo`. A missing
`batchInfo` is refused with `PR655:ExportSource`. Export the saved session with:

```matlab
colormeasure.drivers.pr.exportPR655Csv(session.files.mat);
% colormeasure.drivers.pr.exportPR655Csv(session.files.mat, 'spectra.csv');
% colormeasure.drivers.pr.exportPR655Csv;  % Optional MAT file selector
```

The default output is `measurements.csv` beside the source MAT. Existing CSV
files are replaced only after the new export is written. A custom output must
end in `.csv` and cannot refer to the source MAT. Direct driver collections need
their own export script because they do not contain the session's batch fields.

Names, notes and other text use the shared
[CSV text escaping](../../session/README.md#csv-text-and-spreadsheet-formulas).
For example, a reading named `-ND filter` is exported as `'-ND filter` so a
spreadsheet treats it as text. Numeric values are unchanged, and the source
MAT retains the original text.

Every spectral row includes `IsSynthetic`: `1` identifies generated demo data;
`0` means the reading producer did not synthesize the data. It does not establish
physical validation, calibration or measurement accuracy. `DeviceType` retains
the canonical model name. Export requires the reading's explicit logical
`isSynthetic` field; an absent or malformed flag is refused instead of guessed.

# CS-2000 and CS-2000A measurements

Measure spectra and instrument-calculated XYZ, save readings to a MAT file,
and load them for analysis. The `colormeasure.drivers.cs2000` driver reads the current result
without overwriting the instrument's stored measurements.

For named samples, plots and batch saving, open
[openColorMeasure.m](../../../openColorMeasure.m) in MATLAB **R2026b or newer**,
click **Run** and choose **CS-2000**. The
[CS-2000 window guide](batch-and-ui.md) explains its settings and results.

For command-line measurement, follow the steps below.

## Setup

Use MATLAB R2026b or newer. The instrument's USB connection must appear as a
serial port.

Set **Current Folder** to the project root and add its runtime source folder:

```matlab
addpath(fullfile(pwd,'src'));
```

Follow the [preparation guide](preparation.md) for warm-up, aiming and
accessory settings. Keep the target stable until the complete measurement
cycle finishes. The instrument automatically measures and subtracts its
shutter-closed dark response; no separate lens-cap dark measurement is needed.
Close any other application using the instrument connection.

## Measure and save

This example chooses a save filename, takes one measurement and saves it.
It connects and disconnects automatically. An empty `portName` selects a
single available serial port and verifies the instrument's identity.

```matlab
portName = "";
% portName = "COM4";  % Use an explicit port when needed.
[fileName,folder] = uiputfile('*.mat','Save measurement','sample-001.mat');
if ~isequal(fileName,0)
    outputFile = fullfile(folder,fileName);
    measurements = colormeasure.drivers.cs2000.measureToFile(portName,outputFile);
    plot(measurements.wavelengths,measurements.spectralData(:,end));
    xlabel('Wavelength (nm)');
    ylabel('Spectral radiance (W / sr / m^2 / nm)');
    disp(measurements.XYZData(:,end));
end
```

Acquisition starts after selecting the filename. Choose a new filename for
each result to retain earlier measurements; saving to an existing name
replaces that file. Plotting happens after saving.

The command-line example preserves the instrument's current acquisition
settings, including manual integration time. To select automatic exposure,
use [`applyAutomaticSettings` before `Measure`](settings.md) in a custom
script. The window applies its automatic recipe before each reading.
Accessories and correction-channel selections remain unchanged unless
explicitly overridden.

## Load a measurement

```matlab
saved = load(outputFile);
spectrum = saved.measurements.spectralData(:,end);
XYZ = saved.measurements.XYZData(:,end);
metadata = saved.measurements.metadata(end);
```

Each spectrum has 401 values at 380:1:780 nm. `spectralData` stores one
spectrum per column; `XYZData` stores the corresponding instrument-calculated
CIE 1931 2-degree XYZ in three rows. `metadata(k)` records the conditions,
identity and acquisition details for reading k.

Spectra are spectral radiance in W/(sr m² nm). XYZ retains the instrument's
scale: verify its luminance unit before labeling Y as cd/m² or fL. The driver
does not normalize the values or calculate XYZ from the spectrum. See the
[scientific reference](protocol-and-data.md#scientific-meaning) for units
and the [metadata reference](metadata.md) for saved fields.

## Troubleshooting

- **No port or several ports:** run `serialportlist("available")` in MATLAB
  and set `portName` explicitly, for example `"COM4"` on Windows or
  `"/dev/cu.usbmodem..."` on macOS. If the instrument is absent, compare
  `serialportlist("all")` and check the manufacturer's
  [USB driver](https://www.konicaminolta.com/instruments/download/software/display/index.html).
  A failed identity check stops the connection without trying other devices.
- **Port in use:** close the other application using that connection.
- **Long measurement or timeout:** check the instrument's speed setting.
  Native acquisition preserves manual integration, which can be as long as
  120 seconds. Pre-measurement and the light/dark cycle both take time.
  [Connection options](protocol-and-data.md#api-options-and-retained-fields)
  explain deadlines and matching a physical RS-232C connection.
- **Measurement error:** a failed acquisition adds no partial reading and
  is not retried automatically. Correct the cause before measuring again.
  If remote mode remains active, confirm that the instrument is idle before
  using **ESC** to release it. During measurement, ESC cancels that measurement.
  See [recovery and cleanup](protocol-and-data.md#slot-99-and-persistent-settings).
- **After a code update:** if a launcher reports `Measurement:SessionCompatibility`
  or a missing Session property, preserve the active batch and restart MATLAB.
  Follow the [session update guide](../../session/README.md#troubleshooting-after-an-update).

## Reference

- [Driver methods, options and variants](protocol-and-data.md#api-options-and-retained-fields)
- [Preparation and warm-up](preparation.md)
- [Acquisition settings and overrides](settings.md)
- [Measurement window and batch files](batch-and-ui.md)
- [Device metadata and firmware](metadata.md)
- [Original-driver compatibility](original-comparison.md)
- [Automated tests](../../testing/cs2000.md)

To try the demo or share device-test feedback, use the
[quick start](../../beta-testing/README.md).

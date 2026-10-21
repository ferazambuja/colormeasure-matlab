# Colorimetry Research measurements

For the app, open [openColorMeasure.m](../../../openColorMeasure.m) in MATLAB
**R2026b or newer**, click **Run** and choose your CR model.

The [CR window guide](shared-ui.md) explains model-specific settings and
results. The command-line workflow below uses the `colormeasure.drivers.cr` driver directly.

| Instrument | Results |
| --- | --- |
| CR-100 | Instrument XYZ; host-calculated CCT and Duv. No spectrum. |
| CR-250 / CR-300 | Spectrum, instrument XYZ, and host-calculated XYZ, CCT and Duv. |

## First measurement

Use MATLAB R2026b or newer, with the meter recognized as a serial port. Set
**Current Folder** to the extracted download or repository folder and add the
app's source folder to the path:

```matlab
setupColorMeasure
```

Connect the meter and prepare a stable target using the
[model-specific setup guide](preparation.md#ordinary-light-measurements).
The example uses the instrument's **current settings**. For automatic exposure
or explicit changes, use the [acquisition settings example](settings.md#inspect-apply-and-measure).

Choose the save location first. Calling `measureToFile` then connects and
**immediately takes one reading**, saves it, releases the port and returns the
measurements:

```matlab
[fileName, folder] = uiputfile('*.mat', 'Save CR measurement', 'cr-reading.mat');
if isequal(fileName, 0), return; end
fileName = fullfile(folder, fileName);
portName = "";                              % select one available candidate
% portName = "COM4";                        % explicit port when needed
measurements = colormeasure.drivers.cr.measureToFile("CR250", portName, fileName);
disp(measurements.XYZ);                     % one row: X, Y, Z
```

Use `"CR100"` or `"CR300"` for the other models. The driver verifies the selected
model before measuring. If several ports are available, select one explicitly
as described under [troubleshooting](#troubleshooting). Keep the target steady
until the command returns. An existing save file is replaced.

For CR-250 and CR-300, display the spectrum with:

```matlab
plot(measurements.wl(1,:), measurements.spectralData(1,:));
xlabel('Wavelength (nm)');
title(measurements.metadata(1).radiometricQuantity);
```

`XYZ` is calculated from the spectrum for these models; `instrumentXYZ` retains
the meter's own result. CR-100 uses instrument XYZ and has no saved spectrum.
The accessory determines whether spectral readings represent radiance,
irradiance, radiant intensity or radiant flux. See the
[scientific guide](color-science.md) for units and calculation conventions.

## Repeated measurements

Use the class instead of `measureToFile` to collect several readings in one
history. Each `Measure` takes one new reading; position the next sample before
running it again. This example uses the `portName` and `fileName` selected above.
Its first `Save` replaces any earlier contents of that file:

```matlab
meter = colormeasure.drivers.cr.CR250(portName);
```

Position the sample, then run this block once per reading:

```matlab
meter.Measure();
meter.Save(fileName);
```

After the last sample:

```matlab
meter.Disconnect();
```

Each `Save` writes the complete history to the same MAT file. The readings
remain accessible after disconnection. If saving fails, call
`meter.Save(newFileName)` with a writable path to save them without measuring
again. After an acquisition error, release the connection with
`meter.Disconnect()` and use the [recovery reference](api-and-protocol.md#errors-and-recovery)
before reconnecting.

## Load saved measurements

Loading a MAT file does not connect to the instrument:

```matlab
saved = load(fileName, 'measurements');
measurements = saved.measurements;
disp(measurements.XYZ);                     % one row per successful reading
```

The struct contains every retained reading and its device metadata. For
CR-250/300 it also contains each reading's spectrum and wavelength grid.
See the [data reference](api-and-protocol.md#retained-values) for all fields.

## Troubleshooting

- **Several ports:** run `serialportlist("available")` in MATLAB and pass the
  intended port as `portName`. A port name alone does not identify a model.
- **Missing or busy port:** check power and cable, then close other programs
  connected to the meter. On Windows, if the device is not recognized, the USB
  driver is available from the [manufacturer's downloads](https://www.colorimetryresearch.com/downloads).
  Device Manager shows the assigned COM port; macOS names commonly begin
  `/dev/cu.usbmodem`, and Linux names commonly begin `/dev/ttyACM`.
- **Wrong model:** use the matching `colormeasure.drivers.cr.CR100`, `colormeasure.drivers.cr.CR250` or `colormeasure.drivers.cr.CR300`
  class. Related models such as CR-250-RH are not interchangeable.
- **Exposure or synchronization error:** check the reported device code and
  [acquisition settings](settings.md). A host timeout changes waiting time,
  not exposure. A timeout does not prove that the instrument has stopped;
  follow [errors and recovery](api-and-protocol.md#errors-and-recovery).
- **Saving error:** choose an existing writable folder. Native `Save` and
  `measureToFile` do not create missing parent directories.
- **After a code update:** if a launcher reports `Measurement:SessionCompatibility`
  or a missing Session property, preserve the active batch and restart MATLAB.
  Follow the [session update guide](../../session/README.md#troubleshooting-after-an-update).

## Reference

- [API, direct serial commands and recovery](api-and-protocol.md)
- [Instrument preparation](preparation.md) and [acquisition settings](settings.md)
- [Device metadata and firmware](metadata.md)
- [Color science, units and sources](color-science.md)
- [CR measurement window](shared-ui.md)
- [Original-driver comparison](original-comparison.md)
- [Automated tests](../../testing/cr.md)

To try the demo or share device-test feedback, use the
[quick start](../../beta-testing/README.md).

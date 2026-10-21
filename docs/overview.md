# Choose how to use Color Measurement

Use the app for interactive readings, a Session for scripted batches, or an
instrument driver for direct control. All three run inside MATLAB.

## Use the app

Open [openColorMeasure.m](../openColorMeasure.m) and click **Run**. Choose an
instrument and save folder, then select its port in the window if needed.
Select **Measure** for each reading and **Finish batch** when done.

The app shows spectra and chromaticity, compares samples, offers color analysis
and guides chart readings one patch at a time. Each batch saves complete MAT
records; Finish also exports CSV. The [window guide](ui/README.md) explains the
controls and recovery actions.

To explore without hardware, run [demoDirectInstruments.m](../demoDirectInstruments.m).
For a first connected-instrument test and feedback report, run
[testLabInstrument.m](../testLabInstrument.m). The
[quick start](beta-testing/README.md) explains both routes.

## Use your own scripts

- **Drivers** give you serial communication, device settings and native readings.
  Start with the [PR-655](drivers/pr/README.md), [CR-100/250/300](drivers/cr/README.md)
  or [CS-2000/2000A](drivers/cs2000/README.md) examples.
- **Sessions** add sample names, notes, batch saving and recovery to driver
  acquisition. See the [Session API](session/README.md).
- **Color calculations** work with retained measurements. See the
  [colorimetry guide](colorimetry/README.md) for functions, units and references.

## Use your saved results

Load **measurements.mat** as ordinary MATLAB structs. It contains complete
readings, settings/metadata and batch information. Guided charts also retain
attempts and source history. Loading it does not connect to an instrument.

Read the [file structure and import examples](saved-data.md), or run
[examples/loadSavedBatch.m](../examples/loadSavedBatch.m).

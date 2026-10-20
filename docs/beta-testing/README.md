# Try Color Measurement

Use MATLAB **R2026b or newer**, with the JVM enabled. Extract the
[download](../../README.md#start-here) and set MATLAB's **Current Folder** to
**ColorMeasurement-MATLAB** (or to your clone of the repository).

## Open the demo

Open [demoDirectInstruments.m](../../demoDirectInstruments.m) and click **Run**, or enter:

```matlab
demoDirectInstruments
```

Choose an instrument model, then select **Measure** to add generated readings.
Explore **Data**, **Compare**, **Color** and **Settings...**, or try
**Chart / ColorChecker…**. No instrument is needed.

## Test a lab instrument

From the extracted folder, run:

```matlab
testLabInstrument
```

This captures a first device test: three readings and a brief
look at the results window.

1. Choose your instrument, then follow the prompts to prepare it and select its port.
2. Keep the target steady and confirm each of the three readings.
3. When the window opens, check the readings and plots, then close it.
   Answer the final prompt and add a note if helpful.
4. **Open an [instrument test issue](https://github.com/ferazambuja/colormeasure-matlab/issues/new?template=instrument-test.yml)**
   and attach the ZIP from **Desktop → ColorMeasurement-Reports**, even if the
   check fails. MATLAB prints its location and the feedback link.

After a passed check, the app reopens automatically. You can stop there.
Issue attachments are public. The ZIP holds your readings, the instrument's
serial number and settings, and file paths that can show your computer user
name. To keep those private, leave the ZIP out and paste the result and any
error message instead.
See the [feedback guide](../feedback.md) for help.

For further use, see the [window guide](../ui/README.md) and
[saved-data examples](../saved-data.md).

## What the device test checks

The command checks communication, three readings, saving and the results window.
It does not calibrate the instrument or establish optical accuracy. A software
test uses simulated responses; a device-test report records what happened with
your connected instrument.

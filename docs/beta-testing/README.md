# Try Color Measurement

Use MATLAB **R2026b or newer**, with the JVM enabled. Extract the
[download](../../README.md#start-here) and set MATLAB's **Current Folder** to
**ColorMeasurement-MATLAB**.

## Open the demo

```matlab
setupColorMeasure
session = colormeasure.demo('CR250', 'gallery');
```

Explore **Data**, **Compare**, **Color** and **Settings...** with generated
readings. No instrument is needed.

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
Review the report before posting it publicly: it can contain readings, device
details and local paths. See the [feedback guide](../feedback.md) for help.

For further use, see the [window guide](../ui/README.md) and
[saved-data examples](../saved-data.md).

## What the device test checks

The command checks communication, three readings, saving and the results window.
It does not calibrate the instrument or establish optical accuracy. A software
test uses simulated responses; a device-test report records what happened with
your connected instrument.

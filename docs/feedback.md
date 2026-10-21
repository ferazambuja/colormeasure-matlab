# Help test the beta

## With an instrument

Extract the download, set MATLAB's **Current Folder** to
**ColorMeasurement-MATLAB** (or to your clone of the repository), then run:

```matlab
testLabInstrument
```

1. Choose your instrument and follow the preparation and port prompts.
2. Confirm three readings of the same steady target.
3. Inspect the results window, close it and answer the final prompt.
4. Open an [instrument test issue](https://github.com/ferazambuja/colormeasure-matlab/issues/new?template=instrument-test.yml)
   and share the result and any error. You can attach the report ZIP from
   **Desktop → ColorMeasurement-Reports**.
   Send feedback even if the check fails; if no ZIP was created, paste the error.

After a passed check, the app reopens. Select **New batch** to try your own
measurements, or stop there.

Nothing is uploaded automatically, and issue attachments are public. The ZIP
holds your readings, the instrument's serial number and settings, and file
paths that can show your computer user name. To keep those private, leave the
ZIP out: choose the result and paste any error message, or the `Result` line
from `report.txt` in the report folder.

## Without an instrument

Try the [demo](beta-testing/README.md#open-the-demo), then
[report a problem or suggestion](https://github.com/ferazambuja/colormeasure-matlab/issues/new?template=feedback.yml).
Say what you tried, what happened and your MATLAB release and operating system.
Screenshots help with window or chart issues.

# Color Measurement for MATLAB

A measurement app and scriptable drivers for PR-655, CR-100/250/300 and
CS-2000 instruments. Collect readings, compare samples and save results for
your own MATLAB scripts.

**[Download the UI + drivers ZIP](https://github.com/ferazambuja/colormeasure-matlab/releases/download/v0.1.0-beta.1/ColorMeasurement-MATLAB-Beta.zip)**

Requires **MATLAB R2026b or newer**, with the JVM enabled. No Python, Argyll or
MCSL-Tools installation is needed.

**Public beta:** try the demo or help test a connected instrument. Physical
instrument testing is still pending; this release does not establish measurement
accuracy or calibration.

## Features

- **Measure and save together.** Full MAT snapshots after each complete reading;
  **Finish batch** exports CSV. Names, notes, timing and capture metadata stay
  with the data.
- **See your results.** Linked spectra, chromaticity, a reading table and detailed
  numerical results in one window.
- **Compare samples.** Inspect spectral differences, XYZ, Lab and CIEDE2000 with
  a chosen reference white.
- **Explore color.** Chromatic adaptation and measured-reference reflectance/relighting
  are separate derived views; acquired data stays unchanged. Export analysis separately.
- **Read guided charts.** **Chart / ColorChecker…** opens Classic, Digital SG or
  custom grids that track patch positions,
  missing readings, repeated attempts and selected results. Continue saved charts
  in a linked new batch while retaining their source history.
- **Control capture settings.** Adjust model-specific settings and inspect the
  instrument's readback.
- **Edit and recover.** Correct sample names and notes, restore hidden windows
  and retry saving without repeating a reading.
- **Use your own scripts.** Use the drivers directly or load saved MATLAB structs.
- **Try it without equipment.** Explore a gallery of generated readings or
  practice collecting samples and charts.

![Current direct-serial measurement window with generated CR-250 readings](docs/ui/images/direct-serial-gallery.jpg)

*Demo with generated readings.*

![Guided ColorChecker Classic chart with generated readings](docs/ui/images/direct-serial-chart.jpg)

*Chart mode with generated readings.*

## Start here

Use **MATLAB R2026b or newer**, with the JVM enabled.

1. Download and extract the ZIP.
2. Set MATLAB's **Current Folder** to the extracted **ColorMeasurement-MATLAB** folder.

### Explore the UI without hardware

```matlab
setupColorMeasure
session = colormeasure.demo('CR250', 'gallery');
```

Try **Data**, **Compare**, **Color** and **Settings...**. For generated readings
that you collect yourself, use `colormeasure.demo('CR250')`. Other model keys:
`PR655`, `CR100`, `CR300`, `CS2000`.

### Test an instrument and share feedback

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
Reports can contain readings, device details and local paths. Review yours before
sharing it publicly. See the [feedback guide](docs/feedback.md) for help or other feedback.

## Use the app

For a normal session after setup:

```matlab
session = colormeasure.app;   % choose a model and save folder
```

Opening the window never measures automatically. Select **Measure** for each
reading and **Finish batch** when done. Closing the window hides the retained
batch; **New batch** creates a separate collection.

## Your data belongs in your MATLAB workflow

- **`measurements.mat` is the full record:** ordinary `measurements` structs and
  `batchInfo`, including settings, metadata and chart history when present.
- **`measurements.csv` is a supporting table:** written at Finish; spectral
  instruments use one row per wavelength per reading.
- **`chart-selected.csv` summarizes chart selections:** it does not replace the
  complete attempt history in MAT.
- A save failure retains completed readings for recovery; use **Retry save**
  or **Another folder** before closing MATLAB.

Read the **[saved-data guide and MATLAB import examples](docs/saved-data.md)**.
The runnable [loadSavedBatch.m](examples/loadSavedBatch.m) opens a batch and builds
an XYZ summary without launching the app or connecting hardware.

```matlab
saved = load('measurements.mat', 'measurements', 'batchInfo');
readings = saved.measurements;
if ~isempty(readings)
    XYZ = vertcat(readings.XYZ);  % inspect each reading's units and XYZ source
end
```

## Use the drivers in your scripts

| Model key | Instrument and guide | Returned measurements |
| --- | --- | --- |
| `PR655` | [PR-655; tentative PR-670](docs/drivers/pr/README.md) | Spectrum and host-calculated XYZ |
| `CR100` | [Colorimetry Research CR-100](docs/drivers/cr/README.md) | Instrument XYZ; no spectrum |
| `CR250`, `CR300` | [Colorimetry Research CR-250 / CR-300](docs/drivers/cr/README.md) | Spectrum, host XYZ and instrument XYZ |
| `CS2000` | [Konica Minolta CS-2000 / CS-2000A](docs/drivers/cs2000/README.md) | Spectrum and instrument XYZ |

Driver guides include setup and examples for your own scripts.
The drivers use namespaced class names. Their APIs and saved formats differ
from the original MCSL drivers; they are not complete drop-in replacements.
PR-670 support is tentative.

## Use MATLAB commands

The [session guide](docs/session/README.md) covers named command-line batches,
MAT/CSV contents and recovery. Native drivers live under
`colormeasure.drivers.pr`, `colormeasure.drivers.cr` and
`colormeasure.drivers.cs2000`. The [colorimetry guide](docs/colorimetry/README.md)
covers spectral integration, chromaticity, Lab, color differences, adaptation
and reference-based reflectance calculations.

[Acquisition science](docs/session/color-science.md) and
[color calculations](docs/colorimetry/science.md) document equations, sources,
quantity conventions and interpretation limits.

## Attribution and licenses

Fernando Voltolini de Azambuja developed the measurement sessions, instrument
updates, graphical workflow, tests and color-calculation implementation and
adaptations. The project retains MCSL-Tools contributions and scientific methods
from the sources identified in the documentation.

The original [MCSL license](LICENSE.txt) and [contributor attribution](OWNERS.txt)
remain included. The [colorimetry code license](licenses/colorimetry-MIT.txt),
[colorimetry notices](docs/colorimetry/THIRD_PARTY_NOTICES.md),
[PR driver notices](docs/drivers/pr/THIRD_PARTY_NOTICES.md), and
[CIE data terms](resources/colorimetry/README.md) identify their respective scope.
The [guided-chart resources and source terms](resources/charts/README.md) retain
ArgyllCMS's AGPL-3.0 terms for the source-derived chart identifiers, numerical
reference data and retained original chart-source files. The
application's MIT license does not replace those terms. The standalone package
includes the application source, chart data in source form, original chart
files, generators, attribution and applicable licenses.

## More guides

- [How the app, drivers and saved data work together](docs/overview.md)
- [Window controls, chart continuation, settings and analysis](docs/ui/README.md)
- [Demo and device-check walkthrough](docs/beta-testing/README.md)
- [Share device-test results or report a problem](docs/feedback.md)
- [Session API, saving and recovery](docs/session/README.md)
- [Saved-data structure and import examples](docs/saved-data.md)
- [Software testing reference](docs/testing/workflow.md)

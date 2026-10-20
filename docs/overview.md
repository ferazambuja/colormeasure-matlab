# How Color Measurement works

The app and MATLAB commands use the same instrument drivers and batch records.
You can use the graphical workflow, collect a batch from a script, or use a
driver directly without opening the app.

## A reading in the app

1. Choose an instrument, port and save folder. Opening the app does not measure.
2. Select **Measure**. The instrument's driver connects, checks its identity,
   applies the app's acquisition settings and requests one reading.
3. The session retains a complete reading, releases the connection and saves a
   MAT snapshot. The window shows the saved values, plots and status.
4. Repeat as needed, then select **Finish batch** to export CSV.

If measurement or saving fails, inspect the status and use the recovery controls.
The [window guide](ui/README.md) explains those actions, capture settings,
comparisons and guided charts.

## Drivers, sessions and calculations

- **Drivers** own serial communication, device settings, response parsing and
  instrument-specific records. Start with the [PR](drivers/pr/README.md),
  [CR](drivers/cr/README.md) or [CS-2000](drivers/cs2000/README.md) guide.
- **Sessions** collect named readings, notes and settings in a batch, save them
  and support recovery. The [session API](session/README.md) also works without
  a window.
- **The UI** presents the session and its actions. Chart mode adds patch
  positions, repeated attempts and selected readings to that same batch.
- **Color calculations** derive previews, comparisons and analysis from retained
  measurements. The [colorimetry guide](colorimetry/README.md) explains methods,
  units and reference whites. These views do not overwrite acquired data.

## Use the saved results

`measurements.mat` is the complete record, stored as ordinary MATLAB structs.
CSV is a convenient supporting table; chart CSV contains selected chart results.
Loading a MAT file needs neither the app nor a connected instrument.

See the [file structure and import examples](saved-data.md), or run
[`examples/loadSavedBatch.m`](../examples/loadSavedBatch.m).

The [demo](beta-testing/README.md#open-the-demo) uses generated readings.
The optional [instrument check](feedback.md) collects three real readings and a
local feedback report. Neither software tests nor a successful device check
establish instrument calibration or optical accuracy.

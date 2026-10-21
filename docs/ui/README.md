# Use the measurement app

Collect readings, inspect results and save a batch in MATLAB. To explore without
an instrument, open [demoDirectInstruments.m](../../demoDirectInstruments.m) and
click **Run**. The screenshots below show generated demo data.

## Open the app

Use MATLAB **R2026b or newer**, with the JVM enabled. Set MATLAB's **Current
Folder** to the extracted download or repository folder.

1. Open [openColorMeasure.m](../../openColorMeasure.m) and click **Run**.
2. Choose your instrument and a save folder. Each batch gets its own subfolder.
3. Select the instrument's port if several are listed. **Refresh ports** updates
   the list after you connect a cable.

Opening the window takes no reading. Check the instrument's setup guide before
measuring: [PR-655](../drivers/pr/README.md), [CR-100/250/300](../drivers/cr/README.md)
or [CS-2000/2000A](../drivers/cs2000/README.md).

For a first device test and feedback report, use
[testLabInstrument.m](../../testLabInstrument.m) instead. The
[quick start](../beta-testing/README.md) explains its prompts.

![Measurement window with generated CR-250 readings](images/direct-serial-gallery.jpg)

## Take readings

1. Enter a **sample name** and optional **notes**.
2. Position the instrument and select **Measure**. Follow the preparation
   prompt if one appears; **Ready** continues and **Cancel** stops that reading.
3. Keep the target steady. A completed reading appears in the table and plots
   and is saved to MAT. The next sample name advances and the notes clear.
4. Repeat as needed, then select **Finish batch** to finalize MAT and export CSV.
5. Select **New batch** for another collection.

Each reading needs a separate **Measure** action. Ctrl+Shift+M is its shortcut
on all platforms when the Measure tab is ready. Finish editing text before
using the shortcut.

Closing the window hides the batch. Run **openColorMeasure.m** again to restore
it. **Finish batch** ends acquisition for that batch; its results stay available.
Keep MATLAB open until any save problem is resolved.

## Find your results

| Tab or control | Use it to |
| --- | --- |
| **Measure** | Name the next sample, add notes, choose a port and take a reading |
| **Data** | Read the selected sample's values, units, timing and notes; **Copy** copies the summary |
| **Compare** | Compare two readings with a chosen Lab white reference |
| **Color** | Calculate adapted color or reference-based reflectance/relighting |
| **Readings / Hide readings** | Show or hide the reading table |
| **Show log / Show readings** | Switch between event messages and readings |

Select a table row, spectral curve or chromaticity point to inspect a reading.
**Follow latest** returns to the newest reading and follows new results.
**All spectra**, **Selected spectrum** and **Compare A / B** change the spectral
view. CR-100 has XYZ only, so it has no spectrum plot.

The chromaticity selector switches between **CIE 1976 u′v′** and **CIE 1931 xy**.
**Reset plots** restores the full diagram and spectrum after zooming. Small
sample-color previews are approximate sRGB colors with normalized brightness;
they are navigation aids, not calibrated appearance matches.

Select a reading and choose **Edit…** to correct its name or notes. Changes are
saved, and original annotations remain in MAT. Editing a chart reading's name
does not change its patch. Editing a finished batch keeps it finished.

## Measurement settings

The app applies automatic acquisition settings before each reading:

| Instrument | Automatic settings |
| --- | --- |
| PR-655 / tentative PR-670 | Adaptive exposure, one averaging cycle, automatic synchronization |
| CR-100 | Colorimeter mode, automatic exposure and electronic range |
| CR-250 / CR-300 | Automatic exposure; existing exposure multiplier and supported synchronization retained |
| CS-2000 / CS-2000A | Multi-Normal, 1-second multi interval, internal ND Auto and No Sync |

To inspect or change them:

1. Open **Settings...**. **Read settings** connects to read the current settings
   without taking a measurement.
2. Select a setting to read its help. To change it, enable **Override this
   setting** and enter a value. Use a period for decimals.
3. Select **Use for next readings**. The app applies the request when you next
   select **Measure**. **Cancel** discards the draft.

**Last read** is a dated observation. Unread choices need an explicit selection.
**Clear overrides**, followed by **Use for next readings**, restores the app's
automatic acquisition recipe on subsequent readings. Accessory, correction and
calibration selections stay as configured unless explicitly changed.

If applying settings fails, no reading starts. Check the log and instrument
before trying again; some settings may already have changed.

For individual controls, see the [PR settings](../drivers/pr/settings.md),
[CR settings](../drivers/cr/settings.md) and
[CS-2000 settings](../drivers/cs2000/settings.md) references.

## Measure a chart one patch at a time

![ColorChecker Classic chart with six generated readings](images/direct-serial-chart.jpg)

Start with ordinary sample readings, or select **Chart / ColorChecker…** to
set up a chart. Choose **ColorChecker Classic** (4 × 6), **Digital SG** (10 × 14)
or a named **Custom grid** of up to 140 cells, then select **Start chart**.

1. Click the patch you intend to measure. Check **Active patch** and the
   coordinate on the **Measure** button.
2. Position the instrument on that physical patch and select **Measure**.
3. After a successful reading, the next target advances in row order, returning
   to any gaps. Click another patch to measure out of order.
4. To repeat a patch, select it and measure again. The latest successful attempt
   becomes selected; earlier attempts remain saved. A failed repeat keeps the
   earlier successful result.
5. Select **Finish batch** when done. If patches are missing, choose
   **Finish incomplete** or **Keep measuring**.

Columns are letters and rows are numbers: **B2** is column two, row two.
Rotation changes the diagram, not saved coordinates. Arrow keys move the
inspection highlight; **Space** or **Enter** makes that cell the Active patch.
The highlight can differ from the next target, so check the Measure button.

| Mark | Meaning |
| --- | --- |
| `○` | To measure |
| `✓` | A reading is selected |
| `*` | Next patch to measure |
| `!` | Check the attempt; `✓!` retains an earlier successful reading after a failed retake |

Classic's unmeasured cells show approximate reference colors to help identify
patches. Digital SG and custom grids have no reference palette. Measured cells
are dark with a check mark; inspect their values in **Data**. When available,
the **Chart color** swatch shows the reference color, not a color calculated
from your reading. Lighting, optics and physical positioning remain
your responsibility; the grid does not turn radiance readings into reflectance
or check that the instrument points at the correct patch.

**Chart / Plots** switches the workspace. **Readings** shows the table beside
the chart. **Pause chart** lets you take individual samples without filling
cells; **Resume chart** returns to the retained target. **Samples** pauses the
chart and returns to individual readings.

A *pass* groups chart readings taken under one setup. If measurement settings
change, **Review changed settings…** explains the difference. **Start new pass**
keeps earlier results and starts empty coverage. The **Pass** selector inspects
older passes without changing the active target.

If saving fails after a reading, keep that result and use **Retry save** or
**Another folder**. Measuring it again would create another attempt.

### Continue a saved or finished chart

Use continuation to fill missing patches or repeat readings in a new batch.

1. Open the app for the intended instrument and setup.
2. Choose **Chart / ColorChecker… → Continue chart…**. An existing chart uses
   **Change chart… → Continue chart…**; a finished chart offers **Continue chart…**.
3. Choose a saved **measurements.mat**, **This batch**, or another open chart
   batch. Select the source pass and review its coverage and setup.
4. Choose **Continue selected pass** when identity and required conditions
   match, or **Start new pass** for fresh coverage. **Cancel** leaves work unchanged.

Acceptance saves and finishes unfinished live batches involved in the transfer.
A source selected from disk is kept unchanged. New readings go into a linked
batch; its MAT also retains earlier chart readings and their source identities.
The new table contains this batch's readings, while chart details can show
inherited results.

A disabled action explains what needs attention. Establish missing settings
through normal readiness controls. **Confirm observed setup…** records only
conditions you can check; it cannot override reported differences or establish
calibration. If the earlier setup cannot be established, start a new pass.
Resolve any save or connection-cleanup problem first. See the
[Session API](../session/README.md#continue-a-chart-in-a-new-session) for commands
and file-size limits.

## Compare two readings

1. Open **Compare** and choose **A (ref.)** and **B (test)**. You can also select
   two rows with Command-click on macOS or Ctrl-click on Windows.
2. Choose a **Lab white** for Lab and **ΔE00**: a measured white from the same
   setup, or D50, D65 or A with **White Y** on the samples' XYZ scale.
3. If **Same XYZ scale (operator)** appears, confirm it only after checking
   that both samples and the white share that scale.
4. Inspect ΔE00, Lab, XYZ and chromaticity differences. **Copy comparison**
   includes the reference and any unavailable-result explanations.

No Lab white is selected automatically. Preset **White Y** starts at 100; use
it only when that value fits your measurement scale. Samples are not each
normalized to 100. Choosing a comparison white does not change their recorded
values or predict their appearance under another light.

Signed differences are **B − A**. Compatible spectra also show a signed
difference plot and **Spectral RMS**, the root mean square of the spectral
difference on matching, uniformly spaced wavelength samples. RMS retains the
spectral units. There is no automatic pass/fail threshold.

**Unavailable** explains a missing white, unknown scale or incompatible data.
CIEDE2000 has viewing-context limits; see
[calculation methods and interpretation](../session/color-science.md#cielab-reference-white-and-color-differences)
before treating a difference as a perceptual judgment.

## Adapted color and object-color views

Open **Color**, choose a sample and **View**, then select **Apply view**.

- **Chromatic adaptation:** choose source and destination whites. The app uses
  Bradford adaptation for the derived color; the spectrum stays unchanged.
- **Reflectance / relight:** choose a spectral sample and a measured white
  reference from the same lighting, geometry and scale. Supply the white's
  reflectance CSV, or explicitly assume an ideal white for a relative ratio.
  Choose the target illuminant. CR-100 has no spectrum for this calculation.

Changing an input makes the previous result unavailable until you apply again.
**Measured view** restores the acquired plots. **Export analysis MAT...** saves
the derived result, source readings and assumptions in a separate new file.
Choose a new name; existing files are preserved.

The [illumination guide](../session/illumination.md) explains reference-file
format, setup, equations and limits.

## Save, close and recover

**measurements.mat** contains complete readings and batch information.
**Finish batch** also exports acquisition-order **measurements.csv**. Guided
charts update **chart-selected.csv** after progress is saved. Keep MAT for full
spectra and chart attempt history. See the [saved-data guide](../saved-data.md)
for file structure and import examples.

The status footer reports measurement, saving and errors. **Show log** opens
more detail; select a message to read or copy it. Filtering messages does not
delete them.

| Problem | What to do |
| --- | --- |
| MAT or CSV save failed | Use **Retry save**, or **Another folder** for a writable destination. Keep MATLAB open until recovered. |
| A reading completed but cleanup failed | Keep the reading and resolve cleanup below; do not repeat it just to save it. |
| Finished batch needs a save retry | Retry saving; the batch stays closed to new readings. |
| Chart CSV is stale or unavailable | Keep MAT. Follow the log's recovery action; use another folder if an existing CSV was changed externally. |

### Unconfirmed connection cleanup

**Cleanup unconfirmed** means the app could not confirm that the instrument
connection closed. It can follow a failed connection attempt or release.

- Use **Retry cleanup** when available. It retries the existing connection's
  release without measuring again.
- Otherwise use **Confirm cleanup...** only after checking that no MATLAB batch
  or other program uses the port and that the instrument is idle. Complete both
  checks and explain how you checked.

Saving or restarting alone does not confirm cleanup. If the confirmation's save
fails, use **Retry save** or **Another folder**. The
[command reference](../session/README.md#unconfirmed-connection-cleanup) explains
how to do the same from a script.

## Switch instruments or update the app

Choose another **Instrument** and select **Open**. Each model has its own batch;
select the previous model and **Open** to return. A chart is paused and saved
before switching. Resolve saving or cleanup problems before continuing.

Before updating the app, finish and save active batches, then restart MATLAB.
To change serial or timeout options, follow the
[session configuration instructions](../session/README.md#window-integration).

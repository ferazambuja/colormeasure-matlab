# Measurement window

Collect named readings, inspect spectra and chromaticity, and save a batch from
one window. MATLAB remains available for calculations between readings.
**MATLAB R2026b or newer is required.**
Screenshots show generated demo readings.

![Current direct UI with generated CR-250 readings](images/direct-serial-gallery.jpg)

Follow the relevant [instrument setup guide](../../README.md#instrument-workflows),
then run `setupColorMeasure` from the extracted folder and open the app:

```matlab
colormeasure.app
```

Choose the instrument. **Measurement save folder** explains where results will
go before opening the OS folder picker. Select **Choose folder** and choose a
parent folder; each batch gets its own subfolder with MAT files and supported
CSV exports. Choosing a folder does not start a measurement. **Cancel**, or
closing either dialog, leaves an existing batch unchanged and opens no new one.
A single available port is selected automatically; choose the meter's port
when several are listed. The driver
verifies instrument identity when it connects.
This launcher opens the PR, CR and CS-2000 workflows below.
To open a specific model and retain its session handle directly:

```matlab
session = colormeasure.app('CR250');
```

| Model key | Instrument | Family shortcut |
| --- | --- | --- |
| `PR655` | PR-655; tentative PR-670 | `colormeasure.drivers.pr.measurePR655` |
| `CR100` | CR-100, XYZ only | `colormeasure.drivers.cr.measureCR100` |
| `CR250` | CR-250 | `colormeasure.drivers.cr.measureCR250` |
| `CR300` | CR-300 | `colormeasure.drivers.cr.measureCR300` |
| `CS2000` | CS-2000 / CS-2000A | `colormeasure.drivers.cs2000.measureCS2000` |

The bare command publishes a named session handle in the MATLAB workspace;
requesting an output uses the selected variable instead. Repeating a launcher
restores that model's active or finished batch. Each model has its own session;
selecting another model never changes the instrument of an existing batch.
`colormeasure.app` restores that batch's connection settings, including custom
options previously supplied through a family launcher.
The folder and instrument selector share the top row. The window also shows
the reading count; the folder tooltip contains the full destination and its
opening time. Model-specific launchers use the same `src` path
entry and accept the connection options described in each driver guide.

New windows open maximized. Restore or resize the window as needed; reopening
the same session keeps your size choice. The left tabs sit above the
persistent status footer, with the readings table to their right. **Show log** replaces the table with
event history; **Show readings** brings the table back.

The [color-science reference](../session/color-science.md) provides the underlying
code excerpts, primary sources, units and interpretation limits.

## Collect native-instrument readings

1. **Enter a sample name and optional notes.** The initial name is **Sample 001**.
2. **Position the sample and select Measure.** Keep the meter and sample steady.
   For live PR, CR and CS sessions and the PR demo, the first reading shows
   preparation guidance; **Ready** continues that requested measurement, and
   **Cancel** preserves the draft.
   Instructions remain available under **Settings... → Instrument help**.
   Each completed reading releases the connection, updates the complete MAT
   batch, and appears in the plots and table.
3. **Prepare the next sample.** The name advances and notes clear only after a
   successful reading. Each reading requires an explicit **Measure** action.
4. **Select Finish batch** when done. It finalizes MAT and exports CSV. Results
   remain visible for inspection; acquisition for that batch is complete.
5. **Select New batch** to choose a destination for another batch. Cancelling
   leaves the completed batch visible. Previously returned handles remain
   readable; the launcher's named workspace handle points to the new batch.

If a cable was connected after opening the window, **Refresh ports** updates
its list. One candidate is selected automatically; several require a choice.

Notes accept multiple lines; pressing Enter there adds a line. **Measure** also
has a shortcut: Ctrl+Shift+M on every platform, from the idle Measure tab.
It is inactive in other tabs, during an operation, and while a settings or modal
dialog is open. Finish any text edits with Tab or a click outside the field
before using it. Holding the shortcut does not start repeated readings. Calibration
and positioning prompts require their own explicit response buttons.
If an otherwise active shortcut is blocked by cleanup, changed settings or
another measurement-readiness condition, the status explains why no measurement
started. Correct that condition before trying again; the shortcut does not
bypass a disabled measurement action.

Acquisition is synchronous. Measurement and saving controls are disabled while
busy; inspection can respond when MATLAB processes events during the operation.
Port selection identifies a candidate connection. The selected model's adapter
verifies identity and applies its automatic acquisition settings before measuring.
Opening the window does not configure the instrument. Accessory and calibration
selections are retained unless explicitly overridden.

| Instrument | Automatic acquisition before each reading |
| --- | --- |
| PR-655 / tentative PR-670 | Adaptive exposure, one averaging cycle, automatic synchronization |
| CR-100 | Reported Colorimeter mode, automatic exposure and electronic range |
| CR-250 / CR-300 | Automatic exposure; existing exposure multiplier and supported synchronization are retained |
| CS-2000 / CS-2000A | Multi-Normal with a 1-second multi interval, internal ND Auto and No Sync |

Preparation instructions remain model-specific: [CR guide](../drivers/cr/preparation.md)
and [CS guide](../drivers/cs2000/preparation.md).
See [connection behavior](../session/README.md#actions) for port discovery and protocol
details.

## Measure a chart one patch at a time

![Current Classic chart workflow with six generated readings](images/direct-serial-chart.jpg)

*Generated data; reference illustrations remain separate from measured colors.*

The app starts with individual sample readings. Select **Chart / ColorChecker…** in the
Measure tab to measure a chart one patch at a time. In **Set up guided chart**, choose a layout; for **Custom grid**,
enter **Chart name**, **Rows** and **Columns**. Check the window's save
destination, then select **Start chart**. Switching between presets inside the
dialog preserves the custom entries. **Cancel** closes the draft without
changing the batch. Setup itself does not measure or calibrate.

| Layout | Rows × columns | Coordinates |
| --- | --- | --- |
| ColorChecker Classic | 4 × 6 | A1–F4 |
| ColorChecker Digital SG | 10 × 14 | A1–N10 |
| Custom | Your dimensions, up to 140 cells in total | Generated from the dimensions |

Direct radiance/luminance instruments use the grid to name and retain readings
of an illuminated chart under suitable optics and stable lighting. The grid
does not turn those readings into reflectance. Physical positioning remains
the operator’s responsibility.

Columns are letters and rows are numbers, starting at the upper left of the
unrotated diagram. For example, B2 is the second column in the second row.
Custom columns continue AA, AB, … after Z. Rotation changes the diagram,
while saved coordinates and the next measurement target remain fixed. The
inspection stays at the same visible grid position where possible, so rotation
can change which coordinate it shows. If that position no longer fits the
rotated grid, inspection starts at its first visible cell.

The **Chart / Plots** selector changes the main workspace without taking a
reading. The **Chart** workspace starts with the readings table collapsed to
leave room for the grid, including when a demo script starts the chart.
Select **Readings** to review acquired rows, or **Hide readings** to return that
space to the chart. Calibration instructions and save recovery
remain available with the table collapsed.

1. Choose the patch you intend to measure. Arrow keys move the highlighted
   **inspection** cell without changing the measurement target or saving the
   batch. With the grid focused, press **Space** or **Enter** to make that cell
   the **Active patch**; clicking a cell also makes it Active. These actions
   never acquire a reading. Active is marked `*` in the active pass's grid and
   named on the **Measure** button. Check that coordinate and add any patch
   notes. The pending sample name is the coordinate.
2. Position the instrument on that physical patch, then select **Measure B2**
   (or the coordinate shown on the button).
   The existing measurement shortcut also works when the Measure tab is idle.
   Follow any preparation or calibration instructions before returning to the
   patch. Selecting a cell alone never starts acquisition.
3. After a successful retained reading, **Active patch** advances to the next
   unmeasured cell in row order, returning to earlier gaps when necessary.
   The highlighted inspection cell stays selected so you can review its result;
   it can now differ from Active. **While the chart is resumed, Measure uses Active**, shown by `*`
   and the button's coordinate. Click another cell, or activate the inspected
   cell with **Space** or **Enter**, to retarget the next reading or measure
   out of order.
   Notes apply to that attempt: success retains them on the reading and clears
   the next-cell draft; a failed or unresolved attempt keeps them for retry.
4. To repeat a patch, make it Active and measure again. A successful repeat becomes
   its selected reading; earlier attempts remain in the batch. A failed repeat
   keeps the previous selected reading. Repeats do not increase the completed
   cell count.
5. Use **Pause chart** to stop chart work while retaining progress. The `*`
   disappears; selecting cells only inspects them. The footer normally says
   **Paused chart patch**, but a save, recovery or unavailable setup can take
   priority. Follow the action shown there. While paused, **Measure**, when available, takes free
   samples that do not fill chart cells. Select **Resume chart** in the same
   live session to measure chart patches again. **Samples** in the sidebar
   pauses the chart and returns to individual sample readings.
6. Select **Finish batch** when done. If the active pass is incomplete, the
   prompt lists its missing coverage. Choose **Finish incomplete** to save and
   finish, or **Keep measuring** to return to that pass. A complete active pass
   finishes without this prompt, even when an earlier retained pass is incomplete.
   Filling every cell does not finish automatically. While finishing or after
   finish, acquisition is closed and `*` disappears. During Finish the footer
   names the **Chart target**; a save-recovery pause can show **Blocked chart
   target**. Once the batch is finished, **Retained chart patch** identifies
   the preserved target for inspection. A later MAT save retry keeps acquisition
   closed and says **Saving retained output. Wait for saving to complete.**
   An optional export retry instead names **Updating CSV**;
   wait for that action to finish. It does not take another reading.

The chart diagram preserves the preset or custom arrangement, including rotation.
Near-square colored cells and coordinate/status captions share one native keyboard grid.
Unmeasured cells show the chart's reference colors when available. A check mark
shows that a reading has been collected; direct readings use a dark cell and
keep their numerical results in **Data**. The small **Chart color** swatch shows
the selected patch's reference color, so you can identify it on the chart.

The legend shows `○` **To measure**, `✓` **Measured**, `*` **Next patch** and
`!` **Check reading**. If a retake fails, `✓!` keeps the earlier successful
reading selected and flags the retake for review. The footer tells you which
patch is selected and what to do next. Hover over it for reading details and
color information.

Keep the instrument's measurement area within the intended patch. Chart colors
are approximate screen previews; use the saved values for analysis.


Cancelled and failed readings do not advance progress.
The patch association is fixed when a reading starts. An inspection action
during acquisition cannot move that reading to another cell. If acquisition
succeeds but saving fails, the cell remains measured and visibly unsaved.
Recover with **Retry save** or **Another folder** before further chart work;
these actions save the retained reading without measuring it again.
While an operation or save is in progress, cell selection is for inspection;
wait for that operation or save to finish before changing the measurement target.
For a blocked chart, follow the named recovery action. If settings changed while
paused, use **Review changed settings…** before resuming; Resume does not accept
the changed context for you. This review is required before another chart
reading; while the chart stays paused, an available **Measure** still takes
free samples. Unconfirmed connection cleanup must also be resolved
before another acquisition. An unsupported setup prevents chart acquisition.
A visible `*` identifies an available target; it disappears during
acquisition, save recovery, a pending setup decision, ineligible
setups, prior-pass inspection, pause and finish. The retained target stays named
separately from the inspected cell. A failed retry keeps the selected successful
reading. A new pass begins with empty measured coverage.

To edit a B2 reading acquired in the current batch, inspect B2's selected reading
number and attempt. Select **Readings**, choose that row and select
**Edit…**. Renaming it **Foo** leaves it associated with B2; the chart details tooltip shows
its current name, while **Data** shows its notes. Earlier attempts remain
separate rows. The chart and export keep the coordinate and editable name
separate; editing does not retarget the reading or remove its original annotation.

A chart pass groups readings taken under one acquisition setup. A material
settings change exposes **Review changed settings…**. Review the differences,
then choose **Start new pass** for empty coverage or **Decide later** to leave
the decision pending. Normal recalibration alone does not fill a cell.
Changing the diagram, annotations or save folder does not start a pass.

When several passes exist, the **Pass** selector lets you inspect earlier
coverage and attempts read-only. The current pass is labelled **active**.
Inspecting another pass never changes the active measurement patch: check the
active coordinate in the details and the **Measure** button before acquiring.
To measure again against an earlier or finished pass, use linked continuation
below. The original batch stays a retained record.

Direct instrument switching pauses and saves the source chart, then opens the
other instrument's separate session. Return to the original instrument and
select **Resume chart** when ready. If the source cannot be saved, its window
and recovery controls stay available; recover saving before switching.
Progress is saved in MAT, then `chart-selected.csv` is refreshed as a chart-order
summary. It is separate from acquisition-order `measurements.csv`, which is
written at Finish. Missing cells have
empty measured-value fields. If numerical export is unavailable, the chart
summary states the reason and retains identity, status and annotations. See
[chart saved data](../session/README.md#chart-records-and-selected-reading-csv).

Closing and reopening the window can restore this chart while its session is
still alive. Quitting MATLAB ends that session. Plain MATLAB `load` supports
inspection; use the explicit continuation workflow below to create a fresh
measurement session from a saved chart.
Qualified chart illustrations use the declared relative scale and white.
They do not enable reference-based warnings. Exporting the preset reference
datasets is unavailable. Native radiance/luminance readings do not become relative reflective colors.

## Measured-reference eligibility

Native radiance/luminance and naming-only chart contexts do not qualify as
relative reflective measured references. In this direct installation, relative
measured colors and placement checking are unavailable. There is no
placement configuration control or measured-reference acceptance workflow.
The application does not convert native quantities or establish a physical patch match. Ordinary
guided measurement works without reference checking.

The **Chart color** swatch shows a historical preset illustration; its tooltip
names the source. It remains distinct from measured colors and does
not enable placement warnings. See the scientific
[quantity and comparison limits](../colorimetry/position-checks.md) before
interpreting chart color or reference metadata.

## Continue a saved or finished chart

Continue a chart when you need to finish missing patches or repeat readings in
another batch. The app keeps the source chart and its earlier readings, then
saves new work in a separate batch. Opening the preview takes no measurement
and does not finish the current batch.

1. Open the window for the instrument and setup you intend to use. With no
   chart set up, choose **Chart / ColorChecker… → Continue chart…**. For an
   unfinished chart already in the window, choose **Change chart… → Continue
   chart…**. In the source chooser, select **This batch** to use that live chart,
   open a saved `measurements.mat`, or choose another retained chart batch.
   A finished chart offers **Continue chart…** directly.
2. Choose **Source pass**. Review its measured count and the comparison of
   **Source pass** with **Current setup**. You can choose an earlier pass;
   selecting it changes only the preview.
3. Check the source label before choosing an action. Acceptance finishes and
   saves the current batch and any other unfinished live source batch, then hides
   their old windows. A source selected from disk is not rewritten. **Cancel**
   leaves the batches unchanged.

   | Action | What happens |
   | --- | --- |
   | **Continue selected pass** | Keeps that pass's selected readings and measured coverage in a new linked batch. Available only when identity and required measurement conditions are established and compatible. |
   | **Start new pass** | Keeps prior history for inspection and starts the new active pass with zero measured cells. Use this for changed or unestablished conditions. |
   | **Cancel** | Closes the preview without changing the source or starting a batch. |

4. After accepting, check the new window's save status and **Active patch**.
   No reading is taken until you select **Measure**. Recover any save failure with
   **Retry save** or **Another folder**; do not acquire the patch again just to
   save it.

If another retained batch owns the selected instrument, open that batch's
window before continuing. The app refuses to replace a different owner silently.
A disabled action reports why it is unavailable; recovering saving or cleanup
may be required before making the continuation choice.

If the preview says a setting is not established, **Cancel** and use the normal
settings/readiness controls to establish it, then reopen the comparison.
**Confirm observed setup…** appears only for identity or fitted conditions the
operator can check. Select a condition, enter its observed value and confirm
that you checked it in both setups. This records your declaration separately
from instrument readback. It cannot override a reported difference, supply
missing scientific units or waive calibration and cleanup. Unknown required
conditions keep **Continue selected pass** unavailable. When requested, review
and acknowledge the reported capability change; a matching model or port alone
does not prove the same instrument or measurement setup.

Newly read settings cannot fill missing identity or scale in an older selected
reading. If those original facts remain unknown, start a new pass. If the file
picker selects the unfinished current batch's own MAT, return to the source
chooser and select **This batch** instead. You can also finish the batch first
and use **Continue chart…**. Previewing the live source does not finish it;
the app refuses to rewrite its chosen disk file as part of continuation.

The chart details identify readings from an earlier batch by original segment
and row and distinguish retained from new attempts. Those rows are not added
to the new batch's ordinary **Readings** table. A successful repeat selects the
new attempt without deleting the old one; a failed repeat preserves the previous
selection. The selected-chart CSV can include inherited readings, while
ordinary acquisition-order files contain this batch's new readings.

Keep the MAT file as the complete portable record. It contains inherited
readings and their source information; moving it does not require the original
folder or a still-running source session. Plain `load` remains useful for
inspection. Unsupported saved schemas and inconsistent references are refused
for continuation. Keep those originals and read the reported reason; the app
does not silently convert them or infer cleanup.

A chart saved while a measurement or its connection cleanup was unfinished is
refused while the batch that saved it is still open. Resolve cleanup and saving
there first. If that owner already resolved cleanup and saved elsewhere, continue
from that open batch, or finish it and open its current MAT file named by the
preview. If that batch has ended, for example
after MATLAB restarted, the preview
shows **Confirm cleanup...**. Record the same two checks as for
[unconfirmed cleanup](#unconfirmed-connection-cleanup) before **Continue
selected pass** or **Start new pass** becomes available. The new batch saves
your declaration; a patch whose measurement never completed shows `!` and no
reading. See [continuation limits and the Session API](../session/README.md#continue-a-chart-in-a-new-session).

### Unconfirmed connection cleanup

For a direct instrument in an ordinary or guided-chart batch, **Cleanup unconfirmed**
means that the application cannot confirm the instrument connection is closed. This
can follow a failed release or an attempt to open a connection that returned no
owner and no confirmation of cleanup, for example a busy or unplugged port.
Selecting a listed port does not prove that opening it succeeded. The warning
does not assert that the instrument is still operating; it records uncertainty
that must be resolved before another measurement.

Any completed reading remains retained. Keep the session and recover its saved
data; do not measure again to recreate the result. Saving or restarting alone
does not confirm cleanup or permit continuation.

When the connection's original owner is still available, select **Retry cleanup**.
It retries that connection's release without reconnecting or measuring. A
failed release keeps the original reading and uncertainty. If cleanup succeeds
but saving fails, use **Retry save**; this does not release or measure again.
Manual confirmation cannot replace the available owner's cleanup. **Confirm cleanup...**
is available only when the app can no longer reach the connection. First
check that no MATLAB batch or other program still uses the instrument's
port (quitting them, or unplugging and reconnecting the instrument cable,
closes it) and that the instrument is not measuring. Then
select **Confirm cleanup...**. Select
**I confirmed the connection is closed.** and **I confirmed the instrument is
idle.**, explain how you checked, then select **Record checked cleanup**. The
explanation must be nonblank and within the 2,048-unit text limit. **Cancel**
before recording leaves the guard in place.

The confirmation records your declaration and attempts to save it; it does not
operate or validate the instrument. If saving fails, close the dialog and use
**Retry save** or **Another folder**. A finished batch stays finished.

## Switch instruments

Choose a model in **Instrument** at the top of the window, then select **Open**.
An existing batch for that model reopens with its own readings, connection
options and settings. A new model asks for a save folder. Cancelling that choice
leaves the current batch visible.

Switching keeps the previous batch available; it does not finish it or change
its instrument. Select that model and **Open** to return. Reading acquisition
still requires **Measure**. While another model is selected but not yet opened,
acquisition controls are disabled to avoid acting on the previous instrument.

## Instrument views

The controls show the data available from the selected model.

**CR-100: XYZ and chromaticity.** This colorimeter does not supply a spectrum.

**CR-250: spectra and host-calculated XYZ**, with instrument XYZ retained separately.

**CR-300: spectra on the instrument-reported wavelength grid.**

**CS-2000: 401-bin spectra and instrument-calculated XYZ.**

## Measurement settings

Ordinary measurements use the model's automatic acquisition settings. Open
**Settings...** only when an experiment needs an override or the current
instrument configuration needs inspection.

1. Select **Read settings** to inspect the connected instrument. This takes no
   measurement. **Last read** shows the reported values; the observation time
   identifies when they were read. Unavailable values remain marked as such.
2. Select a setting. The scrollable help shows its purpose, when to use it,
   tradeoffs, normal operation and manual sources under separate headings.
   Text can be selected and copied.
3. Enable **Override this setting** and enter the requested value. Some settings
   need companion choices; the help identifies these requirements. Invalid
   numeric text stays in the editor so you can correct it before applying.
   Use a period for decimals (`0.5`), without commas or thousands separators.
   When a choice shows a recognized **Last read** value, enabling Override
   puts that value in the draft; select another value if needed. **Last read**
   is a dated observation, not a live check of the instrument.
   For an unread or unrecognized choice, select a value explicitly; the editor
   shows **Choose a value** and cannot apply an incomplete override. A later
   **Read settings** updates the observation without filling that draft for you.
   Matching names include their instrument IDs so distinct entries stay identifiable.
4. Select **Use for next readings**. The request is stored for this session and
   sent when **Measure** starts. **Cancel** discards the draft. The Settings
   button shows the number of active overrides.

In a short settings window, the settings and help can scroll; **Use for next
readings**, **Cancel** and the validation message remain below that content.

**Read settings** stays unavailable while connection cleanup is unconfirmed.
Use the main window's [cleanup action](#unconfirmed-connection-cleanup).
You can still inspect settings and edit unapplied drafts; those actions do not
contact the instrument.

**Clear overrides** clears the draft. Select **Use for next readings** to apply
that change to the session. On the next reading, automatic-profile settings
return to their normal recipe. Other settings, including accessories
and calibration selections, remain on the instrument until explicitly changed;
clearing a checkbox does not undo a physical or calibration change.

At **Measure**, the driver checks the complete request against fresh readback
and avoids rewriting settings confirmed unchanged. An override requests a
value; it does not guarantee a setting-write command. If settings cannot be applied, no measurement starts;
the log explains the problem. Some settings may already have changed. Correct
the request or device setup before deliberately trying again.

Requested settings and available readback are saved with each reading in MAT.
These are separate from the instrument's reported conditions during the exposure.
Per-setting explanations remain available after Finish. Adapters with preparation
guidance also offer **Instrument help** inside this panel.
Automatic recipes, direct commands and model-specific limits are documented in
the [PR settings reference](../drivers/pr/settings.md),
[CR settings reference](../drivers/cr/settings.md), and
[CS settings reference](../drivers/cs2000/settings.md).

| Model-specific controls | Preview (synthetic readback) |
| --- | --- |
| CR-100: colorimeter mode, range and exposure | [Historical CR-100 settings](images/cr100-settings.png) |
| CR-250: exposure, averaging and available corrections | [Current CR-250 settings](images/direct-serial-settings.jpg) |
| CR-300: exposure, exposure multiplier and available corrections | [Historical CR-300 settings](images/cr300-settings.png) |
| CS-2000: speed, ND, synchronization and accessories | [Historical CS-2000 settings](images/cs2000-settings.png) |

## Inspect spectra and results

CR-100 supplies XYZ only, so its window explains that no spectrum is available.
CR-250/300 and CS-2000 expose their recorded spectra and family-specific units.
No spectrum or physical unit is inferred from an XYZ field.

The **spectrum and chromaticity plots are visible together**, with the readings
table below the plots. **Hide readings** gives the plots more room; **Readings**
restores the table. **Expand** and **Compact** adjust the lower workspace. The
plot controls remain available while the table is hidden. The sidebar has four tabs:

| Tab | Purpose |
| --- | --- |
| **Measure** | Name the next sample, add notes, select a port, and start or finish acquisition. |
| **Data** | Inspect the selected reading's labeled results, duration, local completion time, instrument, and notes. **Copy** includes the complete summary. |
| **Compare** | Compare two retained readings using a separately selected Lab white reference. |
| **Color** | Derive an adapted color or a reference-based reflectance/color result without altering measurements. |

Switching tabs never starts a measurement or changes retained readings. Returning
to **Measure** restores the last **All spectra** or **Selected spectrum** view.
Returning to **Compare** restores the selected A/B plots. A derived Color view
returns to measured plots on **Measure**; its analysis remains available to export.
Pending sample inputs stay available in **Measure**. Numeric
results and notes scroll independently in **Data**. Full-precision values and
technical metadata remain in `session.measurements` and the MAT file.
The table bounds the Sample column instead of stretching it across spare space.
**Mode** describes each retained reading's acquisition mode or quantity, not the
currently selected setup or chromaticity coordinate system. Missing information
is shown as **Unavailable**. At wider sizes, **Notes** follows Sample and shows a
one-line preview. Full notes remain in **Data** at every size.

Select one reading and choose **Edit…** above the table to correct its name or
notes. **Save changes** applies to that reading only and saves the revised MAT
snapshot. **Cancel** leaves the reading unchanged. Names may repeat; acquisition
and patch identities remain unchanged. Original annotations are retained in
`batchInfo.readingAnnotations`. Changing the next sample in **Measure** does not
edit an earlier reading.

Editing a finished batch updates its MAT and CSV without reopening acquisition.
If saving fails, the edit remains in the session; use **Retry save** or **Another
folder**. A finished batch remains closed to measurement while recovery is
pending. Editing is paused during acquisition, finalization or unresolved
operation recovery. A draft editor detects changes to the same reading made
from MATLAB; cancel and reopen it before applying another edit.
For spectra, **Data** and **Copy** also show the retained wavelength range,
sample count and spacing. Nonuniform grids are identified explicitly. Output
spacing describes the saved samples, not the instrument's optical bandwidth.

Batch and reading times use the computer's local time with an explicit UTC offset.
UTC remains the canonical saved timestamp. New readings also save acquisition-local
timestamps and the time-zone name, including the offset in effect at each reading.
The copied reading summary includes UTC as well. Event-log timestamps remain UTC.

- **Select a table row, spectrum, or chromaticity point** to inspect that reading.
  Names may repeat; the reading number identifies each record. A `>` marker in
  the table identifies the inspected reading. In ordinary All/Selected views,
  its curve and point are heavier; in Compare A / B, the larger points identify
  the comparison pair even when another table row is inspected.
- **Scroll the table** with the mouse wheel, trackpad or scrollbar. All readings
  remain in the table, in acquisition order.
- **Follow latest** selects the newest reading and follows subsequent measurements.
  Selecting a reading pauses following, preserving the inspected record and
  table position as new measurements arrive. **Follow latest** and plot selections
  scroll the table to the selected reading.
- **All spectra / Selected spectrum / Compare A / B** shows the complete
  overlay, a single reading, or the chosen comparison pair. The chromaticity
  plot keeps all valid batch points. Spectral options require acquired spectra.
  Compare A / B gives both A and B larger circles. XYZ-only instruments show
  these circles in Compare without requiring spectral controls. Changing the
  pair updates the circles; returning to Measure restores the inspected
  reading's emphasis.

Scrolling, selection and display options leave the complete MATLAB struct and
saved MAT data unchanged.

The latest-reading summary shows the last table row's XYZ, units and
chromaticity on one line. Its tooltip contains the full text if the window is
too narrow. It does not change to an older reading when you inspect one.
**Inspecting** or **Following**, beside the lower controls, identifies the
selected reading even with the table hidden. The status footer stays visible
while you switch sidebar tabs, including when acquisition or saving fails.

Light and dark themes follow MATLAB settings. Background opacity and point
outlines adjust when the theme changes, preserving the selected reading.

The coordinate selector changes the table and chromaticity plot between
**CIE 1976 u'v'** (initial view) and **CIE 1931 xy**. It does not change the observer,
recorded XYZ, spectra, or saved files. Black and invalid chromaticities show as
unavailable and have no plotted point. Observer and units come from each reading's
adapter declarations. The PR workflow calculates host XYZ from the acquired
spectrum. A field named Y is not assigned a universal luminance unit. See [device-reported and host-calculated XYZ](../session/color-science.md#device-reported-and-host-calculated-xyz).

The chromaticity background shows approximate sRGB colors within the spectral
locus. Its subdued colors help orient the diagram; they are not calibrated
color matches or a display-gamut measurement. Outlined points remain visible
above the background. The diagram updates when switching between u′v′ and xy.

The chromaticity axes use equal scale and fixed initial limits. **Reset plots**
restores the full diagram and spectrum after zooming. Point/line colors identify
readings. The small swatch beside each sample name is a separate, approximate
sRGB chromaticity preview. Its brightness is normalized, so dim and bright
samples of the same chromaticity have the same swatch. The native preview does
not infer a source white. Selecting a Lab comparison white changes the comparison
without recoloring these previews or altering acquired XYZ. Out-of-gamut RGB values
are clipped; the swatch is a navigation aid, not an appearance match. Black is
shown as black; invalid XYZ has no swatch. When the table has spare width, a
larger preview beside it shows the selected reading using the same conversion
and observer check as the small swatches. Selecting an older reading changes
this preview while the latest-reading summary stays on the newest reading.
The preview hides in compact windows to preserve the table's column space.
The plotted samples do not
establish a device gamut or gamut-coverage percentage.

Scientific basis: [CIE xy](https://cie.co.at/eilvterm/17-23-053),
[CIE 1976 u′v′](https://cie.co.at/eilvterm/17-23-073), and
[ICC sRGB matrix/encoding, A.7–A.8](https://registry.color.org/rgb-registry/files/sRGB.pdf).
The [implementation notes](../session/color-science.md#approximate-display-colors)
identify the additional clipping, brightness normalization and background blending.

## Adapted color and object-color views

Open **Color**, choose a sample and a calculation under **View**, then select **Apply view**.
**Measured view** restores the acquired plots. Changing a reference or option
invalidates the old result until Apply view is selected again.

- **Chromatic adaptation:** choose the source white from D50/D65/A or a reading explicitly
  serving as white; choose the destination white. The derived chromaticity uses
  full Bradford adaptation. The original spectrum is unchanged. This also works
  with XYZ-only CR-100 readings.
- **Reflectance / relight:** choose the sample and a measured white reference acquired
  under the same illumination, geometry and numerical scale. Load the white's
  two-column CSV (`Wavelength_nm`, `Reflectance`, with 1 = 100%), or explicitly
  assume an ideal white to obtain a relative spectral ratio. Confirm the setup,
  then choose D50/D65/A or a measured illuminant spectrum as the target light.
  Spectral devices are required; CR-100 has no spectrum for this calculation.

The same Color controls apply to all compatible retained readings. The
[PR spectral adaptation example](images/pr655-adaptation.png) shows the
measured spectrum beside a separately derived chromaticity. CR-100 supports
adaptation from XYZ only. Reference-based spectral calculations require
eligible spectra; matching plots alone do not establish that eligibility.

The derived result has its own labels, preview and **Export analysis MAT...** action.
Choose a folder, then enter a new `.mat` filename. Existing files are kept;
the export does not offer Replace. The file is staged and then published as a
hard link that cannot replace a name created in the meantime, so the folder must
be on a filesystem with hard links (not exFAT, FAT32 or many SMB mounts).
Cancelling either dialog keeps the applied view.
It does not replace readings in the table or saved batch. Export retains source
readings, selected references and calculation assumptions. See the
[illumination guide](../session/illumination.md) for procedures, scientific equations,
reference-file format, sources and limitations.

## Compare two readings

*Synthetic example using B as the Lab white: B consequently has Lab (100, 0, 0).
Choose the white appropriate to the experiment.*

**Help** beside **Copy comparison** explains the Lab white, White Y and the
separate instrument-calibration procedure. In **Color**, **Help** beside
**Export analysis MAT...** explains adapting whites, the measured object reference
and the target illuminant spectrum. Help is selectable and scrollable; closing it
returns to the measurements without applying an analysis.

1. Open **Compare** and choose **A (ref.)** and **B (test)**. Alternatively,
   select two rows with Command-click on macOS or Ctrl-click on Windows.
   For readings with compatible spectra, the spectrum plot shows A and B
   together, with B dashed. A signed **B − A** difference plot appears below it
   on matching wavelength grids; both share the wavelength zoom. The
   chromaticity plot stays visible.
2. For **ΔE00**, choose a **Lab white**:
   - A **measured reading**, chosen as the common white for both samples and
     using the same XYZ convention and numerical scale; or
   - **D50**, **D65**, or **A (tungsten)**. **White Y** starts at **100** and is
     editable. Adjust it to the experiment's reference-white level on the same
     scale as the sample XYZ. The preset specifies a chromaticity; the default
     does not establish the measured scale or normalize the samples. Clearing
     White Y withholds Lab/ΔE until a positive value is entered.

   For routine sample comparisons, measure the white with the same instrument,
   accessory, settings and setup as the samples. An experiment can deliberately
   vary an acquisition setting or measurement condition: record what changed
   and choose one explicit common Lab white on the readings' scale. The
   differences describe that experiment; they do not by themselves establish
   repeatability under unchanged conditions or conformance. The comparison's
   compatibility checks still apply.

   For comparisons relative to a display's white, select a measured white from
   that display and setup. For a specified target white, choose a matching preset and
   enter the target's Y on the readings' scale. For example, **100** fits readings
   relative to a white of 100, or a target white of **100 cd/m²** when the readings'
   Y is in cd/m².

   **A (ref.)** is the comparison sample. No Lab white is selected automatically.
3. If the **Same XYZ scale (operator)** checkbox appears, tick it only when both
   selected samples and the white use the same XYZ scale. This applies only
   when the adapter marks the readings eligible and retained scale is unknown,
   as can occur for CR-100 or CS-2000.
   The option is available only for an otherwise eligible comparison; it cannot
   override known incompatible conventions. Changing A, B, the white or White Y
   clears the confirmation. Without it, Lab/ΔE stays unavailable for those readings.
4. Inspect **ΔE00**, **Spectral RMS**, and each sample's **L*, a*, b***.
   Scroll for signed Lab, XYZ, and chromaticity differences. A notice identifies
   samples whose Y exceeds the selected white Y (L* > 100), so the reference can be
   checked. This can be intentional; the notice does not prove a scale mismatch or
   alter the data. **Copy comparison** includes sample identities,
   white type and XYZ, preset White Y and source, observer, any accepted scale
   declaration and its UTC timestamp, results, and unavailable-metric explanations.

All signed differences are **B − A**. ΔE00 uses the existing CIELAB conversion
with one common white and CIEDE2000 factors kL = kC = kH = 1. A common scale in
both samples and the white cancels in the Lab ratios; samples are not each
normalized to Y = 100. A change of setup or measurement quantity can still make
a comparison inappropriate. There is no automatic pass/fail threshold.

Sources: [CIE CIELAB](https://cie.co.at/eilvterm/17-23-076) and
[Sharma, Wu and Dalal's CIEDE2000 equations and reference cases](https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/).
CIEDE2000's object-color scope includes appropriately normalized displays
representing objects; it excludes stimuli perceived as primary light sources.
Check the experiment's viewing context before interpreting ΔE00 perceptually.
[CIE's 2014 scope summary](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula);
[superseding 2022 edition](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1).

The presets use published CIE illuminant data and the **CIE 1931 2-degree
observer**. Choosing an illuminant sets the common Lab reference; it does not
predict how the samples would look under different lighting or apply chromatic
adaptation. White selection and White Y do not change XYZ, spectra, plots, or
saved measurements. See [reference data and calculation](../session/illuminant-whites.md).

The additional ΔL*, Δa*, Δb*, ΔC*, and signed ΔH* describe CIELAB differences;
they are not additive parts of ΔE00. ΔH* is the signed hue chord difference;
the interface withholds it when an endpoint has undefined hue (zero chroma).
Differences in xy and u′v′ are dimensionless
and are not CCT-related Duv; XYZ differences retain their measurement scale.

**Spectral RMS** is `sqrt(mean((spectrumB - spectrumA).^2))` on matching,
uniform wavelength samples. It has the same units as the spectra; the displayed
range and step identify its support. No interpolation, extrapolation, or
normalization is applied. It is not an average of color differences.
RMS alone does not show the difference's sign or wavelength location; use the
two curves and signed difference plot to inspect those features.
See the [RMS definition and implementation excerpt](../session/color-science.md#spectral-rms).

An unavailable value shows **Unavailable**. Explanations for unavailable ΔE00 or spectral
RMS appear below the table. Missing
white, White Y or a required scale declaration withholds Lab/ΔE calculations. Missing XYZ does not
prevent a compatible spectral comparison. Black can be compared in Lab, although
its chromaticity is undefined. Missing or incompatible spectra only withhold
spectral RMS and residuals. XYZ, chromaticity and spectral compatibility are
checked separately. Comparison never changes the acquired readings or autosaved batch.
The [command-based example](../session/README.md#compare-retained-readings) returns a
struct that can be retained for analysis.

## Status and log

The status line reports the current operation and reading count. Save problems
appear there; routine file details remain in the log.
Port selection permits an acquisition attempt; it does not verify a connection.
Current measurement and save failures appear there even when the log is closed.
Hover over the status line for its full text.

**Cleanup unconfirmed** takes priority over a finished or saved status because
another acquisition still requires confirmed cleanup. If the batch has finished,
the status also retains **Finished** and its saved count; the warning does not
mean those readings were lost.

The log starts closed to leave room for readings. **Show log** replaces the
table with event history; **Show readings** restores the table. Both plots and
the current sidebar tab stay visible. Toggling preserves the table position,
log filter, selected message and history.

Warnings or errors arriving while the log is closed add an issue count to
**Show log**. Opening the log clears this cue; the count is not a record of
which messages have been read.

- **Follow latest** starts enabled. Clear it before scrolling manually to hold
  a place in the history.
- **Select a message** to pause following and show its full text alongside the
  history. Details scroll separately; **Copy** includes the full timestamp,
  severity and message.
- **Jump to latest** resumes following the newest matching event.
- **All events** / **Warnings/errors** filters the view without deleting history.
  A notice identifies a selected message hidden by the filter. Returning to a
  matching filter restores that selection and its details.

Long summaries are shortened in the list; full text remains in the details and
`session.log`. Selecting another visible message leaves the history in place.

## Close, restore and save recovery

**Closing the window hides it; it does not finish the batch.** The same applies
to ordinary `close all`. Run the launcher again, or `session.show()`, to restore
it. Sessions have no automatic expiry: check the displayed time and folder
before continuing an older batch. **Finish batch**, followed by **New batch**,
starts a separate collection. Quitting MATLAB ends the live session.

**New batch** inherits the current connection settings. A launcher refuses to
restore a retained batch when different settings are requested. To change serial
or timeout options, finish the batch, retain its saved files or a copy of its
readings, then call `delete(session)` and relaunch with the new options supported
by the instrument launcher. The [session guide](../session/README.md#window-integration)
describes this configuration check.

MAT is updated after each completed reading, followed by the chart CSV. The acquisition-order CSV is exported at Finish. If
MATLAB was closed without Finish, the saved MAT retains the completed readings.
The shared [saved-batch export](../session/README.md#export-a-saved-batch) creates the
supporting CSV using the matching instrument adapter, without reconnecting to
the meter or changing the MAT file. With a live session, use **Finish batch**;
if its export fails, **Retry save** retries that export without another reading.

A failed direct-instrument reading preserves its sample name and notes.
Read the error and cleanup status before retrying. If a complete reading was
retained but release failed, keep that result; measuring again would create a
new reading. **Cleanup unconfirmed** requires
[cleanup through the original connection owner](#unconfirmed-connection-cleanup).
Saving again or changing folders does not resolve it. Retry
with **Measure** only when the app makes acquisition available again.

If creating the batch folder, saving MAT, or exporting the acquisition-order CSV fails, recovery controls appear below the
results on every tab. The recovery tooltip and retained log give the error:

| Control | Action |
| --- | --- |
| **Retry save** | Retry persistence without acquiring again. A CSV-only retry leaves the current finalized MAT intact. |
| **Another folder** | Save the retained batch at a new destination without acquiring again; earlier snapshots are retained. |

The save controls act on the current batch even if another instrument is selected
in the header. The next sample's name and notes stay available for the next reading.
In a direct-instrument window with neither readings nor retained chart setup,
use **Another folder** to replace a missing destination. A retained chart setup
or edit can also need saving even when no patches have been measured.
Finalization errors keep acquisition closed while saving is recovered.
Ordinary display errors do not discard valid acquired readings.
Resolve unsaved readings before quitting MATLAB.

See the [session API and saved-data guide](../session/README.md) for command-based
acquisition, ordinary structs, MAT contents, and loading examples.

## Demo without an instrument

To practice the window without connecting a meter, keep **src** on the MATLAB
path and run:

```matlab
session = colormeasure.demo;                    % Choose a model; Measure generates each reading
```

For a ready-filled view, use `session = colormeasure.demo('CR250', 'gallery')`.
Model names are `PR655`, `CR100`, `CR250`, `CR300` and `CS2000`; CR-100 has XYZ
only. These sessions save generated data separately from live-device sessions
and do not validate instrument communication or measurement accuracy.

With the same **src** path entry, the equivalent interactive commands
are `colormeasure.drivers.pr.demoPR655`, `colormeasure.drivers.cr.demoCR100`, `colormeasure.drivers.cr.demoCR250`, `colormeasure.drivers.cr.demoCR300` and `colormeasure.drivers.cs2000.demoCS2000`.
Use **Finish batch** to end a demo, just as for a live session.

The family commands are three kinds. Measurement launchers (`measurePR655`,
`measureCR100`, `measureCR250`, `measureCR300`, `measureCS2000`) open or restore
the live window and publish the session under the name the adapter declares,
`session.workspaceName`. Demo launchers (`demoPR655`, `demoCR100`, `demoCR250`,
`demoCR300`, `demoCS2000`) open synthetic sessions the same way. File-based
routes (`colormeasure.drivers.cr.measureToFile`,
`colormeasure.drivers.cs2000.measureToFile`) drive the driver without a window
and write a MAT file directly.

## Further information

- [Command-line sessions and saved data](../session/README.md)
- [Instrument adapter reference](../session/adapters.md)

- [Demo and device-test quick start](../beta-testing/README.md)

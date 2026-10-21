# CR measurements in the window

Open [openColorMeasure.m](../../../openColorMeasure.m) in MATLAB, click **Run**
and choose **CR-100**, **CR-250** or **CR-300**. Opening the window takes no reading.
Follow the
[measurement-window guide](../../ui/README.md)
for naming samples, selecting a port, measuring, viewing results and finishing
a batch. The differences specific to CR instruments are described below.

## Acquisition settings

Prepare the target and fitted accessory using the
[CR setup guide](preparation.md#ordinary-light-measurements). The selected port's
model is checked when connecting. A port listing is not a model identification;
a wrong model stops before measurement.

Each **Measure** applies the model's automatic recipe and staged settings,
then acquires one reading and releases the connection:

| Model | Automatic recipe | Available results |
| --- | --- | --- |
| CR-100 | Colorimeter mode, automatic exposure and automatic electronic range | Instrument XYZ, CCT and Duv; no spectrum |
| CR-250 / CR-300 | Automatic exposure | Spectrum, host XYZ, instrument XYZ, CCT and Duv |

Accessory, filters, corrections, synchronization, speed and exposure multiplier
remain unchanged unless explicitly overridden. This differs from direct native
`Measure` and `colormeasure.drivers.cr.measureToFile`, which retain the instrument's current settings.

CR-100's automatic recipe requires firmware **1.16 or newer** and usable,
unambiguous Colorimeter-mode capability and readback. Older or unrecognized
firmware cannot use this recipe; use the [direct workflow](README.md#first-measurement)
with the meter correctly configured. A version number alone does not establish
support: unavailable mode capabilities also prevent acquisition.

Choose **Settings...** for supported overrides or **Instrument help** for the
model's preparation instructions. CR-specific considerations are:

- CR-100 manual exposure requires Manual range D.
- CR-250 Averages repeats and averages exposures. CR-100/300 Exposure multiplier
  has a different meaning; consult the control's model-specific help.
- Aperture is read-only; verify that the actual spot and viewing distance suit
  the target.
- Settings may persist in the meter after disconnect. Clearing an accessory or
  correction override does not reset that device selection.

The [settings reference](settings.md) explains capabilities, dependencies and
application receipts. A failed application can leave partial settings changes
and prevents that reading; inspect the receipt before retrying. For longer
acquisitions, the family launchers accept `ResponseTimeout` and
`MeasurementTimeout`. To change them, finish the batch successfully, retain its
saved files or readings, delete the finished session handle, and relaunch with
the [new timeout options](api-and-protocol.md#shared-sessions-and-saved-data);
**New batch** retains the existing options.
A host timeout stops waiting; it does not abort the exposure. Confirm the meter
is idle before following [connection recovery](api-and-protocol.md#errors-and-recovery).

## Interpreting and saving results

For CR-100, primary XYZ comes from the meter. For CR-250/300, primary XYZ is
calculated from the spectrum and `instrumentXYZ` retains the meter's separate
result. The accessory determines whether a spectrum describes radiance,
irradiance, radiant intensity or radiant flux; Y is not always luminance.
CR spectral-density and host-XYZ units remain provisional because the per-nm
denominator has not been confirmed. See [quantities and units](color-science.md#quantities-and-units)
before interpreting absolute values.

CR-100 has no spectrum plot or spectral relighting. For CR-250/300 object-color
work, acquire a matched white reference and object spectrum using the
[reference procedure](preparation.md#reflectance-and-object-color), then use
**Color → View → Reflectance / relight**. This derived view leaves the original
readings unchanged.

For Lab and color differences, all selected XYZ values and the comparison white
must share a scale. When that scale cannot be verified automatically, the
window can request an explicit same-scale confirmation only when the retained
instrument and configuration information are consistent. Confirmation records
an operator declaration; it does not calibrate the instrument or establish
absolute units. See [comparison metadata](api-and-protocol.md#shared-sessions-and-saved-data)
for the required fields and the [color-analysis guide](../../session/illumination.md)
for white selection and derived views.

The MAT file contains every reading, native data and capture metadata. CSV is
an optional flattened export. CR-100 exports one row per reading; CR-250/300
export one row per wavelength. Native `meter.Save` and session MAT files have
different structures, documented in the [saved-data reference](api-and-protocol.md#shared-sessions-and-saved-data).

For the demo and device-test instructions, see the
[quick start](../../beta-testing/README.md).

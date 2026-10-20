# Preparing CR-100, CR-250 and CR-300 measurements

Prepare the instrument before calling `Measure` or `colormeasure.drivers.cr.measureToFile`: the direct
API starts acquisition without a preparation dialog. Read the model-specific
instructions below, or inspect the same concise guidance without connecting:

```matlab
guide = colormeasure.drivers.cr.preparation("CR250");
disp(strjoin(guide.details, sprintf('\n\n')));
```

This helper returns text without connecting or changing settings. The
[settings guide](settings.md) explains each control and provides a complete
read, apply, measure and save example. Native `Measure` uses the existing device
settings. The optional measurement window applies the model's automatic recipe
and staged overrides before each reading, as described below.

## Ordinary light measurements

1. Stabilize the source, aim at the target and choose the intended measurement geometry.
   Check that the instrument's accessory and filter selections match the fitted
   hardware. Follow the installed model's operating instructions for startup
   and maintenance. Close other clients using the meter before connecting.
2. Read current settings with `readSettings()`. Use `applyAutomaticSettings(struct())`
   for automatic exposure on CR250/300. On CR100 the recipe first selects the
   device-reported Colorimeter mode, then automatic exposure and electronic
   range. Unsupported or ambiguous mode capabilities stop automatic application
   before settings change. Accessory, filters, corrections, synchronization, speed and exposure
   multiplier stay inherited unless explicitly overridden. This is the ordinary
   acquisition recipe, not a factory reset.
3. For a controlled experiment, choose supported overrides using the
   [model-specific control descriptions](settings.md#what-each-setting-means).
   Use `applySettings(overrides)` to change only the named settings, or
   `applyAutomaticSettings(overrides)` to combine them with the automatic recipe.
   Check the returned receipt before measuring. Failure after a setter is attempted
   blocks `Measure` until a later successful recovery application or a newly
   constructed connection.
4. Keep the target steady until the whole reading finishes. Save the complete
   reading and its capture metadata. A host deadline changes waiting time;
   it does not change exposure or improve optical precision.

| Model | Preparation details |
| --- | --- |
| CR-100 | Tristimulus XYZ only. The ordinary recipe first selects Colorimeter mode, then automatic exposure and electronic range. Fixed exposure requires Fixed range D. Synchronization matters for modulated sources; exposure multiplier extends exposure. |
| CR-250 | Fixed aperture chosen when ordered: verify spot size and working distance. Use automatic exposure ordinarily. Slow speed is intended for low light; the Averages control repeats and averages exposures, increasing duration. |
| CR-300 | Fixed aperture chosen when ordered: verify spot size and working distance. Use automatic exposure ordinarily. Choose reported speed and exposure multiplier settings suited to the experiment; see the model-specific settings help before changing them. |

Sources: CRI App Manual 1.5.10 §§5.8 and 5.10, printed pp.20–24, and Remote
Communications Manual 1.36 §§4.2.1.6–19, pp.14–19, through
[manufacturer downloads](https://www.colorimetryresearch.com/downloads);
[CR-100 brochure](https://www.colorimetryresearch.com/static/files/products/colorimeters/CR100.pdf),
pp.2 and 4; [CR-250 specifications](https://www.colorimetryresearch.com/products/cr-250)
and [CR-300 specifications](https://www.colorimetryresearch.com/products/cr-300).
The [cosine illuminance receptor](https://www.colorimetryresearch.com/accessories/illuminance-receptor)
changes the measured quantity to illuminance, with irradiance also available
on spectroradiometers. It is calibrated with
its particular instrument and is not interchangeable between meters. Do not
interpret those readings as screen luminance/radiance.

## Using the measurement window

Open **Settings... → Instrument help** for the selected model's preparation
instructions, including accessory and object-color considerations. Reopen it
after changing the physical setup. The [CR window guide](shared-ui.md) explains
the automatic recipe and model-specific controls; the
[shared window guide](../../ui/README.md)
covers sample entry, settings controls and saving.

## Reflectance and object color

An emitted-light reading is not a reflectance spectrum. The CRI app describes
a source/sample measurement sequence (§7.2.3, p.54), and its §11.3, p.70,
describes photometric and integrated-radiometric ratios. Those passages do not
define a complete calibrated-white spectral substitution procedure.

For a white-reference/object measurement:

1. Illuminate a nonfluorescent object externally with a stable light source.
   Measure a white reference and the object with the same illumination,
   viewing geometry, accessory, settings and wavelength grid. Preserve both
   original spectra. Use a setup appropriate to the intended reflectance factor.
2. Retain the reference's wavelength-dependent reflectance data. The host
   calculation is sample/reference × reference factor. An ideal-white assumption
   instead produces a relative spectral ratio; it does not establish calibrated
   reflectance.
3. Use the measured reference and object in **Color → View → Reflectance / relight**.
   The [color-analysis guide](../../session/illumination.md)
   explains reference data, illuminant selection, confirmation and separate
   analysis export. Selecting a white for Lab comparisons alone does not perform
   this reference-substitution calculation.

The reference-substitution equation follows
[NIST SP250-71](https://www.nist.gov/document/sp25071-colorimeterpdf),
p.2, equation (2.1). Its optical setup is a reference 0:45 reflectometer, not
the CR arrangement described here; using the equation does not reproduce that
instrument's uncertainty or validation. The [CIE reflectance-factor definition](https://www.cie.co.at/eilvterm/17-24-070)
requires identical illumination and specified collection geometry. The model
assumes a nonfluorescent object and matched geometry; it does not measure
hemispherical reflectance. **CR-100 cannot provide spectral reflectance or
spectral relighting**, because it supplies XYZ rather than a spectrum.

## Optional corrections

Use an existing correction only when it is appropriate for the source,
accessory and reference procedure. CR100 supports colorimeter matrices and XYZ
matching; the CR250 application manual describes spectral matching. For CR300,
use only supported profiles with an established procedure for the installed
meter. The settings API selects existing profiles and preserves their reported
capture metadata; it does not create or overwrite calibration profiles.

See [existing correction settings](settings.md#what-each-setting-means), CRI App
Manual §§12.2.3 and 14.3.1, pp.77–78 and 83–84, and the manufacturer's
[Colorimeter Utility](https://www.colorimetryresearch.com/products/cri-app)
for preparing profiles. The [scientific guide](color-science.md) explains
absolute spectral units and calculation provenance.

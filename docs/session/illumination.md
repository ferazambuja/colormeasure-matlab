# Adapted color and object-color calculations

The **Color** tab derives a result from retained readings. It never triggers
a measurement or changes the acquired XYZ, spectra, comparisons or batch files.
Choose **Measured view** to return to the acquired plots. The same calculation
is available through [`colormeasure.analysis.deriveIllumination`](../../src/+colormeasure/+analysis/deriveIllumination.m).

## In plain language

Adaptation asks how a color might correspond under a different adapting white.
Object-color calculation asks how a material would respond to another light,
using an estimate of its spectral reflectance. These are different operations.
Neither makes the instrument more accurate or reconstructs missing spectral data.

Related tools: [ArgyllCMS spotread](https://www.argyllcms.com/doc/spotread.html)
and [Colour spectral integration](https://colour.readthedocs.io/en/latest/generated/colour.sd_to_XYZ.html).

## Adapt a color to a white

1. Select a retained sample in **Color**, then choose **Chromatic adaptation**.
2. Choose the **source white**: D50, D65, A, or a reading intentionally serving
   as the adapting white. A colored sample does not automatically reveal the
   light illuminating the scene.
3. Choose the destination white in **To white**, then **Apply view**. The derived chromaticity
   is labeled separately from the measured points. The spectrum stays measured.

This operation supports every family with confirmed CIE 1931 2-degree XYZ,
including CR-100. It uses the linear Bradford transform with full adaptation.
The selected sample and any measured adapting white must each declare the
CIE 1931 2-degree observer in their per-reading data. A batch-level observer
summary does not establish either reading's observer. Missing or incompatible
per-reading declarations leave the acquired data intact and refuse adaptation.
Both white vectors are normalized to Y = 1 before the transform; sample XYZ is
not separately normalized. This models a chromaticity change, not absolute
luminance under a new viewing environment. Compatible white chromaticities can
be used even when an absolute XYZ scale is unknown.

Core operation, implemented in [`colormeasure.colorimetry.adaptXYZ`](../../src/+colormeasure/+colorimetry/adaptXYZ.m):

```matlab
sourceWhite = sourceWhite / sourceWhite(2);
destinationWhite = destinationWhite / destinationWhite(2);
% M is the Bradford cone-response matrix; XYZ values are rows.
T = M \ (diag((M * destinationWhite.') ./ (M * sourceWhite.')) * M);
adaptedXYZ = XYZ * T.';
```

The [library science reference](../colorimetry/science.md)
gives the constants and numerical tests. See also the
[Colour Von Kries/Bradford implementation](https://colour.readthedocs.io/en/latest/generated/colour.adaptation.chromatic_adaptation_VonKries.html).
Full adaptation is an explicit modeling assumption, not a fit to an observer's
viewing conditions. The broader [CIECAM16 model](https://www.cie.co.at/publications/cie-2016-colour-appearance-model-colour-management-systems-ciecam16)
includes additional appearance correlates; those are not calculated here.

## Estimate reflectance and choose a target light

This workflow requires sample and reference **radiance** spectra whose adapter
explicitly permits the ratio calculation. PR radiance code 11, CR radiometric
type 0 and the recognized CS-2000/2000A radiance convention support it, as do
their spectral demos. XYZ-only CR-100, native reflectance, irradiance, radiant
intensity, radiant flux and undeclared quantities do not enter this ratio path.
Matching spectra can still be compared without being eligible for this calculation.
Quantity conventions are described in the [PR protocol notes](../drivers/pr/api.md),
[CR radiometric quantity table](../drivers/cr/color-science.md) and
[CS protocol and data guide](../drivers/cs2000/protocol-and-data.md).

1. Measure a nonfluorescent, externally illuminated reflective object and a
   white reference using stable lighting,
   the same measurement geometry, and compatible numerical units/settings.
   Keep those readings in the same batch. Instrument setup and measurement
   remain the ordinary explicit **Measure** workflow.
2. Select **Reflectance / relight**, the sample and the measured reference reading.
3. Supply the reference's spectral reflectance data, or explicitly choose the
   ideal-white assumption described below. Confirm that the acquisition setup
   satisfies the stated conditions.
4. Select the target illuminant: a bundled CIE D50/D65/A spectrum, or another
   spectral reading intentionally serving as the illuminating spectrum.
   A raw white-tile reading includes the tile’s reflectance; it is not the
   illuminating spectrum unless corrected for that reflectance or explicitly
   treated as a spectrally neutral reference. Do not treat an emissive display
   sample/reference ratio as material reflectance.
5. Select **Apply view**. The left plot shows the derived spectral factor, and the
   chromaticity marker shows its calculated color under the selected light.

The measured sample and reference must have identical wavelength grids and
compatible spectral conventions. A selected illuminant reading must also use
that grid and compatible spectral units. No measured spectrum is interpolated
or extrapolated. A relative illuminant scale is sufficient because its overall
magnitude cancels in the object-color normalization.

The radiance sample/reference ratio likewise cancels a common multiplicative
scale. It does not require a separately confirmed absolute XYZ scale or a new
absolute-unit calibration. Eligibility declares the input quantity; the
operator still confirms the reflective object, common scale and matched setup.
A device's acquisition-mode name alone does not establish whether the measured
object emits light or reflects external illumination.

For matching geometry, the implemented ratio is:

```matlab
reflectanceFactor = sampleSpectrum ./ referenceSpectrum .* referenceReflectance;
```

This is a directional reflectance-factor estimate, not a measurement of all
reflected energy. The [CIE definition](https://cie.co.at/eilvterm/17-24-070)
depends on illumination and collection geometry; factors above one can be
meaningful and are not clipped. Negative sample bins are also retained.
Nonpositive or numerically weak reference bins cause a refusal rather than a
fabricated ratio. The numerical threshold is not an instrument noise assessment.
Fluorescence, changing illumination, stray-light correction and differing
geometries are not modeled.

Konica Minolta's [CS-S10w Professional manual, §2.10.15, printed p.143](https://www.konicaminolta.com/instruments/download/instruction_manual/software/pdf/cs-s10w_16x_pro_instruction_eng.pdf#page=145)
uses characterized white-plate data for its object-color calibration. The
calculation here uses retained spectra and supplied reference data; it does not
write instrument calibration or reproduce the vendor's entire workflow.

### White-reference file

Use two numeric columns with an optional header:

```csv
Wavelength_nm,Reflectance
380,0.982
381,0.982
382,0.983
```

These rows illustrate the format, not a usable calibration file. Supply actual
reference data covering the entire measured range, with increasing wavelengths.
Values are fractions: `0.98` means 98%. Do not supply percentages such as `98`.
Reference-file values are linearly interpolated to the measurement grid, never
extrapolated. The exported analysis retains both supplied and sampled data.

Without characterized data, explicitly assuming reflectance 1 at every
wavelength produces a **relative spectral ratio**. Its calculated colors depend
on that ideal-white assumption and are not characterized reflectance results.

### Object-color integration

For the measured wavelength grid, with target illuminant S and CIE 1931
color-matching functions:

```matlab
k = 100 / sum(S .* ybar);
XYZ = k * [sum(R .* S .* xbar), sum(R .* S .* ybar), sum(R .* S .* zbar)];
```

The common wavelength interval cancels for a uniform grid. An ideal diffuser
has Y = 100 over the **available spectral range**. Limited instrument ranges
are reported; no unmeasured tails are invented. This relative object-color
calculation is separate from the existing radiance-to-XYZ acquisition path.
The bundled [CIE data and attribution](../../resources/colorimetry/README.md)
document the observer, illuminant tables, sampling and checksums.

## Preview and export

Derived XYZ and chromaticity retain the selected destination/target convention.
The color swatch is additionally adapted from that white to D65 for sRGB display,
then uses the existing brightness-normalized, gamut-clipped preview. In adaptation
mode, changing only the destination white changes coordinates but not this swatch:
full linear Bradford source-to-destination-to-D65 transforms compose to the same
source-to-D65 transform. This is expected for corresponding colors. It is an
orientation aid, not a calibrated appearance prediction. The raw table swatches
continue to describe the acquired readings.

**Export analysis MAT...** saves a separate MAT result with source readings, source
spectra/XYZ, references, configuration, assumptions, derived values and UTC time.
Choose a folder and enter a new `.mat` filename. Existing files are retained,
and cancelling either dialog leaves the applied analysis available to export.
For reflectance analysis, `provenance.quantityContext` records the sample and
reference's declared spectral quantity, unit label and adapter eligibility
alongside the operator's setup declaration. The original measurements remain unchanged.
It does not modify or overwrite the measurement batch. Changing a selection or
configuration clears the displayed analysis until **Apply view** is selected again.

Exported `whiteXYZ` is a Y=1 chromaticity reference in adaptation mode; sample
XYZ retains its transformed acquisition scale. Do not use that white directly
for Lab unless a common numerical scale has separately been established.
In reflectance mode, both XYZ and `whiteXYZ` share the explicitly calculated
perfect-diffuser Y=100 convention. `provenance` labels both conventions.

### Adapter declaration for the ratio calculation

`viewData` supplies one logical `reflectanceRatioEligible` value and one
`spectralQuantities` cell per reading. Supported quantities here are `radiance`
and `synthetic radiance`; `reflectanceRatioReasons` may explain a refused row.
Missing, malformed or contradictory declarations withhold this calculation.
[`reflectanceRatioEligibility`](../../src/+colormeasure/+analysis/reflectanceRatioEligibility.m)
checks both rows and their existing spectral comparison keys and grids. The UI
and direct `deriveIllumination` call use the same check. It does not infer
eligibility from instrument name, spectrum presence or a comparison key alone.
Native reflectance must retain its own quantity and use a workflow designed for
that data; declaring a reflective setup does not make it a radiance spectrum.

## Practice without an instrument

With the repository **src** folder on the MATLAB path, run
`session = colormeasure.demo('CR250', 'gallery')` and try the steps above with the
generated readings. Use `CR100` to inspect adaptation with XYZ-only data.
Synthetic readings demonstrate the controls; they do not validate a physical
reflectance setup or reference plate.

<!-- BEGIN TEMPORARY-BETA-TESTING -->

For verification procedures, see the [shared testing guide](../beta-testing/UI.md#illumination-workflow)
and the relevant instrument's hardware checklist.

<!-- END TEMPORARY-BETA-TESTING -->

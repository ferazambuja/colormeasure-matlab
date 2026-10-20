# Measurement color science: calculations and sources

## In plain language

The window displays the XYZ and spectral data supplied by each instrument
adapter. PR and CR spectral workflows calculate XYZ from their acquired spectra;
CR-100 and CS workflows retain instrument-reported XYZ. CR-100 has no spectrum.
Sharing a window does not make these quantities or their scales interchangeable.
The saved records retain their source and units, and comparisons require
compatible declarations. Software agreement does not establish calibration.

## Calculation ownership

The reusable mathematics lives in [colorimetry module](../colorimetry/README.md)
under the `colormeasure.colorimetry` namespace. Command-line acquisition needs spectrum integration
without a graphical interface. Presentation, selection and plotting stay with
the measurement window. The original drivers and `Convert` belong to a
separately supplied, pinned MCSL-Tools checkout used for optional comparisons;
see the [CR comparison guide](../drivers/cr/original-comparison.md).

The [library scientific reference](../colorimetry/science.md) contains
equations, focused source excerpts and primary citations for all library
calculations: spectrum integration, xy/u′v′, Lab, CIEDE2000, illuminant whites,
spectral RMS, previews and CCT. Its [compatibility guide](../colorimetry/compatibility.md)
states preserved conventions and deliberate differences. Attribution and data
licenses are recorded in [the library notices](../colorimetry/THIRD_PARTY_NOTICES.md).

## Device-reported and host-calculated XYZ

Instrument capability and the value selected by a driver are different things.
The following describes the opt-in driver workflows.

| Instrument | Instrument report | Value used by the workflow |
| --- | --- | --- |
| PR-655 / tentative PR-670 | `D2` returns XYZ from the latest reading; `M2` starts a new reading | `XYZ` is calculated from the `M5` spectrum; instrument XYZ is not currently requested |
| CR-100 | `RM XYZ` returns XYZ; `RM CCT` can return CCT/Duv | Instrument XYZ; host-calculated CCT/Duv; no spectrum |
| CR-250 / CR-300 | `RM XYZ` returns XYZ; spectral models also support `RM XYZ10` | Host spectrum-derived `XYZ`; separate `instrumentXYZ` and native `spectralData` are retained |
| CS-2000 / CS-2000A | `MEDR,2,0,01` returns XYZ; block `11` returns 10-degree XYZ | Instrument 2-degree XYZ and a 401-sample spectrum; no host spectral XYZ replacement |

Sources: Photo Research, *PR-655/PR-670 User Manual*, Rev. B (2009-07-29), printed
pp.104, 110–115; Colorimetry Research *Remote Communications v1.36*,
§§4.3.1.27–28, 4.3.1.33, from [manufacturer downloads](https://www.colorimetryresearch.com/downloads);
Konica Minolta *CS-2000/2000A Communication Specifications Rev7*,
[p.43](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf#page=43).

For PR, `M5` followed by `D2` is the documented way to retrieve spectrum and XYZ
from one exposure. Substituting `M2` would take another exposure. The current
integration adds neither command. Instrument observer/units settings and custom
CR matching functions can change instrument results; host integration here
always uses CIE 1931 2-degree CMFs. Numerical equality between host and instrument
XYZ is therefore not assumed. When optional metadata capture is enabled, PR
`D602` is retained as reported current setup, not proof of capture-time settings.

CR and CS session adapters preserve the full native reading in `driverSnapshot`
and retain `instrumentMetadata`. Host display fields do not replace those
records. Per-reading quantity, units, observer and method declarations determine
which calculations are available. In particular, a field called `XYZ` or
`radiance` does not establish an absolute scale. See the detailed
[CR scientific reference](../drivers/cr/color-science.md) and
[CS measurement metadata](../drivers/cs2000/metadata.md) for protocol
fields and unresolved interpretation limits.

`batchInfo.configuration` records host-requested adapter options. This is separate
from device-reported capture metadata and does not establish exposure settings,
units or calibration. The session log includes the adapter's connection summary
when supplied.

## PR spectrum integration and provenance

Excerpt from [colormeasure.drivers.pr.PR655](../../src/+colormeasure/+drivers/+pr/PR655.m):

```matlab
xyz = colormeasure.colorimetry.spectra2XYZ(spectrum, wavelengths);
total = colormeasure.colorimetry.spectralIntegral(spectrum, wavelengths);
```

The library preserves the former `spec2XYZ` convention: CIE 1931 2-degree,
spline interpolation of CMFs only for off-grid samples, zero CMFs outside
360–830 nm, inclusive rectangle weights and the inherited photometric scale.
The PR grids coincide with native integer-nanometre CMFs. No acquired spectrum
is resampled, clipped, normalized or bandwidth-corrected.

PR readings identify the method as
`colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1` in
`xyzMethod`, including direct `pr.measure()` calls. The official CIE table differs from the school
MAT representation by at most 1.11×10⁻¹⁶ per entry, so numerical comparison uses
floating-point tolerances rather than byte equality. The library also rejects
nonfinite inputs and missing, nonpositive or irregular grids instead of guessing.

The inherited scale evaluates air-tabulated CMFs at a vacuum wavelength and is
retained for compatibility; it is not an exact standard-air photometric
realization. See [the derivation and source excerpts](../colorimetry/science.md)
and [BIPM/CIE G1-2019, §§3, 6, 8.2 and 9](https://www.bipm.org/documents/20126/52718503/G1-2019.pdf/692275b2-049d-5222-35de-c975dd1850fc).

## Units and totals

Established spectral radiance in W/(m²·sr·nm) gives Y a nominal cd/m² scale
under this convention. That interpretation requires the actual quantity,
units and optical accessory to agree. A field named `radiance` is insufficient.
PR Table 9 omits code `0` used by the manual's M5 example, so the workflow
preserves `unitsCode` and its instrument-unit label. See
Photo Research, *PR-655/PR-670 User Manual*, Rev. B (2009-07-29), printed pp.113 and 116.

The PR presentation adapter treats the documented radiometric codes **11–14**
as separate declared quantities: radiance, irradiance, radiant intensity, and
radiant flux. Matching codes and recorded conventions permit magnitude and
spectral comparisons; they do not verify calibration or absolute spectral
units. Code `0`, other undefined codes, and photometric codes `111–114` without
an established spectral interpretation do not enable XYZ-magnitude, Lab/ΔE,
spectral RMS, or reference-spectrum reflectance comparisons. These records
remain available for inspection, plotting, and chromaticity calculations when
the saved XYZ method is recognized. Synthetic demos explicitly use a separate
common synthetic scale.

The relevant boundary in `colormeasure.drivers.pr.viewData` is:

```matlab
elseif ismember(reading.unitsCode,11:14)
    quantities={'radiance','irradiance','radiant intensity','radiant flux'};
    quantity=quantities{reading.unitsCode-10};
```

The adapter emits explicit, separate eligibility keys for XYZ, chromaticity,
and spectra. Empty keys withhold a comparison instead of falling back to a
matching but uninterpreted raw code. Exposure, synchronization, aperture, and
corrected filter changes alone do not redefine the physical unit; their
experimental significance still belongs in the measurement interpretation.

`totalRadiance` is the software inclusive sum: `sum(spectrum) * step`.
For a constant spectrum of one, 380:4:780 nm gives 404, not the trapezoidal 400.
`instrumentTotalRadiance` is the separate M5 header result. Neither software
sum nor XYZ is photon-weighted; the instrument photon integral remains separate
as `integratedPhotonRadiance`. These quantities need not agree numerically.

## Synthetic data and validation

[syntheticProfiles](../../src/+colormeasure/+simulation/syntheticProfiles.m) defines illustrative Gaussian
components; [syntheticProfile](../../src/+colormeasure/+simulation/syntheticProfile.m) samples a selected profile
on the requested wavelength grid. It assigns neither physical units nor XYZ.
The family demo adapters provide the model-shaped reading and synthetic
provenance. CR-100 exposes XYZ without spectra; spectral demos retain their
corresponding sample grids. Profiles do not represent standard illuminants,
calibrated sources, or instrument performance models.

The [PR DemoInstrument](../../src/+colormeasure/+drivers/+pr/DemoInstrument.m) calculates XYZ
with the same library converter used by acquisition. Its synthetic total uses
the inclusive uniform-step sum used by the driver; this does not test
meter-header agreement. Demo scale declarations
describe generated values only and do not establish a live instrument's scale.

The [testing guide](../testing/workflow.md) covers numerical references, original-driver
comparisons and model-specific checks. Physical comparisons additionally depend
on the instrument's units, settings and calibration.

## Chromaticity, observer and spectral locus

The window uses retained XYZ; opening, selecting or comparing readings never
recalculates their XYZ from spectra. The reusable coordinate equations and
scaled-ratio excerpts are in [the library reference](../colorimetry/science.md).
The [display wrapper](../../src/+colormeasure/+analysis/chromaticity.m) accepts finite, real, nonnegative XYZ
with at least one positive component. Black and negative integrated XYZ are
withheld from the diagram. Signed spectral bins remain saved. This display
policy is stricter than the library's mathematically defined signed ratios.

The [PR adapter](../../src/+colormeasure/+drivers/+pr/viewData.m) recognizes
`colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1`
as the declared observer and tested MCSL integration convention. Unknown methods withhold
the observer declaration and standard-white presets for the affected reading.
XYZ magnitude and spectral comparisons require their own matching declared
conventions; recognized chromaticity can be compared independently of absolute
scale. Synthetic and physical data remain distinct. A port address is connection
metadata, not a color convention. Matching declarations do not prove the same
physical setup or calibration.

The shared comparison layer treats XYZ/Lab, chromaticity and spectra as separate
domains. Adapters supply `xyzComparisonKeys`, `chromaticityComparisonKeys` and
`spectralComparisonKeys` per reading. Matching chromaticity conventions can
permit coordinate differences even when the XYZ scale is unknown; matching
spectral declarations can permit RMS independently of XYZ. Empty domain keys
withhold that calculation; a missing domain declaration also withholds it.
These checks are application policy, not a claim that matching metadata proves
measurement equivalence.

The full official 360–830 nm, 1 nm observer defines the spectral locus,
independently of the meter's shorter/coarser sampling. [ResultsView](../../src/+colormeasure/+ui/ResultsView.m)
joins its endpoints with the purple boundary. Changing xy/u′v′ changes neither
observer nor data. The outline and sample points do not establish a device gamut.
Sources: [CIE spectrum locus](https://cie.co.at/eilvterm/17-23-056),
[purple boundary](https://cie.co.at/eilvterm/17-23-058), and
[CIE 1976 UCS](https://cie.co.at/eilvterm/17-23-073).

## CIELAB, reference white and color differences

The [pair comparison](../../src/+colormeasure/+analysis/compareReadings.m) delegates numerical calculations:

```matlab
lab=colormeasure.colorimetry.XYZ2Lab(xyz,w);
```

```matlab
result.deltaE00=colormeasure.colorimetry.deltaE00(lab(2,:),lab(1,:));
```

Both readings use the same positive reference white and retain their acquired
scale. Presets select D50/D65/A chromaticity with an editable White Y that starts
at 100 in the window. This is a reference-white default, not an inferred sample
scale; it must match the experiment's XYZ convention. An arbitrary white level
can change Lab and ΔE00. Clearing the field withholds those calculations.
A measured white uses its own XYZ and must share the readings' declared
conventions and experimental setup. Selecting a Lab comparison white does not relight,
individually normalize or chromatically adapt samples. The separate
[Color tab](illumination.md) explicitly derives adaptation or object-color
results with its own references and assumptions. L* > 100 is flagged as
sample Y exceeding white Y, not automatically a mathematical error. The
[white derivation](illuminant-whites.md) retains source checksums and CIE attribution;
the [library guide](../colorimetry/science.md) contains the complete
piecewise Lab and CIEDE2000 calculation stages and their reference tests.

When live CR-100 or CS metadata does not establish a common XYZ scale, the
window withholds Lab/ΔE until an eligible pair and white receive an explicit
same-scale declaration. Eligibility requires matching adapter declarations;
the control cannot override known incompatible quantities or conventions. It
records the selected A, B, white and confirmation time in the comparison result
and copied summary. Changing the pair, white or White Y clears the confirmation.
The declaration is an operator's analysis assumption, not inferred calibration,
a unit conversion, or a modification of the acquired readings. Synthetic demos
already declare their generated scale and need no such confirmation.

CIEDE2000 is an object-color difference model, including appropriately normalized
display stimuli representing objects; its stated scope excludes stimuli perceived
as primary light sources. The UI cannot establish that viewing context. A number
is not a universal visibility/pass-fail threshold. See the CIE
[2014 scope summary](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula)
and [superseding 2022 edition](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1).

The additional component differences use B minus A. ΔL*, Δa*, Δb*, XYZ and
chromaticity differences are coordinate subtraction. Chroma and signed hue chord
are derived from CIELAB geometry in [compareReadings](../../src/+colormeasure/+analysis/compareReadings.m):

```matlab
chroma=hypot(lab(:,2),lab(:,3));
result.deltaC=chroma(2)-chroma(1);
```

```matlab
hue=atan2d(lab(:,3),lab(:,2));
dh=hue(2)-hue(1);
if dh>180,dh=dh-360;elseif dh< -180,dh=dh+360;end
result.deltaH=2*sqrt(chroma(1))*sqrt(chroma(2))*sind(dh/2);
```

The chord is withheld if either chroma is zero (undefined hue). Its sign follows
the shorter B−A hue-angle difference; it is not CIEDE2000's primed hue term.
This reporting convention is distinct from the nonnegative ΔE00 scalar.
[CIE CIELAB coordinates](https://cie.co.at/eilvterm/17-23-076) define the underlying
space; the choice to expose this signed component is an application policy.
Numerical range failures leave the affected metric unavailable with a reason;
compatible spectral comparisons remain independent.

## Spectral RMS

The comparison uses the shared implementation:

```matlab
[value,difference]=colormeasure.colorimetry.spectralRMS(double(a.y(:)),x,double(b.y(:)),y);
```

It requires identical positive, increasing, uniform wavelength grids, retains
signed bins and reports their spectral units, range and step. The library's
wavelength-step tolerance also applies to UI comparisons. No resampling,
perceptual weighting or white normalization occurs. See the
[library RMS derivation and excerpt](../colorimetry/science.md) and
[MATLAB RMS definition](https://www.mathworks.com/help/matlab/ref/rms.html).

RMS discards the sign and location of a difference: `[1 1 1 1]` and `[2 0 0 0]`
both have RMS 1 but describe different spectral changes. The view therefore
shows both the overlay and signed B−A residual. Multiplying a spectrum by two
preserves chromaticity but usually changes its RMS difference. RMS is not ΔE,
a percentage, integrated energy, statistical significance or uncertainty;
wavelength bins are not repeated measurements.

## Approximate display colors

Reading swatches and the chromaticity-diagram background use
`colormeasure.colorimetry.previewColor`. Its matrix, clipping,
peak-linear-channel normalization and sRGB encoding are documented with excerpts
in [the library reference](../colorimetry/science.md), based on
[ICC sRGB, A.7–A.8](https://registry.color.org/rgb-registry/files/sRGB.pdf).
Normalization discards measured brightness; clipping can change chromaticity.
Direct reading swatches and the diagram background do not infer a source white.
The plotted xy/u′v′ coordinates remain the original acquired data. The separate guided-chart diagram uses
[`relativeColor`](../colorimetry/chart-colors.md) to preserve shared-scale brightness.
The comparison white does not recolor the acquired-reading previews. The
Color tab provides a derived swatch with its own white and adaptation metadata.
Both are orientation aids,
not calibrated appearance, ICC transforms or measured gamuts.

The UI retains diagram geometry and masking. Excerpt from
[chromaticityBackground](../../src/+colormeasure/+ui/chromaticityBackground.m), inverting the
[CIE coordinate equations](https://cie.co.at/eilvterm/17-23-073) at Y = 1:

```matlab
if strcmp(mode, 'uv')
    X = 9*a ./ (4*b);
    Z = (12-3*a-20*b) ./ (4*b);
else
    X = a ./ b;
    Z = (1-a-b) ./ b;
end
```

Zero denominators and nonphysical XYZ are masked, along with pixels outside
the locus/purple boundary. The resulting RGB is blended with the UI theme.
Black swatches remain black; invalid XYZ has no swatch. Separate curve/point
colors identify reading indices using `hsv2rgb`; they have no colorimetric meaning.

## Tests

The [shared testing guide](../testing/workflow.md#numerical-and-presentation-checks) describes
reference cases, input checks and presentation tests.

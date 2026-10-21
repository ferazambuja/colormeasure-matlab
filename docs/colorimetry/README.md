# Color calculations

The `colormeasure.colorimetry` package converts spectra to XYZ, calculates chromaticity and
color differences, and supports explicitly selected adaptation and reflectance
calculations. It is used by the acquisition and analysis workflows in
`colormeasure` and can also be called from MATLAB scripts.

Requires base MATLAB R2026b or newer. Software checks have run on R2026b;
earlier revisions were tested with MATLAB R2026a Update 5. Test results apply
to the source revision and MATLAB version recorded in each report. Historical
[performance measurements](performance.md) remain attributed to R2026a.

## Quick start

Set MATLAB Current Folder to the project root and run `setupColorMeasure`.
Wavelengths are explicit double-precision values, in nanometres:

```matlab
setupColorMeasure
lambda = (380:4:780)';
spectrum = exp(-0.5*((lambda-550)/40).^2); % Synthetic spectral density
XYZ = colormeasure.colorimetry.spectra2XYZ(spectrum, lambda);
xyY = colormeasure.colorimetry.XYZ2xyY(XYZ);
uvY = colormeasure.colorimetry.XYZ2uvY(XYZ);              % CIE 1976 u′v′ and unchanged Y
```

For many readings on one grid, prepare the integrator once:

```matlab
integrator = colormeasure.colorimetry.XYZIntegrator(lambda);
XYZ = integrator.convert([spectrum, 0.8*spectrum]); % Two rows of XYZ
```

For Lab and ΔE00, supply one reference white in the **same XYZ scale** as both
samples. The following reference-white values are illustrative, not a default:

```matlab
whiteXYZ = [95.05 100 108.88];
Lab = colormeasure.colorimetry.XYZ2Lab([40 42 35; 41 42.5 36], whiteXYZ);
difference = colormeasure.colorimetry.deltaE00(Lab(1,:), Lab(2,:));
```

`colormeasure.colorimetry.illuminantWhite('D65', whiteY)` supplies a standard-white chromaticity
with an explicitly chosen `whiteY`. D65 alone does not specify a luminance or
measurement scale. It does not relight or adapt the measured samples.

## Functions

| Function | Result |
| --- | --- |
| `colormeasure.colorimetry.spectra2XYZ` | Spectra → CIE 1931 2-degree XYZ, explicit uniform grid |
| `colormeasure.colorimetry.XYZIntegrator` | Prepared reusable integrator for a fixed grid |
| `colormeasure.colorimetry.observer` | Bundled 360–830 nm, 1 nm CIE 1931 CMFs |
| `colormeasure.colorimetry.spectralIntegral` | Inclusive uniform-step spectral sum |
| `colormeasure.colorimetry.XYZ2xyY`, `XYZ2uvY`, `xyY2uvY` | Chromaticity with Y retained |
| `colormeasure.colorimetry.XYZ2Lab` | CIELAB relative to an explicit positive white |
| `colormeasure.colorimetry.deltaE00` | CIEDE2000, kL = kC = kH = 1 |
| `colormeasure.colorimetry.XYZ2CCT` | CCT/Duv under the retained CR workflow policy |
| `colormeasure.colorimetry.illuminantWhite` | CIE-derived D50, D65 or A white with explicit Y |
| `colormeasure.colorimetry.adaptXYZ` | Full Bradford adaptation; explicit source/destination whites |
| `colormeasure.colorimetry.reflectanceFromReference` | Sample/reference spectral ratio with characterized plate factor |
| `colormeasure.colorimetry.reflectanceXYZ` | Spectral factor under a target SPD; perfect-diffuser Y=100 |
| `colormeasure.colorimetry.illuminantSpectrum` | Bundled D50, D65 or A SPD on the requested grid |
| `colormeasure.colorimetry.spectralRMS` | Raw RMS and signed B − A residual on identical grids |
| `colormeasure.colorimetry.previewColor` | Approximate, brightness-normalized sRGB swatch; an optional explicit white enables Bradford adaptation to D65 |
| `colormeasure.colorimetry.relativeColor` | Approximate sRGB with explicit white/observer and shared relative scale |

Use the `colormeasure.colorimetry.` prefix shown above. See [compatibility and shapes](compatibility.md),
[science and limitations](science.md),
[adaptation and reflectance](adaptation-reflectance.md), [relative chart colors](chart-colors.md),
[reference-based chart warnings](position-checks.md), [CCT details](cct.md), and
[performance measurements](performance.md).

## Checks

```matlab
report = colormeasure.runTests;
```

Tests include frozen school-reference results, explicit input/shape policies,
CIE data identity, Bradford reference/invariant checks, reference-ratio and
perfect-diffuser integration checks, and all 34 published CIEDE2000 reference pairs. These are
software tests, not instrument calibration or perceptual validation.

The optional tools in `tools/colorimetry/` regenerate school-reference fixtures or benchmark
against a supplied school checkout. `benchmarkMATLAB` compares public MATLAB
functions and requires Image Processing Toolbox for its Lab/ΔE00 comparisons.
Ordinary use and tests need neither that toolbox nor the school checkout.
See [benchmark commands and results](performance.md). These timings measure
computation, not the time to acquire a spectrum.

## Scope and sources

This library covers the calculations used by the PR/CR acquisition and
measurement-window workflow. CS-2000 supplies instrument XYZ directly; this
library does not replace those values. Explicit Bradford adaptation and
reference-based spectral reflectance calculations return separate derived
results. They require stated whites, measurement conditions and reference data;
selecting a Lab white alone does not invoke them. Other observers, appearance
models, fluorescence compensation and calibrated RGB rendering remain outside
the implemented scope.

[Code license](../../licenses/colorimetry-MIT.txt), [third-party attribution](THIRD_PARTY_NOTICES.md),
[CIE data and derived-white terms](../../resources/colorimetry/README.md), and
[test-reference provenance](../../tests/colorimetry/data/README.md) are distributed with the code.

## Source identity and attribution

Functions use the `colormeasure.colorimetry` namespace to keep calls distinct from other MATLAB
conversions.

The checked-out Git commit identifies this implementation. Record that commit
when reporting reproducible calculations. The [source manifest](../../resources/provenance/colorimetry-source.json)
records repository-relative paths and hashes for the colorimetry distribution.
Reference data is bundled in `resources/colorimetry`; calculations do not load a
school `Convert` folder.

The [attribution record](THIRD_PARTY_NOTICES.md) distinguishes new implementation
work, adapted school code and third-party data. Keep the supplied code and data
notices when distributing the package.

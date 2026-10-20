# Color calculations and scientific boundaries

## In plain language

This library converts sampled spectra into color coordinates and compares
compatible readings. The equations, numerical choices, and data sources are
listed here so that results can be reproduced and differences from the school
functions can be understood. Agreement between implementations tests software;
it does not establish an instrument's calibration, physical units, or visual
agreement under a particular viewing condition.

Code blocks below are focused excerpts from this library, with surrounding input
checks omitted where stated. Links lead to the complete implementations. The
original school `Convert` functions are separate reference implementations;
these functions use the `colormeasure.colorimetry` namespace and their own bundled data.

## Calculation map

| Operation | Implementation | Result and main convention |
| --- | --- | --- |
| Observer data | [`observer`](../../src/+colormeasure/+colorimetry/observer.m) | CIE 1931 2-degree CMFs, 360–830 nm at 1 nm |
| Spectrum to XYZ | [`spectra2XYZ`](../../src/+colormeasure/+colorimetry/spectra2XYZ.m), [`XYZIntegrator`](../../src/+colormeasure/+colorimetry/XYZIntegrator.m) | One XYZ row per spectrum; explicit uniform wavelength grid |
| Spectral total | [`spectralIntegral`](../../src/+colormeasure/+colorimetry/spectralIntegral.m) | Inclusive rectangle sum, retaining signed samples |
| Chromaticity | [`XYZ2xyY`](../../src/+colormeasure/+colorimetry/XYZ2xyY.m), [`XYZ2uvY`](../../src/+colormeasure/+colorimetry/XYZ2uvY.m), [`xyY2uvY`](../../src/+colormeasure/+colorimetry/xyY2uvY.m) | xy or 1976 u′v′, retaining the input Y |
| CIELAB | [`XYZ2Lab`](../../src/+colormeasure/+colorimetry/XYZ2Lab.m) | One explicit positive reference white |
| CIEDE2000 | [`deltaE00`](../../src/+colormeasure/+colorimetry/deltaE00.m) | ΔE00 with kL = kC = kH = 1 |
| Reference whites | [`illuminantWhite`](../../src/+colormeasure/+colorimetry/illuminantWhite.m) | D50, D65, or A at an explicit White Y |
| Adaptation | [`adaptXYZ`](../../src/+colormeasure/+colorimetry/adaptXYZ.m) | Full linear Bradford; sample XYZ scale retained |
| Reference ratio | [`reflectanceFromReference`](../../src/+colormeasure/+colorimetry/reflectanceFromReference.m) | Spectral factor using a measured, characterized reference |
| Reflectance integration | [`reflectanceXYZ`](../../src/+colormeasure/+colorimetry/reflectanceXYZ.m), [`illuminantSpectrum`](../../src/+colormeasure/+colorimetry/illuminantSpectrum.m) | Explicit target SPD; grid-specific perfect diffuser Y=100 |
| Spectral comparison | [`spectralRMS`](../../src/+colormeasure/+colorimetry/spectralRMS.m) | RMS and signed B−A residual on identical grids |
| Display swatch | [`previewColor`](../../src/+colormeasure/+colorimetry/previewColor.m) | Brightness-normalized approximate sRGB preview |
| CCT and Duv | [`XYZ2CCT`](../../src/+colormeasure/+colorimetry/XYZ2CCT.m) | Near-white description; see [CCT calculation](cct.md) |

The [adaptation and reflectance guide](adaptation-reflectance.md) gives the new
operations' equations, source excerpts, data attribution, measurement
assumptions and limits. Those explicit operations are separate from the
unchanged acquired-spectrum and acquired-XYZ conversions described below.

## 1. Observer data and spectral integration

### Data and sampling

The bundled observer is the unmodified [CIE 2019 dataset,
DOI 10.25039/CIE.DS.xvudnb9b](https://doi.org/10.25039/CIE.DS.xvudnb9b).
Its source is CIE 018:2019, Table 6. The [data record](../../resources/colorimetry/README.md)
contains download links, checksums, attribution, and the CC BY-SA 4.0 terms.
`observer` reads this package's data folder and validates the table shape and
wavelength column; MATLAB's current folder does not select the observer.

`XYZIntegrator` samples the CMFs once for a supplied grid:

```matlab
if all(wavelength==fix(wavelength))
    matching = zeros(numel(wavelength),3);
    inside = wavelength>=native(1) & wavelength<=native(end);
    matching(inside,:) = cmf(wavelength(inside)-native(1)+1,:);
else
    matching = interp1(native,cmf,wavelength,'spline',0);
end
```

Integer-nanometre samples use direct indexing. Other samples retain the school's
spline interpolation. Values outside 360–830 nm receive zero CMF weight. The
[CIE dataset metadata](https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv_metadata.json)
specifies linear interpolation and zero extrapolation: **spline is a retained
compatibility choice**, not a claim that CIE requires spline interpolation.
The input spectrum itself is not resampled by this function.

### Photometric scale and sum

The prepared scale is:

```matlab
peakNm = (299792458 / 540e12) / 1e-9;
obj.Wavelength = wavelength;
obj.Step = step;
obj.Scale = 683*obj.Step / interp1(native,cmf(:,2),peakNm);
```

The conversion then applies the matrix product:

```matlab
XYZ = obj.Scale .* (obj.MatchingFunctions.' * spectra).';
```

Each wavelength receives its full interval weight, including both endpoints.
The method is an inclusive rectangle sum, not a trapezoidal integral. Signed
spectral bins remain signed; no spectrum is individually normalized or clipped.
The scale stays outside the matrix product to preserve the school's operation
order. The official CSV and inherited school MAT observer differ by at most
1.11×10⁻¹⁶ in one table value, so matching results means agreement within
floating-point rounding, not identical bytes.

The inherited denominator samples the air-tabulated y-bar function at the
vacuum wavelength c/(540 THz), approximately 555.1712185 nm. It gives a scale
near 683.016758 before the wavelength step, rather than the approximately
683.002 lm/W standard-air convention. This difference is retained explicitly
for compatibility. [BIPM/CIE, *Principles Governing Photometry*, 2019,
§§3, 6, 8.2 and 9](https://www.bipm.org/documents/20126/52718503/G1-2019.pdf/692275b2-049d-5222-35de-c975dd1850fc).

Only an established spectral-radiance input in W/(m²·sr·nm) supports nominal
luminance-scaled Y under this convention. A field named `radiance` does not
establish its physical units. The library does not infer an accessory's
measurement quantity or an instrument's units code, apply an illuminant, or
turn a reflectance-factor spectrum into emission.

### Grid and array contract

Wavelengths are explicit, finite, positive, increasing, uniform, and double
precision. At least two samples are required. The implementation checks
spacing rather than using only the first interval:

```matlab
tolerance = min(4*eps(max(1,max(abs(wavelength)))),abs(steps(1))*1e-8);
if any(wavelength<=0) || any(steps<=0) || any(~isfinite(steps)) || ...
        any(abs(steps-steps(1))>tolerance)
    error('colormeasure:Colorimetry:Wavelength','Wavelengths must be positive, increasing and uniformly spaced.');
end
```

The tolerance allows small double roundoff, capped relative to the step so that
nearly coincident but irregular samples are not accepted. Build fractional grids
in double precision; converting an already rounded single-precision grid to
double cannot restore its intended spacing. The code does not guess missing
wavelengths or infer optical bandwidth from sampling interval.

Spectra may be finite real single or double, with N wavelengths in rows or
columns. For an N×N input, spectra occupy columns. Results are always M×3 double
XYZ for M spectra. [`spectra2XYZ`](../../src/+colormeasure/+colorimetry/spectra2XYZ.m) caches one prepared
grid; an explicit immutable `XYZIntegrator` avoids repeated setup when scripts
alternate among several grids. This changes preparation work, not the equation.
See [measured performance and tradeoffs](performance.md).

### Unweighted spectral total

[`spectralIntegral`](../../src/+colormeasure/+colorimetry/spectralIntegral.m) uses the same grid contract
and endpoint convention:

```matlab
if size(spectra,1)==n
    value = sum(double(spectra),1).' * step;
elseif size(spectra,2)==n
    value = sum(double(spectra),2) * step;
```

The omitted `else` rejects a shape that does not match the wavelengths.
For a constant input of 1 at `380:2:780`, the result is 201×2 = 402, while
`trapz` would give 400. This is an intentional inherited convention, not a
precision claim. Input density per nm times the nm interval establishes the
integral's units only when those input units are known. No photon weighting is
applied. An instrument-reported integrated quantity may use a different grid,
endpoint treatment, bandwidth correction, or unit convention and should retain
its own identity rather than be overwritten by this total.

## 2. Chromaticity coordinates

The CIE xy coordinates divide X and Y by X+Y+Z. They describe chromaticity;
the retained third component is the original Y, whose physical interpretation
depends on the input quantity. [CIE S 017:2020, term
17-23-053](https://cie.co.at/eilvterm/17-23-053).

`XYZ2xyY` scales each row before the sum to prevent finite large inputs from
producing an overflowing denominator:

```matlab
scale = max(abs(rows), [], 2);
scale(scale == 0) = 1;
scaled = rows ./ scale;
denominator = sum(scaled, 2);
coordinates = scaled(:, 1:2) ./ denominator;
coordinates(denominator == 0, :) = nan;
coordinates(~isfinite(coordinates)) = nan;
xyY = [coordinates rows(:, 2)];
```

`XYZ2uvY` uses CIE 1976 u′v′ directly, with the same initial row scaling:

```matlab
denominator = scaled(:, 1) + 15 * scaled(:, 2) + 3 * scaled(:, 3);
coordinates = scaled(:, 1:2) .* [4 9] ./ denominator;
coordinates(denominator == 0, :) = nan;
coordinates(~isfinite(coordinates)) = nan;
uvY = [coordinates rows(:, 2)];
```

`xyY2uvY` uses the equivalent xy formula, scaling the constant term along with
the coordinates:

```matlab
scale = max([abs(coordinates) ones(size(rows, 1), 1)], [], 2);
scaled = coordinates ./ scale;
denominator = -2 * scaled(:, 1) + 12 * scaled(:, 2) + 3 ./ scale;
uvY = scaled .* [4 9] ./ denominator;
uvY(missing | denominator == 0, :) = nan;
uvY(~isfinite(uvY)) = nan;
if size(rows, 2) == 3, uvY(:, 3) = rows(:, 3); end
```

These are **CIE 1976 u′v′**, not CIELUV L*u*v*. CCT uses CIE 1960 `(u,v)` with
v = 2v′/3. [CIE S 017:2020, term
17-23-073](https://cie.co.at/eilvterm/17-23-073).

Finite signed values are permitted for mathematical use. A zero denominator,
including black, yields unavailable chromaticities (`NaN`); it does not assign
black an arbitrary chromaticity. Direct u′v′ can remain defined for signed XYZ
whose X+Y+Z is zero, whereas the school's intermediate route through xy cannot.
The input Y is never normalized in the returned result. Paired unavailable xy
values can pass through `xyY2uvY`; other nonfinite inputs are rejected. UI
policies may separately withhold signed or otherwise inapplicable samples.

Coordinate functions retain row/column orientation. An ambiguous 3×3 XYZ array
means row samples. See each function's help for the corresponding xy/xyY shape
rule. This makes orientation deterministic without a warning or guessed switch.

## 3. CIELAB and reference-white meaning

[`XYZ2Lab`](../../src/+colormeasure/+colorimetry/XYZ2Lab.m) requires one finite, strictly positive 1×3
white in the **same XYZ scale as the samples**. The calculation is:

```matlab
relative = rows ./ double(whiteXYZ);
if any(~isfinite(relative), 'all')
    error('colormeasure:Colorimetry:NumericRange', 'XYZ divided by the reference white exceeds the numeric range.');
end
nonlinear = relative > (6 / 29)^3;
f = zeros(size(relative));
f(nonlinear) = relative(nonlinear).^(1/3);
f(~nonlinear) = (841 / 108) * relative(~nonlinear) + 4 / 29;
Lab = [116 * f(:, 2) - 16, 500 * (f(:, 1) - f(:, 2)), ...
    200 * (f(:, 2) - f(:, 3))];
```

This is the CIE piecewise function: the nonlinear branch applies only above
(6/29)³; lower and negative ratios use the real linear branch. Each component's
function is evaluated once. A common scale on samples and white cancels.
Black can have valid Lab even though its chromaticity is undefined.
L*>100 indicates sample Y above the chosen White Y and does not by itself
establish an error. No chromatic adaptation or clipping is performed.
[CIE S 017:2020, term 17-23-076](https://cie.co.at/eilvterm/17-23-076).

A reference white is an experimental choice, not something the software can
infer from a light's name. For an emissive measurement, selecting D65 specifies
a white chromaticity but still requires a justified White Y. An arbitrary
unconfirmed value of 100 can change Lab and ΔE00 substantially. Saving the white
XYZ, its source, and the sample scale makes the comparison reproducible.

## 4. CIEDE2000

[`deltaE00`](../../src/+colormeasure/+colorimetry/deltaE00.m) implements the published equations with
kL = kC = kH = 1. It accepts paired Lab arrays or one reference row broadcast
over the samples. Both Lab values must use the same appropriate reference white.
The excerpts below show the calculation stages; the linked function also
contains input validation and array-orientation handling.

Modified a′, C′, and h′ are obtained from the average-chroma gain. `hypot` avoids
forming unnecessary squared chroma components:

```matlab
meanChroma = chroma1 / 2 + chroma2 / 2;
gain = 0.5 * (1 - sqrt(chromaFraction(meanChroma)));
a1 = (1 + gain) .* first(:, 2);
a2 = (1 + gain) .* second(:, 2);
prime1 = hypot(a1, first(:, 3));
prime2 = hypot(a2, second(:, 3));
if any(~isfinite(prime1) | ~isfinite(prime2))
    error('colormeasure:Colorimetry:NumericRange', 'Modified Lab chroma exceeds the numeric range.');
end
hue1 = mod(atan2(first(:, 3), a1) * (180 / pi), 360);
hue2 = mod(atan2(second(:, 3), a2) * (180 / pi), 360);
hue1(prime1 == 0) = 0;
hue2(prime2 == 0) = 0;
achromatic = prime1 == 0 | prime2 == 0;
```

Zero chroma and a hue pair crossing the 0°/360° seam require explicit branches:

```matlab
hueDifference = hue2 - hue1;
hueDifference(hueDifference > 180) = hueDifference(hueDifference > 180) - 360;
hueDifference(hueDifference < -180) = hueDifference(hueDifference < -180) + 360;
hueDifference(achromatic) = 0;
hueSum = hue1 + hue2;
meanHue = hueSum / 2;
acrossSeam = abs(hue1 - hue2) > 180 & ~achromatic;
belowTurn = acrossSeam & hueSum < 360;
aboveTurn = acrossSeam & hueSum >= 360;
meanHue(belowTurn) = (hueSum(belowTurn) + 360) / 2;
meanHue(aboveTurn) = (hueSum(aboveTurn) - 360) / 2;
meanHue(achromatic) = hueSum(achromatic);
```

This implements the published mean-hue wrap. The fraction C⁷/(C⁷+25⁷) is evaluated
without raising a large C to the seventh power:

```matlab
ratio = zeros(size(chroma));
small = chroma <= 25;
power = (chroma(small) / 25).^7;
ratio(small) = power ./ (1 + power);
ratio(~small) = 1 ./ (1 + (25 ./ chroma(~small)).^7);
```

The lightness, chroma, and hue weights and the rotation term are:

```matlab
meanLightness = first(:, 1) / 2 + second(:, 1) / 2;
meanPrime = prime1 / 2 + prime2 / 2;
T = 1 - 0.17 * cosd(meanHue - 30) + 0.24 * cosd(2 * meanHue) + ...
    0.32 * cosd(3 * meanHue + 6) - 0.20 * cosd(4 * meanHue - 63);
offset = abs(meanLightness - 50);
lightnessScale = 1 + (0.015 * offset) .* (offset ./ hypot(sqrt(20), offset));
chromaScale = 1 + 0.045 * meanPrime;
hueScale = 1 + (0.015 * meanPrime) .* T;
rotation = -2 * sqrt(chromaFraction(meanPrime)) .* ...
    sind(60 * exp(-((meanHue - 275) / 25).^2));
```

The lightness weight uses `hypot` to avoid squaring a large lightness offset.
These are algebraic rearrangements of the published terms, not new weights.

The final weighted terms complete the square in the same CIEDE2000 quadratic
form, reducing intermediate overflow:

```matlab
lightnessTerm = (second(:, 1) - first(:, 1)) ./ lightnessScale;
chromaTerm = (prime2 - prime1) ./ chromaScale;
% Normalize before multiplying square roots to avoid the C1'*C2' product.
hueTerm = (2 * sind(hueDifference / 2)) .* ...
    (sqrt(prime1) ./ sqrt(hueScale)) .* (sqrt(prime2) ./ sqrt(hueScale));
% Complete the square in Eq. 22 and use hypot, avoiding unnecessary squares
% of large differences. This is algebraically the same quadratic form.
difference = hypot(hypot(lightnessTerm, chromaTerm + (rotation / 2) .* hueTerm), ...
    sqrt(max(0, 1 - (rotation / 2).^2)) .* hueTerm);
```

The equations, hue cases, and 34 numeric reference pairs come from
[Sharma, Wu & Dalal (2005), *The CIEDE2000 Color-Difference Formula:
Implementation Notes, Supplementary Test Data, and Mathematical Observations*,
equations 2–22](https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/ciede2000noteCRNA.pdf).
The authors' MATLAB/Excel software was not copied. Tests check the published
rounded values within 5×10⁻⁵. These numerical checks do not establish a universal
visibility threshold for arbitrary emissive or HDR conditions; see the
[CIE description of ISO/CIE 11664-6](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1).

## 5. D50, D65, and A reference whites

[`illuminantWhite`](../../src/+colormeasure/+colorimetry/illuminantWhite.m) uses these bundled constants:

```matlab
names={'D50','D65','A'};
normalized=[0.964240837883784 1 0.825128116837737; ...
            0.950470558654283 1 1.08882873639588; ...
            1.09850315268456 1 0.355849301338885];
```

After name and Y validation, the selected row is scaled:

```matlab
index=find(strcmp(name,names),1);
xyz=normalized(index,:)*Y;
```

Each row was calculated as the sum of illuminant SPD times the CIE 1931 CMFs
over 360:1:830 nm, divided by the resulting Y. Sampling the same published D50
and observer tables every 5 nm
gives approximately `[96.421748, 100, 82.520912]` at Y = 100. This rounds to
`[96.422, 100, 82.521]`, the D50 reference also specified in
[ITU-T T.42 (2003)/Cor.1 (2004)](https://www.itu.int/ITU-T/recommendations/rec.aspx?lang=en&rec=7240).
The 1 nm result is `[96.424084, 100, 82.512812]`, so the constants intentionally
differ. This numerical agreement does not establish that the historical
reference was generated from these exact newer files. The
[data record](../../resources/colorimetry/README.md#d50-sampling-reconciliation) gives the input
checksums and reproduction method.

Sources: [CIE D50](https://doi.org/10.25039/CIE.DS.etgmuqt5),
[CIE D65](https://doi.org/10.25039/CIE.DS.hjfjmt59),
[CIE A](https://doi.org/10.25039/CIE.DS.8jsxjrsn), and the
[CIE 1931 observer](https://doi.org/10.25039/CIE.DS.xvudnb9b).
The [data record](../../resources/colorimetry/README.md) contains the derivation convention and
checksums. These derived constants retain CIE attribution and CC BY-SA 4.0
terms, separately from the MIT implementation.

The `illuminantWhite` API requires an explicit positive White Y. The measurement
window supplies an editable initial value of 100 for preset Lab whites; it does
not infer the instrument's scale or rescale sample XYZ. Adjust that reference
level to the experiment. The returned structure identifies the white, observer,
source, and method. Choosing
a white changes the Lab reference only: it does not relight an emission
spectrum, multiply a sample by an illuminant, or perform chromatic adaptation.

## 6. Spectral RMS and the signed residual

[`spectralRMS`](../../src/+colormeasure/+colorimetry/spectralRMS.m) requires identical increasing uniform
wavelength grids. It does not interpolate one spectrum onto another. After
validation, its calculation is:

```matlab
residual = double(b(:))-double(a(:));
if any(~isfinite(residual)), error('colormeasure:Colorimetry:NumericRange','Residual exceeds finite range.'); end
scale = max(abs(residual));
if scale==0
    rmsDifference = 0;
else
    % Scale before the native norm to avoid extreme-value overflow/underflow.
    % The normalized RMS cannot exceed one; cap floating-point roundoff there.
    rmsDifference = scale*min(1,norm(residual/scale,2)/sqrt(numel(residual)));
end
```

RMS is `sqrt(mean((B−A).^2))`, in the input spectral units. The scaled evaluation
uses base MATLAB's [`norm`](https://www.mathworks.com/help/matlab/ref/norm.html)
to avoid creating a squared-residual temporary. Scaling avoids overflow or
underflow from squaring the unscaled residuals; normal floating-point rounding
still applies. The normalized RMS is at most one;
`min(1,...)` enforces this mathematical bound against floating-point roundoff,
including at `realmax`. A residual subtraction that itself overflows is rejected
before this calculation. The result is not weighted by the observer or wavelength
interval; the equal grid makes each sample equally represented. Raw signed B−A
residuals remain available for seeing
where the spectra differ.

For example, residuals `[1, 1, 1, 1]` and `[2, 0, 0, 0]` both have RMS = 1,
although one is spread across every bin and the other is concentrated in one.
RMS alone loses that shape and sign information. It is neither ΔE, an uncertainty
estimate, nor a test of statistical significance. Matching grids alone do not
establish compatible quantities: callers must also check units, instrument and
accessory conditions, and whether the samples have comparable scaling.

## 7. Approximate display previews

[`previewColor`](../../src/+colormeasure/+colorimetry/previewColor.m) accepts finite nonnegative XYZ rows
for display and returns an RGB swatch plus validity and clipping flags. XYZ is
scaled internally before the matrix multiplication to avoid overflow.
`previewColor(XYZ)` has no declared source white and performs no chromatic
adaptation. `previewColor(XYZ, whiteXYZ)` requires a positive finite 1-by-3
white and performs the existing full Bradford adaptation to sRGB D65 before
the display's max-channel normalization. The caller must establish the
CIE 1931 2-degree observer and the shared XYZ reference conditions; the
function cannot infer them from three numbers.

The optional adaptation uses the same matrix equation and destination white
as [relative chart colors](chart-colors.md#equations-and-implementation),
following [ICC.1:2004-10, Annex E.3](https://www.color.org/ICC1V42.pdf#page=102).
Exact excerpt from `previewColor.m`:

```matlab
if nargin==2
    values=colormeasure.colorimetry.adaptXYZ(values,double(whiteXYZ),[.9505 1 1.089]);
end
```

The same [implementation](../../src/+colormeasure/+colorimetry/previewColor.m)
then applies this conversion and display policy:

```matlab
linear=linearSRGB(values);
clipped(valid)=any(linear<0,2);
linear=max(0,linear); scale=max(linear,[],2); scale(scale==0)=1;
linear=linear./scale;
rgb(valid,:)=encodeSRGB(linear);
```

The matrix and transfer function now live in the shared
[`linearSRGB`](../../src/+colormeasure/+colorimetry/private/linearSRGB.m) and
[`encodeSRGB`](../../src/+colormeasure/+colorimetry/private/encodeSRGB.m) helpers.
Normalization remains in `previewColor`; the encoder introduces no scale.

The matrix and encoding follow the [ICC sRGB interpretation, A.7–A.8,
pp. 1–2](https://registry.color.org/rgb-registry/files/sRGB.pdf). The clipping and
peak-channel normalization are project display choices. Negative linear RGB
channels are clipped; each nonblack swatch's largest linear channel becomes 1
before encoding. Black remains black, while invalid XYZ has no preview.

Consequently, two differently bright samples with the same chromaticity and
the same declared-white treatment have the same swatch. Out-of-gamut colors
are only approximated. There is no display-profile transform or viewing-condition model. The preview
helps locate readings in a table; it does not show measured brightness or
calibrated appearance, and its clipping flag is not an instrument-gamut result.

For example, these two synthetic D50-relative neutral samples both produce
approximately white `(1,1,1)` swatches, despite their different Y values:

```matlab
white = colormeasure.colorimetry.illuminantWhite('D50', 100);
samples = [0.18 * white.XYZ; 0.50 * white.XYZ];
[rgb, valid, clipped] = colormeasure.colorimetry.previewColor(samples, white.XYZ);
```

This illustrates brightness normalization, not measured whiteness. Use
`relativeColor` to preserve the two samples' shared-scale brightness instead.
The numerical cases in
[`testRelativeColor`](../../tests/colorimetry/testRelativeColor.m) check the
declared-white preview and its agreement with the same adaptation owner,
while retaining checks for one-argument arithmetic and flags.

The direct readings table uses the ordinary one-argument preview and infers
no source white. The optional declared-white argument remains a numerical API
for explicitly qualified inputs; a device name alone supplies no white.

### Relative chart illustrations

[Chart colors](chart-colors.md) compose the same display helpers with the
existing Bradford adaptation and an explicit shared white/scale. This retains
brightness differences and keeps historical reference illustrations separate
from acquired values. It does not turn a radiance reading into reflectance.
The guide supplies equations, exact excerpts, numerical examples, source
interpretations and limitations.

## 8. CCT, compatibility, and retained measurements

The [CCT guide](cct.md) documents the CIE 1960 coordinate calculation, frozen
Planckian table, triangular/parabolic estimates, applicability limits, code
excerpts, and reference tests. It is a separate calculation from 1976 u′v′
plotting and from Lab/ΔE00.

The [compatibility guide](compatibility.md) lists the API and policy differences
from the original school functions. Raw spectra, instrument-returned values,
and host-derived calculations have different producers and should keep their
own provenance. A library change must not relabel an earlier saved result or
silently replace instrument XYZ with host XYZ. Comparing those values requires
checking their observer, spectral grid, units, and calculation conventions.

Software reference cases live in [tests](../../tests/colorimetry), with their provenance in
[test-reference provenance](../../tests/colorimetry/data/README.md). Tests cover frozen school
spectral outputs, coordinate edge cases, the CIELAB breakpoint, CIEDE2000
reference pairs, RMS, previews, whites, and CCT. They do not establish device
agreement, optical calibration, or experiment-specific perceptual validity.

## Attribution

Scientific definitions and dataset citations identify the underlying methods;
they are not claims that the science originated in this project. Adaptations
of MCSL code retain its MIT notice. CIE data and derived constants retain their
separate data terms. See [third-party notices](THIRD_PARTY_NOTICES.md) before
redistributing the library or data.

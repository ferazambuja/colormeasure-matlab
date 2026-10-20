# Relative chart colors

The direct serial student frontend retains native radiance/luminance and
instrument-scale readings without turning them into relative reflectance.
Measured relative chart fills are unavailable. Local historical preset
illustrations and the shared MATLAB color-calculation kernels remain.

The chart diagram uses approximate screen colors to locate patches. A subdued
reference illustration identifies an unmeasured cell. A selected, accepted direct
reading shows a measurement mark and a neutral unavailable measured-color fill.
Neither fill proves correct positioning, device accuracy or agreement
with a physical chart. Missing color context leaves a neutral cell; it does
not remove the reading or prevent guided measurement.

This projection differs from the table's **Chromaticity preview — brightness
normalized**, which normalizes each reading and infers no source white.
See the [preview API and qualification rules](science.md#7-approximate-display-previews).

## Quantities, white and observer

[`relativeColor`](../../src/+colormeasure/+colorimetry/relativeColor.m) takes
N-by-3 XYZ, an explicit positive reference-white XYZ row in the same scale,
and `CIE1931_2deg`. All samples share that white's Y. The function neither
estimates a white from the brightest patch nor rescales patches individually.
Scaling samples and white together leaves the displayed RGB unchanged.

The generated Classic reference uses Argyll's ICC-rounded D50
white. SG's source XYZ has no qualified original white/observer basis,
so its expected values are retained without a reference-color rendering.

Direct radiance/luminance readings keep their acquired units and chart
association. No relative surface color is inferred from them. Their measured
cell stays neutral in this direct product; no relative calculation is inferred.
A different observer cannot be converted by renaming XYZ: that requires the
appropriate spectral calculation and data. Reference rendering reports explicit
unavailable reasons for missing or unsupported white, observer and scale.
Acquired native colors remain unavailable even if a convenient display white
is declared; that declaration does not change their measured quantity.

## Equations and implementation

For source white \(W_s=(X_n,Y_n,Z_n)\), divide **every** sample by the same
\(Y_n\). The existing full linear Bradford adaptation then predicts corresponding
XYZ under the sRGB reference D65 white \(W_d=(0.9505,1,1.089)\):

\[
X_{65}=B^{-1}\operatorname{diag}
\left(\frac{B W_d}{B(W_s/Y_n)}\right)B(X/Y_n).
\]

Here division inside the diagonal is componentwise. This is chromatic
adaptation, not spectral relighting. The [ICC specification, Annex E.3](https://www.color.org/ICC1V42.pdf#page=102)
defines the Bradford matrix and full-adaptation equations. The destination
white follows the [ICC sRGB interpretation, A.3](https://registry.color.org/rgb-registry/files/sRGB.pdf):
its absolute reference XYZ is `(76.04,80,87.12)`, divided by 80. It is a display
encoding reference; it does not replace the acquired quantity's source white.

Exact excerpt from `relativeColor.m`:

```matlab
destinationWhite=[.9505 1 1.089]; % ICC sRGB A.3: [76.04 80 87.12] / 80.
valid=all(imag(XYZ)==0,2)&all(isfinite(XYZ),2)&all(real(XYZ)>=0,2);
rgb=NaN(size(XYZ));clipped=false(size(XYZ,1),1);
values=double(real(XYZ(valid,:)))./double(whiteXYZ(2));
```

Exact excerpt from the shared
[`linearSRGB`](../../src/+colormeasure/+colorimetry/private/linearSRGB.m):

```matlab
matrix=[3.2406255 -1.5372080 -.4986286; ...
    -.9689307 1.8757561 .0415175; .0557101 -.2040211 1.0569959];
linear=XYZ*matrix.';
```

The [ICC sRGB interpretation, A.7–A.8](https://registry.color.org/rgb-registry/files/sRGB.pdf)
supplies this matrix and the transfer function. Linear display channels are
clipped to `[0,1]`, then encoded as `12.92*c` below or at `0.0031308`, or
`1.055*c^(1/2.4)-0.055` above it. Exact excerpt from the shared
[`encodeSRGB`](../../src/+colormeasure/+colorimetry/private/encodeSRGB.m):

```matlab
clipped=any(linear<0 | linear>1,2);
linear=min(1,max(0,linear));
encoded=12.92*linear; nonlinear=linear>.0031308;
encoded(nonlinear)=1.055*linear(nonlinear).^(1/2.4)-.055;
rgb=min(1,max(0,encoded));
```

The rounded published matrix maps its D65 reference white to linear RGB
approximately `(0.99999999235,1.00000002715,0.99999988515)`. The tiny green
excursion is still reported as clipping. No tolerance silently clears that
status and no per-patch normalization hides it. Clipping describes an
approximate screen representation, not invalid measurement or ΔE. A calibrated
display profile, viewing-condition model and spectral reconstruction are absent.
Finite nonnegative XYZ rows are eligible, including black. Invalid rows yield
`NaN` RGB and `valid=false`; arithmetic overflow has a named domain error.

## Historical preset illustrations

The [reference manifest](../../resources/provenance/chart-reference-source.json)
pins the original numerical files, exact Argyll consumer sources, generator
and existing build-time Python CGATS/science modules. The original files and
their [AGPL terms](../../resources/charts/ARGYLL-AGPL-3.0.txt) accompany the
derived references. The application's MIT license does not relabel that data.
See [resource attribution and reproduction](../../resources/charts/README.md).

| Preset | Retained source values | Interpretation used for illustration |
|---|---|---|
| Classic | Argyll 3.5.0 `ref/ColorChecker.cie`, created 18 February 2008; 24 Lab rows | `scanin.c:1403–1408` converts Lab with `icmD50`, then scales XYZ by 100. The existing Python `lab_to_xyz` performs this build-time inverse of the [CIE Lab definition](https://cie.co.at/eilvterm/17-23-076). Original Lab rows remain retained. |
| Digital SG | `ref/ColorCheckerSG.ti2`, created 10 February 2014; 140 expected XYZ rows | Retained source data only. The original white/observer basis is unestablished, so reference colors are unavailable. Device RGB fields are not a substitute sRGB palette. |

Both source files lack explicit illuminant/observer keywords. The Classic
Lab interpretation follows its pinned Argyll consumer. `icc_util.c:2080–2095`
identifies the D50 white with the 1931 observer and rounds `(0.9642,1,0.8249)`
to ICC s15Fixed16 before multiplying by 100. The resulting retained white is
`(96.4202880859375,100,82.49053955078125)`. This establishes a historical
**expected illustration convention**, not original specimen measurement
conditions, physical chart edition, backing, geometry or spectral reflectance.
These references are not quantitative position-test or acceptance standards.

For SG, `chartread.c:193,3128–3132` retains expected XYZ on a scale of 100 and
`:149–163` uses D50 Lab for its expected-value comparison. That consumer
assumption does not establish the source values' original colorimetric basis
for display. The application therefore preserves the original values and
mapping while showing an explicit unavailable reference-color state. It does
not infer a replacement white or adjust the data to make the patches neutral.
Direct measured colors remain unavailable. Custom targets have no invented
reference palette; imported target interpretation is absent from this installation.

The separate `doc/SG_header.txt` in the
[ArgyllCMS 3.5.0 archive](https://www.argyllcms.com/Argyll_V3.5.0_src.zip)
names a manufacturer `digital_colorchecker_sg_l_a_b.txt` dataset and declares
Lab columns. It does not establish a numerical relationship between that
dataset and the retained TI2 XYZ. A white specified for a separate Lab file
cannot be assigned to these XYZ values without that relationship.

Source locations, not merely raw source IDs, map reference cells to the
structural chart. In SG, `C06` and `C07` both have raw ID 26; their distinct
locations remain distinct. Rotation changes display positions only.

## Worked examples and checks

For `(95.05,100,108.9)` as the white, neutral samples at 18% and 50% of that
white encode to about `(0.461356,0.461356,0.461356)` and
`(0.735357,0.735357,0.735357)`. They remain visibly different. Setting both
to their own maximum would erase this useful distinction.

Classic source `A01` retains Lab `(37.99,13.56,14.06)`. Inverting Lab under the
ICC-rounded D50 white gives XYZ `(11.52184773,10.08244856,5.08894279)` on
the Y=100 scale. Bradford adaptation and the shared sRGB encoder give RGB
`(0.45299913,0.31736162,0.26419090)`, without clipping. This is the historical
reference illustration, not a measured Dark skin specimen. The numerical
test checks this independently calculated result and the original Lab round trip.

[`testRelativeColor`](../../tests/colorimetry/testRelativeColor.m) checks
black, white, neutral brightness, common-scale invariance, the transfer
breakpoint, display clipping, invalid/missing context and overflow. It also
pins ordinary previews to their pre-extraction arithmetic and flags.
[`testChartColors`](../../tests/workflow/testChartColors.m) checks the current
local Classic/SG reference values, source mapping, MAT retention and native
radiance naming-only availability. Software cases do not establish
physical measurement accuracy.

## Retention and display state

[`Run`](../../src/+colormeasure/+chart/Run.m) freezes `referenceData` at chart
creation, separately from measurement rows. The direct product retains each
selected completed native attempt and accepted context but leaves its measured
relative color unavailable. A failed retry preserves the last
accepted selection. A new pass has its own selections. Reading retained but
unsaved is distinct from reading unavailable.

[`colors`](../../src/+colormeasure/+chart/colors.m) returns plain per-cell
`reference` and `measured` values with RGB, availability, clipping, context,
provenance and a reason. The UI's neutral veil affects display pixels only.
It changes neither original reference numbers nor measurements, context,
provenance or clipping flags. Checkmarks and text establish progress separately
from color. No calibration, acquisition or export operation is triggered by
rendering these values.

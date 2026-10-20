# Attribution and third-party material

## MCSL-Tools

The initial numerical conventions, array-orientation compatibility and some
implementations were derived from the MIT-licensed RIT-MCSL/MCSL-Tools project.
The derived implementations and their sources are identified below.

- Upstream numerical source: [main at ce4e63f](https://github.com/RIT-MCSL/MCSL-Tools/tree/ce4e63f19ad54617478ff84791483deec920532d).
- The frozen spectral fixture and original school benchmarks were produced
  from [18106db](https://github.com/RIT-MCSL/MCSL-Tools/tree/18106db15c223277c84cbc6b631c0df8330bafdc),
  with source hashes in [the fixture source record](../../tools/colorimetry/reference-source.json).
  The fixture's `spec2XYZ.m` and `getObserverFunction.m` differ from ce4e63f only
  in comments and whitespace; `ObsFunctions.mat` is identical. The actual
  generation revision remains part of the fixture's provenance.
- Spectrum integration retains the `spec2XYZ` convention; its implementation
  is reorganized around a prepared integrator and package-relative CIE data.
- `XYZ2CCT` adapts the school algorithm and CR validity wrapper. The original
  `PlanckLocus.mat` is retained unchanged.
- `previewColor` and `illuminantWhite` are extracted from the measurement
  workflow contributions by Fernando Voltolini de Azambuja.
- `relativeColor` composes the package's existing Bradford adaptation with
  explicit shared-white scaling. The shared `linearSRGB` and `encodeSRGB`
  helpers implement the ICC-published matrix and encoding equations.
  Fernando Voltolini de Azambuja authored this application implementation
  and extraction; the underlying scientific definitions are credited in the
  [chart-color guide](chart-colors.md), not claimed as new methods.
- Coordinate/Lab/ΔE00 equations are implemented here with compatible array
  orientations. CIE and Sharma references identify the underlying science.

The package's author credit identifies its new implementation and adaptation
work. The root library license accompanies these contributions. The upstream
copyright and complete permission notice are distributed in
[resources/colorimetry/MCSL-LICENSE.txt](../../resources/colorimetry/MCSL-LICENSE.txt). Preserve this notice and the
upstream license when redistributing derived code or data.

## CIE datasets and derived values

The bundled official observer, D50/D65/A spectral tables and their metadata are
unchanged CIE files, licensed CC BY-SA 4.0. The D50/D65/A constants and independent CCT test references derived
from CIE data carry the same attribution/data terms. See
[resources/colorimetry/README.md](../../resources/colorimetry/README.md). The code's MIT license does not relabel those
data as MIT.

## Adaptation and reflectance calculations

`adaptXYZ` independently implements the linear Bradford equations and matrix
documented in ICC.1:2004-10, Annex E.3. The published Colour Bradford example is
used as a numerical test reference; Colour and ArgyllCMS implementations were
not copied. `reflectanceFromReference` implements the documented sample/reference
ratio with characterized reference factors; `reflectanceXYZ` independently
implements the reflecting-object XYZ normalization with perfect-diffuser Y=100.
The [scientific guide](adaptation-reflectance.md) cites definitions,
workflow context, implementation choices and limits. These code contributions
are covered by the package's MIT license; the bundled CIE data retains its
separate CC BY-SA 4.0 attribution and terms.

## CIEDE2000 reference pairs

The tests include the 34 published numerical pairs of Sharma, Wu & Dalal (2005),
with attribution in [test-reference provenance](../../tests/colorimetry/data/README.md). The authors'
MATLAB and Excel implementations are not included in this package.

## Historical chart reference illustrations

Classic Lab and Digital SG expected XYZ values come from the retained
ArgyllCMS 3.5.0 numerical sources, with their original AGPL-3.0 terms.
The retained numerical data and derived Classic illustrations retain those
source terms; SG's expected-color rendering is unavailable because its original
white/observer basis is unestablished. The application
MIT license does not relabel them. The [resource notice](../../resources/charts/README.md)
and [reference source manifest](../../resources/provenance/chart-reference-source.json)
identify the original values, consumer interpretation, generator and source hashes.
The [chart-color guide](chart-colors.md) distinguishes the historical expected
illustrations from physical chart editions and acquired measurements.

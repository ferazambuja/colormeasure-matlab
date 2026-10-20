# Chart reference data and credits

The MATLAB app reads the packaged JSON files directly. `classic.json` and
`sg.json` define patch grids and identifiers. `classic-reference.json` and
`sg-reference.json` contain historical reference values and their color context.
Each chart saves its reference data separately from instrument readings.

| Resource | Source and interpretation |
|---|---|
| Classic layout | ArgyllCMS 3.5.0 `ref/ColorChecker.ti2` |
| SG layout and expected XYZ | `ref/ColorCheckerSG.ti2`; original XYZ retained, but reference colors unavailable because the original white/observer basis is unestablished |
| Classic expected colors | `ref/ColorChecker.cie`; original Lab interpreted using the historical D50 convention |

Original numerical files are retained unchanged in [sources](sources),
including their original identifiers and whitespace. Source location maps,
not raw IDs alone, identify cells. SG's duplicated raw ID 26 does not merge
`C06` and `C07`.

The [layout source record](../provenance/chart-source.json) and
[reference source record](../provenance/chart-reference-source.json) identify
the original files, their interpretation and the packaged data by digest.

## Data credits and terms

Argyll's `ref/ReadMe.txt` explicitly lists these numerical targets under
`ref/License.txt`, the GNU Affero General Public License version 3. The
unmodified terms accompany them in [ARGYLL-AGPL-3.0.txt](ARGYLL-AGPL-3.0.txt).
The original chart data comes from the
[official ArgyllCMS source distribution](https://www.argyllcms.com/downloadsrc.html).
Keep the original chart files, editable data, source records and associated
license notices together when sharing these resources. Application code uses
the separate [MIT license](../../LICENSE.txt).

## Using the reference colors

Classic illustrations follow the historical D50 expected-color convention.
SG's expected XYZ remains source data without a rendered reference palette;
an assumed D50 white does not establish its original basis.
Physical chart edition, backing, geometry and specimen measurement conditions
remain unverified. They are positioning illustrations, not a measured specimen,
reference-accuracy claim or quantitative acceptance test. Device RGB columns
are never treated as sRGB. Custom grids have no invented palette. See the
[scientific projection and limitations](../../docs/colorimetry/chart-colors.md).

ColorChecker is an X-Rite/Calibrite product name. Classic names identify
patches; neither the names nor these historical illustrations establish the
reference values of a particular physical chart.

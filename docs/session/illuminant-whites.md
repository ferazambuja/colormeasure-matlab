# Standard Lab reference whites

`colormeasure.colorimetry.illuminantWhite(name, Y)` supplies D50, D65 and A whites for
the CIE 1931 2-degree observer. `Y` is the chosen white level in the same XYZ
scale as the compared readings. It returns XYZ and its source metadata. The comparison retains that metadata in `whiteReference`.
The window starts preset **White Y** at **100**; it remains editable and must
use the experiment's sample scale. This default does not rescale measurements
or confirm an unknown instrument scale. A measured white uses its own XYZ.
The function APIs still require an explicit positive `Y` argument.
For the CIELAB equations, comparison limits and other calculations, see
[Color science: calculations, code and sources](color-science.md).

| Illuminant | X at Y = 100 | Y | Z at Y = 100 |
| --- | ---: | ---: | ---: |
| D50 | 96.4240837883784 | 100 | 82.5128116837737 |
| D65 | 95.0470558654283 | 100 | 108.882873639588 |
| A | 109.850315268456 | 100 | 35.5849301338885 |

## Calculation and sources

For each illuminant, sum its relative spectral power distribution multiplied
by each CIE 1931 color-matching function over **360–830 nm at 1 nm intervals**.
Divide all three sums by the Y sum, then multiply by the requested white Y.
The shared library stores these three derived normalized XYZ triplets; no runtime
download or spectrum resampling is needed.

Excerpt from [colormeasure.colorimetry.illuminantWhite](../../src/+colormeasure/+colorimetry/illuminantWhite.m), after selecting the
illuminant's row in the derived table:

```matlab
xyz=normalized(index,:)*Y;
```

Here `normalized` has Y = 1; the source datasets and derivation are identified
below. The white normalization does not change either sample's recorded XYZ.

This uses the complete common wavelength range of the source tables. It is
independent of the measurement instrument's wavelength range. Both samples
use the same resulting white in `XYZ2Lab`. There is no chromatic adaptation,
per-sample normalization, or prediction of a sample under different lighting.

The source is the International Commission on Illumination (CIE):

| Dataset | DOI | Downloaded CSV MD5 |
| --- | --- | --- |
| [D50](https://cie.co.at/datatable/cie-standard-illuminant-d50) | 10.25039/CIE.DS.etgmuqt5 | `e72757c3078b58e78ba63051be4b27b0` |
| [D65](https://cie.co.at/datatable/cie-standard-illuminant-d65) | 10.25039/CIE.DS.hjfjmt59 | `03d4eb9b837c60671627c946fb534deb` |
| [A, 1 nm](https://cie.co.at/datatable/cie-standard-illuminant-1-nm) | 10.25039/CIE.DS.8jsxjrsn | `ed0e4effb55d82b950c0912b6278a9d1` |
| [CIE 1931 2-degree CMFs](https://cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer) | 10.25039/CIE.DS.xvudnb9b | `17cca777db64b17170f06f67ce9d3ab7` |

These CIE datasets are distributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
The derived reference-white table and numeric constants in `illuminantWhite.m`
are attributed to CIE and distributed under the same license. The modification
is spectral integration followed by white-Y normalization, as described above.

The separately supplied MCSL-Tools baseline's `Convert/CIE_Illuminants.mat` uses
a different D50 tabulation,
giving Z = 82.5239941944622 at Y = 100. These presets use the CIE 1 nm values
above. Its A and D65 tables match the checked CIE spectra.

The shared library's [D50 sampling reconciliation](../../resources/colorimetry/README.md#d50-sampling-reconciliation)
compares the 1 nm constants with the rounded 5 nm reference, including the source
checksums and calculation. Use that convention when comparing tabulated whites.
The meter's finite spectral range and sampling are additional approximations and
can affect computed Lab and color differences.

# Reference data

## CIE 1931 observer

`CIE_xyz_1931_2deg.csv` and its metadata were downloaded unmodified from CIE:

- [Dataset](https://doi.org/10.25039/CIE.DS.xvudnb9b), CIE 2019, *Colour-matching functions of CIE 1931 standard colorimetric observer*.
- [CSV](https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv).
- [Metadata](https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv_metadata.json).
- CSV SHA-256: `fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1`.
- CSV MD5: `17cca777db64b17170f06f67ce9d3ab7`.
- License: [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Original source: CIE 018:2019, Table 6. Range 360–830 nm at 1 nm intervals. The table
is not modified. The calculation retains legacy spline sampling between table
entries even though the dataset metadata specifies linear interpolation.

## Reference-white constants

The numeric D50/D65/A constants inside `colormeasure.colorimetry.illuminantWhite` were derived by
summing CIE illuminant SPD times the 1931 observer at 360:1:830 nm, then normalizing
to Y = 1.
The derivation is an adaptation of CIE data; these derived values remain
attributed to CIE under CC BY-SA 4.0, separately from the function's MIT code.

| Illuminant | Dataset DOI | CSV MD5 | XYZ at Y=1 |
| --- | --- | --- | --- |
| D50 | [10.25039/CIE.DS.etgmuqt5](https://doi.org/10.25039/CIE.DS.etgmuqt5) | `e72757c3078b58e78ba63051be4b27b0` | 0.964240837883784,1,0.825128116837737 |
| D65 | [10.25039/CIE.DS.hjfjmt59](https://doi.org/10.25039/CIE.DS.hjfjmt59) | `03d4eb9b837c60671627c946fb534deb` | 0.950470558654283,1,1.08882873639588 |
| A | [10.25039/CIE.DS.8jsxjrsn](https://doi.org/10.25039/CIE.DS.8jsxjrsn) | `ed0e4effb55d82b950c0912b6278a9d1` | 1.09850315268456,1,0.355849301338885 |

These constants are not interchangeable with rounded 5 nm whites without allowing
for their sampling convention. White Y must be chosen in the sample's XYZ scale.

### D50 sampling reconciliation

Use the unmodified [CIE D50 table](https://cie.co.at/datatable/cie-standard-illuminant-d50)
and the [CIE 1931 observer](https://doi.org/10.25039/CIE.DS.xvudnb9b), with the
checksums above. At each shared wavelength from 360 through 830 nm, multiply
D50's relative spectral value by each observer function. Sum those products
with an inclusive uniform step, then multiply the resulting XYZ by `100/Y`.
Changing only the sampling step gives:

| Step | X at Y=100 | Y | Z at Y=100 |
| --- | ---: | ---: | ---: |
| 1 nm | 96.42408378837831 | 100 | 82.51281168377379 |
| 5 nm | 96.42174816313872 | 100 | 82.52091199740008 |

The 5 nm result rounds to `[96.422, 100, 82.521]`, the D50 reference specified
in [ITU-T T.42 (2003)/Cor.1 (2004)](https://www.itu.int/ITU-T/recommendations/rec.aspx?lang=en&rec=7240).
The bundled constants preserve the 1 nm result, divided by 100. This reconciles
the numerical difference; it does not establish that the historical reference
was generated from these exact newer files.
Neither row is an instrument calibration or a measured white. The
[science guide](../../docs/colorimetry/science.md#5-d50-d65-and-a-reference-whites) explains
how the caller chooses the reference-white scale.

## Bundled illuminant spectra

The following original CSV files and their official metadata were downloaded
unmodified from CIE on 2026-09-17. Each CSV covers 300–830 nm at 1 nm spacing.
They are relative SPDs, with value 100 at 560 nm, rather than measured absolute
irradiance. CSV checksums agree with the downloaded official metadata.

| Name and dataset | CSV | Metadata | CSV SHA-256 |
| --- | --- | --- | --- |
| CIE 2022, D50, [10.25039/CIE.DS.etgmuqt5](https://doi.org/10.25039/CIE.DS.etgmuqt5) | [CIE_std_illum_D50.csv](https://files.cie.co.at/Publications-datasets/CIE_std_illum_D50.csv) | [Official metadata](https://files.cie.co.at/Publications-datasets/CIE_std_illum_D50.csv_metadata.json) | `b23049c6f7b266c1c1fbe147aa271e8930ca02d6e569c5ae1804c036faea4193` |
| CIE 2019, D65, [10.25039/CIE.DS.hjfjmt59](https://doi.org/10.25039/CIE.DS.hjfjmt59) | [CIE_std_illum_D65.csv](https://files.cie.co.at/Publications-datasets/CIE_std_illum_D65.csv) | [Official metadata, revision 2](https://files.cie.co.at/Publications-datasets/CIE_std_illum_D65.csv_metadata_v2.json) | `e76f210bffff3d552ef7113025da5f325d5dfec200dd4b878b1a2f3a507032cb` |
| CIE 2018, A, [10.25039/CIE.DS.8jsxjrsn](https://doi.org/10.25039/CIE.DS.8jsxjrsn) | [CIE_std_illum_A_1nm.csv](https://files.cie.co.at/Publications-datasets/CIE_std_illum_A_1nm.csv) | [Official metadata, revision 2](https://files.cie.co.at/Publications-datasets/CIE_std_illum_A_1nm.csv_metadata_v2.json) | `61ef23fe146b8b665c74706717ab28cec7db6c9022993490bdc71991f43cb59b` |

Publisher and author: International Commission on Illumination (CIE), Vienna,
Austria. The CSVs, metadata and derived/interpolated data are attributed under
[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).
Preserve these source/license notices when distributing the data or adaptations.
The MATLAB code's separate MIT license does not replace those data terms.

The D50/D65 metadata cites ISO/CIE 11664-2:2022, Table B.1. For A, the retained
revision-2 metadata cites equation 1 and Table A.1 of that standard. CIE's dataset
landing page cites CIE 015:2018 equation 4.1 and displays a different checksum;
the checksums recorded here identify the retained CSV and agree with its
revision-2 metadata. Metadata supplies checksums and interpolation instructions. [`illuminantSpectrum`](../../src/+colormeasure/+colorimetry/illuminantSpectrum.m) uses exact
integer-nanometre table samples and **linear interpolation** for fractional
wavelengths, with **no extrapolation**. D50/D65 metadata specifies linear
interpolation; A metadata instead recommends the related formula. Linear
interpolation of the A table is an explicitly identified approximation here,
not implementation of that formula. The stored CIE files themselves are unchanged.

[`reflectanceXYZ`](../../src/+colormeasure/+colorimetry/reflectanceXYZ.m) additionally restricts its
integration to the observer's 360–830 nm range and records any shorter input
range. Its perfect-diffuser white uses the actual requested grid. At
360:1:830 nm, these datasets reproduce the `illuminantWhite`
constants within floating-point rounding.

## Planckian compatibility table

`PlanckLocus.mat` is copied without modification from MIT-licensed MCSL-Tools
at ce4e63f. It supplies the compatibility CCT algorithm with the source's
integration and constant conventions.
See [CCT sources, checksum and limitations](../../docs/colorimetry/cct.md) and the preserved
[MCSL copyright/license](MCSL-LICENSE.txt).

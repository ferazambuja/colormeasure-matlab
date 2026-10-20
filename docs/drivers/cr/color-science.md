# CR measurements and derived values

See the [measurement guide](README.md) to collect and save data, and the
[API reference](api-and-protocol.md) for method signatures and array shapes.

The CR-100 supplies XYZ directly. The CR-250 and CR-300 supply a spectrum;
their `XYZ` field is calculated in MATLAB using the bundled `colormeasure.colorimetry` library's
CIE 1931 2° observer. `instrumentXYZ` retains the instrument's XYZ separately, and
`metadata(k).instrumentRadiometricValue` retains the radiometric result reported
by the instrument for reading k. These values can differ from the MATLAB results because the
instrument uses its own observer, corrections and integration procedure.
Retained accessory, user calibration and (for spectral models) CMF metadata
describe the instrument configuration; they do not change the observer used
for MATLAB spectral integration. All three models derive CCT/Duv in MATLAB
from their primary `XYZ`. Although the protocol documents device CCT, this
driver does not request it or substitute it for the host result.

Using a fixed observer does not undo instrument corrections. The CRI App
Manual v1.5.10 §14.3.1.2 (p.84) describes spectral Match calibration against a
reference spectrum. Such a correction may affect the returned spectrum and
therefore the XYZ calculated from it; it must not be assumed to affect only
`instrumentXYZ`. The manual is available through the
[manufacturer downloads](https://www.colorimetryresearch.com/downloads).

`spectralData` and `wl` retain the spectrum and wavelength grid returned by the
instrument. Negative spectral bins are retained. No clipping, normalization,
interpolation or resampling is applied to the acquired spectrum. A reading is
committed only after its required acquisition, parsing and calculations finish.

## Quantities and units

| Field | Origin | Interpretation |
| --- | --- | --- |
| `wl` | Instrument spectrum header | Wavelength in nm; actual returned range, spacing and count |
| `spectralData` | Instrument spectral response | Signed spectral values; quantity and inherited density interpretation recorded per reading |
| `XYZ` for CR-100 | Instrument | Documented 2° tristimulus values with the instrument's active calibration |
| `XYZ` for CR-250/300 | MATLAB | CIE 1931 2° tristimulus values; conditional Y units follow the quantity table below |
| `integratedSpectrum` | MATLAB | Inclusive rectangle integral over the sampled band; conditional units follow the quantity table below |
| `CCT`, `Duv` | MATLAB | Correlated colour temperature in K and signed distance in CIE 1960 UCS; `NaN` when unavailable |

Remote Communications v1.36 §4.3.1.36 defines the four radiometric types.
CRI App Manual v1.5.10 §6.2 (pp.28–29), available through the
[manufacturer downloads](https://www.colorimetryresearch.com/downloads), gives
their integrated units. The corresponding photometric quantities follow the
[BIPM/CIE photometry definitions](https://www.bipm.org/documents/20126/52718503/G1-2019.pdf/692275b2-049d-5222-35de-c975dd1850fc).

| Type | Quantity | Instrument radiometric unit | Assumed spectral unit | Conditional host Y unit |
| --- | --- | --- | --- | --- |
| 0 | Radiance | W/(m² sr) | W/(m² sr nm) | cd/m², luminance |
| 1 | Irradiance | W/m² | W/(m² nm) | lx, illuminance |
| 2 | Radiant intensity | W/sr | W/(sr nm) | cd, luminous intensity |
| 3 | Radiant flux | W | W/nm | lm, luminous flux |

`metadata` records `radiometricType`, `radiometricQuantity`, `radiometricUnit`,
`spectralDensityUnit` and `xyzUnit`. The last two explicitly append
`(provisional: assumes per nm)` to the unit strings shown above;
`spectralDensityUnitsConfirmed` is false. For example, derived illuminance is
labeled `lx (provisional: assumes per nm)`, not an unqualified `lx`. Both numerical outputs of
`RM Radiometric` are retained as `instrumentRadiometricValue` and
`instrumentPhotonValue`, alongside the full reply. The photon-irradiance unit
label in the app manual is internally inconsistent, so no confirmed photon
unit is assigned. Interpret `instrumentRadiometricValue` using that reading's
radiometric type, quantity and unit.

`spectralData` and `integratedSpectrum` retain the signed spectrum and its
host integral for every quantity type. Histories may include different types;
use each row's metadata to distinguish radiance, irradiance, intensity and flux.

The host calculation interprets each sample as a density per nm, then
multiplies the sum by the wavelength increment in nm.
The available CR remote protocol describes `RM Spectrum` but does not
explicitly establish its per-nm denominator. Consequently these absolute-unit
labels remain an inherited interpretation requiring manufacturer confirmation.
The instrument's radiometric quantity type is checked separately. A radiance
type code does not by itself resolve the spectral-density denominator.
Compare the retained instrument radiometric result and the integrated spectrum
under an authorized measurement, including any band limits and instrument
settings, before treating them as equivalent.

`integratedSpectrum` covers only the reported wavelength band. It does not
estimate radiation outside that band or convert between measurement geometries.
In type 0, `integratedSpectrum` is not radiant power or hemispherical exitance.
`XYZ` is not normalized to Y=100 or Y=1.

## Spectral integration

[colormeasure.drivers.cr.spectralValues](../../../src/+colormeasure/+drivers/+cr/spectralValues.m) validates finite real samples and
an explicit grid before calling
[`colormeasure.colorimetry.spectra2XYZ`](../../../src/+colormeasure/+colorimetry/spectra2XYZ.m) and
[`colormeasure.colorimetry.spectralIntegral`](../../../src/+colormeasure/+colorimetry/spectralIntegral.m).
The runtime calls are qualified. The original `Convert` functions come from
a separately supplied, pinned MCSL-Tools checkout and are used only as a
[comparison baseline](original-comparison.md). Add this application's `src`
folder to MATLAB's path as shown in the [measurement guide](README.md).

To reproduce the calculation for one retained reading:

```matlab
k = 1; % Index of one successful spectral reading in measurements.
spectrum = measurements.spectralData(k,:).';
wavelength = measurements.wl(k,:).';
XYZ = colormeasure.colorimetry.spectra2XYZ(spectrum, wavelength);
integratedSpectrum = colormeasure.colorimetry.spectralIntegral(spectrum, wavelength);
[CCT, Duv] = colormeasure.colorimetry.XYZ2CCT(XYZ);
```

Recalculation creates analysis values; it does not change or relabel the saved
measurement. The source method strings on a saved row describe its acquisition
software, not whichever library happens to be on today's path.

The library bundles the unchanged official CIE 1931 2° CSV at 1 nm intervals
from 360 to 830 nm. This replaces the inherited `Convert/ObsFunctions.mat`
representation for current runtime only. The table values differ by at most
1.11×10⁻¹⁶ in one entry, so agreement is assessed within floating-point rounding,
not by requiring byte-identical XYZ. This is not a different observer or an
instrument recalibration. Dataset source, checksum and attribution are retained
in the [library data record](../../../resources/colorimetry/README.md).

The prepared [`XYZIntegrator`](../../../src/+colormeasure/+colorimetry/XYZIntegrator.m)
uses these focused excerpts (input checks omitted):

```matlab
peakNm = (299792458 / 540e12) / 1e-9;
obj.Scale = 683*obj.Step / interp1(native,cmf(:,2),peakNm);
XYZ = obj.Scale .* (obj.MatchingFunctions.' * spectra).';
```

Here `spectra` is W × N, `MatchingFunctions` is W × 3, and `Step` is
the wavelength increment in nm. CR passes one spectrum at a time and retains
one XYZ row. Keeping the scale outside the matrix product preserves the
original operation order. The corresponding column-spectrum integral is:

```matlab
value = sum(double(spectra),1).' * step;
```

The observer functions, rather than the measurement, are interpolated onto
the measurement wavelengths using a cubic spline; observer values outside the
table are zero. At integer wavelengths already in the table this selects
the tabulated values. This implementation does not add an assumed spectral
tail beyond the measured range. Both endpoints have full rectangle weights:
a constant unit spectrum from 380 through 780 nm at 2 nm spacing integrates
to 402, not the trapezoidal value 400.

The [official CIE observer dataset](https://doi.org/10.25039/CIE.DS.xvudnb9b)
identifies the observer and tabulation. Its metadata recommends linear
interpolation; the repository's spline interpolation is an existing convention
and is not represented here as CIE's prescribed interpolation method.

There is also a small existing scale discrepancy. `spec2XYZ` uses
`683 / ybar(299792458 / 540e12 * 1e9)`, with linear interpolation for this
single normalization value. This inserts the **vacuum** wavelength
555.1712185 nm into observer functions ordinarily tabulated in air, producing
`Klegacy = 683.0167582353332`. The
[BIPM/CIE Principles Governing Photometry (2019), section 6](https://www.bipm.org/documents/20126/52718503/G1-2019.pdf/692275b2-049d-5222-35de-c975dd1850fc)
uses 555.017 nm in standard air and approximately 683.002 lm/W at the peak.
[NIST's realization of the candela](https://www.nist.gov/pml/sensor-science/optical-radiation/realization-candela)
explains the common 683 lm/W approximation. The legacy factor exceeds 683
by about 0.00245%; its common factor changes absolute XYZ, not chromaticity
or CCT. `colormeasure.colorimetry` retains this numerical convention.

## Grid validation

The library requires positive, increasing, uniformly spaced, finite double
wavelengths. CR's helper converts supported numeric vectors to double without
changing their values. It neither canonicalizes a nearly uniform grid nor
resamples measured data. The exact uniformity tolerance from the library is:

```matlab
tolerance = min(4*eps(max(1,max(abs(wavelength)))),abs(steps(1))*1e-8);
```

Every step must differ from the first by no more than that tolerance. Four
ULPs refer to double-precision spacing at the largest wavelength, with the
additional relative cap preventing effectively coincident irregular samples
from being accepted. For example:

```matlab
% A deliberately irregular grid:
colormeasure.drivers.cr.spectralValues([1 2 3], [500 501 502+1e-10]); % CR:InvalidSpectrum
```

An intended grid such as `380:0.1:780` is generated and checked in double;
promoting an already rounded single-precision grid does not restore its intended
spacing. On a measured grid failure, retain and inspect the response rather
than rounding it until it passes. Invalid grids map to `CR:InvalidSpectrum`;
a nonfinite XYZ or integral caused by arithmetic range maps to
`CR:DerivedOverflow`. No partial measurement row is retained. During acquisition,
those host errors preserve the port only after a complete, quiescent exchange,
as described in the [failure guide](api-and-protocol.md#errors-and-recovery).

## CCT and Duv

[colormeasure.drivers.cr.cct](../../../src/+colormeasure/+drivers/+cr/cct.m) calls the bundled
[`colormeasure.colorimetry.XYZ2CCT`](../../../src/+colormeasure/+colorimetry/XYZ2CCT.m), adapted from the
school `XYZ2CCT` and the CR validity wrapper. It retains the triangular
and parabolic approaches described by
[Ohno, Practical Use and Calculation of CCT and Duv (2014)](https://doi.org/10.1080/15502724.2014.839020).
It uses CIE 1960 coordinates:

```matlab
denominator = X + 15*Y + 3*Z;
u = 4*X / denominator;
v = 6*Y / denominator;
```

This is `(u', 2*v'/3)`, not unmodified CIE 1976 `(u',v')`. Duv is
dimensionless; positive values are above the Planckian locus and negative
values below it. CCT describes the nearest locus point, not the source's
physical temperature. See [CIE TN 013:2022, section 6](https://doi.org/10.25039/TN.013.2022).

The retained `PlanckLocus.mat` spans 1000–25000 K. The bundled file is byte-for-byte
identical to the original table, SHA-256
`c17df5017fe0eb930c8989ee732c70c2bf64eef25acd9d73bdacf5dde4753e2c`.
It loads relative to the package, so an unrelated same-named MAT file on the
path or in the current folder cannot replace it. Its generator uses
`CCT2Planckian` with wavelengths 300:5:830 nm, refractive index n=1, and the
exact SI values of h, c and k, so its second radiation constant is
0.01438776877... m K. CIE TN 013:2022 discusses the distinction from
the 0.014388 m K value specified in CIE 015:2018. No table or physical-constant
change is made here. The approximation and table do not establish a universal
sub-kelvin accuracy guarantee. Ohno's published assessment covers
1000–20000 K and Duv from -0.03 to +0.03; the retained wider table and the
0.05 applicability boundary are different limits.

Both CCT and Duv become `NaN` for:

- Black, nonfinite or nonreal XYZ, negative integrated XYZ components, or Y≤0.
- A nonfinite/nonreal calculation result or an estimate at/outside the table
  endpoints, where the minimum is not bracketed by adjacent entries.
- A distance outside the CIE 0.05 applicability limit on either side of the
  locus. The retained policy also rejects its positive boundary at 0.05.

CCT assumes XYZ refers to the CIE 1931 2° observer. The CR Remote
Communications Manual v1.36, section 4.3.1.27, labels `RM XYZ` as 2°;
the [manufacturer's colorimeter calibration description](https://www.colorimetryresearch.com/learning/fcmm)
explains its CIE 1931 target. CR-100 CCT uses that interpretation of its
calibrated output. User calibration mode and available calibration identifiers
are retained; a user correction is not independently verified
by these software checks. `RM CMF` is expressly limited to spectroradiometers
(manual section 4.3.1.41) and must not be used to gate CR-100 measurements.
For spectral models, custom instrument CMFs can affect `instrumentXYZ`, while
MATLAB `XYZ` always uses the stated 1931 observer. Manufacturer manuals and
SDK are available through the [CR downloads page](https://www.colorimetryresearch.com/downloads).

Negative **spectral samples** and negative **integrated XYZ** are different
conditions. A spectrum with a negative bin can still integrate to valid,
positive tristimulus values and produce finite CCT/Duv. If the integrated XYZ
is negative it is still retained; only CCT/Duv are unavailable. The library
scales a temporary XYZ triplet to avoid arithmetic overflow in chromaticity
calculation; it never modifies the retained measurement.

## Independent numerical checks

`tests/drivers/cr/testCRScience.m` checks the public helpers without instruments. The
reference values were calculated separately using Python/NumPy, the official
CIE 1 nm CSV, and SciPy's bounded scalar minimization, rather than calling
the old or new conversion functions, or reading either copy of the Planckian
table.

The [CIE CSV metadata](https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv_metadata.json)
records SHA-256
`fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1`, which was
verified before generating the fixtures. The CR tests embed derived numeric reference results. The library separately
bundles the unchanged official CSV with its attribution and checksums.

For the spectral references, select wavelengths 380:1:780 or 380:2:780 from
the official table and independently evaluate the rectangle sum with the
documented legacy factor. Equal-energy unit spectra give:

| Grid | X | Y | Z | Integrated spectrum |
| --- | ---: | ---: | ---: | ---: |
| 380:1:780 | 72983.81396481987 | 72984.72987293049 | 72977.66485260120 | 401 |
| 380:2:780 | 72984.24536081358 | 72984.75543572048 | 72979.64793779360 | 402 |

For the CCT references, integrate
`lambda.^(-5) ./ expm1(h*c ./ (lambda*k*T))` against the official CMFs
over 360:1:830 nm, with lambda in metres. Convert the resulting XYZ to
1960 `(u,v)`. A unit normal to the locus, estimated using T±0.1 K and
oriented toward positive v, creates the signed-distance fixtures. Minimize
the squared `(u,v)` distance to an independently computed Planckian locus
using bounded scalar minimization. Finally convert the target `(u,v)` to XYZ
with Y=1 using `X=3*u/(2*v)` and `Z=(4-u-10*v)/(2*v)`.

The retained reference cases cover 2856 K and 6500 K, signed ±0.01 Duv,
rejected ±0.06 Duv, and out-of-table Planckian temperatures 800 and 30000 K.
The acceptance tolerances, 0.1 K and 5e-7 Duv for the four valid fixtures,
compare different wavelength grids and numerical approaches; they are not
instrument uncertainty claims. Tests also cover signed spectra, negative
integrated XYZ, black, malformed grids, nonfinite inputs and overflow.

## Implementation provenance

The original MCSL spectral and CCT implementations credit Tucker Downs and
Luke Hellwig in the source and repository history; the upstream copyright
also names Minyao Li, Michael Murdoch and Yongmin Park. Those original files
remain unchanged. The bundled `colormeasure.colorimetry` implementation by Fernando Voltolini
de Azambuja adapts the spectral convention and CCT algorithm, reorganizes
spectral integration, and loads its own reference data. It is not claimed as
an independently invented color-science method. Its unchanged Planckian table
and adapted code retain the upstream MIT notice in
[THIRD_PARTY_NOTICES.md](../../colorimetry/THIRD_PARTY_NOTICES.md) and
[MCSL-LICENSE.txt](../../../resources/colorimetry/MCSL-LICENSE.txt). The official CIE
CSV and metadata retain their separate CC BY-SA 4.0 attribution and terms in
the [data record](../../../resources/colorimetry/README.md). No manufacturer SDK source
is copied into these helpers.

The [source manifest](../../../resources/provenance/colorimetry-source.json)
records repository-relative colorimetry paths and hashes. The current repository
commit identifies this implementation. Runtime calculations are under
`src/+colormeasure/+colorimetry`, data under `resources/colorimetry`, and
numerical checks under `tests/colorimetry`.
Per-reading `xyzSource` and `cctSource` identify the result's producer and
convention; see [calculation provenance](metadata.md#calculation-provenance).

The shared [science guide](../../colorimetry/science.md) documents further
library functions. CR acquisition uses only spectral XYZ, band integration
and CCT/Duv; it does not add Lab, color-difference or display-preview processing
to measurements. The instrument/host distinction is unchanged: CR-100 primary
XYZ is device-reported, CR-250/CR-300 primary XYZ is host-derived, and all three
retain the original `instrumentXYZ`. Instrument and host values are kept
separate because their calculation settings and conventions can differ.

Absolute comparisons require matching quantities, spectral-density units and
instrument settings. The spectral-density denominator and the effect of
instrument-specific corrections must be established before claiming absolute
radiance or luminance agreement. Numerical test tolerances do not describe
instrument uncertainty or calibration.

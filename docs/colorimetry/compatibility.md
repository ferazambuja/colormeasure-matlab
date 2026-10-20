# Compatibility

This reference describes array shapes, numerical conventions and differences
from the school conversion functions. Calls use the `colormeasure.colorimetry` namespace.
A library update never recalculates saved data automatically.

| School/workflow function | Standalone function | Contract |
| --- | --- | --- |
| `spec2XYZ(s,wl)` | `colormeasure.colorimetry.spectra2XYZ(s,wl)` | N wavelengths × M spectra or its transpose; square arrays mean columns; output M×3 |
| `getObserverFunction('1931')` | `colormeasure.colorimetry.observer()` | 471×3 CMFs and 471×1 nm wavelengths; no guessed grid or alternate observer |
| `XYZ2xyY`, `XYZ2uvY` | Same names under `colormeasure.colorimetry` | N×3 or 3×N; 3×3 means rows; retain orientation and Y |
| `xyY2uvY` | `colormeasure.colorimetry.xyY2uvY` | xy or xyY, retaining orientation/Y; 2/3-column orientation wins when ambiguous |
| `XYZ2Lab` | `colormeasure.colorimetry.XYZ2Lab` | Preserve XYZ orientation; require one finite positive 1×3 reference white |
| `deltaE_2000` | `colormeasure.colorimetry.deltaE00` | Lab pairs, or one reference broadcast over samples; first-input orientation determines result orientation |
| CR wrapper + `XYZ2CCT` | `colormeasure.colorimetry.XYZ2CCT` | N×3 input, N×1 CCT/Duv; invalid/out-of-domain rows unavailable together |
| PR/CR spectral sum | `colormeasure.colorimetry.spectralIntegral` | Inclusive rectangle weights, not `trapz`; output M×1 |

## Deliberate differences

- The package namespace keeps these functions distinct from the original MATLAB names.
- Spectral conversion requires explicit positive, increasing, uniform wavelengths.
  Wavelength arrays use double precision; single-precision spectra remain
  supported. Generate wavelengths in double from the intended start/step rather
  than promoting an already rounded single-precision fractional grid. Grid
  roundoff tolerance is capped at four double ULPs and 1e-8 of the first step.
  It refuses missing/irregular grids rather than guessing wavelengths or using
  only the first interval on an irregular grid.
- Spectral/coordinate/Lab calculations use finite real single/double inputs and
  return double. Signed spectra are retained. Input and arithmetic errors are
  explicit; see each function's help for shape and unavailable-value handling.
- Ratio calculations avoid overflow by scaling each XYZ triplet before division.
  They retain the original Y. Direct u′v′ can remain valid for signed XYZ with
  X+Y+Z = 0, where the old route through xy was undefined. Black has undefined
  chromaticity, represented by
  paired NaNs. Paired unavailable xy coordinates may pass through `xyY2uvY`.
- Lab evaluates its piecewise function once per component and avoids complex
  intermediate cube roots for negative values on the linear branch.
- CIEDE2000 includes the mean-hue wrap and published zero-chroma rules, checked
  against all 34 published Sharma reference pairs and a separate independently
  evaluated unequal-chroma hue-wrap case.
- CCT uses the current CR validity policy, not all sentinel behaviors of bare
  school `XYZ2CCT`. See [CCT](cct.md).
- Data is loaded relative to the installed package. A same-named MAT file on
  another MATLAB path cannot silently replace the reference data.

The bundled official CIE CMFs differ from the inherited MAT representation by
at most 1.11×10⁻¹⁶ in a table entry. Numerical compatibility therefore means
agreement within floating-point rounding, not a promise of byte-identical XYZ.
The prepared integrator keeps the scale multiplication outside the matrix
product to preserve the legacy operation order.

## Saved data and API compatibility

Measurement MAT files contain value structs, not package objects. Saved method
labels retain the calculation identity. Adapters use recognized method and unit
declarations to decide which derived views and comparisons are available; see
[acquisition science](../session/color-science.md#chromaticity-observer-and-spectral-locus).
Custom scripts that retain a prepared integrator or function handle should
recreate it using `colormeasure.colorimetry`; these objects are not part of ordinary batch files.

### Calculation APIs

The explicit adaptation/reflectance functions return derived results.
`adaptXYZ` preserves the XYZ orientation and
uses one source/destination white pair. `reflectanceFromReference` returns
wavelengths-by-samples factors; `reflectanceXYZ` returns samples-by-3 XYZ and
a 1-by-3 white. Both spectral APIs use the existing uniform double-wavelength
contract. Unlike the emission integrator, reflectance integration refuses
out-of-observer-range wavelengths, samples CMFs linearly, and normalizes a
perfect diffuser to Y=100 over the input grid. See the
[equations, assumptions and sources](adaptation-reflectance.md).

Measurement records distinguish acquired spectra and instrument-reported XYZ
from host-derived values, and retain their units and calculation methods. The
available fields depend on the instrument and acquisition method; see the
corresponding instrument guide.

# Benchmarks

These software benchmarks compare calculation time and numerical agreement.
They do not measure instrument exposure, communication, plotting or saving.
Results depend on array size, MATLAB version and the host computer.

## Computational methods

- A prepared `XYZIntegrator` reuses the sampled observer for repeated readings.
  Integer-nanometre grids use exact table indexing during preparation; off-grid
  wavelengths retain spline interpolation.
- Direct u′v′ calculation avoids the intermediate xy conversion. Per-row scaling
  also avoids overflow when forming ratios.
- Lab computes the piecewise transform once for each component. Only positive
  values on the nonlinear branch take a fractional power.
- CCT finds the nearest locus point using squared distance, then takes square
  roots only for the three neighboring distances needed by the algorithm.
- Data loads are cached and tied to the installed package, rather than whichever
  same-named data file MATLAB finds elsewhere.

Both the school `spec2XYZ` and this library cache observer/grid data. Acquisition
converts each new spectrum once. The timings below include the validation and
preparation work specified for each call.

## Observed timings

These retained timings describe the implementation and environment below. They
are not a new benchmark of the current checkout.

MATLAB R2026a Update 5, macOS Apple Silicon. These are local computation timings,
not instrument acquisition timings. The kernel comparison used 32 XYZ rows and
the median of three `timeit` estimates, alternating old/new order between rounds.
School source: MCSL-Tools revision
[18106db](https://github.com/RIT-MCSL/MCSL-Tools/tree/18106db15c223277c84cbc6b631c0df8330bafdc).
The [attribution record](THIRD_PARTY_NOTICES.md) identifies its relation to the
main numerical source.

| Calculation | School | Library | Observed ratio, school / library |
| --- | ---: | ---: | ---: |
| Lab, 32 rows | 45.1 µs | 44.5 µs | 1.01 |
| 1976 u′v′, 32 rows | 65.8 µs | 56.0 µs | 1.18 |
| CCT, 32 rows | 4.85 ms | 2.03 ms | 2.39 |

A spectral sweep covered 101, 201 and 401 wavelengths, with 1, 32 and
1024 spectra. Prepared conversion took approximately 0.03–0.51 ms across those
cases; the school converter took approximately 0.016–0.15 ms. Input validation
scans the whole input for nonfinite values, whereas the school function mostly
checks dimensions. On larger batches that safety check costs more than the
saved preparation work. The ordinary convenience call adds a grid-cache check.

The maximum absolute XYZ difference in that sweep was about 1.1×10⁻¹¹ for XYZ
values on the order of tens of thousands, consistent with floating-point
rounding. The public regression suite checks independent frozen expected values
on additional shapes and grids, including signed and zero spectra.

The paired medians reduce order effects. Re-run on the deployment machine if
computation throughput matters.

## Reproduce

```matlab
% Current Folder: the project folder containing src
addpath(fullfile(pwd, 'src'), fullfile(pwd, 'tools', 'colorimetry'));
benchmarkAgainstMCSL('/path/to/MCSL-Tools', 'spectra-timing.csv');
benchmarkColorKernels('/path/to/MCSL-Tools', 'kernel-timing.csv');
```

These developer tools require a school checkout for comparison. Runtime library
functions and the bundled tests do not. The tools isolate the selected checkout’s `Convert` folder, verify function
and data-file resolution, and clear its cached observer/locus data before checking
numerical agreement and timing. The original MATLAB folder and path are restored
on completion or failure; relative output paths retain the caller’s destination. Follow the [MathWorks `timeit` guidance](https://www.mathworks.com/help/matlab/ref/timeit.html)
when interpreting results.

## Public MATLAB functions and integration overhead

MATLAB already provides useful building blocks: matrix multiplication, `sum`,
`hypot`, and `norm` are used directly by this library. A public color-conversion
function is a different comparison: argument handling, shape conversion,
validation, and optional-toolbox requirements can outweigh its numerical work
for one or two readings.

The optional [`benchmarkMATLAB`](../../tools/colorimetry/benchmarkMATLAB.m) tool compares:

- [`xyz2lab`](https://www.mathworks.com/help/images/ref/xyz2lab.html) with an
  explicit numeric white `[95 100 108]`, using the same scale for samples.
- [`imcolordiff`](https://www.mathworks.com/help/images/ref/imcolordiff.html)
  with `Standard='CIEDE2000'`, `isInputLab=true`, and kL = kC = kH = 1.
- [`rms`](https://www.mathworks.com/help/matlab/ref/rms.html), both directly on
  the residual and after scaling to avoid squared-value overflow/underflow.

It calls public APIs. Lab and ΔE00
comparisons require Image Processing Toolbox. That optional benchmark dependency
does not change the toolbox-free runtime library.

### Numerical checks before timing

The tool checks all 34 Sharma pairs and 2,005 Lab rows, including signed values,
black, the piecewise-function breakpoint and nearby values. Each ΔE00
implementation must match the published rounded references within 5×10⁻⁵;
the comparison also allows at most 5×10⁻⁵ between implementations and timed
ΔE00 variants. This is a software comparison tolerance, not bit-identical
arithmetic or a perceptual threshold. Lab uses an absolute 10⁻¹⁰ tolerance
for the dedicated parity cases. Every timing variant is checked before measuring. Extreme Lab/ΔE00 results are recorded separately
because native error behavior need not match the library's guarded contract.
Large and tiny spectral residuals check the scaled RMS calculation; raw `rms`
can overflow or underflow on those inputs even when their RMS is representable.

The library's spectral RMS uses a scaled `norm` reduction from base MATLAB.
It avoids constructing the explicit squared-residual temporary, preserves the
input scaling, and caps rounding at the mathematical bound RMS ≤ max(abs(residual)).
Unscaled `norm` is not a safe substitute:
its intermediate norm can overflow even when division by sqrt(N) would make the
final RMS finite.

### Timing protocol

The 55 cases contain four variants for Lab and ΔE00 at 1, 2, 32, 1,024, and
32,768 rows, and five RMS variants at 101, 201, and 401 wavelength samples:

| Variant | Included work |
| --- | --- |
| `colormeasure.colorimetry` | The public library call, including its validation |
| `MATLAB direct` | The public native API with already prepared input |
| `MATLAB validated` | Native API plus compatible input/output checks and shape handling |
| `MATLAB validated + resolver` | The same wrapper, plus verifying its resolved path on every call |
| RMS direct/scaled residual | Only the reduction of a prepared B−A vector; no grid validation or subtraction |

All native functions must resolve inside `matlabroot`; a same-named function
elsewhere on the MATLAB path fails the benchmark. The wrapper variants are
benchmark candidates rather than runtime backends. The resolver variant
includes the cost of per-call path resolution.

Every variant is warmed using 1,000 consumed calls. The report takes the median
of three [`timeit`](https://www.mathworks.com/help/matlab/ref/timeit.html)
estimates, reversing variant order on the second pass. RMS and the color cases
with up to 32 rows use batches of 1,000 consumed calls and report the time per
call, including the amortized loop and dispatch overhead. `belowResolution`
flags estimates below useful timing resolution; these do not support a speed
ratio.

### Observed native comparison

MATLAB R2026a Update 5 on macOS Apple Silicon, using the warmed protocol above.
These are per-call medians in microseconds; they include the current scaled-`norm`
RMS implementation. All 55 cases completed with positive timing estimates.

| Calculation | Rows | Library | Native direct | Native validated | Validated + resolver |
| --- | ---: | ---: | ---: | ---: | ---: |
| Lab | 1 | 2.12 | 74.1 | 72.5 | 125 |
| Lab | 32 | 7.05 | 74.3 | 73.6 | 125 |
| Lab | 32,768 | 1.33e+03 | 1.08e+03 | 1.21e+03 | 1.26e+03 |
| ΔE00 | 1 | 7.56 | 37.4 | 37.3 | 77.3 |
| ΔE00 | 32 | 15.3 | 49.5 | 51 | 93.5 |
| ΔE00 | 32,768 | 3.32e+03 | 3.98e+03 | 4.06e+03 | 4.24e+03 |

At 201 wavelengths, the complete `colormeasure.colorimetry.spectralRMS` call took about 4.27 µs,
versus 4.68 µs for the validated native-RMS candidate and 65.6 µs with a path
check on each call. Native `rms` on an already prepared residual took 0.389 µs;
its scaled counterpart took 0.907 µs. Those reductions omit grid checks and
residual construction, so their times cannot replace the complete-call result.

At 32,768 rows, native Lab's direct call was about 19% faster here; adding
validation and path resolution reduced that margin to about 5%. Smaller batches
favored the bundled implementation on this machine. These results do not define
a universal array-size threshold.

MATLAB warm-up, dispatch and system load affect such short measurements. Small
differences between variants, including a validated call occasionally appearing
faster than its direct equivalent, are not evidence that adding validation
removes work.

### Reproduce and retain the result

```matlab
% Current Folder: the project folder containing src
addpath(fullfile(pwd, 'src'), fullfile(pwd, 'tools', 'colorimetry'));
[report, details] = benchmarkMATLAB('matlab-timing.csv');
save('matlab-timing.mat', 'report', 'details');
```

No school checkout or instrument is involved. The optional CSV contains the
summary table; the returned `details` includes all three timing rounds,
numerical-check results, MATLAB version, API paths, seed, and timing protocol.
The tool restores the MATLAB path and random-generator state when it returns.
Run it without another benchmark or acquisition competing for CPU time.

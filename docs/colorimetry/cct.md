# Correlated colour temperature and Duv

```matlab
[CCT, Duv] = colormeasure.colorimetry.XYZ2CCT([0.9687838667891457 1 1.121180717781349]);
```

`XYZ` contains one reading per row, in CIE 1931 2-degree XYZ. An N×3 matrix
returns N×1 columns: CCT in kelvin and dimensionless signed Duv. A 3×3 matrix
means three readings; column-oriented XYZ is not inferred. The example is a
synthetic 6500 K Planckian reference, not illuminant D65.

## In plain language

CCT describes the temperature of the closest point on the Planckian locus;
Duv describes the signed chromaticity distance from that locus. They are useful
near-white light descriptors. They do not measure an LED's physical temperature,
colour rendering, or instrument accuracy. The calculation leaves the supplied
XYZ unchanged. A mathematical answer outside the method's applicable range is
reported as unavailable rather than presented as a meaningful temperature.

## 1. Reference table and conventions

[`colormeasure.colorimetry.XYZ2CCT`](../../src/+colormeasure/+colorimetry/XYZ2CCT.m) preserves the MCSL triangular/parabolic
calculation and the CR current validity policy. The implementation is adapted from
[MCSL `XYZ2CCT.m` at ce4e63f](https://github.com/RIT-MCSL/MCSL-Tools/blob/ce4e63f19ad54617478ff84791483deec920532d/Convert/XYZ2CCT.m),
under its MIT license. That source credits
[Ohno, *Practical Use and Calculation of CCT and Duv* (2014)](https://doi.org/10.1080/15502724.2014.839020).
Ohno's [CORM 2011 presentation](https://cormusa.org/wp-content/uploads/2018/04/CORM_2011_Calculation_of_CCT_and_Duv_and_Practical_Conversion_Formulae.pdf),
slides 11, 13 and 15, illustrates the triangular and parabolic estimates. The
implementation details below specify this library's table and branch boundaries.
The excerpts below are from this library's implementation; the full source
includes the omitted table-validation checks.

The unchanged `PlanckLocus.mat` spans 1000–25000 K and has SHA-256
`c17df5017fe0eb930c8989ee732c70c2bf64eef25acd9d73bdacf5dde4753e2c`.
The [source generator](https://github.com/RIT-MCSL/MCSL-Tools/blob/ce4e63f19ad54617478ff84791483deec920532d/Convert/private/generate_CCT_table.m)
and [`CCT2Planckian`](https://github.com/RIT-MCSL/MCSL-Tools/blob/ce4e63f19ad54617478ff84791483deec920532d/Convert/CCT2Planckian.m)
specify `300:5:830` nm, the school's CIE 1931 2-degree integration,
refractive index 1, and exact SI h, c, and k. The corresponding second radiation
constant is hc/k = 0.01438776877… m K. This library does not regenerate the
table, apply a new correction factor, or change that convention.

The table is loaded once from the project's bundled resources:

```matlab
persistent temperatures locus
if isempty(temperatures)
    root = colormeasure.root();
    data = load(fullfile(root,'resources','colorimetry','PlanckLocus.mat'), 'cct', 'uvY1960');
```

Before using it, the implementation checks numeric type, shape, finite real
values, increasing temperatures, and the expected endpoints. An unrelated
`PlanckLocus.mat` in MATLAB's current directory cannot replace the bundled data.
This is a compatibility calculation, not a claim of universal sub-kelvin
accuracy or complete implementation of a lighting standard.

## 2. CIE 1960 coordinates

CCT uses `(u,v) = (u′, 2v′/3)`, not distances directly in the 1976 u′v′ plot.
This is the coordinate system specified by the CCT definition in
[CIE TN 013:2022, §6](https://files.cie.co.at/Pubs/TN/CIE_TN_013_2022.pdf).

After rejecting an invalid XYZ row, the code scales the calculation to avoid
an overflowing denominator:

```matlab
value = value ./ max(value);
denominator = value(1) + 15*value(2) + 3*value(3);
uv = [4*value(1) 6*value(2)] ./ denominator;
```

This internal positive scaling changes neither coordinate nor retained XYZ.
It also means CCT and Duv do not describe luminance: readings at different
brightnesses can have the same CCT and Duv.

## 3. Nearest-table search and triangular estimate

The closest table entry is found using squared distance. Square roots are
needed only for the three entries used by the following interpolation:

```matlab
squaredDistances = sum((locus - uv).^2,2);
[~, m] = min(squaredDistances);
if m == 1 || m == numel(temperatures)
    continue % No pair of surrounding temperatures brackets this estimate.
end
distance = sqrt(squaredDistances(m-1:m+1));
t = temperatures(m-1:m+1);
l = sqrt(sum((locus(m-1,:) - locus(m+1,:)).^2));
x = (distance(1)^2 - distance(3)^2 + l^2) / (2*l);
estimate = t(1) + (t(3)-t(1))*(x/l);
vTx = locus(m-1,2) + (locus(m+1,2)-locus(m-1,2))*(x/l);
radialSquared = distance(1)^2 - x^2;
if radialSquared < 0
    tolerance = 8*eps(max(distance(1)^2, x^2));
    if radialSquared < -tolerance, continue; end
    radialSquared = 0;
end
signedDistance = sqrt(radialSquared)*sign(uv(2)-vTx);
```

The minimum is unchanged by squaring nonnegative distances; an exact tie uses
the first entry, as MATLAB's `min` specifies. Endpoints have no surrounding pair
and are withheld. The chord length `l` and along-chord distance `x` determine
an interpolated temperature. The distance perpendicular to that chord gets
its sign from the sample's v relative to `vTx`: positive above, negative below.
This is a local numerical estimate, not an assertion that the locus is a
straight line.

The squared perpendicular distance is geometrically nonnegative. Subtraction
near a chord can produce a tiny negative value through floating-point roundoff.
Values within eight representable-number spacings at the larger squared term
are treated as zero; more negative values remain unavailable. This numerical
safeguard is an implementation choice, not a CIE threshold or an accuracy claim.

## 4. Parabolic estimate farther from the locus

When the triangular estimate gives `abs(Duv) > 0.002`, the retained method fits
a parabola to the three distance/temperature pairs and uses its vertex:

```matlab
if abs(signedDistance) > 0.002
    product = (t(3)-t(2))*(t(1)-t(3))*(t(2)-t(1));
    a = (t(1)*(distance(3)-distance(2)) + ...
        t(2)*(distance(1)-distance(3)) + ...
        t(3)*(distance(2)-distance(1))) * product^-1;
    b = -(t(1)^2*(distance(3)-distance(2)) + ...
        t(2)^2*(distance(1)-distance(3)) + ...
        t(3)^2*(distance(2)-distance(1))) * product^-1;
    c = -(distance(1)*(t(3)-t(2))*t(2)*t(3) + ...
        distance(2)*(t(1)-t(3))*t(1)*t(3) + ...
        distance(3)*(t(2)-t(1))*t(1)*t(2)) * product^-1;
    estimate = -(b/(2*a));
    signedDistance = sign(uv(2)-vTx)*(a*estimate^2+b*estimate+c);
end
```

The 0.002 branch threshold and these equations are unchanged from the school
calculation. Reducing the number of square roots changes search work without
introducing a new table or a different interpolation model. Benchmarks and
their limits are recorded in [performance](performance.md); timing does not
establish scientific accuracy.

## 5. Unavailable results and differences from the original

The outputs start as `NaN` pairs. Black, nonreal/nonfinite XYZ, negative
components, and Y≤0 are skipped. The final estimate must satisfy:

```matlab
if ~isreal(estimate) || ~isreal(signedDistance) || ...
        ~isfinite(estimate) || ~isfinite(signedDistance) || ...
        estimate <= temperatures(1) || estimate >= temperatures(end) || ...
        signedDistance >= 0.05 || abs(signedDistance) > 0.05
    continue
end
CCT(j) = estimate;
Duv(j) = signedDistance;
```

Thus a row is unavailable if it lacks a bracket, lands at or outside
1000–25000 K, produces nonreal/nonfinite arithmetic, or has `abs(Duv) > 0.05`.
The original routine's extra rejection at exactly positive 0.05 is also
retained; negative −0.05 is not rejected by that boundary test alone.
The CCT and Duv results are always available or unavailable together.

The two-sided 0.05 limit follows the applicability discussion in
[CIE TN 013:2022, §6](https://files.cie.co.at/Pubs/TN/CIE_TN_013_2022.pdf).
That note's §3 also distinguishes the SI value of hc/k from the
0.014388 m K value specified in CIE 015:2018. Changing that constant, the
observer sampling, or the integration rule would change the numerical
reference and must be assessed separately.

Compared with calling bare school `XYZ2CCT`, this library adds explicit batch
shape and validity handling, including the narrowly bounded roundoff safeguard
above. The reference table is unchanged. The CR current wrapper uses this same
calculation and paired-unavailable policy.
Invalid measurements remain available to callers in their original form;
an unavailable CCT is not a reason to discard raw XYZ or spectral data.

## 6. Verification and interpretation

[`testCCT.m`](../../tests/colorimetry/testCCT.m) uses independent numeric cases shared with
the CR current scientific tests. They integrate Planck's law over the
official CIE 1931 CMFs at `360:1:830` nm with exact SI h, c, and k. A locus
normal estimated from T±0.1 K and oriented toward positive v supplies signed
offsets. A bounded scalar minimization of squared distance to this independently
integrated locus checks the nearest temperature. The inverse coordinate
calculation with Y=1 is `X=3*u/(2*v)` and `Z=(4-u-10*v)/(2*v)`.

The four accepted references cover 2856 K, 6500 K, and ±0.01 Duv at 6500 K.
Tolerances of 0.1 K and 5×10⁻⁷ Duv allow for different wavelength grids and
numerical methods. They are software comparison tolerances, not instrument
uncertainty or an accuracy guarantee over every valid input. Further cases
exercise ±0.06 Duv, outside-table temperatures, invalid XYZ, scale invariance,
batch shape, a conflicting table in the current directory, and interior locus
chord midpoints that exercise cancellation in the squared-distance calculation.

Reference data source: [CIE 2019, CIE 1931 standard colorimetric
observer](https://doi.org/10.25039/CIE.DS.xvudnb9b), CC BY-SA 4.0.
The official CSV has SHA-256
`fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1`.
These are synthetic software tests, independent of an instrument connection or
another MCSL-Tools checkout. [Data attribution](../../resources/colorimetry/README.md) and
[third-party notices](THIRD_PARTY_NOTICES.md) retain the source boundaries.

Instrument-reported CCT and this host calculation may differ because their
XYZ, observer, table, constants, or numerical method differ. Retain each
producer's result and method instead of silently substituting one for the
other. Matching the software references alone does not establish agreement
with an instrument or the suitability of CCT for a saturated light source.

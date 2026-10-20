# Chromatic adaptation and spectral reflectance

## In plain language

Two different questions need different calculations. **Chromatic adaptation**
predicts a corresponding color when the observer adapts from one white to
another. **Reflectance integration** predicts the stimulus from a surface under
a specified illumination spectrum. Changing the Lab white alone performs neither
operation. These functions return derived results; they never rewrite acquired
XYZ or spectra and do not establish calibration or viewing-condition agreement.

| Question | Function | Required information |
| --- | --- | --- |
| Corresponding XYZ under another adapted white | [`adaptXYZ`](../../src/+colormeasure/+colorimetry/adaptXYZ.m) | Sample XYZ and source/destination white XYZ |
| Spectral factor relative to a measured plate | [`reflectanceFromReference`](../../src/+colormeasure/+colorimetry/reflectanceFromReference.m) | Sample/reference spectra and characterized reference factor on one grid |
| Surface color under a target illuminant | [`reflectanceXYZ`](../../src/+colormeasure/+colorimetry/reflectanceXYZ.m) | Spectral factor and target illuminant SPD |
| D50, D65 or A spectrum | [`illuminantSpectrum`](../../src/+colormeasure/+colorimetry/illuminantSpectrum.m) | Name and wavelength grid within the bundled range |

Related workflow reference: [ArgyllCMS `spotread`](https://www.argyllcms.com/doc/spotread.html)
describes Bradford white-relative display mode (`-ew`) and illuminant selection
for reflection/transmission spectra (`-i`).

## Linear Bradford adaptation

`adaptXYZ(XYZ, sourceWhiteXYZ, destinationWhiteXYZ)` accepts real finite
single/double N×3 or 3×N XYZ. A 3×3 array contains row samples. Output retains
that orientation and uses double precision. Each white is a positive 1×3 row.
Whites giving nonpositive Bradford cone responses are refused.

The implementation uses full linear Bradford adaptation. This excerpt from
[`adaptXYZ`](../../src/+colormeasure/+colorimetry/adaptXYZ.m) includes white
normalization, cone-response validation and identity handling:

```matlab
source = normalizedWhite(sourceWhiteXYZ);
destination = normalizedWhite(destinationWhiteXYZ);
bradford = [0.8951 0.2664 -0.1614; -0.7502 1.7135 0.0367; 0.0389 -0.0685 1.0296];
cones = bradford * [source; destination].';
if any(~isfinite(cones),'all') || any(cones<=0,'all')
    error('colormeasure:Colorimetry:InvalidWhite','Whites must give finite positive Bradford cone responses.');
end
if isequal(source,destination)
    transform = eye(3);
else
    transform = bradford \ (diag(cones(:,2)./cones(:,1))*bradford);
end
adapted = rows * transform.';
```

Its `normalizedWhite` helper validates and normalizes each supplied white:

```matlab
function white=normalizedWhite(value)
if ~(isa(value,'single')||isa(value,'double')) || ~isreal(value) || ...
        ~isequal(size(value),[1 3]) || any(~isfinite(value)) || any(value<=0)
    error('colormeasure:Colorimetry:InvalidWhite','Whites must be finite positive 1-by-3 single or double XYZ rows.');
end
white=double(value)/double(value(2));
if any(~isfinite(white)) || any(white<=0)
    error('colormeasure:Colorimetry:NumericRange','White normalization exceeds the finite calculation range.');
end
end
```

The matrix and cone-ratio construction follow **ICC.1:2004-10, Annex E.3,
equations E.1–E.4**, which describe the linearized Bradford transform under
full adaptation. The MATLAB implementation uses a linear solve rather than
an explicitly formed inverse. [ICC specification, PDF page 102](https://www.color.org/ICC1V42.pdf#page=102).

Normalizing both whites to Y=1 makes their chromaticities determine the
transform. It does **not** divide each sample by its own brightness or force
its Y to 100. Multiplying input XYZ by a common scalar multiplies adapted XYZ
by that scalar. Individual Y values can change under the color transform.
A source white with Y=203 maps to the destination-white chromaticity at Y=203,
even if the supplied destination white was expressed at Y=1 or Y=100.
For subsequent Lab, use the destination white at the intended sample scale.

Signed XYZ components are retained. No RGB conversion, clipping, gamut mapping,
black subtraction, or per-sample normalization takes place. The returned `meta`
records the raw/normalized whites, matrix, full-adaptation assumption and
brightness policy. This is a corresponding-color model, not a measurement of
observer adaptation and not a spectral relighting model.

The numerical test includes the independently published Bradford example in
[Colour 0.4.7](https://colour.readthedocs.io/en/v0.4.7/generated/colour.adaptation.chromatic_adaptation_VonKries.html),
plus identity, white mapping, round-trip, brightness scaling and signed-value
checks. No optional image-processing toolbox is needed.

### MATLAB API choice

The numerical implementation operates directly on XYZ. MATLAB's
[`chromadapt`](https://www.mathworks.com/help/images/ref/chromadapt.html) also
defaults to Bradford, but accepts RGB images. Converting acquired XYZ through
a clipped display RGB representation before adaptation would lose information.
The small XYZ matrix operation therefore lives in the bundled library without
requiring an image-processing toolbox.

## Reference ratio and its measurement assumptions

`reflectanceFromReference(sample, reference, referenceReflectance, wavelength)`
calculates, bin by bin:

```matlab
reflectance = (sample./reference).*referenceReflectance;
```

The sample may contain multiple spectra. References are one measured spectrum
and one characterized factor spectrum. Values are **fractions**, so 0.35 means
35%; the characterized reference is never implicitly assumed to be a perfect
white. The returned array has wavelengths in rows, one sample per column.
Signed sample bins and factors above 1 remain visible and are flagged in
metadata. Negative estimates can arise from noise or corrections and are not
assertions of negative physical reflectance.

The caller must establish the **same actual wavelength samples**, numerical
scale, illumination, geometry and relevant instrument settings. Array lengths
and the explicit uniform grid are checked; a numeric vector carries no second
grid for the function to compare. This function does not infer those conditions
from matching lengths, change instrument settings, resample measurements, or
subtract dark readings. Any dark correction belongs in a separately identified
preprocessing step applied consistently to sample and reference.

CIE's reflectance-factor and radiance-factor definitions depend on illumination
and collection geometry. The directional ratio of radiance measurements is a
spectral radiance-factor estimate for that geometry, not automatically total
hemispherical reflectance. A factor greater than 1 need not violate energy
conservation because it compares with a specified diffuser/geometry.
[CIE S 017:2020, terms 17-24-070](https://cie.co.at/eilvterm/17-24-070)
and [17-24-075](https://cie.co.at/eilvterm/17-24-075).

The CS-S10w object-color workflow similarly uses a measured white plate plus
its characterization, expressed as one spectral factor per wavelength.
This supports the reference-measurement approach; it does not certify this
implementation against CS-S10w or issue any instrument calibration command.
[Konica Minolta CS-S10w Professional v1.6 manual, §2.10.15, printed page 143](https://www.konicaminolta.com/instruments/download/instruction_manual/software/pdf/cs-s10w_16x_pro_instruction_eng.pdf#page=145).

### Weak reference bins

The function refuses the entire ratio when a reference bin is nonpositive or
at most `sqrt(eps('double'))` times the reference peak. That relative numerical
floor is about 1.49×10⁻⁸. There is no replacement value, smoothing, clipping,
or omission of offending wavelengths. The condition is unchanged by a common
rescaling of the input spectra.

This floor only catches unusable/numerically weak denominators. Passing it
does not establish adequate signal-to-noise ratio; a bin far above the floor
can still be too noisy for useful measurements. A stable broadband source,
repeat readings and appropriate instrument range remain relevant.

## Target-illuminant integration

`reflectanceXYZ(reflectance, wavelength, illuminant)` takes fractional factors
and either a named D50/D65/A illuminant or an explicit nonnegative SPD vector
on the **same grid**. It returns one XYZ row per sample, the grid-specific
perfect-diffuser white, and metadata. The SPD must have positive photopic
weight. No illuminant is guessed and no acquisition unit becomes cd/m² here.

For a uniform interval Δλ, the convention is:

```text
XYZ = 100 × Σ[R(λ) S(λ) (x̄(λ), ȳ(λ), z̄(λ)) Δλ] / Σ[S(λ) ȳ(λ) Δλ]
```

The denominator makes an ideal diffuser with factor 1 have Y=100 over the
stated grid. The common interval cancels. The implementation additionally
scales the illuminant by its maximum to avoid needless overflow; this also
cancels and is not sample normalization:

```matlab
weighted=matching.*(spd/max(spd));
denominator=sum(weighted(:,2));
if ~isfinite(denominator) || denominator<=0
    error('colormeasure:Colorimetry:IlluminantSpectrum','Illuminant has no finite positive photopic weight on this grid.');
end
weights=weighted/denominator;
XYZ=100*(weights.'*reflectance).';
white=100*sum(weights,1);
```

This is an inclusive uniform sum with full endpoint weights, not a trapezoidal
integral. There is no 683 photometric factor. The object-colour normalization
and uniform sum are given in Changjun Li's
[*CIE TC1-71 Perspective: An Overview on Accurately Computing Tristimulus Values*](https://library.imaging.org/admin/apis/public/api/ist/website/downloadArticle/cic/16/1/art00005)
(2008), p. 22, equations (1)–(3). Here the sum is evaluated on the supplied grid;
no spectral bandpass correction is applied. This does not establish CIE standard
conformance for arbitrary sample spacing or a truncated wavelength range.
The existing emission-oriented `spectra2XYZ` and its compatibility conventions
are unchanged.

Measurements are not extrapolated or resampled. The bundled CIE 1931 2-degree
CMFs are linearly interpolated onto the supplied grid, which must lie within
360–830 nm. Named illuminants are sampled from the bundled official tables;
see [data identity and interpolation](../../resources/colorimetry/README.md#bundled-illuminant-spectra).
For a limited range such as 380–780 nm, `meta.limitedRange=true`; the returned
white uses that same truncated range. It can differ from the full-range
`illuminantWhite` constants. Pair that returned white with the returned XYZ
for Lab rather than substituting a full-range constant.

The prediction assumes a nonfluorescent spectral factor that remains applicable
under the target illuminant and retained geometry. It does not model fluorescence,
illumination-dependent materials, gloss/angle changes, or missing wavelengths.
Using a measured emitted spectrum directly as reflectance does not remove its
original illuminant. Arbitrary nonnegative spectra are not interchangeable with
characterized reference ratios.

## Example using retained spectra

```matlab
% All arrays below must already refer to the same actual lambda samples.
[factor, ratioInfo] = colormeasure.colorimetry.reflectanceFromReference( ...
    sampleSpectrum, measuredPlateSpectrum, characterizedPlateFactor, lambda);
[XYZ_D65, white_D65, integrationInfo] = colormeasure.colorimetry.reflectanceXYZ(factor, lambda, 'D65');
Lab_D65 = colormeasure.colorimetry.XYZ2Lab(XYZ_D65, white_D65);
```

Save the original measurements, reference identity, characterized factors and
returned metadata alongside derived results. Synthetic numerical tests verify
the equations and refusal behavior; physical agreement still depends on the
measurement setup and material assumptions.

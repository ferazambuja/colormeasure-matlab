# Numerical test references

## Spectral compatibility

`mcsl-spectra-reference.mat` contains spectra, grids and expected XYZ
computed by the school implementation at
[revision 18106db](https://github.com/RIT-MCSL/MCSL-Tools/tree/18106db15c223277c84cbc6b631c0df8330bafdc),
independently of this library. The generator computes expected spectral integrals
directly as the sample sum multiplied by the uniform wavelength step.
Its pinned scripts differ from
[main ce4e63f](https://github.com/RIT-MCSL/MCSL-Tools/tree/ce4e63f19ad54617478ff84791483deec920532d)
only in comments and whitespace; the observer data is identical. It covers native 1/2/4 nm grids, a fractional grid, outside-observer
samples, full CMF coverage, signed/zero/broad/narrow spectra and square arrays.
The test tolerance permits floating-point rounding, including the last-bit
representation difference in the official CSV and inherited CMF MAT table.

[tools/reference-source.json](../../../tools/colorimetry/reference-source.json) pins the source
hashes. The optional generator requires those exact school source bytes before
updating the fixture. Do not regenerate a reference just to make a changed
algorithm pass. Document intentional scientific changes separately.

## CIEDE2000

`ciede2000.txt` preserves the 34 numeric reference pairs and four-decimal expected
results from Gaurav Sharma, Wencheng Wu and Edul N. Dalal (2005), *The CIEDE2000
Color-Difference Formula: Implementation Notes, Supplementary Test Data, and
Mathematical Observations*, Color Research & Application 30(1), 21–30,
[doi:10.1002/col.20070](https://doi.org/10.1002/col.20070).

[Authors' page](https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/) and
[original numeric data](https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/dataNprograms/ciede2000testdata.txt).
Columns 1–3 and 4–6 are the two Lab values; column 7 is ΔE00. Absolute tolerance
5×10⁻⁵ accounts for published rounding. The authors' MATLAB source is not bundled.

A separate unequal-chroma hue-wrap regression uses Lab `[50 20 -20]` and
`[50 80 80]`, with expected ΔE00 `39.01817399392473`. This value was evaluated
independently from the paper's equations 2–22 with 85-digit decimal arithmetic;
it is not one of the published 34 pairs. Its tolerance is 10⁻¹⁰. Equal-chroma
seam pairs alone cannot detect the incorrect above-turn mean-hue branch because
their chroma difference removes the rotation cross-term.

## CCT

Independent CIE-derived reference values and their construction are described
in [the CCT guide](../../../docs/colorimetry/cct.md). Those data retain CIE attribution and
CC BY-SA 4.0 terms. They validate numerical cases, not measured lamp temperatures.

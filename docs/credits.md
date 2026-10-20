# License and credits

Fernando Voltolini de Azambuja developed the measurement app, sessions, updated
instrument drivers, tests and color-calculation implementation and adaptations.
The application code uses the [MIT license](../LICENSE.txt).

## Code contributions

The project builds on instrument and colorimetry work from the RIT Munsell Color
Science Laboratory's MCSL-Tools toolbox. Its copyright notice and
[contributor credits](../OWNERS.txt) are retained. The PR driver also adapts
MIT-licensed Psychtoolbox routines.

- [Colorimetry contributions and scientific sources](colorimetry/THIRD_PARTY_NOTICES.md)
- [Colorimetry code license](../licenses/colorimetry-MIT.txt)
- [PR driver contributions and notices](drivers/pr/THIRD_PARTY_NOTICES.md)

## Reference data

| Included material | Source and terms |
| --- | --- |
| Observer functions, illuminant spectra and derived reference whites | CIE; [CC BY-SA 4.0 and dataset attribution](../resources/colorimetry/README.md) |
| Planckian lookup table | MCSL-Tools; [MIT notice](../resources/colorimetry/MCSL-LICENSE.txt) |
| Chart layouts, historical reference values and retained chart source files | ArgyllCMS; [source attribution and AGPL-3.0 notice](../resources/charts/README.md) |

The chart files supply layouts and historical reference colors. Instrument
control and color calculations run in MATLAB.

Keep the associated copyright, license and data-source notices when sharing a copy.

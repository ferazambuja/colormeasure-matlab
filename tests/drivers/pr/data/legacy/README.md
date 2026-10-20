# Original PR-655 comparison reference

These two text fixtures preserve the original school's conversion functions at
[`ce4e63f`](https://github.com/RIT-MCSL/MCSL-Tools/tree/ce4e63f19ad54617478ff84791483deec920532d/Convert).
They retain the original contents and are covered by the repository's
[license](https://github.com/RIT-MCSL/MCSL-Tools/blob/main/LICENSE.txt). They are test references, not additional
functions on the MATLAB path. Historical comments in these frozen files are
part of the reference snapshot; use the current [color-science guide](../../../../../docs/session/color-science.md)
for calculation conventions and unit limitations.

`testPR655LegacyParity` executes the original `Devices/PR655/PR655.m` driver
from the school revision `ce4e63f`.

The test makes temporary copies with unique class/function names. Its only
driver substitutions are the class/constructor name, a synthetic serial-port
factory, and the name of the frozen conversion function. The conversion copies
only receive distinct function/dependency names. The test checks SHA-256 digests
of the original driver, the two conversion fixtures and the unchanged
`Convert/ObsFunctions.mat` before execution. This keeps the numerical reference
independent of later edits to the active conversion functions and works from a
downloaded ZIP without Git or network access.

The replay verifies complete original-compatible PR-655 replies, multiple
spectral shapes and histories, saved numerical arrays and valid Auto Sync
frequencies. A short valid header deliberately demonstrates
why the new parser differs from the original fixed-offset parser. Original
timeouts and fragmented replies are not exercised: its unbounded wait could
hang the test. The new driver's protocol tests cover those cases separately.

Synthetic replay does not establish physical agreement, device repeatability,
units or calibration.

<!-- BEGIN TEMPORARY-BETA-TESTING -->

The [hardware comparison](../../../../../docs/beta-testing/PR655.md#pr-655-instrument-comparison) uses
separate original/beta measurement runs.

<!-- END TEMPORARY-BETA-TESTING -->

Keep these baseline bytes frozen. If a deliberate scientific or compatibility
change breaks parity, document the reason and add an explicit expectation for
that difference; do not regenerate the old reference to make the test pass.

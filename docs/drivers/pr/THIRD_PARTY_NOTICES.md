# Third-party sources and attribution

The [acquisition science guide](../../session/color-science.md) and
[standalone colorimetry guide](../../colorimetry/science.md) identify the
mathematical sources and inherited MCSL code. Citations do not replace licenses
or contributor credits. The bundled library has its own
[code and data notices](../../colorimetry/THIRD_PARTY_NOTICES.md); CIE reference data
and derived white constants carry their stated CC BY-SA attribution.

## Psychtoolbox attribution

`colormeasure.drivers.pr.PR655` adapts remote-mode initialization and character-wise command pacing
from Psychtoolbox-3 PR670init.m and PR670write.m. Native spectrum validation
was also informed by PR670parsespdstr.m. The implementation uses MATLAB
serialport and retains the school's spectral-value convention.

Upstream revision: 8f952b4cae7ee3fd90a792b1b36bfb3030ed701d.

- [PR670init.m](https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/PsychHardware/PR670Toolbox/PR670init.m)
- [PR670write.m](https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/PsychHardware/PR670Toolbox/PR670write.m)
- [PR670parsespdstr.m](https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/PsychHardware/PR670Toolbox/PR670parsespdstr.m)
- [Upstream license](https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/8f952b4cae7ee3fd90a792b1b36bfb3030ed701d/Psychtoolbox/License.txt)

These M-files use the distribution's default MIT license. The applicable
copyright notice and license are reproduced below. The original MCSL
attribution is included in [LICENSE.txt](../../../LICENSE.txt) and
[OWNERS.txt](../../../OWNERS.txt) at the project root.

```text
Copyright (c) The individual Psychtoolbox core developers:
          (c) 1996-2022, David Brainard <brainard@psych.upenn.edu>
          (c) 1996-2022, Denis Pelli    <denis.pelli@nyu.edu>
          (c) 1996-2007, Allen Ingling  <allen.ingling@nyu.edu>
          (c) 2005-2023, Mario Kleiner  <mario.kleiner.de@gmail.com>

          (c) Individual major contributors:
          (c) 2006       Richard F. Murray <rfm@yorku.ca>
          (c) 2008-2022  Diederick C. Niehorster <dcnieho@gmail.com>
          (c) 2013-2022  Ian Andolina
          (c) 2008-2011  Tobias Wolf <towolf@tuebingen.mpg.de>

MIT license:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
USE OR OTHER DEALINGS IN THE SOFTWARE.
```

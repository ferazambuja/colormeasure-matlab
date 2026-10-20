# Current direct UI screenshots

The current direct app images, captured on 15 October 2026, show generated
CR-250 readings, the measurement settings dialog and a Classic chart in progress.
[Capture metadata](direct-capture-record.json) records their source/UI digest,
platform, origin and image hashes. They were captured from actual R2026b windows;
no physical instrument was operated and no calibration or accuracy is established.

- [Measurement gallery](direct-serial-gallery.jpg)
- [Measurement settings](direct-serial-settings.jpg)
- [Guided chart](direct-serial-chart.jpg)

## Earlier illustrations

The retained native images contain generated measurements and settings. They
are historical illustrations from the source revisions recorded in
[capture-record.json](capture-record.json), not screenshots of the current
direct-only layout or evidence of physical measurement, calibration, keyboard
focus or accessibility. Current operator guides link only the five retained
illustrations and describe the implemented controls in their text.

This source inventory retains the original metadata and image hashes only for
the five files shipped here. Its `originalCaptureRecord` locator identifies the
complete, byte-preserved original record in the qualified source history.
All original capture artifacts remain in that preserved history; no screenshot
was recaptured to curate this inventory.

To inspect the current native UI without equipment, add this installation’s
`src` folder and open a generated gallery:

```matlab
session = colormeasure.demo('CR250', 'gallery');
```

Other model keys are `PR655`, `CR100`, `CR300` and `CS2000`. **Settings...**
shows the chosen synthetic instrument’s settings. Data, Compare, Color and the
log inspect the same retained demonstration readings.

A new capture must record its exact source revision, MATLAB release, model,
generated-data origin, window dimensions, image dimensions, theme and image
hash. Check labels, scientific units, plot ranges and visible controls before
using it in a guide. Logical window dimensions may differ from image pixels
because of display scaling. A rendered window does not establish native input,
physical instrument behavior or screen-reader support. Keep those validations
separate in the [testing guide](../../testing/workflow.md).

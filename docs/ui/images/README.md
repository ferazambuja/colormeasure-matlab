# Current direct UI screenshots

The current direct app images, captured on 15 October 2026, show generated
CR-250 readings, the measurement settings dialog and a Classic chart in progress.
[Capture metadata](direct-capture-record.json) records their source/UI digest,
platform, origin and image hashes. They were captured from actual R2026b windows;
no physical instrument was operated and no calibration or accuracy is established.

- [Measurement gallery](direct-serial-gallery.jpg)
- [Measurement settings](direct-serial-settings.jpg)
- [Guided chart](direct-serial-chart.jpg)

## Additional settings illustrations

The PR, CR and CS-2000 guides also include five earlier images of generated
readings and settings. Their dates, source identities and image hashes are in
[capture-record.json](capture-record.json). Layout details can differ from the
current window; use the guide text for the current controls.

Historical source identities in the capture records document where an image
was made. They are not revisions in this public repository's history. The
images and their metadata are included here; no earlier checkout is needed.

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

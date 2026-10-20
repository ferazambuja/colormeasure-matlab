# Device identification and selection checks

> **Device-test checklist**
> Scope: [what the device test checks](README.md#what-the-device-test-checks).

## Purpose

Check which available information can reliably associate a connection with a
supported instrument: OS device descriptions, hardware IDs, USB descriptors,
and instrument-protocol identity replies. USB product names are one clue, not
the only possible method. The current `colormeasure.app` launcher
asks for the model, selects a single available port candidate, and verifies the
instrument through that model's driver. These checks investigate reducing that
manual model choice; they do not describe an implemented automatic model-discovery feature.

A USB product name may identify the exact instrument, a manufacturer family, or
only a USB-to-serial adapter. The port name alone does not establish the model.
For example, the manufacturer's CR serial driver lists VID `2799`, PID `0002`
as **Colorimetry Research, Inc. Meter**. That is a family identifier, not a
CR-100/250/300 distinction. See [manufacturer downloads](https://www.colorimetryresearch.com/downloads).

## Record one connected instrument

Finish any acquisition and release its connection before changing cables.

1. Record the model printed on the instrument and the OS/MATLAB version.
2. List MATLAB ports before and after connecting just that instrument:

   ```matlab
   serialportlist('all')
   serialportlist('available')
   ```

3. Record the USB manufacturer, product description, vendor/product IDs and
   associated port. If a serial adapter is used, distinguish its identity from
   the instrument behind it.

   On macOS, inspect **System Information → USB**. Terminal equivalents:

   ```sh
   system_profiler SPUSBDataType
   ioreg -r -c IOSerialBSDClient -l -w 0
   ```

   Compare before and after connecting. If more than one entry changes, retain
   the relevant USB/serial tree entries so their relationship can be checked;
   do not infer it from similar serial-number suffixes.

   On Windows, use **Device Manager → Ports → Properties → Details** to record
   the hardware IDs, bus-reported description and parent. A PowerShell summary:

   ```powershell
   Get-CimInstance Win32_SerialPort | Select-Object DeviceID, Name, Description, PNPDeviceID
   ```

   If that command omits a port shown in Device Manager, retain the Device
   Manager details instead. OS enumeration and MATLAB availability are separate.

4. Select the known model/port in the measurement window and take one reading
   as part of its device checklist. Record the driver's verified model alongside
   the USB information. Keep USB descriptor serial numbers distinct from any
   instrument identity returned through its command protocol.
5. Reconnect using another USB socket or hub and repeat the association check.
   Record which fields stayed stable and which port name changed. Share only the
   relevant device entries; unrelated device identifiers are unnecessary.

The first three steps read OS metadata only. The fourth is an explicit physical
measurement, performed with the instrument prepared as in its normal guide.

## Cases to check

| Setup | Required behavior |
| --- | --- |
| One instrument with an exact product name | Check that its named model and port agree with the protocol identity. |
| Generic family descriptor | Retain family information; require a model choice or a verified family discovery response. |
| Generic USB-to-serial bridge | Require explicit model selection; the bridge's vendor does not identify the meter. |
| Multiple instruments, including two of one model | Preserve a way to choose the intended physical device. |
| Port occupied by another program | Report availability separately from device identity. |
| Unsupported model or unexpected suffix | Do not map it to a supported model on a partial name match. |
| Wrong model selected manually | Verify the driver rejects the mismatch before applying acquisition settings or acquiring. |

Treat passive OS identification and active protocol identification as separate
steps. A family-specific read-only model query may distinguish models that share
a USB identifier. Test its responses and unsupported-command behavior through
the known family driver; do not send guessed protocols to unrelated ports.
Successful passive identification must still be followed by protocol identity
verification. Entering remote mode can itself change instrument state before
the identity reply, so normal connection cleanup still applies. A metadata match
alone does not validate settings, acquisition or measurement accuracy.

## Check saved identity

After the device checklist's successful reading, inspect the last reading's
`deviceType`, `instrumentMetadata`, its `port`, and any `instrumentSettings`
receipt. Finish the batch, load its MAT and confirm those values are unchanged. Compare them
with the instrument's actual identity, keeping unavailable or unqueried fields
explicit. See [metadata defaults by device](../session/README.md#diagnostics-and-provenance).

The complete MAT is the source for this check. The CSV intentionally contains
only selected columns. Inspect optional PR metadata separately when enabled;
its absence under the default setting is not a save failure.

## Record the result

For each tested combination, retain the code revision, OS/MATLAB version,
connection type, model, relevant descriptors and IDs, port association, protocol
identity, and any ambiguous or missing information. Label untouched combinations
untested. These observations determine which automatic-selection rules can be
implemented and checked with fixtures.

# Preparing and completing a CS-2000 measurement

This procedure covers ordinary emitted-light measurements with the direct current
driver or shared window. It follows the manufacturer's [CS-2000/CS-2000A
operating manual](https://www.konicaminolta.com/instruments/download/instruction_manual/display/pdf/cs-2000-2000a_instruction_eng.pdf)
and [communication specification Rev.7](https://www.konicaminolta.com.cn/instruments/download/software/driver/cs-20002000a_cs0700_eng.pdf).
Page numbers below are printed page numbers.

The shared window presents preparation guidance before the first live
measurement attempt. Open **Settings... → Instrument help** to read it again.

## Before connecting

1. Power the instrument and stabilize the target and measurement environment.
   The operating manual (p.23) specifies at least **20 minutes of warm-up** for
   the low-luminance conditions below, using Illuminant A (2856 K) as a guide:

   | Measurement angle | Target luminance requiring this warm-up |
   | --- | --- |
   | 1 degree | 2 cd/m² or lower |
   | 0.2 degree | 50 cd/m² or lower |
   | 0.1 degree | 200 cd/m² or lower |

   The same page also calls for warm-up outside normal room-temperature and
   humidity conditions, and another 20 minutes after powering off and on,
   even briefly. Stay within the rated operating environment (pp.3–4).
   Reopening a serial connection is not a power cycle. Record the power-on time
   when preparing low-luminance measurements.
2. Aim/focus, select the intended measurement angle, accessories, speed and
   synchronization, and keep the target stable through the entire reading.
   For weak sources, choose accuracy/repeatability versus speed deliberately;
   the manual discusses NORMAL/FAST and multi-integration modes on pp.28–29.
   Native `Connect`/`Measure` preserve these settings. The shared window applies
   Multi-Normal with a 1-second multi interval, internal ND Auto and No Sync
   before each reading, plus any staged overrides. Direct code can request the
   same recipe through [`applyAutomaticSettings`](settings.md). Accessory and
   correction selections stay unchanged unless explicitly overridden.
3. Close any other client using the port, then use the [measurement example](README.md#measure-and-save)
   or [shared window](batch-and-ui.md). Do not use `INIT` as a preparation or
   calibration step: it resets instrument data/settings (Rev.7 pp.74–75).

Record power-on time in the experiment notes; the software cannot determine
whether the instrument is warmed up. Apply the luminance thresholds using a
verified instrument unit, rather than assuming raw saved XYZ is in cd/m².
See [XYZ units and scientific meaning](protocol-and-data.md#scientific-meaning).

## What happens during one reading

| Stage | Instrument behavior | MATLAB behavior |
| --- | --- | --- |
| Pre-measurement | Estimates the required measurement duration; typically about 1–10 s. | Sends `MEAS,1`, then allows at least 35 s for its first reply. |
| Light and dark measurement | Measures the target, closes its internal shutter automatically, then measures dark current with the same integration time. The instrument subtracts that dark result internally. | Waits for the separate completion reply for the announced duration plus `ResponseTimeout`; it does not send another exposure or subtract a second dark spectrum. |
| Retrieval and persistence | Supplies completed spectrum, XYZ and conditions. | Validates and retains a complete reading, then saves it through the chosen workflow. The shared session also records cleanup warnings. |

The pre-measurement exchange is specified on Rev.7 p.41; automatic dark
measurement is described on operating-manual p.78. The announced duration is
002–242 **whole seconds**, covering the actual measurement after the first
reply. Integration time alone is shorter than the complete light/dark cycle
(operating-manual p.29).

**No separate lens-cap dark/zero calibration is required by this documented
ordinary workflow.** Measuring a black display patch is a target measurement;
it is distinct from the shutter-closed dark-current measurement. Leave the
target in place and let the instrument finish both internal phases. No command
is accepted during pre-measurement; the current synchronous interface has no
immediate instrument-abort control.

## Completion, errors and limits

Check the saved spectrum, XYZ, actual conditions and cleanup status. On timeout,
no partial row is appended and no automatic retry starts. A closed port does
not prove measurement stopped: establish that the instrument is idle before
following [recovery instructions](README.md#troubleshooting). Shutter,
temperature or cooling errors require investigating the instrument/environment;
they are not requests to take a manual dark reference.

## Object-color and reflectance measurements

The instrument can measure light reflected from an illuminated object. Keep the
illumination stable and uniform, and measure the reference white plate and
sample in the same position and at the same viewing/illumination angles. The
manufacturer's example (p.81) uses 45-degree illumination and perpendicular
viewing, conducts white calibration in CS-S10w's object-color mode, then replaces
the plate with the sample without changing geometry.

The driver keeps reflected radiance and instrument XYZ. Open
**Color → View → Reflectance / relight** for the separate host calculation:

1. Acquire and retain the matched white-plate and object spectra.
2. Select the object as the sample and the measured plate as the reference;
   supply its wavelength-dependent reflectance data. The host computes
   sample/reference × reference factor. The explicit ideal-white option gives
   a relative spectral ratio and does not establish calibrated reflectance.
3. Select the illuminant for the derived object color. The originals remain
   unchanged; the output is a derived result for that geometry and assumes a
   nonfluorescent object.
4. After completing the selections, check **Reflective object; same setup**
   to confirm those measurement conditions, then click **Apply view**.
   Use **Export analysis MAT...** to save the derived result separately from
   the original measurements.

This substitution equation is described in
[NIST SP250-71](https://www.nist.gov/document/sp25071-colorimeterpdf),
p.2, equation (2.1), for its reference 0:45 reflectometer. This setup does not
inherit that instrument's validation or uncertainty. This UI does not perform
CS-S10w white calibration or claim numerical equivalence to it. Selecting a
white reading for the UI's Lab comparison performs none of the above steps.

## Advanced setup: calibration channels

**Ch00** uses the manufacturer's fixed calibration; **Ch01–Ch10** contain
stored user corrections when populated (p.47). Select an existing channel through
**Settings... → Measurement settings**, or the direct
[settings API](settings.md). Selecting a populated channel does not create or update calibration;
an empty requested channel is rejected before setting writes. Creating user
calibration is not a routine preparation step. Without an explicit override,
the driver preserves and records the selected channel. Keep
the laboratory's intended configuration; channel names and the factory
calibration date do not prove calibration validity. The manual recommends an
annual checkup (p.5); follow the laboratory's calibration policy.

The protocol returns completed results, not separate light/dark sensor frames
or a verified warm-up status. Follow the operating manual's preparation and
warm-up requirements before acquisition.

## Instrument help

The window's **Settings... → Instrument help** summarizes preparation and
settings for the CS-2000.

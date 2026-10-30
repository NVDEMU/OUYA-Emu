# OUYA controller compatibility

The controller goal is the stock OUYA input contract, not simply treating every
pad as an Xbox controller.

## Input path

1. The host OS and Android Emulator expose the connected controller as an
   Android game controller.
2. The guest receives Android KeyEvent and MotionEvent events.
3. The imported OUYA/Cortex framework performs the official hardware-to-OUYA
   remapping where the dashboard or game uses the OUYA SDK.
4. OUYA applications receive the standard OUYA O/U/Y/A buttons, D-pad, and
   analog axes.

The official OUYA Everywhere documentation describes Cortex as providing
controller remapping across controller manufacturers. It recommends
`OuyaActivity` or the `OuyaInputMapper` APIs for applications. That original
framework is preferred over reimplementing its private mapping behavior.

## Host fallback mapping

`ouya-controller-profile.json` records the positional fallback for a generic
host pad:

| Host position | OUYA button |
| --- | --- |
| South / bottom | O (confirm) |
| East / right | U |
| North / top | Y |
| West / left | A |

D-pad, sticks, L1/R1, L2/R2, Start, Back, and pointer/touch-surface input are
also part of the compatibility target.

This profile is a specification, not a system-wide input hook. The authentic
Cortex framework must be imported and verified first. If it does not support
the Android Emulator's virtual gamepad device, the next implementation step
is a privileged guest-side input adapter; a normal foreground APK cannot
reliably intercept and rewrite input for every other application.

## Validation

- Confirm Android Emulator detects the host controller with `adb shell
  dumpsys input`.
- Confirm the OUYA dashboard responds to D-pad navigation and O/confirm.
- Confirm back/cancel and shoulder navigation.
- Confirm left/right stick axes and trigger analog values.
- Confirm the original OUYA controller touch surface is available as pointer
  input; do not assume a generic gamepad provides one.
- Test the same events in an original OUYA game that uses Cortex
  `OuyaActivity` / `OuyaInputMapper`.

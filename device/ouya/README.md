# Authentic OUYA system integration

The target is the **original OUYA dashboard and its system applications**, not
an OUYA-themed replacement launcher. The in-repo `OUYALauncher` is a
development fallback and is deliberately not installed by the product fragment.

## Important architecture boundary

The stock OUYA OTA is for a Tegra 3 ARM console. Its boot image, kernel,
device tree, NVIDIA graphics stack, and board services cannot simply be
booted by the Android Emulator's virtual hardware. This project therefore
uses an ARM64 Android Emulator guest as the hostable Android runtime and
imports the original OUYA application layer from a stock OTA. This preserves
the real dashboard APK and resources; it does not claim to emulate Tegra 3.

An ARM64 guest is required because OUYA titles commonly contain ARM32 native
libraries. Select an Android Emulator ARM64 system image with 32-bit app
support. Compatibility still depends on the Android version and each title.

## Import the authentic dashboard

Use a stock OUYA OTA you obtained yourself, such as
`RC-OUYA-1.2.1427-r1_ota.zip`. The project does not redistribute firmware.

From the repository root:

```bash
python3 tools/import_ouya_firmware.py /path/to/RC-OUYA-1.2.1427-r1_ota.zip
```

The importer stages OUYA/Cortex-named APKs from `system/app` and
`system/priv-app` into `vendor/ouya-emu/proprietary/ouya`, writes an
inventory report, and generates `ouya-imported.mk`. It deliberately does not
copy the Tegra kernel, bootloader, vendor drivers, or unrelated Android system
apps. Review `import-report.json` and confirm the original console/dashboard
APK is present before building. If the OTA stores files in a payload or
filesystem image rather than directly in the ZIP, extract its system
filesystem first and adapt the importer input; the script will not pretend an
unrecognized OTA was imported.

Include this product fragment from the selected Android product makefile:

```make
include vendor/ouya-emu/device/ouya/ouya_product.mk
```

The generated makefile copies the imported APKs into the guest's system
partition. This is a first integration pass: privileged permissions,
signature/shared-UID assumptions, missing OUYA framework services, and
obsolete Android APIs may still need explicit compatibility work.

## Boot and select the actual dashboard

Create an Android Emulator AVD named `OUYA-Emu` using an ARM64 system image
with ARM32 app support (Android 9–11 is a sensible first test). Launch it:

```bash
OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
```

Then install the imported original apps into the guest:

```bash
bash tools/install-ouya-apks.sh
```

The default installer uses `adb install`, which persists across emulator
restarts and is the best first compatibility test. If a package must live in
the system partition, launch an AOSP/userdebug AVD with
`OUYA_WRITABLE_SYSTEM=1` and use
`bash tools/install-ouya-apks.sh --system`. That mode requires `adb root`
and `adb remount`; changes made to a temporary writable system image may be
lost when the emulator exits. If firmware apps require platform-signature
permissions or a shared system UID, copying the APKs is not sufficient; the
relevant OUYA framework and signing compatibility still need to be solved.

After the imported firmware apps are installed, query HOME candidates:

```bash
adb shell cmd package query-activities --brief \\\
  -a android.intent.action.MAIN -c android.intent.category.HOME
```

Use the component belonging to the original OUYA dashboard (not
`tv.ouya.emulator.launcher`) to select it as HOME:

```bash
bash tools/set-ouya-home.sh package.name/.DashboardActivity
```

The imported `RC-OUYA-1.2.1427-r1` dashboard manifest was inspected: its package is `tv.ouya.console`, and the HOME activity is `tv.ouya.console.launcher.guide.GuideActivity`. For that exact firmware, try:

```bash
bash tools/set-ouya-home.sh tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity
```

This identifies the manifest component, not a successful launch. The dashboard APK has no `classes.dex`; its code is supplied as a matching Dalvik `.odex`. Android 9–11 uses ART and cannot directly consume that Android 4.1 Dalvik odex. A deodex/rebuild or Android 4.1-compatible runtime path is therefore required before the original dashboard can be expected to execute. The manifest also requests numerous privileged Android and OUYA permissions, so merely sideloading it is insufficient.

## Controller target

The host-to-OUYA positional mapping contract is in
`controller/ouya-controller-profile.json`:

- South / bottom face button → OUYA O (confirm)
- East / right face button → OUYA U
- North / top face button → OUYA Y
- West / left face button → OUYA A
- D-pad and left/right sticks → navigation / analog input
- Bumpers and triggers → L1/R1 and L2/R2
- Touch surface → pointer movement and primary click

This describes the intended mapping. Android Emulator gamepad forwarding and
the guest-side OUYA framework translation must be validated on a running
guest; touch-surface forwarding is not yet implemented or claimed.

## Validation checklist

- [ ] ARM64 AVD boots reliably on each supported host OS.
- [ ] Stock OUYA dashboard APK and all required companion APKs are imported.
- [ ] Dashboard launches with its original graphics, tabs, and assets.
- [ ] HOME button returns to the original dashboard.
- [ ] D-pad, face buttons, sticks, bumpers, and triggers behave correctly.
- [ ] OUYA touch surface behaves as pointer input.
- [ ] ARM32 native OUYA game launches and renders.
- [ ] OUYA SDK services (controller, billing/store, discover, firmware) are
      stubbed or redirected only where required, without replacing dashboard UI.


## Installing games

Games are installed as Android packages, not copied into the firmware image.
With the guest running, use `tools/install-ouya-game.sh /path/to/title.apk`.
The installer also accepts `.apks` split bundles. It invokes the guest's
Android package manager through ADB and leaves the original game package
intact. Installation and successful execution are separate checks: ARM32
native code, OUYA SDK services, controller input, graphics, and obsolete
Android APIs may still need compatibility implementation.

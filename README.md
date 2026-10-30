# OUYA-Emu

**A desktop-hosted environment for the original OUYA console experience.**

The goal is to boot the **real OUYA dashboard**, navigate its original Play,
Discover, Make, and Manage screens with a controller, and launch original
OUYA games. This is analogous to Dolphin's Wii System Menu support: the
authentic system UI is the target, not a newly drawn imitation.

## Architecture

OUYA firmware is an Android 4.x build for NVIDIA Tegra 3 hardware. The stock
kernel, bootloader, device tree, and NVIDIA drivers are board-specific and
cannot be dropped into the Android Emulator's virtual hardware. OUYA-Emu
therefore separates the original OUYA application layer from the physical
console boot chain:

1. **Host runtime:** Android Emulator provides a desktop-hosted Android guest.
2. **OUYA firmware layer:** import the original OUYA/Cortex APKs from a
   user-supplied stock OTA. Do not substitute the in-repo placeholder launcher.
3. **Authentic dashboard:** select the imported OUYA dashboard as the guest's
   HOME activity and retain its original UI/resources.
4. **Controller path:** map host gamepad events to OUYA's O/U/Y/A face-button
   layout, D-pad, sticks, shoulders, triggers, and touch surface.

This approach aims to preserve the actual OUYA menu and application behavior.
It is not a cycle-accurate Tegra 3 emulator, and it does not imply every
original game or proprietary service already works.

## Current implementation status

- [x] BlissOS Typhoon x86_64 source manifest retained as an experimental
      Android image build base.
- [x] Host Android Emulator AVD launcher script added.
- [x] Stock OTA APK importer added (user-supplied firmware only).
- [x] Product fragment now imports staged OUYA APKs and no longer installs
      the replacement `OUYALauncher` as the system HOME.
- [x] HOME-selection helper added for the actual dashboard activity.
- [x] OUYA positional controller mapping contract documented.
- [ ] Build and boot the ARM64 AVD with 32-bit app support.
- [ ] Import and identify the original dashboard and companion APKs from a
      real OTA; verify the dashboard launches as HOME.
- [ ] Implement missing OUYA privileged permissions and framework services.
- [ ] Validate all controller events, including the controller touch surface.
- [ ] Launch and test an original ARM32 OUYA game.

The existing `OUYALauncher` source is retained only as a development fallback;
it is intentionally not included in the product packages.

## Quick start: host emulator

Install Android SDK Platform-Tools and Android Emulator. Create an AVD named
`OUYA-Emu` using an ARM64 AOSP/userdebug Android system image with ARM32 app
support (Android 9–11 is a sensible first test).

```bash
OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
```

The wrapper expects the Android SDK at `ANDROID_SDK_ROOT` or `ANDROID_HOME`.
For optional system-partition installation, set `OUYA_WRITABLE_SYSTEM=1`
and use an AOSP/userdebug AVD that permits `adb root` and `adb remount`.

## Import original OUYA firmware apps

Obtain a stock OUYA OTA legally and keep it local. For example, the final
official package is commonly referenced as
`RC-OUYA-1.2.1427-r1_ota.zip`.

```bash
python3 tools/import_ouya_firmware.py /path/to/RC-OUYA-1.2.1427-r1_ota.zip
```

The importer stages OUYA/Cortex-named APKs from the OTA and generates
`vendor/ouya-emu/proprietary/ouya/ouya-imported.mk`. Review its
`import-report.json` and confirm that the original dashboard and companion
packages were found. Include the project product fragment from the selected
Android product makefile:

```make
include vendor/ouya-emu/device/ouya/ouya_product.mk
```

After importing, sideload the original APKs into the guest:

```bash
bash tools/install-ouya-apks.sh
```

This installs them as regular apps first, which is the simplest persistent
compatibility test. If a package needs to be a system app, use an AOSP/userdebug
AVD and the optional mode:

```bash
OUYA_WRITABLE_SYSTEM=1 OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
bash tools/install-ouya-apks.sh --system
```

Temporary writable-system changes may be lost when the emulator exits; a
custom built system image is the durable solution.

Then query HOME candidates and select the actual dashboard component:

```bash
adb shell cmd package query-activities --brief \\\
  -a android.intent.action.MAIN -c android.intent.category.HOME
bash tools/set-ouya-home.sh package.name/.DashboardActivity
```

The imported `RC-OUYA-1.2.1427-r1` dashboard manifest was inspected: its package is `tv.ouya.console`, and the HOME activity is `tv.ouya.console.launcher.guide.GuideActivity`. For that exact firmware, try:

```bash
bash tools/set-ouya-home.sh tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity
```

This identifies the manifest component, not a successful launch. The dashboard APK has no `classes.dex`; its code is supplied as a matching Dalvik `.odex`. Android 9–11 uses ART and cannot directly consume that Android 4.1 Dalvik odex. A deodex/rebuild or Android 4.1-compatible runtime path is therefore required before the original dashboard can be expected to execute. The manifest also requests numerous privileged Android and OUYA permissions, so merely sideloading it is insufficient. The Bliss product-fragment route is a separate source-image
integration path, not the AVD workflow above.

See [the authentic system integration guide](device/ouya/README.md) and
[controller mapping contract](controller/ouya-controller-profile.json).

## Important limitations

- The stock OUYA OTA is not a bootable Android Emulator system image. Its
  Tegra-specific boot chain and drivers are not used.
- An ARM64 guest with ARM32 compatibility is required for OUYA native code.
  Translation and game compatibility are not yet verified.
- Copying original APKs is only the first step. Some OUYA applications may
  require signature permissions, privileged permissions, shared UIDs,
  framework classes, native libraries, or backend services.
- The dashboard may open but fail to populate Discover/Store content until
  the corresponding OUYA APIs are implemented or redirected.
- No proprietary firmware, OUYA APKs, games, keys, or game data are included.

## Source build base

The repository retains the BlissOS Typhoon manifest for experimental Android
image integration:

```bash
repo init -u https://github.com/NVDEMU/OUYA-Emu.git -b typhoon-x86 -m bliss.xml --git-lfs
repo sync -c --force-sync --no-tags --no-clone-bundle -j"$(nproc --all)" --optimized-fetch --prune
```

A full BlissOS source build requires a Linux build host and substantial disk
space. This source manifest path is separate from the host Android Emulator
AVD workflow above.

## License

See [LICENSE](LICENSE) for the inherited base repository license. New project
files use the same license unless otherwise noted.


## Add OUYA games from APK files

OUYA titles are Android applications. With an OUYA guest running and
`ANDROID_SDK_ROOT` (or `ANDROID_HOME`) configured, install a game directly:

```bash
bash tools/install-ouya-game.sh "/path/to/Game.apk"
```

For split APK bundles exported by some Android stores/tools, pass the
`.apks` bundle instead:

```bash
bash tools/install-ouya-game.sh "/path/to/Game.apks"
```

The script uses Android's package installer inside the guest. It does not
include, download, or bypass game licensing. Once installed, launch the game
from the guest's app list or the OUYA dashboard's Play area if the dashboard
recognizes the package. A successful APK install does not guarantee runtime
compatibility: many OUYA games use ARMv7 native libraries, OUYA SDK/controller
APIs, Android 4.x-era behavior, or Tegra-specific graphics assumptions. The
current Android Emulator guest must provide ARM32 app support; compatibility
and dashboard catalog integration are separate work items.

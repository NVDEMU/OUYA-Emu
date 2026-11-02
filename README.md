# OUYA-Emu

**A desktop-hosted environment for the original OUYA console experience.**

The target is the **real OUYA dashboard**—its Play, Discover, Make, and Manage screens—and the ability to launch original OUYA games. This is not an OUYA-themed replacement launcher.

## Current status

- [x] Stock OTA importer for OUYA/Cortex APKs and matching Android 4.1 framework files.
- [x] Dalvik ODEX dependency inventory; the stock launcher names 11 framework ODEX files, all present in the supplied OTA.
- [x] Local deodex/rebuild/signing pipeline for OUYA system APKs.
- [x] APK installer for games, including split-APK bundles.
- [x] Automated importer tests and shell syntax checks on every push.
- [ ] Run deodexing with baksmali/smali and Android SDK build-tools on a host.
- [ ] Boot a compatible ARM64 guest with ARM32 application support.
- [ ] Verify that the authentic dashboard launches as HOME and that its OUYA services work.
- [ ] Validate controller events and launch an original ARM32 OUYA game.

The final four items are runtime milestones. Successful firmware extraction does not prove that the dashboard has booted or that a game runs.

## Architecture and important boundary

The stock OUYA image is Android 4.1.2 (API 16) for NVIDIA Tegra 3 ARM hardware. The OTA ZIP contains the system partition contents and a kernel boot image, but it is **not a complete raw console image**: it does not provide the full bootloader/BCT/partition set needed to reproduce the physical boot chain. The Tegra kernel and proprietary GPU/HAL stack are also board-specific.

The current development route is a desktop-hosted Android guest with the authentic OUYA application layer imported from the user's own OTA. It does not yet emulate Tegra 3 cycle-for-cycle or reproduce the OUYA hardware boot chain.

A key compatibility issue was identified in the stock firmware: OUYALauncher.apk has no classes.dex. Its executable code is in OUYALauncher.odex, optimized for Android 4.1 Dalvik. Android 9–11 uses ART and cannot load that old ODEX directly. The importer now stages the matching framework ODEX/JAR set, and the conversion tool rebuilds each OUYA APK with a classes.dex for testing on a later Android guest.

## Requirements

- Android SDK with Emulator, Platform-Tools, and Build-Tools (including apksigner).
- A Java JDK (java and keytool), plus the pinned smali/baksmali 3.0.10 fat JARs downloaded by the setup script.
- An ARM64 Android Emulator system image with 32-bit ARM application support.
- A stock OUYA OTA that you obtained yourself. Firmware and games are not redistributed here.

The Android guest image is a compatibility test target, not a copy of the OUYA OS. Android API compatibility, system permissions, OUYA SDK services, ARM32 native code, and graphics behavior still need runtime validation.

## Build the authentic dashboard APKs from your OTA

Keep the OTA local and run these commands from the repository root:

~~~sh
python3 tools/import_ouya_firmware.py /path/to/RC-OUYA-1.2.1427-r1_ota.zip
~~~

The importer stages OUYA/Cortex APK+ODEX pairs under vendor/ouya-emu/proprietary/ouya/system and the exact system/framework JAR+ODEX set under vendor/ouya-emu/proprietary/ouya/deodex/system/framework. It writes firmware-report.json, including the dependencies read from each Dalvik ODEX. The proprietary staging tree is ignored by Git.

Set up the pinned conversion tools and then rebuild the APKs:

~~~sh
bash tools/setup-smali.sh
ANDROID_SDK_ROOT=/path/to/Android/Sdk bash tools/deodex-ouya-apps.sh
~~~

The setup script downloads the official v3.0.10 fat JARs from the baksmali/smali release and verifies both SHA-256 digests. Manual paths are also supported:

~~~sh
ANDROID_SDK_ROOT=/path/to/Android/Sdk BAKSMALI_JAR=/path/to/baksmali-fat.jar SMALI_JAR=/path/to/smali-fat.jar bash tools/deodex-ouya-apps.sh
~~~

The script deodexes against the framework extracted from the **same OTA**, assembles classes.dex, removes stale APK signature records, and signs the rebuilt APKs with a local debug key. It does not and cannot recreate OUYA's original signing key. Therefore, OUYA platform-signature permissions and shared-UID assumptions may still fail; this is an explicit compatibility task, not something signing with a local key solves.

The script outputs rebuilt APKs under vendor/ouya-emu/proprietary/ouya/deodexed/system/app and writes a local deodex report. The generated ouya-imported.mk copies these rebuilt APKs into an Android product image. Run the conversion step before building a product image.

## Boot a guest and try the original dashboard

Create an Android Emulator AVD named OUYA-Emu using an ARM64 system image that includes 32-bit ARM application support. Android 9 / API 28 is a reasonable initial compatibility target for older apps; verify the image actually exposes armeabi-v7a before testing ARM32 games.

Start the AVD:

~~~sh
OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
~~~

Install the locally rebuilt firmware apps. A user install is useful as a first package-manager check:

~~~sh
bash tools/install-ouya-apks.sh
~~~

For firmware apps that need system placement, use an AOSP/userdebug image that allows adb root and remount:

~~~sh
OUYA_WRITABLE_SYSTEM=1 OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
bash tools/install-ouya-apks.sh --system
~~~

Select the actual dashboard HOME component from this firmware:

~~~sh
bash tools/set-ouya-home.sh tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity
~~~

The component comes from the stock manifest. A successful set-home command is not proof that the activity has rendered; check logcat and the process state. If it crashes, collect:

~~~sh
adb logcat -d -s AndroidRuntime ActivityTaskManager PackageManager
~~~

Likely remaining blockers include unavailable Android 4.x internal APIs, missing OUYA privileged permissions, framework services that were built into the console firmware, removed platform behaviors, and vendor graphics assumptions. Work through those errors rather than replacing the original UI with a lookalike.

## Install games from APK files

With the guest running and the Android SDK configured, install a game APK:

~~~sh
bash tools/install-ouya-game.sh /path/to/Game.apk
~~~

Split APK bundles are also accepted:

~~~sh
bash tools/install-ouya-game.sh /path/to/Game.apks
~~~

This uses Android's package installer. It does not download games or bypass licensing. An installed APK may still fail to run if the guest lacks ARM32 ABI support, the OUYA SDK/controller APIs, compatible graphics behavior, or an expected Android 4.x service.

## Controller target

The host-to-OUYA positional mapping contract is in controller/ouya-controller-profile.json. The intent is:

- South / bottom face button → OUYA O (confirm)
- East / right face button → OUYA U
- North / top face button → OUYA Y
- West / left face button → OUYA A
- D-pad and sticks → navigation / analog input
- Bumpers and triggers → L1/R1 and L2/R2
- Touch surface → pointer movement and primary click

This is a mapping target, not a validated claim. Android Emulator gamepad forwarding and the guest's OUYA controller services still need testing; touch-surface forwarding is not implemented yet.

## Source build base

The repository retains the BlissOS Typhoon x86_64 manifest as an experimental Android source-image build base:

~~~sh
repo init -u https://github.com/NVDEMU/OUYA-Emu.git -b typhoon-x86 -m bliss.xml --git-lfs
repo sync -c --force-sync --no-tags --no-clone-bundle -j"$(nproc --all)" --optimized-fetch --prune
~~~

A full BlissOS source build needs a Linux build host and substantial disk space. This path does not make the stock Tegra kernel boot on generic virtual hardware; it is separate from the ARM64 Android Emulator guest workflow.

## License

See LICENSE for the inherited base repository license. New project files use the same license unless otherwise noted.

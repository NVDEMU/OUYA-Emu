# Authentic OUYA system integration

The target is the **original OUYA dashboard and system applications**, not an OUYA-themed replacement launcher. The in-repo OUYALauncher source is only a development fallback and is not installed as HOME.

## What the stock OTA contains

The RC-OUYA-1.2.1427-r1 OTA identifies Android 4.1.2 / API 16, device ouya_1_1, and ARMv7-A. It contains a kernel boot image and the complete system tree, including system/framework JAR/ODEX files. It is not a complete raw console flash image and does not supply the full bootloader/BCT/partition chain.

The OTA's OUYALauncher APK has no classes.dex. It is paired with a Dalvik ODEX whose dependency block names 11 framework ODEX files. The importer stages the matching framework tree so deodexing uses the exact framework from the same firmware release.

## Import and deodex

Run from the repository root with a locally obtained stock OTA:

~~~sh
python3 tools/import_ouya_firmware.py /path/to/RC-OUYA-1.2.1427-r1_ota.zip
~~~

This stages OUYA/Cortex APK and ODEX pairs under vendor/ouya-emu/proprietary/ouya/system, the full system/framework file set under vendor/ouya-emu/proprietary/ouya/deodex/system/framework, boot ramdisk configuration, and firmware-report.json. The proprietary files are not committed.

Install Java and Android SDK Build-Tools with apksigner. Then download the pinned smali/baksmali toolchain and run:

~~~sh
bash tools/setup-smali.sh
ANDROID_SDK_ROOT=/path/to/Android/Sdk bash tools/deodex-ouya-apps.sh
~~~

The downloader uses the official v3.0.10 release assets and verifies their SHA-256 checksums. You can override the JAR paths with BAKSMALI_JAR and SMALI_JAR. The conversion script uses API level 16, rebuilds APKs with classes.dex, removes invalidated stock signature records, and signs the result with a local debug key. That local key is not the OUYA platform key. Any signature-protected permissions, shared UID, or privileged service dependencies must be handled separately.

The rebuilt APKs are written to vendor/ouya-emu/proprietary/ouya/deodexed/system/app. The generated ouya-imported.mk references only these rebuilt APKs; raw Dalvik ODEX files are never copied into a modern ART system image.

## Guest runtime

Create an AVD named OUYA-Emu with an ARM64 system image that includes ARM32 application support. API 28 / Android 9 is a reasonable first compatibility test for old APK behavior, but native 32-bit support must be verified on the chosen image.

Launch the AVD:

~~~sh
OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
~~~

Install the rebuilt firmware APKs:

~~~sh
bash tools/install-ouya-apks.sh
~~~

If system placement is needed, use an AOSP/userdebug guest with writable system support:

~~~sh
OUYA_WRITABLE_SYSTEM=1 OUYA_AVD_NAME=OUYA-Emu bash tools/run-ouya-emu.sh
bash tools/install-ouya-apks.sh --system
~~~

The stock dashboard HOME activity is:

~~~sh
bash tools/set-ouya-home.sh tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity
~~~

This component is taken from the stock manifest; it is not evidence of a successful launch. Use logcat to inspect startup crashes:

~~~sh
adb logcat -d -s AndroidRuntime ActivityTaskManager PackageManager
~~~

The likely next blockers are missing Android 4.x APIs, signature-protected permissions, OUYA-specific framework services, and Tegra-specific graphics paths. Fix the actual runtime exceptions and missing service calls without replacing the dashboard UI.

## Controller and game runtime

Controller mapping is documented in controller/ouya-controller-profile.json. It remains unvalidated in a running guest. Games install through tools/install-ouya-game.sh; that installer accepts APKs and split .apks archives. A successful install is not a successful launch: ARM32 ABI, OUYA SDK/controller services, graphics, and old Android API compatibility all need separate checks.

# OUYA Android guest profile

This directory contains the first OUYA-specific product overlay for the BlissOS Typhoon x86_64 Android guest.

## What this does

- Adds the OUYA launcher to the system image through `ouya_product.mk`.
- Sets a landscape, television-style default UI profile.
- Leaves host GPU selection and ARM native-code translation to the Android guest/build configuration instead of pretending that generic x86_64 automatically reproduces Tegra 3.

## Integrate into a BlissOS source checkout

After syncing the manifest into an Android source workspace, copy or check out this overlay at `device/ouya`. Then include this fragment from the x86_64 product makefile used by your build:

```make
include device/ouya/ouya_product.mk
```

The fragment is intentionally an include, not a standalone lunch target. The exact parent product makefile depends on the BlissOS branch and should be confirmed in the synced source tree before modifying it.

Build the selected x86_64 product using the branch's documented BlissOS commands. Do not mark the guest as OUYA-compatible merely because the image builds: verify boot, launcher selection, controller input, ARM32 translation, and actual OUYA APK behavior separately.

## ARM application compatibility

OUYA software commonly contains ARM native libraries. An x86_64 Android image needs a working ARM translation layer for those applications. BlissOS has documented optional integrations for Houdini and Google's `ndk_translation`, but binary availability, licensing, ABI coverage, and compatibility vary by branch. Do not bundle proprietary translation binaries in this repository. Record the exact provider/version and test results when a legally obtained compatible layer is configured.

## Display and input

Use a landscape guest display. OUYA's original output modes include 720p and 1080p; test both. The launcher supports Android D-pad and standard game-controller key events, but physical OUYA-controller Bluetooth pairing and touchpad behavior still need dedicated testing.

# OUYA Android guest profile

This is the first OUYA-specific product overlay for the BlissOS Typhoon x86_64 guest.

## Integration

The manifest syncs this repository into `vendor/ouya-emu`. Include the product fragment from the selected x86_64 product makefile:

```make
include vendor/ouya-emu/device/ouya/ouya_product.mk
```

This fragment is intentionally not a standalone lunch target. Confirm the actual parent product makefile in the synced branch before editing it.

## ARM compatibility

OUYA apps commonly include ARM native libraries. An x86_64 Android guest needs a compatible ARM translation layer. BlissOS has documented optional Houdini and Google's `ndk_translation` integrations, but binary availability, licensing, ABI coverage and compatibility vary. No proprietary translation binaries are bundled here.

## Validation still required

A successful image build does not prove OUYA compatibility. Test boot, default launcher selection, 720p/1080p output, controller input, ARM32 translation and actual OUYA APKs separately. The launcher currently handles standard Android gamepad/D-pad events; Bluetooth pairing, touchpad behavior and proprietary OUYA services remain future work.

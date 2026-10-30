# OUYA Launcher

A minimal Android home application for OUYA-Emu.

## Current functionality

- Registers as the Android HOME activity.
- Discovers installed applications advertising `tv.ouya.intent.category.GAME`.
- Displays a focusable, controller-navigable game list.
- Launches the selected game.
- Refreshes the list when returning from a game.

## Build integration

The app uses Soong. Include `OUYALauncher` in the product with:

```make
PRODUCT_PACKAGES += OUYALauncher
```

The companion product fragment is `device/ouya/ouya_product.mk`.

## Not implemented yet

This is deliberately a first launcher milestone. It does not yet reproduce the original OUYA storefront, user accounts, purchase flow, system-menu overlay, proprietary OUYA SDK services, screenshots, or gamepad touchpad behavior. It also has not yet been compiled against the selected BlissOS branch or tested in a booted image.

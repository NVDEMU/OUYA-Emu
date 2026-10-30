# OUYA Launcher

A minimal Android HOME application for OUYA-Emu.

- Registers as the Android HOME activity.
- Discovers apps declaring `tv.ouya.intent.category.GAME`.
- Displays a focusable game list navigable with D-pad/controller input.
- Launches selected games and refreshes when returning.

Build with Soong and include `OUYALauncher` in the product using `device/ouya/ouya_product.mk`.

This is only the launcher foundation. The original storefront, account/purchase services, proprietary OUYA SDK APIs, system-menu overlay, screenshots, and controller touchpad behavior are not implemented yet. This app has not yet been compiled against BlissOS Typhoon or tested in a booted image.

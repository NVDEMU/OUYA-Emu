# OUYA-Emu product additions.
# Include this fragment from the selected BlissOS x86_64 product makefile.
PRODUCT_PACKAGES += \
    OUYALauncher

PRODUCT_PRODUCT_PROPERTIES += \
    ro.ouyaemu.profile=ouya \
    persist.sys.strictmode.disable=1

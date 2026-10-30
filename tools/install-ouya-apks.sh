#!/usr/bin/env bash
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
ADB="${ANDROID_SDK_ROOT:+$ANDROID_SDK_ROOT/platform-tools/adb}"
STAGING="${1:-vendor/ouya-emu/proprietary/ouya/system}"

if [[ -z "$ADB" || ! -x "$ADB" ]]; then
  echo "Set ANDROID_SDK_ROOT and install Android platform-tools." >&2
  exit 2
fi
if [[ ! -d "$STAGING" ]]; then
  echo "Imported firmware staging directory not found: $STAGING" >&2
  echo "Run tools/import_ouya_firmware.py first." >&2
  exit 2
fi

found=0
"$ADB" wait-for-device
"$ADB" root
"$ADB" wait-for-device
if ! "$ADB" remount; then
  echo "Could not remount the emulator system partition. Use an AOSP/userdebug AVD and launch with -writable-system." >&2
  exit 1
fi

while IFS= read -r -d '' apk; do
  found=1
  relative="${apk#"$STAGING/"}"
  remote="/system/$relative"
  remote_dir="${remote%/*}"
  echo "Installing original firmware APK: $relative"
  "$ADB" shell "mkdir -p '$remote_dir'"
  "$ADB" push "$apk" "$remote"
  "$ADB" shell "chown root:root '$remote' && chmod 0644 '$remote'"
done < <(find "$STAGING/app" "$STAGING/priv-app" -type f -name '*.apk' -print0 2>/dev/null)

if [[ "$found" -eq 0 ]]; then
  echo "No staged OUYA APKs found under $STAGING/app or priv-app." >&2
  exit 2
fi

"$ADB" shell "restorecon -RF /system/app /system/priv-app || true"
echo "OUYA APKs staged. Rebooting guest..."
"$ADB" reboot
"$ADB" wait-for-device
echo "Guest rebooted. Discover the original dashboard HOME component with:"
echo "  adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME"

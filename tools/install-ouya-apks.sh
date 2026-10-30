#!/usr/bin/env bash
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
ADB="${ANDROID_SDK_ROOT:+$ANDROID_SDK_ROOT/platform-tools/adb}"
MODE="user"
if [[ "${1:-}" == "--system" ]]; then
  MODE="system"
  shift
fi
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
if [[ "$MODE" == "system" ]]; then
  "$ADB" root
  "$ADB" wait-for-device
  if ! "$ADB" remount; then
    echo "Could not remount the emulator system partition. Use an AOSP/userdebug AVD and launch with OUYA_WRITABLE_SYSTEM=1." >&2
    exit 1
  fi
fi

while IFS= read -r -d '' apk; do
  found=1
  relative="${apk#"$STAGING/"}"
  if [[ "$MODE" == "system" ]]; then
    remote="/system/$relative"
    remote_dir="${remote%/*}"
    echo "Copying original firmware APK to system: $relative"
    "$ADB" shell "mkdir -p '$remote_dir'"
    "$ADB" push "$apk" "$remote"
    "$ADB" shell "chown root:root '$remote' && chmod 0644 '$remote'"
    # Preserve the matching legacy Dalvik optimized code when present.
    odex="${apk%.apk}.odex"
    if [[ -f "$odex" ]]; then
      remote_odex="${remote%.apk}.odex"
      echo "Copying matching Dalvik ODEX: ${odex##*/}"
      "$ADB" push "$odex" "$remote_odex"
      "$ADB" shell "chown root:root '$remote_odex' && chmod 0644 '$remote_odex'"
    fi
  else
    echo "Installing original firmware APK as an app: $relative"
    "$ADB" install -r "$apk"
  fi
done < <(find "$STAGING/app" "$STAGING/priv-app" -type f -name '*.apk' -print0 2>/dev/null)

if [[ "$found" -eq 0 ]]; then
  echo "No staged OUYA APKs found under $STAGING/app or priv-app." >&2
  exit 2
fi

if [[ "$MODE" == "system" ]]; then
  "$ADB" shell "restorecon -RF /system/app /system/priv-app || true"
  "$ADB" reboot
  "$ADB" wait-for-device
  echo "System APKs copied. If changes disappear after closing the emulator, build them into the AVD system image instead."
else
  echo "APK install complete. Some firmware apps may require privileged permissions or a matching platform signature."
fi
echo "Discover the dashboard HOME component with:"
echo "  adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME"

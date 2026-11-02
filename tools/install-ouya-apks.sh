#!/usr/bin/env bash
# Install rebuilt OUYA system APKs (classes.dex embedded) into the guest.
set -euo pipefail

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
ADB="${SDK_ROOT:+$SDK_ROOT/platform-tools/adb}"
MODE="user"
if [[ "${1:-}" == "--system" ]]; then MODE="system"; shift; fi
ROOT_STAGING="${1:-vendor/ouya-emu/proprietary/ouya}"

if [[ -z "$ADB" || ! -x "$ADB" ]]; then
  echo "Set ANDROID_SDK_ROOT and install Android platform-tools." >&2
  exit 2
fi
if [[ -d "$ROOT_STAGING/deodexed/system" ]]; then
  STAGING="$ROOT_STAGING/deodexed/system"
elif [[ -d "$ROOT_STAGING/system/app" ]]; then
  STAGING="$ROOT_STAGING/system"
elif [[ -d "$ROOT_STAGING/app" ]]; then
  STAGING="$ROOT_STAGING"
else
  echo "Deodexed OUYA APK staging not found under: $ROOT_STAGING" >&2
  echo "Run tools/import_ouya_firmware.py, then tools/deodex-ouya-apps.sh." >&2
  exit 2
fi

found=0
"$ADB" wait-for-device
if [[ "$MODE" == "system" ]]; then
  "$ADB" root
  "$ADB" wait-for-device
  if ! "$ADB" remount; then
    echo "Could not remount the emulator system partition. Use an AOSP/userdebug AVD." >&2
    exit 1
  fi
fi

while IFS= read -r -d '' apk; do
  found=1
  relative="${apk#"$STAGING/"}"
  python3 - "$apk" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    if "classes.dex" not in z.namelist():
        raise SystemExit("Refusing non-deodexed OUYA APK (missing classes.dex): " + sys.argv[1])
PY
  if [[ "$MODE" == "system" ]]; then
    remote="/system/$relative"
    remote_dir="${remote%/*}"
    echo "Installing rebuilt OUYA system APK: $relative"
    "$ADB" shell "mkdir -p '$remote_dir'"
    "$ADB" push "$apk" "$remote"
    "$ADB" shell "chown root:root '$remote' && chmod 0644 '$remote'"
    # Remove a stale stock Dalvik ODEX; the guest consumes the embedded DEX.
    "$ADB" shell "rm -f '${remote%.apk}.odex'"
  else
    echo "Installing rebuilt OUYA APK: $relative"
    "$ADB" install -r "$apk"
  fi
done < <(find "$STAGING/app" "$STAGING/priv-app" -type f -name '*.apk' -print0 2>/dev/null)

if [[ "$found" -eq 0 ]]; then
  echo "No rebuilt OUYA APKs found under $STAGING/app or priv-app." >&2
  exit 2
fi

if [[ "$MODE" == "system" ]]; then
  "$ADB" shell "restorecon -RF /system/app /system/priv-app || true"
  "$ADB" reboot
  "$ADB" wait-for-device
  echo "Rebuilt APKs copied into the system partition."
else
  echo "APK install complete. Some packages may still require OUYA signature permissions/services."
fi
echo "Dashboard HOME component: tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity"
echo "Try: adb shell am start -n tv.ouya.console/tv.ouya.console.launcher.guide.GuideActivity"

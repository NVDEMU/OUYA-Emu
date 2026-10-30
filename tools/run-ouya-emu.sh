#!/usr/bin/env bash
set -euo pipefail

AVD_NAME="${OUYA_AVD_NAME:-OUYA-Emu}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -z "$ANDROID_SDK_ROOT" ]]; then
  echo "Set ANDROID_SDK_ROOT (or ANDROID_HOME) to your Android SDK directory." >&2
  exit 2
fi

EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
if [[ ! -x "$EMULATOR" ]]; then
  echo "Android Emulator not found at: $EMULATOR" >&2
  echo "Install the Android Emulator package from the Android SDK Manager." >&2
  exit 2
fi
if [[ ! -x "$ADB" ]]; then
  echo "ADB not found at: $ADB" >&2
  exit 2
fi

if ! "$EMULATOR" -list-avds | grep -Fxq "$AVD_NAME"; then
  echo "AVD '$AVD_NAME' does not exist." >&2
  echo "Create an AVD named '$AVD_NAME' with an ARM64 Android system image." >&2
  echo "The ARM64 guest is intentional: OUYA software contains ARM32 native code." >&2
  exit 2
fi

echo "Launching AVD: $AVD_NAME"
echo "Connect a gamepad before launch; Android Emulator forwards supported host gamepad input."
if [[ "${OUYA_WRITABLE_SYSTEM:-0}" == "1" ]]; then
  exec "$EMULATOR" -avd "$AVD_NAME" -gpu auto -writable-system -no-snapshot-load
fi
exec "$EMULATOR" -avd "$AVD_NAME" -gpu auto -no-snapshot-load

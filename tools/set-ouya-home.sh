#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${1:-}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
ADB="${ANDROID_SDK_ROOT:+$ANDROID_SDK_ROOT/platform-tools/adb}"

if [[ -z "$COMPONENT" || "$COMPONENT" != */* ]]; then
  echo "Usage: $0 package.name/.HomeActivity" >&2
  echo "Pass the actual HOME activity discovered from the imported OUYA firmware." >&2
  exit 2
fi
if [[ -z "$ADB" || ! -x "$ADB" ]]; then
  echo "Set ANDROID_SDK_ROOT and install Android platform-tools." >&2
  exit 2
fi

"$ADB" wait-for-device
if ! "$ADB" shell dumpsys package "${COMPONENT%%/*}" | grep -q "Activity"; then
  echo "Package may not be installed: ${COMPONENT%%/*}" >&2
  exit 1
fi

"$ADB" shell cmd package set-home-activity "$COMPONENT"
"$ADB" shell am start -a android.intent.action.MAIN -c android.intent.category.HOME

#!/usr/bin/env bash
# Install an OUYA/Android game APK (or an .apks split-APK bundle) into the guest.
set -euo pipefail

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
ADB="${SDK_ROOT:+$SDK_ROOT/platform-tools/adb}"
if [[ -z "$ADB" || ! -x "$ADB" ]]; then
  echo "Set ANDROID_SDK_ROOT and install Android platform-tools." >&2
  exit 2
fi
if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 game.apk [another.apk ...] | game.apks" >&2
  exit 2
fi
"$ADB" wait-for-device

for file in "$@"; do
  [[ -f "$file" ]] || { echo "File not found: $file" >&2; exit 2; }
  case "${file##*.}" in
    apk)
      echo "Installing $file"
      "$ADB" install -r "$file"
      ;;
    apks)
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      python3 - "$file" "$tmp" <<'PY'
import sys, zipfile
from pathlib import PurePosixPath
source, out = sys.argv[1:]
with zipfile.ZipFile(source) as z:
    entries = [i for i in z.infolist()
               if i.filename.endswith(".apk")
               and not PurePosixPath(i.filename).is_absolute()
               and ".." not in PurePosixPath(i.filename).parts]
    if not entries:
        raise SystemExit("No APK files found in .apks bundle")
    for i in entries:
        name = PurePosixPath(i.filename).name
        with z.open(i) as src, open(out + "/" + name, "wb") as dst:
            dst.write(src.read())
PY
      set -- "$tmp"/*.apk
      [[ -f "$1" ]] || { echo "No APK splits extracted." >&2; exit 2; }
      echo "Installing split bundle $file"
      "$ADB" install-multiple -r "$@"
      rm -rf "$tmp"
      trap - EXIT
      ;;
    *)
      echo "Unsupported file type: $file (expected .apk or .apks)" >&2
      exit 2
      ;;
  esac
done

echo "Installation finished. The guest may still need OUYA SDK/controller services,"
echo "ARM32 ABI support, or compatible graphics features for this title to run."
echo "Use the dashboard's Play area or Android app launcher to start the installed game."

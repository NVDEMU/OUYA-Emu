#!/usr/bin/env bash
# Rebuild stock Android 4.1 Dalvik ODEX pairs as APKs containing classes.dex.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${OUYA_STAGING:-$ROOT/vendor/ouya-emu/proprietary/ouya}"
FRAMEWORK="$STAGING/deodex/system/framework"
SOURCE="$STAGING/system/app"
OUT="$STAGING/deodexed/system/app"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
JAVA="${JAVA:-java}"
KEYTOOL="${KEYTOOL:-keytool}"
BAKSMALI="${BAKSMALI:-baksmali}"
SMALI="${SMALI:-smali}"
BAKSMALI_JAR="${BAKSMALI_JAR:-$ROOT/.tools/smali/baksmali-3.0.10-fat.jar}"
SMALI_JAR="${SMALI_JAR:-$ROOT/.tools/smali/smali-3.0.10-fat.jar}"
[[ -f "$BAKSMALI_JAR" ]] || BAKSMALI_JAR=""
[[ -f "$SMALI_JAR" ]] || SMALI_JAR=""

usage() {
  echo "Usage: $0 [--staging /path/to/ouya-firmware-staging]" >&2
  echo "Requires Java, baksmali/smali 3.0.10 (commands or fat JARs), and Android SDK apksigner." >&2
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--staging" ]]; then
  [[ -n "${2:-}" ]] || { usage; exit 2; }
  STAGING="$2"
  FRAMEWORK="$STAGING/deodex/system/framework"
  SOURCE="$STAGING/system/app"
  OUT="$STAGING/deodexed/system/app"
  shift 2
fi
if [[ "$#" -ne 0 ]]; then usage; exit 2; fi

[[ -d "$SOURCE" ]] || { echo "OUYA APK staging not found: $SOURCE" >&2; exit 2; }
[[ -d "$FRAMEWORK" ]] || {
  echo "Matching Android 4.1 framework files are missing: $FRAMEWORK" >&2
  echo "Re-import the full stock OTA with tools/import_ouya_firmware.py." >&2
  exit 2
}
command -v "$JAVA" >/dev/null 2>&1 || { echo "Java is required." >&2; exit 2; }
command -v "$KEYTOOL" >/dev/null 2>&1 || { echo "keytool is required (install a JDK)." >&2; exit 2; }

APKSIGNER="${APKSIGNER:-}"
if [[ -z "$APKSIGNER" && -n "$SDK_ROOT" ]]; then
  for candidate in "$SDK_ROOT"/build-tools/*/apksigner; do
    [[ -x "$candidate" ]] && APKSIGNER="$candidate"
  done
fi
if [[ -z "$APKSIGNER" ]]; then
  APKSIGNER="$(command -v apksigner || true)"
fi
[[ -n "$APKSIGNER" && -x "$APKSIGNER" ]] || {
  echo "Android SDK build-tools apksigner is required. Set ANDROID_SDK_ROOT." >&2
  exit 2
}
if [[ -z "$BAKSMALI_JAR" ]]; then
  command -v "$BAKSMALI" >/dev/null 2>&1 || {
    echo "Set BAKSMALI to a smali 3.0.10 executable or BAKSMALI_JAR to its 3.0.10 fat JAR." >&2
    exit 2
  }
fi
if [[ -z "$SMALI_JAR" ]]; then
  command -v "$SMALI" >/dev/null 2>&1 || {
    echo "Set SMALI to a smali 3.0.10 executable or SMALI_JAR to its 3.0.10 fat JAR." >&2
    exit 2
  }
fi

run_baksmali() {
  if [[ -n "$BAKSMALI_JAR" ]]; then
    "$JAVA" -jar "$BAKSMALI_JAR" deodex --api 16 --classpath-dir "$FRAMEWORK" --output "$2" "$1"
  else
    "$BAKSMALI" deodex --api 16 --classpath-dir "$FRAMEWORK" --output "$2" "$1"
  fi
}
run_smali() {
  if [[ -n "$SMALI_JAR" ]]; then
    "$JAVA" -jar "$SMALI_JAR" assemble --api 16 --output "$2" "$1"
  else
    "$SMALI" assemble --api 16 --output "$2" "$1"
  fi
}

mkdir -p "$OUT"
KEYSTORE="$STAGING/deodexed/ouyaemu-debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  "$KEYTOOL" -genkeypair -noprompt -keystore "$KEYSTORE" -storepass android \
    -keypass android -alias ouyaemu -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=OUYA-Emu Local Rebuild"
fi

found=0
while IFS= read -r -d '' odex; do
  apk="${odex%.odex}.apk"
  [[ -f "$apk" ]] || { echo "Skipping ODEX without matching APK: $odex" >&2; continue; }
  found=1
  name="${odex##*/}"
  base="${name%.odex}"
  work="$(mktemp -d "${TMPDIR:-/tmp}/ouya-deodex.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  echo "Deodexing $base against the OTA's own API-16 framework..."
  run_baksmali "$odex" "$work/smali"
  run_smali "$work/smali" "$work/classes.dex"
  [[ -s "$work/classes.dex" ]] || { echo "No classes.dex produced for $base" >&2; exit 1; }

  mkdir -p "$work/unsigned"
  python3 - "$apk" "$work/classes.dex" "$work/unsigned/$base.apk" <<'PY'
import sys, zipfile
src, dex, dst = sys.argv[1:]
with zipfile.ZipFile(src, "r") as original, zipfile.ZipFile(dst, "w") as rebuilt:
    for info in original.infolist():
        name = info.filename
        upper = name.upper()
        if name == "classes.dex" or (upper.startswith("META-INF/") and
                upper.endswith((".SF", ".RSA", ".DSA", ".EC", "MANIFEST.MF"))):
            continue
        rebuilt.writestr(info, original.read(name))
    rebuilt.write(dex, "classes.dex", compress_type=zipfile.ZIP_DEFLATED)
PY
  target="$OUT/$base.apk"
  "$APKSIGNER" sign --ks "$KEYSTORE" --ks-key-alias ouyaemu \
    --ks-pass pass:android --key-pass pass:android --min-sdk-version 16 \
    --out "$target" "$work/unsigned/$base.apk"
  "$APKSIGNER" verify "$target" >/dev/null
  echo "Built $target"
  rm -rf "$work"
  trap - EXIT
done < <(find "$SOURCE" -type f -name '*.odex' -print0)

if [[ "$found" -eq 0 ]]; then
  echo "No OUYA ODEX/APK pairs found in $SOURCE." >&2
  exit 2
fi

python3 - "$STAGING" "$OUT" <<'PY'
import hashlib, json, pathlib, sys
root, out = map(pathlib.Path, sys.argv[1:])
items = []
for apk in sorted(out.glob("*.apk")):
    items.append({"apk": str(apk.relative_to(root)), "size": apk.stat().st_size,
                  "sha256": hashlib.sha256(apk.read_bytes()).hexdigest()})
(root / "deodexed" / "deodex-report.json").write_text(
    json.dumps({"api_level": 16, "apps": items,
                "signing": "local debug key; not OUYA platform-signed"}, indent=2) + "\n",
    encoding="utf-8")
PY

echo "Deodexed $(find "$OUT" -type f -name '*.apk' | wc -l | tr -d ' ') OUYA APKs."
echo "These are locally re-signed test packages; privileged OUYA signature permissions may still be unavailable."
echo "Product makefile: $STAGING/ouya-imported.mk"

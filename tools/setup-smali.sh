#!/usr/bin/env bash
# Download pinned, checksum-verified smali/baksmali command-line fat JARs.
set -euo pipefail

VERSION="3.0.10"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${OUYA_TOOLS_DIR:-$ROOT/.tools/smali}"
CURL="${CURL:-curl}"
SHASUM="${SHASUM:-shasum}"

command -v "$CURL" >/dev/null 2>&1 || { echo "curl is required." >&2; exit 2; }
command -v "$SHASUM" >/dev/null 2>&1 || { echo "shasum is required." >&2; exit 2; }
mkdir -p "$DEST"

download_verified() {
  name="$1"
  expected="$2"
  url="https://github.com/baksmali/smali/releases/download/v$VERSION/$name-$VERSION-fat.jar"
  target="$DEST/$name-$VERSION-fat.jar"
  tmp="$target.download"
  echo "Downloading $name $VERSION..."
  "$CURL" --fail --location --retry 3 --retry-delay 1 --output "$tmp" "$url"
  actual="$("$SHASUM" -a 256 "$tmp" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$tmp"
    echo "SHA-256 mismatch for $name: expected $expected, got $actual" >&2
    exit 1
  fi
  mv "$tmp" "$target"
  echo "Verified $target"
}

download_verified "baksmali" "37ae4a41a8886e15c20b8362fa4250f96bbdb55e1a608199ad8b5dff068b588f"
download_verified "smali" "32fa0e88a6c397b3922201adf5f3e534fbaed5a663c71d0c558c3ddce0af844a"

echo
echo "Tools installed. Run:"
echo "  BAKSMALI_JAR=\"$DEST/baksmali-$VERSION-fat.jar\" \\"
echo "  SMALI_JAR=\"$DEST/smali-$VERSION-fat.jar\" \\"
echo "  ANDROID_SDK_ROOT=/path/to/Android/Sdk bash tools/deodex-ouya-apps.sh"

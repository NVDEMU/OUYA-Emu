#!/usr/bin/env python3
"""Import inspectable OUYA firmware components from a user-supplied OTA ZIP.

Proprietary firmware stays in the local staging directory. The tool extracts
OUYA/Cortex APK+ODEX pairs and boot ramdisk configuration for analysis; it
does not install a Tegra kernel or bootloader.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import struct
import zipfile
from pathlib import Path, PurePosixPath

TOKENS = ("ouya", "cortex")
APP_DIRS = ("system/app/", "system/priv-app/")
MAX_MEMBER = 512 * 1024 * 1024
MAX_TOTAL = 2 * 1024 * 1024 * 1024


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return not path.is_absolute() and ".." not in path.parts


def write_member(archive: zipfile.ZipFile, name: str, destination: Path) -> dict:
    info = archive.getinfo(name)
    if info.file_size > MAX_MEMBER:
        raise ValueError(f"Refusing oversized OTA member: {name}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with archive.open(info) as source, destination.open("wb") as target:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
            target.write(chunk)
    return {"ota_path": name, "staged_path": destination.as_posix(),
            "size": info.file_size, "sha256": digest.hexdigest()}


def extract_ramdisk_config(data: bytes, outdir: Path) -> list[str]:
    """Extract only regular init/fstab/property text files from newc CPIO."""
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    position, extracted = 0, []
    while position + 110 <= len(data):
        if data[position:position + 6] != b"070701":
            break
        fields = [int(data[position + 6 + i * 8:position + 14 + i * 8], 16)
                  for i in range(13)]
        mode, file_size, name_size = fields[1], fields[6], fields[11]
        position += 110
        raw_name = data[position:position + name_size]
        position = (position + name_size + 3) & ~3
        name = raw_name.rstrip(b"\0").decode("utf-8", "replace")
        if name == "TRAILER!!!":
            break
        payload = data[position:position + file_size]
        position = (position + file_size + 3) & ~3
        relative = PurePosixPath(name.lstrip("./"))
        if not safe_name(str(relative)) or not relative.parts:
            continue
        if not (name.endswith((".rc", ".prop", ".fstab", ".conf")) or
                name.startswith("fstab.") or name == "default.prop"):
            continue
        if (mode & 0o170000) != 0o100000:
            continue
        target = outdir.joinpath(*relative.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        extracted.append(target.as_posix())
    return extracted


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ota", type=Path, help="user-supplied stock OUYA OTA ZIP")
    parser.add_argument("--out", type=Path,
                        default=Path("vendor/ouya-emu/proprietary/ouya"))
    args = parser.parse_args()
    if not args.ota.is_file():
        parser.error(f"OTA file does not exist: {args.ota}")
    args.out.mkdir(parents=True, exist_ok=True)

    report = {
        "source_ota": args.ota.name,
        "warning": "Local user-supplied proprietary firmware. Never commit this directory.",
        "firmware_metadata": {}, "system_properties": {},
        "updater_script": "", "boot_image": None,
        "ramdisk_config_files": [], "staged_firmware_files": [], "notes": []
    }
    with zipfile.ZipFile(args.ota) as archive:
        infos = archive.infolist()
        expanded_size = sum(item.file_size for item in infos if not item.is_dir())
        if expanded_size > MAX_TOTAL:
            raise ValueError(f"OTA expands to {expanded_size} bytes; limit is {MAX_TOTAL}")
        names = {item.filename for item in infos if safe_name(item.filename)}

        for member in ("META-INF/com/android/metadata",
                       "META-INF/com/google/android/updater-script",
                       "system/build.prop"):
            if member not in names:
                continue
            raw = archive.read(member).decode("utf-8", "replace")
            if member.endswith("/metadata"):
                report["firmware_metadata"] = dict(
                    line.split("=", 1) for line in raw.splitlines() if "=" in line)
            elif member.endswith("updater-script"):
                report["updater_script"] = raw
            else:
                props = {}
                for line in raw.splitlines():
                    if "=" in line and not line.lstrip().startswith("#"):
                        key, value = line.split("=", 1)
                        if key.startswith(("ro.product.", "ro.build.", "ro.opengles.",
                                           "ro.hardware.", "ro.board.")):
                            props[key] = value
                report["system_properties"] = props

        for name in sorted(names):
            lower = name.lower()
            if (lower.startswith(APP_DIRS) and
                    any(token in lower for token in TOKENS) and
                    lower.endswith((".apk", ".odex"))):
                relative = PurePosixPath(name).relative_to("system")
                destination = args.out / "system" / Path(*relative.parts)
                report["staged_firmware_files"].append(
                    write_member(archive, name, destination))

        if "boot.img" in names:
            boot = archive.read("boot.img")
            boot_path = args.out / "boot.img"
            boot_path.write_bytes(boot)
            boot_info = {"size": len(boot),
                         "sha256": hashlib.sha256(boot).hexdigest(),
                         "path": boot_path.as_posix()}
            if boot[:8] == b"ANDROID!":
                page_size = struct.unpack_from("<I", boot, 36)[0]
                kernel_size = struct.unpack_from("<I", boot, 8)[0]
                ramdisk_size = struct.unpack_from("<I", boot, 16)[0]
                boot_info.update({"format": "legacy Android boot image",
                                  "page_size": page_size,
                                  "kernel_size": kernel_size,
                                  "ramdisk_size": ramdisk_size})
                if page_size and ramdisk_size:
                    ramdisk_start = ((page_size + kernel_size + page_size - 1)
                                     // page_size) * page_size
                    ramdisk = boot[ramdisk_start:ramdisk_start + ramdisk_size]
                    report["ramdisk_config_files"] = extract_ramdisk_config(
                        ramdisk, args.out / "boot-ramdisk-config")
            report["boot_image"] = boot_info
        else:
            report["notes"].append("No top-level boot.img found.")

    report["counts"] = {
        "firmware_apk_and_odex_files": len(report["staged_firmware_files"]),
        "ramdisk_config_files": len(report["ramdisk_config_files"])
    }
    (args.out / "firmware-report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")

    copied = report["staged_firmware_files"]
    if copied:
        lines = ["# Generated locally. Do not commit proprietary firmware.",
                 "OUYA_IMPORTED_FILES := \\"]
        for index, item in enumerate(copied):
            source = item["staged_path"]
            target = "system/" + source.split("/system/", 1)[1]
            continuation = " \\" if index < len(copied) - 1 else ""
            lines.append(f"    {source}:{target}{continuation}")
        lines += ["", "PRODUCT_COPY_FILES += $(OUYA_IMPORTED_FILES)"]
    else:
        lines = ["# No OUYA/Cortex APK or ODEX files found in this OTA."]
    (args.out / "ouya-imported.mk").write_text("\n".join(lines) + "\n",
                                                encoding="utf-8")
    print(f"Imported {len(copied)} OUYA/Cortex APK/ODEX files.")
    print(f"Extracted {len(report['ramdisk_config_files'])} ramdisk config files.")
    print(f"Report: {args.out / 'firmware-report.json'}")
    return 0 if copied else 2


if __name__ == "__main__":
    raise SystemExit(main())

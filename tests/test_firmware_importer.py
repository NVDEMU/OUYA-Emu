import json
import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "import_ouya_firmware.py"


def make_odex(dependency="core.odex"):
    dep = (b"\0\0\0\0" + struct.pack("<I", 1) + struct.pack("<I", 1) +
           struct.pack("<I", 28) + f"/system/framework/{dependency}\0".encode())
    header = bytearray(40)
    header[:8] = b"dey\n036\0"
    struct.pack_into("<II", header, 16, 40, len(dep))
    return bytes(header) + dep


class FirmwareImporterTests(unittest.TestCase):
    def test_imports_apps_and_matching_framework(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            ota = root / "sample-ota.zip"
            with zipfile.ZipFile(ota, "w") as archive:
                archive.writestr("META-INF/com/android/metadata", "pre-device=ouya_1_1\n")
                archive.writestr("system/build.prop", "ro.build.version.sdk=16\n")
                archive.writestr("system/framework/core.jar", b"framework jar")
                archive.writestr("system/framework/core.odex", make_odex())
                archive.writestr("system/app/OUYALauncher.apk", b"apk payload")
                archive.writestr("system/app/OUYALauncher.odex", make_odex())
                archive.writestr("system/app/OUYAWallpaper.apk", b"apk payload")
                archive.writestr("system/app/OUYAWallpaper.odex", make_odex())
            out = root / "out"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(ota), "--out", str(out)],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = json.loads((out / "firmware-report.json").read_text())
            self.assertEqual(report["firmware_metadata"]["pre-device"], "ouya_1_1")
            self.assertEqual(report["system_properties"]["ro.build.version.sdk"], "16")
            self.assertEqual(report["counts"]["framework_files"], 2)
            self.assertEqual(report["counts"]["firmware_apk_and_odex_files"], 4)
            launcher = next(x for x in report["staged_firmware_files"]
                            if x["ota_path"] == "system/app/OUYALauncher.odex")
            self.assertEqual(launcher["odex_dependencies"], ["core.odex"])
            self.assertEqual(launcher["missing_framework_dependencies"], [])
            self.assertTrue((out / "deodex/system/framework/core.odex").is_file())
            makefile = (out / "ouya-imported.mk").read_text()
            self.assertIn(
                "deodexed/system/app/OUYALauncher.apk:system/app/OUYALauncher.apk",
                makefile)
            self.assertNotIn(".odex:", makefile)

    def test_path_validation_and_odex_bounds(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("ouya_importer", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertFalse(module.safe_name("../escape"))
        self.assertFalse(module.safe_name("/absolute/path"))
        self.assertFalse(module.safe_name("folder\\escape"))
        self.assertTrue(module.safe_name("system/app/OUYALauncher.apk"))
        malformed = (b"dey\n036\0" + b"\0" * 8 +
                     struct.pack("<II", 999, 999) + b"\0" * 16)
        with self.assertRaises(ValueError):
            module.odex_dependencies(malformed)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Check the actual Android artifact, including its game classification/bridge."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--build-tools", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
apk = root / "build/TheLastLinea.apk"
version = json.loads((root/"version.json").read_text())

def command(tool, *extra):
    return subprocess.check_output([str(args.build_tools/tool), *extra], text=True, stderr=subprocess.STDOUT)

signature = command("apksigner", "verify", "--verbose", "--print-certs", str(apk))
badging = command("aapt", "dump", "badging", str(apk))
manifest = command("aapt", "dump", "xmltree", str(apk), "AndroidManifest.xml")
assert "name='online.b5solucoes.thelastlinea.preview'" in badging, "Unexpected package identity"
assert f"versionCode='{version['version_code']}'" in badging, "Build number mismatch"
assert "sdkVersion:'24'" in badging, "Unexpected Android minimum version"
assert "targetSdkVersion:'36'" in badging, "Unexpected target SDK"
assert re.search(r"android:isGame.*0xffffffff", manifest), "Android must recognize this as a game"
assert re.search(r"android:appCategory.*0x0\b", manifest), "Android game category required"
assert re.search(r"android:screenOrientation.*0x0\b", manifest), "Landscape orientation required"
assert "org.godotengine.plugin.v2.LineaUpdater" in manifest, "Native updater is missing"
assert "online.b5solucoes.linea.updater.LineaUpdateProvider" in manifest, "Private update provider is missing"
assert "android.permission.REQUEST_INSTALL_PACKAGES" in manifest, "Installation permission is missing"
assert "android.permission.INTERNET" in manifest, "Update network permission is missing"
assert "Verified using v2 scheme (APK Signature Scheme v2): true" in signature, "APK v2 signature required"
with zipfile.ZipFile(apk) as archive:
    libraries = [name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")]
    assert any("libgodot_android.so" in name for name in libraries), "Godot native library is missing"
    assert all("/arm64-v8a/" in name for name in libraries), "APK should contain only ARM64 libraries"
    assert any(b"LINEA_EGL_RECOVERED" in archive.read(name) for name in archive.namelist()
               if re.fullmatch(r"classes\d*\.dex",name)), "Android EGL surface recovery patch is missing"
report = (f"Android artifact verified: {version['version']}\n"
          f"Bytes: {apk.stat().st_size}\nSHA-256: {hashlib.sha256(apk.read_bytes()).hexdigest()}\n\n"
          + signature + "\n" + badging + "\n" + manifest)
(root/"build/APK-verification.txt").write_text(report)
print("PASS: APK signature, build number, Android game classification, landscape, ARM64 and native update bridge.")

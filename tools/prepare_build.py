#!/usr/bin/env python3
"""Prepare Godot settings/presets without persisting private credentials in git."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--code", type=int, required=True)
parser.add_argument("--sdk", default=os.environ.get("ANDROID_HOME", ""))
parser.add_argument("--java", default=os.environ.get("JAVA_HOME", "/usr/lib/jvm/java-21-openjdk-amd64"))
args = parser.parse_args()
assert 0 < args.code < 2100000000
templates = Path.home() / ".local/share/godot/export_templates/4.6.3.stable"
if not (root / "android/build/build.gradle").exists():
    with zipfile.ZipFile(templates / "android_source.zip") as source:
        source.extractall(root / "android/build")
(root / "android/.build_version").write_text("4.6.3.stable")
(root / "android/build/.gdignore").touch()
(root / "android/build/gradlew").chmod(0o755)

config_dir = Path(os.environ.get("XDG_CONFIG_HOME", Path.home()/".config"))/"godot"
config_dir.mkdir(parents=True, exist_ok=True)
editor_settings = config_dir / "editor_settings-4.6.tres"
editor_settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    f'export/android/android_sdk_path={json.dumps(str(Path(args.sdk).resolve()))}\n'
    f'export/android/java_sdk_path={json.dumps(str(Path(args.java).resolve()))}\n')

build = root / "build"
build.mkdir(exist_ok=True)
(build / ".gdignore").touch()
# Public Android DEBUG identity for this preview package only; never a production key.
key = build / "preview.keystore"
key.write_bytes(base64.b64decode((root/"tools/preview-signing.base64").read_text()))
key.chmod(0o600)
version = f"0.1.0-preview.{args.code}"
presets = (root/"export_presets.cfg").read_text()
presets = re.sub(r"version/code=\d+",f"version/code={args.code}",presets)
presets = re.sub(r'version/name="[^"]+"',f'version/name="{version}"',presets)
signing = (f'keystore/release={json.dumps(str(key))}\n'
           'keystore/release_user="androiddebugkey"\nkeystore/release_password="android"\n')
presets = presets.replace('[preset.0.options]', '[preset.0.options]\n'+signing)
(root/"export_presets.cfg").write_text(presets)
(root/"version.json").write_text(json.dumps({"version":version,"version_code":args.code,"chapter":1}))
project = (root/"project.godot").read_text()
project = re.sub(r'config/version="[^"]+"',f'config/version="{version}"',project)
(root/"project.godot").write_text(project)
print(f"Prepared Android preview {version} (arm64, API 24+).")

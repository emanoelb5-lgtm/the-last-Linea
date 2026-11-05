"""Exercise version propagation on an isolated build scaffold, without an SDK."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]

class BuildVersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="linea-version-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ["tools/prepare_build.py","tools/preview-signing.base64","project.godot","export_presets.cfg"]:
            target = self.root/name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy(SOURCE/name,target)
        android = self.root/"android/build"
        android.mkdir(parents=True)
        (android/"build.gradle").touch()
        (android/"gradlew").touch()
        (self.root/"version.json").write_text(json.dumps({"version":"0.2.0","chapter":1}))
        self.env = dict(os.environ,XDG_CONFIG_HOME=str(self.root/"config"),GITHUB_ENV=str(self.root/"environment"))

    def prepare(self,code):
        return subprocess.run([sys.executable,str(self.root/"tools/prepare_build.py"),"--code",str(code),"--sdk",str(self.root/"sdk"),"--java",str(self.root/"java")],env=self.env,text=True,capture_output=True)

    def test_version_and_environment_follow_source(self):
        self.assertEqual(self.prepare(1005).returncode,0)
        metadata=json.loads((self.root/"version.json").read_text())
        self.assertEqual(metadata["version"],"0.2.0-preview.1005")
        self.assertEqual(metadata["version_code"],1005)
        self.assertIn("GAME_VERSION=0.2.0\n",(self.root/"environment").read_text())
        self.assertIn('version/name="0.2.0-preview.1005"',(self.root/"export_presets.cfg").read_text())

    def test_rebuilding_keeps_base_version_and_one_signing_block(self):
        self.assertEqual(self.prepare(1005).returncode,0)
        self.assertEqual(self.prepare(1006).returncode,0)
        metadata=json.loads((self.root/"version.json").read_text())
        self.assertEqual(metadata["version"],"0.2.0-preview.1006")
        self.assertEqual((self.root/"export_presets.cfg").read_text().count("keystore/release="),1)

    def test_invalid_metadata_cannot_inject_release_environment(self):
        (self.root/"version.json").write_text(json.dumps({"version":"0.2.0\nOTHER=value","chapter":1}))
        self.assertNotEqual(self.prepare(1005).returncode,0)
        self.assertFalse((self.root/"environment").exists())

if __name__ == "__main__":
    unittest.main()

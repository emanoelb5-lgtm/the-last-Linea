#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
root = Path(__file__).resolve().parents[1]
apk = root / "build/TheLastLinea.apk"
version = json.loads((root/"version.json").read_text())
tag = os.environ["RELEASE_TAG"]
repository = os.environ["GITHUB_REPOSITORY"]
manifest = dict(version,
    apk_url=f"https://github.com/{repository}/releases/download/{tag}/TheLastLinea.apk",
    size=apk.stat().st_size, sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),
    package="online.b5solucoes.thelastlinea.preview", channel="preview")
(root/"build/update.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
(root/"build/SHA256SUMS.txt").write_text(f"{manifest['sha256']}  TheLastLinea.apk\n")
notes = (root/"docs/RELEASE_NOTES.md").read_text()
(root/"build/RELEASE_NOTES.md").write_text(notes+f"\n\nVersão Android: **{version['version']}** · build **{version['version_code']}**.\n")
print("Created public update manifest and SHA-256 checksum.")

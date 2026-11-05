#!/usr/bin/env python3
"""Godot can exit with code 0 after a script error: also check its output."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
editor = os.environ.get("GODOT", "godot")
with tempfile.TemporaryDirectory(prefix="linea-tests-") as isolated:
    env = dict(os.environ, XDG_DATA_HOME=isolated, XDG_CONFIG_HOME=isolated)
    for extra in [["--editor", "--import", "--quit"], ["tests/runner.tscn"]]:
        result = subprocess.run([editor, "--headless", "--path", str(root), *extra],
                                env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=100)
        print(result.stdout)
        if result.returncode or re.search(r"(?:SCRIPT ERROR:|^ERROR:|CHECK FAILED:)", result.stdout, re.M):
            sys.exit(result.returncode or 1)
    print("Godot import and gameplay/update integration checks passed.")

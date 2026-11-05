#!/usr/bin/env python3
"""Compile the pinned Godot 4.6.3 Android surface recovery fix into the release AAR.

Only GLSurfaceView and its nested classes change. Native engine libraries,
rendering resources, package identity and application signing stay the same.
The source retains its Android/AOSP Apache-2.0 notice.
"""
import argparse
import io
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--sdk',type=Path,required=True)
args = parser.parse_args()
aar = ROOT/'android/build/libs/release/godot-lib.template_release.aar'
source = ROOT/'native-compat/GLSurfaceView.java'
with tempfile.TemporaryDirectory(prefix='linea-gl-') as directory:
    temp = Path(directory)
    compiled = temp/'classes'
    compiled.mkdir()
    original_jar = temp/'original.jar'
    with zipfile.ZipFile(aar) as original_aar:
        original_jar.write_bytes(original_aar.read('classes.jar'))
    subprocess.run(['javac','-source','17','-target','17','-classpath',
                    os.pathsep.join([str(args.sdk/'platforms/android-36/android.jar'),str(original_jar)]),
                    '-d',str(compiled),str(source)],check=True)
    replacements = {str(p.relative_to(compiled)):p.read_bytes() for p in compiled.rglob('*.class')}
    assert 'org/godotengine/godot/gl/GLSurfaceView$GLThread.class' in replacements
    with zipfile.ZipFile(aar) as old:
        classes = io.BytesIO()
        with zipfile.ZipFile(io.BytesIO(old.read('classes.jar'))) as original, zipfile.ZipFile(classes,'w',zipfile.ZIP_DEFLATED) as updated:
            for item in original.infolist():
                updated.writestr(item,replacements.pop(item.filename,original.read(item)))
            for path,data in replacements.items():
                updated.writestr(path,data)
        output = temp/'patched.aar'
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as updated:
            for item in old.infolist():
                updated.writestr(item,classes.getvalue() if item.filename=='classes.jar' else old.read(item))
    aar.write_bytes(output.read_bytes())
print('PASS: patched Android EGL_BAD_SURFACE recovery; native engine binaries unchanged')

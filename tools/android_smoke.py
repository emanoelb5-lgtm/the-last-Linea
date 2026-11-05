#!/usr/bin/env python3
"""Install and launch the APK; retain logcat and screenshots even after a crash."""
import argparse
from pathlib import Path
import re
import subprocess
import time

parser=argparse.ArgumentParser()
parser.add_argument('--apk',type=Path,required=True)
parser.add_argument('--output',type=Path,default=Path('build/android-startup'))
parser.add_argument('--seconds',type=int,default=35)
parser.add_argument('--require-ready',action='store_true')
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
package='online.b5solucoes.thelastlinea.preview'

def adb(*arguments,check=True):
    return subprocess.run(['adb',*arguments],capture_output=True,text=True,timeout=90,check=check).stdout

def screenshot(name):
    result=subprocess.run(['adb','exec-out','screencap','-p'],capture_output=True,timeout=30)
    if result.returncode==0:
        (args.output/name).write_bytes(result.stdout)

failure=None
try:
    device=adb('shell','getprop')
    (args.output/'device.txt').write_text(device)
    print('ABILIST:',adb('shell','getprop','ro.product.cpu.abilist').strip(),flush=True)
    print(adb('install','--no-streaming','-r',str(args.apk)),flush=True)
    adb('shell','am','force-stop',package,check=False)
    adb('logcat','-c')
    launch=adb('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',package)
    (args.output/'launch.txt').write_text(launch)
    print(launch,flush=True)
    start=time.monotonic()
    while time.monotonic()-start < args.seconds:
        elapsed=time.monotonic()-start
        if elapsed>3 and not adb('shell','pidof',package,check=False).strip():
            raise RuntimeError('Application process exited during startup')
        time.sleep(1)
    screenshot('startup.png')
except Exception as error:
    failure=error
finally:
    screenshot('last-screen.png')
    logs=adb('logcat','-d','-v','threadtime',check=False)
    (args.output/'logcat.txt').write_text(logs)
    relevant='\n'.join(line for line in logs.splitlines() if re.search(r'godot|AndroidRuntime|FATAL|Fatal signal|linea|LINEA_',line,re.I))
    (args.output/'relevant.txt').write_text(relevant)
    print(relevant[-18000:],flush=True)
    if re.search(r'SCRIPT ERROR:|FATAL EXCEPTION|Fatal signal|Unable to start activity|Unable to instantiate application',relevant):
        failure=failure or RuntimeError('Android reported a runtime crash or script error')
    if args.require_ready and 'LINEA_BOOT_READY' not in relevant:
        failure=failure or RuntimeError('The first rendered game frame was not observed')
if failure:
    raise SystemExit(str(failure))
print('PASS: Android process stayed alive through startup')

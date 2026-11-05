#!/usr/bin/env python3
"""Exercise the actual exported APK, retaining evidence even after a crash."""
import argparse
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from PIL import Image, ImageStat

parser = argparse.ArgumentParser()
parser.add_argument('--apk', type=Path, required=True)
parser.add_argument('--output', type=Path, default=Path('build/android-startup'))
parser.add_argument('--seconds', type=int, default=35)
parser.add_argument('--require-ready', action='store_true')
parser.add_argument('--exercise', action='store_true')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
package = 'online.b5solucoes.thelastlinea.preview'
CRASH = r'SCRIPT ERROR:|FATAL EXCEPTION|Fatal signal|Unable to start activity|Unable to instantiate application|Program linking failed|!_start_success|godot\s*:\s*ERROR:'


def adb(*arguments, check=True):
    return subprocess.run(['adb', *arguments], capture_output=True, text=True,
                          timeout=120, check=check).stdout


def screenshot(name):
    result = subprocess.run(['adb', 'exec-out', 'screencap', '-p'], capture_output=True, timeout=30)
    if result.returncode == 0:
        (args.output/name).write_bytes(result.stdout)


def wait_for_picture(name, seconds=45):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        alive()
        screenshot(name)
        picture = Image.open(args.output/name).convert('RGB')
        # A live PID can still be stuck on a black EGL surface after resume.
        if max(ImageStat.Stat(picture).stddev) > 5 and max(pair[1] for pair in picture.getextrema()) > 40:
            return
        time.sleep(2)
    raise RuntimeError(f'Android surface stayed blank: {name}')


def dismiss_system_tutorial():
    # Android's first-use immersive tutorial can cover the game's whole surface.
    # Inspect native UI nodes; never send a speculative tap into the game.
    adb('shell', 'uiautomator', 'dump', '/sdcard/linea-window.xml', check=False)
    source = adb('shell', 'cat', '/sdcard/linea-window.xml', check=False)
    (args.output/'native-window.xml').write_text(source)
    try:
        root = ET.fromstring(source)
    except ET.ParseError:
        return
    for node in root.iter('node'):
        if node.get('text') not in ('Got it', 'OK') or node.get('package') not in ('android','com.android.systemui'):
            continue
        bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
        if bounds:
            x1,y1,x2,y2 = map(int,bounds.groups())
            adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
            time.sleep(2)
            print('Dismissed Android immersive-mode tutorial', flush=True)
            return


def app_logs():
    return adb('logcat', '-d', '-v', 'threadtime', '-s', 'godot:I', 'Godot:D',
               'libc:F', 'AndroidRuntime:E', 'DEBUG:F', '*:S', check=False)


def alive():
    if not adb('shell', 'pidof', package, check=False).strip():
        raise RuntimeError('Application process exited')
    logs = app_logs()
    if re.search(CRASH, logs):
        raise RuntimeError('Android reported a runtime crash, shader or script error')
    return logs


def wait_for(marker, seconds=120):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        logs = alive()
        if marker in logs:
            return logs
        time.sleep(2)
    raise RuntimeError(f'Timed out waiting for {marker}')


def observe(seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        alive()
        time.sleep(2)


failure = None
try:
    (args.output/'device.txt').write_text(adb('shell', 'getprop'))
    print('ABILIST:', adb('shell', 'getprop', 'ro.product.cpu.abilist').strip(), flush=True)
    # A reproducible 16:9 landscape surface; no dependency on a runner's skin.
    adb('shell', 'wm', 'size', '720x1280')
    adb('shell', 'settings', 'put', 'secure', 'immersive_mode_confirmations', 'confirmed')
    print(adb('install', '--no-streaming', '-r', str(args.apk)), flush=True)
    # A fresh Google APIs image applies Pixel/navigation resource overlays after
    # boot_completed and package installation. Let that finish before launching:
    # changing Activity assets mid-initialization tears down the native engine.
    print('Waiting for first-boot resource overlays to settle before launch', flush=True)
    time.sleep(30)
    adb('shell', 'am', 'force-stop', package, check=False)
    adb('logcat', '-c')
    launch_args = ('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
                   '-c', 'android.intent.category.LAUNCHER', '-p', package)
    launch = adb(*launch_args)
    (args.output/'launch.txt').write_text(launch)
    print(launch, flush=True)
    if args.require_ready:
        wait_for('LINEA_BOOT_READY')
    dismiss_system_tutorial()
    wait_for_picture('01-menu.png')
    if args.exercise:
        logs = wait_for('LINEA_BUTTON NEW_GAME')
        points = re.findall(r'LINEA_BUTTON NEW_GAME (\d+) (\d+)', logs)
        point = points[-1] if points else None
        if not point:
            raise RuntimeError('The new-game button was not laid out')
        adb('shell', 'input', 'tap', point[0], point[1])
        wait_for('LINEA_INTRO_READY')
        observe(4)
        screenshot('02-intro.png')
        wait_for('LINEA_PLAY_READY', 120)
        observe(3)
        wait_for_picture('03-play.png')
        # Exercise native touch delivery, movement and two sound effects.
        adb('shell', 'input', 'swipe', '128', '596', '128', '530', '1600')
        observe(3)
        screenshot('04-walk.png')
        pid_before = adb('shell', 'pidof', package).strip()
        adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        time.sleep(3)
        adb(*launch_args)
        observe(5)
        if adb('shell', 'pidof', package).strip() != pid_before:
            raise RuntimeError('Returning from background restarted the app')
        wait_for_picture('05-resume.png')
        logs = wait_for('LINEA_BUTTON RESUME_GAME')
        points = re.findall(r'LINEA_BUTTON RESUME_GAME (\d+) (\d+)', logs)
        point = points[-1] if points else None
        if not point:
            raise RuntimeError('The resume button was not laid out')
        adb('shell', 'input', 'tap', point[0], point[1])
        wait_for('LINEA_PLAY_RESUMED')
        observe(3)
        wait_for_picture('06-resumed-play.png')
    observe(args.seconds)
    screenshot('last-screen.png')
except Exception as error:
    failure = error
finally:
    screenshot('last-screen.png')
    logs = adb('logcat', '-d', '-v', 'threadtime', check=False)
    (args.output/'logcat.txt').write_text(logs)
    relevant = app_logs()
    (args.output/'relevant.txt').write_text(relevant)
    print(relevant[-20000:], flush=True)
    if re.search(CRASH, relevant):
        failure = failure or RuntimeError('Android reported a runtime failure')
    if args.require_ready and 'LINEA_BOOT_READY' not in relevant:
        failure = failure or RuntimeError('The first rendered game frame was not observed')
if failure:
    raise SystemExit(str(failure))
print('PASS: Android startup' + (', cutscene, gameplay, touch and background/resume' if args.exercise else ''))

#!/usr/bin/env python3
"""Render original ambience/foley once, instead of running a PCM loop on Android.

Requires ffmpeg with libvorbis. Assets are committed; players and CI do not need it.
"""
from array import array
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000


def render(kind, duration, loop=False):
    rng = random.Random(48217)
    count = round(RATE * duration)
    samples = array('h')
    smooth = 0.0
    for i in range(count):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        smooth += (noise - smooth) * .012
        envelope = (1 - i / count) ** 2
        if kind == 'wind':
            sample = smooth * (.6 + .3 * math.sin(math.tau * t / duration))
        elif kind == 'drone':
            sample = sum(math.sin(math.tau * f * t) * a for f, a in [(55,.23),(82.5,.16),(110,.08)])
        elif kind == 'step':
            sample = (noise*.3 + math.sin(math.tau*100*t)*.6)*envelope*.4
        elif kind == 'scratch':
            sample = noise*envelope*(.4+.3*math.sin(t*190))
        elif kind == 'trap':
            sample = (math.sin(math.tau*180*t)+math.sin(math.tau*311*t)*.4+noise*.4)*envelope*.5
        elif kind == 'door':
            sample = (math.sin(math.tau*(80+t*70)*t)*.4+smooth)*math.sin(math.pi*t/duration)
        elif kind == 'echo':
            sample = (math.sin(math.tau*440*t)+math.sin(math.tau*660*t)*.4)*envelope*.35
        else:
            sample = math.sin(math.tau*330*t)*envelope*.2
        sample *= min(1, min(t, duration-t)*8) if loop else min(1, t*400)
        samples.append(round(max(-1,min(1,sample))*24000))
    if sys.byteorder != 'little':
        samples.byteswap()
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory)/'source.wav'
        with wave.open(str(source),'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(samples.tobytes())
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),
                        '-c:a','libvorbis','-q:a','3',str(ROOT/'audio'/f'{kind}.ogg')],check=True)


if __name__ == '__main__':
    (ROOT/'audio').mkdir(exist_ok=True)
    for name, duration in [('wind',5),('drone',8),('step',.14),('scratch',.55),
                           ('trap',.55),('door',1.6),('echo',1.6),('ui',.14)]:
        render(name,duration,name in ('wind','drone'))
        print(name, (ROOT/'audio'/f'{name}.ogg').stat().st_size)

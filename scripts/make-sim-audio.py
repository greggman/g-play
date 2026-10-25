"""Generates the audio file the Simulator playback engine plays for every track.

python3 scripts/make-sim-audio.py && afconvert ... (see below)
A quiet chord with a gentle pulse, long enough for any fixture track.
"""
import math, struct, sys, wave

rate = 16000
seconds = 7 * 60
out = sys.argv[1] if len(sys.argv) > 1 else "sim-tone.wav"
freqs = [220.0, 277.18, 329.63]
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    frames = bytearray()
    for i in range(rate * seconds):
        t = i / rate
        pulse = 0.55 + 0.45 * math.cos(2 * math.pi * 0.5 * t)
        v = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        frames += struct.pack("<h", int(v * pulse * 0.12 * 32767))
    w.writeframes(bytes(frames))

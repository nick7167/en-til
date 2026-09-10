"""Original short synthesized cues; no samples or external copyrighted audio."""
import math, struct, wave
from pathlib import Path
out = Path('ios/EnTil/Resources')
for name, frequencies, duration in [('lock', [520, 780], .12), ('reveal', [523.25, 659.25, 783.99], .36), ('ready', [660, 880], .16)]:
    rate = 44100
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        samples = []
        for i in range(int(rate * duration)):
            t = i / rate
            envelope = min(1, t / .006) * (1 - t / duration) ** 3
            value = sum(math.sin(2 * math.pi * hz * t) for hz in frequencies) / len(frequencies)
            samples.append(struct.pack('<h', int(value * envelope * 13000)))
        f.writeframes(b''.join(samples))

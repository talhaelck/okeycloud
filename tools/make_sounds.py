"""Synthesises the kahvehane's sounds into assets/audio/ (16-bit mono WAV, 44.1 kHz). No recordings needed, so no
licences: rain on the windows, the stove crackling, the wall clock, tea spoons on glass, tavla dice and checkers,
the match crowd on the TV, the murmur of talk, and the street door (creak, bell, a gust of rain); and the game's
own sounds: tiles (click, seat in the rack, fall on the felt, slide, shuffle), menu ticks, the stings for opening,
getting caught and winning, and chalk on the score board.
Loops (*_loop.wav) fade their ends into each other so they repeat seamlessly.

    python tools/make_sounds.py
"""
import pathlib
import wave

import numpy as np

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def fast_lowpass(x, cutoff):
    # Frequency-domain brick wall with a soft edge; fine for noise beds.
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(x))


def bandpass(x, low, high):
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (low / np.maximum(f, 1)) ** 4) / (1 + (f / high) ** 4)
    return np.fft.irfft(spectrum, len(x))


def env(seconds, attack, decay):
    x = t(seconds)
    return np.minimum(1, x / max(attack, 1e-4)) * np.exp(-x / decay)


def place(bed, sound, at):
    i = int(at * RATE)
    n = min(len(sound), len(bed) - i)
    if n > 0:
        bed[i:i + n] += sound[:n]


def loopable(x, fade=1.0):
    n = int(fade * RATE)
    head, tail = x[:n], x[-n:]
    ramp = np.linspace(0, 1, n)
    out = x[:-n].copy()
    out[:n] = tail * (1 - ramp) + head * ramp
    return out


def save(name, x, peak=0.8):
    OUT.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, "%.1fs" % (len(x) / RATE))


def clink(freq=3200.0, length=0.9):
    """A spoon tapping a thin tea glass: a few inharmonic, quickly decaying partials."""
    x = t(length)
    out = np.zeros_like(x)
    for ratio, gain, decay in [(1.0, 1.0, 0.35), (2.32, 0.5, 0.18), (4.25, 0.25, 0.08), (6.1, 0.12, 0.05)]:
        out += gain * np.sin(2 * np.pi * freq * ratio * x + rng.uniform(0, 6)) * np.exp(-x / decay)
    out[:60] *= np.linspace(0, 1, 60)
    return out


def knock(freq, length=0.12, bright=3000.0):
    """A short hard knock (wood, bone, bakelite): a damped resonance plus a noisy click."""
    x = t(length)
    tone = np.sin(2 * np.pi * freq * x) * np.exp(-x / (length * 0.25))
    click = bandpass(noise(length), 800, bright) * np.exp(-x / 0.008)
    return tone * 0.6 + click


def rain_loop(seconds=24):
    bed = fast_lowpass(noise(seconds), 2200) * 0.5 + bandpass(noise(seconds), 2000, 7000) * 0.25
    for _ in range(int(seconds * 60)):
        drop = bandpass(noise(0.03), 1500, 9000) * env(0.03, 0.001, 0.006) * rng.uniform(0.3, 1.2)
        place(bed, drop, rng.uniform(0, seconds - 0.05))
    # Water running off the gutter now and then.
    swell = 1 + 0.25 * np.sin(2 * np.pi * t(seconds) / 6.0)
    return loopable(bed * swell)


def stove_loop(seconds=20):
    bed = fast_lowpass(noise(seconds), 180) * 1.5  # the fire's low roar
    for _ in range(int(seconds * 7)):
        pop = bandpass(noise(0.05), 600, 6000) * env(0.05, 0.0005, 0.01) * rng.uniform(0.5, 2.5)
        place(bed, pop, rng.uniform(0, seconds - 0.1))
    for _ in range(int(seconds * 1.2)):
        crack = knock(rng.uniform(300, 900), 0.08, 8000) * rng.uniform(1.0, 3.0)
        place(bed, crack, rng.uniform(0, seconds - 0.1))
    return loopable(bed)


def clock_loop():
    bed = np.zeros(int(2.0 * RATE))
    place(bed, knock(2400, 0.05, 9000), 0.0)
    place(bed, knock(2000, 0.05, 8000) * 0.8, 1.0)
    return bed


def dice():
    bed = np.zeros(int(1.2 * RATE))
    at = 0.0
    for i in range(7):
        at += rng.uniform(0.04, 0.12) * (1 + i * 0.15)
        place(bed, knock(rng.uniform(1400, 2600), 0.06, 7000) * (1.0 - i * 0.11), at)
    return bed


def checker():
    return knock(rng.uniform(500, 700), 0.15, 4000)


def crowd_loop(seconds=30):
    """A stadium through a small TV speaker: a band-limited roar that swells, with a cheer now and then."""
    roar = bandpass(noise(seconds), 300, 2500)
    x = t(seconds)
    swell = 0.6 + 0.25 * np.sin(2 * np.pi * x / 7.3) + 0.15 * np.sin(2 * np.pi * x / 2.9 + 1)
    for at in (9.0, 21.0):
        swell += 0.9 * np.exp(-((x - at) / 1.2) ** 2)
    # Small speaker: no lows, a little boxy resonance.
    return loopable(bandpass(roar * swell, 400, 3500))


def murmur_loop(seconds=30, voices=9):
    """Men talking at the other tables: formant-filtered noise chopped into syllables, a laugh now and then."""
    x = t(seconds)
    bed = np.zeros_like(x)
    for v in range(voices):
        pitch = rng.uniform(95, 140)
        source = np.sign(np.sin(2 * np.pi * pitch * x * (1 + 0.03 * np.sin(2 * np.pi * x * rng.uniform(0.2, 0.5))))) * 0.3 + noise(seconds) * 0.2
        voice = bandpass(source, rng.uniform(250, 400), rng.uniform(1800, 2600))
        syllables = np.clip(np.sin(2 * np.pi * x * rng.uniform(3.0, 5.0) + rng.uniform(0, 6)), 0, 1) ** 2
        phrases = np.clip(np.sin(2 * np.pi * x / rng.uniform(4, 9) + rng.uniform(0, 6)) + 0.3, 0, 1)
        bed += voice * syllables * phrases * rng.uniform(0.4, 1.0)
    for at in rng.uniform(2, seconds - 2, 3):
        laugh = np.zeros(int(1.2 * RATE))
        for k in range(5):
            place(laugh, bandpass(noise(0.12), 300, 2000) * env(0.12, 0.01, 0.05), k * 0.17)
        place(bed, laugh * 1.5, at)
    # Far away across the room: muffle it.
    return loopable(fast_lowpass(bed, 1500))


def door_open():
    seconds = 2.6
    x = t(seconds)
    # Hinge creak: a scraping tone sliding up and down.
    freq = 380 + 140 * np.sin(2 * np.pi * x * 0.6)
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(freq) / RATE)) * (np.sin(2 * np.pi * x * 31) > 0.2)
    creak = bandpass(creak, 400, 3000) * np.exp(-((x - 0.6) / 0.45) ** 2) * 0.5
    # The bell over the door.
    bell = np.zeros_like(x)
    for strike in (0.15, 0.32):
        b = np.zeros(int((seconds - strike) * RATE))
        tb = t(seconds - strike)
        for ratio, gain in [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1)]:
            b += gain * np.sin(2 * np.pi * 1760 * ratio * tb) * np.exp(-tb / 0.6)
        place(bell, b * 0.35, strike)
    # A gust of street and rain while it is open.
    gust = fast_lowpass(noise(seconds), 3000) * np.exp(-((x - 1.2) / 0.7) ** 2) * 0.6
    return creak + bell + gust


def door_close():
    bed = knock(140, 0.4, 1500) * 2
    place(bed, knock(90, 0.3, 800), 0.0)
    return bed


# --- The game's own sounds -----------------------------------------------------------------------------------

def tile_click(freq):
    """Bakelite tapping bakelite: a bright tick over a short wooden body (a tile picked up or plucked)."""
    bed = np.zeros(int(0.09 * RATE))
    place(bed, knock(freq, 0.07, 8000) * 0.9, 0.0)
    place(bed, knock(freq * 0.45, 0.05, 2500) * 0.3, 0.0)
    return bed


def tile_rack(freq):
    """A tile slid into its slot on the wooden rack: a little scrape, then a round tok."""
    bed = np.zeros(int(0.22 * RATE))
    place(bed, bandpass(noise(0.05), 1500, 5000) * env(0.05, 0.004, 0.02) * 0.3, 0.0)
    place(bed, knock(freq, 0.1, 3500), 0.045)
    return bed


def tile_felt(freq):
    """A tile dropped on the felt: a dull thud and a tiny second bounce."""
    bed = np.zeros(int(0.3 * RATE))
    place(bed, fast_lowpass(knock(freq, 0.12, 1800), 2500) * 1.2, 0.0)
    place(bed, fast_lowpass(knock(freq * 1.2, 0.06, 1800), 2500) * 0.3, 0.085)
    return bed


def tile_slide():
    """A tile pushed across the felt."""
    x = bandpass(noise(0.4), 900, 4500) * env(0.4, 0.08, 0.14)
    return x * (0.7 + 0.3 * np.sin(2 * np.pi * 18 * t(0.4)))


def shuffle():
    """The deal: tiles clattering together."""
    bed = np.zeros(int(1.6 * RATE))
    for _ in range(46):
        at = rng.uniform(0.0, 1.35) ** 1.15
        place(bed, knock(rng.uniform(900, 2400), 0.05, 7000) * rng.uniform(0.2, 0.9), at)
    place(bed, bandpass(noise(1.5), 1200, 6000) * env(1.5, 0.1, 0.7) * 0.12, 0.0)
    return bed


def ui_hover():
    return knock(1500, 0.035, 4000) * 0.5


def ui_click():
    bed = np.zeros(int(0.09 * RATE))
    place(bed, knock(780, 0.08, 4500), 0.0)
    place(bed, knock(1400, 0.04, 6000) * 0.4, 0.0)
    return bed


def sting_open():
    """Opening the hand: two warm taps and a soft wooden chord."""
    bed = np.zeros(int(1.1 * RATE))
    place(bed, knock(520, 0.14, 3500), 0.0)
    place(bed, knock(660, 0.16, 3500) * 0.9, 0.13)
    x = t(0.9)
    for f, g in ((196, 0.5), (294, 0.35), (392, 0.25)):
        place(bed, np.sin(2 * np.pi * f * x) * np.exp(-x / 0.35) * g * 0.5, 0.2)
    return bed


def sting_caught():
    """Caught: a hard drum hit with a falling pitch and a dissonant clang."""
    bed = np.zeros(int(1.2 * RATE))
    x = t(0.9)
    place(bed, np.sin(2 * np.pi * (60 * x + 10 * (1 - np.exp(-x * 9)))) * np.exp(-x / 0.25), 0.0)
    place(bed, bandpass(noise(0.3), 200, 4000) * env(0.3, 0.001, 0.05) * 0.8, 0.0)
    place(bed, clink(1500, 0.6) * 0.5 + clink(1590, 0.6) * 0.4, 0.02)
    return bed


def sting_win():
    """Finishing the hand: a rising run of tea-glass clinks over a low chord."""
    bed = np.zeros(int(2.0 * RATE))
    for i, f in enumerate((2400, 3000, 3600, 4800)):
        place(bed, clink(f, 0.9) * 0.55, 0.12 * i)
    x = t(1.5)
    for f in (130, 196, 262):
        place(bed, np.sin(2 * np.pi * f * x) * np.exp(-x / 0.5) * 0.4, 0.3)
    return bed


def sting_deck():
    """The pile ran out: a low, flat double knock."""
    bed = np.zeros(int(0.8 * RATE))
    place(bed, knock(180, 0.2, 1200), 0.0)
    place(bed, knock(150, 0.25, 1200) * 0.9, 0.22)
    return bed


def chalk():
    """Chalk on the board: a scratch with a little judder."""
    n = 0.16
    x = bandpass(noise(n), 2500, 9000) * env(n, 0.01, 0.07)
    return x * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * rng.uniform(60, 90) * t(n))))


def main():
    save("rain_loop.wav", rain_loop(), 0.6)
    save("stove_loop.wav", stove_loop(), 0.7)
    save("clock_loop.wav", clock_loop(), 0.5)
    for i, f in enumerate((3100, 3600, 2800)):
        save("spoon_%d.wav" % i, clink(f), 0.6)
    save("dice.wav", dice(), 0.7)
    for i in range(3):
        save("checker_%d.wav" % i, checker(), 0.6)
    save("tv_crowd_loop.wav", crowd_loop(), 0.6)
    save("murmur_loop.wav", murmur_loop(), 0.6)
    save("door_open.wav", door_open(), 0.8)
    save("door_close.wav", door_close(), 0.8)
    # The game's own sounds come last so that the sounds above stay exactly as they were.
    for i, f in enumerate((2100, 2500, 2900, 2300)):
        save("tile_click_%d.wav" % i, tile_click(f), 0.6)
    for i, f in enumerate((780, 880, 700)):
        save("tile_rack_%d.wav" % i, tile_rack(f), 0.6)
    for i, f in enumerate((320, 380, 280)):
        save("tile_felt_%d.wav" % i, tile_felt(f), 0.6)
    save("tile_slide.wav", tile_slide(), 0.45)
    save("shuffle.wav", shuffle(), 0.7)
    save("ui_hover.wav", ui_hover(), 0.4)
    save("ui_click.wav", ui_click(), 0.6)
    save("sting_open.wav", sting_open(), 0.7)
    save("sting_caught.wav", sting_caught(), 0.9)
    save("sting_win.wav", sting_win(), 0.7)
    save("sting_deck.wav", sting_deck(), 0.6)
    for i in range(3):
        save("chalk_%d.wav" % i, chalk(), 0.5)


main()

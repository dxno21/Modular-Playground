"""Hypnotische Sequenzen bei 138 BPM: Low, Mid, High – Pitch im Loose-Modus (nicht quantisiert).

Die drei Spuren laufen polymetrisch (16 / 14 / 15 Steps). Dadurch verschieben sie sich ständig
gegeneinander und treffen sich erst nach 210 Steps wieder: der hypnotische Effekt.

    python3 reference/sequences_138.py       # rendert previews/seq138_*.wav
"""
import random
from pathlib import Path

from metal_perc_ref import LOWMID_FM_METAL, SR, MetalPerc, write_wav

BPM = 138
COMMON = dict(bpm=BPM, qmode=0, clock_div=1)  # 1/16, Pitch Loose

SEQUENCES = {
    # Tiefe FM-Metal-Perc, rollend und offbeat, leicht verstimmte Mikro-Tonhöhen
    "low": dict(
        params=dict(LOWMID_FM_METAL, **COMMON, tune=38, seq_len=16, decay=0.36, fm_amt=0.8,
                    live_vel=1, vel_range=0.25, live_pitch=1, pitch_range=0.25),
        on=  "1000 0010 0010 1001",
        vel=[1, 0, 0, 0, 0, 0, .8, 0, 0, 0, .9, 0, .7, 0, 0, .6],
        pitch=[0, 0, 0, 0, 0, 0, -0.7, 0, 0, 0, 0.35, 0, -1.3, 0, 0, 0.5],
    ),
    # Mittlere Plonks über das Lowpass-Gate, 14 Steps gegen den 16er-Takt
    "mid": dict(
        params=dict(LOWMID_FM_METAL, **COMMON, tune=50, seq_len=14, amp_mode=1, lpg_color=0.7, decay=0.24,
                    fm_ratio=3.1, fm_amt=0.75, ring=0.6, live_vel=1, vel_range=0.35,
                    live_pitch=1, pitch_range=0.6, level=0.7),
        on=  "1010 0101 1001 01",
        vel=[1, 0, .55, 0, 0, .8, 0, .5, .9, 0, 0, .6, 0, .7],
        pitch=[0, 0, 2.5, 0, 0, -1.2, 0, 4.3, 0, 0, 0, 1.7, 0, -2.6],
    ),
    # Hohe metallische Ticks aus der Oszillator-Bank, 15 Steps, wahrscheinlichkeitsgesteuert
    "high": dict(
        params=dict(COMMON, morph=0.15, waveform=1, mod_wave=0, inharm=0.55, voices=5, spread=1.2, detune=12,
                    tilt=0.4, pw=0.35, tune=79, decay=0.1, attack=1.0, bright=0.8, drive=0.25, noise_mix=0.08,
                    accent=0.7, seq_len=15, live_steps=1, density=0.85, live_vel=1, vel_range=0.45,
                    live_pitch=1, pitch_range=1.5, analog=0.6, age=0.35, level=0.55),
        on=  "1101 1011 1101 101",
        vel=[1, .45, 0, .7, .9, 0, .5, .65, 1, .4, 0, .75, .85, 0, .55],
        pitch=[0, 0.4, 0, -0.6, 0, 0, 1.1, 0, 0, -0.3, 0, 0.8, 0, 0, -1.0],
    ),
}


def make_voice(name):
    seq = SEQUENCES[name]
    v = MetalPerc(**seq["params"])
    on = [int(c) for c in seq["on"].replace(" ", "")]
    n = len(on)
    v.steps_on = on + [0] * (16 - n)
    v.steps_vel = list(seq["vel"]) + [1.0] * (16 - n)
    v.steps_pitch = list(seq["pitch"]) + [0.0] * (16 - n)
    return v


def bars(n):
    return n * 4 * 60 / BPM


def main():
    out = Path(__file__).resolve().parent.parent / "previews"
    random.seed(138)
    for name in SEQUENCES:
        audio = make_voice(name).render(bars(4))
        peak = write_wav(out / f"seq138_{name}.wav", audio, normalize_to=0.89)
        print(f"seq138_{name}: Rohpegel peak={peak:.3f}")
    # Alle drei Spuren zusammen, 8 Takte
    random.seed(138)
    layers = [make_voice(name).render(bars(8)) for name in SEQUENCES]
    gains = {"low": 0.8, "mid": 0.8, "high": 1.6}  # Mischpult-Fader
    mix = [sum(g * x for g, x in zip(gains.values(), s)) for s in zip(*layers)]
    peak = write_wav(out / "seq138_mix_low_mid_high.wav", mix, normalize_to=0.89)
    print(f"seq138_mix_low_mid_high: Rohpegel peak={peak:.3f}")


if __name__ == "__main__":
    main()

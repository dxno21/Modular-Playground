"""Main Layer im Stil von Mord Records: roh, dunkel, industriell, rollende 16tel, 145 BPM.

Ein Metal-Perc-Device spielt eine verzerrte FM-Rolle zwischen den Kicks. Über 16 Takte werden
Fold, FM Amt und Decay hochgefahren, wie Automation in einem Track-Aufbau.

    python3 reference/sequence_mord_main.py   # rendert previews/mord_main_*.wav
"""
import math
import random
from pathlib import Path

from metal_perc_ref import SR, MetalPerc, write_wav

BPM = 145
BARS = 16

PARAMS = dict(
    bpm=BPM, clock_div=1, seq_len=16,
    # Pitch: Bb Phrygian (dunkle kleine Sekunde), Grundton Bb2 (~117 Hz) über der Kick
    tune=46, qmode=1, scale_sel=2, root=10,
    # Klang: lineare FM mit Metallstab-Ratio, Sinus-Träger, Saw-Modulator, viel Sättigung und Fold
    morph=0.5, waveform=0, mod_wave=2, fm_mode=0, fm_ratio=2.76, fm_amt=0.75, fm_fb=0.15,
    ring=0.4, ring_bleed=0.4, sweep=7, sweep_time=30, retrig=0,
    attack=3, decay=0.18, accent=0.8, drive=0.85, asym=0.5, wfold=0.3, noise_mix=0.0, level=0.8,
    # Analog: rau und lebendig, Sag pumpt mit den lauten Schlägen
    analog=0.7, age=0.5, sag=0.6, quality=1,
    # leichte Velocity-Variation pro Schlag
    live_vel=1, vel_range=0.2,
)

# Steps 1/5/9/13 bleiben für die Kick frei, Akzente auf den Offbeats (3/7/11/15)
STEPS_ON = "0111 0111 0111 0111"
STEPS_VEL = [0, .55, 1, .6, 0, .55, 1, .65, 0, .6, 1, .55, 0, .7, 1, .5]
STEPS_PITCH = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, -2, 0, 3]

# Variante "alle Steps": jeder Step spielt eine eigene Note (Bb Phrygian), Akzente weiter auf den Offbeats
ALL_ON = "1111 1111 1111 1111"
ALL_VEL = [.8, .5, 1, .6, .75, .5, 1, .65, .8, .5, 1, .55, .75, .7, 1, .5]
ALL_PITCH = [0, 12, 1, 0, -2, 0, 3, 1, 0, 12, 1, 0, -5, -2, 3, 7]

# Automation: (Parameter, Startwert, Endwert) linear über die 16 Takte
AUTOMATION = [("wfold", 0.3, 0.6), ("fm_amt", 0.75, 1.0), ("decay", 0.18, 0.3)]


def bar_len():
    return int(4 * 60 / BPM * SR)


def render_main(on=STEPS_ON, vel=STEPS_VEL, pitch=STEPS_PITCH):
    v = MetalPerc(**PARAMS)
    v.steps_on = [int(c) for c in on.replace(" ", "")]
    v.steps_vel = list(vel)
    v.steps_pitch = list(pitch)
    audio = []
    for bar in range(BARS):
        t = bar / (BARS - 1)
        for name, lo, hi in AUTOMATION:
            v.p[name] = lo + (hi - lo) * t
        audio += [v.tick() for _ in range(bar_len())]
    return audio


def render_kick(n_samples):
    """Einfache verzerrte Referenz-Kick auf jeder Viertel (nur zur Orientierung im Mix)."""
    out = [0.0] * n_samples
    beat = int(60 / BPM * SR)
    for start in range(0, n_samples, beat):
        ph = 0.0
        for n in range(min(int(0.4 * SR), n_samples - start)):
            t = n / SR
            f = 48 + 110 * math.exp(-t / 0.03)
            ph += f / SR
            env = math.exp(-t / 0.16)
            out[start + n] += math.tanh(3 * math.sin(2 * math.pi * ph) * env) * 0.9
    return out


def main():
    out = Path(__file__).resolve().parent.parent / "previews"
    random.seed(145)
    main_layer = render_main()
    peak = write_wav(out / "mord_main_layer.wav", main_layer, normalize_to=0.89)
    print(f"mord_main_layer: Rohpegel peak={peak:.3f}")
    kick = render_kick(len(main_layer))
    mix = [0.55 * k + m / peak * 0.55 for k, m in zip(kick, main_layer)]
    write_wav(out / "mord_main_with_ref_kick.wav", mix, normalize_to=0.89)
    print("mord_main_with_ref_kick: fertig")
    random.seed(146)
    peak = write_wav(out / "mord_main_all_steps.wav", render_main(ALL_ON, ALL_VEL, ALL_PITCH), normalize_to=0.89)
    print(f"mord_main_all_steps: Rohpegel peak={peak:.3f}")


if __name__ == "__main__":
    main()

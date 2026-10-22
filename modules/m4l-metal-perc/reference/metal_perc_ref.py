"""Python-Referenz des gen~-Codes (src/metal_perc.genexpr.in).

Bildet den DSP Sample für Sample nach, damit Klang und Pegel ohne Max geprüft
und WAV-Vorschauen gerendert werden können. Änderungen am Algorithmus immer in
beiden Dateien machen.

    python3 reference/metal_perc_ref.py          # rendert previews/*.wav
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100

SCALES = {
    "chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
    "minor_pentatonic": [0, 3, 5, 7, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian_dominant": [0, 1, 4, 5, 7, 8, 10],
    "hirajoshi": [0, 2, 3, 7, 8],
}
SCALE_NAMES = list(SCALES)


def scale_mask(degrees):
    return sum(1 << d for d in degrees)


SCALE_MASKS = [scale_mask(SCALES[n]) for n in SCALE_NAMES]

BANK_H = [1, 2, 3, 4, 5, 6]
BANK_M = [1, 1.483, 1.8, 2.546, 2.63, 3.897]
BANK_E = [1, 1.593, 2.135, 2.296, 2.917, 3.598]
DETUNE = [0, 0.7, -0.4, 1, -0.9, 0.3]
MODE_H = [1, 2, 3, 4]
MODE_B = [1, 2.756, 5.404, 8.933]
MODE_P = [1, 1.594, 2.136, 2.653]


def mix(a, b, t):
    return a + (b - a) * t


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def mtof(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def fract(x):
    return x - math.floor(x)


def noise():
    return random.uniform(-1, 1)


def blep(t, dt):
    if t < dt:
        x = t / dt
        return x + x - x * x - 1
    if t > 1 - dt:
        x = (t - 1) / dt
        return x * x + x + x + 1
    return 0.0


def osc(p, dt, w, pw=0.5):
    if w < 0.5:
        return math.sin(2 * math.pi * p)
    if w < 1.5:
        sq = 1 if p < pw else -1
        return sq + blep(p, dt) - blep(fract(p + 1 - pw), dt) - (2 * pw - 1)
    if w < 2.5:
        return 2 * p - 1 - blep(p, dt)
    return 4 * abs(p - 0.5) - 1


def quant(n, root, mask):
    base = math.floor(n + 0.5)
    best, bestd = base, 100
    for k in range(-6, 7):
        cand = base + k
        deg = (cand - root) % 12
        if (mask >> int(deg)) & 1 and abs(cand - n) < bestd:
            best, bestd = cand, abs(cand - n)
    return best


def svf(x, fc, q, st, i, mode):
    g = math.tan(math.pi * fc / SR)
    k = 1 / q
    a1 = 1 / (1 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1, ic2 = st[i], st[i + 1]
    v3 = x - ic2
    v1 = a1 * ic1 + a2 * v3
    v2 = ic2 + a2 * ic1 + a3 * v3
    st[i] = 2 * v1 - ic1
    st[i + 1] = 2 * v2 - ic2
    if mode == "bp":
        return v1 * k
    return x - k * v1 - v2


DEFAULTS = dict(
    tune=56, waveform=1, morph=0.0, inharm=0.5, attack=0.5, decay=0.3, damp=0.5, bright=0.6,
    drive=0.2, noise_mix=0.05, accent=0.5, level=0.8,
    voices=6, spread=1.0, detune=0.0, tilt=0.0, pw=0.5,
    fm_ratio=1.4142, fm_amt=0.36, fm_fb=0.0, ring=0.4, mod_wave=1,
    sweep=0.0, sweep_time=30.0, retrig=0,
    qmode=1, scale_sel=1, root=0,
    seq_on=1, bpm=130, clock_div=1, seq_len=16,
    live_steps=0, live_vel=0, live_pitch=0,
    density=0.6, vel_range=0.5, pitch_range=7,
)


class MetalPerc:
    def __init__(self, **params):
        self.p = dict(DEFAULTS, **params)
        self.steps_on = [1] * 16
        self.steps_vel = [1.0] * 16
        self.steps_pitch = [0.0] * 16
        self.int_phase = 0.0
        self.last_step = -1
        self.env = 0.0
        self.att = False
        self.target = 0.0
        self.coef = 0.999
        self.exc = 0.0
        self.pe = 0.0
        self.fb_prev = 0.0
        self.hit_note = self.p["tune"]
        self.hit_vel = 1.0
        self.ph = [0.0] * 8
        self.st = [0.0] * 16
        self.dc_x = self.dc_y = 0.0

    def trigger(self, vel, pitch):
        p = self.p
        note = p["tune"] + pitch
        if p["qmode"] > 0.5:
            note = quant(note, p["root"], SCALE_MASKS[int(p["scale_sel"])])
        self.hit_note = note
        self.hit_vel = vel
        t = 0.01 * 250 ** p["decay"]
        t *= 1 - p["accent"] * 0.5 + p["accent"] * vel
        self.coef = math.exp(-6.9078 / (t * SR))
        self.target = max(self.env, vel)
        self.att = True
        self.exc = 1.0
        self.pe = 1.0
        if p["retrig"] > 0.5:
            self.ph = [0.0] * 8
            self.fb_prev = 0.0

    def clock(self):
        p = self.p
        spb = [2, 4, 8, 3, 6][int(p["clock_div"])]
        length = int(p["seq_len"])
        self.int_phase += p["bpm"] / 60 / SR
        cur = math.floor(self.int_phase * spb) % length
        if cur == self.last_step:
            return
        self.last_step = cur
        if p["seq_on"] > 0.5 and self.steps_on[cur]:
            if p["live_steps"] < 0.5 or random.random() < p["density"]:
                vel = self.steps_vel[cur]
                pitch = self.steps_pitch[cur]
                if p["live_vel"] > 0.5:
                    vel *= 1 - p["vel_range"] * random.random()
                if p["live_pitch"] > 0.5:
                    pitch += p["pitch_range"] * noise()
                self.trigger(vel, pitch)

    def tick(self, use_seq=True):
        p = self.p
        if use_seq:
            self.clock()
        if self.att:
            self.env += (self.target - self.env) * (1 - math.exp(-4.6 / (p["attack"] * 0.001 * SR)))
            if self.env >= self.target * 0.99:
                self.att = False
        else:
            self.env *= self.coef
        self.exc *= 0.992
        env = self.env
        self.pe *= math.exp(-6.9078 / (p["sweep_time"] * 0.001 * SR))
        f0 = mtof(self.hit_note + p["sweep"] * self.pe)
        nyq = SR * 0.45
        w = math.floor(p["waveform"] + 0.5)
        acc_b = p["bright"] * (1 - p["accent"] * 0.4 + p["accent"] * 0.4 * self.hit_vel)
        ta = clamp(p["inharm"] * 2, 0, 1)
        tb = clamp(p["inharm"] * 2 - 1, 0, 1)

        nv = math.floor(p["voices"] + 0.5)
        bank = asum = 0.0
        for i in range(6):
            ratio = mix(mix(BANK_H[i], BANK_M[i], ta), BANK_E[i], tb)
            ratio = 1 + (ratio - 1) * p["spread"]
            ratio *= 2 ** (p["detune"] * DETUNE[i] / 1200)
            inc = min(f0 * ratio / SR, 0.45)
            ph = self.ph[i]
            if i < nv:
                amp = (i + 1) ** p["tilt"]
                bank += osc(ph, inc, w, p["pw"]) * amp
                asum += amp
            self.ph[i] = fract(ph + inc)
        bank /= asum
        fca = min(f0 * mix(2, 24, acc_b) * (0.4 + 0.6 * math.sqrt(env)), nyq)
        eng_a = 1.8 * svf(bank, fca, 1.5, self.st, 0, "bp") + 1.8 * svf(bank, fca, 0.7, self.st, 2, "hp")

        inc_c = min(f0 / SR, 0.45)
        inc_m = min(f0 * p["fm_ratio"] / SR, 0.45)
        pc, pm = self.ph[6], self.ph[7]
        mods = osc(fract(pm + p["fm_fb"] * 0.5 * self.fb_prev), inc_m, math.floor(p["mod_wave"] + 0.5), p["pw"])
        self.fb_prev = mods
        idx = p["fm_amt"] * 2 * env * (1 - p["accent"] * 0.4 + p["accent"] * 0.4 * self.hit_vel)
        car = osc(fract(pc + idx * mods), inc_c, w, p["pw"])
        rsig = osc(pc, inc_c, w, p["pw"]) * mods
        self.ph[6] = fract(pc + inc_c)
        self.ph[7] = fract(pm + inc_m)
        eng_b = 1.2 * (car * (1 - p["ring"]) + rsig * p["ring"])

        ex = noise() * self.exc * self.exc * (0.4 + 0.6 * acc_b) * self.hit_vel
        q = mix(400, 12, p["damp"])
        res = 0.0
        for j in range(4):
            mr = mix(mix(MODE_H[j], MODE_B[j], ta), MODE_P[j], tb)
            fr = min(f0 * mr, nyq)
            res += svf(ex, fr, q, self.st, 4 + j * 2, "bp") * math.sqrt(1000 / fr) / (j + 1)
        eng_c = res * math.sqrt(q) * 15 * min(1, env * 4)

        va, vb = eng_a * env, eng_b * env
        m = p["morph"] * 2
        if m < 1:
            voice = va * math.cos(m * math.pi / 2) + vb * math.sin(m * math.pi / 2)
        else:
            m -= 1
            voice = vb * math.cos(m * math.pi / 2) + eng_c * math.sin(m * math.pi / 2)
        nz = svf(noise(), min(f0 * 8, nyq), 0.7, self.st, 12, "hp") * env * p["noise_mix"]
        x = voice + nz
        g = 1 + p["drive"] * 12
        y = math.tanh(x * g) / math.sqrt(g)
        self.dc_y = y - self.dc_x + 0.995 * self.dc_y
        self.dc_x = y
        return self.dc_y * p["level"]

    def render(self, seconds, use_seq=True):
        return [self.tick(use_seq) for _ in range(int(seconds * SR))]


def write_wav(path, samples, normalize_to=None):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = normalize_to / peak if normalize_to else 1.0
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(clamp(s * gain, -1, 1) * 32767)) for s in samples)
        wf.writeframes(frames)
    return peak


# ------------------------------------------------------------------ Presets
def seq(on, vel=None, pitch=None):
    on = [int(c) for c in on.replace(" ", "")]
    return on, vel or [1.0] * 16, pitch or [0.0] * 16


# Low/Mid-FM-Metal: reine Sinus-FM (Träger + Modulator), Grundton G1 (~98 Hz),
# Ratio 2.76 (Metallstab-Mode) für metallische Seitenbänder, weicher Anschlag gegen Klicks
LOWMID_FM_METAL = dict(
    morph=0.5, waveform=0, mod_wave=0, fm_ratio=2.76, fm_amt=0.9, fm_fb=0.0, ring=0.7,
    sweep=5, sweep_time=40, retrig=0, attack=4, tune=43, decay=0.38, accent=0.6, drive=0.2,
    noise_mix=0.0, scale_sel=2, root=7, level=0.8,
)

PRESETS = {
    "01_bank_hats_square": dict(
        params=dict(morph=0.0, waveform=1, inharm=0.5, decay=0.12, bright=0.8, tune=60, noise_mix=0.25),
        pattern=seq("1011 1011 1011 1111",
                    vel=[1, .5, .8, .5, 1, .4, .8, .6, 1, .5, .8, .5, 1, .6, .9, .7]),
    ),
    "02_fm_clank_saw": dict(
        params=dict(morph=0.5, waveform=2, inharm=0.65, decay=0.35, bright=0.7, tune=48, drive=0.4, fm_ratio=2.12, mod_wave=2, fm_amt=0.42),
        pattern=seq("1001 0010 0100 1010",
                    pitch=[0, 0, 0, 3, 0, 0, 7, 0, 0, 5, 0, 0, 0, 0, 10, 0]),
    ),
    "03_resonator_pipes_phrygian": dict(
        params=dict(morph=1.0, inharm=0.55, damp=0.25, decay=0.6, bright=0.5, tune=50,
                    scale_sel=2, root=2, live_pitch=1, pitch_range=7),
        pattern=seq("1000 1010 0010 1000"),
    ),
    "04_industrial_drive_tri": dict(
        params=dict(morph=0.3, waveform=3, inharm=0.8, decay=0.25, bright=0.9, drive=0.9,
                    tune=40, noise_mix=0.4, live_vel=1, vel_range=0.6, fm_ratio=2.8, mod_wave=3, fm_amt=0.54),
        pattern=seq("1111 1111 1111 1111"),
    ),
    "05_hypnotic_random_sine": dict(
        params=dict(morph=0.7, waveform=0, inharm=0.6, decay=0.3, damp=0.4, bright=0.6, tune=55,
                    live_steps=1, density=0.7, live_pitch=1, pitch_range=5, scale_sel=4, fm_ratio=1.88, mod_wave=0),
        pattern=seq("1101 1011 0110 1101"),
    ),
    "07_osc_sweep_feedback_pulse": dict(
        params=dict(morph=0.5, waveform=1, mod_wave=2, pw=0.2, fm_ratio=3.1, fm_amt=0.6, fm_fb=0.7, ring=0.6,
                    sweep=36, sweep_time=40, retrig=1, decay=0.28, tune=38, drive=0.6),
        pattern=seq("1001 0010 1001 0110", vel=[1, .6, .6, .7, .6, .6, .9, .6, 1, .6, .6, .8, .6, .9, .7, .6]),
    ),
    "08_osc_bank_voices_spread_detune": dict(
        params=dict(morph=0.0, waveform=1, voices=3, spread=1.6, detune=25, tilt=0.6, pw=0.3, inharm=0.55,
                    decay=0.45, bright=0.7, tune=58),
        pattern=seq("1101 1011 0110 1101"),
    ),
    "09_lowmid_fm_metal": dict(
        params=dict(LOWMID_FM_METAL),
        pattern=seq("1001 0010 0100 1010",
                    vel=[1, 1, 1, .7, 1, 1, .8, 1, 1, .9, 1, 1, .75, 1, .85, 1],
                    pitch=[0, 0, 0, 1, 0, 0, 0, 0, 0, -2, 0, 0, 3, 0, 0, 0]),
    ),
}


def render_presets(out_dir, bars=2):
    out_dir.mkdir(parents=True, exist_ok=True)
    random.seed(7)
    report = []
    for name, preset in PRESETS.items():
        v = MetalPerc(**preset["params"])
        v.steps_on, v.steps_vel, v.steps_pitch = preset["pattern"]
        secs = bars * 4 * 60 / v.p["bpm"]
        audio = v.render(secs)
        peak = write_wav(out_dir / f"{name}.wav", audio, normalize_to=0.89)
        report.append((name, peak))
    # Waveform-Vergleich: gleicher Schlag, 4 Wellenformen nacheinander
    audio = []
    for w in range(4):
        v = MetalPerc(morph=0.25, waveform=w, mod_wave=w, decay=0.4, tune=52)
        v.trigger(1.0, 0)
        audio += v.render(0.6, use_seq=False)
    peak = write_wav(out_dir / "06_waveforms_sine_square_saw_tri.wav", audio, normalize_to=0.89)
    report.append(("06_waveforms_sine_square_saw_tri", peak))
    # Low/Mid-FM-Metal einzeln in drei Lagen: G1, D2, G2
    audio = []
    for pitch in (0, 7, 12):
        v = MetalPerc(**LOWMID_FM_METAL)
        v.trigger(1.0, pitch)
        audio += v.render(0.5, use_seq=False)
    peak = write_wav(out_dir / "10_lowmid_fm_metal_hits_G1_D2_G2.wav", audio, normalize_to=0.89)
    report.append(("10_lowmid_fm_metal_hits_G1_D2_G2", peak))
    return report


if __name__ == "__main__":
    here = Path(__file__).resolve().parent.parent
    for name, peak in render_presets(here / "previews"):
        print(f"{name:40s} Rohpegel peak={peak:.3f}")

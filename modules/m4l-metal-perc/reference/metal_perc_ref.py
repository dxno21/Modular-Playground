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


def svf(x, fc, q, sr, st, i, mode, sat=0.0):
    """TPT-SVF, mode 0 LP, 1 BP (unity peak), 2 HP; sat > 0 = OTA-Sättigung der Eingangsstufe."""
    g = math.tan(math.pi * min(fc, sr * 0.49) / sr)
    k = 1 / q
    a1 = 1 / (1 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1, ic2 = st[i], st[i + 1]
    v3 = x - ic2
    if sat > 0.001:
        v3 = math.tanh(v3 * sat) / sat
    v1 = a1 * ic1 + a2 * v3
    v2 = ic2 + a2 * ic1 + a3 * v3
    st[i], st[i + 1] = 2 * v1 - ic1, 2 * v2 - ic2
    if mode > 1.5:
        return x - k * v1 - v2
    if mode > 0.5:
        return v1 * k
    return v2


def rnd_hash(sd, i):
    return fract(math.sin(sd * 12.9898 + i * 78.233 + 0.5) * 43758.5453)


def diode(v):
    u = v - 0.2
    return u * u / (u + 0.2) if u > 0 else 0.0


def diode_ring(c, m):
    return (diode(c + m) + diode(-c - m) - diode(c - m) - diode(m - c)) * 1.25


DEFAULTS = dict(
    tune=56, waveform=1, morph=0.0, inharm=0.5, attack=0.5, decay=0.3, damp=0.5, bright=0.6,
    drive=0.2, noise_mix=0.05, accent=0.5, level=0.8,
    voices=6, spread=1.0, detune=0.0, tilt=0.0, pw=0.5,
    fm_ratio=1.4142, fm_amt=0.36, fm_fb=0.0, ring=0.4, mod_wave=1,
    sweep=0.0, sweep_time=30.0, retrig=0,
    fm_mode=0, ring_bleed=0.15,
    wfold=0.0, asym=0.25, amp_mode=0, lpg_color=0.6, reso_mode=0,
    analog=0.5, age=0.3, sag=0.25, hum=0.0, hum_hz=0, seed=1, quality=1,
    flt_type=0, cutoff=2000.0, reso=0.2, flt_env=0.0, key_trk=0.0,
    menv_atk=2.0, menv_dec=150.0, menv_curve=0.6, menv_loop=0, menv_pitch=0.0, menv_fm=0.0, menv_fold=0.0,
    qmode=1, scale_sel=1, root=0,
    seq_on=1, bpm=130, clock_div=1, seq_len=16, rtrg_rate=1, rtrg_len=1.0, rtrg_vel=-0.5,
    live_steps=0, live_vel=0, live_pitch=0,
    density=0.6, vel_range=0.5, pitch_range=7,
)


class MetalPerc:
    def __init__(self, **params):
        self.p = dict(DEFAULTS, **params)
        p = self.p
        self.steps_on = [1] * 16
        self.steps_vel = [1.0] * 16
        self.steps_pitch = [0.0] * 16
        self.steps_rtrg = [0] * 16
        self.rt_arm = False
        self.rt_on = False
        self.rt_cnt = self.rt_next = self.rt_total = self.rt_int = 0.0
        self.rt_vel, self.rt_note = 1.0, p["tune"]
        self.started = False
        self.int_phase = 0.0
        self.last_step = -1
        self.env = 0.0
        self.att = False
        self.target = 0.0
        self.coef = 0.999
        self.exc = 0.0
        self.pe = 0.0
        self.fb_prev = 0.0
        self.hit_note = p["tune"]
        self.hit_vel = 1.0
        self.pend = 0
        self.p_note, self.p_vel = p["tune"], 1.0
        self.vac = 0.0
        self.sagf = 0.0
        self.bt_amp = 0.0
        self.me_lin = 0.0
        self.me_stage = 0
        self.hum_ph = 0.0
        self.pk = [0.0, 0.0, 0.0]
        self.ph = [0.0] * 8
        self.osl = [0.0] * 8
        self.dr = [0.0] * 9
        self.st = [0.0] * 26
        self.dc_x = self.dc_y = 0.0
        sd = p["seed"]
        self.tol = ([rnd_hash(sd, i) * 2 - 1 for i in range(8)] + [rnd_hash(sd, i + 8) - 0.5 for i in range(8)]
                    + [rnd_hash(sd, i + 16) - 0.5 for i in range(8)] + [rnd_hash(sd, i + 24) for i in range(8)]
                    + [rnd_hash(sd, j + 32) * 2 - 1 for j in range(8)])

    # Ein Trigger vom Sequencer / MIDI: Tonhöhe bestimmen, mit Jitter starten
    def trigger(self, vel, pitch, rtrg=False):
        p = self.p
        self.rt_arm = rtrg
        note = p["tune"] + pitch
        if p["qmode"] > 0.5:
            note = quant(note, p["root"], SCALE_MASKS[int(p["scale_sel"])])
        jit = math.floor(random.random() * p["analog"] * 0.0004 * SR)
        if jit < 1:
            self.start(note, vel)
        else:
            self.pend, self.p_note, self.p_vel = jit, note, vel

    def start(self, note, vel, from_retrig=False):
        p = self.p
        self.started = True
        if not from_retrig:
            # Retrig (Elektron-Prinzip): Wiederholungen pro Step, rtrg_len Steps lang, mit Velocity-Verlauf
            self.rt_on = False
            if self.rt_arm:
                spb = [2, 4, 8, 3, 6][int(p["clock_div"])]
                step_samps = SR * 60 / (p["bpm"] * spb)
                self.rt_on = True
                self.rt_cnt = 0
                self.rt_int = step_samps / [2, 3, 4, 6, 8][int(math.floor(p["rtrg_rate"] + 0.5))]
                self.rt_next = self.rt_int
                self.rt_total = p["rtrg_len"] * step_samps
                self.rt_vel, self.rt_note = vel, note
            self.rt_arm = False
        self.hit_note = note
        self.hit_vel = vel
        t = 0.01 * 250 ** p["decay"]
        t *= 1 - p["accent"] * 0.5 + p["accent"] * vel
        self.coef = math.exp(-6.9078 / (t * SR))
        self.target = max(self.env, vel)
        self.att = True
        self.exc = 1.0
        self.pe = 1.0
        self.me_stage = 1
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
            return False
        self.last_step = cur
        if p["seq_on"] > 0.5 and self.steps_on[cur]:
            if p["live_steps"] < 0.5 or random.random() < p["density"]:
                vel = self.steps_vel[cur]
                pitch = self.steps_pitch[cur]
                if p["live_vel"] > 0.5:
                    vel *= 1 - p["vel_range"] * random.random()
                if p["live_pitch"] > 0.5:
                    pitch += p["pitch_range"] * noise()
                self.trigger(vel, pitch, bool(self.steps_rtrg[cur]))
                return True
        return False

    def tick(self, use_seq=True):
        p = self.p
        self.started = False
        fired = self.clock() if use_seq else False
        if not fired and self.pend > 0:
            self.pend -= 1
            if self.pend < 0.5:
                self.start(self.p_note, self.p_vel)
        if not self.started and self.rt_on:
            self.rt_cnt += 1
            if self.rt_cnt >= self.rt_total:
                self.rt_on = False
            elif self.rt_cnt >= self.rt_next:
                self.rt_next += self.rt_int
                v = clamp(self.rt_vel * (1 + p["rtrg_vel"] * self.rt_cnt / self.rt_total), 0, 1)
                self.start(self.rt_note, v, from_retrig=True)

        an, ag = p["analog"], p["age"]
        d_a = 1 - math.exp(-2 * math.pi * (0.4 + ag * 0.8) / SR)
        d_norm = 1 / math.sqrt(d_a / (2 - d_a) / 3)
        for i in range(9):
            self.dr[i] += (noise() - self.dr[i]) * d_a
        drift_c = an * (2 + ag * 10)
        tol_c = an * (3 + ag * 5)
        jit_c = an * (0.3 + ag)
        shape_ev = an * (0.04 + ag * 0.08)
        bleed = an * (0.0003 + ag * 0.0015)
        ota = an * (0.4 + ag * 0.8)
        tol = self.tol

        if self.att:
            ov = 1.01 + 0.02 * an
            self.env += (self.target * ov - self.env) * (1 - math.exp(-4.6 / (p["attack"] * 0.001 * SR)))
            if self.env >= self.target:
                self.env = self.target
                self.att = False
        else:
            self.env *= self.coef ** (1 - 0.3 * an * (1 - self.env))
        self.exc *= 0.992
        env = self.env
        if env > self.vac:
            self.vac += (env - self.vac) * (1 - math.exp(-1 / (0.002 * SR)))
        else:
            tau = 0.012 + 0.25 * (1 - self.vac) ** 2
            self.vac += (env - self.vac) * (1 - math.exp(-1 / (tau * SR)))
        vac = self.vac

        self.pe *= math.exp(-6.9078 / (p["sweep_time"] * 0.001 * SR))
        # Mod-Hüllkurve (AD, optional Loop)
        if self.me_stage == 2:
            self.me_lin -= 1 / (p["menv_dec"] * 0.001 * SR)
            if self.me_lin <= 0:
                self.me_lin = 0.0
                self.me_stage = 1 if p["menv_loop"] > 0.5 else 0
        elif self.me_stage == 1:
            self.me_lin += 1 / (p["menv_atk"] * 0.001 * SR)
            if self.me_lin >= 1:
                self.me_lin = 1.0
                self.me_stage = 2
        me_out = self.me_lin
        if self.me_stage != 1:
            me_out = mix(self.me_lin, self.me_lin ** 4, p["menv_curve"])
        me_v = me_out * (0.5 + 0.5 * self.hit_vel)
        gdrift = self.dr[8] * d_norm * drift_c * 0.5
        f0 = mtof(self.hit_note + p["sweep"] * self.pe + p["menv_pitch"] * me_v + gdrift * 0.01) * (1 - p["sag"] * 0.012 * self.sagf)
        w = math.floor(p["waveform"] + 0.5)
        mw = math.floor(p["mod_wave"] + 0.5)
        acc_b = p["bright"] * (1 - p["accent"] * 0.4 + p["accent"] * 0.4 * self.hit_vel)
        ta = clamp(p["inharm"] * 2, 0, 1)
        tb = clamp(p["inharm"] * 2 - 1, 0, 1)
        nv = math.floor(p["voices"] + 0.5)
        osf = [1, 2, 4][int(math.floor(p["quality"] + 0.5))]
        sr2 = SR * osf
        nyq = sr2 * 0.45
        idx = max(0.0, p["fm_amt"] * 2 * env * (1 - p["accent"] * 0.4 + p["accent"] * 0.4 * self.hit_vel)
                  + p["menv_fm"] * 2 * me_v)
        amp = vac ** 1.4 if p["amp_mode"] > 0.5 else env
        amp_ab = amp + bleed
        lpg_fc = mix(16000, 60 * 2 ** (vac * 8.2), p["lpg_color"])
        q = mix(400, 12, p["damp"])
        fold_e = clamp(p["wfold"] + p["menv_fold"] * me_v, 0, 1)
        fold_g = 1 + fold_e * 5
        flt_fc = p["cutoff"] * 2 ** (p["flt_env"] * 6 * me_v + p["key_trk"] * (self.hit_note - 60) / 12) \
            * (1 + an * 0.05 * self.tol[38])
        flt_q = 0.5 + p["reso"] ** 2 * 24
        ft = math.floor(p["flt_type"] + 0.5)
        dg = 1 + p["drive"] * 12
        ab = p["asym"] * 0.3
        fq, slc = [0.0] * 8, [0.0] * 8
        for i in range(8):
            cents = tol[i] * tol_c + self.dr[i] * d_norm * drift_c + noise() * jit_c
            fq[i] = 2 ** (cents / 1200)
            fsl = mix(20000, 5000, an * ag) * (0.85 + 0.3 * tol[i + 24])
            slc[i] = 1 - math.exp(-2 * math.pi * min(fsl, nyq) / sr2)

        st, ph, osl = self.st, self.ph, self.osl
        y = 0.0
        for _ in range(osf):
            bank = asum = 0.0
            for i in range(6):
                ratio = mix(mix(BANK_H[i], BANK_M[i], ta), BANK_E[i], tb)
                ratio = 1 + (ratio - 1) * p["spread"]
                ratio *= 2 ** (p["detune"] * DETUNE[i] / 1200)
                inc = min(f0 * ratio * fq[i] / sr2, 0.45)
                pp = ph[i]
                if i < nv:
                    amp_i = (i + 1) ** p["tilt"]
                    pw_i = clamp(p["pw"] + an * 0.08 * tol[i + 8], 0.03, 0.97)
                    yo = osc(pp, inc, w, pw_i)
                    yo = yo + shape_ev * (yo * yo - 0.5) + an * 0.06 * tol[i + 16]
                    osl[i] += (yo - osl[i]) * slc[i]
                    bank += osl[i] * amp_i
                    asum += amp_i
                ph[i] = fract(pp + inc)
            bank /= asum
            fca = min(f0 * mix(2, 24, acc_b) * (0.4 + 0.6 * math.sqrt(env)) * (1 + an * 0.04 * tol[32]), nyq)
            eng_a = 1.8 * svf(bank, fca, 1.5, sr2, st, 0, 1, ota) + 1.8 * svf(bank, fca, 0.7, sr2, st, 2, 2, ota)

            pc, pm = ph[6], ph[7]
            inc_m = min(f0 * p["fm_ratio"] * fq[7] / sr2, 0.45)
            mods = osc(fract(pm + p["fm_fb"] * 0.5 * self.fb_prev), inc_m, mw, p["pw"])
            mods = mods + shape_ev * (mods * mods - 0.5) + an * 0.06 * tol[23]
            self.fb_prev = mods
            inc_c = min(f0 * fq[6] / sr2, 0.45)
            if p["fm_mode"] > 0.5:
                inc_c = min(inc_c * 2 ** (idx * 0.75 * mods), 0.45)
                car = osc(pc, inc_c, w, p["pw"])
            else:
                car = osc(fract(pc + idx * mods), inc_c, w, p["pw"])
            cplain = osc(pc, inc_c, w, p["pw"])
            rb = p["ring_bleed"]
            rsig = mix(cplain * mods, diode_ring(cplain, mods), rb) + rb * (0.25 * cplain + 0.1 * mods)
            ph[6] = fract(pc + inc_c)
            ph[7] = fract(pm + inc_m)
            eng_b = 1.2 * (car * (1 - p["ring"]) + rsig * p["ring"])

            res = 0.0
            if p["reso_mode"] > 0.5:
                ex = self.exc ** 4 * self.hit_vel * 20
                qb = q * 0.5
                for j in range(2):
                    mr = 1 if j == 0 else mix(1.5, 2.3, p["inharm"])
                    fr = min(f0 * mr * (1 + 0.08 * self.bt_amp) * (1 + an * 0.01 * tol[33 + j]), nyq)
                    res += svf(ex, fr, qb, sr2, st, 4 + j * 2, 1, 1.5) * qb / (j + 1)
                self.bt_amp += (abs(res) - self.bt_amp) * 0.001
                res *= 0.5
            else:
                ex = noise() * self.exc * self.exc * (0.4 + 0.6 * acc_b) * self.hit_vel
                for j in range(4):
                    mr = mix(mix(MODE_H[j], MODE_B[j], ta), MODE_P[j], tb)
                    fr = min(f0 * mr * (1 + an * 0.01 * tol[33 + j]), nyq)
                    res += svf(ex, fr, q, sr2, st, 4 + j * 2, 1, 0) * math.sqrt(1000 / fr) / (j + 1)
                res *= math.sqrt(q) * 15 * osf ** 0.7
            eng_c = res * min(1, env * 4)

            va, vb = eng_a * amp_ab, eng_b * amp_ab
            m = p["morph"] * 2
            if m < 1:
                voice = va * math.cos(m * math.pi / 2) + vb * math.sin(m * math.pi / 2)
            else:
                m -= 1
                voice = vb * math.cos(m * math.pi / 2) + eng_c * math.sin(m * math.pi / 2)
            voice += svf(noise(), min(f0 * 8, nyq), 0.7, sr2, st, 12, 2, 0) * env * p["noise_mix"] * math.sqrt(osf)
            if p["amp_mode"] > 0.5:
                voice = svf(voice, lpg_fc, 0.6, sr2, st, 14, 0, ota)
            if ft > 0.5:
                fcl = clamp(flt_fc, 20, nyq)
                if ft > 3.5:
                    voice = voice - svf(voice, fcl, flt_q, sr2, st, 24, 1, ota)
                else:
                    voice = svf(voice, fcl, flt_q, sr2, st, 24, ft - 1, ota)
            if fold_e > 0.001:
                voice = mix(voice, math.sin(voice * fold_g * math.pi / 2), min(1, fold_e * 3))
            y = (math.tanh(dg * (voice + ab)) - math.tanh(dg * ab)) / math.sqrt(dg)
            if osf > 1:
                y = svf(y, SR * 0.42, 0.5176, sr2, st, 16, 0)
                y = svf(y, SR * 0.42, 0.7071, sr2, st, 18, 0)
                y = svf(y, SR * 0.42, 1.9319, sr2, st, 20, 0)

        dcy = svf(y, 25, 0.7071, SR, st, 22, 2)
        self.sagf += (abs(dcy) - self.sagf) * (0.02 if abs(dcy) > self.sagf else 0.0003)
        y_out = dcy * p["level"] * (1 - p["sag"] * 0.2 * min(1, self.sagf * 2))
        wn = noise()
        pk = self.pk
        pk[0] = 0.99765 * pk[0] + wn * 0.099046
        pk[1] = 0.963 * pk[1] + wn * 0.2965164
        pk[2] = 0.57 * pk[2] + wn * 1.0526913
        pink = (pk[0] + pk[1] + pk[2] + wn * 0.1848) * 0.2
        self.hum_ph = fract(self.hum_ph + (60 if p["hum_hz"] > 0.5 else 50) / SR)
        hz = (math.sin(2 * math.pi * self.hum_ph) + 0.5 * math.sin(6 * math.pi * self.hum_ph)
              + 0.25 * math.sin(10 * math.pi * self.hum_ph))
        return y_out + pink * an * (0.00005 + ag * 0.0003) + hz * p["hum"] * 0.003

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
    analog=0.6, age=0.35, ring_bleed=0.3, asym=0.3, sag=0.3,
)

# Komplett digital: alle Analog-Bausteine aus (zum A/B-Vergleich)
DIGITAL = dict(analog=0.0, age=0.0, sag=0.0, asym=0.0, ring_bleed=0.0, quality=0)

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
    "11_lpg_vactrol_fm_plonk": dict(
        params=dict(LOWMID_FM_METAL, amp_mode=1, lpg_color=0.75, decay=0.25, fm_amt=0.8, tune=48),
        pattern=seq("1010 0110 1001 0101", vel=[1, .5, .8, .5, .6, 1, .5, .7, 1, .5, .6, .9, .5, .8, .6, 1],
                    pitch=[0, 0, 3, 0, 0, 7, 0, 0, 0, 0, 1, 0, 0, 5, 0, 3]),
    ),
    "12_bridged_t_808_toms": dict(
        params=dict(morph=1.0, reso_mode=1, damp=0.55, inharm=0.4, tune=45, decay=0.5, analog=0.6, age=0.4,
                    noise_mix=0.0, qmode=1, scale_sel=2, root=9),
        pattern=seq("1001 0010 1000 1010", pitch=[0, 0, 0, 0, 0, 0, 5, 0, 7, 0, 0, 0, 3, 0, 0, 0]),
    ),
    "13_wavefolder_exp_fm": dict(
        params=dict(LOWMID_FM_METAL, fm_mode=1, fm_amt=0.7, wfold=0.6, drive=0.35, decay=0.3, tune=41),
        pattern=seq("1001 0010 0100 1010"),
    ),
    "15_retrig_rolls_138": dict(
        params=dict(LOWMID_FM_METAL, bpm=138, tune=45, decay=0.2, rtrg_rate=2, rtrg_len=1.0, rtrg_vel=-0.7),
        pattern=seq("1001 0010 1001 0111", pitch=[0, 0, 0, 1, 0, 0, 3, 0, 0, 0, 0, 0, 0, -2, 0, 5]),
        rtrg=[0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1],
    ),
    "16_filter_env_acid_metal": dict(
        params=dict(LOWMID_FM_METAL, bpm=138, tune=43, waveform=2, mod_wave=2, fm_amt=0.6, decay=0.3,
                    flt_type=1, cutoff=180.0, reso=0.75, flt_env=0.75, key_trk=0.5,
                    menv_atk=3.0, menv_dec=140.0, menv_curve=0.7, menv_fm=0.3, drive=0.55),
        pattern=seq("1011 0110 1101 0111", vel=[1, 0, .6, .8, 0, .9, .5, 0, 1, .6, 0, .8, 0, .7, .9, .5],
                    pitch=[0, 0, 0, 3, 0, 0, 1, 0, 0, 12, 0, 0, 0, -2, 0, 3]),
    ),
    "17_env_loop_pitch_fold": dict(
        params=dict(LOWMID_FM_METAL, bpm=138, tune=48, decay=0.5, menv_loop=1, menv_atk=20.0, menv_dec=90.0,
                    menv_curve=0.4, menv_pitch=5.0, menv_fold=0.5, flt_type=2, cutoff=1500.0, reso=0.4,
                    flt_env=0.4),
        pattern=seq("1000 0000 1000 0010"),
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
        v.steps_rtrg = list(preset.get("rtrg", [0] * 16))
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
    # A/B: dasselbe Pattern erst komplett digital, dann mit allen Analog-Bausteinen
    pat = PRESETS["09_lowmid_fm_metal"]["pattern"]
    audio = []
    for extra in (DIGITAL, {}):
        v = MetalPerc(**dict(LOWMID_FM_METAL, **extra))
        v.steps_on, v.steps_vel, v.steps_pitch = pat
        audio += v.render(2 * 4 * 60 / v.p["bpm"]) + [0.0] * int(0.4 * SR)
    peak = write_wav(out_dir / "14_ab_digital_then_analog.wav", audio, normalize_to=0.89)
    report.append(("14_ab_digital_then_analog", peak))
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

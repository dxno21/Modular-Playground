"""Rendert Hörproben direkt mit dem DSP des Devices (gen~ -> JavaScript, ausgeführt mit Node).

    python3 tools/render_js_previews.py

Anders als reference/metal_perc_ref.py ist das exakt derselbe Code wie im Device und im Browser-Player.
Jede Hörprobe besteht aus Abschnitten: gleiche Grundeinstellung, pro Abschnitt geänderte Parameter.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODULE = HERE.parent
sys.path.insert(0, str(MODULE / "reference"))
sys.path.insert(0, str(HERE))
from genexpr_to_js import transpile  # noqa: E402
from metal_perc_ref import LOWMID_FM_METAL  # noqa: E402
import sequence_mord_main as MORD  # noqa: E402

PATTERN = dict(on=[1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1],
               vel=[1, 0, .6, .8, 0, .9, .5, 0, 1, .6, 0, .8, 0, .7, .9, .5],
               pitch=[0, 0, 0, 3, 0, 0, 1, 0, 0, 12, 0, 0, 0, -2, 0, 3])

FILTER_BASE = dict(LOWMID_FM_METAL, clock_mode=2, bpm=138, tune=40, waveform=2, mod_wave=2, fm_amt=0.6, decay=0.32,
                   flt_type=1, cutoff=220.0, reso=0.8, flt_env=0.7, key_trk=0.5, menv_atk=3.0, menv_dec=160.0,
                   menv_curve=0.7, drive=0.5)

MORD_BASE = dict(MORD.PARAMS, clock_mode=2, live_vel=0)
MORD_PATTERN = dict(on=[int(c) for c in MORD.ALL_ON.replace(" ", "")], vel=MORD.ALL_VEL, pitch=MORD.ALL_PITCH)
HYPNO_PATTERN = dict(on=[1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0], vel=[1, 0, 0, .7, 0, 0, .9, 0, 1, 0, 0, .6, 0, .8, 0, 0],
                     pitch=[0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 0, -2, 0, 5, 0, 0])

PREVIEWS = {
    # Je 2 Takte: Clean, OSR, MS2, SMP, PRD mit derselben Einstellung
    "18_filter_circuits_clean_osr_ms2_smp_prd": dict(
        base=FILTER_BASE, bars=2,
        sections=[dict(flt_circ=c) for c in range(5)],
    ),
    # Morph-Filter: Morph wandert pro Takt LP -> BP -> HP -> Notch -> LP
    "19_filter_morph_sweep": dict(
        base=dict(FILTER_BASE, flt_type=5, cutoff=900.0, reso=0.55, flt_env=0.3), bars=1,
        sections=[dict(flt_morph=m / 8) for m in range(9)],
    ),
    # Filter-Drive in MS2: 0, 0.5, 1 (Resonanz wird mit mehr Drive weicher)
    "20_filter_drive_ms2": dict(
        base=dict(FILTER_BASE, flt_circ=2), bars=2,
        sections=[dict(flt_drive=d) for d in (0.0, 0.5, 1.0)],
    ),
    # DIRT: je 1 Takt Off, Diode, Tube, Fuzz, Rectify, Foldback, dann Bitcrusher
    "21_dirt_distortion_types": dict(
        base=dict(MORD_BASE, dist_drive=0.55, dist_tone=0.65), bars=1, pattern=MORD_PATTERN,
        sections=[dict(dist_type=t) for t in range(6)] + [dict(dist_type=0, crush_bits=6, crush_rate=6000.0)],
    ),
    # Feedback-Patch: Amt 0 / 0.4 / 0.8 in die FM, dann in den Filter, dann in beide
    "22_dirt_feedback_patch": dict(
        base=dict(MORD_BASE, flt_type=1, flt_circ=2, cutoff=1800.0, reso=0.5), bars=1, pattern=MORD_PATTERN,
        sections=[dict(fb_amt=0.0), dict(fb_amt=0.4, fb_dest=0), dict(fb_amt=0.8, fb_dest=0),
                  dict(fb_amt=0.5, fb_dest=1), dict(fb_amt=0.8, fb_dest=1), dict(fb_amt=0.7, fb_dest=2)],
    ),
    # Hard Sync 0 -> 0.3 -> 0.6 -> 1, dann Filter-FM 0.5 und 1 (Tiefpass)
    "23_dirt_hard_sync_filter_fm": dict(
        base=dict(MORD_BASE, waveform=2, fm_amt=0.25), bars=1, pattern=MORD_PATTERN,
        sections=[dict(sync=x) for x in (0.0, 0.3, 0.6, 1.0)]
        + [dict(sync=0.0, flt_type=1, flt_circ=4, cutoff=500.0, reso=0.6, flt_fm=x) for x in (0.5, 1.0)],
    ),
    # Rumble-Bus: 2 Takte trocken, dann 6 Takte mit Rumble (Send 0.7, Decay 0.7, Duck 0.7)
    "24_rumble_bus": dict(
        base=dict(LOWMID_FM_METAL, clock_mode=2, bpm=138, tune=43, decay=0.25), bars=2, pattern=HYPNO_PATTERN,
        sections=[dict(rmb_send=0.0), dict(rmb_send=0.7, rmb_decay=0.7, rmb_drive=0.6, rmb_lp=140.0, rmb_duck=0.7),
                  dict(), dict()],
    ),
}

RENDER_JS = r"""
import { createMetalPerc } from './dsp.mjs';
import { writeFileSync } from 'fs';
const spec = JSON.parse(process.argv[2]);
const SR = 44100;
const v = createMetalPerc(SR);
for (const [k, x] of Object.entries(spec.base)) v.set(k, x);
spec.pattern.on.forEach((x, i) => v.set(`s${i + 1}_on`, x));
spec.pattern.vel.forEach((x, i) => v.set(`s${i + 1}_vel`, x));
spec.pattern.pitch.forEach((x, i) => v.set(`s${i + 1}_pitch`, x));
const barLen = Math.round(SR * 4 * 60 / spec.base.bpm);
const ins = [0, 0, 0, 0, 0], outs = [0, 0, 0, 0];
const y = [];
for (const sec of spec.sections) {
  for (const [k, x] of Object.entries(sec)) v.set(k, x);
  for (let n = 0; n < barLen * spec.bars; n++) { v.tick(ins, outs); y.push(outs[0]); }
}
let peak = 1e-9; for (const s of y) peak = Math.max(peak, Math.abs(s));
const g = 0.89 / peak, buf = Buffer.alloc(44 + y.length * 2);
buf.write('RIFF', 0); buf.writeUInt32LE(36 + y.length * 2, 4); buf.write('WAVEfmt ', 8); buf.writeUInt32LE(16, 16);
buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22); buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28);
buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(y.length * 2, 40);
y.forEach((s, i) => buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s * g)) * 32767), 44 + i * 2));
writeFileSync(spec.out, buf);
console.log(`${spec.out}: ${(y.length / SR).toFixed(1)} s, Rohpegel peak=${peak.toFixed(3)}`);
"""


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "dsp.mjs").write_text(transpile((MODULE / "metal_perc.genexpr").read_text()))
        (tmp / "render.mjs").write_text(RENDER_JS)
        for name, spec in PREVIEWS.items():
            job = dict(spec, pattern=spec.get("pattern", PATTERN), out=str(MODULE / "previews" / f"{name}.wav"))
            subprocess.run(["node", str(tmp / "render.mjs"), json.dumps(job)], check=True)


if __name__ == "__main__":
    main()

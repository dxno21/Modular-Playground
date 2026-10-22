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

PATTERN = dict(on=[1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1],
               vel=[1, 0, .6, .8, 0, .9, .5, 0, 1, .6, 0, .8, 0, .7, .9, .5],
               pitch=[0, 0, 0, 3, 0, 0, 1, 0, 0, 12, 0, 0, 0, -2, 0, 3])

FILTER_BASE = dict(LOWMID_FM_METAL, clock_mode=2, bpm=138, tune=40, waveform=2, mod_wave=2, fm_amt=0.6, decay=0.32,
                   flt_type=1, cutoff=220.0, reso=0.8, flt_env=0.7, key_trk=0.5, menv_atk=3.0, menv_dec=160.0,
                   menv_curve=0.7, drive=0.5)

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
            job = dict(spec, pattern=PATTERN, out=str(MODULE / "previews" / f"{name}.wav"))
            subprocess.run(["node", str(tmp / "render.mjs"), json.dumps(job)], check=True)


if __name__ == "__main__":
    main()

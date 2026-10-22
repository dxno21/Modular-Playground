"""Baut die Preview-Seite für GitHub Pages: Layout, Hörproben und Downloads.

    python3 modules/m4l-metal-perc/tools/build_site.py _site

Der Workflow .github/workflows/pages.yml ruft das bei jedem Push auf und veröffentlicht _site.
"""
import html
import json
import shutil
import sys
from pathlib import Path

MODULE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(MODULE / "reference"))
sys.path.insert(0, str(MODULE / "tools"))

SECTIONS = [
    ("Main Layer im Mord-Stil · 145 BPM", "#ff6b4a", [
        ("mord_main_all_steps", "Alle 16 Steps mit eigener Note, Bb Phrygian, Drive steigt über 16 Takte auf 1.0"),
        ("mord_main_layer", "Rollende 16tel zwischen den Kick-Positionen, Akzente auf den Offbeats"),
        ("mord_main_with_ref_kick", "Derselbe Layer mit einfacher Referenz-Kick zur Orientierung"),
    ]),
    ("Hypnotische Sequenzen · 138 BPM · Pitch Loose", "#2ed3c4", [
        ("seq138_mix_low_mid_high", "Alle drei Spuren polymetrisch (16 / 14 / 15 Steps), 8 Takte"),
        ("seq138_low", "Low: FM-Metal, rollend und offbeat, D1"),
        ("seq138_mid", "Mid: Plonks über das Lowpass-Gate, 14 Steps, D2"),
        ("seq138_high", "High: metallische Ticks aus der Oszillator-Bank, 15 Steps, G4"),
    ]),
    ("Analog vs. Digital", "#7bd88f", [
        ("14_ab_digital_then_analog", "Dasselbe Pattern erst komplett digital, nach kurzer Pause mit allen Analog-Bausteinen"),
        ("11_lpg_vactrol_fm_plonk", "Lowpass-Gate mit Vactrol: schnell auf, langsam zu"),
        ("12_bridged_t_808_toms", "Resonator im Bridged-T-Modus (808-Prinzip)"),
        ("13_wavefolder_exp_fm", "Exponentielle FM und Wavefolder"),
    ]),
    ("Presets", "#ffad38", [
        ("15_retrig_rolls_138", "Retrig-Rolls bei 138 BPM: Steps 7, 15, 16 mit x4-Retrig, Velocity fällt ab"),
        ("09_lowmid_fm_metal", "Low/Mid FM Metal im Pattern, G Phrygian"),
        ("10_lowmid_fm_metal_hits_G1_D2_G2", "Low/Mid FM Metal als Einzelschläge auf G1, D2, G2"),
    ]),
    ("Klang-Engines und Oszillatoren", "#9d86ff", [
        ("01_bank_hats_square", "Oszillator-Bank, Square, kurze Decay: metallische Hats"),
        ("02_fm_clank_saw", "FM/Ring, Saw, Pitch-Steps: Industrial-Clank"),
        ("03_resonator_pipes_phrygian", "Resonator mit Live-Pitch in D Phrygian: Rohre und Bleche"),
        ("04_industrial_drive_tri", "Bank → FM, Triangle, viel Drive und Noise"),
        ("05_hypnotic_random_sine", "FM → Resonator, Sine, Live-Steps und Live-Pitch"),
        ("06_waveforms_sine_square_saw_tri", "Ein Schlag nacheinander mit Sine, Square, Saw, Triangle"),
        ("07_osc_sweep_feedback_pulse", "Pulse-FM mit Feedback, Pitch-Sweep und Phase Reset"),
        ("08_osc_bank_voices_spread_detune", "Bank mit 3 Oszillatoren, Spread, Detune und Tilt"),
    ]),
]

DOWNLOADS = [
    ("Metal Perc.amxd", "Max-for-Live-Instrument (experimentell, nicht eingefroren)"),
    ("seq_random.js", "Randomizer, gehört in denselben Ordner wie das Device"),
    ("metal_perc.maxpat", "Patch zum Einfügen in ein leeres Max Instrument (Fallback)"),
    ("metal_perc.genexpr", "gen~-DSP-Code zum Lesen"),
]

PAGE = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Metal Perc</title>
<meta name="description" content="Metallischer Percussion-Generator für Max for Live: Hörproben, Layout und Downloads.">
<style>
:root {{
  color-scheme: dark;
  --bg: #0f1012; --card: #1a1c20; --border: #2a2d33; --text: #d9dce2; --dim: #8a8f99;
  --accent: #ffad38;
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--text);
  font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Helvetica, Arial, sans-serif; }}
main {{ max-width: 980px; margin: 0 auto; padding: 40px 16px 80px; }}
header h1 {{ margin: 0; font-size: 34px; letter-spacing: -.01em; }}
header p {{ margin: 8px 0 0; color: var(--dim); max-width: 680px; }}
.chips {{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px; }}
.chip {{ font-size: 12px; padding: 3px 10px; border: 1px solid var(--border); border-radius: 999px; color: var(--dim); }}
.layout {{ margin: 28px 0 8px; border: 1px solid var(--border); border-radius: 8px; overflow-x: auto; background: #0b0b0d; }}
.layout img {{ display: block; height: 180px; width: auto; max-width: none; }}
.note {{ color: var(--dim); font-size: 13px; margin: 0 0 32px; }}
h2 {{ font-size: 13px; letter-spacing: .1em; text-transform: uppercase; margin: 40px 0 12px; color: var(--c); }}
.grid {{ display: grid; gap: 10px; }}
.track {{ background: var(--card); border: 1px solid var(--border); border-left: 3px solid var(--c);
  border-radius: 8px; padding: 12px 14px; }}
.track .name {{ font-weight: 600; font-size: 14px; }}
.track .desc {{ color: var(--dim); font-size: 13px; margin: 2px 0 8px; }}
audio {{ width: 100%; height: 36px; }}
.steps {{ background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 6px 22px; }}
.steps li {{ margin: 8px 0; }}
code {{ background: #26282d; padding: 1px 6px; border-radius: 4px; font-size: 13px; }}
.dl {{ display: grid; gap: 8px; }}
.dl a {{ display: flex; justify-content: space-between; gap: 16px; text-decoration: none; color: var(--text);
  background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 10px 14px; }}
.dl a:hover {{ border-color: var(--accent); }}
.dl span {{ color: var(--dim); font-size: 13px; text-align: right; }}
.cta {{ display: inline-block; margin-top: 24px; padding: 12px 20px; border-radius: 8px; background: var(--accent);
  color: #111; font-weight: 700; text-decoration: none; }}
.cta:hover {{ filter: brightness(1.1); }}
footer {{ margin-top: 48px; color: var(--dim); font-size: 13px; }}
footer a {{ color: var(--dim); }}
@media (max-width: 600px) {{ .dl a {{ flex-direction: column; }} .dl span {{ text-align: left; }} }}
</style>
</head>
<body>
<main>
<header>
  <h1>Metal Perc</h1>
  <p>Metallischer Percussion-Generator für Max for Live: drei Klang-Engines (Oszillator-Bank, FM/Ring, Resonator),
     16-Step-Sequencer mit Randomizer, 1-V/Oct-Quantizer und analoge Schaltungsmodelle.</p>
  <div class="chips"><span class="chip">Max for Live</span><span class="chip">gen~</span>
    <span class="chip">Hypnotic / Industrial Techno</span><span class="chip">Eurorack-Konzept</span></div>
</header>

<a class="cta" href="play/">▶ Live im Browser spielen</a>

<div class="layout"><img src="layout.png" alt="Layout des Devices mit den Sektionen SEQ, RANDOM, OSC, VOICE, CIRCUIT, ANALOG und OUT"></div>
<p class="note">Layout-Vorschau aus dem Patch gerendert. Die Hörproben stammen aus der Python-Referenz des DSP-Codes,
nicht aus Max.</p>

{sections}

<h2 style="--c: var(--accent)">In Ableton laden</h2>
<ol class="steps">
  <li><code>Metal Perc.amxd</code> und <code>seq_random.js</code> herunterladen und in <b>denselben Ordner</b> legen,
      zum Beispiel <code>User Library/Presets/Instruments/Max Instrument/</code>.</li>
  <li>Die <code>.amxd</code> aus dem Live-Browser auf eine MIDI-Spur ziehen.</li>
  <li>Einmal <b>Edit</b> öffnen und <b>Freeze Device</b> klicken, dann ist das JS eingebettet.</li>
  <li>Falls die <code>.amxd</code> nicht lädt: eine leere <i>Max Instrument</i>-Spur anlegen, im Editor die
      Standard-Objekte löschen und den Inhalt von <code>metal_perc.maxpat</code> hineinkopieren.</li>
</ol>

<h2 style="--c: var(--accent)">Downloads</h2>
<div class="dl">
{downloads}
</div>

<footer>Quellcode und Dokumentation:
  <a href="https://github.com/dxno21/Modular-Playground/tree/claude/eurorack-techno-modules-itxsmm/modules/m4l-metal-perc">
  github.com/dxno21/Modular-Playground</a></footer>
</main>
</body>
</html>
"""


def build(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    (out / "audio").mkdir(exist_ok=True)
    (out / "files").mkdir(exist_ok=True)
    shutil.copy(MODULE / "layout.png", out / "layout.png")

    parts = []
    for title, color, tracks in SECTIONS:
        items = []
        for name, desc in tracks:
            wav = MODULE / "previews" / f"{name}.wav"
            if not wav.exists():
                continue
            shutil.copy(wav, out / "audio" / wav.name)
            items.append(f'<div class="track"><div class="name">{html.escape(name)}</div>'
                         f'<div class="desc">{html.escape(desc)}</div>'
                         f'<audio controls preload="none" src="audio/{wav.name}"></audio></div>')
        if items:
            parts.append(f'<h2 style="--c: {color}">{html.escape(title)}</h2>\n<div class="grid" style="--c: {color}">'
                         + "\n".join(items) + "</div>")

    downloads = []
    for fname, desc in DOWNLOADS:
        src = MODULE / fname
        if src.exists():
            shutil.copy(src, out / "files" / fname)
            downloads.append(f'<a href="files/{html.escape(fname)}" download>{html.escape(fname)}'
                             f'<span>{html.escape(desc)}</span></a>')

    (out / "index.html").write_text(PAGE.format(sections="\n".join(parts), downloads="\n".join(downloads)))
    (out / ".nojekyll").write_text("")
    build_player(out / "play")
    print(f"{out}/index.html: {len(parts)} Sektionen, {len(downloads)} Downloads")


# ---------------------------------------------------------------- Browser-Player
UI_ATTRS = ["text", "fontname", "fontsize", "textcolor", "bgcolor", "bordercolor", "border", "rounded", "showname",
            "activedialcolor", "activefgdialcolor", "activeneedlecolor", "activebgcolor", "activebgoncolor",
            "activetextcolor", "activetextoncolor"]


def export_ui(patch):
    """Presentation-Ansicht des Patches als UI-Beschreibung; Parameter über die prepend-Verbindungen."""
    boxes = {b["box"]["id"]: b["box"] for b in patch["boxes"]}
    param_of = {}
    for line in patch["lines"]:
        src, dst = line["patchline"]["source"][0], line["patchline"]["destination"][0]
        text = boxes.get(dst, {}).get("text", "")
        if text.startswith("prepend ") and text != "prepend set":
            param_of[src] = text.split()[1]
    elements = []
    for b in patch["boxes"]:
        b = b["box"]
        if not b.get("presentation"):
            continue
        el = {"cls": b["maxclass"], "rect": b["presentation_rect"]}
        if b.get("varname"):
            el["var"] = b["varname"]
        if b["id"] in param_of:
            el["param"] = param_of[b["id"]]
        vo = b.get("saved_attribute_attributes", {}).get("valueof")
        if vo:
            el["vo"] = vo
        for k in UI_ATTRS:
            if k in b:
                el[k] = b[k]
        elements.append(el)
    sys.path.insert(0, str(MODULE))
    from build import SOUND_RANDOM
    return {"width": patch["devicewidth"], "height": 169, "elements": elements,
            "soundRandom": {g: {k: list(v) for k, v in t.items()} for g, t in SOUND_RANDOM.items()}}


def export_presets():
    import metal_perc_ref as R
    import sequence_mord_main as MORD
    import sequences_138 as S138

    def entry(params, on, vel, pitch, rtrg=None):
        on = [int(c) for c in on.replace(" ", "")] if isinstance(on, str) else list(on)
        n = len(on)
        params = {k: float(v) for k, v in params.items()}
        params.setdefault("bpm", 130.0)
        return {"params": params, "on": on + [0] * (16 - n),
                "vel": [float(v) for v in vel] + [1.0] * (16 - n), "pitch": [float(v) for v in pitch] + [0.0] * (16 - n),
                "rtrg": [int(v) for v in (rtrg or [])] + [0] * (16 - len(rtrg or []))}

    presets = {"Init": entry({}, "1" * 16, [1] * 16, [0] * 16)}
    presets["Mord Main Layer – alle Steps (145)"] = entry(MORD.PARAMS, MORD.ALL_ON, MORD.ALL_VEL, MORD.ALL_PITCH)
    presets["Mord Main Layer – Offbeat (145)"] = entry(MORD.PARAMS, MORD.STEPS_ON, MORD.STEPS_VEL, MORD.STEPS_PITCH)
    for name, seq in S138.SEQUENCES.items():
        presets[f"Hypnotic 138 – {name.title()}"] = entry(seq["params"], seq["on"], seq["vel"], seq["pitch"])
    for key, p in R.PRESETS.items():
        on, vel, pitch = p["pattern"]
        presets[key.split("_", 1)[1].replace("_", " ").title()] = entry(p["params"], on, vel, pitch, p.get("rtrg"))
    return presets


PLAY_PAGE = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Metal Perc Live</title>
<meta name="description" content="Metal Perc im Browser spielen: derselbe DSP wie im Max-for-Live-Device, als AudioWorklet.">
<style>
:root { color-scheme: dark; --bg: #0f1012; --card: #1a1c20; --border: #2a2d33; --text: #d9dce2; --dim: #8a8f99; --accent: #ffad38; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text);
  font: 14px/1.5 "Ableton Sans Medium", -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Helvetica, Arial, sans-serif; }
main { padding: 20px 16px 60px; max-width: 1800px; margin: 0 auto; }
a { color: var(--dim); }
h1 { font-size: 22px; margin: 0 0 4px; }
.sub { color: var(--dim); margin: 0 0 16px; }
.bar { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 14px; }
button, select, input { font: inherit; color: var(--text); background: var(--card); border: 1px solid var(--border);
  border-radius: 6px; padding: 7px 12px; }
button { cursor: pointer; }
button.on, #play.on { background: var(--accent); color: #111; border-color: var(--accent); font-weight: 700; }
#play { min-width: 96px; font-weight: 700; }
#bpm { width: 78px; }
label { color: var(--dim); display: flex; gap: 6px; align-items: center; }
#rack { overflow-x: auto; padding-bottom: 6px; }
.device { position: relative; border-radius: 4px; overflow: hidden; box-shadow: 0 0 0 1px #000; user-select: none;
  font-family: "Ableton Sans Medium", Inter, Helvetica, Arial, sans-serif; }
.dev-hdr { height: 18px; background: #26282d; color: #d4d7dd; font-size: 11px; line-height: 18px; padding-left: 24px; position: relative; }
.dev-hdr:before { content: ""; position: absolute; left: 7px; top: 5px; width: 8px; height: 8px; border-radius: 50%; background: #ffad38; }
.dev-body { position: relative; }
.gm { position: absolute; bottom: 14px; top: 0; width: 8px; border-radius: 2px; background: #2b2e35; overflow: hidden; }
.gm:nth-child(1) { left: 10px; } .gm:nth-child(2) { left: 22px; }
.gl { position: absolute; bottom: 0; left: 0; right: 0; height: 0;
  background: linear-gradient(to top, #2ed3c4 0 70%, #ffd34d 70% 90%, #ff5c5c 90% 100%); background-size: 100% 100%; }
.gh { position: absolute; left: 4px; right: 4px; height: 2px; background: #d4d7dd; margin-bottom: 14px; }
.gv { position: absolute; bottom: -2px; left: -6px; right: -6px; text-align: center; font-size: 8.5px; color: #8a8f99; }
.cpu { color: var(--dim); font-size: 12px; }
.notice { color: var(--dim); font-size: 13px; margin: -4px 0 12px; }
.notice.err { color: #ff6b6b; }
#hit { touch-action: manipulation; }
#status { color: var(--dim); font-size: 12px; min-height: 18px; margin-top: 6px; }
.help { margin-top: 18px; color: var(--dim); font-size: 13px; max-width: 900px; }
.help b { color: var(--text); }
kbd { background: #26282d; border-radius: 4px; padding: 0 5px; font-size: 12px; }
</style>
</head>
<body>
<main>
  <h1>Metal Perc · Live</h1>
  <p class="sub">Derselbe DSP wie im Max-for-Live-Device, automatisch aus dem gen~-Code übersetzt und als AudioWorklet
     im Browser. <a href="../">Zurück zur Übersicht</a></p>
  <div class="bar">
    <button id="play">▶ Play</button>
    <label>BPM <input id="bpm" type="number" min="40" max="300" value="130"></label>
    <label>Preset <select id="preset"><option value="">– wählen –</option></select></label>
    <button id="hit">● Hit</button>
    <button id="midi">MIDI aktivieren</button>
    <span id="cpu" class="cpu"></span>
  </div>
  <div id="notice" class="notice">Zum Starten auf ▶ Play oder ● Hit tippen. iPhone: Lautlos-Schalter aus und Lautstärke hoch.</div>
  <div id="rack"></div>
  <div id="status">Regler ziehen (vertikal), <kbd>Shift</kbd> für fein, Doppelklick setzt zurück.</div>
  <div class="help">
    <p><b>Spielen:</b> <kbd>Leertaste</kbd> startet/stoppt den Sequencer (Clock <i>Host</i> folgt dem BPM-Feld).
       Die Tasten <kbd>A W S E D F T G Y H U J K</kbd> spielen die Voice chromatisch ab C3, wie MIDI-Noten.
       Mit „MIDI aktivieren“ spielt ein angeschlossenes Keyboard (Chrome/Edge).</p>
    <p><b>Handy:</b> Auf dem iPhone den Lautlos-Schalter ausschalten. Auf Touch-Geräten startet der Player mit
       Quality <i>1x</i>. Bei zu hoher CPU-Last reduziert er Quality automatisch. Regler mit dem Finger vertikal ziehen,
       ● Hit spielt einen einzelnen Schlag.</p>
    <p><b>CPU:</b> Wenn es knackst, unter ANALOG → QUALITY auf <i>1x</i> stellen.</p>
  </div>
</main>
<script type="module" src="player.js"></script>
</body>
</html>
"""


def build_player(out: Path):
    from genexpr_to_js import transpile
    out.mkdir(parents=True, exist_ok=True)
    patch = json.loads((MODULE / "metal_perc.maxpat").read_text())["patcher"]
    (out / "ui.json").write_text(json.dumps(export_ui(patch)))
    (out / "presets.json").write_text(json.dumps(export_presets(), ensure_ascii=False))
    dsp = transpile((MODULE / "metal_perc.genexpr").read_text()).replace("export function", "function")
    template = (MODULE / "web" / "worklet_template.js").read_text()
    (out / "worklet.js").write_text(template.replace("/*DSP*/", dsp))
    shutil.copy(MODULE / "web" / "player.js", out / "player.js")
    (out / "index.html").write_text(PLAY_PAGE)
    print(f"{out}/: Player mit {len(json.loads((out / 'presets.json').read_text()))} Presets")


if __name__ == "__main__":
    build(Path(sys.argv[1] if len(sys.argv) > 1 else "_site"))

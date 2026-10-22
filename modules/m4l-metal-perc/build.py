"""Erzeugt metal_perc.genexpr und metal_perc.maxpat aus src/metal_perc.genexpr.in.

    python3 build.py

Die Step-Parameter (16 x On/Vel/Pitch) und das ganze Max-Patch werden hier
generiert, damit nichts von Hand dupliziert werden muss.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "reference"))
from metal_perc_ref import SCALE_MASKS, SCALE_NAMES  # noqa: E402

STEPS = 16
DEVICE_WIDTH = 1736
DEVICE_HEIGHT = 169


# ---------------------------------------------------------------- gen~ Code
def build_genexpr():
    src = (HERE / "src" / "metal_perc.genexpr.in").read_text()
    params = "\n".join(
        f"Param s{i}_on(1, min=0, max=1); Param s{i}_vel(1, min=0, max=1); "
        f"Param s{i}_pitch(0, min=-24, max=24);"
        for i in range(1, STEPS + 1)
    )

    def sel(field):
        args = ", ".join(f"s{i}_{field}" for i in range(1, STEPS + 1))
        return f"selector(cur + 1, {args})"

    code = (src.replace("@STEP_PARAMS@", params)
               .replace("@SEL_ON@", sel("on"))
               .replace("@SEL_VEL@", sel("vel"))
               .replace("@SEL_PITCH@", sel("pitch"))
               .replace("@SCALE_MASKS@", ", ".join(str(m) for m in SCALE_MASKS)))
    leftover = [tok for tok in ("@STEP_PARAMS@", "@SEL_ON@", "@SEL_VEL@", "@SEL_PITCH@", "@SCALE_MASKS@")
                if tok in code]
    assert not leftover, leftover
    return code


# ---------------------------------------------------------------- Max-Patch
class Patch:
    def __init__(self):
        self.boxes = []
        self.lines = []
        self.n = 0

    def _add(self, box):
        self.n += 1
        box["id"] = f"obj-{self.n}"
        self.boxes.append({"box": box})
        return box["id"]

    def obj(self, text, x, y, ninl=1, nout=1, outtypes=None, w=None, **extra):
        box = {
            "maxclass": "newobj", "text": text,
            "numinlets": ninl, "numoutlets": nout,
            "outlettype": outtypes if outtypes is not None else [""] * nout,
            "patching_rect": [x, y, w or max(40, 7 * len(text) + 12), 22],
        }
        box.update(extra)
        return self._add(box)

    def msg(self, text, x, y):
        return self._add({
            "maxclass": "message", "text": text, "numinlets": 2, "numoutlets": 1,
            "outlettype": [""], "patching_rect": [x, y, max(40, 7 * len(text) + 12), 22],
        })

    def comment(self, text, pres, size=9.5, header=False):
        return self._add({"_header": header,
            "maxclass": "comment", "text": text, "numinlets": 1, "numoutlets": 0,
            "fontsize": size, "patching_rect": [pres[0], pres[1] + 400, pres[2], pres[3]],
            "presentation": 1, "presentation_rect": pres,
        })

    def ui(self, maxclass, var, pres, valueof, ninl, nout, outtypes, **attrs):
        box = {
            "maxclass": maxclass, "varname": var,
            "numinlets": ninl, "numoutlets": nout, "outlettype": outtypes,
            "parameter_enable": 1,
            "patching_rect": [pres[0], pres[1] + 400, pres[2], pres[3]],
            "presentation": 1, "presentation_rect": pres,
            "saved_attribute_attributes": {"valueof": valueof},
        }
        box.update(attrs)
        return self._add(box)

    def line(self, src, so, dst, di):
        self.lines.append({"patchline": {"source": [src, so], "destination": [dst, di]}})


def valueof(longname, shortname, ptype, lo=0.0, hi=1.0, init=0.0, unit=1, enum=None, invisible=0):
    v = {
        "parameter_longname": longname, "parameter_shortname": shortname,
        "parameter_type": ptype, "parameter_initial": [init], "parameter_initial_enable": 1,
        "parameter_invisible": invisible,
    }
    if enum is not None:
        v["parameter_enum"] = enum
        v["parameter_mmax"] = len(enum) - 1
    else:
        v.update({"parameter_mmin": lo, "parameter_mmax": hi, "parameter_unitstyle": unit})
    return v


def dial(p, var, longname, shortname, pres, lo, hi, init, ptype=0, unit=1, small=False):
    attrs = {"showname": 0, "shownumber": 0} if small else {}
    return p.ui("live.dial", var, pres, valueof(longname, shortname, ptype, lo, hi, init, unit),
                1, 2, ["", "float"], **attrs)


def toggle(p, var, longname, pres, init):
    return p.ui("live.toggle", var, pres, valueof(longname, longname, 2, init=init, enum=["off", "on"]),
                1, 1, [""])


def tab(p, var, longname, pres, items, init, invisible=0):
    return p.ui("live.tab", var, pres, valueof(longname, longname, 2, init=init, enum=items, invisible=invisible),
                1, 3, ["", "", "float"], num_lines_presentation=1, num_lines_patching=1)


def menu(p, var, longname, pres, items, init):
    return p.ui("live.menu", var, pres, valueof(longname, longname, 2, init=init, enum=items),
                1, 3, ["", "", "float"])


def button(p, var, longname, pres):
    return p.ui("live.button", var, pres, valueof(longname, longname, 2, init=0, enum=["off", "on"]),
                1, 1, [""])


def gen_box(p, code, x, y):
    """gen~ mit eingebetteter Codebox (5 Eingänge, 4 Ausgänge)."""
    sub = {"boxes": [], "lines": []}
    sid = 0

    def sbox(box):
        nonlocal sid
        sid += 1
        box["id"] = f"obj-{sid}"
        sub["boxes"].append({"box": box})
        return box["id"]

    ins = [sbox({"maxclass": "newobj", "text": f"in {i}", "numinlets": 0, "numoutlets": 1,
                 "outlettype": [""], "patching_rect": [20 + 110 * (i - 1), 20, 40, 22]}) for i in range(1, 6)]
    cb = sbox({"maxclass": "codebox", "code": code, "fontface": 0, "fontname": "<Monospaced>", "fontsize": 12,
               "numinlets": 5, "numoutlets": 4, "outlettype": ["", "", "", ""],
               "patching_rect": [20, 60, 760, 600]})
    outs = [sbox({"maxclass": "newobj", "text": f"out {i}", "numinlets": 1, "numoutlets": 0,
                  "patching_rect": [20 + 110 * (i - 1), 680, 40, 22]}) for i in range(1, 5)]
    for i, b in enumerate(ins):
        sub["lines"].append({"patchline": {"source": [b, 0], "destination": [cb, i]}})
    for i, b in enumerate(outs):
        sub["lines"].append({"patchline": {"source": [cb, i], "destination": [b, 0]}})
    patcher = {
        "fileversion": 1,
        "appversion": {"major": 8, "minor": 6, "revision": 0, "architecture": "x64", "modernui": 1},
        "classnamespace": "dsp.gen", "rect": [100, 100, 820, 740],
        "boxes": sub["boxes"], "lines": sub["lines"],
    }
    return p.obj("gen~", x, y, 5, 4, ["signal"] * 4, w=300, patcher=patcher)


# ---------------------------------------------------------------- Theme (Dark Mode)
def rgb(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    return [round(int(h[i:i + 2], 16) / 255, 3) for i in (0, 2, 4)] + [a]


THEME = {
    "bg": rgb("#131417"), "card": rgb("#1d1f23"), "card_border": rgb("#2a2d33"), "stripe": rgb("#25282d"),
    "ctrl": rgb("#2b2e35"), "track": rgb("#3a3e46"), "border": rgb("#3a3e46"),
    "text": rgb("#d4d7dd"), "dim": rgb("#8a8f99"), "on_accent": rgb("#111214"),
    "font": "Ableton Sans Medium", "font_bold": "Ableton Sans Bold",
}
# Akzentfarbe je Sektion, Zuordnung über die x-Position in der Presentation-Ansicht
SECTIONS = [
    # (Name, x von, x bis, Akzent)
    ("SEQ", 0, 440, rgb("#2ed3c4")),
    ("RANDOM", 440, 540, rgb("#ff5c93")),
    ("OSC", 540, 832, rgb("#9d86ff")),
    ("VOICE", 832, 1242, rgb("#ffad38")),
    ("CIRCUIT", 1242, 1486, rgb("#ff6b4a")),
    ("ANALOG", 1486, 1678, rgb("#7bd88f")),
    ("OUT", 1678, DEVICE_WIDTH, rgb("#d4d7dd")),
]
CARDS = [[2, 2, 436, 165], [442, 2, 94, 165], [540, 2, 290, 165], [834, 2, 406, 165],
         [1244, 2, 240, 165], [1488, 2, 188, 165], [1680, 2, 54, 165]]


def accent_for(x):
    for _, lo, hi, acc in SECTIONS:
        if lo <= x < hi:
            return acc
    return THEME["text"]


def dim(c, f=0.45):
    return [round(c[0] * f, 3), round(c[1] * f, 3), round(c[2] * f, 3), 1.0]


def apply_theme(p):
    t = THEME
    for wrapper in p.boxes:
        b = wrapper["box"]
        if not b.get("presentation"):
            continue
        acc = accent_for(b["presentation_rect"][0])
        mc = b["maxclass"]
        style = {}
        if mc == "live.dial":
            style = {"activedialcolor": acc, "dialcolor": dim(acc), "activefgdialcolor": t["track"],
                     "fgdialcolor": t["track"], "activeneedlecolor": t["text"], "needlecolor": t["dim"],
                     "textcolor": t["text"], "fontname": t["font"], "fontsize": 9.0}
        elif mc in ("live.toggle", "live.button"):
            style = {"bgcolor": t["ctrl"], "activebgcolor": t["ctrl"], "bgoncolor": acc, "activebgoncolor": acc,
                     "bordercolor": t["border"], "focusbordercolor": acc}
        elif mc == "live.tab":
            style = {"bgcolor": t["ctrl"], "activebgcolor": t["ctrl"], "bgoncolor": acc, "activebgoncolor": acc,
                     "bordercolor": t["border"], "focusbordercolor": acc, "textcolor": t["dim"],
                     "activetextcolor": t["dim"], "textoncolor": t["on_accent"], "activetextoncolor": t["on_accent"],
                     "fontname": t["font"], "fontsize": 9.0}
        elif mc == "live.menu":
            style = {"bgcolor": t["ctrl"], "activebgcolor": t["ctrl"], "bordercolor": t["border"],
                     "textcolor": t["text"], "activetextcolor": t["text"], "tricolor": acc, "activetricolor": acc,
                     "fontname": t["font"], "fontsize": 9.0}
        elif mc == "live.gain~":
            style = {"textcolor": t["dim"], "fontname": t["font"]}
        elif mc == "comment":
            header = b.pop("_header", False)
            style = {"textcolor": acc if header else t["dim"], "fontname": t["font_bold"] if header else t["font"],
                     "fontsize": 10.0 if header else 8.5}
        b.update(style)


def add_panels(p):
    """Hintergrund, Sektions-Karten und Beat-Streifen als Panels ganz nach hinten legen."""
    panels = []

    def panel(rect, color, border=None, rounded=0):
        box = {"maxclass": "panel", "numinlets": 1, "numoutlets": 0, "background": 1, "mode": 0,
               "bgcolor": color, "rounded": rounded, "border": 1 if border else 0,
               "patching_rect": [rect[0], rect[1] + 400, rect[2], rect[3]],
               "presentation": 1, "presentation_rect": rect}
        if border:
            box["bordercolor"] = border
        panels.append({"box": box})

    panel([0, 0, DEVICE_WIDTH, DEVICE_HEIGHT], THEME["bg"])
    for rect in CARDS:
        panel(rect, THEME["card"], THEME["card_border"], rounded=6)
    for g in (0, 2):  # Beat 1 und 3 leicht hervorheben
        panel([46 + g * 96, 18, 96, 82], THEME["stripe"], rounded=3)
    for i, wrapper in enumerate(panels):
        wrapper["box"]["id"] = f"panel-{i + 1}"
    p.boxes[:0] = panels


def build_maxpat(code):
    p = Patch()
    gen = gen_box(p, code, 40, 1000)

    def to_gen(src, name, x, y, outlet=0):
        pre = p.obj(f"prepend {name}", x, y)
        p.line(src, outlet, pre, 0)
        p.line(pre, 0, gen, 0)

    # ---------------- Signalfluss
    phasor = p.obj("plugphasor~", 40, 940, 1, 1, ["signal"])
    p.line(phasor, 0, gen, 0)
    p.comment("OUT", [1686, 3, 44, 14], header=True)
    gain = p.ui("live.gain~", "out_gain", [1688, 20, 40, 132],
                valueof("Output", "Output", 0, -70.0, 6.0, 0.0, unit=4), 2, 5,
                ["signal", "signal", "", "float", "list"])
    p.line(gen, 0, gain, 0)
    p.line(gen, 0, gain, 1)
    plugout = p.obj("plugout~ 1 2", 40, 1100, 2, 0, [])
    p.line(gain, 0, plugout, 0)
    p.line(gain, 1, plugout, 1)

    # Step-Anzeige
    led = tab(p, "step_led", "Step LED", [48, 2, STEPS * 24, 14], [str(i) for i in range(1, STEPS + 1)], 0,
              invisible=2)
    snap = p.obj("snapshot~ 30", 400, 1060, 2, 1)
    chg = p.obj("change", 400, 1085, 1, 3, ["", "int", "int"])
    setm = p.obj("prepend set", 400, 1110)
    p.line(gen, 2, snap, 0)
    p.line(snap, 0, chg, 0)
    p.line(chg, 0, setm, 0)
    p.line(setm, 0, led, 0)

    # MIDI: Noten aus Live-Clips triggern die Voice
    midiin = p.obj("midiin", 700, 940, 1, 1)
    mparse = p.obj("midiparse", 700, 965, 1, 8)
    trig = p.obj("t b l", 700, 990, 1, 2)
    unpack = p.obj("unpack 0 0", 760, 1015, 1, 2)
    flip = p.obj("counter 0 0 1", 700, 1040, 3, 4)
    p.line(midiin, 0, mparse, 0)
    p.line(mparse, 0, trig, 0)
    p.line(trig, 1, unpack, 0)
    p.line(trig, 0, flip, 0)
    to_gen(unpack, "midi_note", 760, 1065, 0)
    to_gen(unpack, "midi_vel", 860, 1065, 1)
    to_gen(flip, "midi_id", 700, 1090, 0)

    # ---------------- Sequencer
    p.comment("SEQ", [8, 3, 40, 14], header=True)
    p.comment("STEP", [8, 21, 38, 14])
    p.comment("VEL", [8, 47, 38, 14])
    p.comment("PITCH", [8, 79, 38, 14])
    for i in range(1, STEPS + 1):
        x = 48 + (i - 1) * 24
        on = toggle(p, f"s{i}_on", f"S{i} On", [x + 4, 20, 16, 16], 1)
        vel = dial(p, f"s{i}_vel", f"S{i} Vel", f"Vel{i}", [x, 40, 24, 26], 0.0, 1.0, 1.0, small=True)
        pit = dial(p, f"s{i}_pitch", f"S{i} Pitch", f"Pit{i}", [x, 72, 24, 26], -24.0, 24.0, 0.0,
                   unit=7, small=True)
        px = 40 + (i - 1) * 140
        to_gen(on, f"s{i}_on", px, 1200)
        to_gen(vel, f"s{i}_vel", px, 1230)
        to_gen(pit, f"s{i}_pitch", px, 1260)

    p.comment("RUN", [46, 106, 30, 14])
    to_gen(toggle(p, "seq_on", "Seq On", [48, 122, 16, 16], 1), "seq_on", 40, 1320)
    p.comment("CLOCK", [72, 106, 60, 14])
    to_gen(tab(p, "clock_mode", "Clock", [72, 122, 96, 16], ["Host", "Ext", "Int"], 0), "clock_mode", 200, 1320)
    p.comment("DIV", [176, 106, 40, 14])
    to_gen(menu(p, "clock_div", "Division", [176, 122, 52, 16], ["1/8", "1/16", "1/32", "1/8T", "1/16T"], 1),
           "clock_div", 360, 1320)
    to_gen(dial(p, "seq_len", "Length", "Length", [240, 104, 44, 48], 1, 16, 16, ptype=1, unit=0),
           "seq_len", 520, 1320)
    to_gen(dial(p, "bpm", "Int BPM", "BPM", [292, 104, 44, 48], 40.0, 300.0, 130.0), "bpm", 680, 1320)
    p.comment("RESET", [344, 106, 40, 14])
    rst = button(p, "reset", "Reset", [348, 122, 16, 16])
    rcount = p.obj("counter 0 0 1", 840, 1320, 3, 4)
    p.line(rst, 0, rcount, 0)
    to_gen(rcount, "reset_id", 840, 1345)

    # ---------------- Randomizer
    js = p.obj("js seq_random.js", 40, 1400, 1, 0, [])
    p.comment("RANDOM", [446, 3, 80, 14], header=True)
    p.comment("RND", [442, 100, 24, 12])
    p.comment("RNG", [466, 100, 26, 12])
    p.comment("LIVE", [496, 100, 30, 12])
    p.comment("CLEAR", [464, 125, 40, 14])
    lanes = [
        ("steps", "density", "Density", "Dens", 0.0, 1.0, 0.6, 1, 20, "live_steps", "rand_steps"),
        ("vel", "vel_range", "Vel Range", "VRng", 0.0, 1.0, 0.5, 1, 42, "live_vel", "rand_vel"),
        ("pitch", "pitch_range", "Pitch Range", "PRng", 0, 24, 7, 7, 74, "live_pitch", "rand_pitch"),
    ]
    for k, (lane, rvar, rlong, rshort, lo, hi, init, unit, y, live_var, fn) in enumerate(lanes):
        b = button(p, f"rand_{lane}", f"Rand {lane.title()}", [444, y + 2, 16, 16])
        m = p.msg(fn, 200 + k * 140, 1400)
        p.line(b, 0, m, 0)
        p.line(m, 0, js, 0)
        ptype = 1 if lane == "pitch" else 0
        to_gen(dial(p, rvar, rlong, rshort, [468, y, 24, 26], lo, hi, init, ptype=ptype, unit=unit, small=True),
               rvar, 200 + k * 140, 1440)
        to_gen(toggle(p, live_var, f"Live {lane.title()}", [500, y + 2, 16, 16], 0), live_var,
               200 + k * 140, 1470)
    clr = button(p, "clear", "Clear Pattern", [444, 124, 16, 16])
    clr_m = p.msg("clear_pattern", 620, 1400)
    p.line(clr, 0, clr_m, 0)
    p.line(clr_m, 0, js, 0)

    # ---------------- Oszillatoren
    p.comment("OSC", [548, 3, 60, 14], header=True)
    osc_rows = [
        (14, [("voices", "Voices", 1, 6, 6, 0, 1), ("spread", "Spread", 0.0, 2.0, 1.0, 1, 0),
              ("detune", "Detune", 0.0, 50.0, 0.0, 1, 0), ("tilt", "Tilt", -1.0, 1.0, 0.0, 1, 0),
              ("pw", "PW", 0.05, 0.95, 0.5, 1, 0)]),
        (64, [("fm_ratio", "FM Ratio", 0.5, 8.0, 1.4142, 1, 0), ("fm_amt", "FM Amt", 0.0, 1.0, 0.36, 1, 0),
              ("fm_fb", "FM FB", 0.0, 1.0, 0.0, 1, 0), ("ring", "Ring", 0.0, 1.0, 0.4, 1, 0),
              ("sweep", "Sweep", -24.0, 48.0, 0.0, 7, 0)]),
    ]
    for r, (y, row) in enumerate(osc_rows):
        for c, (var, name, lo, hi, init, unit, ptype) in enumerate(row):
            d = dial(p, var, name, name, [550 + c * 56, y, 44, 48], lo, hi, init, ptype=ptype, unit=unit)
            to_gen(d, var, 40 + c * 140 + r * 70, 1660 + r * 30)
    p.comment("MOD WAVE", [550, 116, 80, 14])
    to_gen(tab(p, "mod_wave", "Mod Wave", [550, 132, 112, 16], ["Sin", "Sqr", "Saw", "Tri"], 1), "mod_wave",
           40, 1720)
    p.comment("PHASE", [670, 116, 60, 14])
    to_gen(tab(p, "retrig", "Phase", [670, 132, 84, 16], ["Free", "Reset"], 0), "retrig", 200, 1720)
    to_gen(dial(p, "sweep_time", "Sweep Time", "Sw Time", [774, 114, 44, 48], 1.0, 500.0, 30.0, unit=2),
           "sweep_time", 360, 1720)

    # ---------------- Voice
    p.comment("VOICE", [842, 3, 60, 14], header=True)
    row1 = [
        ("tune", "Tune", 24.0, 96.0, 56.0, 8),
        ("morph", "Morph", 0.0, 1.0, 0.0, 1),
        ("inharm", "Inharm", 0.0, 1.0, 0.5, 1),
        ("decay", "Decay", 0.0, 1.0, 0.3, 1),
        ("damp", "Damp", 0.0, 1.0, 0.5, 1),
        ("bright", "Bright", 0.0, 1.0, 0.6, 1),
    ]
    row2 = [
        ("attack", "Attack", 0.1, 50.0, 0.5, 2),
        ("drive", "Drive", 0.0, 1.0, 0.2, 1),
        ("noise_mix", "Noise", 0.0, 1.0, 0.05, 1),
        ("accent", "Accent", 0.0, 1.0, 0.5, 1),
        ("level", "Level", 0.0, 1.0, 0.8, 1),
    ]
    for row, y in ((row1, 14), (row2, 64)):
        for c, (var, name, lo, hi, init, unit) in enumerate(row):
            d = dial(p, var, name, name, [840 + c * 56, y, 44, 48], lo, hi, init, unit=unit)
            to_gen(d, var, 40 + c * 140 + (0 if y == 14 else 70), 1520 if y == 14 else 1550)
    p.comment("WAVE", [1122, 64, 60, 14])
    to_gen(tab(p, "waveform", "Wave", [1122, 80, 112, 16], ["Sin", "Sqr", "Saw", "Tri"], 1), "waveform", 40, 1600)
    p.comment("PITCH MODE", [840, 116, 80, 14])
    to_gen(tab(p, "qmode", "Pitch Mode", [840, 132, 84, 16], ["Loose", "Scale"], 1), "qmode", 200, 1600)
    p.comment("SCALE", [932, 116, 60, 14])
    to_gen(menu(p, "scale_sel", "Scale", [932, 132, 120, 16], [n.replace("_", " ").title() for n in SCALE_NAMES], 1),
           "scale_sel", 360, 1600)
    p.comment("ROOT", [1060, 116, 40, 14])
    to_gen(menu(p, "root", "Root", [1060, 132, 52, 16],
                ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"], 0), "root", 520, 1600)

    # ---------------- Circuit
    p.comment("CIRCUIT", [1250, 3, 80, 14], header=True)
    for c, (var, name, init) in enumerate([("wfold", "Fold", 0.0), ("asym", "Asym", 0.25),
                                            ("ring_bleed", "Bleed", 0.15), ("lpg_color", "LPG Col", 0.6)]):
        to_gen(dial(p, var, name, name, [1248 + c * 56, 14, 44, 48], 0.0, 1.0, init), var, 40 + c * 140, 1780)
    p.comment("AMP", [1248, 66, 60, 14])
    to_gen(tab(p, "amp_mode", "Amp Mode", [1248, 82, 104, 16], ["VCA", "LPG"], 0), "amp_mode", 40, 1810)
    p.comment("FM", [1360, 66, 60, 14])
    to_gen(tab(p, "fm_mode", "FM Mode", [1360, 82, 112, 16], ["Lin", "Exp"], 0), "fm_mode", 200, 1810)
    p.comment("RESO", [1248, 116, 60, 14])
    to_gen(tab(p, "reso_mode", "Reso Mode", [1248, 132, 140, 16], ["Modal", "Bridged-T"], 0), "reso_mode",
           360, 1810)

    # ---------------- Analog
    p.comment("ANALOG", [1494, 3, 80, 14], header=True)
    for c, (var, name, init) in enumerate([("analog", "Analog", 0.5), ("age", "Age", 0.3), ("sag", "Sag", 0.25)]):
        to_gen(dial(p, var, name, name, [1492 + c * 56, 14, 44, 48], 0.0, 1.0, init), var, 40 + c * 140, 1840)
    to_gen(dial(p, "hum", "Hum", "Hum", [1492, 64, 44, 48], 0.0, 1.0, 0.0), "hum", 460, 1840)
    to_gen(dial(p, "seed", "Seed", "Seed", [1548, 64, 44, 48], 0, 999, 1, ptype=1, unit=0), "seed", 600, 1840)
    p.comment("QUALITY", [1492, 116, 60, 14])
    to_gen(tab(p, "quality", "Quality", [1492, 132, 96, 16], ["1x", "2x", "4x"], 1), "quality", 40, 1870)
    p.comment("HUM HZ", [1600, 116, 60, 14])
    to_gen(tab(p, "hum_hz", "Hum Hz", [1600, 132, 68, 16], ["50", "60"], 0), "hum_hz", 200, 1870)

    apply_theme(p)
    add_panels(p)
    return {
        "patcher": {
            "fileversion": 1,
            "appversion": {"major": 8, "minor": 6, "revision": 0, "architecture": "x64", "modernui": 1},
            "classnamespace": "box",
            "rect": [60, 80, 1300, 900],
            "openinpresentation": 1,
            "devicewidth": DEVICE_WIDTH,
            "default_fontsize": 10.0,
            "boxes": p.boxes,
            "lines": p.lines,
            "dependency_cache": [{"name": "seq_random.js", "bootpath": ".", "type": "TEXT", "implicit": 1}],
        }
    }


def main():
    code = build_genexpr()
    (HERE / "metal_perc.genexpr").write_text(code)
    patch = build_maxpat(code)
    (HERE / "metal_perc.maxpat").write_text(json.dumps(patch, indent=1, ensure_ascii=False))
    from tools.make_amxd import make_amxd
    (HERE / "Metal Perc.amxd").write_bytes(make_amxd((HERE / "metal_perc.maxpat").read_bytes()))
    print(f"metal_perc.genexpr: {len(code.splitlines())} Zeilen")
    print(f"metal_perc.maxpat:  {len(patch['patcher']['boxes'])} Objekte, {len(patch['patcher']['lines'])} Verbindungen")


if __name__ == "__main__":
    main()

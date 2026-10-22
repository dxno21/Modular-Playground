"""Baut aus der Presentation-Ansicht von metal_perc.maxpat eine HTML-Vorschau.

Farben, Schriften und Panels werden aus den Attributen im Patch übernommen.

    python3 tools/render_layout.py metal_perc.maxpat layout.html
"""
import json
import math
import sys

src, out = sys.argv[1], sys.argv[2]
p = json.load(open(src))["patcher"]
W = p["devicewidth"]
H = 169
NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def css(c, fallback="#888"):
    if not c:
        return fallback
    return f"rgba({round(c[0] * 255)},{round(c[1] * 255)},{round(c[2] * 255)},{c[3] if len(c) > 3 else 1})"


def fmt(v, vo):
    u = vo.get("parameter_unitstyle", 1)
    t = vo.get("parameter_type", 0)
    if u == 8:
        n = int(round(v))
        return NOTES[n % 12] + str(n // 12 - 2)
    if u == 7:
        return f"{v:+.0f} st"
    if u == 4:
        return f"{v:.1f} dB"
    if u == 2:
        return f"{v:.1f} ms" if v < 10 else f"{v:.0f} ms"
    if t == 1 or u == 0:
        return f"{int(v)}"
    return f"{v:.2f}"


panels, el = [], []
for wrapper in p["boxes"]:
    b = wrapper["box"]
    if not b.get("presentation"):
        continue
    x, y, w, h = b["presentation_rect"]
    mc = b["maxclass"]
    vo = b.get("saved_attribute_attributes", {}).get("valueof", {})
    init = (vo.get("parameter_initial") or [0])[0]
    font = b.get("fontname", "Ableton Sans Medium")
    fs = b.get("fontsize", 9)
    pos = f"left:{x}px;top:{y}px;width:{w}px;height:{h}px"
    if mc == "panel":
        border = f"border:1px solid {css(b.get('bordercolor'))};" if b.get("border") else ""
        panels.append(f'<div class="abs" style="{pos};box-sizing:border-box;background:{css(b.get("bgcolor"))};'
                      f'border-radius:{b.get("rounded", 0)}px;{border}"></div>')
    elif mc == "comment":
        bold = "font-weight:700;letter-spacing:.08em;" if "Bold" in font else ""
        el.append(f'<div class="abs txt" style="left:{x}px;top:{y}px;width:{w}px;color:{css(b.get("textcolor"))};'
                  f'font-size:{fs}px;{bold}">{b["text"]}</div>')
    elif mc == "live.dial":
        lo, hi = vo["parameter_mmin"], vo["parameter_mmax"]
        f = (init - lo) / (hi - lo) if hi > lo else 0
        small = b.get("showname") == 0
        d = min(w, h - (0 if small else 22)) - 2
        cx, cy = x + w / 2, y + (h / 2 if small else 11 + d / 2 + 1)
        r = d / 2 - 2

        def pt(a):
            return cx + r * math.cos(a), cy + r * math.sin(a)

        sx, sy = pt(math.radians(135))
        ex, ey = pt(math.radians(405))
        vx, vy = pt(math.radians(135 + 270 * f))
        svg = (f'<path d="M{sx},{sy} A{r},{r} 0 1 1 {ex},{ey}" fill="none" stroke="{css(b.get("activefgdialcolor"))}" '
               f'stroke-width="2.6" stroke-linecap="round"/>')
        if f > 0.001:
            svg += (f'<path d="M{sx},{sy} A{r},{r} 0 {1 if 270 * f > 180 else 0} 1 {vx},{vy}" fill="none" '
                    f'stroke="{css(b.get("activedialcolor"))}" stroke-width="2.6" stroke-linecap="round"/>')
        svg += (f'<line x1="{cx}" y1="{cy}" x2="{vx}" y2="{vy}" stroke="{css(b.get("activeneedlecolor"))}" '
                f'stroke-width="1.5" stroke-linecap="round"/>')
        el.append(f'<svg class="abs" style="left:0;top:0;overflow:visible" width="{W}" height="{H}">{svg}</svg>')
        if not small:
            tc = css(b.get("textcolor"))
            el.append(f'<div class="abs txt c" style="left:{x - 8}px;top:{y}px;width:{w + 16}px;color:{tc};'
                      f'font-size:{fs}px;opacity:.75">{vo["parameter_shortname"]}</div>')
            el.append(f'<div class="abs txt c" style="left:{x - 8}px;top:{y + h - 11}px;width:{w + 16}px;color:{tc};'
                      f'font-size:{fs}px">{fmt(init, vo)}</div>')
    elif mc in ("live.toggle", "live.button"):
        on = init and mc == "live.toggle"
        bg = css(b.get("activebgoncolor") if on else b.get("activebgcolor"))
        radius = "50%" if mc == "live.button" else "3px"
        el.append(f'<div class="abs" style="left:{x + 1}px;top:{y + 1}px;width:{w - 2}px;height:{h - 2}px;'
                  f'box-sizing:border-box;background:{bg};border:1px solid {css(b.get("bordercolor"))};'
                  f'border-radius:{radius}"></div>')
    elif mc == "live.tab":
        items = vo["parameter_enum"]
        sw = w / len(items)
        sel = int(init)
        cells = ""
        for i, it in enumerate(items):
            on = i == sel
            bg = css(b.get("activebgoncolor")) if on else "transparent"
            tc = css(b.get("activetextoncolor") if on else b.get("activetextcolor"))
            sep = f"border-left:1px solid {css(b.get('bordercolor'))};" if i else ""
            cells += (f'<div style="width:{sw}px;background:{bg};color:{tc};{sep}text-align:center;'
                      f'line-height:{h - 2}px;font-size:{min(fs, h - 5)}px">{it}</div>')
        el.append(f'<div class="abs" style="{pos};display:flex;box-sizing:border-box;overflow:hidden;'
                  f'background:{css(b.get("activebgcolor"))};border:1px solid {css(b.get("bordercolor"))};'
                  f'border-radius:3px">{cells}</div>')
    elif mc == "live.menu":
        el.append(f'<div class="abs txt" style="{pos};box-sizing:border-box;background:{css(b.get("activebgcolor"))};'
                  f'border:1px solid {css(b.get("bordercolor"))};border-radius:3px;color:{css(b.get("textcolor"))};'
                  f'font-size:{fs}px;line-height:{h - 2}px;padding-left:5px">{vo["parameter_enum"][int(init)]}'
                  f'<span style="position:absolute;right:4px;color:{css(b.get("activetricolor"))}">▾</span></div>')
    elif mc == "live.gain~":
        el.append(f'<div class="abs" style="{pos};display:flex;gap:3px;justify-content:center">'
                  f'<div class="m"></div><div class="m"></div></div>'
                  f'<div class="abs txt c" style="left:{x}px;top:{y + h - 1}px;width:{w}px;'
                  f'color:{css(b.get("textcolor"))};font-size:8.5px">0.0 dB</div>')

html = f"""<!doctype html><meta charset="utf-8"><style>
body{{margin:0;background:#0b0b0d;font-family:"Ableton Sans Medium",Inter,Helvetica,Arial,sans-serif}}
.dev{{position:relative;margin:8px;width:{W}px;border-radius:4px;overflow:hidden;box-shadow:0 0 0 1px #000}}
.hdr{{height:18px;background:#26282d;color:#d4d7dd;font-size:11px;line-height:18px;padding-left:24px;position:relative}}
.hdr:before{{content:"";position:absolute;left:7px;top:5px;width:8px;height:8px;border-radius:50%;background:#ffad38}}
.body{{position:relative;height:{H}px}}
.abs{{position:absolute}} .txt{{white-space:nowrap}} .c{{text-align:center}}
.m{{width:8px;height:100%;border-radius:2px;background:linear-gradient(#ff5c5c 0 6%,#ffd34d 6% 22%,#2ed3c4 22% 100%);
   opacity:.28}}
</style><div class="dev"><div class="hdr">Metal Perc</div><div class="body">{"".join(panels)}{"".join(el)}</div></div>"""
open(out, "w").write(html)

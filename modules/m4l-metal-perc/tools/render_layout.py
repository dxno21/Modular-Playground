"""Baut aus der Presentation-Ansicht von metal_perc.maxpat eine HTML-Vorschau im Live-Stil.

    python3 tools/render_layout.py metal_perc.maxpat layout.html
"""
import json, math, sys
src, out = sys.argv[1], sys.argv[2]
p = json.load(open(src))['patcher']
W = p['devicewidth']; H = 169; S = 2
el = []
def fmt(v, vo):
    u = vo.get('parameter_unitstyle', 1); t = vo.get('parameter_type', 0)
    if u == 8:
        n = int(round(v)); return ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][n%12]+str(n//12-2)
    if u == 7: return f"{v:+.0f} st"
    if u == 4: return f"{v:.1f} dB"
    if t == 1 or u == 0: return f"{int(v)}"
    return f"{v:.2f}"
for b in p['boxes']:
    b = b['box']
    if not b.get('presentation'): continue
    x, y, w, h = b['presentation_rect']; mc = b['maxclass']
    vo = b.get('saved_attribute_attributes', {}).get('valueof', {})
    init = (vo.get('parameter_initial') or [0])[0]
    if mc == 'comment':
        el.append(f'<div class="c" style="left:{x}px;top:{y}px;width:{w}px">{b["text"]}</div>')
    elif mc == 'live.dial':
        lo, hi = vo['parameter_mmin'], vo['parameter_mmax']; f = (init-lo)/(hi-lo) if hi>lo else 0
        small = b.get('showname') == 0
        d = min(w, h - (0 if small else 22)) - 2; cx = x + w/2; cy = y + (h/2 if small else 11 + d/2 + 1)
        r = d/2 - 2
        a0, a1 = math.radians(135), math.radians(135 + 270*f)
        def pt(a): return cx + r*math.cos(a), cy + r*math.sin(a)
        sx, sy = pt(a0); ex, ey = pt(math.radians(405)); vx, vy = pt(a1)
        large = 1 if 270*f > 180 else 0
        svg = f'<path d="M{sx},{sy} A{r},{r} 0 1 1 {ex},{ey}" class="track"/>'
        if f > 0.001:
            svg += f'<path d="M{sx},{sy} A{r},{r} 0 {large} 1 {vx},{vy}" class="val"/>'
        svg += f'<line x1="{cx}" y1="{cy}" x2="{vx}" y2="{vy}" class="needle"/>'
        el.append(f'<svg class="abs" style="left:0;top:0" width="{W}" height="{H}">{svg}</svg>')
        if not small:
            el.append(f'<div class="lbl" style="left:{x-6}px;top:{y}px;width:{w+12}px">{vo["parameter_shortname"]}</div>')
            el.append(f'<div class="num" style="left:{x-6}px;top:{y+h-11}px;width:{w+12}px">{fmt(init, vo)}</div>')
    elif mc == 'live.toggle':
        el.append(f'<div class="tog {"on" if init else ""}" style="left:{x}px;top:{y}px;width:{w-2}px;height:{h-2}px"></div>')
    elif mc == 'live.button':
        el.append(f'<div class="btn" style="left:{x}px;top:{y}px;width:{w-2}px;height:{h-2}px"></div>')
    elif mc == 'live.tab':
        items = vo['parameter_enum']; n = len(items); sw = w / n
        sel = 0 if b['varname'] == 'step_led' else int(init)
        cells = ''.join(f'<div class="cell {"sel" if i==sel else ""} {"led" if b["varname"]=="step_led" else ""}" style="width:{sw}px">{it}</div>' for i, it in enumerate(items))
        el.append(f'<div class="tab" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px">{cells}</div>')
    elif mc == 'live.menu':
        el.append(f'<div class="menu" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px">{vo["parameter_enum"][int(init)]}<span>▾</span></div>')
    elif mc == 'live.gain~':
        el.append(f'<div class="gain" style="left:{x}px;top:{y}px;width:{w}px;height:{h-6}px"><div class="m"></div><div class="m"></div><div class="tri"></div><div class="gv">0.0</div></div>')
html = f'''<!doctype html><meta charset="utf-8"><style>
body{{margin:0;background:#1e1e1e;font-family:Helvetica,Arial,sans-serif}}
.dev{{position:relative;margin:8px;width:{W}px;border-radius:3px;overflow:hidden;box-shadow:0 0 0 1px #111}}
.hdr{{height:18px;background:#5d5d5d;color:#eee;font-size:11px;line-height:18px;padding-left:22px;position:relative}}
.hdr:before{{content:"";position:absolute;left:6px;top:5px;width:8px;height:8px;border-radius:50%;background:#ffb532}}
.body{{position:relative;height:{H}px;background:#a4a4a4}}
.abs{{position:absolute}}
.c,.lbl,.num{{position:absolute;font-size:9.5px;color:#121212;white-space:nowrap}}
.lbl,.num{{text-align:center}} .num{{font-size:9px}}
.track{{fill:none;stroke:#5e5e5e;stroke-width:2.2}} .val{{fill:none;stroke:#ff9a00;stroke-width:2.2}} .needle{{stroke:#121212;stroke-width:1.4}}
.tog{{position:absolute;background:#c9c9c9;border:1px solid #5e5e5e}} .tog.on{{background:#ffb532}}
.btn{{position:absolute;background:#c9c9c9;border:1px solid #5e5e5e;border-radius:50%}}
.tab{{position:absolute;display:flex;border:1px solid #5e5e5e;box-sizing:border-box;background:#c9c9c9}}
.cell{{font-size:8.5px;text-align:center;line-height:14px;border-right:1px solid #8a8a8a;box-sizing:border-box;color:#121212}}
.cell.sel{{background:#ffb532}} .cell.led{{font-size:7.5px;line-height:12px}} .cell.led.sel{{background:#6bd36b}}
.menu{{position:absolute;box-sizing:border-box;border:1px solid #5e5e5e;background:#c9c9c9;font-size:9px;line-height:14px;padding-left:4px}}
.menu span{{position:absolute;right:3px}}
.gain{{position:absolute;display:flex;gap:2px;justify-content:center}}
.m{{width:7px;height:100%;background:linear-gradient(#ff4b4b 0 8%,#ffd24b 8% 25%,#5fd35f 25% 100%);opacity:.35;border:1px solid #444}}
.tri{{position:absolute;right:2px;top:18%;border-right:6px solid #121212;border-top:4px solid transparent;border-bottom:4px solid transparent}}
.gv{{position:absolute;bottom:-12px;font-size:9px}}
</style><div class="dev"><div class="hdr">Metal Perc</div><div class="body">{"".join(el)}</div></div>'''
open(out, 'w').write(html)

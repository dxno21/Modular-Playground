"""Übersetzt den gen~-Code (metal_perc.genexpr) in ein JavaScript-Modul für Web Audio.

    python3 tools/genexpr_to_js.py metal_perc.genexpr web/metal_perc_dsp.js

Unterstützt genau den GenExpr-Umfang, den dieses Modul nutzt: Funktionen, Param, History, Data,
if/else, for, Ein-/Ausgänge in1..inN / out1..outN und die verwendeten Operatoren.
Das Ergebnis exportiert createMetalPerc(sampleRate) -> { tick(ins, outs), set(name, value), params }.
"""
import re
import sys

BUILTINS = {
    "sin": "Math.sin", "cos": "Math.cos", "tan": "Math.tan", "tanh": "Math.tanh", "exp": "Math.exp",
    "pow": "Math.pow", "sqrt": "Math.sqrt", "abs": "Math.abs", "floor": "Math.floor",
    "min": "Math.min", "max": "Math.max",
}
HELPERS = """
const fract = (x) => x - Math.floor(x);
const wrap = (x, lo, hi) => { const r = hi - lo; return lo + (((x - lo) % r) + r) % r; };
const clamp = (x, lo, hi) => (x < lo ? lo : x > hi ? hi : x);
const mix = (a, b, t) => a + (b - a) * t;
const mtof = (n) => 440 * Math.pow(2, (n - 69) / 12);
const noise = () => Math.random() * 2 - 1;
const selector = (i, ...a) => { const k = Math.floor(i); return k >= 1 && k <= a.length ? a[k - 1] : 0; };
const peek = (d, i) => { const k = Math.floor(i); return k >= 0 && k < d.length ? d[k] : 0; };
const poke = (d, v, i) => { const k = Math.floor(i); if (k >= 0 && k < d.length) d[k] = v; };
"""
KEYWORDS = {"if", "else", "for", "return", "while"}
ASSIGN = re.compile(r"\b([A-Za-z_]\w*)\s*(?:\+=|-=|\*=|/=|(?<![<>=!])=(?!=))")


def strip_comments(src):
    return re.sub(r"//[^\n]*", "", src)


def take_block(src, start):
    """Gibt (Inhalt, Ende) des {...}-Blocks ab Index der öffnenden Klammer zurück."""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start + 1:i], i + 1
    raise ValueError("unbalancierte Klammern")


def translate_expr(code, rename):
    def repl(m):
        word = m.group(0)
        if word in rename:
            return rename[word]
        return BUILTINS.get(word, word)
    code = re.sub(r"\b[A-Za-z_]\w*\b(?=\s*\()", repl, code)  # Funktionsaufrufe
    return re.sub(r"\b[A-Za-z_]\w*\b(?!\s*\()", lambda m: rename.get(m.group(0), m.group(0)), code)


def locals_of(body, exclude):
    names = []
    for m in ASSIGN.finditer(body):
        n = m.group(1)
        if n not in exclude and n not in KEYWORDS and n not in names:
            names.append(n)
    return names


def transpile(src):
    src = strip_comments(src)
    funcs = []
    pos = 0
    head = re.compile(r"^([A-Za-z_]\w*)\(([^)]*)\)\s*\{", re.M)
    # Funktionen stehen vor den Deklarationen
    while True:
        m = head.search(src, pos)
        if not m or re.match(r"\s*(Param|History|Data)\b", src[pos:m.start()].strip() or "x"):
            break
        if src[pos:m.start()].strip():
            break
        body, end = take_block(src, m.end() - 1)
        funcs.append((m.group(1), [a.strip() for a in m.group(2).split(",") if a.strip()], body))
        pos = end
    rest = src[pos:]

    params, history, data = [], [], []
    for m in re.finditer(r"\bParam\s+(\w+)\s*\(([^)]*)\)\s*;", rest):
        args = [a.strip() for a in m.group(2).split(",")]
        default = float(args[0])
        lo = hi = None
        for a in args[1:]:
            k, v = a.split("=")
            if k.strip() == "min":
                lo = float(v)
            elif k.strip() == "max":
                hi = float(v)
        params.append((m.group(1), default, lo, hi))
    for m in re.finditer(r"\bHistory\s+(\w+)\s*\(([^)]*)\)\s*;", rest):
        history.append((m.group(1), m.group(2).strip()))
    for m in re.finditer(r"\bData\s+(\w+)\s*\(([^)]*)\)\s*;", rest):
        data.append((m.group(1), m.group(2).strip()))
    body = re.sub(r"\b(Param|History|Data)\s+\w+\s*\([^)]*\)\s*;", "", rest)

    rename = {"samplerate": "SR", "twopi": "TWOPI", "pi": "PI"}
    for i in range(1, 9):
        rename[f"in{i}"] = f"ins[{i - 1}]"
        rename[f"out{i}"] = f"outs[{i - 1}]"

    out = ["// Automatisch erzeugt aus metal_perc.genexpr von tools/genexpr_to_js.py – nicht von Hand editieren.",
           HELPERS.strip(), "", "export function createMetalPerc(sampleRate) {",
           "  const SR = sampleRate, PI = Math.PI, TWOPI = 2 * Math.PI;"]
    for name, args, fbody in funcs:
        loc = locals_of(fbody, set(args))
        out.append(f"  function {name}({', '.join(args)}) {{")
        if loc:
            out.append(f"    let {', '.join(loc)};")
        out.append(translate_expr(fbody, rename).rstrip())
        out.append("  }")
    out.append("  // Parameter")
    out.append("  const P = {")
    for n, d, lo, hi in params:
        out.append(f"    {n}: {{ value: {d}, min: {lo if lo is not None else 'null'}, max: {hi if hi is not None else 'null'} }},")
    out.append("  };")
    for n, d, lo, hi in params:
        out.append(f"  let {n} = {d};")
    out.append("  // Zustand")
    for n, init in history:
        out.append(f"  let {n} = {init};")
    for n, size in data:
        out.append(f"  const {n} = new Float64Array({size});")
    state = {n for n, _ in history} | {n for n, *_ in params} | {n for n, _ in data}
    loc = locals_of(body, state | set(rename))
    out.append("  function tick(ins, outs) {")
    if loc:
        out.append(f"    let {', '.join(loc)};")
    out.append(translate_expr(body, rename).rstrip())
    out.append("  }")
    out.append("  function set(name, v) {")
    out.append("    const p = P[name];")
    out.append("    if (!p) return false;")
    out.append("    if (p.min !== null && v < p.min) v = p.min;")
    out.append("    if (p.max !== null && v > p.max) v = p.max;")
    out.append("    p.value = v;")
    out.append("    switch (name) {")
    for n, *_ in params:
        out.append(f"      case '{n}': {n} = v; break;")
    out.append("    }")
    out.append("    return true;")
    out.append("  }")
    out.append("  return { tick, set, params: P };")
    out.append("}")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    src = open(sys.argv[1]).read()
    js = transpile(src)
    with open(sys.argv[2], "w") as f:
        f.write(js)
    print(f"{sys.argv[2]}: {len(js.splitlines())} Zeilen")

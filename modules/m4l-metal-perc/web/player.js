// Metal Perc im Browser: baut die Device-Oberfläche aus ui.json und steuert den AudioWorklet.
const NOTES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const SVGNS = 'http://www.w3.org/2000/svg';

const css = (c, fb = '#888') => (c ? `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${c[3] ?? 1})` : fb);

function fmt(v, vo) {
  const u = vo.parameter_unitstyle ?? 1;
  const t = vo.parameter_type ?? 0;
  if (vo.parameter_enum) return vo.parameter_enum[Math.round(v)] ?? '';
  if (u === 8) { const n = Math.round(v); return NOTES[((n % 12) + 12) % 12] + (Math.floor(n / 12) - 2); }
  if (u === 7) return `${v >= 0 ? '+' : ''}${v.toFixed(t === 1 ? 0 : 1)} st`;
  if (u === 4) return `${v.toFixed(1)} dB`;
  if (u === 2) return v < 10 ? `${v.toFixed(1)} ms` : `${v.toFixed(0)} ms`;
  if (t === 1 || u === 0) return `${Math.round(v)}`;
  return v.toFixed(2);
}

// 0.25 s Stille als WAV: läuft als <audio> mit und stellt iOS auf Medien-Wiedergabe um
function silentWavUrl() {
  const n = 2000, buf = new ArrayBuffer(44 + n), v = new DataView(buf);
  const str = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  str(0, 'RIFF'); v.setUint32(4, 36 + n, true); str(8, 'WAVEfmt '); v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, 8000, true); v.setUint32(28, 8000, true);
  v.setUint16(32, 1, true); v.setUint16(34, 8, true); str(36, 'data'); v.setUint32(40, n, true);
  for (let i = 0; i < n; i++) v.setUint8(44 + i, 128);
  return URL.createObjectURL(new Blob([buf], { type: 'audio/wav' }));
}

class Player {
  constructor(root, ui, presets) {
    this.root = root;
    this.ui = ui;
    this.presets = presets;
    this.controls = {};      // varname -> Control
    this.values = {};        // Parametername -> Wert (für den Start des Audio-Kontexts)
    this.node = null;
    this.ctx = null;
    this.playing = false;
    this.bpm = 130;
    this.resetCount = 0;
    this.midiFlip = 0;
    this.status = document.getElementById('status');
    this.build();
  }

  // ---------------------------------------------------------------- Oberfläche
  build() {
    const dev = document.createElement('div');
    dev.className = 'device';
    dev.style.width = `${this.ui.width}px`;
    dev.innerHTML = '<div class="dev-hdr">Metal Perc</div>';
    const body = document.createElement('div');
    body.className = 'dev-body';
    body.style.height = `${this.ui.height}px`;
    dev.appendChild(body);
    this.root.appendChild(dev);
    this.device = dev;
    for (const el of this.ui.elements) {
      const make = {
        'panel': () => this.panel(el), 'comment': () => this.comment(el), 'live.dial': () => new Dial(this, el),
        'live.toggle': () => new Toggle(this, el), 'live.button': () => new Button(this, el),
        'live.tab': () => new Tab(this, el), 'live.menu': () => new Menu(this, el), 'live.gain~': () => new Gain(this, el),
      }[el.cls];
      if (!make) continue;
      const c = make();
      if (c instanceof Control) {
        body.appendChild(c.node);
        this.controls[el.var] = c;
        if (el.param) this.values[el.param] = c.value;
      } else if (c) body.appendChild(c);
    }
    this.fit();
    window.addEventListener('resize', () => this.fit());
  }

  fit() {
    const avail = this.root.clientWidth;
    const scale = Math.max(0.6, Math.min(1, avail / (this.ui.width + 2)));
    this.device.style.zoom = scale;
  }

  panel(el) {
    const d = document.createElement('div');
    const [x, y, w, h] = el.rect;
    Object.assign(d.style, { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`,
      background: css(el.bgcolor), borderRadius: `${el.rounded || 0}px`, boxSizing: 'border-box',
      border: el.border ? `1px solid ${css(el.bordercolor)}` : 'none' });
    return d;
  }

  comment(el) {
    const d = document.createElement('div');
    const [x, y, w] = el.rect;
    const bold = (el.fontname || '').includes('Bold');
    Object.assign(d.style, { position: 'absolute', left: `${x}px`, top: `${y}px`, minWidth: `${w}px`, whiteSpace: 'nowrap',
      color: css(el.textcolor), fontSize: `${el.fontsize || 9}px`, fontWeight: bold ? '700' : '400',
      letterSpacing: bold ? '.08em' : '0', pointerEvents: 'none' });
    d.textContent = el.text;
    return d;
  }

  showStatus(c) {
    if (!this.status) return;
    this.status.textContent = `${c.el.vo.parameter_longname}: ${fmt(c.value, c.el.vo)}`;
  }

  // ---------------------------------------------------------------- Werte -> Audio
  changed(c) {
    const el = c.el;
    this.showStatus(c);
    if (el.var === 'out_gain') return this.post({ type: 'gain', value: Math.pow(10, c.value / 20) });
    if (el.param) {
      this.values[el.param] = c.value;
      this.post({ type: 'set', name: el.param, value: c.value });
    }
    // Im Browser gibt es kein Live: der BPM-Regler im Device ist zugleich das Tempo für Clock = Host
    if (el.param === 'bpm') {
      this.bpm = c.value;
      const f = document.getElementById('bpm');
      if (f) f.value = Math.round(c.value);
      this.post({ type: 'transport', playing: this.playing, bpm: this.bpm });
    }
  }

  pressed(c) {
    const actions = {
      reset: () => this.setParam('reset_id', ++this.resetCount),
      rand_steps: () => this.randSteps(), rand_vel: () => this.randVel(), rand_pitch: () => this.randPitch(),
      clear: () => this.clearPattern(),
    };
    (actions[c.el.var] || (() => {}))();
  }

  setParam(name, value) {
    this.values[name] = value;
    this.post({ type: 'set', name, value });
  }

  post(msg) {
    if (this.node) this.node.port.postMessage(msg);
  }

  setControl(varname, v) {
    const c = this.controls[varname];
    if (c) c.set(v, true);
  }

  getControl(varname) {
    return this.controls[varname] ? this.controls[varname].value : 0;
  }

  // Randomizer wie seq_random.js
  randSteps() {
    const d = this.getControl('density');
    for (let i = 1; i <= 16; i++) this.setControl(`s${i}_on`, Math.random() < d ? 1 : 0);
  }
  randVel() {
    const r = this.getControl('vel_range');
    for (let i = 1; i <= 16; i++) this.setControl(`s${i}_vel`, 1 - r * Math.random());
  }
  randPitch() {
    const r = this.getControl('pitch_range');
    for (let i = 1; i <= 16; i++) this.setControl(`s${i}_pitch`, Math.round((Math.random() * 2 - 1) * r));
  }
  clearPattern() {
    for (let i = 1; i <= 16; i++) {
      this.setControl(`s${i}_on`, 1);
      this.setControl(`s${i}_vel`, 1);
      this.setControl(`s${i}_pitch`, 0);
      this.setControl(`s${i}_rtrg`, 0);
    }
  }

  // ---------------------------------------------------------------- Presets
  applyPreset(name) {
    const p = this.presets[name];
    if (!p) return;
    for (const c of Object.values(this.controls)) if (c.el.param && c.el.var !== 'step_led') c.set(c.init, true);
    for (const [k, v] of Object.entries(p.params)) {
      if (k === 'bpm') continue;
      if (this.controls[k]) this.setControl(k, v);
      else this.setParam(k, v);
    }
    p.on.forEach((v, i) => this.setControl(`s${i + 1}_on`, v));
    p.vel.forEach((v, i) => this.setControl(`s${i + 1}_vel`, v));
    p.pitch.forEach((v, i) => this.setControl(`s${i + 1}_pitch`, v));
    (p.rtrg || []).forEach((v, i) => this.setControl(`s${i + 1}_rtrg`, v));
    this.setControl('clock_mode', 0);
    if (p.params.bpm) this.setBpm(p.params.bpm);
  }

  // ---------------------------------------------------------------- Transport
  setBpm(bpm) {
    this.bpm = Math.max(40, Math.min(300, bpm));
    const f = document.getElementById('bpm');
    if (f) f.value = this.bpm;
    if (this.controls.bpm) this.controls.bpm.set(this.bpm, false);
    this.setParam('bpm', this.bpm);
    this.post({ type: 'transport', playing: this.playing, bpm: this.bpm });
  }

  // Muss synchron im Klick/Tipp laufen: Mobile Browser geben Audio nur direkt in der Geste frei.
  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) throw new Error('Dieser Browser unterstützt kein Web Audio.');
      this.ctx = new AC({ latencyHint: 'playback' });
      // iOS: Wiedergabe-Kategorie wählen, damit der Lautlos-Schalter Web Audio nicht stummschaltet
      try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch (e) { /* ältere Safari */ }
      this.silent = new Audio(silentWavUrl());
      this.silent.loop = true;
      this.silent.setAttribute('playsinline', '');
    }
    if (this.ctx.state !== 'running') this.ctx.resume();
    const buf = this.ctx.createBuffer(1, 1, this.ctx.sampleRate);
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    src.connect(this.ctx.destination);
    src.start(0);
    if (this.silent) this.silent.play().catch(() => {});
  }

  async start() {
    this.unlock();
    if (this.node) return;
    if (!this.loading) this.loading = this.load();
    await this.loading;
  }

  async load() {
    try {
      if (!this.ctx.audioWorklet) throw new Error('AudioWorklet fehlt: neueren Browser verwenden (Safari ab 14.5, Chrome, Firefox) und die Seite über https öffnen.');
      await this.ctx.audioWorklet.addModule('worklet.js');
      this.node = new AudioWorkletNode(this.ctx, 'metal-perc', { outputChannelCount: [2] });
      this.node.connect(this.ctx.destination);
      // Auf Touch-Geräten mit 1x Oversampling starten, das spart CPU
      if (window.matchMedia('(pointer: coarse)').matches && this.getControl('quality') > 0) this.setControl('quality', 0);
      for (const [k, v] of Object.entries(this.values)) this.post({ type: 'set', name: k, value: v });
      this.post({ type: 'gain', value: Math.pow(10, this.getControl('out_gain') / 20) });
      this.post({ type: 'transport', playing: this.playing, bpm: this.bpm });
      this.overloads = 0;
      this.node.port.onmessage = (e) => {
        const m = e.data;
        if (m.step !== undefined && this.controls.step_led) this.controls.step_led.set(m.step, false);
        if (this.controls.out_gain) this.controls.out_gain.meter(m.meter);
        if (m.load !== undefined) this.watchLoad(m.load);
      };
      this.notice(`Audio läuft (${this.ctx.sampleRate} Hz).`);
    } catch (err) {
      this.notice(`Audio konnte nicht starten: ${err.message || err}`, true);
      throw err;
    }
  }

  // CPU-Last des Worklets: bei Überlast Oversampling automatisch reduzieren
  watchLoad(load) {
    const cpu = document.getElementById('cpu');
    if (cpu) cpu.textContent = `CPU ${Math.round(load * 100)} %`;
    this.overloads = load > 0.85 ? this.overloads + 1 : 0;
    const q = this.getControl('quality');
    if (this.overloads >= 3 && q > 0) {
      this.setControl('quality', q - 1);
      this.overloads = 0;
      this.notice(`CPU-Last zu hoch: Quality automatisch auf ${['1x', '2x', '4x'][q - 1]} reduziert.`);
    }
  }

  notice(text, isError = false) {
    const n = document.getElementById('notice');
    if (!n) return;
    n.textContent = text;
    n.className = isError ? 'notice err' : 'notice';
  }

  async toggle() {
    await this.start();
    this.playing = !this.playing;
    this.post({ type: 'transport', playing: this.playing, bpm: this.bpm });
    document.getElementById('play').classList.toggle('on', this.playing);
    document.getElementById('play').textContent = this.playing ? '■ Stop' : '▶ Play';
  }

  async noteOn(note, vel) {
    await this.start();
    this.setParam('midi_note', note);
    this.setParam('midi_vel', vel);
    this.setParam('midi_id', ++this.midiFlip);
  }

  async enableMidi() {
    if (!navigator.requestMIDIAccess) {
      alert('Dieser Browser unterstützt kein Web MIDI (Chrome oder Edge verwenden).');
      return;
    }
    const access = await navigator.requestMIDIAccess();
    const bind = () => access.inputs.forEach((inp) => {
      inp.onmidimessage = (e) => {
        const [st, d1, d2] = e.data;
        if ((st & 0xf0) === 0x90 && d2 > 0) this.noteOn(d1, d2);
      };
    });
    bind();
    access.onstatechange = bind;
    const b = document.getElementById('midi');
    b.textContent = `MIDI an (${access.inputs.size})`;
    b.classList.add('on');
  }
}

// -------------------------------------------------------------------- Controls
class Control {
  constructor(player, el) {
    this.player = player;
    this.el = el;
    const vo = el.vo || {};
    this.min = vo.parameter_enum ? 0 : (vo.parameter_mmin ?? 0);
    this.max = vo.parameter_enum ? vo.parameter_enum.length - 1 : (vo.parameter_mmax ?? 1);
    this.int = !!vo.parameter_enum || vo.parameter_type === 1;
    this.init = (vo.parameter_initial || [0])[0];
    this.value = this.init;
    const [x, y, w, h] = el.rect;
    this.node = document.createElement('div');
    Object.assign(this.node.style, { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px` });
    this.node.title = vo.parameter_longname || '';
    this.node.addEventListener('pointerenter', () => player.showStatus(this));
  }
  set(v, emit) {
    v = Math.max(this.min, Math.min(this.max, v));
    if (this.int) v = Math.round(v);
    this.value = v;
    this.draw();
    if (emit) this.player.changed(this);
  }
  draw() {}
}

class Dial extends Control {
  constructor(player, el) {
    super(player, el);
    this.small = el.showname === 0;
    this.node.style.cursor = 'ns-resize';
    this.node.style.touchAction = 'none';
    this.svg = document.createElementNS(SVGNS, 'svg');
    this.svg.setAttribute('width', el.rect[2]);
    this.svg.setAttribute('height', el.rect[3]);
    this.svg.style.overflow = 'visible';
    this.node.appendChild(this.svg);
    if (!this.small) {
      this.label = this.text(0, el.vo.parameter_shortname, 0.75);
      this.num = this.text(el.rect[3] - 11, '', 1);
    }
    let startY = 0, startV = 0;
    const move = (e) => {
      const span = this.max - this.min;
      const sens = e.shiftKey ? 1000 : 200;
      const raw = startV + (startY - e.clientY) / sens * span;
      this.set(this.int ? raw : raw, true);
    };
    this.node.addEventListener('pointerdown', (e) => {
      startY = e.clientY; startV = this.value;
      this.node.setPointerCapture(e.pointerId);
      this.node.addEventListener('pointermove', move);
    });
    this.node.addEventListener('pointerup', (e) => {
      this.node.releasePointerCapture(e.pointerId);
      this.node.removeEventListener('pointermove', move);
    });
    this.node.addEventListener('dblclick', () => this.set(this.init, true));
    this.node.addEventListener('wheel', (e) => {
      e.preventDefault();
      const step = this.int ? 1 : (this.max - this.min) / 100;
      this.set(this.value - Math.sign(e.deltaY) * step, true);
    }, { passive: false });
    this.draw();
  }
  text(top, s, opacity) {
    const t = document.createElement('div');
    const w = this.el.rect[2];
    Object.assign(t.style, { position: 'absolute', left: '-10px', width: `${w + 20}px`, top: `${top}px`, textAlign: 'center',
      fontSize: `${this.el.fontsize || 9}px`, color: css(this.el.textcolor), opacity, pointerEvents: 'none', whiteSpace: 'nowrap' });
    t.textContent = s;
    this.node.appendChild(t);
    return t;
  }
  draw() {
    const [, , w, h] = this.el.rect;
    const f = this.max > this.min ? (this.value - this.min) / (this.max - this.min) : 0;
    const d = Math.min(w, h - (this.small ? 0 : 22)) - 2;
    const cx = w / 2, cy = this.small ? h / 2 : 11 + d / 2 + 1, r = d / 2 - 2;
    const pt = (a) => [cx + r * Math.cos(a), cy + r * Math.sin(a)];
    const rad = (deg) => (deg * Math.PI) / 180;
    const [sx, sy] = pt(rad(135)), [ex, ey] = pt(rad(405)), [vx, vy] = pt(rad(135 + 270 * f));
    const large = 270 * f > 180 ? 1 : 0;
    this.svg.innerHTML =
      `<path d="M${sx},${sy} A${r},${r} 0 1 1 ${ex},${ey}" fill="none" stroke="${css(this.el.activefgdialcolor)}" stroke-width="2.6" stroke-linecap="round"/>` +
      (f > 0.001 ? `<path d="M${sx},${sy} A${r},${r} 0 ${large} 1 ${vx},${vy}" fill="none" stroke="${css(this.el.activedialcolor)}" stroke-width="2.6" stroke-linecap="round"/>` : '') +
      `<line x1="${cx}" y1="${cy}" x2="${vx}" y2="${vy}" stroke="${css(this.el.activeneedlecolor)}" stroke-width="1.5" stroke-linecap="round"/>`;
    if (this.num) this.num.textContent = fmt(this.value, this.el.vo);
  }
}

class Toggle extends Control {
  constructor(player, el) {
    super(player, el);
    this.box = document.createElement('div');
    Object.assign(this.box.style, { position: 'absolute', inset: '1px', borderRadius: '3px', cursor: 'pointer', boxSizing: 'border-box',
      border: `1px solid ${css(el.bordercolor)}` });
    this.node.appendChild(this.box);
    this.node.addEventListener('click', () => this.set(this.value ? 0 : 1, true));
    this.draw();
  }
  draw() { this.box.style.background = css(this.value ? this.el.activebgoncolor : this.el.activebgcolor); }
}

class Button extends Control {
  constructor(player, el) {
    super(player, el);
    this.box = document.createElement('div');
    Object.assign(this.box.style, { position: 'absolute', inset: '1px', borderRadius: '50%', cursor: 'pointer', boxSizing: 'border-box',
      border: `1px solid ${css(el.bordercolor)}`, background: css(el.activebgcolor), transition: 'background .15s' });
    this.node.appendChild(this.box);
    this.node.addEventListener('click', () => {
      this.box.style.background = css(el.activebgoncolor);
      setTimeout(() => { this.box.style.background = css(el.activebgcolor); }, 150);
      player.pressed(this);
    });
  }
}

class Tab extends Control {
  constructor(player, el) {
    super(player, el);
    const items = el.vo.parameter_enum;
    Object.assign(this.node.style, { display: 'flex', boxSizing: 'border-box', overflow: 'hidden', borderRadius: '3px',
      background: css(el.activebgcolor), border: `1px solid ${css(el.bordercolor)}` });
    this.cells = items.map((it, i) => {
      const c = document.createElement('div');
      Object.assign(c.style, { flex: '1', textAlign: 'center', lineHeight: `${el.rect[3] - 2}px`,
        fontSize: `${Math.min(el.fontsize || 9, el.rect[3] - 5)}px`, cursor: el.var === 'step_led' ? 'default' : 'pointer',
        borderLeft: i ? `1px solid ${css(el.bordercolor)}` : 'none', userSelect: 'none' });
      c.textContent = it;
      if (el.var !== 'step_led') c.addEventListener('click', () => this.set(i, true));
      this.node.appendChild(c);
      return c;
    });
    this.draw();
  }
  draw() {
    this.cells.forEach((c, i) => {
      const on = i === this.value;
      c.style.background = on ? css(this.el.activebgoncolor) : 'transparent';
      c.style.color = css(on ? this.el.activetextoncolor : this.el.activetextcolor);
    });
  }
}

class Menu extends Control {
  constructor(player, el) {
    super(player, el);
    const s = document.createElement('select');
    Object.assign(s.style, { width: '100%', height: '100%', background: css(el.activebgcolor), color: css(el.textcolor),
      border: `1px solid ${css(el.bordercolor)}`, borderRadius: '3px', fontSize: `${el.fontsize || 9}px`, padding: '0 3px' });
    el.vo.parameter_enum.forEach((it, i) => s.add(new Option(it, i)));
    s.addEventListener('change', () => this.set(+s.value, true));
    this.sel = s;
    this.node.appendChild(s);
    this.draw();
  }
  draw() { if (this.sel) this.sel.value = this.value; }
}

class Gain extends Control {
  constructor(player, el) {
    super(player, el);
    this.node.style.cursor = 'ns-resize';
    this.node.style.touchAction = 'none';
    this.node.innerHTML = '<div class="gm"><div class="gl"></div></div><div class="gm"><div class="gl"></div></div><div class="gh"></div><div class="gv"></div>';
    this.levels = this.node.querySelectorAll('.gl');
    this.handle = this.node.querySelector('.gh');
    this.label = this.node.querySelector('.gv');
    let startY = 0, startV = 0;
    const move = (e) => this.set(startV + (startY - e.clientY) / 150 * (this.max - this.min), true);
    this.node.addEventListener('pointerdown', (e) => { startY = e.clientY; startV = this.value; this.node.setPointerCapture(e.pointerId); this.node.addEventListener('pointermove', move); });
    this.node.addEventListener('pointerup', () => this.node.removeEventListener('pointermove', move));
    this.node.addEventListener('dblclick', () => this.set(0, true));
    this.draw();
  }
  draw() {
    const f = (this.value - this.min) / (this.max - this.min);
    this.handle.style.bottom = `${f * 100}%`;
    this.label.textContent = `${this.value.toFixed(1)} dB`;
  }
  meter(peak) {
    const db = 20 * Math.log10(Math.max(peak, 1e-6));
    const f = Math.max(0, Math.min(1, (db + 60) / 66));
    this.levels.forEach((l) => { l.style.height = `${f * 100}%`; });
  }
}

// -------------------------------------------------------------------- Start
async function main() {
  const [ui, presets] = await Promise.all([fetch('ui.json').then((r) => r.json()), fetch('presets.json').then((r) => r.json())]);
  const player = new Player(document.getElementById('rack'), ui, presets);
  const sel = document.getElementById('preset');
  Object.keys(presets).forEach((n) => sel.add(new Option(n, n)));
  sel.addEventListener('change', () => { if (sel.value) player.applyPreset(sel.value); });
  document.getElementById('play').addEventListener('click', () => player.toggle().catch(() => {}));
  document.getElementById('bpm').addEventListener('change', (e) => player.setBpm(+e.target.value));
  document.getElementById('midi').addEventListener('click', () => player.enableMidi());
  const hit = document.getElementById('hit');
  // click statt pointerdown: iOS gibt Audio nur bei click/touchend frei
  hit.addEventListener('click', () => player.noteOn(60, 110).catch(() => {}));
  const keys = 'awsedftgyhujk';
  window.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.repeat) return;
    if (e.code === 'Space') { e.preventDefault(); player.toggle(); return; }
    const i = keys.indexOf(e.key.toLowerCase());
    if (i >= 0) player.noteOn(60 + i, 110);
  });
}

main();

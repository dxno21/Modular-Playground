// AudioWorklet für Metal Perc. build_site.py setzt hier den aus gen~ übersetzten DSP ein.
/*DSP*/

class MetalPercProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.dsp = createMetalPerc(sampleRate);
    this.ins = [0, 0, 0, 0, 0];
    this.outs = [0, 0, 0, 0];
    this.gain = 1;
    this.playing = false;
    this.bpm = 130;
    this.phase = 0;
    this.lastStep = -1;
    this.meter = 0;
    this.meterCount = 0;
    this.port.onmessage = (e) => {
      const m = e.data;
      if (m.type === 'set') this.dsp.set(m.name, m.value);
      else if (m.type === 'gain') this.gain = m.value;
      else if (m.type === 'transport') {
        if (m.playing && !this.playing) this.phase = 0;
        this.playing = m.playing;
        this.bpm = m.bpm;
      }
    };
  }

  process(inputs, outputs) {
    const t0 = Date.now();
    const out = outputs[0];
    const L = out[0];
    const R = out[1] || out[0];
    const ins = this.ins, outs = this.outs, dsp = this.dsp;
    const inc = this.bpm / 60 / sampleRate;
    let peak = 0;
    for (let i = 0; i < L.length; i++) {
      // Host-Beat-Phase wie plugphasor~: läuft nur, wenn der Transport spielt
      if (this.playing) this.phase = (this.phase + inc) % 1;
      ins[0] = this.playing ? this.phase : 0;
      dsp.tick(ins, outs);
      const y = outs[0] * this.gain;
      L[i] = y;
      R[i] = y;
      const a = Math.abs(y);
      if (a > peak) peak = a;
    }
    if (peak > this.meter) this.meter = peak;
    // Rechenzeit gegenüber der verfügbaren Blockzeit (Date.now hat ms-Auflösung, daher über viele Blöcke gemittelt)
    this.busy = (this.busy || 0) + (Date.now() - t0);
    this.blocks = (this.blocks || 0) + 1;
    let load;
    if (this.blocks >= 344) {
      load = this.busy / (this.blocks * L.length / sampleRate * 1000);
      this.busy = 0;
      this.blocks = 0;
    }
    if (++this.meterCount >= 8 || load !== undefined) {
      const step = Math.round(outs[2]);
      this.port.postMessage({ step: step !== this.lastStep ? step : undefined, meter: this.meter, load });
      this.lastStep = step;
      this.meter = 0;
      this.meterCount = 0;
    }
    return true;
  }
}

registerProcessor('metal-perc', MetalPercProcessor);

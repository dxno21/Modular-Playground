// seq_random.js – Randomizer für den Step-Sequencer von m4l-metal-perc.
// Schreibt neue Werte direkt in die Step-Regler. Die Regler geben die Werte
// selbst an gen~ weiter, bleiben sichtbar und werden mit dem Live-Set gespeichert.
autowatch = 1;
inlets = 1;
outlets = 0;

var STEPS = 16;

function getv(name) {
	var o = this.patcher.getnamed(name);
	if (!o) {
		post("seq_random: Objekt " + name + " fehlt\n");
		return 0;
	}
	var v = o.getvalueof();
	return (v instanceof Array) ? v[0] : v;
}

function setv(name, v) {
	var o = this.patcher.getnamed(name);
	if (o) {
		o.message("float", v);
	}
}

// Steps: jeder Step wird mit Wahrscheinlichkeit "Density" aktiv
function rand_steps() {
	var d = getv("density");
	for (var i = 1; i <= STEPS; i++) {
		setv("s" + i + "_on", Math.random() < d ? 1 : 0);
	}
}

// Velocity: zufällig zwischen (1 - Range) und 1
function rand_vel() {
	var r = getv("vel_range");
	for (var i = 1; i <= STEPS; i++) {
		setv("s" + i + "_vel", 1 - r * Math.random());
	}
}

// Pitch: ganze Halbtöne zwischen -Range und +Range (im Scale-Modus quantisiert gen~)
function rand_pitch() {
	var r = getv("pitch_range");
	for (var i = 1; i <= STEPS; i++) {
		setv("s" + i + "_pitch", Math.round((Math.random() * 2 - 1) * r));
	}
}

// ---------------- Sound-Randomizer
// Tabelle wird von build.py eingesetzt (Quelle: SOUND_RANDOM in build.py)
// @@SOUND_RANDOM_BEGIN
var SOUND_RANDOM = {"osc": {"voices": [2, 6, true], "spread": [0.4, 1.8, false], "detune": [0.0, 30.0, false], "tilt": [-0.8, 0.8, false], "pw": [0.15, 0.85, false], "fm_ratio": [0.5, 4.0, false], "fm_amt": [0.1, 0.9, false], "fm_fb": [0.0, 0.3, false], "ring": [0.0, 0.8, false], "sweep": [-7.0, 24.0, false], "sweep_time": [10.0, 150.0, false], "mod_wave": [0, 3, true]}, "voice": {"morph": [0.0, 1.0, false], "inharm": [0.0, 1.0, false], "attack": [0.5, 12.0, false], "decay": [0.12, 0.55, false], "damp": [0.1, 0.9, false], "bright": [0.2, 0.95, false], "drive": [0.0, 0.85, false], "noise_mix": [0.0, 0.2, false], "accent": [0.2, 0.9, false], "waveform": [0, 3, true]}};
// @@SOUND_RANDOM_END

// Amount (snd_amt): 0 = nichts, 0.3 = leichte Variation um den aktuellen Wert, 1 = komplett neu
function rand_group(group) {
	var a = getv("snd_amt");
	var t = SOUND_RANDOM[group];
	for (var name in t) {
		var lo = t[name][0], hi = t[name][1], isInt = t[name][2];
		var cur = getv(name);
		var v;
		if (isInt) {
			v = Math.random() < a ? lo + Math.floor(Math.random() * (hi - lo + 1)) : cur;
			setv_int(name, v);
		} else {
			v = cur + (lo + Math.random() * (hi - lo) - cur) * a;
			setv(name, v);
		}
	}
}

function rand_osc() {
	rand_group("osc");
}

function rand_voice() {
	rand_group("voice");
}

function rand_sound() {
	rand_group("osc");
	rand_group("voice");
}

function setv_int(name, v) {
	var o = this.patcher.getnamed(name);
	if (o) {
		o.message("int", v);
	}
}

// Alles zurück: alle Steps an, Velocity 1, Pitch 0, kein Retrig
function clear_pattern() {
	for (var i = 1; i <= STEPS; i++) {
		setv("s" + i + "_on", 1);
		setv("s" + i + "_vel", 1);
		setv("s" + i + "_pitch", 0);
		setv("s" + i + "_rtrg", 0);
	}
}

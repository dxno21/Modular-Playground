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

// Alles zurück: alle Steps an, Velocity 1, Pitch 0
function clear_pattern() {
	for (var i = 1; i <= STEPS; i++) {
		setv("s" + i + "_on", 1);
		setv("s" + i + "_vel", 1);
		setv("s" + i + "_pitch", 0);
	}
}

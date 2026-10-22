# m4l-metal-perc – Metallischer Percussion-Generator

Erstes Modul für das M4L-Rack (Variante A, siehe `KONZEPT.md`). Es ist eine Percussion-Voice mit
drei Klang-Engines, vier Wellenformen, einem 1-V/Oct-Quantizer und einem eingebauten 16-Step-Sequencer mit Randomizer.

> **Status:** Der Code wurde nicht in Max getestet, weil in der Entwicklungsumgebung kein Max/Live lief.
> Der Klang-Algorithmus ist über die Python-Referenz geprüft (`previews/*.wav`). Fehlermeldungen
> aus dem gen~-Compiler bitte melden (Max-Konsole, Zeilennummer). Sie lassen sich schnell beheben.

## Dateien

| Datei | Inhalt |
|---|---|
| `metal_perc.maxpat` | Fertiges Patch für das M4L-Device (generiert) |
| `metal_perc.genexpr` | gen~-DSP-Code, im Patch bereits eingebettet (generiert, zum Lesen) |
| `seq_random.js` | Randomizer, schreibt neue Werte in die Step-Regler |
| `src/metal_perc.genexpr.in` | **Quelle** des DSP-Codes. Hier editieren, dann `python3 build.py` |
| `build.py` | Erzeugt `.genexpr` und `.maxpat` (16 Steps, UI, Verkabelung) |
| `reference/metal_perc_ref.py` | Python-Nachbau des DSP für Hörproben ohne Max |
| `previews/*.wav` | Hörproben (aus der Python-Referenz gerendert) |

## In Ableton Live laden

1. In Live eine leere **Max Instrument**-Spur anlegen (*Max for Live → Max Instrument*) und den Editor öffnen.
2. Im Device-Editor zuerst die Standard-Objekte des neuen Devices löschen (`midiin`, `midiout`, `plugout~`).
   Dann `metal_perc.maxpat` öffnen (*File → Open*), dort alles auswählen (Cmd/Strg+A), kopieren und in den
   Device-Editor einfügen. In den Patcher-Einstellungen *Open in Presentation* aktivieren.
3. Das Device als `Metal Perc.amxd` speichern, und zwar **in denselben Ordner wie `seq_random.js`**.
   Alternativ die JS-Datei in den Ordner des Devices kopieren. Danach *Freeze Device*, damit das JS eingebettet wird.
4. Transport starten. Der Sequencer läuft synchron zu Live (Clock = *Host*).

## Bedienung

### Sequencer (links)
- **STEP:** An/Aus pro Step. Darüber läuft die Positionsanzeige.
- **VEL / PITCH:** Velocity- und Pitch-Poti pro Step (Pitch ±24 Halbtöne).
- **SEQ:** Sequencer an/aus. Bei *aus* spielt die Voice nur über MIDI-Noten oder den Ext-Trigger.
- **CLOCK:** *Host* (Live-Transport), *Ext* (Clock-Signal an Eingang 2) oder *Int* (eigenes Tempo **BPM**).
- **DIV:** 1/8, 1/16, 1/32, 1/8T, 1/16T. **LENGTH:** 1–16 Steps. **RESET:** zurück auf Step 1.

### Randomizer (Mitte), eine Zeile je Spur (Steps / Velocity / Pitch)
- **Rnd** (Knopf): würfelt die Step-Regler einmal neu. Das Ergebnis ist sichtbar, editierbar und wird gespeichert.
  - Steps: Jeder Step ist mit der Wahrscheinlichkeit **Density** aktiv.
  - Velocity: Zufallswert zwischen (1 − **Range**) und 1.
  - Pitch: ganze Halbtöne zwischen −**Range** und +**Range**.
- **Live** (Schalter): würfelt bei *jedem Schlag* neu, ohne die Regler zu verändern. Gut für hypnotische Variation.
  - Steps: Aktive Steps spielen nur mit der Wahrscheinlichkeit **Density**.
  - Velocity / Pitch: Abweichung innerhalb von **Range**.
- **Clear:** alle Steps an, Velocity 1, Pitch 0.

### Pitch (unten rechts)
- **PITCH MODE:** *Scale* rastet die Gesamttonhöhe (Tune + Step-Pitch + CV + MIDI) auf die gewählte Skala ein.
  *Loose* lässt sie stufenlos.
- **SCALE:** Chromatic, Minor, Phrygian, Harmonic Minor, Minor Pentatonic, Dorian, Phrygian Dominant, Hirajoshi.
- **ROOT:** Grundton der Skala.
- **1 V/Oct:** Signal-Eingang 4. Laut Rack-Konvention gilt ±1.0 = ±5 V, also entspricht 0.2 einer Oktave.
  Der Wert wird beim Trigger gehalten (Sample & Hold), wie bei Drum-Modulen üblich.

### Voice (rechts)
| Regler | Wirkung |
|---|---|
| **Tune** | Grundton (MIDI-Note 24–96) |
| **Wave** | Sine / Square / Saw / Triangle für alle Oszillatoren (Bank und FM). Square und Saw sind polyBLEP-bandbegrenzt |
| **Morph** | 0 = **Bank** (6 Oszillatoren, 808-Cymbal-Prinzip) → 0.5 = **FM/Ring** → 1 = **Resonator** (4 Moden, Rauschimpuls) |
| **Inharm** | 0 harmonisch → 0.5 808-Metall-Verhältnisse → 1 Membran/Glocke |
| **Decay** | 10 ms bis 2.5 s |
| **Damp** | Dämpfung der Resonator-Moden (nur Morph Richtung 1) |
| **Bright** | Filteröffnung (Bank) bzw. FM-Index |
| **Drive** | tanh-Sättigung, pegelkompensiert |
| **Noise** | Hochpass-Rauschen, mit der Hüllkurve geformt |
| **Accent** | Wie stark die Velocity Decay und Helligkeit beeinflusst |
| **Level** | Ausgangspegel |

Im Resonator-Modus (Morph = 1) wirkt **Wave** nicht, weil die Moden durch Rauschen angeregt werden.

### MIDI
MIDI-Noten aus Live-Clips triggern die Voice direkt. C3 (60) = Tune, andere Noten transponieren relativ dazu.
Die Velocity wird übernommen.

## Signal-Ein-/Ausgänge des gen~-Kerns (für die Rack-Matrix)

| | Signal |
|---|---|
| in1 | Host-Beat-Phase (`plugphasor~`) |
| in2 | Ext Clock (steigende Flanke = 1 Step) |
| in3 | Ext Reset |
| in4 | Pitch CV 1 V/Oct |
| in5 | Ext Trigger (umgeht den Sequencer) |
| out1 | Audio |
| out2 | Hüllkurve 0..1 (als Mod-Quelle) |
| out3 | aktueller Step 0..15 |
| out4 | Gate/Trigger-Out (5 ms) |

Im Device sind in2 bis in5 noch nicht belegt. Die Anschlüsse sind für die spätere Routing-Matrix vorgesehen.

## Hörproben (`previews/`)

| Datei | Einstellung |
|---|---|
| `01_bank_hats_square` | Bank, Square, kurze Decay: metallische Hats |
| `02_fm_clank_saw` | FM/Ring, Saw, Pitch-Steps: Industrial-Clank |
| `03_resonator_pipes_phrygian` | Resonator, Live-Pitch in D Phrygian: Rohre/Bleche |
| `04_industrial_drive_tri` | Bank→FM, Triangle, viel Drive und Noise, Live-Velocity |
| `05_hypnotic_random_sine` | FM→Resonator, Sine, Live-Steps und Live-Pitch (Moll-Pentatonik) |
| `06_waveforms_sine_square_saw_tri` | Derselbe Schlag nacheinander mit allen 4 Wellenformen |

Die Hörproben sind normalisiert. Neu rendern mit `python3 reference/metal_perc_ref.py`.

## Bekannte Grenzen
- **Host-Clock:** Der Sequencer zählt Beats ab dem Transport-Start. Wenn du mitten im Takt startest, beginnt
  das Pattern dort mit Step 1. Bei Bedarf hilft RESET.
- **Daisy-Port (oopsy):** Der DSP ist reines gen~ und damit portierbar. Die 80 Parameter brauchen auf
  Hardware aber ein eigenes Bedienkonzept.
- Das Layout ist funktional und noch nicht gestaltet.

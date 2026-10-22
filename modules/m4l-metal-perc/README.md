# m4l-metal-perc – Metallischer Percussion-Generator

Erstes Modul für das M4L-Rack (Variante A, siehe `KONZEPT.md`). Es ist eine Percussion-Voice mit
drei Klang-Engines, vier Wellenformen, einem 1-V/Oct-Quantizer und einem eingebauten 16-Step-Sequencer mit Randomizer.

> **Status:** Der Code wurde nicht in Max getestet, weil in der Entwicklungsumgebung kein Max/Live lief.
> Der Klang-Algorithmus ist über die Python-Referenz geprüft (`previews/*.wav`). Fehlermeldungen
> aus dem gen~-Compiler bitte melden (Max-Konsole, Zeilennummer). Sie lassen sich schnell beheben.

![Layout-Vorschau](layout.png)

*Layout-Vorschau, aus den Positionen im Patch gerendert (`tools/render_layout.py`). Es ist kein echter Max-Screenshot, in Live sieht es ähnlich aus.*

**Design:** Dark Mode mit einer Karte pro Sektion und einer Akzentfarbe je Bereich: SEQ Türkis, RANDOM Pink,
OSC Violett, VOICE Amber, CIRCUIT Rot, ANALOG Grün. Im Sequencer sind die Beats 1 und 3 leicht hinterlegt. Alle Farben stehen zentral in
`THEME` und `SECTIONS` in `build.py`. Dort ändern und `python3 build.py` ausführen, dann ist das ganze Device umgefärbt.
Die Farben sind fest gesetzt und folgen nicht dem Live-Theme.

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

### Oszillatoren (OSC, Mitte rechts)
| Regler | Wirkung |
|---|---|
| **Voices** | Anzahl aktiver Oszillatoren der Bank (1–6). Wenige klingen klarer und tonaler, viele dichter und metallischer |
| **Spread** | Abstand der Frequenzverhältnisse: 0 = alle auf dem Grundton, 1 = normal, 2 = doppelt so weit auseinander |
| **Detune** | Feste Verstimmung der Bank-Oszillatoren gegeneinander (0–50 Cent). Erzeugt Schwebungen |
| **Tilt** | Pegel der oberen Partials: − dunkel (Grundton dominiert), + hell (obere Oszillatoren lauter) |
| **PW** | Pulsbreite der Square-Welle (5–95 %). Schmale Pulse klingen nasal und dünn |
| **FM Ratio** | Frequenzverhältnis Modulator/Träger (0.5–8), unabhängig von Inharm. Ganze Zahlen klingen harmonisch, krumme Werte metallisch |
| **FM Amt** | FM-Index, also wie stark der Modulator den Träger verbiegt (folgt der Hüllkurve) |
| **FM FB** | Feedback des Modulators auf sich selbst. Von rau bis Rauschen |
| **Ring** | Mischung FM-Träger ↔ Ringmodulation |
| **Sweep / Sw Time** | Pitch-Hüllkurve: Tonhöhen-Sprung beim Anschlag (−24 bis +48 Halbtöne), der in Sw Time (1–500 ms) zurückläuft. Wirkt auf alle Engines |
| **Mod Wave** | Eigene Wellenform für den FM-Modulator |
| **Phase** | *Free*: Oszillatoren laufen frei, jeder Schlag klingt leicht anders. *Reset*: Phasen starten bei jedem Schlag neu, für einen gleichbleibenden, harten Anschlag |

### Voice (rechts)
| Regler | Wirkung |
|---|---|
| **Tune** | Grundton (MIDI-Note 24–96) |
| **Wave** | Sine / Square / Saw / Triangle für die Bank und den FM-Träger (Modulator: *Mod Wave*). Square und Saw sind polyBLEP-bandbegrenzt |
| **Morph** | 0 = **Bank** (6 Oszillatoren, 808-Cymbal-Prinzip) → 0.5 = **FM/Ring** → 1 = **Resonator** (4 Moden, Rauschimpuls) |
| **Inharm** | 0 harmonisch → 0.5 808-Metall-Verhältnisse → 1 Membran/Glocke |
| **Attack** | Anstiegszeit der Hüllkurve, 0.1–50 ms. Kleine Werte klingen hart und klickend, 3–10 ms weicher |
| **Decay** | 10 ms bis 2.5 s |
| **Damp** | Dämpfung der Resonator-Moden (nur Morph Richtung 1) |
| **Bright** | Filteröffnung der Bank und Helligkeit der Resonator-Anregung |
| **Drive** | tanh-Sättigung, pegelkompensiert |
| **Noise** | Hochpass-Rauschen, mit der Hüllkurve geformt |
| **Accent** | Wie stark die Velocity Decay und Helligkeit beeinflusst |
| **Level** | Ausgangspegel |

Im Resonator-Modus (Morph = 1) wirkt **Wave** nicht, weil die Moden durch Rauschen angeregt werden.

### Circuit (Schaltungs-Modelle)
| Regler | Wirkung |
|---|---|
| **Fold** | Wavefolder (West Coast): Die Welle faltet sich zurück, wenn sie zu laut wird. Erzeugt metallische Obertöne |
| **Asym** | Asymmetrische Sättigung wie bei Transistor oder Röhre. Erzeugt gerade Obertöne und klingt dadurch wärmer |
| **Bleed** | Dioden-Ringmodulator: Anteil der Diodenkennlinie und Durchschlag von Träger und Modulator |
| **LPG Col** | Filteranteil des Lowpass-Gates (0 = fast nur Lautstärke, 1 = volles Tiefpassfilter) |
| **Amp** | *VCA*: klassischer Verstärker. *LPG*: Buchla-artiges Lowpass-Gate mit Vactrol. Öffnet schnell, schließt langsam und nichtlinear: der typische „Plonk“ |
| **FM** | *Lin*: lineare FM (Phasenmodulation, sauber und stimmstabil). *Exp*: exponentielle FM wie bei analogen VCOs. Die Tonhöhe verschiebt sich mit der FM-Stärke |
| **Reso** | *Modal*: 4 Resonator-Moden, angeregt durch Rauschen. *Bridged-T*: das 808-Prinzip. Ein Impuls regt gesättigte Schwingkreise an, die Tonhöhe fällt mit der Amplitude („Boing“) |

### Analog
| Regler | Wirkung |
|---|---|
| **Analog** | Makro für alle Ungenauigkeiten: VCO-Drift, Bauteil-Toleranzen (Stimmung, PW, Gleichanteil, Flankensteilheit), Pitch-Jitter, gerade Obertöne in den Wellenformen, OTA-Sättigung der Filter, Toleranz der Filter-Cutoffs und Moden, Trigger-Jitter bis 0.4 ms, VCA-Bleed, Hüllkurven-Krümmung, Grundrauschen |
| **Age** | *Clean → Vintage → Worn*: mehr und schnellere Drift, weichere Flanken, mehr Bleed und Rauschen |
| **Sag** | Netzteil-Einbruch: Laute Schläge senken kurz Pegel und Tonhöhe. Ergibt einen natürlichen Pump-Effekt |
| **Hum / Hum Hz** | Netzbrumm mit 50 oder 60 Hz plus Obertönen. Standard aus |
| **Seed** | Charakter dieser Instanz. Jeder Wert ergibt andere Bauteil-Toleranzen, wie zwei Exemplare desselben Hardware-Moduls. Wird mit dem Set gespeichert |
| **Quality** | Oversampling 1× / 2× / 4× gegen Aliasing bei FM, Drive und Fold. 2× halbiert das Aliasing (gemessen 4.3 % → 2.2 %, 4×: 1.8 %). 4× kostet etwa die vierfache CPU-Last |

Bei Analog > 0 ist das Device nie ganz still: VCA-Bleed und Grundrauschen liegen bei etwa −67 dBFS, wie bei Hardware.
Für einen komplett digitalen, sauberen Klang Analog, Sag, Asym und Bleed auf 0 und Quality auf 1x stellen.

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
| `07_osc_sweep_feedback_pulse` | FM mit Pulse (PW 0.2), Saw-Modulator, viel Feedback, Pitch-Sweep +36, Phase Reset |
| `08_osc_bank_voices_spread_detune` | Bank mit 3 Oszillatoren, Spread 1.6, Detune 25 Cent, Tilt hell, PW 0.3 |
| `09_lowmid_fm_metal` | Preset *Low/Mid FM Metal* im Pattern (G Phrygian) |
| `10_lowmid_fm_metal_hits_G1_D2_G2` | Preset *Low/Mid FM Metal* als Einzelschläge auf G1, D2, G2 |
| `11_lpg_vactrol_fm_plonk` | Low/Mid FM Metal mit Lowpass-Gate (Vactrol) |
| `12_bridged_t_808_toms` | Resonator im Bridged-T-Modus: 808-artige Metall-Toms |
| `13_wavefolder_exp_fm` | Exponentielle FM und Wavefolder |
| `14_ab_digital_then_analog` | A/B-Vergleich: dasselbe Pattern erst komplett digital, nach kurzer Pause mit allen Analog-Bausteinen |

Alle Hörproben außer dem digitalen Teil von 14 laufen mit den Analog-Standardwerten (Analog 0.5, Age 0.3, Quality 2x). Die Hörproben sind normalisiert. Neu rendern mit `python3 reference/metal_perc_ref.py`.

## Preset: Low/Mid FM Metal

Tiefe bis mittlere FM-Percussion aus zwei Sinus-Oszillatoren: Ein Sinus-Modulator verbiegt einen Sinus-Träger.
Die FM Ratio 2.76 entspricht dem Obertonverhältnis eines schwingenden Metallstabs. Dadurch entstehen unharmonische,
metallische Seitenbänder über einem Grundton von G1 (~98 Hz). Etwa 60 % der Energie liegen unter 1 kHz.

| Bereich | Einstellung |
|---|---|
| Voice | Tune **43** (G1) · Morph **0.50** (reine FM) · Wave **Sin** · Attack **4 ms** · Decay **0.38** · Accent **0.60** · Drive **0.20** · Noise **0** · Level 0.80 |
| OSC | Mod Wave **Sin** · FM Ratio **2.76** · FM Amt **0.90** · FM FB **0** · Ring **0.70** · Sweep **+5 st** · Sw Time **40 ms** · Phase **Free** |
| Pitch | Mode **Scale** · Scale **Phrygian** · Root **G** |
| Circuit / Analog | Bleed **0.30** · Asym **0.30** · Analog **0.60** · Age **0.35** · Sag **0.30** · Quality 2x |
| Pattern | Steps `1001 0010 0100 1010` · Pitch +1 auf Step 4, −2 auf Step 10, +3 auf Step 13 · Velocity leicht akzentuiert |

**Gegen Klicks:**
- **Attack** 3–6 ms statt eines sofortigen Sprungs.
- **Phase Free**: Mit *Reset* springen die Phasen in einen noch klingenden Ausklang, das klickt.
- **Kürzerer Sweep**: wenig Halbtöne, langsam.

Gemessen (Transienten-Spitze über 5 kHz gegenüber dem Ausklang): vorher +21 dB, jetzt etwa 0 dB.

Varianten:
- **FM Ratio 3.53** klingt noch metallischer und glockiger.
- **FM Ratio 1.73** klingt tiefer und tonaler.
- **FM FB** ist die Hauptquelle von Rauschen. Für einen sauberen Klang auf 0 lassen, für Rauheit 0.2–0.4.
- **Attack 6–10 ms** macht den Anschlag noch weicher, eher Mallet-artig.

## Hypnotische Sequenzen 138 BPM (Low / Mid / High, Pitch Loose)

Drei Spuren, je ein Metal-Perc-Device. Pitch Mode steht auf **Loose**, die Tonhöhen sind also nicht quantisiert
(Mikro-Verstimmungen in Bruchteilen von Halbtönen). Die Spuren laufen **polymetrisch** mit 16, 14 und 15 Steps.
Sie verschieben sich ständig gegeneinander und treffen sich erst nach 210 Steps wieder.
Quelle: `reference/sequences_138.py`. Hörproben: `previews/seq138_low|mid|high.wav` (4 Takte) und
`seq138_mix_low_mid_high.wav` (8 Takte, alle drei zusammen).

Gemeinsam: Clock Host (Live auf 138 BPM), Div **1/16**, Pitch Mode **Loose**.

| | Low | Mid | High |
|---|---|---|---|
| Basis | Preset *Low/Mid FM Metal* | Preset *Low/Mid FM Metal* | eigene Einstellung |
| Tune | 38 (D1) | 50 (D2) | 79 (G4) |
| Length | 16 | 14 | 15 |
| Steps | `1000 0010 0010 1001` | `1010 0101 1001 01` | `1101 1011 1101 101` |
| Velocity (aktive Steps) | 1 · .8 · .9 · .7 · .6 | 1 · .55 · .8 · .5 · .9 · .6 · .7 | 1 · .45 · .7 · .9 · .5 · .65 · 1 · .4 · .75 · .85 · .55 |
| Pitch (aktive Steps, Halbtöne) | 0 · −0.7 · +0.35 · −1.3 · +0.5 | 0 · +2.5 · −1.2 · +4.3 · 0 · +1.7 · −2.6 | 0 · +0.4 · −0.6 · 0 · +1.1 · 0 · −0.3 · +0.8 · 0 · 0 · −1.0 |
| Klang | FM Amt 0.8, Decay 0.36 | Amp **LPG** (Col 0.7), FM Ratio 3.1, FM Amt 0.75, Ring 0.6, Decay 0.24 | Morph 0.15 (Bank), Square, Voices 5, Spread 1.2, Detune 12, Tilt 0.4, PW 0.35, Decay 0.1, Attack 1 ms, Bright 0.8, Noise 0.08 |
| Live-Random | Vel (Range 0.25), Pitch (Range 0.25) | Vel (0.35), Pitch (0.6) | Steps (Density 0.85), Vel (0.45), Pitch (1.5) |
| Mix-Fader | 0.8 | 0.8 | 1.6 |

Die Live-Randomisierung verändert Velocity und Tonhöhe bei jedem Schlag leicht. Das Pattern bleibt erkennbar,
wiederholt sich aber nie exakt.

## Main Layer im Mord-Stil (145 BPM)

Roh, dunkel, industriell: eine verzerrte FM-Rolle aus 16teln, die die Kick-Positionen (Steps 1/5/9/13) frei lässt.
Die Akzente liegen auf den Offbeats. Über 16 Takte fahren Fold, FM Amt und Decay hoch, wie Automation
im Track-Aufbau. Quelle: `reference/sequence_mord_main.py`. Hörproben: `previews/mord_main_layer.wav` (solo) und
`mord_main_with_ref_kick.wav` (mit einfacher Referenz-Kick, nur zur Orientierung).

| Bereich | Einstellung |
|---|---|
| Sequencer | Live auf **145 BPM**, Div 1/16, Length 16, Steps `0111 0111 0111 0111` |
| Velocity | `0 .55 1 .6 · 0 .55 1 .65 · 0 .6 1 .55 · 0 .7 1 .5`, Live Vel an (Range 0.2) |
| Pitch | Scale **Phrygian**, Root **A#/Bb**, Tune **46** (Bb2). Step 8 **+1**, Step 14 **−2**, Step 16 **+3** |
| Voice | Morph **0.50**, Wave **Sin**, Attack **3 ms**, Decay **0.18 → 0.30**, Accent **0.80**, Drive **0.85**, Noise 0, Level 0.8 |
| OSC | Mod Wave **Saw**, FM Ratio **2.76**, FM Amt **0.75 → 1.0**, FM FB **0.15**, Ring **0.40**, Sweep **+7 st / 30 ms**, Phase Free |
| Circuit | Fold **0.30 → 0.60**, Asym **0.50**, Bleed **0.40**, Amp VCA, FM **Lin** |
| Analog | Analog **0.70**, Age **0.50**, Sag **0.60**, Quality 2x |
| Automation | Fold, FM Amt und Decay linear über 16 Takte von Start- auf Endwert |

Energie (Spektrum, solo): etwa 20 % unter 120 Hz, 62 % zwischen 120 Hz und 1 kHz, 15–17 % zwischen 1 und 5 kHz.
Die Mitten tragen den Sound, und unten bleibt Platz für Kick und Rumble.

## Bekannte Grenzen
- **CPU:** Durch Oversampling und Analog-Modelle rechnet der Kern deutlich mehr als vorher. Bei Bedarf Quality auf 1x stellen.
- **Host-Clock:** Der Sequencer zählt Beats ab dem Transport-Start. Wenn du mitten im Takt startest, beginnt
  das Pattern dort mit Step 1. Bei Bedarf hilft RESET.
- **Daisy-Port (oopsy):** Der DSP ist reines gen~ und damit portierbar. Die 105 Parameter brauchen auf
  Hardware aber ein eigenes Bedienkonzept.
- Das Layout ist funktional und noch nicht gestaltet.

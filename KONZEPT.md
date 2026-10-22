# Modular Playground – Konzept

**Ziel:** Ein KI-gestütztes Tool, das Eurorack-Module für **Hypnotic- und Industrial-Techno** recherchiert, sie
digital in Ableton Live (Max for Live) testbar macht und daraus ein persönliches, kaufbares Rack ableitet.
Erst virtuell testen, dann gezielt Hardware kaufen. Die Patches sollen ohne Umbauen weiterlaufen.

---

## 1. Kernfrage: Lassen sich fertige Module aus dem Netz einbinden?

Ja, über mehrere Wege, die man kombinieren kann:

| Weg | Was es ist | Läuft in Live? | Nähe zur Hardware |
|---|---|---|---|
| **VCV Rack 2 Pro** | Virtuelles Eurorack, über 3000 Module, viele davon offizielle Umsetzungen echter Hersteller | Ja, als VST3/AU-Plugin | Sehr hoch (gleiche Patch-Logik, oft gleicher DSP-Code) |
| **Max for Live + `vst~`** | Ein M4L-Device kann VST-Plugins hosten und steuern | Ja (nativ) | Hängt vom geladenen Plugin ab |
| **Open-Source-Ports in Max** | z.B. Mutable-Instruments-Ports als Max-Externals (vb.mi-objects von Volker Böhm) | Ja (nativ in M4L) | Hoch (Originalcode) |
| **Hersteller-Plugins** | z.B. Noise Engineering (Ruina, Sinc Vereor …), Softube Modular (Doepfer, Intellijel …), Cherry Audio Voltage Modular | Ja | Hoch |
| **Eigene Nachbauten** | `gen~` / RNBO in Max | Ja | Nur annähernd, dafür 100 % eigen |

**Empfehlung:** VCV Rack 2 Pro als „virtuelles Rack“ im Live-Set. Darum herum M4L-Devices für Sequencing,
Modulation und Steuerung durch die KI.

### Offizielle bzw. originalgetreue Umsetzungen in VCV (Auswahl)
- **Mutable Instruments** (als „Audible Instruments“, Open-Source-Code): Plaits, Rings, Clouds, Marbles, Tides, Ripples, Elements …
- **Befaco**: Rampage, Even VCO, Kickall, Spring Reverb, Noise Plethora …
- **4ms**: Ensemble Oscillator, Spectral Multiband Resonator, Dual Looping Delay …
- Dazu Bogaudio, Vult, Surge XT, Valley u.v.m. als Ersatz bzw. Annäherung für andere Hardware.

---

## 2. Die Brücke Digital ↔ Hardware (der eigentliche Clou)

```
 Ableton Live
 ├── M4L-Sequencer / Modulatoren (KI-generierte Patterns)
 │      │
 │      ├──► VCV Rack Pro (Plugin)  ──► virtuelles Modul      [Testphase]
 │      │
 │      └──► CV Tools ──► DC-gekoppeltes Interface ──► echtes Modul [nach dem Kauf]
 │                       (z.B. Expert Sleepers ES-8/ES-9)
 └── Audio zurück in Live (Effekte, Resampling)
```

- **Ableton CV Tools** (kostenloses M4L-Pack) schickt CV/Gate/Clock über ein DC-gekoppeltes Audio-Interface ins Rack.
- Dieselben Sequenzen und Modulationen steuern erst das virtuelle und später das echte Modul. Man ersetzt
  Modul für Modul, das Set bleibt bestehen.
- **Eigene Module in Hardware:** `gen~`-Patches lassen sich mit *oopsy* auf **Electrosmith Daisy**
  (z.B. Patch.Init() im Eurorack-Format) flashen. Alternativ läuft eigener Code auf **Expert Sleepers Disting NT**
  (C++-Plugins / Lua). So wird der eigene Nachbau zu einem echten, einzigartigen Modul.

---

## 3. Das KI-Tool – Bausteine

### 3.1 Sound-Profil („Wie klinge ich?“)
- Input: eigene Tracks, Referenztracks, Stichworte („rollende Kick, metallische Hihats, dunkler Drone, Rauschen“).
- Audioanalyse (z.B. librosa / Essentia): Tempo, Spektrum, Transienten, Rhythmusdichte, Verzerrungsgrad, Stereobild.
- Ergebnis: Profil-Vektor, z.B. `{ kick_sub: hoch, metallisch: hoch, drift/generativ: mittel, raum: dunkel/groß }`.

### 3.2 Modul-Wissensbasis
Pro Modul: Funktion, Klangcharakter-Tags, HP, Stromverbrauch (+12 V / −12 V / 5 V), Preis, Verfügbarkeit,
**virtuelles Pendant** (VCV-Modul / Plugin / M4L-Port), Grad der Übereinstimmung (original / ähnlich / Ersatz).
> ModularGrid hat keine offizielle API. Die Daten müssen daher manuell oder halbautomatisch gepflegt werden.

### 3.3 Empfehlung und Patch-Generator
- Ordnet das Sound-Profil Modulrollen zu (Kick-Voice, Percussion, Drone, Modulation, Clock/Sequencing, FX, Dynamik).
- Erzeugt **VCV-Patches automatisch**: `.vcv` ist ein zstd-komprimiertes Archiv mit einer `patch.json`, lässt sich
  also generieren.
- Erzeugt passende M4L-Clips und Sequenzen (polymetrisch, Euclid, Wahrscheinlichkeiten). Genau das macht Hypnotic Techno aus.

### 3.4 Feedback-Schleife
- In Live testen, bewerten (z.B. über ein M4L-Device: 👍/👎 pro Patch oder Modul).
- Die KI lernt deine Vorlieben und schlägt die nächste Iteration vor.
- Am Ende steht ein **Rack-Planer**: Kaufreihenfolge nach „Nutzen pro Euro“, HP-Layout, Stromverbrauch.

---

## 4. Startkandidaten für Hypnotic / Industrial Techno

| Rolle | Hardware (Beispiele) | Digital testbar über |
|---|---|---|
| Kick / Percussion | Noise Engineering Basimilus Iteritas, Erica Synths Techno-Serie, Befaco Kickall | Befaco Kickall (VCV), Plaits-Drum-Modelle, eigener `gen~`-Kick |
| Metallisch / Resonanz | Mutable Rings, 4ms SMR | Audible „Resonator“, 4ms SMR (VCV) |
| Makro-Oszillator | Mutable Plaits, 4ms Ensemble Oscillator | Audible „Macro Oscillator 2“, 4ms EnOsc (VCV) |
| Generativ / hypnotisch | Mutable Marbles, Tides | Audible „Random Sampler“, „Tidal Modulator“ |
| Textur / Granular | Mutable Clouds/Beads, Instruō Arbhar | Audible „Texture Synthesizer“ |
| Funktionsgenerator | Make Noise Maths, Befaco Rampage | Befaco Rampage (VCV) |
| Noise / Industrial | Befaco Noise Plethora | Befaco Noise Plethora (VCV) |
| Verzerrung / Crush | Wavefolder, Bitcrusher, Ringmodulatoren | NE Ruina (Plugin), diverse VCV-Module |
| Raum | Befaco Spring Reverb, NE Desmodus Versio | Befaco Spring Reverb (VCV), Valley Plateau |

---

## 5. Roadmap

1. **MVP (ohne KI):** VCV Rack Pro in Live, CV Tools, 3–4 handgebaute Start-Patches (Kick-Rumble, Metall-Perc, Drone).
2. **Wissensbasis:** ca. 50 relevante Module mit Tags und virtuellem Pendant (JSON/CSV).
3. **Patch-Generator:** Skript erzeugt `.vcv`-Patches aus Modulliste und Rollen.
4. **Sound-Profil:** Audioanalyse eigener Tracks, Abgleich mit Wissensbasis.
5. **M4L-Integration:** Device für Bewertung, Patternsteuerung und Brücke zur KI.
6. **Rack-Planer und Hardware:** Kaufempfehlung; optional eigenes Modul auf Daisy / Disting NT.

## Offene Fragen
- Welche Live-Version (Suite = Max for Live enthalten)?
- Gibt es schon ein Eurorack-Case bzw. Module? Wie viel HP und welches Budget?
- Gibt es ein DC-gekoppeltes Audio-Interface (für CV aus Live)?
- Referenzkünstler und -tracks für das Sound-Profil?

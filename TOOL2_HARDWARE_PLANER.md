# Tool 2 – Hardware-Planer (Briefing für eine neue Code-Session)

> Dieses Dokument ist in sich abgeschlossen. Hintergrund und Gesamtidee stehen in `KONZEPT.md`.
> Tool 1 (das modulare Rack in Max for Live) wird separat entwickelt und nutzt **dasselbe Patch-Format** (Abschnitt 4).

## 1. Ziel

Eine Web-App, in der ich **echte Eurorack-Module recherchieren, in einem virtuellen Case anordnen und die
Verkabelung (Patches) planen** kann. Das Genre ist Hypnotic und Industrial Techno.
Die App soll Fehlkäufe verhindern: Erst planen und digital anhören (über Tool 1 / VCV), dann gezielt kaufen.

## 2. Kernfunktionen

### 2.1 Modul-Datenbank
- Pro Modul: Hersteller, Name, Funktion/Kategorie, Klang-Tags, HP, Tiefe (mm), Strom (+12 V / −12 V / +5 V in mA),
  Preis (ca., EUR), Status (erhältlich / eingestellt / gebraucht), Links (Hersteller, Handbuch).
- **Ein- und Ausgänge (Jacks)** mit Name, Typ (`audio`, `cv`, `gate`, `trigger`, `clock`, `pitch`) und Richtung.
- **Digitales Gegenstück:** VCV-Modul / Plugin / M4L-Modul aus Tool 1 / keins. Dazu der Übereinstimmungsgrad
  (`original` | `aehnlich` | `ersatz`).
- Startbestand: ca. 30–50 Module, die für das Genre relevant sind (Liste siehe `KONZEPT.md`, Abschnitt 4).
  Die Daten werden als JSON im Repo gepflegt. ModularGrid hat keine offizielle API, also nicht scrapen.

### 2.2 Case-Planer
- Cases konfigurieren: Reihen × HP (z.B. 2 × 84 HP) und Netzteil-Budget pro Schiene.
- Module per Drag & Drop in die Reihen, mit Kollisionsprüfung und freier HP-Anzeige.
- **Live-Anzeige:** belegte/freie HP, Stromverbrauch je Schiene gegen Budget (Warnung ab 80 %), Gesamtpreis.
- Mehrere Rack-Varianten speichern und vergleichen („Ist-Rack“, „Wunsch-Rack“).

### 2.3 Kabel-Editor (Patch-Planung)
- Ausgang anklicken, dann Eingang anklicken: Das Kabel wird als Kurve über dem Case gezeichnet, Farbe wählbar.
- Validierung: nur Ausgang → Eingang. Ein Eingang hat höchstens ein Kabel. Ein Ausgang darf mehrere haben,
  dann Hinweis „Mult nötig?“. Hinweis bei Typ-Mismatch, z.B. Audio in Clock.
- Mehrere Patches pro Rack. Jeder Patch hat Name, Beschreibung, Regler-Notizen und Tags.
- **Kabelliste** als Text bzw. Druckansicht („Marbles T1 → Rings STRUM“), dazu eine geschätzte Kabellänge
  nach Abstand und die Anzahl je Länge.

### 2.4 KI-Recherche (Phase 2)
- Eingabe: Stichworte zum Sound und/oder vorhandene Module. Ausgabe: Modulvorschläge mit Begründung und
  „Nutzen pro Euro“-Kaufreihenfolge.
- Die KI kann **Patches vorschlagen** und erzeugt dafür Patch-JSON nach Abschnitt 4.
- Umsetzung über die Claude API (aktuelles Modell). Der API-Key kommt nie in den Client-Code.

### 2.5 Export / Import
- Patch-JSON (gemeinsames Format, Abschnitt 4). Das ist der Austausch mit Tool 1.
- Später: Export als VCV-Rack-Patch (`.vcv` = zstd-komprimiertes Tar mit `patch.json`), nur für Module mit VCV-Gegenstück.

## 3. Datenmodell (Modul)

```json
{
  "id": "mutable-rings",
  "manufacturer": "Mutable Instruments",
  "name": "Rings",
  "category": ["resonator", "voice"],
  "tags": ["metallisch", "resonant", "physical-modeling"],
  "hp": 14,
  "depth_mm": 25,
  "power_ma": { "p12": 120, "m12": 5, "p5": 0 },
  "price_eur": 300,
  "status": "eingestellt",
  "jacks": [
    { "id": "in",    "label": "IN",    "dir": "in",  "type": "audio" },
    { "id": "strum", "label": "STRUM", "dir": "in",  "type": "trigger" },
    { "id": "voct",  "label": "V/OCT", "dir": "in",  "type": "pitch" },
    { "id": "odd",   "label": "ODD",   "dir": "out", "type": "audio" },
    { "id": "even",  "label": "EVEN",  "dir": "out", "type": "audio" }
  ],
  "digital": [
    { "kind": "vcv", "ref": "AudibleInstruments.Rings", "match": "original" }
  ],
  "links": { "manual": "" }
}
```
> Die Beispielwerte (Strom, Preis, Jacks) sind beim Befüllen gegen das Herstellerhandbuch zu prüfen.

## 4. Gemeinsames Patch-Format (verbindlich für Tool 1 und Tool 2)

```json
{
  "format": "modular-playground.patch",
  "version": 1,
  "name": "Metal Rumble 01",
  "description": "",
  "tags": ["hypnotic"],
  "modules": [
    { "instance": "m1", "module": "mutable-marbles", "row": 0, "x_hp": 0,  "params": { "rate": 0.4 } },
    { "instance": "m2", "module": "mutable-rings",   "row": 0, "x_hp": 18, "params": {} }
  ],
  "cables": [
    { "from": { "instance": "m1", "jack": "t1" }, "to": { "instance": "m2", "jack": "strum" }, "color": "#e5484d" }
  ],
  "notes": ""
}
```
- `module` verweist auf die `id` aus der Modul-Datenbank. Module aus Tool 1 haben das Präfix `m4l-` (z.B. `m4l-metal-perc`).
- `params`: Werte 0.0–1.0 (normalisiert). Gleiche Namen wie in Tool 1, damit die KI Patches in beiden Tools setzen kann.
- Signal-Konvention (aus Tool 1): ±1.0 = ±5 V, Pitch 1 V/Oct.
- Das Format lebt als JSON-Schema im Repo (`schema/patch.schema.json`) und wird von beiden Tools validiert.

## 5. Vorschlag Technik (nicht festgelegt)
- Frontend: Vite + React + TypeScript, Case und Kabel als SVG, Zustand im Browser (localStorage) plus JSON-Export.
- Daten: `data/modules/*.json` im Repo, validiert per JSON-Schema (z.B. mit Ajv) in einem Test.
- Kein Backend im MVP. Für die KI-Recherche später eine kleine Serverfunktion als Proxy zur Claude API.
- Tests: Vitest für Strom- und HP-Berechnung, Kabelvalidierung und Schema-Validierung.

## 6. MVP-Umfang (erste Session)
1. Repo-Struktur, JSON-Schemas für Modul und Patch.
2. 10–15 Startmodule als JSON (Mutable Plaits/Rings/Marbles/Clouds, Make Noise Maths, Befaco Rampage/Kickall,
   Noise Engineering Basimilus Iteritas, 4ms Ensemble Oscillator, Erica Synths Techno-Module …).
3. Case-Planer mit HP- und Strombudget.
4. Kabel-Editor mit Validierung und Kabelliste.
5. Patch-JSON-Export/-Import.

**Nicht im MVP:** KI-Recherche, VCV-Export, Accounts/Cloud-Sync, Preis-Scraping.

## 7. Offene Fragen an mich
- Vorhandenes Case (Reihen × HP, Netzteil) und vorhandene Module?
- Budget und Ziel-Größe des Racks?
- Soll die App auch auf dem Handy nutzbar sein (z.B. Kabelliste beim Patchen)?
- Deployment: nur lokal oder online (z.B. GitHub Pages)?

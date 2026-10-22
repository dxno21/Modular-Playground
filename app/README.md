# Tool 2 – Hardware-Planer (MVP)

Web-App zum Recherchieren von Eurorack-Modulen, Anordnen im Case und Planen der Verkabelung.
Briefing: [`../TOOL2_HARDWARE_PLANER.md`](../TOOL2_HARDWARE_PLANER.md).

```bash
cd app
npm install
npm run dev      # http://localhost:5173
npm test         # Vitest: Schema, HP/Strom, Kabelvalidierung, Patch-Import/-Export
npm run build    # statischer Build in app/dist (relativer base-Pfad, z.B. für GitHub Pages)
```

## Funktionen
- **Modul-Datenbank** (`../data/modules/*.json`, Schema `../schema/module.schema.json`): Suche, Kategorie-Filter, Details
  mit Strom, Jacks und digitalem Gegenstück.
- **Case-Planer**: Reihen × HP und Netzteil-Budget frei einstellbar. Module per Drag & Drop oder „+“ einsetzen,
  im Case verschieben (Kollisionen rasten auf den nächsten freien Platz). Live: HP frei/belegt, Strom je Schiene
  (Warnung ab 80 %), Gesamtpreis, max. Tiefe.
- **Rack-Varianten**: beliebig viele Racks (Ist-Rack, Wunsch-Rack …), duplizieren, vergleichen,
  Einkaufsliste „von Rack A nach Rack B“.
- **Kabel-Editor**: Ausgang anklicken, dann Eingang (Reihenfolge egal). Validierung: nur Ausgang → Eingang,
  ein Kabel pro Eingang, Hinweis „Mult nötig?“ und bei Typ-Mismatch. Farben, mehrere Patches pro Rack,
  Name/Beschreibung/Tags/Regler-Notizen und Reglerwerte (0–1) je Modul.
- **Kabelliste** mit geschätzter Länge (aufgerundet auf 10/15/20/30/45/60/90/120 cm), Anzahl je Länge, Druckansicht.
- **Patch-JSON Export/Import** im gemeinsamen Format (`../schema/patch.schema.json`). Import legt ein neues Rack an;
  unbekannte Module (z.B. `m4l-…` aus Tool 1) werden mit Hinweis übersprungen.

Der Zustand liegt im `localStorage` des Browsers. Für Sicherungen und den Austausch mit Tool 1 dient der JSON-Export.

## Modul-Daten
Alle Startmodule haben `"verified": false`: HP, Strom, Preis und Jack-Liste sind Richtwerte und müssen gegen das
Herstellerhandbuch geprüft werden (in der App als „ungeprüft“ markiert). Neues Modul = neue Datei
`data/modules/<id>.json`; `npm test` prüft sie gegen das Schema.

## Nicht im MVP
KI-Recherche, VCV-Export, Accounts/Cloud-Sync, Preis-Scraping.

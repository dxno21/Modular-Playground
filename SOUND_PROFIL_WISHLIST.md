# Sound-Profil aus der Bandcamp-Wishlist

> Grundlage: Screenshot der Bandcamp-Wishlist (Profil „Denizz“, 12 Releases) plus Web-Recherche zu Labels und Künstlern.
> Zu diesen Nischen-Künstlern gibt es kaum Interviews oder Gear-Listen. Die Einordnung stützt sich deshalb vor allem
> auf Label-Beschreibungen und die Releases selbst. Gegenprüfung durch Hören: siehe Abschnitt 5.

## 1. Die Releases

| Release | Künstler | Label | Einordnung |
|---|---|---|---|
| My Last Goodbye (Pre-Order) | Tino Trøster | Diffraction Records (Göppingen, seit 2022) | treibend, deep/hypnotisch |
| Blinded by Success | AgainstMe | – | dunkel, reduziert |
| Revival [digi only], Carnets, Liberdade EP | mord-Katalog | **Mord** (Rotterdam, Bas Mooy) | dunkel, repetitiv, industriell, experimentell |
| AMTK+004, ORBE – Exelon | ORBE, Angioma & BLANKA | **Amotik / AMTK+** (Berlin) | hypnotisch-atmosphärisch, roh, minimalistisch |
| In Motion EP | Connor Wall | **Phorum** | „deeply personal and hypnotic“ |
| Iccona | – | IOR Records | dunkel, verwurzelt, organisch-düster |
| Upper And Lower Bounds | Linear System | – | dunkel, symmetrisch, kühl |
| Everything Is Transitory (Remixed) | Lakej (Remixe: Kowalski, Fixeer, Wincent, Biorc) | **Solitär** | atmosphärisch, deep, hypnotisch |
| KALLAIT | Peryl & Rødhåd | **WSNWG** | dunkel, deep, Berliner Dystopian-Umfeld |

**Kurzfassung:** Hypnotic Techno mit dunkler, roher Kante. Er liegt zwischen der atmosphärischen Berliner Schule
(Amotik, Rødhåd, Solitär, Phorum) und der härteren, industriellen Rotterdamer Linie (Mord). Wenig Melodie und keine
großen Breaks. Die Spannung entsteht durch Wiederholung, Mikro-Variation, Raum und Textur.

## 2. Sound-Profil (Vektor für das KI-Tool)

```json
{
  "tempo_bpm": [128, 140],
  "kick": { "rolling": 0.9, "sub": 0.8, "distortion": 0.5 },
  "percussion": { "metallisch": 0.8, "dicht_16tel": 0.7, "polymetrisch": 0.8 },
  "melodie": 0.15,
  "drone_textur": 0.8,
  "raum": { "groesse": 0.8, "dunkel": 0.9 },
  "industrial_noise": 0.6,
  "variation": { "makro": 0.2, "mikro": 0.9 },
  "generativ": 0.7
}
```

## 3. Was das für das Rack bedeutet

| Klangmerkmal | Typisch in der Wishlist | Modulrolle | Aus der Datenbank |
|---|---|---|---|
| Rollende, tiefe Kick mit Rumble | Mord, Amotik, WSNWG | Kick-Voice + Hall/Verzerrung als Rumble | Basimilus Iteritas Alter, Erica Bassdrum |
| Metallische 16tel-Perkussion | Amotik, Rødhåd | Resonator, Makro-Oszillator | Rings, Plaits |
| Hypnotische Wiederholung mit Mikro-Variation | alle | Clock mit Wahrscheinlichkeit/Euclid, Zufall mit Loop | Pamela's Pro Workout, Marbles (Déjà-vu) |
| Langsame Filter- und Klangbewegung | Solitär, Phorum | Funktionsgenerator, LFO | Maths, Tides |
| Dunkle Flächen und Drones | Rødhåd, IOR, Linear System | Mehrstimmiger Oszillator, Granular | Ensemble Oscillator, Clouds |
| Rauschen, industrielle Kante | Mord | Noise, Verzerrung | Noise Plethora (Wavefolder/Crush fehlt noch) |
| Großer, dunkler Raum | alle | Hall | Desmodus Versio, Spring Reverb |

**Fehlt in der Datenbank** (nächste Kandidaten zum Eintragen): Verzerrung/Wavefolder für die Industrial-Kante,
ein Delay für Dub-Echos auf Perkussion und ein Filter/LPG für Hats und Perkussion.

## 4. Vorschlag für deine zwei Behringer-Cases

Behringer Eurorack Rack: je 84 HP in einer Reihe, davon belegt das CP1A-Netzteil 4 HP. Nutzbar sind also 80 HP pro Case,
mit +12 V 1000 mA, −12 V 1000 mA und +5 V 500 mA.

- **Case 1 – Rhythmus** (76/80 HP, +12 V 500 mA): Pamela's Pro Workout, Basimilus Iteritas Alter, Plaits, Rings, Maths, Quad VCA.
- **Case 2 – Drone und Raum** (76/80 HP, +12 V 555 mA): Marbles, Ensemble Oscillator, Noise Plethora, Clouds, Desmodus Versio.

Beide liegen als Patch-JSON in `data/patches/` und erscheinen im Hardware-Planer unter „Vorschlag laden …“,
mit Startverkabelung und Regler-Notizen. Die Clock aus Case 1 (Pamela) synchronisiert Case 2 (Marbles).
Gesamtpreis laut Datenbank: ca. 3.400 € (Case 1 ca. 1.740 €, Case 2 ca. 1.680 €) (Richtwerte, Mutable-Module nur noch gebraucht).

**Kaufreihenfolge nach Nutzen pro Euro für diesen Sound:**
1. Pamela's Pro Workout: Clock und Rhythmus-Herz, ohne sie keine Polymetrik.
2. Plaits: Kick, Hats und Perkussion in einem Modul, gut zum Anfangen.
3. Maths: Hüllkurven und Modulation für alles.
4. Rings: der metallische Charakter.
5. Marbles: hypnotische Variation.
6. Danach: Raum (Desmodus Versio), Drone (Ensemble Oscillator), Spezial-Kick (BIA), Textur (Clouds/Noise Plethora).

Vor jedem Kauf die Module zuerst digital testen (VCV / M4L, siehe `KONZEPT.md`). Die Datenbank-Werte sind noch ungeprüft.

## 5. Nächste Schritte
- Audioanalyse von 3–5 Tracks aus der Wishlist (Tempo, Spektrum, Kick-Länge, Hallanteil), damit der Profilvektor messbar wird.
- Die Ergebnisse mit der Sound-Recherche aus der anderen Session zusammenführen.

## Quellen
- [Mord – Discogs](https://www.discogs.com/label/159295-Mord), [Mord – RA](https://ra.co/labels/9839), [Bas Mooy – Qobuz](https://www.qobuz.com/fr-fr/interpreter/bas-mooy/822492)
- [Amotik – Juno Daily (AMTK+)](https://www.juno.co.uk/junodaily/2023/02/20/amotik-launches-new-split-ep-label-amtk-with-deluka-pairing/), [Mixmag](https://mixmag.net/read/amotik-links-up-with-deluka-for-split-techno-12-launches-new-imprint-news), [Everand-Artikel](https://www.everand.com/article/679116420/Amotik)
- [Connor Wall – Traxsource](https://www.traxsource.com/title/2742615/equals), [Phorum Bandcamp](https://phorum-records.bandcamp.com)
- [Diffraction Records Bandcamp](https://diffraction-records.bandcamp.com/album/diffx001)
- [Behringer Eurorack Rack – Perfect Circuit](https://www.perfectcircuit.com/behringer-eurorack-rack-3u-84hp.html), [Gear4music](https://www.gear4music.com/us/en/Keyboards-and-Pianos/Behringer-EURORACK-Rack-19-inch-Kit-with-Power-Supply/3ER8)

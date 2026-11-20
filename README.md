# Projekt 1861 – Steuerungs-Labor

Ein Spaßprojekt: ein 2D-Strategiespiel fürs Handy, inspiriert vom Klassiker „North & South“ (1989).
Leitlinie: [docs/VISION.md](docs/VISION.md) – kein Remake, sondern die Weiterentwicklung einer Spielidee.

Dieser Stand ist **Phase 1**: ein Testfeld, auf dem sich verschiedene Touch-Steuerungen für die Gefechte ausprobieren und benoten lassen. Alle Grafiken sind Platzhalter.

## Ausprobieren

| Wo | Wie |
| --- | --- |
| iPhone / Browser | https://tomaku23.github.io/project-1861/ öffnen. Tipp fürs iPhone: in Safari „Zum Home-Bildschirm“, dann läuft es im Vollbild. |
| Android (OnePlus) | Unter *Releases* → „Steuerungs-Labor (aktueller Stand)“ die Datei `projekt-1861.apk` laden und installieren. Android fragt einmal, ob Installationen aus dieser Quelle erlaubt sind. |
| Windows-Laptop | [Godot 4.7.2](https://godotengine.org/download) laden (Standard-Version, nicht .NET), `project.godot` öffnen, F5 drücken. Die Maus ersetzt den Finger. |

## So funktioniert das Labor

Blau (du) kämpft gegen Grau (einfache KI). Jede Seite hat Infanterie, Kavallerie und eine Kanone. Wer alle Truppen verliert, verliert die Runde; nach 3 Minuten ist Schluss.

Oben wählst du **Steuerung** und **Kanone**. Jeder Wechsel startet eine neue Runde, damit die Vergleiche fair bleiben.

| Steuerung | Bedienung |
| --- | --- |
| **A · Knöpfe + Wischen** | Truppe unten links wählen, dann übers Feld wischen: Richtung und Länge = Marschrichtung und Weite. Kurz tippen = Halt. |
| **B · Antippen + Ziel** | Eigene Truppe antippen, dann ein Ziel. Gegner antippen = Angriff. |
| **C · Joystick + Feuer** | Daumen links = Joystick, rechts der Feuerknopf. Infanterie feuert nur auf Knopfdruck, Kavallerie greift an, bei der Artillerie zielt der Joystick. |

| Kanone (gilt in A und B) | Bedienung |
| --- | --- |
| **Schleuder** | Irgendwo drücken, nach hinten ziehen, loslassen. Die gepunktete Linie zeigt die Flugbahn. |
| **Timing** | Ziel antippen, dann noch einmal tippen, wenn der pulsierende Kreis klein und grün ist. |

**Zeitlupe:** Beim Wechsel der Truppe läuft das Spiel kurz langsamer. Lässt sich oben abschalten.

**Noten:** Nach jeder Runde vergibst du Schulnoten (1 = sehr gut … 6 = ungenügend) für *Spaß* und *Treffsicherheit*. Oben unter „Noten“ steht der Durchschnitt je Kombination. Die beste Kombination wird die Steuerung fürs echte Spiel.

## Projektaufbau

```text
core/      Spiellogik ohne Grafik: Regeln, Spielzustand, Noten
data/      Einheitenwerte (units.json) – Balancing ohne Code
scenes/    Labor: Schlachtfeld, Truppen, Steuerungen, Oberfläche
systems/   Speichern (mit Versionsnummer und Autosave)
tests/     automatische Tests
docs/      Entscheidungen und Änderungsprotokoll
```

## Automatik

Bei jedem Hochladen auf `main` baut GitHub selbstständig: Tests, Browser-Version (GitHub Pages) und Android-Datei (Release „labor-aktuell“). Den Stand siehst du unter *Actions*.

Tests lokal: `godot --headless --path . --script res://tests/run_tests.gd`

### Einmalige Einrichtung auf GitHub

1. *Settings → Pages → Build and deployment → Source:* „GitHub Actions“ wählen.
2. GitHub Pages ist im kostenlosen Tarif nur für **öffentliche** Repositories verfügbar. Wird das Repository privat, überspringt der Build die Browser-Version automatisch; die Android-Datei bleibt.

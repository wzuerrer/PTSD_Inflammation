# PTSD Symptom Heterogeneity Simulation

## Projektbeschreibung

Dieses Projekt simuliert die Heterogenität von Symptom-Kombinationen bei PTSD unter Berücksichtigung von Inflammation als zweite latente Variable.

## Dateien

- **`Inflammation_Sim.Rmd`** - Erweiterte Simulation mit zwei latenten Variablen (PTSD und Inflammation)

## Änderungen zum ursprünglichen Modell

### Neu hinzugefügt:

#### 1. Zweite latente Variable: Inflammation (I)
- **Prävalenz**: 50%
- **Korrelation mit PTSD (L)**: 0.6
- Beide latente Variablen sind binär (vorhanden/nicht vorhanden)

#### 2. Funktion: `generate_correlated_binary()`
- Erzeugt zwei korrelierte binäre latente Variablen
- Nutzt bivariate Normalverteilung mit anschließender Dichotomisierung
- Ermöglicht präzise Kontrolle über Prävalenzen und Korrelation

#### 3. Erweiterte Symptom-Modellierung
Alle Symptome (S1, S2, M, W1, W2) werden nun von **beiden** latenten Variablen beeinflusst:

**Formel:** `Symptom = Faktor_L × L + Faktor_I × I + Rauschen`

**Faktoren für jedes Symptom:**

| Symptom | L-Faktor (PTSD) | I-Faktor (Inflammation) | SD | Interpretation |
|---------|-----------------|-------------------------|-----|----------------|
| S1 | 2.0 | 1.2 | 0.5 | Starker PTSD-Indikator, mittlerer I-Einfluss |
| S2 | 1.8 | 1.0 | 0.5 | Starker PTSD-Indikator, niedriger I-Einfluss |
| M | 1.2 | 1.3 | 0.8 | Mittlerer PTSD-Indikator, starker I-Einfluss |
| W1 | 0.6 | 0.9 | 1.0 | Schwacher PTSD-Indikator, niedriger I-Einfluss |
| W2 | 0.4 | 0.6 | 1.0 | Sehr schwacher Indikator für beide |

### Geänderte Parameter:

- **L (PTSD) Prävalenz**: 50% (Original) → **80%** (Erweitert)
- **Diagnose-Kriterium**: Bleibt unverändert bei ≥ 2 Symptomen

## Theoretisches Modell

### Additive Effekte
Die Effekte von PTSD (L) und Inflammation (I) auf die Symptome sind:
- **Additiv**: Beide Faktoren tragen unabhängig bei
- **Keine Interaktion**: Kein synergistischer Effekt zwischen L und I

### Korrelierte latente Variablen
- L und I korrelieren mit 0.6 (bidirektionale Beziehung)
- Beide sind nicht direkt beobachtbar
- Werden aus Symptom-Mustern erschlossen

## Verwendung

1. Öffne `Inflammation_Sim.Rmd` in RStudio
2. Installiere benötigte Pakete (falls noch nicht vorhanden):
```r
   install.packages(c("tidyverse", "mvtnorm", "MASS"))
```
3. Führe alle Code-Chunks aus (Ctrl/Cmd + Alt + R)

## Ausgabe

Das Skript berechnet:
- Wahrscheinlichkeiten aller 32 möglichen Symptom-Kombinationen
- Mittelwerte und Standardabweichungen über 100 Simulationen
- Visualisierung der Wahrscheinlichkeitsverteilung
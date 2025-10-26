# PTSD Symptom Heterogeneity Simulation with/without Inflammation

## Dateien

-   **`Inflammation_Sim.Rmd`** - Erweiterte Simulation mit zwei latenten Variablen (PTSD und Inflammation)

## Änderungen zum ursprünglichen Modell

#### 1. Zweite latente Variable I, welche Inflammation simuliert, binär, Prävalenz von 50%, Korrelation mit L von 0.6

#### 2. Funktion: `generate_correlated_binary()`, welche zwei korrelierte binäre latente Variablen erzeugt, bivariate Normalverteilung nutzt mit anschliessender Dichotomisierung

#### 3. Erweitertung der Symptom-Modellierung: Alle Symptome (S1, S2, M, W1, W2) werden nun von beiden latenten Variablen beeinflusst: Formel: `Symptom = Faktor_L × L + Faktor_I × I + Rauschen`. Die Effekte von PTSD (L) und Inflammation (I) auf die Symptome sind additiv, d.h. beide Faktoren tragen unabhängig bei.

#### 4. Geänderter Parameter: L (PTSD) Prävalenz: 50% → 80%

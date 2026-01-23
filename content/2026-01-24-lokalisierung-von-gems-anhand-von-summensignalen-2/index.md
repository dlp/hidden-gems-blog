---
author: GC117
author_bio: >
  Physiker im Ruhestand
author_image: troll.jpg
tags: ["Algorithmus", "Lokalisierung", "Position", "Signal"]
---

# Lokalisierung von Gems anhand von Summensignalen (Teil 2)

Im [Teil 1 dieses Blogs](https://hiddengems.gymnasiumsteglitz.de/blog/2026-01-22-lokalisierung-von-gems-anhand-von-summensignalen) wird erläutert, wie das vom JSON-string mitgeteilte Summensignal sich aus mehreren Einzelsignalstärken zusammensetzt und wie diese mit den sog. *Zielvektoren* und den daraus abgeleiteten *genauen Zielvektoren* zusammenhängen. Ein Vergleich der genauen Zielvektoren in einem bestimmten Tick mit denjenigen aus dem Vorgängertick erlaubt nun, wie wir sehen werden, eine zuverlässige Lokalisierung von plötzlich auftauchenden Gems. 

## Weitere nützliche Datenstrukturen

Bei der Entwicklung des Algorithmus hat sich herausgestellt, dass zwei weitere Datenstrukturen recht nützlich sind. Die erste wird als `GemEst` (»gem estimate«) bezeichnet und enthält alle Informationen, die zur erfolgreichen Lokalisierung neu auftauchender Gems nötig sind. Die Idee dahinter ist, die Anzahl der aktuellen genauen Zielvektoren `ncurr` durch Ausschluss unmöglicher Fälle soweit zu reduzieren (nämlich auf 1), dass nur noch eine Möglichkeit `curr_pos[0]` übrig bleibt. Dabei werden bei jedem Tick die vorherigen Größen (`nprev` und `prev_pos[]`) mit den aktuellen (`ncurr` und `curr_pos[]`) verglichen und anschließend die Ersteren durch die Letzteren überschrieben.

```cpp
struct GemEst {
    int     first_tick;  // Tick beim ersten Signal
    point   first_dist;  // Zielvektor beim ersten Signal
    int     nest;        // Anzahl der Schätzungen
    point   est;         // geschätzte Position des Gems
    int     nprev;       // vorherige Anzahl an genauen Zielvektoren
    point   *prev_pos;   // Array der vorherigen genauen Zielvektoren
    int     ncurr;       // aktuelle Anzahl an genauen Zielvektoren
    point   *curr_pos;   // Array der aktuellen genauen Zielvektoren
    bool    localized;   // Flag ob Lokalisierung erfolgreich war

    GemEst(void);        // Konstruktor (setzt alle Variablen zurück)
    GemEst(int, point);  // Konstruktor (setzt 'first_tick' und 'first_dist')
};

GemEst::GemEst(void) {
    first_tick = nest = nprev = ncurr = -1;
    first_dist = est = point(-1, -1);
    localized = false;
}

GemEst::GemEst(int ft, point fd) {
    first_tick = ft; first_dist = fd;
    nest = nprev = ncurr = -1;
    est = point(-1, -1);
    localized = false;
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 10</em>
</div>

Wir benötigen so viele Variablen dieses Typs, wie Gems gleichzeitig auf dem Spielfeld sein können (`MAXSIMGEMS`), in Stage 2 sind es drei.

```cpp
GemEst  *GEM_EST = NULL;     // Array mit den Daten zur Schätzung der Gem-Positionen
...
GEM_EST = new GemEst[MAXSIMGEMS];   // Speicherplatz reservieren
for (int i = 0; i < MAXSIMGEMS; i++) {
    GEM_EST[i].prev_pos = new point[200];  // max. 200 genaue Zielvektoren im vorherigen Tick
    GEM_EST[i].curr_pos = new point[200];  // max. 200 genaue Zielvektoren im aktuellen Tick
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 11</em>
</div>

Die zweite Datenstruktur `Gem` sammelt die Daten aller Gems, die im Laufe einer Runde auf dem Spielbrett erscheinen:

```cpp
struct Gem {
    point   pos;          // Position beim Erscheinen
    int     ttl;          // time-to-live beim Erscheinen
    int     atick;        // Tick bei Ankündigung durch JSON
    int     ltick;        // Tick bei erster Schätzung durch ein Signal
    int     dtick;        // Tick wenn der Gem stirbt ohne einkassiert zu werden
    int     prev_dist;    // vorheriger Manhattan-Abstand zum Bot
    int     curr_dist;    // aktueller Manhattan-Abstand zum Bot
    float   radius;       // Signalradius beim Erscheinen
    float   level = 0.0;  // aktuelle Signalstärke
    int     state;        // augenblicklicher Zustand
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 12</em>
</div>

Schließlich wird auch von dieser Struktur ein globales Array, `GEMS[]` genannt, benötigt. Die globale Variable `NGEMS` ist die Anzahl der zu einer Zeit bisher aufgetauchten Gems und `MAXGEMS` die Maximalzahl an Gems, die geschätzt in einer gesamten Runde einzusammeln sind.

```cpp
int    NGEMS = 0;     // Anzahl der aktuell bisher aufgetauchten Gems
Gem    *GEMS = NULL;  // Array mit den Daten zu allen Gems
...
GEMS = new Gem[MAXGEMS];  // Speicherplatz reservieren
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 13</em>
</div>

Die einzelnen Bestandteile der Struktur `Gem` sind in den Kommentaren erläutert, nur die Variable `state` muss noch erklärt werden. Jedem Gem können eindeutig die Zustände *schläft*, *lebt*, *eingefangen*, *angekündigt*, *lokalisiert* und *gestorben* zugeordnet werden. Alle diese Zustände werden durch gesetzte Bits innerhalb der `int`-Variablen `state` gespeichert (da es nur sechs verschiedene Zustände sind, reicht eigentlich auch eine 1-Byte-Variable vom Typ `unsigned char`). Die Bits werden hexadezimal durch folgende Konstanten repräsentiert:

```cpp
const int SLEEPING  =  0x0;   // Gem schläft und ist noch nicht erwacht
const int ALIVE     =  0x1;   // Gem lebt und ist sichtbar
const int CAPTURED  =  0x2;   // Gem wurde eingefangen
const int ANNOUNCED =  0x4;   // Gem wurde per JSON angekündigt
const int LOCALIZED =  0x8;   // Gem wurde durch unseren Algorithmus lokalisiert
const int DIED      = 0x10;   // Gem ist leider gestorben ohne eingefangen zu werden
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 14</em>
</div>
 
<div class="alert alert-info">
  Beispiel 3: Wünschen wir, dass Gem <code>GEMS[5]</code> aus dem Schlaf gerissen wird und zum Leben erwacht, können wir das entsprechende erste Bit von rechts (<code>0x1</code>) 
  durch

$$
\texttt{GEMS[5].state |= ALIVE;}
$$
setzen (die Verwendung des <code>|=</code>-Operators lässt die anderen Bits unbeeinflusst). Möchten wir dagegen <code>GEMS[2]</code> ad acta legen, weil wir es gerade geschnappt haben, wären die Befehle
$$
\texttt{GEMS[2].state &= ~ALIVE;}
$$

$$
\texttt{GEMS[2] |= CAPTURED;}
$$
angebracht.
</div>

Nun haben wir alle für unseren Zweck wesentlichen Datenstrukturen vorgestellt.

## Von der Schätzung zur Gewissheit

Beginnen wir also unsere Untersuchung mit demjenigen Tick, in dem das erste Signal im JSON-string erscheint. Die entsprechende Abfrage im Programm ist diejenige zu prüfen, ob `signal_level` im JSON auftaucht. Die dort angegebene Signalstärke wird in der globalen Variable `SIGNAL_LEVEL` gespeichert. Dann wird als Erstes die Summe aller Einzelsignale von Gems berechnet, sofern sie bereits lokalisiert wurden. Dies erledigt die Funktion `sum_of_known_signal_levels()`:

```cpp
float sum_of_known_signal_levels(void)
{
  float sum = 0.0;

  for (int i = 0; i < NGEMS; i++)
    if (GEMS[i].state & ALIVE)
      sum += GEMS[i].level;

  return sum;
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 15</em>
</div>

Damit kann entschieden werden, ob die aktuelle Signalstärke `SIGNAL_LEVEL` ausschließlich von bekannten Gems herrührt, oder ob sich in diesem Summensignal ein noch nicht lokalisierter Gem verbirgt. Der eventuell vorhandene **Signalüberschuss** wird in der globalen Variable `REMAINING_SIGNAL` gespeichert.

```cpp
float  REMAINING_SIGNAL;
...
// berechne Signalüberschuss
float  sum_lvl = sum_of_known_signal_levels(false);
REMAINING_SIGNAL = (SIGNAL_LEVEL > sum_lvl+1e-6) ? SIGNAL_LEVEL-sum_lvl : 0.0;

if (SIGNAL_LEVEL > 0.0) {
  if (REMAINING_SIGNAL > 0.0)

    // jetzt gibt es etwas zu tun
    get_signal_levels(REMAINING_SIGNAL);
}
else {
...
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 16</em>
</div>

Wird an dieser Stelle sowohl ein Signal als auch ein Signalüberschuss festgestellt, wird es spannend. Die Funktion `get_signal_levels()` wertet diesen aus und leistet die Hauptarbeit unseres Algorithmus. Sie fällt daher entsprechend lang aus. Der Beginn der Funktion ist im *Codefragment 9* angegeben.

```cpp
...
    // Fortsetzung von Codefragment 9

    if (nd == 0) {
        point idist, jdist;

        // durchsuche die Tabelle weiter nach der Summe aus zwei Einzelsignalen
        for (int i = 0; i < NSIGNAL_LVL-1; i++) {
            idist = SIGNAL_LVL[i].dist;
            for (int j = i+1; j < NSIGNAL_LVL; j++) {
                jdist = SIGNAL_LVL[j].dist;

                if (fabs((sumlvl = SIGNAL_LVL[i].level+SIGNAL_LVL[j].level) - lvl) < 1e-6) {

                    // 'lvl' ist die Summe zweier unbekannter Einzelsignale
                    SIGNAL_EVENT[NSIGNAL_EVENT].nsrc = 2;

                    // vergleiche 'idist' mit vorherigem signal event
                    bool found = false;
                    for (int m = 0; m < SIGNAL_EVENT[NSIGNAL_EVENT-1].ndist; m++) {
                        if (SIGNAL_EVENT[NSIGNAL_EVENT-1].nsrc == 1) {

                            // vorheriges signal event war ein Einzelsignal
                            if ((mdist(SIGNAL_EVENT[NSIGNAL_EVENT-1].dist[m], idist) <= 1) ||
                                (mdist(SIGNAL_EVENT[NSIGNAL_EVENT-1].dist[m], jdist) <= 1)) {
                                SIGNAL_EVENT[NSIGNAL_EVENT].dist[nd++] = idist;
                                SIGNAL_EVENT[NSIGNAL_EVENT].dist[nd++] = jdist;
                                found = true;
                                break;
                            }
                        }

                        if (SIGNAL_EVENT[NSIGNAL_EVENT-1].nsrc == 2) {

                            // vorheriges signal event war ein Doppelsignal
                            found = compare_two_pairs_of_distances(&SIGNAL_EVENT[NSIGNAL_EVENT-1].dist[m], idist, jdist);
                            if (found) {
                                SIGNAL_EVENT[NSIGNAL_EVENT].dist[nd++] = idist;
                                SIGNAL_EVENT[NSIGNAL_EVENT].dist[nd++] = jdist;
                            }

                            m++;
                        }
                    }
                }
            }
        }

        SIGNAL_EVENT[NSIGNAL_EVENT].ndist = nd;
    }

    if (nd == 0) {

        // echte Summen aus drei unbekannten Einzelsignalen sind hier noch nicht implementiert
        exit(1);
    }

    ...
    // Fortsetzung im Codefragment 20
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 17</em>
</div>

An dieser Stelle muss ich gestehen, dass die Zerlegung von drei unbekannten Einzelsignalen nicht implementiert ist. Dies würde eine Dreifachschleife erfordern, deren Laufzeit kritisch wäre. Zum Glück tritt dieser Fall praktisch nie auf; es müssten dazu in drei aufeinanderfolgenden Ticks jeweils ein Gem erscheinen. Dies ist bisher nie beobachtet worden.

Um den Algorithmus vollständig anzugeben, fehlen noch die Funktionen `mdist()` und `compare_two_pairs_of_distances()`. Die Erstere berechnet die sog. »Manhattan-Distanz« zweier Positionen `p` und `q`. Sie ist die Anzahl der Einzelschritte, um von `p` nach `q` zu gelangen (oder umgekehrt).

```cpp
int mdist(const point& p, const point& q)
{
  return abs(p.x-q.x) + abs(p.y-q.y);
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 18</em>
</div>

Die zweite Funktion vergleicht ein Paar von Zielvektoren `d1[0]`, `d1[1]` mit den Zielvektoren `d2` und `d3`. Übereinstimmung zweier Zielvektoren wird hier erkannt, wenn die Manhattan-Distanz beider Vektoren höchstens 1 beträgt. Dies ist so, weil der Bot zwischen zwei aufeinanderfolgenden Ticks höchstens um einen Schritt weitergelaufen ist.

```cpp
bool compare_two_pairs_of_distances(point* d1, const point& d2, const point& d3)
{
  return ((mdist(d1[0], d2) <= 1) && (mdist(d1[1], d3) <= 1)) ? true : false;
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 19</em>
</div>

Wir fahren fort mit der wichtigsten Funktion `get_signal_levels()`:

```cpp
    ... 
    // Fortsetzung von Codefragment 17

    int nintsect, n;
    point pintsect[100];

    if (nd > 0) {

      // Speichere Daten im Array 'SIGNAL_EVENT'
      // 'TICK' ist der aktuelle Tick, 'BOT' die aktuelle Position des Bots
      SIGNAL_EVENT[NSIGNAL_EVENT].tick = TICK;
      SIGNAL_EVENT[NSIGNAL_EVENT].level = lvl;
      SIGNAL_EVENT[NSIGNAL_EVENT].bot = BOT;

      // Speichere Daten in einem Element des Arrays 'GEM_EST'
      if (NSIGNAL_EVENT == 0 || NSIGNAL_IDX == 0) {

        // Fall 0: kein gem estimate aktiv, speichere Daten in 'GEM_EST[0]'
        GEM_EST[0].first_tick = TICK;
        GEM_EST[0].first_dist = SIGNAL_EVENT[NSIGNAL_EVENT].dist[0];
        GEM_EST[0].nest = 1;
        GEM_EST[0].est = point(-1, -1);
        GEM_EST[0].ncurr = 0;
        GEM_EST[0].localized = false;
        for (int m = 0; m < SIGNAL_EVENT[NSIGNAL_EVENT].ndist; m++) {
          n = get_possible_signal_sources(XBOT, YBOT, SIGNAL_EVENT[NSIGNAL_EVENT].dist[m], GEM_EST[0].curr_pos+GEM_EST[0].ncurr);
          GEM_EST[0].ncurr += n;
        }

        // lösche alle anderen gem estimates
        for (int j = 1; j < MAX_GEMS; j++) {
          GEM_EST[j].first_tick = -1;
          GEM_EST[j].nest = -1;
          GEM_EST[j].est = point(-1, -1);
          GEM_EST[j].ncurr = 0;
          GEM_EST[j].localized = false;
        }

        NSIGNAL_IDX++;
      }
      else
        if (SIGNAL_EVENT[NSIGNAL_EVENT].nsrc > SIGNAL_EVENT[NSIGNAL_EVENT-1].nsrc) {

          // das aktuelle Signal hat mehr Quellen als das vorherige
          int x = SIGNAL_EVENT[NSIGNAL_EVENT].nsrc - 1;

          // Fall 1: ???
          GEM_EST[x].first_tick = TICK;
          GEM_EST[x].first_dist = SIGNAL_EVENT[NSIGNAL_EVENT].dist[x];
          GEM_EST[x].nest = 1;
          GEM_EST[x].est = point(-1, -1);
          GEM_EST[x].ncurr = 0;
          GEM_EST[x].localized = false;
          for (int m = 0; m < SIGNAL_EVENT[NSIGNAL_EVENT].ndist; m++) {
            n = get_possible_signal_sources(XBOT, YBOT, SIGNAL_EVENT[NSIGNAL_EVENT].dist[x], GEM_EST[x].curr_pos+GEM_EST[x].ncurr);
            GEM_EST[x].ncurr += n;
          }

          // aktualisiere Daten von vorherigen gem estimates
          for (x = 0; x < SIGNAL_EVENT[NSIGNAL_EVENT].nsrc-1; x++) {
            if (!is_inside(GEM_EST[x].est)) {
              GEM_EST[x].nest++;
              for (int j = 0; j < GEM_EST[x].ncurr; j++)
                GEM_EST[x].prev_pos[j] = GEM_EST[x].curr_pos[j];
              GEM_EST[x].nprev = GEM_EST[x].ncurr;

              GEM_EST[x].ncurr = 0;
              for (int m = 0; m < SIGNAL_EVENT[NSIGNAL_EVENT].ndist; m++) {
                n = get_possible_signal_sources(XBOT, YBOT, SIGNAL_EVENT[NSIGNAL_EVENT].dist[m], GEM_EST[x].curr_pos+GEM_EST[x].ncurr, false);
                GEM_EST[x].ncurr += n;
              }

              // ermittle Durchschnitt von vorherigen und aktuellen genauen Zielvektoren
              nintsect = intersect_point_arrays(GEM_EST[x].nprev, GEM_EST[x].prev_pos, GEM_EST[x].ncurr, GEM_EST[x].curr_pos, 0, pintsect, false);

              if (nintsect == 1) {

                // hurra, der Gem wurde lokalisiert
                GEM_EST[x].est = pintsect[0];
                GEM_EST[x].localized = true;

                // etabliere neuen Gem
                // (hier in eigenes Programm integrieren)

                NSIGNAL_IDX = 0;

                if (x == 0 && GEM_EST[1].first_tick != -1) {

                  // verschiebe gem estimate 'x+1' --> 'x'
                  GEM_EST[x].first_tick = GEM_EST[x+1].first_tick;
                  GEM_EST[x].first_dist = GEM_EST[x+1].first_dist;
                  GEM_EST[x].nest = GEM_EST[x+1].nest;
                  GEM_EST[x].est = GEM_EST[x+1].est;
                  for (int j = 0; j < GEM_EST[x+1].nprev; j++)
                    GEM_EST[x].prev_pos[j] = GEM_EST[x+1].prev_pos[j];
                  GEM_EST[x].nprev = GEM_EST[x+1].nprev;
                  for (int j = 0; j < GEM_EST[x+1].ncurr; j++)
                    GEM_EST[x].curr_pos[j] = GEM_EST[x+1].curr_pos[j];
                  GEM_EST[x].ncurr = GEM_EST[x+1].ncurr;
                  GEM_EST[x].localized = GEM_EST[x+1].localized;

                  // lösche gem estimate 'x+1'
                  GEM_EST[x+1].first_tick = -1;
                  GEM_EST[x+1].nest = -1;
                  GEM_EST[x+1].est = point(-1, -1);
                  GEM_EST[x+1].nprev = GEM_EST[x+1].ncurr = 0;
                  GEM_EST[x+1].localized = false;
                }
                else {

                  // lösche gem estimate 'x'
                  GEM_EST[x].first_tick = -1;
                  GEM_EST[x].nest = -1;
                  GEM_EST[x].est = point(-1, -1);
                  GEM_EST[x].nprev = GEM_EST[x+1].ncurr = 0;
                  GEM_EST[x].localized = false;
                }
              }
              else {
                if (CALL_LOG && verbose) {
                  for (int k = 0; k < CALL_DEPTH; k++)  CALL << " ";
                  CALL << ".. " << myname << ":  ";
                  CALL << term_light_cyan << "nintsect = " << nintsect;
                  for (int i = 0; i < nintsect; i++)
                    CALL << " (" << std::setw(2) << pintsect[i].x << "," << std::setw(2) << pintsect[i].y << ")";
                  CALL << term_reset << std::endl << std::flush;
                }

                // kopiere die Durchschnittsmenge an genauen Zielvektoren nach 'x'
                for (int i = 0; i < nintsect; i++)
                  GEM_EST[x].curr_pos[i] = pintsect[i];
                GEM_EST[x].ncurr = nintsect;

                if (CALL_LOG && verbose) {
                  for (int k = 0; k < CALL_DEPTH; k++)  CALL << " ";
                  CALL << ".. " << myname << ":  ";
                  print_signal_event(CALL, NSIGNAL_EVENT);
                  for (int m = 0; m < MAX_GEMS; m++) {
                    for (int k = 0; k < CALL_DEPTH; k++)  CALL << " ";
                    CALL << ".. " << myname << ":  ";
                    print_gem_estimates(CALL, m);
                  }
                }
              }
            }
          }
        }
        else {

          // aktualisiere Daten von allen gem estimates
          for (int x = 0; x < SIGNAL_EVENT[NSIGNAL_EVENT].nsrc; x++) {
            if (CALL_LOG && verbose) {
              for (int k = 0; k < CALL_DEPTH; k++)  CALL << " ";
              CALL << ".. " << myname << ":  " << term_dark_gray << "case 2:  index " << x << "  xest|yest = " << GEM_EST[x].xest << " | " << GEM_EST[x].yest << term_reset << std::endl << std::flush;
            }

            if (!is_inside(GEM_EST[x].est)) {
              GEM_EST[x].nest++;
              for (int j = 0; j < GEM_EST[x].ncurr; j++)
                GEM_EST[x].prev_pos[j] = GEM_EST[x].curr_pos[j];
              GEM_EST[x].nprev = GEM_EST[x].ncurr;

              GEM_EST[x].ncurr = 0;
              for (int m = 0; m < SIGNAL_EVENT[NSIGNAL_EVENT].ndist; m++) {
                if (SIGNAL_EVENT[NSIGNAL_EVENT].ndist > SIGNAL_EVENT[NSIGNAL_EVENT-1].ndist) {

                  nintsect = intersect_point_arrays(SIGNAL_EVENT[NSIGNAL_EVENT].ndist, SIGNAL_EVENT[NSIGNAL_EVENT].dist,
                                                    SIGNAL_EVENT[NSIGNAL_EVENT-1].ndist, SIGNAL_EVENT[NSIGNAL_EVENT-1].dist, 1, pintsect);

                  for (int l = 0; l < nintsect; l++)
                    SIGNAL_EVENT[NSIGNAL_EVENT].dist[l] = pintsect[l];
                  SIGNAL_EVENT[NSIGNAL_EVENT].ndist = nintsect;
                }

                n = get_possible_signal_sources(XBOT, YBOT, SIGNAL_EVENT[NSIGNAL_EVENT].dist[m], GEM_EST[x].curr_pos+GEM_EST[x].ncurr);
                GEM_EST[x].ncurr += n;
              }

              nintsect = intersect_point_arrays(GEM_EST[x].nprev, GEM_EST[x].prev_pos, GEM_EST[x].ncurr, GEM_EST[x].curr_pos, 0, pintsect);

              if (nintsect == 1) {

                // hurra, der Gem wurde lokalisiert
                GEM_EST[x].est = pintsect[0];

                // etabliere neuen Gem
                // (hier in eigenes Programm integrieren)

                NSIGNAL_IDX = 0;
                if (x == 0 && GEM_EST[1].first_tick != -1) {

                  // verschiebe gem estimate 'x+1' --> 'x'
                  GEM_EST[x].first_tick = GEM_EST[x+1].first_tick;
                  GEM_EST[x].first_dist = GEM_EST[x+1].first_dist;
                  GEM_EST[x].nest = GEM_EST[x+1].nest;
                  GEM_EST[x].est = GEM_EST[x+1].est;
                  for (int j = 0; j < GEM_EST[x+1].nprev; j++)
                    GEM_EST[x].prev_pos[j] = GEM_EST[x+1].prev_pos[j];
                  GEM_EST[x].nprev = GEM_EST[x+1].nprev;
                  for (int j = 0; j < GEM_EST[x+1].ncurr; j++)
                    GEM_EST[x].curr_pos[j] = GEM_EST[x+1].curr_pos[j];
                  GEM_EST[x].ncurr = GEM_EST[x+1].ncurr;

                  // lösche gem estimate 'x+1'
                  GEM_EST[x+1].first_tick = -1;
                  GEM_EST[x+1].nest = -1;
                  GEM_EST[x+1].est = point(-1, -1);
                  GEM_EST[x+1].nprev = GEM_EST[x+1].ncurr = 0;
                  GEM_EST[x+1].localized = false;
                }
                else {

                  // lösche gem estimate 'x'
                  GEM_EST[x].first_tick = -1;
                  GEM_EST[x].first_dist.x = -1;
                  GEM_EST[x].first_dist.y = -1;
                  GEM_EST[x].nest = -1;
                  GEM_EST[x].est = point(-1, -1);
                  GEM_EST[x].nprev = GEM_EST[x].ncurr = 0;
                  GEM_EST[x].localized = false;
                }
              }
              else {

                // kopiere die Durchschnittsmenge an genauen Zielvektoren nach 'x'
                for (int i = 0; i < nintsect; i++)
                  GEM_EST[x].curr_pos[i].x = pintsect[i];
                GEM_EST[x].ncurr = nintsect;
              }
            }
          }
        }

    NSIGNAL_EVENT++;
  }
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 20</em>
</div>

Es fehlen noch ein paar Funktionen, die hier benutzt werden. Die Funktion `get_possible_signal_sources()` splittet einen Zielvektor `v` nicht nur in genaue Zielvektoren auf (dies ist das Thema am Ende von Teil 1 dieses Blogs), sondern berechnet mithilfe der aktuellen Bot-Position `bot` die resultierenden **Zielpositionen** auf dem Spielfeld, die für den Gem infrage kommen. Dabei werden alle ungültigen Positionen aussortiert. Dies macht die Funktion `is_inside_and_not_wall(const point& p)`, die nur prüft, dass die Position `p` tatsächlich im Innern des Spielfeldes liegt und nicht gerade von einer Wand belegt wird. Alle gültigen Positionen werden im Array `src` abgespeichert, dessen Anzahl an Elementen `l` gibt die Funktion zurück.

```cpp
int get_possible_signal_sources(const point& bot, const point& v, point* src)
{
  point p;
  int l = 0;

  if (v.x == 0 && v.y == 0) {

    // dieser Fall sollte eigentlich nicht auftreten
    p.x = bot.x;
    p.y = bot.y;
    if (is_inside_and_not_wall(p))  src[l++] = p;
  }
  else
    if (v.x == 0 && abs(v.y) > 0) {

      // das ist der Prototyp [n, 0] (Fall 1 aus Teil 1)
      // mit der Vielfachheit 4
      p.x = bot.x;
      p.y = bot.y + v.y;
      if (is_inside_and_not_wall(p))  src[l++] = p;

      p.x = bot.x;
      p.y = bot.y - v.y;
      if (is_inside_and_not_wall(p))  src[l++] = p;

      p.x = bot.x + v.y;
      p.y = bot.y;
      if (is_inside_and_not_wall(p))  src[l++] = p;

      p.x = bot.x - v.y;
      p.y = bot.y;
      if (is_inside_and_not_wall(p))  src[l++] = p;
    }
    else
      if (abs(v.x) > 0 && v.y == 0) {

        // das ist der Prototyp [n, 0] (Fall 1 aus Teil 1)
        // mit der Vielfachheit 4
        p.x = bot.x;
        p.y = bot.y + v.x;
        if (is_inside_and_not_wall(p))  src[l++] = p;

        p.x = bot.x;
        p.y = bot.y - v.x;
        if (is_inside_and_not_wall(p))  src[l++] = p;

        p.x = bot.x + v.x;
        p.y = bot.y;
        if (is_inside_and_not_wall(p))  src[l++] = p;

        p.x = bot.x - v.x;
        p.y = bot.y;
        if (is_inside_and_not_wall(p))  src[l++] = p;
      }
      else
        if (abs(v.x) == abs(v.y)) {

          // das ist der Prototyp [n, n] (Fall 2 aus Teil 1)
          // mit der Vielfachheit 4
          p.x = bot.x + v.x;
          p.y = bot.y + v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x + v.x;
          p.y = bot.y - v.y;

          p.x = bot.x - v.x;
          p.y = bot.y + v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x - v.x;
          p.y = bot.y - v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;
        }
        else {

          // das ist der Prototyp [n, m] (Fall 3 aus Teil 1)
          // mit der Vielfachheit 8
          p.x = bot.x + v.x;
          p.y = bot.y + v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x + v.x;
          p.y = bot.y - v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x - v.x;
          p.y = bot.y + v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x - v.x;
          p.y = bot.y - v.y;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x + v.y;
          p.y = bot.y + v.x;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x + v.y;
          p.y = bot.y - v.x;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x - v.y;
          p.y = bot.y + v.x;
          if (is_inside_and_not_wall(p))  src[l++] = p;

          p.x = bot.x - v.y;
          p.y = bot.y - v.x;
          if (is_inside_and_not_wall(p))  src[l++] = p;
        }

  return l;
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 21</em>
</div>

Die Funktion `intersect_point_arrays()` errechnet den Durchschnitt der Zielpositionen aus dem vorherigen Schritt (`n1` und `a1`) und dem aktuellen Schritt (`n2` und `a2`). Dabei werden nur Zielpositionen in Betracht gezogen, die eine maximale Manhattan-Distanz von `maxdist` haben. Diejenigen Positionen, die in beiden Mengen vorhanden sind, werden im Array `intsect` gespeichert, die Anzahl der Elemente gibt die Funktion zurück. Diese Funktion sorgt für eine Aussortierung der »falschen« Zielpositionen. Je schneller, sie den Wert 1 zurückgibt, desto besser.

```cpp
int intersect_point_arrays(const int& n1, point* a1, const int& n2, point* a2,
                           const int& maxdist, point* intsect)
{
  int nint = 0;
  bool found;

  for (int i = 0; i < n1; i++)
    for (int j = 0; j < n2; j++)
      if (mdist(a1[i], a2[j]) <= maxdist) {
        found = false;
        for (int m = 0; m < nint; m++)
          if ((intsect[m] == a1[i]) {
            found = true;
            break;
          }

        if (!found)
          intsect[nint++] = a1[i];
      }

  return nint;
}
```
<div style='margin-top: -0.75em; margin-bottom: 1em; font-size: 85%;'>
<em>Codefragment 22</em>
</div>

## Ein letzter Tipp

Bei der Entwicklung dieses Algorithmus war ich begeistert, welchen Zuwachs er an eingesammelten Gems gestattete. Dennoch gibt es immer noch zusätzliche Aspekte, die seine Performance steigen lassen. Dies war die Erkenntnis, dass es hier allemal besser ist, den Bot auf einem Zig-Zag-Kurs laufen zu lassen als geradlinig. Wenn man also mehrere gleich gute Möglichkeiten für den nächsten Schritt des Bots hat, sollte man diejenige nehmen, die gegenüber der vorherigen Richtung um 90° gedreht ist. Warum das so ist, sei dem Leser als Hausaufgabe überlassen. :-)

## Schlussbemerkung

Diese Funktionen können sicher noch optimiert werden. Ich muss feststellen, dass es einen großen Unterschied macht, ob man »nur für sich« programmiert und damit zufrieden ist, wenn alles korrekt läuft, oder ob man seinen Programmcode veröffentlichen möchte. Letzteres ist sehr aufwändig, man möchte sich ja schließlich nicht all zu sehr blamieren. Ich möchte anmerken, dass mir die rasche Publikation der zugrundeliegenden Ideen wichtiger war als eine ausgereifte Implementation. In der Hoffnung, dass der Blog einigen Teilnehmer:innen trotz (hoffentlich weniger) kleinerer Fehler und Ungenauigkeiten geholfen hat, lege ich den Stift erstmal nieder.
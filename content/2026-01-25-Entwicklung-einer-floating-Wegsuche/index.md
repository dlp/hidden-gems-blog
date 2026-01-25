---
author: Edgar (Zong)
author_bio: >
  Dipl-Informatiker
  Rentner
tags: ["Wegfindung", "floating", "Algorithmus"]
---

# Bau eines floating Algorithmus zur Wegfindung

Algorithmen zur Wegfindung gibt es fast so viele wie Sandkörner im Ganges.

Besonders bekannt und beliebt sind `BFS` und `A*`. 

(Ich habe für den Blog nachgeschaut, wie diese arbeiten und ob sie nicht identisch sind.)

Wir wollen hier gemeinsam einen einfachen Algorithmus entwickeln, der schneller ist als `BFS` und mehr Informationen bereitstellt.

*Hier kann man erkennen, wie ich an ein Problem herangehe und es löse. Heutzutage gibt es natürlich ganz andere Verfahren, weshalb ich mich schon einmal bei Michael Specht entschuldigen möchte.*

## Ziele

Ausgehend von einer Startposition soll der Algorithmus folgende Informationen liefern:
- Wie weit es zu **jedem** anderen Feld auf der Karte ist.
- In welche **Richtung** muss der Bot gehen.
- Gibt es eine **zweite Richtung**, in der der Weg gleich weit ist?

Er soll außerdem einfach für andere Bedürfnisse erweiterbar sein.

Es wird nur der **kürzeste** Weg berücksichtigt.

Eine Bewertung des Weges ist nicht enthalten. Im Anschluss kann der Leser jedoch eine solche Bewertung oder andere Funktionen hinzufügen.

Warum zu jedem Feld?

Wir lassen ihn einmal von der Bot-Position aus laufen und erhalten dann Informationen zu jedem Gem oder anderen Feldern, die uns interessieren, ohne erneut eine Wegfindung machen zu müssen.

Warum nur erhalten wir nur den ersten Schritt?

Bei jedem Tick ändert sich etwas, und dann berechne ich sowieso neu.

Warum eine zweite Richtung?

Wenn unser Algorithmus sagt, dass der Bot zu dem Feld zurückgehen soll, von dem er kam (weil sich beispielsweise das Ziel geändert hat), könnten wir über eine andere Richtung neue Informationen über die Signale erhalten.

## ein paar Definitionen

Zu Beginn überlegen wir, welche Daten wir wo und wie speichern möchten. Das hat den Vorteil, dass wir beim Coden nicht vergessen, ein Attribut auszufüllen.

- `Pos` ist ein unsigned integer und enthält die X- und Y-Koordinate in der Form Y << 6 | X. Hier ist jedoch Vorsicht geboten, da eine Beschränkung auf eine Kartengröße von maximal 64 in X-Richtung besteht.
- `StartPosition` ist der Ausgangspunkt, von dem aus wir die Wege berechnen wollen.
- `Karte` ist ein Vektor mit einer Größe von (Y-Größe der Karte mulipliziert mit 64). Er enthält alle Informationen, die wir über die Karte haben.
- `WegKarte` ist ein temporärer Vektor. Er dient als Kopie der Karte zum „Bemalen”.
- Karte und WegKarte können die Elemente `WAND`, `BODEN` und `BESUCHT` enthalten. (Der Leser kann gerne auch das Element `UNBEKANNT` hinzufügen.).
- `Wege` ist unser Ergebnisvektor, der die Dimension der Karte hat. Er enthält die Attribute Distanz (Weglänge), Schritt (erster Schritt zu diesem Feld) und SchrittAlternativ (alternativer Schritt zu diesem Feld). Die Position des Feldes entspricht dem Vektorindex.
- `Puffer` ist ein Hilfsvektor mit der Dimension der Karte und enthält nur Positionen.

Keine Sorge, hier können wir immer zurückschauen, wenn etwas benutzt wird.

## einfacher Algorithmus

Wir starten erst einmal ganz einfach ohne den zweiten Schritt und erweitern dann später.

### Variablen Deklaration

Zunächst übertragen wir die Definitionen (siehe oben) in unsere Variablen.

```C
#define KARTENSIZE 64*40

enum FeldTyp {WAND, BODEN, BESUCHT};
FeldTyp Karte[KARTENSIZE], WegKarte[KARTENSIZE];

typedef struct {
  int Distanz;
  int Schritt;
  int SchrittAlternativ;
} TWege;
TWege Wege[KARTENSIZE];

Pos Puffer[KARTENSIZE];

char *Bewegung[] = {"N","W","S","E", "WAIT"};
int PosDelta[] = {-64, -1, 64, 1, 0};
```

Mit `PosDelta` können wir die Nachbarfelder bestimmen, sodass wir nicht alles viermal schreiben müssen.
`Bewegung` wird nicht benutzt und ist nur zum Verständnis von PosDelta aufgeführt.

Warum werden globale statt lokaler Variablen verwendet?

Lokale Variablen sind schneller, da in einem kleineren Adressraum gearbeitet wird.

Das Allokieren kostet bei den Größen Zeit. Außerdem enthalten die Strukturen viele Informationen, die wir später vielleicht nutzen möchten.

*Schlechter Stil, Seiteneffekte. Man sollte Referenzen an die Prozeduren übergeben. Entschuldige, Michael*

### Der erste Wegpunkt wird berechnet

Endlich ist die Buchhaltung erledigt und wir können uns dem Spaß widmen: dem Coden.

Zunächst kopieren wir die Karte in WegKarte und berechnen unseren ersten Wegpunkt.

```C
#define KEINSCHRITT 4

void WegBerechnung (Pos Startposition) {
  //Pointer auf Puffer aktuell und maximales Element.
  int WPakt = 0;
  int WPmax = 0;
  
  //Initialisieren von Wege wird verzichtet
  // for (int y = (Ymax - 1) * 64; y >= 0; y -= 64)
    // for (int x = Xmax -1 ; x >= 0; x--)
      // Wege[y | x].Distanz = -1;
  //Kopieren der Karte
  memcpy(WegKarte, Karte, sizeof(Karte));

  //erster Wegpunkt
  Wege[StartPosition].Distanz = 0;
  Wege[StartPosition].Schritt = KEINSCHRITT;  //bezieht sich auf Bewegung[]
  WegKarte[StartPosition] = BESUCHT;
  Puffer[WPmax] = StartPosition;
  
  //Hier kommen weitere Code Blöcke (siehe unten)
}
```

`WPakt` ist der aktuelle Pointer im Vektor `Puffer`.
`WPmax` ist der letzte Eintrag in `Puffer`.

In `WegKarte` haben wir das Feld mit `BESUCHT` markiert, weil es bereits berechnet wurde.

Im `Puffer` wird es gespeichert, da von hier aus weitere Felder erreichbar sein könnten.

Auf die Initialisierung von `Wege` wird verzichtet, da dies Performance kostet und wir später nur die Felder abfragen, die betreten werden können (Karte[p]==BODEN). Andere Felder können alte und falsche Werte enthalten, was nicht weiter stört.

### Die Nachbarfelder

Vom `Startpunkt` aus sind vier Felder erreichbar: Nord, Süd, Ost und West. (Siehe auch: `Bewegung`).

Das fällt uns sofort ein.

Wir könnten jedes einzeln codieren oder es über den Vektor `PosDelta` geschickt adressieren.

Also berechnen wir die vier Nachbarfelder vom `Startpunkt`.

```C
  for (i = 3; i >= 0; i--) {
    Pos p = Puffer[WPakt] + PosDelta[i];
    if (WegKarte[p] == BODEN) {
      Wege[p].Distanz = 1;
      Wege[p].Schritt = i;  //in i ist die Referenz auf Bewegung[]
      WegKarte[p] = BESUCHT;
      WPmax++;
      Puffer[WPmax] = p;
    }
  }
  WPakt++;
```

Das war doch einfach! Genauso wie bei der `Startposition`.

Wir haben `Distanz` und `Schritt` angepasst.

`WPmax` wird für jedes gültige Feld erhöht.

Am Schluss wird `WPakt` erhöht, weil wir den ersten Punkt in der Warteliste verarbeitet haben.

*Anmerkung: Die For-Schleife auf 0 laufen zu lassen, ist um ein bis zwei Maschinenbefehle schneller. Hier kann der Compiler die Reihenfolge nicht selbstständig umstellen, da sich sonst die Reihenfolge im Puffer ändern würde.*

### Die restlichen Felder

Nun fehlen nur noch die anderen Felder. Ihr ahnt es schon: Es geht genauso weiter.

Ein Feld aus `Puffer` wird genommen und die Nachbarfelder werden verarbeitet.

Dies wiederholen wir in einer Schleife, bis kein unverarbeitetes Feld mehr im Puffer vorhanden ist.

```C
  while (WPakt <= WPmax) {
    Pos p0 = Puffer[WPakt];
    int dist = Wege[p0].Distanz + 1;
    int schritt = Wege[p0].Schritt;
    for (i = 3; i >= 0; i--) {
      Pos p = p0 + PosDelta[i];
      // hier ist normalerweise ein Überprüfung, ob das Feld noch in der Karte ist
      // das lassen wir weg
      if (WegKarte[p] == BODEN) {
        Wege[p].Distanz = dist;
        Wege[p].Schritt = schritt;
        WegKarte[p] = BESUCHT;
        WPmax++;
        Puffer[WPmax] = p;
      }
    }
    WPakt++;
  }
```
*Anmerkung: Dies ist ein zusätzlicher Code Block. Nicht den Code Block der Nachbarfelder des Startpunktes überschreiben.*

Die `Distanz` wird nun vom Vorgänger-Feld berechnet und der Schritt übernommen. Wir speichern den ersten Schritt von der Startposition und nicht irgendeinen Zwischenschritt.

Die Überprüfung, ob die Position p noch in der Karte ist, können wir bei Hidden Gems weglassen, da wir immer eine mit Wänden umrandete Karte haben. Das spart reine Performance.

Wir nutzen hier aus, dass der Puffer durch das Füllen nach Distanz sortiert ist. (Wir fügen nur Werte hinzu, deren Distanz dem letzten Wert im Puffer gleich oder größer ist.) Dadurch brauchen wir keine Überprüfung der Distanz.

### Ende

Jetzt sind wir im Flow und es macht Spaß. Was kommt jetzt?

Das war's schon. Schade.

Eine einfache Wegberechnung auf Floating-Basis ist fertig.

Sie liefert die kürzeste Distanz und den ersten Schritt von der Startposition zu jedem erreichbaren Feld.

Das Attribut `SchrittAlternativ` ist nicht gefüllt.

Unser Ziel war es, einen alternativen Startpunkt zu erhalten. Dies werden wir in der ersten Erweiterung umsetzen.

### Unterschied zu BFS

Wir haben den Algorithmus entwickelt, einfach durch Nachdenken ohne Wissen über BFS. ;-)

Das Ganze sieht doch aus wie der BFS.

Ähnlich, ja, weil es sich bei beiden um Floating-Algorithmen handelt. Wir sehen jedoch Unterschiede zum BFS:
- BFS liefert den gesamten Weg zu einem Zielfeld. Wir hingegen nur die Distanz und den ersten Schritt zu jedem Feld.
- BFS speichert die Position und die Referenz zum Vorgängerfeld in einem Puffer. Die Distanz und der erste Schritt müssen später durch Rückrechnen des Weges berechnet werden. Wir speichern keinen Pointer, da wir nicht zurückrechnen müssen.
- BFS nutzt die Karte, um zu überprüfen, ob das Feld „BODEN” ist, und führt eine weitere Überprüfung durch, ob das Feld bereits verarbeitet wurde. Wir nutzen nur einen Vektor, denn „BESUCHT” ist ungleich „BODEN”.
- Zudem haben wir uns zunutze gemacht, dass die Karten in Hidden-Gems immer mit einer Wand umrandet sind.

Unser Algorithmus ist somit schneller als BFS.

## erste Erweiterung

In diesem Abschnitt lernen wir, wie sich der Algorithmus einfach erweitern lässt.

Eigentlich wollten wir doch auch wissen, ob es noch andere Richtungen mit gleicher Entfernung zum Zielfeld gibt und wenn ja, welche das sind.

Nun kommt wieder der schwierige Teil: Nachdenken, Planen, Entscheiden.

Auf einer Karte ohne Wände:
- Liegt das Zielfeld genau im Norden, gibt es nur einen ersten Schritt „Nord” auf dem kürzesten Weg.
- Liegt das Zielfeld im Nordosten, gibt es zwei Möglichkeiten.

Für die anderen Richtungen ist es identisch.

Mit Wänden sieht es anders aus. Es könnte einen Weg nach Nordost um die Mauer geben, der genauso lang ist wie nach Südosten oder sogar Südwesten. Somit könnten alle vier Schritte möglich sein.


Nachdenken fertig, also planen. Was wollen wir später?

In `Schritt` steht die Bewegung, die der Bot ausführen soll. Wenn es ein Schritt zurück wäre, würde ich keine neuen Informationen über die Signale erhalten. Es reicht mir also eine Alternative.


Entscheidung:

Im Feld `SchrittAlternativ` soll ein möglicher alternativer Schritt stehen. Gleiche Kodierung wie `Schritt`.
Hätten wir uns für alle Schritte entschieden, würden wir `int Schritt` durch `Bool Schritt[4]` ersetzen. Dies überlasse ich dem geneigten Leser.

### Startfeld

Beim Startfeld stetzen wir den alternaitven Schritt `SchrittAlternativ` auf `KEINSCHRITT`.

```C
  Wege[StartPosition].Distanz = 0;
  Wege[StartPosition].Schritt = KEINSCHRITT;
  WegKarte[StartPosition] = BESUCHT;
  Puffer[WPmax] = StartPosition;
  // neu
  Wege[StartPosition].SchrittAlternativ = KEINSCHRITT;
```

`KEINSCHRITT` zeigt an, dass es hier keinen alternativen Schritt gibt.

### Die Nachbarfelder von der Startposition

Die Nachbarfelder können nur von der Startposition in einem Schritt erreicht werden.

Auch hier gibt es keinen alternativen Schritt.

```C
    if (WegKarte[p] == BODEN) {
      Wege[p].Distanz = 1;
      Wege[p].Schritt = i;
      WegKarte[p] = BESUCHT;
      WPmax++;
      Puffer[WPmax] = p;
      // neu
      Wege[p].SchrittAlternativ = KEINSCHRITT;
    }
```

### Die restlichen Felder

Bei den restlichen Felder wird `SchrittAlternativ` vom Vorgänger übernommen.

```C
    int dist = Wege[p0].Distanz + 1;
    int schritt = Wege[p0].Schritt;
    // neu
    int schrittAlternativ = Wege[p0].SchrittAlternativ;
    for (i = 3; i >= 0; i--) {
      Pos p = p0 + PosDelta[i];
      // hier ist normalerweise ein Überprüfung, ob das Feld noch in der Karte ist
      // das lassen wir weg
      if (WegKarte[p] == BODEN) {
        Wege[p].Distanz = dist;
        Wege[p].Schritt = schritt;
        WegKarte[p] = BESUCHT;
        WPmax++;
        Puffer[WPmax] = p;
        // neu
        Wege[p].SchrittAlternativ = schrittAlternativ;
      }
    }
```

Aber halt! Andere Felder könnten von mehreren Seiten aus erreicht werden.

In diesem Fall steht in der `WegKarte` der Wert `BESUCHT`.

Der `Puffer` ist nach Distanz sortiert. Das bedeutet, dass ein bereits sortiertes Feld eine Distanz kleiner oder gleich hat. Da uns kein längerer Weg interessiert, ist nur „gleich lang” relevant.

Die Attribute außer „SchrittAlternativ” sind bereits gesetzt. Wir füllen also nur dieses aus.

Da uns nur ein alternativer Schritt interessiert, können wir diesen überspringen, wenn er bereits gesetzt ist.

```C
      if (WegKarte[p] == BODEN) {
      ...
      } else
      if ((Wege[p].SchrittAlternativ == KEINSCHRITT)
        && (WegKarte[p] == BESUCHT) && (Wege[p].Distanz == dist)) {
        if (Wege[p].Schritt != schritt)
          Wege[p].SchrittAlternativ = schritt;
        else
          Wege[p].SchrittAlternativ = schrittAlternativ;
          // falls beide KEINSCHRITT sind, gibt es hier keinen alternativen Weg. Eine Überprüfung ist unnötig
      }
```

*Anmerkung: für den Leser, der sich für "alle" entschieden hat, muß hier natürlich anders agieren*

### Ende

Das war's schon. So einfach haben wir unserem simplen Algorithmus den zweiten Schritt beigebracht. Das war so einfach, weil wir ihn selbst entwickelt haben und genau wussten, was er macht.

Um das gleiche Ergebnis für nur ein Zielfeld zu erhalten, müssten wir `A*` viermal ausführen. Da `A*` eine sortierte Puffer-Liste benötigt, dürften wir bei mittlerem Abstand zum Zielfeld schneller sein. Außerdem berechnen wir alle Felder.

Leider sind wir schon wieder am Ende.

## eine andere Erweiterung (komplette Wege)

Das hat doch Spaß gemacht bis jetzt. *oh Drohung, ich höre dich kommen*

Für den Bot ist der Algorithmus super: Er ist schnell und leistet alles, was er braucht.

Aber der arme Programmierer auf der anderen Seite des Bildschirms will etwas sehen und debuggen.

Da haben `BFS` und `A*` die große Stärke, dass sie den gesamten Weg anzeigen.

Da die letzte Erweiterung so einfach war, warum nicht den Algorithmus erweitern und auch die kompletten Wege speichern? *(Für alle Felder einen Weg vom Startfeld speichern – und das bei den gestiegenen Preisen für RAM!)*

### Ran ans Werk

Was haben wir, was brauchen wir?

Aus `Puffer[WPakt]` haben wir `Puffer[WPmax]` erstellt.

Das ist doch eine Liste und ruft förmlich nach einem Pointer zum Vorgänger.

Wir erweitern also `Puffer` um das Attribut `Parent`.


**Halt! Stop! Wir sind im Flow gefangen.**

Wir haben etwas wichtiges vergessen: Nachdenken.

Beinahe hätten wir unseren schönen Algorithmus in `BFS` verwandelt, mit all seinen Nachteilen.
Wir hätten einen Referenz-Vektor auf `Puffer` erstellt, ...


`p0` ist unsere Position, aus der wir die Felder `p` erstellen.

In `Wege[p]` muss also eine Referenz auf `p0` stehen.

`Parent` für Schritt und `ParentAlternativ` für den SchrittAlternativ.


Das Attribut `Parent` ist einfach zu bestimmen. Es ist `p0` bei der Erstellung.

Das Attribut `ParentAlternativ` ist schwieriger.

Die Nachbarfelder des Startpunkts haben keinen alternativen Schritt. Wenn wir später den Weg für den alternativen Schritt wissen wollen, nutzen wir `ParentAlternativ` als Pointer. Er muss also auch bei den Nachbarfeldern auf die Startposition zeigen.

Allgemein sind `Parent` und `ParentAlternativ` immer gleich, bis auf eine Ausnahme. Wird `SchrittAlternativ` verändert, muss `ParentAlternativ` auf dieses `p0` gesetzt werden. 

```C
typedef struct {
  int Distanz;
  int Schritt;
  int SchrittAlternativ;
  //neu
  int Parent;
  int ParentAlternativ;
} TWege;
...
// Startposition
Wege[StartPosition].Parent = -1;
Wege[StartPosition].ParentAlternativ = -1;
...
// Nachbarfelder der Startposition
      Wege[p].Parent = StartPosition;
      Wege[p].ParentAlternativ = StartPosition;
...
// sonstige Felder
      if (WegKarte[p] == BODEN) {
        ...
        Wege[p].Parent = p0;
        Wege[p].ParentAlternativ = p0;
      } else
      if ((Wege[p].SchrittAlternativ == KEINSCHRITT)
        && (WegKarte[p] == BESUCHT) && (Wege[p].Distanz == dist)) {
        ...
        Wege[p].ParentAlternativ = p0;
      }
...
```

Ich sehe, ihr habt kurz gedacht: Da ist ein Bug. Wenn in der letzten Zeile `schrittAlternativ` den Wert `KEINSCHRITT` hat und trotzdem übernommen wird. Aber dann ist euch aufgefallen, dass es zwar ein anderer Weg ist, aber immer noch ein gültiger. Bei diesem Feld gibt es noch keinen alternativen Schritt. Wenn später auf dem Weg ein Wert ungleich `KEINSCHRITT` gesetzt wird, wird dort eine Entscheidung getroffen.

### Ende

Das war es schon. So wird für jedes Feld der komplette Weg platzsparend gespeichert.

Hier wird deutlich, warum die Vektoren global definiert wurden.

So können wir jederzeit darauf zugreifen.

# Anregungen

`A*` kann den Weg auch bewerten und den „besten” suchen. Es gibt auch Floating-Algorithmen, die dies können.

Wir können den Algorithmus einfach erweitern, um auch eine bewertete Wegsuche durchzuführen. Natürlich hat der kürzeste Weg dabei die höchste Priorität. Dazu müssen wir ein neues Attribut „Bewertung” und eine Bewertungsfunktion hinzufügen. Die erste Erweiterung muss nur ein wenig umgeschrieben werden. Das sollte für euch schnell erledigt sein.

Am Anfang erwähnte ich, dass die Karte nur aus WAND und BODEN besteht. Unbekannte Felder könnt ihr jetzt ohne Probleme hinzufügen.

Wenn ihr sonst irgendwelche Ideen habt, versucht euch daran. Coding macht Spaß.

Gerüchte besagen, dass es irgendwann Portale geben wird. Ich sehe es euch schon sagen: „Diese Stelle muss ich ändern, damit er auch Portale kann.”


# Fazit

Wir haben einen einfachen, schnellen, leicht anpassbaren Algorithmus zur Wegberechnung erstellt, der vieles leistet. Nur Kaffeekochen kann er nicht. Und einen Kaffee gehe ich mir jetzt holen.

**Ich hoffe, dass euch das Lesen genauso viel Spaß gemacht hat wie mir das Schreiben.**

*Zur Performance kann ich sagen, dass ich in Stage 1 nach der Kartenerkundung für den Cache die Prozedur „jedes Feld als Startposition” habe laufen lassen. Dies hat ca. 10 ms gedauert. In Stage 2 werde ich das nicht mehr machen, da die Karte doppelt so groß ist und die Zeit des Algorithmus mit dem Quadrat steigt, also 40 ms. Ich nutze ihn nur für die Felder, die ich benötige, ohne zu cachen*

---
author: Edgar (Zong)
author_bio: >
  Dipl-Informatiker
  Rentner
tags: ["Erfahrungsbericht", "Stage 2", "Entwicklung", "Konzept"]
---

# Erfahrungsbericht: Einstieg in Stage 2

## Einleitung

Hier möchte ich beschreiben, wie ich meinen Bot für Stage 2 entwickelt habe. Dabei geht es weniger um konkrete Lösungen als um die Art und Weise, wie ich das Problem angehe und löse.

<div class="alert alert-info">
<em>Disclaimer:</em> Dieser Blog richtet sich vor allem an Schüler und Mitspieler, die noch nicht viel Erfahrung mit dem Programmieren haben. Ich zeige, wie ich als „alter Hase” an ein solches Problem herangehe und es in einfache, schnell zu lösende Teile zerlege. Programmcode oder eine genaue Beschreibung meiner Umsetzung sucht ihr deshalb vergeblich.
</div>

Wenn ihr die Herausforderung ähnlich oder genauso angegangen seid, freut mich das, auch wenn ich euch nichts Neues erzählen kann. Anderenfalls könntet ihr bei zukünftigen Aufgaben überlegen, diese ähnlich anzugehen und dabei Spaß zu haben.  

## Änderungen in Stage 2

In Stage 2 gab es neue Herausforderungen:
- Die Karte wurde vergrössert.
- Die Sicht wurde eingeschränkt auf 5 bis 15 Felder.
- Neue Felder in der JSON Datei.
- Die Gems senden ein Signal aus.
- Es sind in Version 0.1 direkt 2 bis 3 Gems möglich.

Ansonsten blieb es bei der Map (generator) cellular. Wie in Stage 1 haben wir es also wieder mit Wänden und Wegfindung zu tun. Alles ist in der Dokumentation unter [https://hiddengems.gymnasiumsteglitz.de/stages](https://hiddengems.gymnasiumsteglitz.de/stages) beschrieben.

## Die ersteren Schritte

### Die Karte wurde vergrössert

Die Karte hat nun 49 × 29 Felder. Ich finde es gut, dass die Karte bereits in Version v0.1 auf die maximale Größe gesetzt wird. In den Stages 0 und 1 gab es die Größenänderung erst in Version v0.2, was zu Performanceproblemen bei einigen Mitspielern führte. Diese Probleme mussten in den letzten zwei Wochen gelöst werden.

Die Änderungen im Programm sind schnell erledigt. Ich nutze feste Array- und Vektorgrößen. Dafür muss ich lediglich zwei Konstanten (`#define`) ändern. Alles wird über diese gesteuert. Ich verwende hierfür nie feste Zahlen. Die realen Werte der Karte lese ich natürlich weiterhin aus der JSON-Datei aus.

Mit 49 x 29 Feldern ist die Anzahl fast doppelt so hoch wie in Stage 1. Da einige Algorithmen mit O(N x N) skalieren, bedeutet dies eine vierfache Laufzeit. Ich muss später also auf die Laufzeit achten. Ich mache mir einen Knoten ins Taschentuch – ich bin schon älter.

### Die Sicht wurde eingeschränkt auf 5 bis 15 Felder

Die Einschränkung der Sicht auf fünf bis 15 Felder ist zunächst nur interessant, wenn jemand eine eigene Visibility-Berechnung durchführt. Bisher war sie fest auf 100 eingestellt, weshalb ich sie nie aus der JSON-Datei gelesen, sondern einer Variablen fest zugewiesen habe. Die Änderung ist schnell erledigt.
Eine eigene Visibility-Berechnung ist eigentlich nicht mehr notwendig.

Anekdote am Rande: Ich interpretierte „visibility 5” so, dass mein Bot fünf Felder weit sieht. Beim Erkunden der Karte ging er einmal auf ein Feld zu, das er sehen wollte. Er blieb fünf Felder links davon stehen und erwartete, dass der Runner ihm das Feld zeigt. Der Runner meinte jedoch: „Du bist fünf Felder weg, also zeige ich es dir nicht.” Der Bot meinte, er korrigiere seine Position. Und zwar 5 Felder links vom Feld. Da stünde er schon. Und müsse es jetzt sehen. Der Runner sagte: „Nein, du bist fünf Felder weg, das Feld siehst du nicht.” ...

Man sollte Annahmen immer kontrollieren. Ein „<=" in ein „<” geändert und die beiden haben sich wieder verstanden.
„Visibility 5” bedeutet, dass man alles sieht, was weniger als 5 entfernt ist, also auch 4,99. Dadurch ergibt sich ein schöner Kreis ohne seltsame Spitzen oben, unten, links und rechts.

### Neue Felder in der JSON Datei

Nun kommt mein Bot zum ersten Mal zum Einsatz. Er erhält die neue JSON-Datei vom Runner und schreibt sie in eine Datei. Anschließend beendet er sich sofort. Das gleiche mache ich später noch einmal, wenn das erste Signal kommt. Aus der Datei kann ich die Parameternamen einfach kopieren, ohne sie von der Webseite abschreiben zu müssen. Beim zweiten Lauf des Bots darf er die neuen Werte über stderr ausgeben, die ich dann mit der JSON-Datei kontrolliere.

### Die Signale
Bisher gab es nichts Neues zu lernen, nur langweilige Buchhaltung. Kommen wir jetzt zu dem Teil, der euch mehr interessiert und Spaß macht – zumindest mir und hoffentlich auch euch in Zukunft.

### Erster Gem

Die Gems senden Signale aus, deren Stärke mit zunehmender Entfernung meines Bots von ihnen abnimmt. Dafür schreibe ich eine kleine Funktion, die die Signalstärke am Bot ausgibt, als wäre ein Gem im Eingabefeld. Die Funktion wird jetzt nicht getestet. Es wäre zu aufwendig, jedes Mal die Position eines Gems abzählen und dann nachzurechnen. Der Test folgt später.

Wenn ein Signal erscheint, kann ich nun jedes Feld auf der Karte überprüfen und sehen, ob das Signal übereinstimmt. Wenn ja, wird das Feld rot markiert. Das Ganze kommt in eine kleine Prozedur. Ja, ich prüfe jedes Feld mit Brute Force, denn die Laufzeit ist mir noch egal. Anmerkung: „Übereinstimmen” bedeutet bei Fließkommazahlen nicht, dass sie gleich sind, sondern dass sie sich beide innerhalb eines kleinen Fehlerintervalls befinden. Das ist nötig, weil bei Fließkommazahlen immer Rundungsfehler auftreten.

Nun führe ich noch einige Vereinfachungen durch, da ich nur einen Gem lokalisieren möchte und mich nicht mit anderen Dingen herumschlagen will. Deshalb entferne ich die Wände und nehme die schöne Map aus Stage 0 (Runner-Parameter `--generator arena`). Außerdem möchte ich verhindern, dass ein zweiter Gem erscheint (Runner-Parameter `--max_gems 1`). Mein Bot darf sich bewegen, wie er will (random) und soll das Gem nicht einsammeln.

Der Runner wird gestartet und der Bot tanzt fröhlich umher. Sobald ein Gem erscheint, sind einige wenige rote Punkte zu sehen, die auf einem Kreis liegen. Mit jeder Bewegung des Bots ändern sich die Positionen der Punkte. Nur das Feld mit dem Gem ist immer rot markiert. Der Test meiner Signalfunktion ist zunächst erfolgreich, später folgt ein weiterer Test.

Beim zweiten Tick muss ich nicht alle Felder kontrollieren, sondern nur die roten des ersten. Diese werden in eine Liste aufgenommen, die beim nächsten Tick überprüft wird. Wenn nur noch ein Feld übrig ist, ist der Gem lokalisiert. Danach darf der Bot die Position wieder vergessen und die Lokalisierung neu starten.

Im nächsten Schritt lasse ich den Bot längere Strecken laufen, um zu sehen, ob es bei anderen Entfernungen genauso gut funktioniert. Dabei fällt mir auf, dass es passieren kann, dass zwei Felder in der Liste bleiben, wenn der Bot lange in eine Richtung geht. Ein kleiner Schritt nach links oder rechts zwischendurch löst das Problem. Ein weiterer Knoten ins Taschentuch. (Im letzten Jahrtausend gab es große Stofftaschentücher, da passen viele Knoten rein. Und mit Knoten wurden die Inkas auch zur Großmacht.)

Zusätzlich zeigt sich, dass die Signalfunktion bei unterschiedlichen Entfernungen korrekt arbeitet. Der Test ist beendet.

### Nun fehlt noch der Abschußtest: Wände

Wenn man den Parameter `--generator arena` weglässt, sind auf einmal Wände da. Allerdings hat mein Bot noch nie einen Weg in unbekanntes Gebiet geplant. Es gibt zwei Möglichkeiten: Entweder er sucht so lange einen Weg auf bekanntem Gebiet (das sich durch die Sicht erweitert) oder ich lasse ihn Indiana Jones spielen und er darf unbekanntes Gebiet als betretbar planen. Letzteres erfordert nur die Änderung einer Zeile und ist somit einen Test wert.

Nun darf der Bot endlich auch Gems sammeln gehen – von irgendetwas müssen wir schließlich die Stromrechnung bezahlen. Die Wegplanung funktioniert hervorragend. Taucht plötzlich eine Wand auf, plant er sofort einen neuen, guten Weg. Man könnte meinen, er hätte sein Leben lang nichts anderes gemacht. Auf jeden Fall besser, als wenn ich es ihm in hunderten von Zeilen beibringen würde.

Mir fällt außerdem auf, dass rote Punkte auf Wänden oder in unzugänglichen Gebieten erscheinen. Dort können sich keine Gems befinden. Nein, diesmal kein Knoten ins Taschentuch, die Codezeile wird sofort eingebaut, auch wenn sie vielleicht erst später zieht.

Jetzt muss er nur noch commiten und er startet in den Scrims. Aber halt, da war noch etwas: `--max_gems 1` gibt es nicht. Ein kurzer Test zeigt außerdem, dass der Bot die Gems nicht so schnell einsammelt, sodass immer nur einer auf der Karte ist. Bei zwei Gems liefert die Erkennung falsche Felder, die nach der ersten Bewegung alle verschwinden. Also weiter.

### Zwei Gems

Also die Gegebenheiten wieder einfacher machen. Es gibt keine Wände, `max_gems` ist auf 2 gesetzt und der Bot sammelt keine Gems ein, sondern darf wieder tanzen. Da ich für einen Gem ein gutes Verfahren habe, konzentriere ich mich nur darauf, zwei Gems zu lokalisieren. Jetzt muss das Signal in zwei Signale zerlegt werden. Aber wie? Klar, in einen größeren und einen kleineren Teil. Mich interessiert nur, wo sich der nähere Gem befindet, denn diesen wird mein Bot später zuerst einsammeln. Die Position des anderen Gems kann ich nach dem Einsammeln bestimmen.

Eine Prozedur markiert alle Felder blau, deren Signal zwischen dem empfangenen Signal und dessen Hälfte liegt. Natürlich mit den Lookup-Tabellen. Der Bot tanzt herum. Sobald der erste Gem erscheint, färben sich viele Felder blau. Es ist ein breiter Ring um den Bot. Der Gem ist blau eingefärbt. Der Ring bewegt sich zwar beim Bewegen des Bots, aber im Gegensatz zu Gem1 ist die Schnittmenge über 90 %. Das war ein Gem, der hier nicht interessiert.

Der zweite Gem erscheint und mein Bot tanzt weiter vor Freude. Ich sehe, dass sich der Ring wie erwartet verschmälert hat und näher an den Bot gerückt ist. Der nahe Gem ist weiterhin blau gefärbt. Die Schnittmenge bleibt weiterhin bei über 90 %. Es muss also noch nach anderen Kriterien gefiltert werden.

Die Information, dass das Restsignal nicht vom nahen Gem stammt, habe ich bisher außer Acht gelassen. Wenn ich überprüfe, ob es für dieses ein gültiges Feld für den zweiten Gem gibt, verschwinden einige blaue Felder. Der Ring bekommt Löcher und sieht aus wie ein Emmentaler Käse. Mein Bot steht unten nahe der Mitte der Karte und der Ring ist eigentlich ein schöner Kreisbogen. Fast wie ein Regenbogen, wenn er bunt gefärbt wäre. Nach vielen Time-Warp-Schritten hat er einige Löcher, aber weder mein Bot noch ich können erkennen, ob sich der Gem links, rechts oder oben befindet. 

Ein Fehlschlag – sofort vergessen und neu beginnen.

### Neuer Versuch

Der neue Ansatz besteht darin, aus der Vergangenheit zu lernen (bei meinem Alter habe ich da noch viel vor mir, aber der Bot ist noch jung). Die Idee ist: Wenn der Bot auf den Gem zugeht, steigt das Signal; wenn er sich entfernt, sinkt es. Da nur der nahe gelegene Gem betrachtet wird, ist dessen Änderung am Signal stärker als die des anderen Gems. Felder, die diese Bedingung nicht erfüllen, werden entfernt.

Durch die zufällige Bewegung wird die Richtung schnell klar, eine genaue Lokalisierung findet jedoch nicht statt. Ich lasse den Bot nun in diese Richtung laufen. Als Ziel wird ein Mittelwert zwischen drei zufälligen Feldern gewählt. Um das Wechseln zwischen zwei Zielen zu verringern, wird das alte Ziel mit in die Berechnung einbezogen. Je näher der Bot dem Zielgebiet kommt, desto kleiner wird dieses.

Das Ganze sieht etwas aus, wie  „Laufe in die Richtung, in der das Signal stärker wird.” Der Unterschied ist, dass der Bot das Ziel auch bei schwächer werdendem Signal weiter eingrenzt. Ansonsten sind die Konzepte sehr ähnlich.

Zur Verbesserung fließt die letzte Information, der Signalrest, noch in eine Wahrscheinlichkeits-Berechnung des Feldes ein. Zum Vergessen nehme ich 50 % des alten Wertes plus 50 % des neuen Wertes. Das beschleunigt die Eingrenzung des Zielgebietes deutlich.

### Wände

Nun werden wieder Wände auf die Karte gesetzt. Die einzige temporäre Änderung ist, dass der Bot wartet, bis sich das Signal zweimal erhöht hat. Erst dann sind zwei Gems auf der Karte. (Nach dem vielen Rumgelaufe freut sich der Bot über eine kleine Pause.) Und so motiviert sammelt der Bot die ersten Gems schnell ein. Die Wände stören am Anfang nicht, aber später, wenn die Karte mehr und mehr erkundet wird. Das berechnete Zielfeld liegt sehr oft in einem unerreichbaren Gebiet und der Bot findet keinen Weg dorthin.

Die einfache Zielberechnung durch Mittelung von drei Feldern muss einer anderen Methode weichen. Ich entscheide mich dafür, ein erreichbares Feld mit hoher Wahrscheinlichkeit und genügend anderen blauen Feldern in der Umgebung zu wählen. Dass die Zielfindung aufwändiger ist als das Signal zu finden, ärgert mich. Hier muss ich später noch einmal ran. Knoten ins Taschentuch.

In meinem vorherigen [Blogbeitrag](https://hiddengems.gymnasiumsteglitz.de/blog/2026-01-27-entwicklung-einer-floating-wegsuche) habe ich einen Wegfindungsalgorithmus beschrieben, der in einer einzigen Berechnung alle erreichbaren Felder findet. Das Ergebnis nutze ich nun, um weitere blaue Felder auszuschließen, wenn sie nicht erreichbar sind. Es ist lediglich eine Abfrage im Vektor erforderlich. Beim Test zeigt sich jedoch, dass, wenn der Gem zu dicht an einer Wand liegt, zu viel des Zielgebietes entfernt wird und ich kein gutes Ziel für den Bot erhalte. Deshalb wird die Abfrage entfernt.

Wenn der Bot eine Gem einsammelt, erscheint in der Regel direkt ein neuer und die Berechnung läuft. Erscheint er jedoch erst einige Ticks später, führt das neue Signal die Zielberechnung in die Irre. Deshalb wird bei starken Signaländerungen nach oben oder unten die Berechnung zurückgesetzt und neu gestartet.

## Drei Gems

Zurück zu unserer einfachen Karte ohne Wände: Der Bot wartet nun auf drei Signalerhöhungen. Da ich bei der Berechnung für zwei Gems nichts auf die Anzahl der vorhandenen Gems programmiert habe, lasse ich den Code erst einmal unverändert laufen. Es zeigt sich, dass es manchmal etwas länger dauert, das Zielgebiet einzugrenzen. Wenn die beiden entfernten Gems jedoch auf gegenüberliegenden Seiten des Bots liegen, geht dies sogar schneller, weil sich deren Signalfehler gegenseitig ausgleichen.

Doch dann geschah plötzlich etwas Überraschendes: Mein Bot entschied sich, nicht auf den nahen Gem zu gehen. Links war der nahe Gem und rechts lagen zwei weitere Gem, die nicht weit voneinander entfernt waren. Diese beiden nahm er ins Visier und sammelte sie ein. Ihr gemeinsames Signal war stärker als das des nahen Gems. Eine Priorisierung der Gems, die ich eigentlich erst später bei der Zielfindung programmieren wollte. Ein schlauer Bot.

Für drei Gems muß nichts geändert werden. Die Routine für zwei Gems kann hingegen ohne neuen Parameter benutzt werden.

## Zusammenbau

In meinem Baukasten habe ich nun ein Teil für die Lokalisierung eines Gems und ein Teil für zwei oder drei Gems. Zusätzlich habe ich die Kartenerkundung, Wegfindung und Gegnerausweichen aus Stage 1 sowie die Zielauswahl aus Stage 0.

Die Kartenerkundung findet immer dann statt, wenn kein Signal vorhanden ist. Ab einer bestimmten Runde soll mein Bot nicht weiter erkunden, sondern tanzen. Zu diesem Zeitpunkt ist die Karte bereits in den wichtigen Teilen erkundet und er würde nur in irgendwelchen Ecken verschwinden, weit weg vom Geschehen. Er darf dann einen Gem-Tanz aufführen. Den hat er bei der Entwicklung lange genug geübt.

Der Bot nutzt die Lokalisierung eines Gems, um sich den Gem zu merken, wenn ein Signal auftritt. Tritt eine starke Signalveränderung auf, wird diese zusammen mit dem Signalrest gestartet. So kann mein Bot auch einen zweiten oder dritten Gem schnell finden. Schlägt die Lokalisierung fehl, weil kein Ziel gefunden wurde, wird die Routine für zwei oder mehr Gems gestartet.

Kennt der Bot mehrere Gems, nutzt er die Zielauswahl aus Stage 0. Nicht erkannte Gems spielen hierbei keine Rolle, solange ein Gem bekannt ist. Befinden sich mehrere unbekannte Gems auf der Karte, macht der Bot einen Schritt nach links oder rechts („Let's do the time-warp again”).

Ich schaue mir nun ein paar Seeds an, kann aber nichts Unauffälliges erkennen. Der Abschlusstest ist der Seed mit den 20 Runden von gestern. Dabei achte ich auf den Score und die medianen und maximalen Zeitwerte der einzelnen Runden. Beim Score überrascht mich der Bot ein weiteres Mal. Er ist nur 10 % schlechter als der Top-Bot von gestern. Die Laufzeiten sind ebenfalls überraschend niedrig. Hochgerechnet auf den Scrim-Server liegen sie bei 3 bis 5 ms (Median) sowie bei 20 bis 25 ms (Maximum). Ich kenne den Multiplikator für die Zeiten zwischen meinem Rechner und dem Scrim-Server.

Nach einer letzten Kontrolle der Knoten im Taschentuch ist klar: Die Laufzeit ist in Ordnung, der Seitenschritt zur Lokalisierung auch. Eine neue Zielfindung fehlt allerdings und wird später nachgereicht. Also wird der Bot eingecheckt und darf ab morgen in den Scrims Spaß haben. Wenn er weiterhin so gut abschneidet, gibt es täglich eine Extraportion Akkupower.

Der Bot mit diesem Code lief vom 8. Januar bis zum 31. Januar und hielt sich bis zuletzt zwischen Platz 10 und 20. Er freute sich täglich über eine kleine Belohnung. Die Laufzeiten habe ich täglich überprüft. In Ausnahmefällen stieg der Maximalwert ab und zu auf 60 bis 90 ms. Am 1. Februar wurde er jedoch durch eine komplett neue Version ersetzt.

Der liebe Bot wird aber nicht eingemottet, sondern ist der Sparringspartner des Neuen. Und er macht dem das Leben richtig schwer. ;-)

## Zukunft des Bots

Der Bot ist an einem Tag entstanden – und das sieht man auch am Code.
Im Anschluss habe ich jedoch jedes einzelne Teil noch einmal überarbeitet. Begonnen habe ich mit der Hauptroutine, die die anderen Routinen aufruft, und bin dann bis hinunter zum Ausweichen vorgegangen. Ich habe jedes Teil nacheinander in kleine, einfache Schritte zerlegt und gelöst.

Ein Beispiel ist die Ein-Gem-Routine. Sie wird aufgerufen, wenn das Signal nicht mehr korrekt ist. Bislang startete sie die Suche nach einem Gem. War diese erfolglos, endete die Routine. Nun hat sie jedoch viel mehr Aufgaben zu erledigen. 

Wenn das Signal zu klein ausfällt, bedeutet dies, dass ein Gem verschwunden ist. (Wenn der Bot oder der sichtbare Gegner diesen eingesammelt haben, wird er bereits an anderer Stelle verarbeitet.) Der verschwundene Gem kann über sein Signal leicht ermittelt werden. Es können jedoch auch mehrere Gems die gleiche Distanz haben, sodass es nicht mehr eindeutig ist. In diesem Fall muss er der Hauptroutine mitteilen, dass er gerne einen Schritt nach Osten/Westen oder Norden/Süden machen möchte und sich die Gems merken.

Das ist jedoch nicht der einzige oder der normale Fall, wenn das Signal ausfällt. Oft wird beim Verschwinden eines Gems ein neuer erzeugt. Das Signal vermischt sich. Nun muss die Routine testen, welcher Gem verschwunden sein kann und wo ein neuer entstanden wäre. Dieser kann natürlich nicht in dem Tick lokalisiert werden. Auch hier gibt es keine Eindeutigkeit. 

Die alte Ein- Gem-Routine kann also nicht die Liste des letzten Ticks benutzen, sondern wird so verändert, dass sie mit dem Signalfehler des letzten und des aktuellen Ticks die Berechnung für beide durchführt. Sie muss aber auch in der Lage sein, über mehrere Ticks eine Liste abzuarbeiten. Ohne zu früh um Hilfe zu rufen.

Im nächsten Tick kann wieder ein Gem entstehen. Es kann aber auch einer verschwinden. Die Signalverfolgung ist also wieder ein großer Teil, der sich wunderbar in kleinere Teile zerlegen lässt. Das Testen ist nicht ganz so einfach wie früher, weil viele Spezialfälle beachtet werden müssen und es schwierig ist, Seeds für diese zu finden. Hier behelfe ich mir, indem ich Test-Gems erzeuge und immer den gleichen Seed auf der Karte ohne Wände verwende.

Die Test-Gems erzeuge ich, indem ich das Signal des Runners ignoriere. Die Felder mit den Test-Gems werden rosa eingefärbt und dem Bot wird das Signal mitgeteilt, das diese Gems erzeugt. So kann ich beliebig Gems erzeugen und verschwinden lassen. Das funktioniert allerdings nur auf einer Karte ohne Wände, da die Gems sonst auf unerreichbarem Gebiet stehen könnten.

Das Finden von zwei oder drei Gems wurde durch ein neues Verfahren ersetzt, das sie in drei bis fünf Ticks lokalisiert. Dadurch musste hier keine neue Zielfindung programmiert werden. Es kommt jedoch in einem Run nur selten zum Einsatz.

Da die Berechnungen komplex werden können, führe ich nach jeder Programmierung eines Teils einen Test mit einem Scrim (20 Runden) durch, um zu sehen, ob sich der Score verändert hat und ob die Laufzeiten gestiegen sind. Dafür habe ich ein kleines Tool geschrieben, das den Runner startet, die JSON-Datei automatisch auswertet und die Werte mit dem letzten Lauf vergleicht.

## Ende

Wie ihr seht, zerlege ich ein Problem immer in kleine, einfache Teile, die jeweils nur eine bestimmte Teilaufgabe lösen sollen. Dabei wird das Umfeld so weit wie möglich vereinfacht. Erst später kommt der komplexe Kontext hinzu und es wird untersucht, ob mehrere Teile zu einem zusammengeführt werden können.

Jetzt mache ich Schluss, denn die neue Version des Bots hat sich in den Scrims nicht nur extra Power, sondern auch eine besondere Überraschung verdient. Meint ihr, er würde sich über eine RGB-Beleuchtung freuen? Ich hoffe, ihr hattet Spaß beim Lesen und habt mein Vorgehen ansatzweise verstanden. Vielleicht hilft es euch einmal in der Zukunft und ihr könnt sagen: „Wenn so ein alter Hase wie der Zong das so macht, kann ich das auch.”

Ein Lob geht auch an dich, lieber Leser, dass du bis jetzt durchgehalten hast. Im Coden bin ich zwar gut, aber Prosa ist nicht meine Stärke. Ich wünsche dir und deinem Bot viel Erfolg bei dem schönen Contest.

Edgar (Zong)

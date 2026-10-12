# Lingora 🌍

App iOS nativa (SwiftUI) per imparare **le lingue che la gente chiede e che nessuna
grande app insegna**, dall'A1 al B2, nello stile di Duolingo: un percorso a tappe
diviso in livelli → unità → lezioni, con esercizi di lettura, scrittura, ascolto e
parlato, flashcard, videochiamate con Anorcha e capitoli di sola scrittura.

**L'app è in inglese** e ogni corso è insegnato a partire dall'inglese.

| Corso | Stato | Alfabeto | Voce | Riconoscimento vocale |
|---|---|---|---|---|
| 🇹🇭 Thai | contenuti in scrittura | thai + traslitterazione | sì | sì (Apple) |
| 🇮🇷 Persiano | contenuti in scrittura | persiano (da destra) + traslitterazione | sì | no: pronuncia spenta |
| 🇵🇭 Tagalog | da scrivere | latino | sì | no: pronuncia spenta |
| 🇲🇾 Malese | da scrivere | latino | sì | sì (Apple) |
| 🇺🇿 Uzbeko | **completo** A1–B2 | latino | sì | sì (modello sul telefono) |

Le altre lingue della lista (cantonese, punjabi, tamil, telugu, malayalam, kannada,
curdo kurmanji e sorani, mongolo, khmer, lao, kazako, kirghiso, azero, georgiano,
armeno, urdu, bengalese) compaiono nell'app come *Coming soon*. Punjabi, curdo,
kirghiso e armeno non hanno una voce neurale gratuita: arriveranno senza ascolto e
pronuncia.

Il nome del progetto Xcode, del target e il bundle identifier (`com.uzbelia.app`)
restano quelli di prima, così firma, account Apple/Google e Firebase continuano a
funzionare; il nome mostrato sul telefono è **Lingora**.

---

## Come aprirla ed eseguirla

```bash
open Uzbelia.xcodeproj
```

Poi in Xcode: seleziona un simulatore iPhone e premi ⌘R. Da riga di comando:

```bash
xcodebuild -project Uzbelia.xcodeproj -scheme Uzbelia -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Test (contenuti + motore degli esercizi):

```bash
xcodebuild -project Uzbelia.xcodeproj -scheme Uzbelia -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

### Installarla sul telefono

1. Collega l'iPhone al Mac e sbloccalo.
2. In Xcode: **Uzbelia** (icona blu in alto a sinistra) → **Signing & Capabilities** →
   **Team**: scegli il tuo Apple ID. Se non c'è, aggiungilo da **Xcode → Settings →
   Accounts → +**; se compare un errore di login, rifai il login lì (serve la password
   dell'Apple ID e il codice a due fattori).
3. Se Xcode dice che il bundle identifier non è disponibile, cambialo in
   **Signing & Capabilities → Bundle Identifier** con qualcosa di unico, tipo
   `com.tuonome.uzbelia`.
4. In alto seleziona il tuo iPhone al posto del simulatore e premi ⌘R.
5. La prima volta il telefono rifiuta l'app: **Impostazioni → Generali → VPN e gestione
   dispositivo → Apple Development: (tua mail) → Autorizza**.

### Per quanto resta installata

Non dipende da come la installi, ma da **con quale account la firmi**:

| Account | Quanto dura | Come si rinnova |
|---|---|---|
| Apple ID gratuito | **7 giorni** | ricollegare l'iPhone e rifare ⌘R |
| Apple Developer a pagamento | **1 anno** | uguale, una volta l'anno |
| TestFlight | **90 giorni per build** | caricare una build nuova ogni tre mesi |
| App Store | per sempre | pubblicazione e revisione Apple |

Il progetto è già impostato sul team a pagamento (`DEVELOPMENT_TEAM` in `project.yml`),
quindi **un'installazione dura un anno**: è la via più lunga che esista senza pubblicare
sull'App Store, e non richiede né TestFlight né revisioni.

Per il secondo telefono basta collegarlo e rifare ⌘R: la firma automatica lo registra
da sola (il piano a pagamento ne consente fino a 100 all'anno).

Il progetto Xcode è generato da [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Se modifichi `project.yml` (o aggiungi cartelle di sorgenti), rigeneralo con `xcodegen generate`.
La firma è **automatica** e il campo Team è volutamente vuoto, così Xcode ti fa scegliere
il tuo.

Requisiti: Xcode 16+, iOS 17.0 o successivo. **Nessuna dipendenza esterna**, nemmeno per
l'account. Senza chiave IA e senza account **funziona interamente offline**; con una
chiave la rete serve per la videochiamata, per il capitolo di scrittura, per le frasi
nuove e per il giudizio sulle traduzioni alternative — e se manca, ognuna di queste
ricade sull'offline. L'account (facoltativo, vedi [più sotto](#account-non-perdere-i-progressi))
serve solo a non perdere i progressi cambiando telefono.

---

## Il corso in numeri

Ogni corso ha lo stesso scheletro (stessi id di unità e lezioni, stessi argomenti),
quindi gli stessi numeri. Per l'uzbeko, completo:

- **4 livelli** (A1, A2, B1, B2), **32 unità** (8 per livello)
- **339 lezioni** + 32 dialoghi + 32 capitoli di scrittura + 32 ripassi d'unità
- ogni lezione richiede **5 sessioni** → circa **1.760 sessioni** per arrivare al B2
- **6.581 coppie di traduzione** (vocaboli + frasi complete)
- **4.068 frasi di esercizio**, una dozzina per lezione
- **77 note di grammatica** scritte per quella lingua, **256 domande** per le
  videochiamate e **512 domande di approfondimento**

### Il lessico rispetta le bande CEFR

Il conteggio è sulle **voci di vocabolario distinte insegnate fino a quel livello**
(cumulativo), verificato a ogni compilazione del contenuto e da un test:

| Livello | Banda CEFR | Il corso insegna |
|---|---|---|
| A1 | 500 – 1.000 | **814** |
| A2 | 1.000 – 2.000 | **1.599** |
| B1 | 2.000 – 5.000 | **3.191** |
| B2 | 4.000 – 8.000 | **5.172** |

Se un giorno il contenuto scendesse sotto la soglia, `python3 content/build.py`
fallisce e lo dice: la promessa "a fine livello sai N parole" è controllata, non
dichiarata.

### Struttura di un'unità

```
Unità ─┬─ Lezione 1  ┐
       ├─ …          │  da 8 a 19 lezioni tematiche per unità:
       ├─ Lezione n  │  4 lezioni "narrative" + pacchetti di lessico
       │             ┘  (16-21 vocaboli ciascuna)
       ├─ Dialogo       storia da leggere/ascoltare + esercizi
       ├─ Scrittura     chat con Anorcha: scrivi tu, nessun esercizio
       └─ Ripasso       test finale su tutta l'unità (14 esercizi)
```

### Ogni lezione si fa 5 volte, e ogni volta è diversa

Come una skill di Duolingo, una lezione non è finita al primo giro: servono **5
sessioni**, e il percorso non avanza finché non sono tutte fatte (l'anello intorno
al nodo mostra 1/5, 2/5…). Ogni passaggio allena qualcosa di diverso:

| # | Sessione | Domande | Che cosa contiene |
|---|---|---|---|
| 1 | **Lettura** | 11 | solo lettura: abbinamenti, scelta multipla, completa, costruisci la frase |
| 2 | **Ascolto** | 10 | solo ascolto: ascolta e scegli, *che cosa significa?*, ricomponi quello che senti, dettato |
| 3 | **Scrittura** | 9 | solo scrittura: otto frasi da scrivere con la tastiera e **un breve testo** |
| 4 | **Parlato** | 9 | solo voce: leggi ad alta voce, *ascolta e ripeti* |
| 5 | **Ripasso** | 11 | tutto insieme, senza aiuti e con più produzione |

**L'etichetta è una promessa**: una sessione che si chiama *Ascolto* contiene
soltanto esercizi di ascolto, *Scrittura* soltanto esercizi di scrittura, e così via.
Solo il *Ripasso* mescola. Per non diventare monotone, le sessioni a tema alternano
più formati della stessa abilità (e la stessa domanda non arriva due volte di fila
nella stessa direzione). Le domande sbagliate tornano alla fine, come prima.

Se un'abilità è spenta in *Profilo* (o messa in pausa con «Non posso parlare ora»),
la sessione dedicata a quell'abilità diventa un *Ripasso* e **lo dice**, sul nodo e
nella lezione: niente sessioni chiamate *Ascolto* riempite d'altro.

Dialoghi e ripassi d'unità restano a sessione singola; il dialogo, dopo la lettura,
ha solo esercizi di ascolto.

Ogni unità ha anche un **manuale** (l'icona 📖 sul banner) con le note di grammatica e
l'elenco completo delle parole, ognuna con audio e indicatore di memoria.

### Le frasi non sono sempre le stesse

Una lezione insegna una decina di parole e quattro o cinque frasi, e va fatta cinque
volte: se le sessioni fossero fatte solo di quelle, al terzo giro non si tradurrebbe più,
si ricorderebbe quale bottone si era premuto.

Per questo ogni lezione ha anche **una dozzina di frasi di esercizio** (`drills`,
**4.068 in tutto il corso**), scritte con le parole di quella lezione e di quelle
prima, alla lunghezza e con la grammatica del suo livello (A1 3-6 parole, A2 4-9, B1 6-13,
B2 8-16). Non aggiungono vocaboli: servono a usare in modi diversi quelli già insegnati.

- Il **primo** giro resta sulle parole e sulle frasi della lezione: lì le parole nuove
  si incontrano per la prima volta.
- Dal **secondo** in poi la sessione è fatta di quattro parole della lezione e otto
  frasi, scelte fra quelle **che hai visto meno**: le frasi mai viste per prime, a parità
  a caso. Così ogni giro porta frasi che il giro prima non aveva.
- Il ripasso dell'unità e *Ripassa un capitolo* pescano dalle frasi di tutta l'unità,
  con la stessa regola.
- Stanno in `content/drills/<unità>.py`; `python3 content/check_drills.py` controlla
  lunghezze, apostrofi, doppioni e che ogni lezione ne abbia almeno dieci, e
  `build.py` rifà lo stesso controllo prima di scrivere il JSON.

Con una chiave IA configurata l'app **si scrive anche frasi nuove da sola**
(`PhraseForge`): stesso lessico del capitolo, stessa grammatica, stesso livello CEFR —
ma frasi che nessuno ha mai visto.

- Si aggiungono a quelle del corso dal secondo giro in poi, e non sono mai più della
  metà delle frasi di una sessione.
- La lunghezza è vincolata al livello, così «nuovo» non diventa mai di nascosto «più
  difficile».
- Tutto quello che arriva viene **tenuto su disco** e si accumula: dopo i primi giri
  c'è varietà anche offline, e ogni capitolo arriva a un massimo di 90 frasi.
- È sempre attiva, senza interruttore, ma è la prima cosa a cui l'app rinuncia quando le
  richieste del giorno scarseggiano (vedi [L'assistente IA](#lassistente-ia)): allora
  restano le frasi di esercizio del corso e quelle già scritte.

### Un capitolo di sola scrittura, in ogni unità

Ogni unità ha un nodo **Scrivi ad Anorcha**: niente esercizi, niente cinque sessioni —
una **chat**. Anorcha scrive un messaggio nella lingua che stai imparando, tu rispondi
di tuo pugno, e va avanti per qualche scambio. Sono **32 capitoli in tutto**, uno per
unità, distribuiti da A1 a B2.

| Livello | Messaggi da scrivere | Minimo per messaggio |
|---|---|---|
| A1 | 4 | 3 parole |
| A2 | 5 | 5 parole |
| B1 | 6 | 8 parole |
| B2 | 6 | 12 parole |

Ogni unità ha un **argomento fisso** (com'è andata oggi, mettersi d'accordo, chiedere
un favore, un piccolo problema…) scelto dall'id dell'unità, così il capitolo ha
un'identità sua; i messaggi dentro, invece, sono scritti nuovi ogni volta. Tocca un
messaggio di Anorcha per vederne la traduzione.

**Durante la chat non ti corregge niente** — una conversazione che ti segna l'errore a
ogni riga è una conversazione che smetti di scrivere. Alla fine arriva il rapporto:
frase per frase, cosa era sbagliato, perché, e un modo più naturale di dirlo. È lo
stesso motore di correzione della videochiamata, quindi **funziona anche offline**
(con una chiave, le correzioni le scrive l'IA; senza, le fa il correttore locale).
Anche senza chiave Anorcha ha un copione di domande per ogni argomento, quindi il
capitolo si fa comunque.

### Le note di grammatica sono scritte per ogni lingua

Le note sono in inglese e spiegano **la grammatica di quella lingua** a chi parla
inglese: per l'uzbeko che *essere* al presente è una desinenza (`-man/-san/-miz`), per
il thai che non si coniuga niente e il tempo lo dicono le parole intorno, per il
persiano l'*ezafe*. Non si traducono da un corso all'altro: ogni corso ha le sue.

Nella scheda **Grammatica** ogni capitolo è una riga con, sotto il titolo, i titoli delle
sue regole; un tocco apre **un foglio** con tutte le regole del capitolo, da leggere
dall'alto in basso. Prima le regole si aprivano dentro la lista: scivolavano giù dalla
riga sopra con una molla, spingevano via il resto della lista e in chiusura risalivano
sfumando sopra l'intestazione. Con un foglio la lista resta esattamente dov'era.

---

## I tipi di esercizio

Gli esercizi non sono scritti a mano uno per uno: un motore (`ExerciseFactory`) li genera
da ogni coppia di traduzione, scegliendo il formato adatto alla lunghezza della frase e
alternandoli in modo che lo stesso tipo non capiti due volte di fila.

| Esercizio | Abilità | Descrizione |
|---|---|---|
| **Abbina le coppie** | lettura | 5 parole da accoppiare con la traduzione (due giri nelle lezioni di soli vocaboli) |
| **Scelta multipla** | lettura | 4 opzioni, in tutte e due le direzioni |
| **Completa la frase** | lettura | una parola tolta dalla frase, 4 candidate |
| **Costruisci la frase** | lettura | tessere con distrattori, dalla frase scritta |
| **Ascolta e scegli** | ascolto | solo audio, scegli la frase che hai sentito |
| **Ascolta: che cosa significa?** | ascolto | solo audio, scegli il significato nella tua lingua |
| **Ricomponi quello che senti** | ascolto | solo audio, ricostruisci la frase con le tessere |
| **Scrivi quello che senti** | ascolto | dettato con audio (normale e lento) |
| **Scrivi la traduzione** | scrittura | tastiera libera, con tolleranza ai refusi |
| **Scrivi un breve testo** | scrittura | due o tre cose da dire, corrette a giri (vedi sotto) |
| **Pronuncia la frase** | parlato | leggi ad alta voce: microfono, riconoscimento e punteggio |
| **Ascolta e ripeti** | parlato | il testo resta nascosto: lo senti e lo ripeti a voce |

Per l'uzbeko c'è una **riga di tasti rapidi** (`o'`, `g'`, `sh`, `ch`, `ng`, `'`) subito
sopra il pulsante di verifica — quindi sempre sopra la tastiera — negli esercizi in cui
si scrive.

### Scrivi un breve testo

Ogni sessione di *Scrittura* (e l'allenamento *Scrittura*) finisce con un testo da
scrivere: Anorcha ti chiede un messaggio che dica **due o tre cose** (tre da B1), scritte
nella tua lingua; la prima frase è **già cominciata** nel riquadro, e sotto ci sono le
**parole che conosci** da toccare. Le cose da dire sono frasi del corso stesso, quindi il
testo si scrive sempre con parole **già studiate**.

Poi lo correggi **un poco alla volta**, con l'aiuto dell'app:

1. **Primo controllo** — il testo torna con gli errori evidenziati e numerati (una parola
   sbagliata, una che manca, una di troppo, l'ordine, una parte non detta) e per ognuno un
   indizio che dice **dove guardare**, non la soluzione.
2. **Secondo controllo** — gli indizi danno le **prime lettere**; compare *Mostra la
   correzione*.
3. **Dal terzo** — l'indizio è la correzione stessa.

Pulito al primo colpo è *giusto*; pulito dopo qualche indizio è *giusto con aiuto*; se
chiedi la correzione vedi il testo corretto, conta come errore ma **non costa cuori** e non
ti viene richiesto. Il tuo modo di dirlo non è un errore: ogni frase passa prima dalle
stesse regole di `Equivalence` delle traduzioni (via *mening*, via *men*, nomi scritti a
modo tuo…), e una frase in più scritta da te viene solo controllata per ortografia e
grammatica. Con una chiave IA la correzione la scrive l'assistente, che accetta qualsiasi
formulazione naturale; senza, la fa il correttore offline (`CompositionChecker`).

### Come vengono corrette le risposte

`Grader` normalizza prima di confrontare: minuscole, spazi multipli, punteggiatura,
accenti italiani (*perche* = *perché*) e **tutte le varianti di apostrofo uzbeko**
(`o'` = `oʻ` = `o‘`). Un refuso di una lettera su parole lunghe viene accettato come
“Quasi!” mostrando la grafia corretta; le parole corte devono essere esatte. Sono
ammesse risposte alternative scrivendo `forma1 / forma2` nel contenuto, e una
traduzione detta con parole tue ma giusta è segnata giusta: vedi
[più sotto](#più-di-una-traduzione-può-essere-giusta).

Ogni risposta ha il suo suono, come su Duolingo: un *ding* quando è giusta, un suono
d'errore (insieme alla vibrazione) quando è sbagliata, anche nell'abbinamento delle
coppie. Passano dal canale dei media come la voce del corso, quindi si sentono anche
con il silenzioso; si spengono da *Profilo → Effetti sonori*. Quando l'app rilegge la risposta
ad alta voce, aspetta che il suono sia finito.

---

## Il design

L'interfaccia è costruita su un piccolo design system in `Sources/DesignSystem`:

- **Violetto e bianco, più un colore per tipo di sessione.** Una scala di violetto
  (`Violet` in `Theme.swift`) porta gli accenti dell'app e le unità del percorso; un **rosa
  tenue** è riservato agli errori. Ogni *tipo* di sessione ha poi il suo colore, sempre
  lo stesso ovunque compaia (nodo del percorso, anello delle sessioni, pulsante, barra di
  avanzamento, carta in *Allenati*):

  | Lettura | Ascolto | Scrittura | Parlato | Ripasso |
  |---|---|---|---|---|
  | azzurro `#56A4EB` | acqua `#45BDCB` | pesca `#F2A86E` | menta `#66C89A` | viola `#8B6EF3` |

  I quattro colori hanno la stessa luminosità e la stessa morbidezza del viola, cambia
  solo la tinta; e le loro ombre piegano verso il viola, come un pittore scalda o
  raffredda un'ombra verso la luce principale. È questo che li tiene insieme invece di
  farli sembrare una scatola di pastelli. "Giusto" non ha un colore suo: è una pillola
  viola piena con la spunta bianca. Le lingue sono targhette `UZ` / `IT` invece delle
  bandiere.
- **Sfondo "aurora"** (`AuroraBackground`): una tela bianco-lavanda con aloni lilla che
  si muovono lentamente. Di notte gli stessi aloni brillano su un indaco profondo.
- **Vetro** (`.glass`, `.glassCapsule`, `GlassPane`): pannelli smerigliati con il bordo
  luminoso in alto e un'ombra viola che li fa galleggiare.
- **Componenti riutilizzabili** (in `Glass.swift`): pulsante principale a pillola in
  gradiente viola (`.primary`), pulsanti a pillola in vetro (`.glass`), pulsanti rotondi in vetro (`GlassCircleButton`), campo di ricerca,
  menu a tendina, selettore a pillole, toggle e checkbox in vetro, toast e finestra
  modale (`GlassDialog`).
- **Sfere lucide** (`OrbIcon`) al posto delle icone piatte, con **archi di progresso**
  (`ArcRing`) intorno; ciò che è completato diventa **perla** (bianco e lavanda).
- Le abilità si riconoscono dall'**icona** (libro, cuffie, matita, microfono, frecce)
  *e* dal colore; l'anello intorno a un nodo è diviso in cinque archi, uno per sessione,
  ciascuno del colore della sua.
- **La serie si festeggia** (`StreakCelebrationView`): la prima volta al giorno che
  finisci qualcosa — lezione, allenamento, flashcard, chiamata, chat — prima di chiudere
  si accende una fiamma disegnata a mano (non un'emoji: una goccia con una seconda
  lingua di fuoco, che oscilla davvero, con qualche scintilla che sale), il numero
  rotola dal vecchio al nuovo, e nella settimana il giorno di oggi si riempie e si
  spunta. Ogni battuta ha il suo tempo; con *Riduci movimento* compare tutto e basta.
  La fiamma nell'intestazione resta grigia finché quel giorno non hai fatto niente.

## Saltare avanti: i test di verifica

Non sei obbligata a fare tutto in ordine, ma nemmeno puoi saltare gratis.

- **Tocchi una lezione bloccata** → «Sblocca con un test»: 15 domande prese da tutto
  quello che avresti saltato, servono l'80% (max 3 errori). Superato, quelle lezioni
  risultano completate e il percorso riparte da lì.
- **Tocchi un livello bloccato** (A2/B1/B2) → test di livello: 20 domande prese dal
  livello precedente, stessa soglia. Superato, il livello si apre tutto.

I test non consumano cuori, non contengono esercizi di pronuncia (non devono dipendere
da un microfono) e mostrano in alto gli errori residui. Se non li superi non succede
nulla: puoi riprovare o seguire il percorso normale.

## Videochiamata con Anorcha

Tab **Chiama**: quattro pulsanti, **A1 A2 B1 B2**. Scegli il livello, il telefono squilla,
rispondi e si parla.

- **È una conversazione, non un questionario.** Con l'assistente (vedi sotto) ogni
  domanda dopo il saluto nasce da quello che hai appena detto, e resta sullo stesso
  argomento finché ha senso.
- **Anche offline tiene il filo.** Le domande partono dal **capitolo a cui sei arrivata**
  in quel livello, e sono organizzate in *fili*: una domanda del capitolo e le due scritte
  apposta per seguirla, qualunque cosa tu abbia risposto («Chi c'è nella tua famiglia?» →
  «Con chi vai più d'accordo?» → «Dove abita la maggior parte di loro?»). Quando si passa
  a un altro filo Anorcha lo dice («Adesso cambiamo un attimo argomento») invece di
  saltare. Prima le domande venivano mescolate con un paio di capitoli vecchi e un
  «Perché?» a caso, ed era così che una chiamata sulla famiglia finiva sui biglietti
  dell'autobus. Le domande di approfondimento stanno in `content/questions.py`
  (`FOLLOWUPS`); i fili cambiano a ogni chiamata, quindi **due chiamate uguali
  praticamente non capitano** (un test lo verifica su dodici chiamate, un altro che
  ogni domanda segua davvero quella prima).
- **Rispondi tu, come vuoi.** Nessun suggerimento, nessuna scelta multipla: microfono
  (o tastiera, se preferisci scrivere) e dici quello che ti viene in mente. Puoi sempre
  dire «Non so rispondere» e passare oltre.
- **Alla fine arriva il recap.** Quante domande hai affrontato, quante parole hai detto,
  quante diverse, e poi **risposta per risposta**: che cosa hai detto, se andava bene, e
  le correzioni.

### Che cosa corregge davvero

| | |
|---|---|
| **Ortografia** | ogni parola viene confrontata con il lessico del corso: *rahmet* → *rahmat* |
| **Grammatica** | gli errori tipici di questa coppia di lingue: *uchta kitoblar* → *uchta kitob* («dopo un numero il nome resta singolare»), *ho andato* → *sono andato*, *in Roma* → *a Roma*, *sono 25 anni* → *ho 25 anni* |
| **Più naturale** | una formulazione idiomatica presa dal corpus del corso, al posto della tua |
| **Lingua** | se hai risposto nella lingua sbagliata te lo dice, senza contarlo come errore |
| **Consigli** | sulle abitudini, non sul singolo scivolone: «molte risposte erano brevi», «attenzione agli apostrofi» |

Il correttore è **prudente per scelta**: se non può giustificare una correzione, tace. Non
segnala una parola che il corso semplicemente non insegna (*deyman* non diventa *yeyman*
solo perché differiscono di una lettera: un cambio di iniziale non è un refuso).

### L'assistente IA

**Non c'è niente da configurare.** La chiave Gemini è compilata dentro l'app
(`Secrets.swift`, tenuta fuori da git) e nell'app non compare da nessuna parte: niente
servizio da scegliere, niente chiave da incollare, niente «Prova la chiave». È una
chiave **dedicata**, creata nel progetto Firebase dell'app (`uzbelia-76044`) e
limitata alla sola API Gemini. Una chiave incollata a mano in una versione precedente
continua a funzionare, ma non viene più chiesta.

Con l'assistente la videochiamata diventa **una conversazione scritta sul momento**:

- a ogni turno il modello riceve **tutta la trascrizione**, da entrambe le parti (anche
  le sue reazioni e i passaggi di argomento), e deve scrivere *prima* che cosa ha capito
  della tua risposta e su quale argomento si trova — due campi che nessuno vede, ma un
  modello che ha appena scritto «ha due fratelli, uno fa il medico» poi non ti chiede del
  tempo;
- **tiene il filo**: reagisce a un dettaglio concreto di quello che hai detto, la domanda
  dopo nasce da lì, resta sullo stesso argomento per due o tre scambi e si sposta solo
  verso qualcosa di vicino, passando da un tuo dettaglio. Non chiede mai una cosa a cui
  hai già risposto. Se non ha sentito niente o la risposta non si capisce, **te lo
  richiede più semplice** invece di cambiare argomento; se salti, ne chiede una più facile
  sullo stesso tema;
- la risposta arriva dal riconoscimento vocale, quindi il modello è istruito a leggerla
  «con generosità», come farebbe un'amica;
- il saluto finale cita qualcosa che le hai raccontato;
- il modello riceve anche un *briefing* su di te: capitolo, lezioni, vocabolario appena
  studiato, capitoli già fatti, le parole che sbagli più spesso, i giorni di fila, l'ora
  del giorno e un «angolo» estratto a sorte per la chiamata;
- se una richiesta fallisce viene **riprovata una volta**; se fallisce ancora, quel turno
  usa la domanda del filo offline e la chiamata prosegue. Solo due turni falliti di fila
  spengono l'assistente per il resto della chiamata.

Verificato con la chiave vera, simulando una chiamata sulla famiglia: saluto → «chi
c'è a casa?» → due fratelli e una sorella → come si chiama → Jasur lavora a Tashkent →
che lavoro fa → il plov della domenica → chi lo cucina; e a una risposta vuota ha
richiesto la stessa cosa invece di andare avanti.

**Il limite da sapere.** Sul piano gratuito di Google questa chiave ha **20 richieste
al giorno per tutto il progetto** (cioè per entrambi i telefoni insieme), e funziona solo
`gemini-3.6-flash` (gli altri modelli rispondono 404). Una videochiamata ne usa circa
nove, una per turno più il rapporto finale. Per non sprecarle l'app le **razionsa**
(`AIBudget` in `AIClient.swift`):

| Uso | Può chiedere finché, oggi, da questo telefono… |
|---|---|
| conversazione (videochiamata, chat di scrittura) | sempre, finché Google dice di sì |
| correzioni (rapporto della chiamata, testo breve) | meno di 16 richieste |
| extra (significato di una parola, frasi nuove, seconda opinione, trascrizione) | meno di 5 richieste |

Quando Google risponde «quota del giorno finita», l'app se lo segna fino all'ora che
Google indica e **non riprova più**: la chiamata prosegue subito offline invece di farti
aspettare risposte che non possono arrivare.

Per togliere il limite basta **attivare la fatturazione** sul progetto Google Cloud
(`console.cloud.google.com/billing`, progetto *uzbelia-76044*): con Gemini Flash una
videochiamata costa una frazione di centesimo. È una cosa che solo il titolare
dell'account può fare, perché chiede un metodo di pagamento.

La chiave serve anche agli **esercizi**, per far accettare le traduzioni alternative:
vedi più sotto.

## «Ora non posso»

Dentro un esercizio di pronuncia o di ascolto, accanto a *Verifica*, c'è **«Non posso
parlare ora»** / **«Non posso ascoltare ora»**. Un tocco e quella abilità va in pausa per
**15 minuti**: niente microfono e niente audio, in questa sessione e in tutte quelle
iniziate finché la pausa dura.

Le domande già in coda non vengono buttate: una pronuncia diventa una traduzione
scritta, un dettato diventa una traduzione dalla tua lingua. La lezione resta lunga
uguale e insegna le stesse parole, solo in silenzio.

La pausa scade da sola — non devi ricordarti di riattivare niente — e intanto compare in
*Profilo → Impostazioni* con i minuti che restano e un «Riattiva» per annullarla prima.

## Scopri il tuo livello

All'inizio, sopra la scelta manuale del livello, c'è **«Scopri il tuo livello»**: un test
che sale lungo tutto il corso, due domande per capitolo, da A1 fino a B2.

Non è un punteggio ma **una curva**: giuste all'inizio, sbagliate più avanti, e il punto
in cui giri è dove appartieni. Chi la lingua non l'ha mai vista si ferma al primo gradino
e parte da A1, che è esattamente giusto.

Vieni messa **al primo capitolo che non sapevi**, mai oltre: così il test può solo
saltare roba che hai dimostrato di avere. Un gradino sbagliato per distrazione ti fa
partire un po' prima del dovuto, e dal percorso puoi sempre testare per saltare avanti.
Niente microfono e niente audio: lo puoi fare in autobus.

## Più di una traduzione può essere giusta

Un corso elenca una forma per frase, una lingua ne ha parecchie: *a domani* è
`ertaga ko'rishguncha` sul libro ed `ertagacha` per strada, e sono giuste entrambe.
Lo stesso vale nell'altro senso: `yaxshiman` è «sto bene», ma anche «va tutto ok».

Quando scrivi una traduzione tua che non è parola per parola quella del libro, prima di
dire qualunque cosa l'app prova queste strade, dalla più economica alla più costosa:

| | |
|---|---|
| **Le regole della lingua** | offline e istantaneo (`Equivalence`): i casi prevedibili, elencati qui sotto |
| **Il corso stesso** | se quella forma è insegnata altrove come traduzione della stessa frase, è accettata subito, offline |
| **La tua storia** | una forma già accettata in passato vale per sempre, senza nessuna richiesta di rete |
| **L'assistente** | con una chiave configurata, il modello decide se è un modo naturale di dire la stessa cosa |

Se una di queste la riconosce, la risposta è **giusta e basta**: banner verde,
*«Corretto!»*, la tua forma — e sotto, come fa Duolingo, *«Un'altra soluzione
corretta:»* con la versione del libro. Niente rosso, niente cuore perso, niente domanda
che torna.

Le regole della lingua coprono, senza rete:

| | esempio |
|---|---|
| **Pronome sottinteso** | `itim` = `mening itim` («il mio cane»), `Klaudiyaman` = `men Klaudiyaman`, *sono Claudia* = *io sono Claudia* — e al contrario. Un pronome che non concorda resta sbagliato: `sening itim` non è «il mio cane» |
| **Saluti, grazie, scuse** | `assalomu alaykum` = `salom`, `tashakkur` = `rahmat`, `uzr` = `kechirasiz`, *per piacere* = *per favore*, *scusi* = *scusa*; *salve* vale *ciao* se stavi traducendo `salom`, *ciao* vale *arrivederci* se stavi traducendo `xayr` |
| **Presentarsi** | `mening ismim Klaudiya` = `men Klaudiyaman`, *il mio nome è* = *mi chiamo* |
| **Nomi** | scritti alla tua maniera: *Claudia* per `Klaudiya`, *Marco* per `Marko` |
| **Parole di tempo** | `ertaga`, `bugun`, *domani*, *oggi*… possono stare all'inizio o prima del verbo |
| **Numeri** | in cifre o in lettere; `uchta kitob` = `uch kitob` |
| **Sinonimi sicuri** | *abitare* / *vivere*, *adesso* / *ora*, *che cosa* / *cosa*, *cos'è* / *che cos'è* |

Ogni regola toglie solo ciò che in quella posizione non porta significato: `men ham`
(«anch'io») tiene il suo `men`, `u kitob` tiene il suo `u` quando la frase italiana dice
*quel libro*, *con lei* non diventa *con lui*.

L'esaminatore IA è **severo sul significato e generoso sul registro**: colloquiale,
abbreviato, regionale o più formale vanno tutti bene; viene rifiutato solo ciò che
significa altro, è in un'altra lingua o non è grammaticale. Le regole offline coprono i
casi frequenti; per *qualunque* costruzione alternativa corretta (`Menda kitob bor` per
`Mening kitobim bor`, *tu* per *Lei*…) serve la chiave: senza, quelle risposte restano
segnate sbagliate.

Per quel caso, sotto una risposta sbagliata c'è un piccolo pulsante grigio **«La mia
risposta era giusta»** (con la bandierina): è una segnalazione tua, non un secondo
verdetto dell'app. Un tocco e viene accettata, il cuore torna indietro e la forma è
imparata per sempre.

Vale per gli esercizi di traduzione libera (scrittura e banco di parole). Il dettato e
le scelte multiple hanno una risposta sola, e restano tali.

## La voce uzbeka

iOS non ha una voce uzbeka né un riconoscitore uzbeko: da solo leggerebbe l'uzbeko con
una voce **turca** e valuterebbe la pronuncia contro una trascrizione turca, che è
grosso modo buona quanto sembra.

**La voce vera è attiva da subito, senza chiavi e senza account.** Microsoft Edge ha una
funzione *Leggi ad alta voce* servita dalle stesse voci neurali che Azure vende, fra cui
`uz-UZ-MadinaNeural` e `uz-UZ-SardorNeural`. Il browser ci parla via WebSocket con un
token che chiunque può calcolare, quindi l'app chiede lo stesso audio senza registrarsi
da nessuna parte (`EdgeVoice.swift`, nessuna dipendenza esterna).

> È un endpoint **non documentato**: Microsoft potrebbe cambiarlo o chiuderlo senza
> preavviso. Per questo non regge niente di essenziale — ogni errore ricade da solo
> sulla voce turca di iOS, esattamente come prima.

Con una chiave **Azure Speech** (facoltativa) si passa alla via contrattuale, che aggiunge
anche l'ascolto:

| | |
|---|---|
| **Voce** | identica: `uz-UZ-MadinaNeural` o `uz-UZ-SardorNeural` |
| **Ascolto** | riconoscimento vocale `uz-UZ` invece del turco approssimato |
| **Costo** | piano **F0**: 500.000 caratteri e 5 ore al mese, gratis — ma la registrazione Azure chiede una carta |

Chiave e regione si incollano in `Secrets.swift`, da `portal.azure.com` → *Create a
resource* → **Speech** → tier **F0** → *Keys and Endpoint*.

### Il riconoscimento: lo fa il telefono

Dentro l'app gira **[`navai-uz/whisper-small-uzbek`](https://huggingface.co/navai-uz/whisper-small-uzbek)**
— un Whisper small rifinito su uzbeko (Common Voice 22, FLEURS, FeruzaSpeech) — tramite
whisper.cpp, **sul dispositivo**: niente chiave, niente account, niente rete.

Sullo stesso spezzone di «Ertaga ko'rishguncha! Men xursandman.»:

| | |
|---|---|
| Apple, che ripiega sul turco | `Selam gece Özbekçe orada yaptım` |
| Gemini | `Ertagacha ko'rishguncha Men xursandman` |
| **Il modello sul telefono** | **`ertaga koʻrishguncha men xursandman`** |

L'ordine è: il modello sul telefono, poi Azure se c'è la chiave, poi Gemini, e solo in
ultimo il turco approssimato di iOS.

**Le parole compaiono mentre parli.** Circa una volta al secondo il modello rilegge quello
che hai detto finora e lo scrive sotto, in grigio chiaro perché è ancora una lettura
provvisoria; quando smetti, una passata completa la sostituisce con la versione buona.
Questo lo può fare solo il modello a bordo: mandare un secondo di audio al secondo a un
server non sarebbe né veloce né gentile col traffico dati. Con le altre vie il testo
compare tutto insieme alla fine, come prima.

**I due artefatti non stanno in git** — l'XCFramework (58 MB) e il modello (181 MB) sono
troppo grossi. Si ricostruiscono con:

```bash
./scripts/build-uzbek-recognizer.sh
```

Serve `cmake` (`brew install cmake`) e scarica circa 1 GB; ci mette qualche minuto. Senza
quei file **l'app compila lo stesso**: il riconoscitore si dichiara non disponibile e
valgono le vie di prima. Con loro, l'app pesa circa 200 MB in più.

**L'audio viene messo in cache su disco**, per voce e per velocità: un corso ripete di
continuo le stesse parole, quindi dopo il primo passaggio su un capitolo non esce quasi
più niente dal telefono.

Se la rete cade o un servizio smette di rispondere, si torna **da sola** alla voce turca
di iOS: l'audio non smette mai di funzionare, peggiora e basta. E l'avviso «pronuncia
approssimata» compare solo quando lo è davvero.

## Tocca una parola per il significato

Dentro un esercizio, un tocco su una parola apre sotto una piccola carta con **che cosa
vuol dire quella parola** — **mai la traduzione della frase intera**. Quando la parola fa
parte di un'espressione fissa che il corso insegna come unità (`xayrli tong`, `ertaga
ko'rishguncha`), l'espressione si illumina nella riga e la carta dice che cosa vuol dire
lei, perché `xayrli tong` non è «mattino propizio».

Le parole flesse che il corso non elenca da sole vengono ricondotte alla **forma base**,
e la carta lo dice: `bordim` → *forma base: bormoq* · andare; `kitoblarim` → `kitob`;
`parliamo` → `parlare`. La forma base è accettata solo se le desinenze la spiegano per
intero (`Glossary.base`), così un'ipotesi non passa mai per un dato certo.

Da dove esce il significato, dal più economico al più caro:

| | |
|---|---|
| **Il corso** | la parola insegnata da sola, l'espressione fissa che la contiene, o la sua forma base: istantaneo e offline |
| **La tua cronologia** | ogni significato già cercato è tenuto per sempre: una parola si cerca una volta sola nella vita dell'app |
| **L'assistente** | con una chiave, gliela chiede — ed è quasi sempre lui, per il motivo qui sotto |

Il corso insegna da sola solo una parola su cinque (**22%** in uzbeko, 35% in italiano):
tutte le altre compaiono soltanto dentro le frasi. La lettura della forma base ne
recupera una buona parte anche senza chiave; con la chiave funziona quasi sempre — e
anche all'assistente si chiede la parola o l'espressione, mai la frase — e ogni
risultato resta sul telefono.

Si può spegnere da *Profilo → «Tocca una parola per il significato»*: su una domanda
come «Che cosa significa…?» il suggerimento ti dà in mano la risposta, e potresti non
volerlo.

## Parole nuove ed errori che tornano

Sopra l'esercizio compare una targhetta quando c'è qualcosa da sapere:

- **NUOVA** — è la prima volta in assoluto che il corso ti mette davanti quella parola.
- **ERRORE PRECEDENTE** — arancione quando la domanda sta tornando perché l'hai appena
  sbagliata in questa sessione, rossa quando è una parola che avevi già sbagliato in una
  sessione passata.

Una domanda sbagliata **torna prima della fine della lezione** e non se ne va finché non
la fai giusta. Una traduzione giusta detta con parole tue invece non torna, e nemmeno una
accettata con «La mia risposta era giusta»: non erano errori.

Qualunque cosa scritta nella lingua che stai imparando si tocca e si sente: le opzioni
di risposta, le tessere dell'abbinamento, i chip del banco di parole, le parole chiave
di una lezione, le righe di una storia, il vocabolario della guida, gli errori nel
riepilogo, i sottotitoli della videochiamata.

Dentro una frase il bersaglio è **la singola parola**: tocchi *kech* e senti *kech*, non
tutta la riga. Per l'intera frase ci sono i pulsanti 🔊 e 🐢 di sempre, oppure un tocco
prolungato.

## Gamification

- **Cuori e gemme illimitati** (è un regalo, non un negozio): ∞ nell'intestazione,
  gli errori non ti fermano mai. Non c'è un interruttore: sono illimitati e basta.
- **XP** per sessione, con bonus per precisione e per gli esercizi di pronuncia
- **Obiettivo giornaliero** configurabile (20/50/100/150 XP) con barra di avanzamento
- **Serie (streak)** giornaliera, con *salva-serie* che copre un giorno saltato. Conta
  qualsiasi cosa dia XP — anche un allenamento, un mazzo di flashcard o una chiamata — e
  quando cresce si festeggia (vedi [Il design](#il-design))
- **Corone**: fino a 3 per tappa, in base alle sessioni completate
- **Promemoria giornaliero** opzionale (notifica locale all'ora che scegli, testo bilingue
  che ricorda la serie in corso)

## Ripassare quello che hai già fatto

- **Ripassa questa unità**: dentro il manuale di ogni unità già iniziata, un pulsante
  genera una sessione di 18 esercizi pescati da tutta l'unità. Ripetibile all'infinito,
  senza cuori.
- **Allenati → Ripassa un capitolo**: l'elenco di tutte le unità che hai iniziato, con
  la percentuale di avanzamento, per riallenarne una qualsiasi quando vuoi.
- **Allenati → Esercitati con le flashcard**: un mazzo di 20 carte con le parole che hai
  già incontrato — prima quelle in scadenza, poi quelle ancora deboli, poi le altre,
  ognuna delle tre fasce mescolata. Tocchi la carta e si gira (il lato nella lingua che
  impari si sente da solo); la scorri a destra se la sapevi, a sinistra se no, oppure
  usi i tre pulsanti sotto. Si può partire dall'uzbeko o dall'italiano. Ogni carta
  aggiorna la stessa memoria delle lezioni (vedi SRS), quindi cambia anche quello che
  ti chiede il *Ripasso misto*. Alla fine: quante ne sapevi, e un pulsante per ripassare
  solo quelle da rivedere.
- **Ripasso misto**, **I tuoi errori** e **Allena un'abilità** restano disponibili come
  allenamento libero.

## Ripetizione dilazionata (SRS)

Ogni coppia ha una “memoria” 0→1 che sale con le risposte giuste e crolla con gli errori;
l'intervallo di ripasso cresce di conseguenza (4h → 12h → 1g → 3g → 7g → 14g). La scheda
**Allenati → Ripasso misto** propone per prime le parole più deboli e già in scadenza;
**I tuoi errori** ripesca ciò che hai sbagliato; **Allena un'abilità** genera una sessione
di soli esercizi di lettura, scrittura, ascolto o pronuncia.

---

## Audio e microfono — cosa aspettarsi

Questo è l'unico punto in cui la piattaforma pone un limite reale, ed è meglio saperlo:

- **Italiano**: iOS ha voci native (`it-IT`) e riconoscimento vocale nativo. Tutto perfetto.
- **Uzbeko**: iOS **non** include una voce né un riconoscitore uzbeko. L'app cerca
  `uz-UZ` e, se assente, ripiega sulla lingua turcica più vicina disponibile
  (turco, poi azero, poi russo) per leggere l'uzbeko in alfabeto latino: la pronuncia è
  comprensibile e utile, ma **approssimata**. Lo stesso vale per il punteggio di
  pronuncia, che viene leggermente “ammorbidito” quando usa un riconoscitore sostitutivo.

L'app lo dichiara apertamente sotto il microfono.
Se un giorno Apple aggiungerà una voce uzbeka, verrà usata automaticamente senza modifiche.

---

## Account: non perdere i progressi

Senza account l'app è quello che è sempre stata: un file sul telefono. Reinstalli,
cambi iPhone, e i progressi se ne vanno con lui.

Con un account quel file ha un gemello su **Firestore**: viene mandato su qualche
secondo dopo ogni cambiamento, e **riunito** con quello del server a ogni accesso.

L'account è **l'ultimo passo dell'onboarding**, subito prima di cominciare: è lì che
si decide se le prossime settimane di studio esistono solo su questo telefono. Chi
preferisce di no ha *Continua senza account* in fondo, e può rimediare in qualsiasi
momento da *Profilo → Account*. Chi invece sta reinstallando trova *Ho già un account*
già sulla primissima schermata: accede, i progressi tornano giù, e l'onboarding si
salta del tutto.

Il passo c'è **sempre**, anche in una build le cui stringhe in `Secrets.swift` sono
ancora vuote: i tre pulsanti restano al loro posto e sotto compare un promemoria giallo
che dice quali stringhe mancano. Una schermata che si nasconde da sola quando non è
configurata è una schermata che non ti accorgi di non aver configurato.

Tre modi per entrare, tutti e tre sullo stesso account Firebase e quindi sullo stesso
documento di progressi:

| | Che cosa serve |
|---|---|
| **Accedi con Apple** | niente: è un framework di sistema |
| **Accedi con Google** | una stringa in `Secrets.swift` (il client OAuth iOS) |
| **Email e password** | niente, con recupero password via email |

### La fusione non perde mai niente

Non è «vince l'ultimo che scrive» — è così che sparisce una settimana di lezioni
quando due telefoni si sincronizzano nell'ordine sbagliato. La regola è additiva:

| Dato | Come si uniscono le due copie |
|---|---|
| XP, gemme, serie, salva-serie | il valore più alto |
| lezioni fatte | completamenti, corone e precisione migliori delle due |
| memoria delle parole (SRS) | la copia più allenata |
| livelli sbloccati | l'unione |
| storico giornaliero | giorno per giorno, il massimo |
| errori e domande già fatte | l'unione, con lo stesso tetto di prima |
| impostazioni e «ora non posso» | **vince questo telefono** |

La chiave IA **non lascia mai il telefono**: viene tolta dal blob prima dell'invio.

### Come si attiva (una volta sola)

Il modo corto, se hai `npm`:

```bash
./scripts/crea-progetto-firebase.sh
```

Installa `firebase-tools` se manca, apre il browser per il login Google — l'unica
cosa che chiede — e poi fa tutto il resto da solo: crea il progetto, ci attacca
l'app web (che porta la **Web API Key**) e l'app **iOS** con il bundle
`com.uzbelia.app` (che porta il **client OAuth di Google**, senza il quale quel
pulsante non potrebbe funzionare), accende Email, Apple e Google via l'API di
Identity Toolkit, crea Firestore, carica le regole, e scrive tutte e tre le stringhe
in `Secrets.swift` tenendole fuori dai commit, come già fa la chiave Azure.

Se qualche interruttore non si lascia alzare via API, lo dice e apre la pagina
giusta della console: sono due clic, non di più.

Su un progetto Firebase che esiste già:

```bash
./scripts/crea-progetto-firebase.sh <PROJECT_ID>
```

Le chiavi si possono anche scrivere a mano in qualsiasi momento:

```bash
./scripts/set-firebase-keys.sh <WEB_API_KEY> <PROJECT_ID>
./scripts/set-firebase-keys.sh --google <ID_CLIENT_OAUTH_IOS>
```

Il modo lungo, tutto dalla console:

Non c'è nessun SDK nel progetto — né Firebase né GoogleSignIn. L'app parla con le API
REST (*Identity Toolkit* per l'account, *Firestore* per il documento) con `URLSession`,
esattamente come già parla con Gemini; Apple passa per `AuthenticationServices`, che è
di sistema; Google per la finestra di `ASWebAuthenticationSession` e il normale giro
OAuth con **PKCE**. Niente pacchetto da risolvere, niente `GoogleService-Info.plist`,
niente da registrare in Info.plist, nessun minuto in più di compilazione — **due
stringhe** in `Sources/Services/Secrets.swift` (tre se vuoi anche Google) e basta.

1. `console.firebase.google.com` → crea un progetto.
2. ⚙ **Project settings**: copia il **Project ID** e la **Web API Key**.
3. **Build → Authentication** → Get started → Sign-in method → abilita
   **Email/Password**, **Apple** e (se lo vuoi) **Google**. Per Apple, su iOS nativo
   non serve né Services ID né chiave privata: basta l'interruttore.
4. **Build → Firestore Database** → Create database (qualsiasi regione).
5. Firestore → **Rules**, così ognuno può toccare solo il proprio documento:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /learners/{uid} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```

6. Incolla le due stringhe in `Secrets.swift` (`firebaseAPIKey`, `firebaseProjectID`)
   e ricompila.

Per il **pulsante Google**, una stringa in più: Google Cloud console →
*APIs & Services → Credentials* → il client OAuth 2.0 di tipo **iOS** che Firebase ha
creato abilitando Google (o creane uno con il bundle id `com.uzbelia.app`), e incollalo
in `googleOAuthClientID`.

Per **Accedi con Apple** non serve nulla in `Secrets`: l'entitlement è nel progetto
(`Resources/Uzbelia.entitlements` → `com.apple.developer.applesignin`) e la firma
automatica aggiunge la capability all'App ID da sola al primo build su iPhone. Da
provare su un iPhone vero, o su un simulatore dove hai fatto l'accesso con un ID
Apple: senza, il foglio si apre e si chiude con un errore 1000 che non riguarda
l'app.

Lasciate vuote, **tutta la sezione Account sparisce dallo schermo** e l'app salva solo
sul telefono, come prima. La Web API Key non è un segreto come le altre in quel file:
nomina soltanto il progetto, e sono le regole qui sopra a tenere i dati privati.

Il documento contiene il profilo in JSON **compresso** (`bytesValue`), più XP e serie
in chiaro per poterli leggere dalla console. Un corso finito sta in poche decine di KB,
molto sotto il megabyte che Firestore concede a un documento.

---

## Architettura

```
Sources/
├── App/              punto di ingresso, tab bar, testi dell'interfaccia (it + uz)
├── DesignSystem/     palette, tipografia, bottoni 3D, mascotte, componenti
├── Models/           albero del corso (Curriculum) e stato utente persistito
├── Content/          caricamento del curriculum dal bundle
├── Engine/           Exercise, ExerciseFactory, Grader, SRS, PhraseForge,
│                    WritingChapter
├── Services/         sintesi vocale, riconoscimento vocale, feedback aptico,
│                    client IA, client Firebase (REST), Apple/Google, portachiavi
└── Features/
    ├── Onboarding/   scelta corso, livello di partenza, obiettivo, accesso
    ├── Path/         percorso a serpentina, schede tappa, manuale d'unità
    ├── Lesson/       motore di sessione, 8 viste esercizio, storie, risultati
    ├── Writing/      il capitolo di scrittura: chat con Anorcha e correzione
    ├── Practice/     allenamento libero, drill per abilità, elenco parole
    ├── Grammar/      tutte le note del corso, con ricerca
    └── Profile/      statistiche, grafico settimanale, negozio, impostazioni,
                      account
content/              sorgenti del curriculum (Python) + compilatore in JSON
Resources/Curriculum/ JSON generati e inclusi nell'app
Tests/                test su contenuti, grader, SRS e motore esercizi
```

Lo stato (progressi, XP, serie, SRS, impostazioni) è un unico blob JSON in
*Application Support*, con decodifica tollerante: aggiungere campi in futuro non
cancella i progressi di chi sta già studiando. Con un account configurato lo stesso
blob ha un gemello su Firestore (vedi sotto). Le frasi generate stanno in un secondo
file, `uzbelia-phrases.json`, accanto al primo.

---

## Modificare o ampliare i corsi

Ogni corso è una cartella `content/courses/<codice>/` (il formato è descritto in
`content/courses/FORMAT.md`):

| File | Contenuto |
|---|---|
| `course.py` | nome, alfabeto, traslitterazione sì/no |
| `a1.py` … `b2.py` | unità, note di grammatica, lezioni, dialoghi |
| `extra_<livello>*.py` | lezioni di lessico in più |
| `drills/<unità>.py` | le frasi di esercizio, una dozzina per lezione |
| `questions.py` | domande e approfondimenti delle videochiamate |
| `phrases.py` | le battute che l'app stessa dice nella lingua (reazioni, aperture della chat) |

Ogni coppia è `("inglese", "lingua")`, oppure `("inglese", "lingua", "traslitterazione")`
per gli alfabeti non latini:

```python
("a1u1l1", ("Greetings", "Salomlashish"),
 [("hello", "salom"), ("thank you", "rahmat")],             # vocaboli
 [("Hello, how are you?", "Salom, qalaysan?")]),            # frasi
```

Il corso di uzbeko è il **master**: un corso nuovo nasce traducendo e adattando
all'altra cultura il suo lato inglese (nomi, città, piatti, feste, moneta), con le
note di grammatica riscritte per la lingua nuova. Poi:

```bash
python3 content/build.py            # tutti i corsi
python3 content/build.py th         # solo il thai
```

Il compilatore scrive `Resources/Curriculum/<codice>-a1.json` … e rifiuta il corso se
trova lati vuoti, id duplicati, lezioni troppo povere, frasi nell'alfabeto sbagliato,
traslitterazioni mancanti, o un lessico sotto la banda CEFR del livello. Un corso
compare nell'app non appena il suo `a1.json` è nel bundle; per aggiungere una lingua
nuova serve anche il suo caso in `Language` (`Sources/Models/Curriculum.swift`), con
voce, alfabeto e riconoscimento.

---

## Mascotte

**Anorcha**, un melograno (`anor`, il frutto simbolo dell'Uzbekistan) disegnato
interamente con forme SwiftUI — nessuna immagine da caricare.

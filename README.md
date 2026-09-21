# Uzbelia 🇮🇹 ⇄ 🇺🇿

App iOS nativa (SwiftUI) per imparare **uzbeko e italiano dall'A1 al B2**, nello stile di
Duolingo/Ling: un percorso a tappe diviso in livelli → unità → lezioni, con esercizi di
lettura, scrittura, ascolto e parlato.

Il corso è **bidirezionale** e usa lo stesso corpus di frasi in entrambe le direzioni:

| Corso | Lingua dell'interfaccia | Lingua che impari |
|---|---|---|
| *Imparo l'uzbeko* | italiano | uzbeko |
| *Italyan tilini o'rganaman* | uzbeko | italiano |

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

### Usarla in due

L'app è pensata per una coppia che impara la lingua dell'altro: stesso corpus, due versi.

- **Ognuno sul proprio iPhone.** Ripeti la procedura qui sopra collegando il suo telefono
  al tuo Mac. Al primo avvio lui sceglie *Italyan tilini o'rganaman* e da lì l'intera
  interfaccia è in uzbeko, mentre esercizi, audio e correzioni sono in italiano.
- **Progressi separati.** XP, serie, cuori, parole imparate e forme alternative accettate
  vivono sul telefono, non in un account: nessuno vede o sposta i dati dell'altro.
- **Una sola chiave.** Quella in `Secrets.swift` viene compilata dentro l'app, quindi
  funziona su entrambi i telefoni senza configurare niente. La quota Google però è
  **condivisa**: due persone sul piano gratuito di Gemini stanno larghe, ma se un giorno
  finisce, le videochiamate tornano al generatore offline e le traduzioni alternative
  ricadono sul corso e sulle forme già imparate.
- **Il bundle identifier.** Se installi su due telefoni con lo stesso Apple ID va bene
  così; se usate due Apple ID diversi, ognuno mette il proprio Team in *Signing &
  Capabilities*.
- **Chi ha la chiave ha il conto.** Una chiave dentro un'app si può estrarre dal bundle:
  fra voi due non è un problema, ma è il motivo per cui l'app non va data ad altri.

---

## Il corso in numeri

- **4 livelli** (A1, A2, B1, B2)
- **32 unità** (8 per livello)
- **339 lezioni** + 32 dialoghi + 32 ripassi d'unità = **403 tappe** di percorso
- ogni lezione richiede **5 sessioni** → circa **1.760 sessioni** per arrivare al B2
- **6.581 coppie di traduzione** (vocaboli + frasi complete)
- **77 note di grammatica** bilingui + **256 domande di conversazione** legate ai capitoli

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
       └─ Ripasso       test finale su tutta l'unità (20 esercizi)
```

### Ogni lezione si fa 5 volte, e ogni volta è diversa

Come una skill di Duolingo, una lezione non è finita al primo giro: servono **5
sessioni**, e il percorso non avanza finché non sono tutte fatte (l'anello intorno
al nodo mostra 1/5, 2/5…). Ogni passaggio allena qualcosa di diverso:

| # | Sessione | Che cosa fa |
|---|---|---|
| 1 | **Scoperta** | incontri le parole: abbinamenti, scelta multipla, audio d'appoggio |
| 2 | **Ascolto** | solo orecchio: dettati e riconoscimento audio |
| 3 | **Scrittura** | produci tu le frasi con la tastiera |
| 4 | **Parlato** | pronuncia al microfono |
| 5 | **Ripasso** | tutto insieme, senza aiuti e con più produzione |

L'abilità in evidenza occupa circa metà della sessione: **anche dentro un singolo
giro gli esercizi restano mescolati**, non diventa mai una fila di quindici dettati.
Dialoghi e ripassi d'unità restano invece a sessione singola.

Ogni unità ha anche un **manuale** (l'icona 📖 sul banner) con le note di grammatica e
l'elenco completo delle parole, ognuna con audio e indicatore di memoria.

### Le frasi non sono sempre le stesse

Il corso ha un corpus fisso, quindi al quinto giro su una lezione le quindici frasi
sarebbero le stesse del primo: non si traduce più, si ricorda quale bottone si era
premuto. Con una chiave IA configurata l'app **si scrive frasi nuove da sola**
(`PhraseForge`): stesso lessico del capitolo, stessa grammatica, stesso livello CEFR —
ma frasi che nessuno ha mai visto.

- Il **primo** giro su una lezione resta sempre sul corpus del corso: le parole nuove
  si incontrano in frasi verificate, non inventate.
- Dal secondo in poi la sessione è circa **metà capitolo e metà frasi nuove**.
- La lunghezza è vincolata al livello (A1 3-6 parole, A2 4-9, B1 6-13, B2 8-18), così
  «nuovo» non diventa mai di nascosto «più difficile».
- Tutto quello che arriva viene **tenuto su disco** e si accumula: dopo i primi giri
  c'è varietà anche offline, e ogni capitolo arriva a un massimo di 90 frasi.
- Si disattiva da *Profilo → Frasi sempre nuove*. Senza chiave non parte mai e il
  corso funziona esattamente come prima.

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

### Le note di grammatica sono bilingui *e asimmetriche*

Una stessa nota contiene due testi diversi, non una traduzione:

- il testo **italiano** spiega **la grammatica uzbeka** a chi parla italiano;
- il testo **uzbeko** spiega **la grammatica italiana** a chi parla uzbeko.

Esempio (A1, unità 1): allo studente italiano si spiega che l'uzbeko non ha il verbo
*essere* al presente ma usa le desinenze `-man/-san/-miz`; allo studente uzbeko si spiega
che l'italiano usa sempre *essere* e che è irregolare.

---

## I tipi di esercizio

Gli esercizi non sono scritti a mano uno per uno: un motore (`ExerciseFactory`) li genera
da ogni coppia di traduzione, scegliendo il formato adatto alla lunghezza della frase e
alternandoli in modo che lo stesso tipo non capiti due volte di fila.

| Esercizio | Abilità | Descrizione |
|---|---|---|
| **Abbina le coppie** | lettura | 5 parole da accoppiare con la traduzione |
| **Scelta multipla** | lettura | 4 opzioni, con audio se il testo è in lingua target |
| **Completa la frase** | lettura/grammatica | una parola tolta dalla frase, 4 candidate |
| **Costruisci la frase** | produzione | word bank con tessere + distrattori |
| **Scrivi la traduzione** | scrittura | tastiera libera, con tolleranza ai refusi |
| **Scrivi quello che senti** | ascolto + scrittura | dettato con audio (normale e lento) |
| **Ascolta e scegli** | ascolto | solo audio, 4 opzioni testuali |
| **Pronuncia la frase** | parlato | microfono + riconoscimento vocale e punteggio |

Per l'uzbeko c'è una **riga di tasti rapidi** (`o'`, `g'`, `sh`, `ch`, `ng`, `'`) sopra la
tastiera negli esercizi di scrittura.

### Come vengono corrette le risposte

`Grader` normalizza prima di confrontare: minuscole, spazi multipli, punteggiatura,
accenti italiani (*perche* = *perché*) e **tutte le varianti di apostrofo uzbeko**
(`o'` = `oʻ` = `o‘`). Un refuso di una lettera su parole lunghe viene accettato come
“Quasi!” mostrando la grafia corretta; le parole corte devono essere esatte. Sono
ammesse risposte alternative scrivendo `forma1 / forma2` nel contenuto.

---

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

- **Le domande non sono un copione fisso.** Vengono composte al momento a partire dal
  **capitolo a cui sei arrivata** in quel livello: se sei a «Cibo e bevande» ti chiede che
  cosa mangi a colazione, se sei a «Raccontare il passato» ti chiede un ricordo d'infanzia.
  Ogni chiamata mescola domande nuove, un paio di ripassi dai capitoli precedenti, un
  aggancio a metà conversazione («E perché?», «Fammi un esempio») e una chiusura: **due
  chiamate uguali praticamente non capitano** (un test lo verifica su dodici chiamate).
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

### Con una chiave IA (facoltativo)

In *Profilo → Impostazioni → Assistente IA* puoi scegliere fra tre opzioni:

| | |
|---|---|
| **Nessuna** (default) | tutto offline: domande dal corso, correzione con regole e corpus |
| **Gemini (gratis)** | chiave da `aistudio.google.com/apikey`, ha un piano gratuito |
| **Claude (a pagamento)** | chiave da `console.anthropic.com`, richiede credito prepagato |

Con una chiave la videochiamata diventa **una conversazione scritta sul momento**:

- ogni turno è generato da quello che hai appena risposto — Anorcha reagisce a un
  dettaglio che hai detto e la domanda dopo nasce da lì, invece di leggere una scaletta;
- **tiene il filo**: resta sullo stesso argomento per due o tre scambi prima di spostarsi,
  non richiede mai una cosa a cui hai già risposto, e torna su quello che le hai detto
  prima. Le dici che hai preso il tè con tua sorella e ti chiede dov'è; le dici che si
  chiama Malika e lavora a Tashkent e ti chiede che lavoro fa;
- il modello riceve un *briefing* su di te: capitolo in corso, lezioni dentro al
  capitolo, vocabolario appena studiato, capitoli già fatti, le parole che sbagli più
  spesso, i giorni di fila e l'ora del giorno;
- **due chiamate non si somigliano mai**: a ogni chiamata viene estratto a sorte un
  «angolo» fra dodici (parti da un ricordo, confronta due cose, mettila in una
  situazione…), il vocabolario viene rimescolato, e le ultime 60 domande già fatte
  vengono passate al modello come lista da evitare;
- la correzione finale è argomentata invece che basata su regole.

L'interfaccia è identica e compare ✨. C'è un pulsante **Prova la chiave** che fa una
richiesta vera e ti dice subito se funziona o qual è l'errore.

Se la chiamata al modello fallisce (chiave sbagliata, quota finita, niente rete), la
videochiamata **non si interrompe**: ricade sul generatore e sul correttore offline, e
smette di riprovare per non bruciare quota.

La chiave serve anche agli **esercizi**, per far accettare le traduzioni alternative:
vedi più sotto.

> Stato delle verifiche: il percorso offline è provato end-to-end. Del percorso IA ho
> potuto verificare che la richiesta a Gemini è formata correttamente — l'ho eseguita con
> una chiave finta e Google ha risposto rifiutando **solo la chiave** (400 «API key not
> valid»), il che dimostra che endpoint, header e corpo sono giusti. Non ho potuto provare
> una risposta completa perché non ho una chiave vera.

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

Quando scrivi una traduzione tua e il correttore non la riconosce, prima di segnarla
sbagliata l'app prova tre strade, dalla più economica alla più costosa:

| | |
|---|---|
| **Il corso stesso** | se quella forma è insegnata altrove come traduzione della stessa frase, è accettata subito, offline |
| **La tua storia** | una forma già accettata in passato vale per sempre, senza nessuna richiesta di rete |
| **L'assistente** | con una chiave configurata, il modello decide se è un modo naturale di dire la stessa cosa |
| **Tu** | se nessuno dei tre la riconosce, sotto l'errore c'è **«Anche la mia è giusta»**: un tocco e viene accettata, il cuore torna indietro e la forma è imparata per sempre |

L'esaminatore è **severo sul significato e generoso sul registro**: colloquiale,
abbreviato, regionale o più formale vanno tutti bene; viene rifiutato solo ciò che
significa altro, è in un'altra lingua o non è grammaticale.

Quando passa, **non è un errore corretto: è una risposta giusta**. Spunta verde,
*«Corretto!»*, la tua forma con la sua traduzione — e solo sotto, in piccolo, *«Nel corso
te l'avrei detta così, ma la tua va benissimo»* con la versione del libro. La forma resta
**imparata per sempre**, anche offline.

Le prime tre strade sono istantanee o quasi. Il pulsante è l'ultima spiaggia, per quando
nessuno può decidere: **con una chiave configurata non lo vedi quasi mai**, perché il
giudizio arriva da solo prima del verdetto.

Vale per gli esercizi di traduzione libera (scrittura e banco di parole). Il dettato e
le scelte multiple hanno una risposta sola, e restano tali.

Senza chiave restano attive le altre tre strade: il corso, la tua storia e il pulsante.
Il pulsante compare solo dove più di una risposta è davvero possibile — traduzione
scritta e banco di parole — e mai sul dettato o sulle scelte multiple.

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
più niente dal telefono. In *Profilo → Voce* vedi quanto è grande la cache e puoi
svuotarla.

Se la rete cade o un servizio smette di rispondere, si torna **da sola** alla voce turca
di iOS: l'audio non smette mai di funzionare, peggiora e basta. E l'avviso «pronuncia
approssimata» compare solo quando lo è davvero.

## Tocca una parola per il significato

Dentro un esercizio, un tocco su una parola apre sotto una piccola carta con **che cosa
vuol dire quella parola** — e, quando la riga è un'espressione che il corso insegna
intera, anche **che cosa vuol dire tutta l'espressione**, perché `ertaga ko'rishguncha`
non è «domani fino-a-vederci».

Da dove esce il significato, dal più economico al più caro:

| | |
|---|---|
| **Il corso** | se la parola è insegnata da sola, o la frase è una voce sua, è istantaneo e offline |
| **La tua cronologia** | ogni significato già cercato è tenuto per sempre: una parola si cerca una volta sola nella vita dell'app |
| **L'assistente** | con una chiave, gliela chiede — ed è quasi sempre lui, per il motivo qui sotto |

Il corso insegna da sola solo una parola su cinque (**22%** in uzbeko, 35% in italiano):
tutte le altre compaiono soltanto dentro le frasi. Senza chiave quindi il tocco funziona
in una minoranza dei casi; con la chiave funziona quasi sempre, e ogni risultato resta
sul telefono.

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
la fai giusta. Una risposta accettata con «Anche la mia è giusta» invece non torna: non
era un errore.

Qualunque cosa scritta nella lingua che stai imparando si tocca e si sente: le opzioni
di risposta, le tessere dell'abbinamento, i chip del banco di parole, le parole chiave
di una lezione, le righe di una storia, il vocabolario della guida, gli errori nel
riepilogo, i sottotitoli della videochiamata.

Dentro una frase il bersaglio è **la singola parola**: tocchi *kech* e senti *kech*, non
tutta la riga. Per l'intera frase ci sono i pulsanti 🔊 e 🐢 di sempre, oppure un tocco
prolungato.

## Gamification

- **Cuori e gemme illimitati** (è un regalo, non un negozio): ∞ nell'intestazione,
  gli errori non ti fermano mai. C'è comunque un interruttore in *Profilo →
  Impostazioni* se un giorno volessi rimettere il limite dei 5 cuori.
- **XP** per sessione, con bonus per precisione e per gli esercizi di pronuncia
- **Obiettivo giornaliero** configurabile (20/50/100/150 XP) con barra di avanzamento
- **Serie (streak)** giornaliera, con *salva-serie* che copre un giorno saltato
- **Corone**: fino a 3 per tappa, in base alle sessioni completate
- **Promemoria giornaliero** opzionale (notifica locale all'ora che scegli, testo bilingue
  che ricorda la serie in corso)

## Ripassare quello che hai già fatto

- **Ripassa questa unità**: dentro il manuale di ogni unità già iniziata, un pulsante
  genera una sessione di 18 esercizi pescati da tutta l'unità. Ripetibile all'infinito,
  senza cuori.
- **Allenati → Ripassa un capitolo**: l'elenco di tutte le unità che hai iniziato, con
  la percentuale di avanzamento, per riallenarne una qualsiasi quando vuoi.
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

L'app lo dichiara apertamente: sotto il microfono e in *Profilo → Impostazioni → Voce usata*.
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

## Modificare o ampliare il corso

Il contenuto si scrive in `content/a1.py … b2.py`, in un formato compatto:

```python
# content/a1.py — le lezioni narrative
("a1u1l1", ("Saluti", "Salomlashish"),
 [("ciao", "salom"), ("grazie", "rahmat")],          # vocaboli
 [("Ciao, come stai?", "Salom, qalaysan?")]),        # frasi

# content/extra_a1.py — i pacchetti di lessico, che diventano lezioni in più
"a1u4": [
  ("Frutta e verdura", "Meva va sabzavot",
   [("pera", "nok"), ("melagrana", "anor")],
   [("Compro tre chili di uva.", "Uch kilo uzum sotib olaman.")]),
]
```

Le domande delle videochiamate stanno in `content/questions.py`: otto per ogni unità,
più aperture, rilanci e chiusure per livello.

Poi si ricompila e si valida in un comando:

```bash
python3 content/build.py
```

Il compilatore rifiuta il contenuto se trova lati vuoti, caratteri cirillici finiti per
sbaglio nel testo uzbeko, apostrofi tipografici, id duplicati o lezioni troppo povere.
Dopo la ricompilazione, i **70 test** Xcode rigenerano sessioni su tutte le unità in
entrambe le direzioni e verificano che ogni domanda sia risolvibile: risposta sempre
presente tra le opzioni, nessun doppione, word bank sempre in grado di ricostruire la
frase, nessun distrattore segnaposto, e nessuna domanda con due risposte giuste (parole
che condividono una traduzione, come *bog'* = giardino/parco, non finiscono mai nella
stessa domanda). Gli altri test coprono le bande CEFR del lessico, il correttore di
risposte, la ripetizione dilazionata, le cinque sessioni con focus diversi, i test di
sblocco, le videochiamate (domande sempre diverse e legate al capitolo giusto, e un correttore
che non inventa errori) e il tempo di costruzione di una sessione sul corpus completo.

---

## Mascotte

**Anorcha**, un melograno (`anor`, il frutto simbolo dell'Uzbekistan) disegnato
interamente con forme SwiftUI — nessuna immagine da caricare.

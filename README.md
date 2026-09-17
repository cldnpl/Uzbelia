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

Con un Apple ID gratuito l'app **scade dopo 7 giorni** e va reinstallata da Xcode; con un
account Apple Developer a pagamento dura un anno.

Il progetto Xcode è generato da [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Se modifichi `project.yml` (o aggiungi cartelle di sorgenti), rigeneralo con `xcodegen generate`.
La firma è **automatica** e il campo Team è volutamente vuoto, così Xcode ti fa scegliere
il tuo.

Requisiti: Xcode 16+, iOS 17.0 o successivo. Nessuna dipendenza esterna, nessun account.
Senza chiave IA **funziona interamente offline**; con una chiave la rete serve solo per la
videochiamata e per il giudizio sulle traduzioni alternative, e se manca ricade sull'offline.

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
significa altro, è in un'altra lingua o non è grammaticale. Se passa, vedi *«Va bene
anche così!»*, la tua forma con la sua traduzione, la versione del corso come
riferimento e una riga che spiega la sfumatura — e la forma resta **imparata per
sempre**, anche offline.

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

### E il riconoscimento, senza carta?

Lo fa **Gemini**, con la stessa chiave gratuita delle videochiamate (AI Studio non chiede
nessuna carta). L'app registra a 16 kHz e manda l'audio al modello, che scrive quello che
ha sentito. L'ordine è: Azure se c'è la chiave, altrimenti Gemini, altrimenti il turco
approssimato di iOS come è sempre stato.

**L'audio viene messo in cache su disco**, per voce e per velocità: un corso ripete di
continuo le stesse parole, quindi dopo il primo passaggio su un capitolo non esce quasi
più niente dal telefono. In *Profilo → Voce* vedi quanto è grande la cache e puoi
svuotarla.

Se la rete cade o un servizio smette di rispondere, si torna **da sola** alla voce turca
di iOS: l'audio non smette mai di funzionare, peggiora e basta. E l'avviso «pronuncia
approssimata» compare solo quando lo è davvero.

## Ogni parola si può ascoltare

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

## Architettura

```
Sources/
├── App/              punto di ingresso, tab bar, testi dell'interfaccia (it + uz)
├── DesignSystem/     palette, tipografia, bottoni 3D, mascotte, componenti
├── Models/           albero del corso (Curriculum) e stato utente persistito
├── Content/          caricamento del curriculum dal bundle
├── Engine/           Exercise, ExerciseFactory, Grader, SRS
├── Services/         sintesi vocale, riconoscimento vocale, feedback aptico
└── Features/
    ├── Onboarding/   scelta corso, livello di partenza, obiettivo
    ├── Path/         percorso a serpentina, schede tappa, manuale d'unità
    ├── Lesson/       motore di sessione, 8 viste esercizio, storie, risultati
    ├── Practice/     allenamento libero, drill per abilità, elenco parole
    ├── Grammar/      tutte le note del corso, con ricerca
    └── Profile/      statistiche, grafico settimanale, negozio, impostazioni
content/              sorgenti del curriculum (Python) + compilatore in JSON
Resources/Curriculum/ JSON generati e inclusi nell'app
Tests/                test su contenuti, grader, SRS e motore esercizi
```

Lo stato (progressi, XP, serie, SRS, impostazioni) è un unico blob JSON in
*Application Support*, con decodifica tollerante: aggiungere campi in futuro non
cancella i progressi di chi sta già studiando.

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

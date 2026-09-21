#!/bin/bash
# Crea da zero il progetto Firebase che dà all'app gli account — email, Apple e
# Google — e scrive le chiavi in Sources/Services/Secrets.swift.
#
# Fa tutto lui tranne una cosa che solo tu puoi fare, e per cui aprirà il browser:
#   · il login con il tuo account Google
#
# Serve node (ce l'hai già se hai npm). Il piano gratuito Spark basta e avanza:
# Authentication è gratis, Firestore ha 50.000 letture e 20.000 scritture al giorno,
# e questa app ne fa una manciata a persona.
#
# Su un progetto che esiste già:  ./scripts/crea-progetto-firebase.sh <PROJECT_ID>
set -e
cd "$(dirname "$0")/.."

BUNDLE="com.uzbelia.app"
FILE="Sources/Services/Secrets.swift"
PROGETTO="${1:-}"

verde()  { printf "\033[32m%s\033[0m\n" "$1"; }
giallo() { printf "\033[33m%s\033[0m\n" "$1"; }
rosso()  { printf "\033[31m%s\033[0m\n" "$1"; }

echo "▸ 1/9  Controllo firebase-tools…"
if ! command -v firebase >/dev/null 2>&1; then
  echo "       non c'è, lo installo (può chiedere la password del Mac)"
  npm install -g firebase-tools
fi

echo "▸ 2/9  Login Google (si apre il browser)…"
if ! firebase login:list 2>/dev/null | grep -q "@"; then
  firebase login
fi
firebase login:list

# L'access token che la CLI si è appena presa serve anche a noi, per i tre
# interruttori che la CLI non ha un comando per alzare. Un comando qualsiasi lo
# rinfresca e lo riscrive nel configstore.
firebase projects:list >/dev/null 2>&1 || true
TOKEN=$(node -e '
  const fs=require("fs"),os=require("os"),path=require("path");
  const p=[path.join(os.homedir(),".config/configstore/firebase-tools.json"),
           path.join(os.homedir(),"Library/Preferences/configstore/firebase-tools.json")];
  for (const f of p) {
    try { const t=JSON.parse(fs.readFileSync(f,"utf8")).tokens;
          if (t && t.access_token) { console.log(t.access_token); break; } } catch {}
  }' 2>/dev/null || true)

api() {  # api <metodo> <url> [corpo]
  [ -n "$TOKEN" ] || return 1
  if [ -n "$3" ]; then
    curl -sS -X "$1" "$2" -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" -d "$3"
  else
    curl -sS -X "$1" "$2" -H "Authorization: Bearer $TOKEN"
  fi
}
ok() { echo "$1" | grep -q '"error"' && return 1 || return 0; }

if [ -z "$PROGETTO" ]; then
  PROGETTO="uzbelia-$(date +%s | tail -c 6)"
  echo "▸ 3/9  Creo il progetto $PROGETTO…"
  firebase projects:create "$PROGETTO" --display-name "Uzbelia"
else
  echo "▸ 3/9  Uso il progetto che mi hai dato: $PROGETTO"
fi

echo "▸ 4/9  App web (è lei che porta la Web API Key)…"
firebase apps:create WEB "Uzbelia" --project "$PROGETTO" >/dev/null 2>&1 || true
APP_WEB=$(firebase apps:list WEB --project "$PROGETTO" --json | node -e \
  'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
     const a=JSON.parse(s).result;console.log(a&&a[0]?a[0].appId:"")})')
CHIAVE=$(firebase apps:sdkconfig WEB "$APP_WEB" --project "$PROGETTO" --json 2>/dev/null | node -e \
  'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
     try{console.log(JSON.parse(s).result.sdkConfig.apiKey||"")}catch{console.log("")}})')

if [ -z "$CHIAVE" ]; then
  rosso "✗ Non sono riuscito a leggere la Web API Key."
  echo "  Prendila a mano da console.firebase.google.com → ⚙ Impostazioni progetto,"
  echo "  poi:  ./scripts/set-firebase-keys.sh <CHIAVE> $PROGETTO"
  exit 1
fi

# Questo è il passo che mancava, ed è il motivo per cui il pulsante Google non
# poteva funzionare: registrando l'app iOS, Firebase crea da sé il client OAuth
# iOS legato al bundle, e lo consegna dentro il GoogleService-Info.
echo "▸ 5/9  App iOS ($BUNDLE) — è lei che porta il client OAuth di Google…"
firebase apps:create IOS "Uzbelia iOS" --project "$PROGETTO" --bundle-id "$BUNDLE" >/dev/null 2>&1 || true
APP_IOS=$(firebase apps:list IOS --project "$PROGETTO" --json | node -e \
  'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
     const a=JSON.parse(s).result;console.log(a&&a[0]?a[0].appId:"")})')
CLIENT=""
if [ -n "$APP_IOS" ]; then
  CLIENT=$(firebase apps:sdkconfig IOS "$APP_IOS" --project "$PROGETTO" --json 2>/dev/null | node -e \
    'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
       let t="";try{const r=JSON.parse(s).result;
         t=r.fileContents||r.sdkConfig&&r.sdkConfig.CLIENT_ID||"";}catch{}
       if(/^[0-9]/.test(t)&&t.includes("apps.googleusercontent.com")){console.log(t.trim());return;}
       const m=/<key>CLIENT_ID<\/key>\s*<string>([^<]+)<\/string>/.exec(t);
       console.log(m?m[1]:"")})')
fi

echo "▸ 6/9  Accendo i tre modi di accedere…"
RESTA_GOOGLE=0
RESTA_APPLE=0
ADMIN="https://identitytoolkit.googleapis.com/admin/v2/projects/$PROGETTO"

R=$(api PATCH "$ADMIN/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired" \
      '{"signIn":{"email":{"enabled":true,"passwordRequired":true}}}' || true)
ok "$R" && verde "       ✓ Email e password" || giallo "       … Email/password: da alzare a mano"

# Apple, per un'app iOS nativa, non chiede altro che il bundle: la firma la fa
# il dispositivo, e Firebase deve solo sapere quale app accettare.
R=$(api POST "$ADMIN/defaultSupportedIdpConfigs?idpId=apple.com" \
      "{\"enabled\":true,\"clientId\":\"$BUNDLE\"}" || true)
if ok "$R"; then verde "       ✓ Apple"
else
  R=$(api PATCH "$ADMIN/defaultSupportedIdpConfigs/apple.com?updateMask=enabled,clientId" \
        "{\"enabled\":true,\"clientId\":\"$BUNDLE\"}" || true)
  ok "$R" && verde "       ✓ Apple" || { giallo "       … Apple: da alzare a mano"; RESTA_APPLE=1; }
fi

R=$(api POST "$ADMIN/defaultSupportedIdpConfigs?idpId=google.com" '{"enabled":true}' || true)
if ok "$R"; then verde "       ✓ Google"
else
  R=$(api PATCH "$ADMIN/defaultSupportedIdpConfigs/google.com?updateMask=enabled" \
        '{"enabled":true}' || true)
  ok "$R" && verde "       ✓ Google" || { giallo "       … Google: da alzare a mano"; RESTA_GOOGLE=1; }
fi

echo "▸ 7/9  Database Firestore…"
R=$(api POST "https://firestore.googleapis.com/v1/projects/$PROGETTO/databases?databaseId=(default)" \
      '{"type":"FIRESTORE_NATIVE","locationId":"eur3"}' || true)
echo "$R" | grep -q "ALREADY_EXISTS" && verde "       ✓ c'era già" \
  || { ok "$R" && verde "       ✓ creato" || giallo "       … da creare a mano nella console"; }

echo "▸ 8/9  Regole: ognuno tocca solo il proprio documento…"
mkdir -p .firebase
cat > .firebase/firestore.rules <<'RULES'
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /learners/{uid} {
      allow read, write: if request.auth != nil && request.auth.uid == uid;
    }
  }
}
RULES
cat > .firebase/firebase.json <<'CONF'
{ "firestore": { "rules": "firestore.rules" } }
CONF
if (cd .firebase && firebase deploy --only firestore:rules --project "$PROGETTO" >/dev/null 2>&1); then
  verde "       ✓ caricate"
else
  giallo "       … non caricate: le incollerai a mano (sono in .firebase/firestore.rules)"
fi

echo "▸ 9/9  Scrivo le chiavi nell'app…"
./scripts/set-firebase-keys.sh "$CHIAVE" "$PROGETTO"
if [ -n "$CLIENT" ]; then
  ./scripts/set-firebase-keys.sh --google "$CLIENT"
else
  giallo "       … client OAuth iOS non letto: il pulsante Google resterà nascosto"
  RESTA_GOOGLE=1
fi

echo
echo "════════════════════════════════════════════════════════════════"
echo "  PROGETTO:  $PROGETTO"
echo "  API KEY:   $CHIAVE"
[ -n "$CLIENT" ] && echo "  GOOGLE:    $CLIENT" || true
echo "  (tutto già scritto in $FILE)"
echo "════════════════════════════════════════════════════════════════"
echo

if [ "$RESTA_APPLE" = "1" ] || [ "$RESTA_GOOGLE" = "1" ]; then
  giallo "Resta un interruttore da alzare a mano — trenta secondi:"
  echo "  https://console.firebase.google.com/project/$PROGETTO/authentication/providers"
  [ "$RESTA_APPLE" = "1" ]  && echo "    → abilita  Apple   (nessun campo da riempire: Salva)" || true
  [ "$RESTA_GOOGLE" = "1" ] && echo "    → abilita  Google  (email di supporto: la tua)" || true
  echo
  command -v open >/dev/null && \
    open "https://console.firebase.google.com/project/$PROGETTO/authentication/providers" || true
else
  verde "Non resta niente da fare nella console."
fi

echo "Poi ricompila:  xcodegen generate && open Uzbelia.xcodeproj   (⌘R)"
echo
echo "Nota: Accedi con Apple funziona solo su un iPhone vero, o su un simulatore"
echo "dove hai fatto l'accesso con un ID Apple (Impostazioni → Accedi)."

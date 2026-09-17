#!/bin/bash
# Scrive la chiave Gemini in Sources/Services/Secrets.swift.
# Uso:  ./scripts/set-gemini-key.sh <CHIAVE>
#
# Google ha emesso due formati di chiave API: i vecchi "AIza…" e, dai primi mesi
# del 2026, quelli che iniziano con "AQ.". Funzionano entrambi.
set -e
cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
  echo "Uso: ./scripts/set-gemini-key.sh <CHIAVE>"
  exit 1
fi

FILE="Sources/Services/Secrets.swift"
/usr/bin/sed -i '' "s|static let geminiKey = \".*\"|static let geminiKey = \"$1\"|" "$FILE"
git update-index --skip-worktree "$FILE" 2>/dev/null || true
echo "✓ Chiave Gemini scritta in $FILE (e tenuta fuori da git)"

echo "▸ La provo davvero…"
CODE=$(curl -s -o /tmp/uzbelia-keytest.json -w "%{http_code}" -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent" \
  -H "x-goog-api-key: $1" -H "Content-Type: application/json" \
  -d '{"contents":[{"role":"user","parts":[{"text":"Rispondi solo: ciao"}]}]}')
if [ "$CODE" = "200" ]; then
  echo "✅ La chiave funziona. Ricompila e hai videochiamate IA, traduzioni alternative e voce uzbeka riconosciuta."
else
  echo "⚠ Google ha risposto $CODE:"
  /usr/bin/python3 -c "import json;print(' ', json.load(open('/tmp/uzbelia-keytest.json')).get('error',{}).get('message','?')[:200])" 2>/dev/null
fi
rm -f /tmp/uzbelia-keytest.json

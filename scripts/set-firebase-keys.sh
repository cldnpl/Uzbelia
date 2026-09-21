#!/bin/bash
# Scrive le chiavi dell'account in Sources/Services/Secrets.swift.
#
# Uso:  ./scripts/set-firebase-keys.sh <WEB_API_KEY> <PROJECT_ID>
#       ./scripts/set-firebase-keys.sh --google <ID_CLIENT_OAUTH_IOS>
set -e
cd "$(dirname "$0")/.."

FILE="Sources/Services/Secrets.swift"

scrivi() {   # scrivi <nome-costante> <valore>
  /usr/bin/sed -i '' "s|static let $1 = \".*\"|static let $1 = \"$2\"|" "$FILE"
}

if [ "$1" = "--google" ]; then
  [ $# -eq 2 ] || { echo "Uso: ./scripts/set-firebase-keys.sh --google <ID_CLIENT_OAUTH_IOS>"; exit 1; }
  scrivi googleOAuthClientID "$2"
  echo "✓ Client Google scritto in $FILE"
else
  if [ $# -ne 2 ]; then
    echo "Uso: ./scripts/set-firebase-keys.sh <WEB_API_KEY> <PROJECT_ID>"
    echo "     ./scripts/set-firebase-keys.sh --google <ID_CLIENT_OAUTH_IOS>"
    echo
    echo "Le prime due si trovano su console.firebase.google.com → ⚙ Impostazioni progetto."
    exit 1
  fi
  scrivi firebaseAPIKey "$1"
  scrivi firebaseProjectID "$2"
  echo "✓ Chiavi Firebase scritte in $FILE"
fi

# tiene le chiavi fuori dai commit, come per Azure e Gemini
git update-index --skip-worktree "$FILE" 2>/dev/null || true

grep -n "firebaseAPIKey\|firebaseProjectID\|googleOAuthClientID" "$FILE" | grep "static let"
echo
echo "Ora ricompila (⌘R in Xcode) e l'ultimo passo dell'onboarding funziona."

#!/bin/bash
# Scrive la chiave Azure Speech in Sources/Services/Secrets.swift.
# Uso:  ./scripts/set-azure-key.sh <CHIAVE> <REGIONE>
set -e
cd "$(dirname "$0")/.."

if [ $# -ne 2 ]; then
  echo "Uso: ./scripts/set-azure-key.sh <CHIAVE> <REGIONE>"
  echo "Esempio: ./scripts/set-azure-key.sh abc123... westeurope"
  exit 1
fi

FILE="Sources/Services/Secrets.swift"
/usr/bin/sed -i '' "s|static let azureSpeechKey = \".*\"|static let azureSpeechKey = \"$1\"|" "$FILE"
/usr/bin/sed -i '' "s|static let azureSpeechRegion = \".*\"|static let azureSpeechRegion = \"$2\"|" "$FILE"

# tiene la chiave fuori dai commit
git update-index --skip-worktree "$FILE" 2>/dev/null || true

echo "✓ Chiave scritta in $FILE (e tenuta fuori da git)"
grep -n "azureSpeechRegion" "$FILE"

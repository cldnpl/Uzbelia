#!/bin/bash
# Crea una risorsa Speech gratuita (F0) e stampa chiave e regione.
set -e

GRUPPO="uzbelia"
NOME="uzbelia-speech-$RANDOM"
REGIONE="westeurope"

echo "▸ Controllo l'abbonamento Azure…"
if ! az account show >/dev/null 2>&1; then
  echo "✗ Non sei loggata. Esegui prima:  az login"
  exit 1
fi
az account show --query "{abbonamento:name, stato:state}" -o table

echo "▸ Creo il gruppo di risorse…"
az group create --name "$GRUPPO" --location "$REGIONE" -o none

echo "▸ Creo la risorsa Speech gratuita (F0)…"
az cognitiveservices account create \
  --name "$NOME" --resource-group "$GRUPPO" \
  --kind SpeechServices --sku F0 --location "$REGIONE" \
  --yes -o none

echo "▸ Leggo la chiave…"
CHIAVE=$(az cognitiveservices account keys list --name "$NOME" --resource-group "$GRUPPO" --query key1 -o tsv)

echo
echo "════════════════════════════════════════"
echo "  CHIAVE:   $CHIAVE"
echo "  REGIONE:  $REGIONE"
echo "════════════════════════════════════════"
echo
echo "Per metterle nell'app, incolla questo (con la chiave qui sopra):"
echo
echo "  cd ~/Desktop/uzbelia && ./scripts/set-azure-key.sh $CHIAVE $REGIONE"

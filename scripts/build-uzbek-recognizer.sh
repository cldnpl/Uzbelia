#!/bin/bash
# Ricostruisce il riconoscitore uzbeko che gira sul telefono:
#
#   Frameworks/whisper.xcframework        (whisper.cpp compilato per iPhone)
#   Resources/Models/ggml-uzbek-small.bin (il modello, 181 MB)
#
# Sono due artefatti troppo grandi per git. Senza di loro l'app compila lo stesso:
# il riconoscitore si dichiara non disponibile e si torna alle vie di prima.
#
# Serve: cmake (brew install cmake), Xcode, python3. Scarica circa 1 GB.
set -e
cd "$(dirname "$0")/.."
ROOT="$PWD"
WORK="${TMPDIR:-/tmp}/uzbelia-asr"
MODEL="navai-uz/whisper-small-uzbek"

mkdir -p "$WORK" && cd "$WORK"

echo "▸ 1/5  whisper.cpp"
[ -d whisper.cpp ] || git clone --depth 1 https://github.com/ggml-org/whisper.cpp

echo "▸ 2/5  XCFramework per iPhone (qualche minuto)"
if [ ! -d whisper.cpp/build-apple/whisper.xcframework ]; then
  (cd whisper.cpp && ./build-xcframework.sh > "$WORK/xcframework.log" 2>&1) \
    || { echo "✗ compilazione fallita, vedi $WORK/xcframework.log"; exit 1; }
fi

echo "▸ 3/5  modello da HuggingFace (~970 MB)"
mkdir -p hf
for f in config.json preprocessor_config.json tokenizer.json vocab.json \
         added_tokens.json special_tokens_map.json normalizer.json generation_config.json \
         tokenizer_config.json merges.txt model.safetensors; do
  [ -f "hf/$f" ] || curl -fsSL -o "hf/$f" \
    "https://huggingface.co/$MODEL/resolve/main/$f" || true
done
[ -s hf/model.safetensors ] || { echo "✗ pesi non scaricati"; exit 1; }

echo "▸ 4/5  conversione in ggml e quantizzazione"
python3 -m venv .venv 2>/dev/null || true
./.venv/bin/pip install -q torch transformers numpy
mkdir -p openai-whisper/whisper/assets ggml
[ -f openai-whisper/whisper/assets/mel_filters.npz ] || curl -fsSL \
  -o openai-whisper/whisper/assets/mel_filters.npz \
  "https://raw.githubusercontent.com/openai/whisper/main/whisper/assets/mel_filters.npz"
./.venv/bin/python whisper.cpp/models/convert-h5-to-ggml.py hf openai-whisper ggml

cmake -S whisper.cpp -B whisper.cpp/build-host -DCMAKE_BUILD_TYPE=Release \
      -DWHISPER_BUILD_TESTS=OFF > /dev/null
cmake --build whisper.cpp/build-host -j8 --target whisper-quantize > /dev/null
whisper.cpp/build-host/bin/whisper-quantize ggml/ggml-model.bin ggml/ggml-uzbek-small.bin q5_1

echo "▸ 5/5  installazione nel progetto"
rm -rf "$ROOT/Frameworks/whisper.xcframework"
mkdir -p "$ROOT/Frameworks" "$ROOT/Resources/Models"
cp -R whisper.cpp/build-apple/whisper.xcframework "$ROOT/Frameworks/"
# solo le due varianti che serve compilare per iPhone
rm -rf "$ROOT"/Frameworks/whisper.xcframework/{tvos-*,xros-*,macos-*}
python3 - "$ROOT/Frameworks/whisper.xcframework/Info.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
d = plistlib.load(open(path, 'rb'))
keep = {'ios-arm64', 'ios-arm64_x86_64-simulator'}
d['AvailableLibraries'] = [l for l in d['AvailableLibraries'] if l['LibraryIdentifier'] in keep]
plistlib.dump(d, open(path, 'wb'))
PY
cp ggml/ggml-uzbek-small.bin "$ROOT/Resources/Models/"

cd "$ROOT" && xcodegen generate > /dev/null
echo
echo "✅ Fatto. Ricompila l'app: l'uzbeko ora lo riconosce il telefono, offline."
du -sh Frameworks/whisper.xcframework Resources/Models/ggml-uzbek-small.bin

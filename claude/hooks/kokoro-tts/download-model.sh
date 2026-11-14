#!/bin/bash
# Download Kokoro ONNX model + voices bundle into ./models/.
# Default: full-precision kokoro-v1.0.onnx (~310 MB) + voices-v1.0.bin (~28 MB).
# Override the model variant via $1 (e.g. kokoro-v1.0.fp16, kokoro-v1.0.int8).
set -euo pipefail

VARIANT="${1:-kokoro-v1.0}"
DIR="$(cd "$(dirname "$0")" && pwd)/models"
mkdir -p "$DIR"

BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"

curl -fL -o "$DIR/${VARIANT}.onnx" "$BASE/${VARIANT}.onnx"
curl -fL -o "$DIR/voices-v1.0.bin" "$BASE/voices-v1.0.bin"

echo "Downloaded ${VARIANT}.onnx + voices-v1.0.bin to $DIR"
if [ "$VARIANT" != "kokoro-v1.0" ]; then
    echo "Set KOKORO_MODEL=$DIR/${VARIANT}.onnx if not using the default."
fi

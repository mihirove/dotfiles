#!/bin/bash
# Download a Piper voice model into ./models/.
# Default voice: en_US-amy-medium. Override via $1 (e.g. en_US-lessac-medium).
set -euo pipefail

VOICE="${1:-en_US-amy-medium}"
DIR="$(cd "$(dirname "$0")" && pwd)/models"
mkdir -p "$DIR"

# Voice path on HF: <lang>/<region>/<name>/<quality>/<voice>.onnx[.json]
LANG="${VOICE%%_*}"           # en
REST="${VOICE#*_}"            # US-amy-medium
REGION="${REST%%-*}"          # US
REST="${REST#*-}"             # amy-medium
NAME="${REST%-*}"             # amy
QUALITY="${REST##*-}"         # medium

BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main/${LANG}/${LANG}_${REGION}/${NAME}/${QUALITY}"

curl -fL -o "$DIR/${VOICE}.onnx"      "$BASE/${VOICE}.onnx"
curl -fL -o "$DIR/${VOICE}.onnx.json" "$BASE/${VOICE}.onnx.json"

echo "Downloaded $VOICE to $DIR"
echo "Set CLAUDE_TTS_PIPER_MODEL=$DIR/${VOICE}.onnx if not using the default."

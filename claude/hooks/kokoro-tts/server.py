"""Kokoro TTS HTTP server (ONNX backend).

Loads a Kokoro ONNX session once at startup and serves /synth requests
sequentially. The Claude Code Stop hook posts each sentence and gets
back a wav path.

Env vars:
    KOKORO_MODEL    path to kokoro-v1.0.onnx (default: ./models/kokoro-v1.0.onnx)
    KOKORO_VOICES   path to voices-v1.0.bin (default: ./models/voices-v1.0.bin)
    KOKORO_LANG     language code: en-us, en-gb, ... (default: en-us)
    KOKORO_VOICE    voice id (default: af_heart)
    KOKORO_SPEED    speech rate multiplier (default: 1.0)
    KOKORO_HOST     bind host (default: 127.0.0.1)
    KOKORO_PORT     bind port (default: 7321)
"""

import os
import tempfile
import threading
from contextlib import asynccontextmanager
from pathlib import Path

import soundfile as sf
import uvicorn
from fastapi import FastAPI, HTTPException
from kokoro_onnx import Kokoro
from pydantic import BaseModel

HERE = Path(__file__).resolve().parent
MODEL = os.environ.get("KOKORO_MODEL", str(HERE / "models" / "kokoro-v1.0.onnx"))
VOICES = os.environ.get("KOKORO_VOICES", str(HERE / "models" / "voices-v1.0.bin"))
LANG = os.environ.get("KOKORO_LANG", "en-us")
VOICE = os.environ.get("KOKORO_VOICE", "af_heart")
SPEED = float(os.environ.get("KOKORO_SPEED", "1.0"))
HOST = os.environ.get("KOKORO_HOST", "127.0.0.1")
PORT = int(os.environ.get("KOKORO_PORT", "7321"))

_state: dict = {"kokoro": None}
_gen_lock = threading.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    if not os.path.exists(MODEL) or not os.path.exists(VOICES):
        raise RuntimeError(
            f"missing model files; run download-model.sh "
            f"(expected {MODEL} and {VOICES})"
        )
    _state["kokoro"] = Kokoro(MODEL, VOICES)
    yield
    _state["kokoro"] = None


app = FastAPI(lifespan=lifespan)


class SynthRequest(BaseModel):
    text: str


@app.get("/health")
def health():
    return {"ready": _state["kokoro"] is not None, "voice": VOICE, "lang": LANG}


@app.post("/synth")
def synth(req: SynthRequest):
    kokoro = _state["kokoro"]
    if kokoro is None:
        raise HTTPException(status_code=503, detail="kokoro not loaded")
    with _gen_lock:
        samples, sample_rate = kokoro.create(
            req.text, voice=VOICE, speed=SPEED, lang=LANG
        )
    if samples is None or len(samples) == 0:
        raise HTTPException(status_code=500, detail="empty audio output")
    fd, path = tempfile.mkstemp(suffix=".wav", prefix="kokoro-")
    os.close(fd)
    sf.write(path, samples, sample_rate)
    return {"wav_path": path}


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning")

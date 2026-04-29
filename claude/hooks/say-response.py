"""Read Claude responses aloud via a pluggable TTS backend.

The active backend is chosen by the CLAUDE_TTS_BACKEND env var
(default: piper). To add or swap a backend:

    1. Write `synth_<name>(sentence: str) -> str` returning a wav path.
    2. Register it in the BACKENDS dict below.
    3. (Optional) Teach tts-server-start.sh / tts-server-stop.sh how to
       manage its server, if it needs one.

Stdlib-only — runnable with plain `python3`, no uv project required.
"""

import concurrent.futures
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

MAX_TEXT_LENGTH = 3000

# ---------------------------------------------------------------------------
# Backends
# ---------------------------------------------------------------------------

PIPER_DIR = os.path.expanduser("~/.claude/hooks/piper-tts")
PIPER_MODEL = os.environ.get(
    "CLAUDE_TTS_PIPER_MODEL",
    os.path.join(PIPER_DIR, "models/en_US-amy-medium.onnx"),
)


def synth_piper(sentence: str) -> str:
    fd, out_path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    subprocess.run(
        [
            "uv", "run", "--directory", PIPER_DIR, "piper",
            "--model", PIPER_MODEL,
            "--output_file", out_path,
        ],
        input=sentence.encode(),
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return out_path


KOKORO_URL = os.environ.get("CLAUDE_TTS_KOKORO_URL", "http://127.0.0.1:7321")
KOKORO_READY_TIMEOUT = float(os.environ.get("CLAUDE_TTS_KOKORO_READY_TIMEOUT", "120"))


def synth_kokoro(sentence: str) -> str:
    body = json.dumps({"text": sentence}).encode()
    req = urllib.request.Request(
        f"{KOKORO_URL}/synth",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    deadline = time.time() + KOKORO_READY_TIMEOUT
    while True:
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read())["wav_path"]
        except urllib.error.URLError:
            if time.time() > deadline:
                raise
            time.sleep(0.5)


BACKENDS = {
    "piper": synth_piper,
    "kokoro": synth_kokoro,
}

# ---------------------------------------------------------------------------
# Text cleaning
# ---------------------------------------------------------------------------


def clean(text):
    lines = text.split("\n")
    cleaned = []
    in_code = False
    in_insight = False
    for line in lines:
        s = line.strip()
        if s.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        if "★ Insight" in s or "★Insight" in s:
            in_insight = True
            continue
        if in_insight:
            if s and all(c == "─" for c in s):
                in_insight = False
            continue
        if s.startswith("$ ") or s.startswith("> "):
            continue
        if line.startswith("    ") and s:
            continue
        if "|" in s:
            continue
        if s.startswith("---") or s.startswith(":--"):
            continue
        s = re.sub(r"^[-*+]\s+", "", s)
        s = re.sub(r"^\d+\.\s+", "", s)
        if s:
            cleaned.append(s)
    text = " ".join(cleaned)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    for ch in ["#", "`", ">"]:
        text = text.replace(ch, "")
    text = re.sub(r"[（(]([^）)]*)[）)]", r"\1", text)
    text = re.sub(r"【[^】]*】", "", text)
    text = re.sub(r"\[[^\]]*\]", "", text)
    text = re.sub(r"https?://\S+", "", text)
    text = " ".join(text.split()).strip()
    if len(text) > MAX_TEXT_LENGTH:
        return text[:MAX_TEXT_LENGTH] + "... truncated"
    return text


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

backend_name = os.environ.get("CLAUDE_TTS_BACKEND", "piper")
synthesize = BACKENDS.get(backend_name)
if synthesize is None:
    sys.exit(f"unknown CLAUDE_TTS_BACKEND: {backend_name}")

data = json.load(sys.stdin)
text = data.get("last_assistant_message", "")
if not text:
    sys.exit(0)

text = clean(text)
if not text:
    sys.exit(0)

# English-only models — strip CJK characters, skip if nothing left.
text = re.sub(r"[　-鿿＀-ﾟ]+", " ", text)
text = " ".join(text.split()).strip()
if not text:
    sys.exit(0)

sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
if not sentences:
    sys.exit(0)

wav_files = []
try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(synthesize, s) for s in sentences]
        player = None
        for future in futures:
            wav_path = future.result()
            wav_files.append(wav_path)
            if player:
                player.wait()
            player = subprocess.Popen(["afplay", wav_path])
        if player:
            player.wait()
finally:
    for path in wav_files:
        try:
            os.unlink(path)
        except OSError:
            pass

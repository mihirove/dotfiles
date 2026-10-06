"""Read Claude responses aloud via a pluggable TTS backend.

The active backend is chosen by the CLAUDE_TTS_BACKEND env var
(default: kokoro). To add or swap a backend:

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
KOKORO_READY_TIMEOUT = float(os.environ.get("CLAUDE_TTS_KOKORO_READY_TIMEOUT", "30"))
KOKORO_PIDFILE = "/tmp/kokoro-tts.pid"


def kokoro_pid_alive() -> bool:
    try:
        with open(KOKORO_PIDFILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def kokoro_wait_ready() -> bool:
    """Block until /health reports ready. Fail fast when no server is running."""
    if not kokoro_pid_alive():
        return False
    deadline = time.time() + KOKORO_READY_TIMEOUT
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{KOKORO_URL}/health", timeout=2) as resp:
                if json.loads(resp.read()).get("ready"):
                    return True
        except urllib.error.URLError:
            if not kokoro_pid_alive():
                return False
        time.sleep(0.5)
    return False


def synth_kokoro(sentence: str) -> str:
    body = json.dumps({"text": sentence}).encode()
    req = urllib.request.Request(
        f"{KOKORO_URL}/synth",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read())["wav_path"]


BACKENDS = {
    "piper": synth_piper,
    "kokoro": synth_kokoro,
}

# `piper` shells out to a fresh CLI per sentence (cold-start cost each time),
# so 4 parallel processes hammer CPU. `kokoro` is a single server with an
# internal lock — concurrent posts just queue, the parallelism overlaps
# network/setup with synth.
BACKEND_WORKERS = {"piper": 1, "kokoro": 4}

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
# Transcript reading
# ---------------------------------------------------------------------------


def other_audio_playing(cpu_threshold: float = 5.0) -> bool:
    """coreaudiod's CPU spikes only while a stream is being mixed, so high
    usage means something else is already playing — skip TTS to avoid talking
    over it."""
    try:
        out = subprocess.check_output(["ps", "-axo", "%cpu=,comm="], text=True)
    except (OSError, subprocess.CalledProcessError):
        return False
    for line in out.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            continue
        cpu_str, comm = parts
        if not comm.endswith("coreaudiod"):
            continue
        try:
            return float(cpu_str) > cpu_threshold
        except ValueError:
            return False
    return False


def wait_for_transcript_settle(path: str, settle_s: float = 0.15, max_wait_s: float = 2.0) -> None:
    """The Stop hook can fire before the just-finished turn is flushed to the
    transcript, which would make us read the previous turn's message. Block
    until two stat() calls in a row see the same size + mtime."""
    deadline = time.time() + max_wait_s
    prev = (-1, -1.0)
    while time.time() < deadline:
        try:
            st = os.stat(path)
            cur = (st.st_size, st.st_mtime)
        except OSError:
            return
        if cur == prev:
            return
        prev = cur
        time.sleep(settle_s)


def last_assistant_message(transcript_path: str) -> str:
    """Read the assistant's most recent textual reply from a JSONL transcript."""
    wait_for_transcript_settle(transcript_path)
    last = ""
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("type") != "assistant":
                    continue
                content = rec.get("message", {}).get("content", [])
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    text = "".join(
                        c.get("text", "")
                        for c in content
                        if isinstance(c, dict) and c.get("type") == "text"
                    )
                else:
                    text = ""
                text = text.strip()
                if text:
                    last = text
    except OSError:
        return ""
    return last


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

backend_name = os.environ.get("CLAUDE_TTS_BACKEND", "kokoro")
synthesize = BACKENDS.get(backend_name)
if synthesize is None:
    sys.exit(f"unknown CLAUDE_TTS_BACKEND: {backend_name}")

data = json.load(sys.stdin)
transcript_path = data.get("transcript_path", "")
if not transcript_path:
    sys.exit(0)

text = last_assistant_message(transcript_path)
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

if other_audio_playing():
    sys.exit(0)

# Fail fast if kokoro server isn't reachable, instead of blocking on every
# sentence's POST until the per-call timeout.
if backend_name == "kokoro" and not kokoro_wait_ready():
    sys.exit(0)

workers = BACKEND_WORKERS.get(backend_name, 2)
wav_files = []
executor = concurrent.futures.ThreadPoolExecutor(max_workers=workers)
futures = [executor.submit(synthesize, s) for s in sentences]
try:
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
    executor.shutdown(wait=True, cancel_futures=True)
    for fut in futures:
        if fut.done() and fut.exception() is None:
            try:
                p = fut.result()
                if p and p not in wav_files:
                    wav_files.append(p)
            except Exception:
                pass
    for path in wav_files:
        try:
            os.unlink(path)
        except OSError:
            pass

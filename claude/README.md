# Claude Code config

Per-user Claude Code config: `CLAUDE.md`, `settings.json`, output styles, skills, statusline, and hooks. Symlinked to `~/.claude/` by `home/programs/claude.nix` (via `mkOutOfStoreSymlink`), so edits in this directory take effect without a `nix run .#switch`.

## TTS hooks

`hooks/` wires two text-to-speech backends into Claude Code so the assistant's responses can be read aloud. Everything is opt-in via the `CLAUDE_VOICE=1` env var and dispatched from `settings.json`.

### Architecture

```text
SessionStart hook  →  tts-server-start.sh  →  prep venv (piper) / launch HTTP server (kokoro)
Stop hook          →  say-response.py      →  clean text → split → synth → afplay
SessionEnd hook    →  tts-server-stop.sh   →  kill the kokoro server, if running
```

`say-response.py` is stdlib-only — it reads the assistant's last message off stdin, strips code blocks / Insight blocks / markdown, splits into sentences, dispatches each one to the active backend, and pipes the resulting wav files to `afplay` in order. The Stop hook is `async: true` so playback never blocks the next prompt.

### Backends

| Backend | Engine | Latency | Quality | Disk | When to pick |
|---|---|---|---|---|---|
| `piper` | piper-tts CLI, ONNX | very fast | decent (robotic-ish) | ~60 MB / voice | low-resource hosts; quick utterances |
| `kokoro` | kokoro-onnx, persistent FastAPI server on `127.0.0.1:7321` | fast (real-time on M-series) | natural, multi-voice | ~340 MB | preferred — much more pleasant voice, server stays warm |

Both live in their own `uv` project (`piper-tts/` and `kokoro-tts/`) so deps don't pollute system Python. Models are downloaded on demand and gitignored.

### Enable it

```bash
# 1. Pick a backend in settings.json (env.CLAUDE_TTS_BACKEND)
#    "piper" or "kokoro"

# 2. Download the voice/model files (one-time)
~/.claude/hooks/piper-tts/download-model.sh        # ~60 MB
~/.claude/hooks/kokoro-tts/download-model.sh       # ~340 MB

# 3. Turn the hook on for a session
CLAUDE_VOICE=1 claude
```

The gate flag means TTS is silent by default for everyone else who clones this repo — no surprises on a fresh `nix run .#switch`.

### Tune voice or speed

| Backend | Voice | Speed | Where |
|---|---|---|---|
| piper | `CLAUDE_TTS_PIPER_MODEL=.../en_US-ryan-medium.onnx` | (model-baked) | `settings.json` env, or shell |
| kokoro | `KOKORO_VOICE=am_michael` (`am_*` male, `af_*` female, `bm_*`/`bf_*` British) | `KOKORO_SPEED=1.15` | `settings.json` env, then restart server |

Kokoro reads its env vars at server start, so changing them needs `tts-server-stop.sh && tts-server-start.sh`.

### Add a new backend

1. Write `synth_<name>(sentence: str) -> str` returning a wav path in `say-response.py` and register it in the `BACKENDS` dict.
2. (Optional) Teach `tts-server-start.sh` / `tts-server-stop.sh` how to manage its server, if it needs one.
3. Set `CLAUDE_TTS_BACKEND=<name>` in `settings.json`.

The HTTP contract for server-style backends (kokoro) is intentionally trivial: `POST /synth {"text": ...} → {"wav_path": ...}`. That's why swapping kokoro's PyTorch engine for ONNX was a server-side patch only.

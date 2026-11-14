#!/bin/bash
# Start a TTS backend server (or one-shot prep) for the selected backend.
BACKEND="${CLAUDE_TTS_BACKEND:-piper}"

# Read session_id from the hook payload (Claude Code pipes JSON on stdin).
SESSION_ID=""
if [ ! -t 0 ]; then
    SESSION_ID="$(jq -r '.session_id // empty' 2>/dev/null || true)"
fi

case "$BACKEND" in
    piper)
        # No daemon — just make sure the venv is ready so the Stop hook
        # doesn't pay the cold-start cost on first invocation.
        UV="$(which uv)"
        DIR="$HOME/.claude/hooks/piper-tts"
        if [ -x "$UV" ] && [ -d "$DIR" ]; then
            "$UV" sync --directory "$DIR" >/dev/null 2>&1 || true
        fi
        ;;
    kokoro)
        UV="$(which uv)"
        DIR="$HOME/.claude/hooks/kokoro-tts"
        PIDFILE="/tmp/kokoro-tts.pid"
        LOCKDIR="/tmp/kokoro-tts.lock.d"
        LOGFILE="/tmp/kokoro-tts.log"
        SESSIONS_DIR="/tmp/kokoro-tts.sessions"
        # Refcount: register this session so SessionEnd can tell when the last
        # parallel Claude Code instance is gone before killing the server.
        if [ -n "$SESSION_ID" ]; then
            mkdir -p "$SESSIONS_DIR"
            : > "$SESSIONS_DIR/$SESSION_ID"
        fi
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            exit 0
        fi
        # `mkdir` is atomic; concurrent SessionStarts won't both spawn a server.
        if ! mkdir "$LOCKDIR" 2>/dev/null; then
            exit 0
        fi
        trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT
        # Re-check: a peer may have started the server, written the PID, and
        # released the lock between the first check and our mkdir.
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            exit 0
        fi
        if [ -x "$UV" ] && [ -d "$DIR" ]; then
            "$UV" sync --directory "$DIR" >/dev/null 2>&1 || true
            nohup "$UV" run --directory "$DIR" python "$DIR/server.py" \
                >"$LOGFILE" 2>&1 &
            echo $! > "$PIDFILE"
        fi
        ;;
    *)
        exit 0
        ;;
esac

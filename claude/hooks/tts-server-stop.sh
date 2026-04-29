#!/bin/bash
# Stop a TTS backend server, if the selected backend runs one.
BACKEND="${CLAUDE_TTS_BACKEND:-piper}"

case "$BACKEND" in
    kokoro)
        PIDFILE="/tmp/kokoro-tts.pid"
        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" 2>/dev/null || true
            rm -f "$PIDFILE"
        fi
        ;;
esac
exit 0

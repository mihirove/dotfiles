#!/bin/bash
# Stop the kokoro TTS server, if running. Backend-agnostic: the PIDFILE is
# the source of truth so a session that swapped CLAUDE_TTS_BACKEND mid-flight
# still cleans up a previously-started server.
PIDFILE="/tmp/kokoro-tts.pid"
LOCKDIR="/tmp/kokoro-tts.lock.d"
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi
rmdir "$LOCKDIR" 2>/dev/null || true
exit 0

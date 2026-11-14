#!/bin/bash
# Drop this session's sentinel and stop the kokoro server only when the last
# parallel Claude Code instance is gone. Backend-agnostic: the PIDFILE +
# sentinel dir are the source of truth so a session that swapped
# CLAUDE_TTS_BACKEND mid-flight still cleans up correctly.
PIDFILE="/tmp/kokoro-tts.pid"
LOCKDIR="/tmp/kokoro-tts.lock.d"
SESSIONS_DIR="/tmp/kokoro-tts.sessions"

SESSION_ID=""
if [ ! -t 0 ]; then
    SESSION_ID="$(jq -r '.session_id // empty' 2>/dev/null || true)"
fi

if [ -n "$SESSION_ID" ]; then
    rm -f "$SESSIONS_DIR/$SESSION_ID"
fi

# GC sentinels left behind by sessions that were force-killed (no SessionEnd).
# 24h is generous — Claude Code sessions don't usually last that long.
if [ -d "$SESSIONS_DIR" ]; then
    find "$SESSIONS_DIR" -type f -mmin +1440 -delete 2>/dev/null || true
fi

# Other sessions still active? Leave the server running.
if [ -d "$SESSIONS_DIR" ] && [ -n "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]; then
    exit 0
fi

if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi
rmdir "$LOCKDIR" 2>/dev/null || true
rmdir "$SESSIONS_DIR" 2>/dev/null || true
exit 0

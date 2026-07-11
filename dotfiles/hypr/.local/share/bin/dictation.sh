#!/usr/bin/env bash
# Toggle speech-to-text dictation (bound to Super+D in hyprland.lua).
#
# This now delegates to VoiceFlow (~/work/walky/voiceflow): local whisper.cpp
# transcription + local LLM cleanup + insertion into the previously focused
# window. First press starts recording; second press stops, transcribes,
# corrects and inserts.
#
# Resolution order:
#   1. `voiceflow` on PATH (installed via home-manager)
#   2. the VoiceFlow repo launcher (works before a NixOS rebuild)
#   3. legacy inline whisper-only dictation (ultimate fallback)
#
# Requires (for the fallback): whisper-cpp, pw-record, wtype, dunst.

VOICEFLOW_REPO="$HOME/work/walky/voiceflow"

if command -v voiceflow >/dev/null 2>&1; then
    exec voiceflow toggle
fi
if [ -x "$VOICEFLOW_REPO/scripts/voiceflow-run.sh" ]; then
    exec "$VOICEFLOW_REPO/scripts/voiceflow-run.sh" toggle
fi

# ---------------------------------------------------------------------------
# Legacy fallback: original whisper-only dictation (English base.en model).
# ---------------------------------------------------------------------------
PIDFILE="/tmp/dictation-recording.pid"
AUDIOFILE="/tmp/dictation-audio.wav"
MODEL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/whisper-models"
MODEL="$MODEL_DIR/ggml-base.en.bin"

if [ ! -f "$MODEL" ]; then
    mkdir -p "$MODEL_DIR"
    notify-send -u normal "Dictation" "Downloading whisper model (base.en)…"
    whisper-cpp-download-ggml-model base.en "$MODEL_DIR" 2>/dev/null
    [ -f "$MODEL" ] || { notify-send -u critical "Dictation" "Model download failed"; exit 1; }
fi

if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    notify-send -u low -t 2000 "Dictation" "Transcribing…"
    RESULT=$(whisper-cli -m "$MODEL" -np -nt -f "$AUDIOFILE" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    rm -f "$AUDIOFILE" 2>/dev/null
    if [ -z "$RESULT" ] || [ "$RESULT" = "[BLANK_AUDIO]" ]; then
        notify-send -u low -t 2000 "Dictation" "No speech detected"; exit 0
    fi
    wtype -- "$RESULT"
else
    pw-record --rate 16000 --channels 1 "$AUDIOFILE" &
    echo $! > "$PIDFILE"
    notify-send -u low -t 2000 "Dictation" "Recording… press again to stop"
fi

#!/usr/bin/env bash
# Toggle speech-to-text dictation
# First call: starts recording. Second call: stops recording, transcribes, types result.
# Requires: whisper-cpp, pw-record, wtype, dunst (notifications)

PIDFILE="/tmp/dictation-recording.pid"
AUDIOFILE="/tmp/dictation-audio.wav"
MODEL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/whisper-models"
MODEL="$MODEL_DIR/ggml-base.en.bin"
LANG="en"  # change to "de" for German, or "auto" for auto-detect

# Download model if missing
if [ ! -f "$MODEL" ]; then
    mkdir -p "$MODEL_DIR"
    notify-send -u normal "Dictation" "Downloading whisper model (base.en)... one-time setup"
    whisper-cpp-download-ggml-model base.en "$MODEL_DIR" 2>/dev/null
    # The download script may name it differently, find it
    if [ ! -f "$MODEL" ]; then
        # Try to find whatever was downloaded
        FOUND=$(find "$MODEL_DIR" -name "ggml-base.en*" -type f 2>/dev/null | head -1)
        if [ -n "$FOUND" ] && [ "$FOUND" != "$MODEL" ]; then
            mv "$FOUND" "$MODEL"
        fi
    fi
    if [ ! -f "$MODEL" ]; then
        notify-send -u critical "Dictation" "Failed to download model. Run manually:\nwhistper-cpp-download-ggml-model base.en $MODEL_DIR"
        exit 1
    fi
    notify-send -u normal "Dictation" "Model downloaded successfully"
fi

if [ -f "$PIDFILE" ]; then
    # Stop recording
    PID=$(cat "$PIDFILE")
    kill "$PID" 2>/dev/null
    rm -f "$PIDFILE"

    notify-send -u low -t 2000 "Dictation" "Transcribing..."

    # Transcribe — whisper-cpp needs 16kHz WAV
    # pw-record already records WAV; convert to 16kHz mono if needed
    WAVFILE="/tmp/dictation-16k.wav"
    if command -v sox &>/dev/null; then
        sox "$AUDIOFILE" -r 16000 -c 1 "$WAVFILE" 2>/dev/null
    elif command -v ffmpeg &>/dev/null; then
        ffmpeg -y -i "$AUDIOFILE" -ar 16000 -ac 1 "$WAVFILE" 2>/dev/null
    else
        # pw-record with --rate should have handled this, use as-is
        WAVFILE="$AUDIOFILE"
    fi

    # Run whisper-cli
    RESULT=$(whisper-cli -m "$MODEL" -np -nt -f "$WAVFILE" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Clean up temp files
    rm -f "$AUDIOFILE" "$WAVFILE" 2>/dev/null

    if [ -z "$RESULT" ] || [ "$RESULT" = "[BLANK_AUDIO]" ]; then
        notify-send -u low -t 2000 "Dictation" "No speech detected"
        exit 0
    fi

    # Type result into focused window
    wtype -- "$RESULT"
    notify-send -u low -t 2000 "Dictation" "Typed: ${RESULT:0:60}..."
else
    # Start recording
    pw-record --rate 16000 --channels 1 "$AUDIOFILE" &
    echo $! > "$PIDFILE"
    notify-send -u low -t 2000 "Dictation" "Recording... press again to stop"
fi

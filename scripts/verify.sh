#!/bin/sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT_DIR/build"
BIN_PATH="$BIN_DIR/verify-tests"

mkdir -p "$BIN_DIR"

swiftc \
  -framework Carbon \
  -o "$BIN_PATH" \
  "$ROOT_DIR/scripts/verify.swift" \
  "$ROOT_DIR/LocalTranscribePaste/Hotkeys/Hotkey.swift" \
  "$ROOT_DIR/LocalTranscribePaste/Transcription/WhisperTranscriptParser.swift"

"$BIN_PATH"

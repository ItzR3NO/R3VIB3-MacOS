# R3VIB3

![R3VIB3 Header](docs/R3VIBEHeader.jpeg)

Local-only macOS menu bar dictation app designed for seamless transcription across your local Mac and remote desktop sessions. Most dictation tools don’t paste reliably into RDP clients — R3VIB3 does.

## Build and run
1. Open `LocalTranscribePaste/LocalTranscribePaste.xcodeproj` in Xcode.
2. Select the `LocalTranscribePaste` target (builds the R3VIB3 app).
3. Build and run (Debug).

The app runs as a menu bar item with the R3VIB3 icon.

## Permissions
On first launch, the app shows a permissions checklist window.

Enable:
- **Microphone**: System Settings > Privacy & Security > Microphone
- **Accessibility**: System Settings > Privacy & Security > Accessibility

If you change permissions, quit and relaunch the app.

## Whisper.cpp binary and model
This project uses the whisper.cpp CLI binary (default engine) and keeps models in Application Support.

### Whisper CLI binary
Replace the placeholder file with the actual whisper.cpp CLI binary:
- Source file path: `LocalTranscribePaste/LocalTranscribePaste/Resources/whisper/whisper-cli`
- Ensure the binary is **executable** (`chmod +x whisper-cli`).
- Build a **universal** binary (Apple Silicon + Intel) and replace the placeholder.

The app looks for the binary inside its bundle as `whisper-cli`.

### Model file
Default model path:
```
~/Library/Application Support/R3VIB3/Models/ggml-base.en.bin
```

Steps:
1. Create the folder if it does not exist.
2. Copy a whisper.cpp model file (`.bin`) into that folder.
3. In the app Settings, pick the model path you want to use.

## Usage
Default hotkeys:
- **Toggle Dictation**: Control + Option + Space
- **Paste Last Transcript**: Control + Option + V

Workflow:
1. Press Toggle Dictation to start recording.
2. Press Toggle Dictation again to stop and transcribe.
3. A popover shows the transcript with actions: Copy, Paste, Clear, Retry.
4. Use Paste Last Transcript hotkey to paste into the active app.

## Launch at login
In Settings, enable **Launch at login** to start R3VIB3 automatically when you sign in.


## Remote desktop notes (Microsoft Remote Desktop)
- Enable clipboard sharing in the RDP client.
- If Cmd+V does not paste into the remote session, switch to **Ctrl+V** in Settings.
- If clipboard paste is blocked, enable **Type** mode (character-by-character typing).

## Logs
The app uses `os_log` for audio start/stop, transcription, paste actions, and permission status.

## Notes
- Transcription runs locally and offline.
- The app never auto-inserts text into other apps.

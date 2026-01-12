# R3VIB3 Derived Contracts

This document captures behavior observed from the codebase. It is meant to lock expectations for refactors.

## Entry Points
- App lifecycle: `LocalTranscribePasteApp` + `AppDelegate.applicationDidFinishLaunching`.
- Hotkeys: Carbon hotkeys (`HotkeyManager`) and event-tap hotkeys (`HoldHotkeyManager`).
- Status bar menu: `StatusBarController` menu items.

## Invariants
- Dictation requires microphone permission; paste actions require accessibility permission.
- Recording indicator state matches `AppState.isRecording` and `activeRecordingMode`.
- Transcription only runs after a successful recording stop.
- `R3VIB3/Models` is preferred over legacy `LocalTranscribePaste/Models` if present.

## Flows
### Toggle dictation (happy path)
1. Toggle hotkey or menu item calls `AppState.toggleDictation()`.
2. Recording starts via `AudioCaptureManager.startRecording()`.
3. On stop, audio is converted to 16k mono, transcribed by whisper-cli.
4. Transcript is stored, optionally copied, and paste-ready indicator shown.

### Toggle dictation (failure path)
- Missing microphone permission: show permissions window, log warning.
- Recording start/stop failure: show error message, leave indicator off.
- Transcription failure: show message derived from `TranscriptionError`.

### Hold-to-record (happy path)
- Event tap detects hold hotkey; `AppState.startHoldRecording()`
- On key release, `stopHoldRecording()` triggers transcription.

## Boundaries
- UI: Status bar, popovers, settings, permissions windows.
- Orchestration: `AppState`.
- Audio capture: `AudioCaptureManager`.
- Transcription: `TranscriptionManager` + `WhisperCLITranscriber`.
- Input/paste: `PasteManager`.
- Permissions: `PermissionsManager`.

## Time + Async Rules
- Transcription runs on a dedicated background queue.
- UI updates dispatched to main thread via `MainThreadRunner`.
- Hotkey event tap runs on CoreGraphics callback thread; actions hop to main.

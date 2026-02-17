# Whisper Dictation 🎙️
![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![License](https://img.shields.io/badge/license-MIT-green)

macOS native voice input tool — lives in the menubar, hold the shortcut to record, release to auto-transcribe, result pasted at cursor.

Based on [whisper.cpp](https://github.com/ggerganov/whisper.cpp), fully local processing, no data sent to the cloud.

## Features

- **Global hotkey** — Hold `Left Ctrl + Left Option` to record, release to auto-transcribe
- **ESC cancel** — Press ESC while recording to cancel
- **Auto paste** — After transcription, simulates `Cmd+V` to paste at cursor
- **Does not steal focus** — App stays in background
- **Menubar App** — No Dock icon

## Environment Requirements

- macOS 13.0+
- Xcode 15.0+
- CMake (`brew install cmake`)

## Installation

The steps below explain how to install and quickly start the app:

1. **Clone** repository (includes whisper.cpp submodule)
   ```bash
   git clone --recursive https://github.com/YOUR_USERNAME/WhisperDictation.git
   cd WhisperDictation
   ```
2. **Setup**: download model and build xcframework
   ```bash
   ./setup.sh
   ```
3. **Run**: open with Xcode and run
   ```bash
   open WhisperDictation.xcodeproj
   ```

## Quick Start

```bash
# 1. Clone (includes whisper.cpp submodule)
git clone --recursive https://github.com/YOUR_USERNAME/WhisperDictation.git
cd WhisperDictation

# 2. One‑click setup (download model + compile xcframework)
./setup.sh

# 3. Open with Xcode and run
open WhisperDictation.xcodeproj
# ⌘R to run
```

Use other models (larger = more accurate, slower):
```bash
./setup.sh small    # or tiny, base, medium, large
```

## First‑time Authorization

The app needs permissions in **System Settings**:

| Permission | Location | Purpose |
|------------|----------|---------|
| **Input Monitoring** | Privacy & Security → Input Monitoring | Listen to global hotkey |
| **Accessibility** | Privacy & Security → Accessibility | Simulate Cmd+V paste |
| **Microphone** | Privacy & Security → Microphone | Record audio |

> ⚠️ After granting, **restart the app** for changes to take effect.

## Usage

| Action | Result |
|--------|--------|
| **Hold Left Ctrl + Left Option** | Start recording |
| **Release any key** | Stop recording → auto‑transcribe → paste |
| **ESC** | Cancel recording |

## Architecture

```
WhisperDictation/
├── WhisperDictationApp.swift   # MenuBarExtra entry
├── AppState.swift              # State management
├── HotkeyManager.swift         # Global hotkey listener
├── AudioRecorder.swift         # 16kHz mono PCM recording
├── WhisperTranscriber.swift    # Load model & transcribe
├── TextInserter.swift          # Simulate Cmd+V paste
├── LibWhisper.swift            # whisper.cpp C API bridge
└── RiffWaveUtils.swift         # WAV decoding
```

## License

MIT

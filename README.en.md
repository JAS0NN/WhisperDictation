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

## Requirements

- macOS 13.0+
- [Xcode](https://developer.apple.com/xcode/) 15.0+ (full Xcode app required, Command Line Tools alone are not sufficient)
- CMake (`brew install cmake`)
- Python 3 (needed for the default BreezeASR25 model)

## Installation

```bash
# 1. Clone (includes whisper.cpp submodule)
git clone --recursive https://github.com/JAS0NN/WhisperDictation.git
cd WhisperDictation

# 2. One-click setup (build xcframework + download model)
./setup.sh

# 3. Open with Xcode and run (Cmd+R)
open WhisperDictation.xcodeproj
```

By default this downloads the [BreezeASR25](https://huggingface.co/MediaTek-Research/Breeze-ASR-25) multilingual model (~3GB). The setup script will automatically install required Python packages (`transformers`, `safetensors`, `huggingface-hub`, `openai-whisper`).

To use an official Whisper model instead (smaller, English-only):
```bash
./setup.sh --official          # defaults to base.en
./setup.sh --official small    # or tiny, base, medium, large
```

## First-time Authorization

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
| **Release any key** | Stop recording → auto-transcribe → paste |
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

# Whisper Dictation 🎙️
![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-orange) ![License](https://img.shields.io/badge/license-MIT-green)

macOS 原生語音輸入工具 — 住在 menubar，按住快捷鍵錄音、放開自動轉寫、結果直接貼到游標所在位置。

基於 [whisper.cpp](https://github.com/ggerganov/whisper.cpp)，完全本地端處理，不傳送任何資料到雲端。

## Features

- **全域快捷鍵** — 按住 `Left Ctrl + Left Option` 錄音，放開自動轉寫
- **ESC 取消** — 錄音途中按 ESC 可取消
- **自動貼上** — 轉寫完成後模擬 `Cmd+V` 貼到游標位置
- **不搶前景** — App 不會跳到前面打斷你的工作
- **Menubar App** — 不佔 Dock 位置
- **CoreML 加速** — 可選啟用 Apple Neural Engine，加速推理

## 環境需求

- macOS 14.0+, Apple Silicon (arm64)
- Xcode Command Line Tools（`xcode-select --install`）
- CMake（`brew install cmake`）
- Python 3（模型轉換需要）

> 不需要完整 Xcode app。`setup.sh` 會自動使用 CMake (Command Line Tools) 來編譯 macOS 專用的 framework。

## 快速安裝

```bash
# 1. Clone（含 whisper.cpp submodule）
git clone --recursive https://github.com/JAS0NN/WhisperDictation.git
cd WhisperDictation

# 2. 一鍵 setup（編譯 framework + 下載模型）
./setup.sh

# 3. Build & 運行
./build.sh
open build/WhisperDictation.app
```

如果你有完整 Xcode app，也可以用 Xcode 打開：
```bash
open WhisperDictation.xcodeproj   # ⌘R
```

### 模型選項

預設下載 [BreezeASR25](https://huggingface.co/MediaTek-Research/Breeze-ASR-25) 多語言模型（~3GB），setup 過程會自動安裝所需 Python 套件。

使用官方 Whisper 模型（較小、僅英文）：
```bash
./setup.sh --official          # 預設 base.en
./setup.sh --official small    # 或 tiny, base, medium, large
```

### CoreML 加速（可選）

啟用 Apple Neural Engine 加速 encoder 推理：
```bash
./setup.sh --coreml
```

這會將模型額外轉換成 CoreML 格式（~1.2GB）。whisper.cpp 會自動偵測並使用，不需要改任何程式碼。需要額外 Python 套件（torch, coremltools），建議先建虛擬環境：
```bash
python3 -m venv .venv
source .venv/bin/activate
./setup.sh --coreml
```

## 首次運行授權

首次運行需要在 **System Settings** 中授權：

| 權限 | 位置 | 用途 |
|------|------|------|
| **Input Monitoring** | Privacy & Security → Input Monitoring | 監聽全域快捷鍵 |
| **Accessibility** | Privacy & Security → Accessibility | 模擬 Cmd+V 貼上 |
| **Microphone** | Privacy & Security → Microphone | 錄音 |

> 授權後需要**重啟 App** 才生效。

## 使用方式

| 操作 | 動作 |
|------|------|
| **按住 Left Ctrl + Left Option** | 開始錄音 |
| **放開任一鍵** | 停止錄音 → 自動轉寫 → 貼上 |
| **ESC** | 取消錄音 |

## 架構

```
WhisperDictation/
├── WhisperDictationApp.swift   # MenuBarExtra 入口
├── AppState.swift              # 狀態管理
├── HotkeyManager.swift         # NSEvent 全域快捷鍵監聽
├── AudioRecorder.swift         # 16kHz mono PCM 錄音
├── WhisperTranscriber.swift    # Whisper 模型載入與轉寫
├── TextInserter.swift          # 模擬 Cmd+V 貼上
├── LibWhisper.swift            # whisper.cpp C API bridge
└── RiffWaveUtils.swift         # WAV 解碼
```

## Build 腳本

| 腳本 | 用途 |
|------|------|
| `setup.sh` | 編譯 whisper framework + 下載模型（首次使用） |
| `setup.sh --coreml` | 同上 + 轉換 CoreML 模型 |
| `build.sh` | 用 swiftc 編譯 .app（不需要 Xcode） |

## License

MIT

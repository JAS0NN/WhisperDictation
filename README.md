# Whisper Dictation 🎙️
![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![License](https://img.shields.io/badge/license-MIT-green)

macOS 原生語音輸入工具 — 住在 menubar，按住快捷鍵錄音、放開自動轉寫、結果直接貼到游標所在位置。

基於 [whisper.cpp](https://github.com/ggerganov/whisper.cpp)，完全本地端處理，不傳送任何資料到雲端。

## Features

- **全域快捷鍵** — 按住 `Left Ctrl + Left Option` 錄音，放開自動轉寫
- **ESC 取消** — 錄音途中按 ESC 可取消
- **自動貼上** — 轉寫完成後模擬 `Cmd+V` 貼到游標位置
- **不搶前景** — App 不會跳到前面打斷你的工作
- **Menubar App** — 不佔 Dock 位置

## 環境需求

- macOS 13.0+
- [Xcode](https://developer.apple.com/xcode/) 15.0+（需要完整 Xcode app，不能只有 Command Line Tools）
- CMake (`brew install cmake`)
- Python 3（預設 BreezeASR25 模型需要）

## 安裝

```bash
# 1. Clone（含 whisper.cpp submodule）
git clone --recursive https://github.com/JAS0NN/WhisperDictation.git
cd WhisperDictation

# 2. 一鍵 setup（編譯 xcframework + 下載模型）
./setup.sh

# 3. 用 Xcode 打開並運行（⌘R）
open WhisperDictation.xcodeproj
```

預設會下載 [BreezeASR25](https://huggingface.co/MediaTek-Research/Breeze-ASR-25) 多語言模型（~3GB），setup 過程會自動安裝所需 Python 套件（`transformers`、`safetensors`、`huggingface-hub`、`openai-whisper`）。

使用官方 Whisper 模型（較小、僅英文）：
```bash
./setup.sh --official          # 預設 base.en
./setup.sh --official small    # 或 tiny, base, medium, large
```

## 首次運行授權

首次運行需要在 **System Settings** 中授權：

| 權限 | 位置 | 用途 |
|------|------|------|
| **Input Monitoring** | Privacy & Security → Input Monitoring | 監聽全域快捷鍵 |
| **Accessibility** | Privacy & Security → Accessibility | 模擬 Cmd+V 貼上 |
| **Microphone** | Privacy & Security → Microphone | 錄音 |

> ⚠️ 授權後需要**重啟 App** 才生效。

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

## License

MIT

# Whisper Dictation 🎙️

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
- Xcode 15.0+
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) （用來編譯 xcframework）

## Setup

### 1. Clone whisper.cpp 並下載模型

```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
bash models/download-ggml-model.sh base.en
```

### 2. 執行 setup script

```bash
cd /path/to/WhisperDictation
chmod +x setup.sh
./setup.sh /path/to/whisper.cpp
```

這會自動：
- 編譯 `whisper.xcframework`
- 複製 xcframework 和模型檔到專案中

### 3. Build & Run

1. 開啟 `WhisperDictation.xcodeproj`
2. `⌘R` 運行

### 4. 授權

首次運行需要在 **System Settings** 中授權：
- **Privacy & Security → Input Monitoring** ✅
- **Privacy & Security → Accessibility** ✅

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

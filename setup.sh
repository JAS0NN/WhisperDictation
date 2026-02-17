#!/bin/bash
# Setup WhisperDictation: build xcframework + download & convert BreezeASR25 model
# Usage:
#   ./setup.sh              # Default: download & convert BreezeASR25
#   ./setup.sh --official   # Use official whisper model instead (e.g. base.en)
#   ./setup.sh --official small  # Use a specific official model

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_CPP_DIR="$SCRIPT_DIR/whisper.cpp"
MODELS_OUT="$SCRIPT_DIR/WhisperDictation/Resources/models"

# ─── Check submodule ───
if [ ! -f "$WHISPER_CPP_DIR/CMakeLists.txt" ]; then
    echo "❌ whisper.cpp submodule not initialized. Run:"
    echo "   git submodule update --init --recursive"
    exit 1
fi

# ─── Build xcframework ───
echo "📦 Building whisper.xcframework..."
cd "$WHISPER_CPP_DIR"
./build-xcframework.sh

echo ""
echo "📋 Copying xcframework..."
cp -R "$WHISPER_CPP_DIR/build-apple/whisper.xcframework" "$SCRIPT_DIR/whisper.xcframework"

mkdir -p "$MODELS_OUT"

# ─── Model setup ───
if [ "$1" = "--official" ]; then
    # Official whisper model path
    MODEL="${2:-base.en}"
    echo ""
    echo "📥 Downloading official model: ggml-$MODEL..."
    bash models/download-ggml-model.sh "$MODEL"
    cp "$WHISPER_CPP_DIR/models/ggml-$MODEL.bin" "$MODELS_OUT/"
    echo "✅ Model copied: ggml-$MODEL.bin"
    echo ""
    echo "⚠️  Remember to update AppState.swift forResource to: \"ggml-$MODEL\""
else
    # BreezeASR25 (default)
    echo ""
    echo "📥 Downloading BreezeASR25 from HuggingFace..."

    # Check dependencies
    if ! python3 -c "import transformers, safetensors" 2>/dev/null; then
        echo "📦 Installing Python dependencies..."
        pip3 install transformers 'safetensors[torch]'
    fi
    if ! command -v huggingface-cli &>/dev/null && ! command -v hf &>/dev/null; then
        echo "📦 Installing huggingface-hub..."
        pip3 install huggingface-hub
    fi

    BREEZE_DIR="$SCRIPT_DIR/.breeze-asr25-tmp"
    mkdir -p "$BREEZE_DIR"

    # Download HF config files + model
    echo "⬇️  Downloading model files (≈3GB)..."
    if command -v hf &>/dev/null; then
        HF_CMD="hf"
    else
        HF_CMD="huggingface-cli"
    fi
    $HF_CMD download MediaTek-Research/Breeze-ASR-25 \
        --include "*.safetensors" "config.json" "vocab.json" "added_tokens.json" \
                  "tokenizer.json" "preprocessor_config.json" "special_tokens_map.json" \
                  "merges.txt" "normalizer.json" "generation_config.json" "tokenizer_config.json" \
        --exclude "optimizer.bin" "whisper-github/*" \
        --local-dir "$BREEZE_DIR"

    # Convert to GGML
    echo ""
    echo "🔄 Converting safetensors → GGML format..."

    # Need openai-whisper for mel_filters.npz
    if ! python3 -c "import whisper" 2>/dev/null; then
        pip3 install openai-whisper
    fi

    WHISPER_PKG_DIR=$(python3 -c "import whisper, os; print(os.path.dirname(os.path.dirname(whisper.__file__)))")
    python3 "$WHISPER_CPP_DIR/models/convert-h5-to-ggml.py" "$BREEZE_DIR" "$WHISPER_PKG_DIR" "$MODELS_OUT"

    # Rename to descriptive name
    mv "$MODELS_OUT/ggml-model.bin" "$MODELS_OUT/ggml-breeze-asr25.bin"

    # Cleanup
    echo "🧹 Cleaning up temp files..."
    rm -rf "$BREEZE_DIR"

    echo "✅ Model ready: ggml-breeze-asr25.bin"
fi

echo ""
echo "✅ Setup complete! Open WhisperDictation.xcodeproj in Xcode and press ⌘R"

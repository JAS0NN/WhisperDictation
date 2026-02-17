#!/bin/bash
# Setup WhisperDictation: build xcframework + download & convert model
#
# Usage:
#   ./setup.sh                  # Default: BreezeASR25 model
#   ./setup.sh --official       # Use official whisper model (e.g. base.en)
#   ./setup.sh --official small # Use a specific official model
#   ./setup.sh --coreml         # Also convert CoreML model for Neural Engine acceleration

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_CPP_DIR="$SCRIPT_DIR/whisper.cpp"
MODELS_OUT="$SCRIPT_DIR/WhisperDictation/Resources/models"

# Parse flags
USE_COREML=false
USE_OFFICIAL=false
OFFICIAL_MODEL=""
for arg in "$@"; do
    case "$arg" in
        --coreml) USE_COREML=true ;;
        --official) USE_OFFICIAL=true ;;
        *)
            if $USE_OFFICIAL && [ -z "$OFFICIAL_MODEL" ]; then
                OFFICIAL_MODEL="$arg"
            fi
            ;;
    esac
done

# ─── Check submodule ───

if [ ! -f "$WHISPER_CPP_DIR/CMakeLists.txt" ]; then
    echo "❌ whisper.cpp submodule not initialized. Run:"
    echo "   git submodule update --init --recursive"
    exit 1
fi

# ─── Build whisper framework (macOS arm64 only) ───

cd "$WHISPER_CPP_DIR"

echo "📦 Building whisper.framework for macOS arm64..."

BUILD_DIR="build-macos"

cmake -B "$BUILD_DIR" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_BLAS_DEFAULT=ON \
    -DGGML_METAL_USE_BF16=ON \
    -DGGML_OPENMP=OFF \
    -DWHISPER_COREML=ON \
    -DWHISPER_COREML_ALLOW_FALLBACK=ON \
    -S .

cmake --build "$BUILD_DIR" --config Release -j"$(sysctl -n hw.ncpu)"

echo ""
echo "📋 Assembling whisper.framework..."

FRAMEWORK_DIR="$SCRIPT_DIR/whisper.xcframework/macos-arm64/whisper.framework"
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Versions/A/Headers"
mkdir -p "$FRAMEWORK_DIR/Versions/A/Modules"
mkdir -p "$FRAMEWORK_DIR/Versions/A/Resources"

# Combine static libraries
COREML_LIB="$BUILD_DIR/src/libwhisper.coreml.a"
LIBS=(
    "$BUILD_DIR/src/libwhisper.a"
    "$BUILD_DIR/ggml/src/libggml.a"
    "$BUILD_DIR/ggml/src/libggml-base.a"
    "$BUILD_DIR/ggml/src/libggml-cpu.a"
    "$BUILD_DIR/ggml/src/ggml-metal/libggml-metal.a"
    "$BUILD_DIR/ggml/src/ggml-blas/libggml-blas.a"
)
if [ -f "$COREML_LIB" ]; then
    LIBS+=("$COREML_LIB")
fi
libtool -static -o "$BUILD_DIR/combined.a" "${LIBS[@]}" 2>/dev/null

# Create dynamic library
LINK_FRAMEWORKS="-framework Foundation -framework Metal -framework Accelerate"
if [ -f "$COREML_LIB" ]; then
    LINK_FRAMEWORKS="$LINK_FRAMEWORKS -framework CoreML"
fi

xcrun clang++ -dynamiclib \
    -isysroot "$(xcrun --show-sdk-path)" \
    -arch arm64 \
    -mmacosx-version-min=14.0 \
    -Wl,-force_load,"$BUILD_DIR/combined.a" \
    $LINK_FRAMEWORKS \
    -lstdc++ \
    -install_name "@rpath/whisper.framework/Versions/Current/whisper" \
    -o "$FRAMEWORK_DIR/Versions/A/whisper"

# Copy headers
cp include/whisper.h "$FRAMEWORK_DIR/Versions/A/Headers/"
cp ggml/include/ggml.h ggml/include/ggml-alloc.h ggml/include/ggml-backend.h \
   ggml/include/gguf.h "$FRAMEWORK_DIR/Versions/A/Headers/"
cp ggml/include/ggml-metal.h ggml/include/ggml-cpu.h \
   ggml/include/ggml-blas.h "$FRAMEWORK_DIR/Versions/A/Headers/"

# Create module map
cat > "$FRAMEWORK_DIR/Versions/A/Modules/module.modulemap" << 'MODULEMAP'
framework module whisper {
    header "whisper.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "ggml-blas.h"
    header "gguf.h"

    link "c++"
    link framework "Accelerate"
    link framework "Metal"
    link framework "Foundation"

    export *
}
MODULEMAP

# Create Info.plist
cat > "$FRAMEWORK_DIR/Versions/A/Resources/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>ggml.whisper</string>
    <key>CFBundleName</key>
    <string>whisper</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
PLIST

# Create versioned symlinks
cd "$FRAMEWORK_DIR"
ln -sf A Versions/Current
ln -sf Versions/Current/Headers Headers
ln -sf Versions/Current/Modules Modules
ln -sf Versions/Current/Resources Resources
ln -sf Versions/Current/whisper whisper
cd "$WHISPER_CPP_DIR"

echo "✅ whisper.framework built at: $FRAMEWORK_DIR"

# ─── Model setup ───

mkdir -p "$MODELS_OUT"

if $USE_OFFICIAL; then
    # Official whisper model path
    MODEL="${OFFICIAL_MODEL:-base.en}"
    echo ""
    echo "📥 Downloading official model: ggml-$MODEL..."
    bash models/download-ggml-model.sh "$MODEL"
    cp "$WHISPER_CPP_DIR/models/ggml-$MODEL.bin" "$MODELS_OUT/"
    echo "✅ Model copied: ggml-$MODEL.bin"
    echo ""
    echo "⚠️  Remember to update AppState.swift forResource to: \"ggml-$MODEL\""
else
    # BreezeASR25 (default)
    if [ -f "$MODELS_OUT/ggml-breeze-asr25.bin" ]; then
        echo ""
        echo "✅ Model already exists: ggml-breeze-asr25.bin (skipping download)"
    else
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
fi

# ─── CoreML model conversion (optional) ───

if $USE_COREML; then
    COREML_OUT="$MODELS_OUT/ggml-breeze-asr25-encoder.mlmodelc"

    if [ -d "$COREML_OUT" ]; then
        echo ""
        echo "✅ CoreML model already exists (skipping conversion)"
    else
        echo ""
        echo "🧠 Converting model to CoreML format (Neural Engine acceleration)..."
        echo "   This requires ~10GB RAM and a few minutes."

        # Install Python deps for CoreML conversion
        PYTHON3="python3"
        if [ -d "$SCRIPT_DIR/.venv" ]; then
            PYTHON3="$SCRIPT_DIR/.venv/bin/python3"
        fi

        # Check/install deps
        if ! $PYTHON3 -c "import coremltools, torch, transformers" 2>/dev/null; then
            echo "📦 Installing CoreML conversion dependencies..."
            echo "   (torch, coremltools, transformers, openai-whisper)"
            $PYTHON3 -m pip install 'torch>=2.1' coremltools openai-whisper transformers ane_transformers 'numpy<2'
        fi

        # Convert HuggingFace model → CoreML .mlpackage
        cd "$WHISPER_CPP_DIR"
        $PYTHON3 models/convert-h5-to-coreml.py \
            --model-name large-v2 \
            --model-path MediaTek-Research/Breeze-ASR-25 \
            --encoder-only True

        # Compile .mlpackage → .mlmodelc
        echo "🔧 Compiling CoreML model..."
        if command -v xcrun && xcrun --find coremlc &>/dev/null; then
            # Full Xcode — use coremlc
            xcrun coremlc compile models/coreml-encoder-large-v2.mlpackage models/
            rm -rf "$COREML_OUT"
            mv models/coreml-encoder-large-v2.mlmodelc "$COREML_OUT"
        else
            # Command Line Tools only — use coremltools Python
            $PYTHON3 -c "
import coremltools as ct, shutil, os
model = ct.models.MLModel('models/coreml-encoder-large-v2.mlpackage')
compiled = model.get_compiled_model_path()
dest = '$COREML_OUT'
if os.path.exists(dest): shutil.rmtree(dest)
shutil.copytree(compiled, dest)
print(f'Compiled to: {dest}')
"
        fi

        # Cleanup intermediate files
        rm -rf models/coreml-encoder-large-v2.mlpackage models/hf-large-v2.pt

        echo "✅ CoreML model ready: ggml-breeze-asr25-encoder.mlmodelc"
    fi
fi

# ─── Done ───

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ Setup complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  Option A — Xcode:"
echo "    open WhisperDictation.xcodeproj   # then ⌘R"
echo ""
echo "  Option B — Command line:"
echo "    ./build.sh"
echo "    open build/WhisperDictation.app"
echo ""
if ! $USE_COREML; then
    echo "  💡 Want Neural Engine acceleration? Re-run with:"
    echo "    ./setup.sh --coreml"
    echo ""
fi

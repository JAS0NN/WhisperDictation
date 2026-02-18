#!/bin/bash
# Setup WhisperDictation: build xcframework + download & convert model
#
# Usage:
#   ./setup.sh                  # Default: BreezeASR25 model
#   ./setup.sh --official       # Use official whisper model (e.g. base.en)
#   ./setup.sh --coreml         # Also convert CoreML model for Neural Engine acceleration

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_CPP_DIR="$SCRIPT_DIR/whisper.cpp"
MODELS_OUT="$SCRIPT_DIR/WhisperDictation/Resources/models"

# ─── Python Environment (uv) ───

# Ensure uv is installed
if ! command -v uv &>/dev/null; then
    echo "📦 Installing uv..."
    pip3 install uv || { echo "❌ Failed to install uv via pip3. Please install it manually."; exit 1; }
fi

# Create venv if needed
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "🐍 Creating virtual environment with uv..."
    uv venv "$SCRIPT_DIR/.venv"
fi

EXT_PYTHON="$SCRIPT_DIR/.venv/bin/python3"
# Helper to install python deps inside venv
uv_install() {
    uv pip install -p "$EXT_PYTHON" "$@"
}

# ─── Parse flags ───
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

CMAKE_COREML_FLAG="OFF"
if $USE_COREML; then
    CMAKE_COREML_FLAG="ON"
fi

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
    -DWHISPER_COREML=$CMAKE_COREML_FLAG \
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
COREML_LIB=""
if [ -f "$BUILD_DIR/src/Release/libwhisper.coreml.a" ]; then
    COREML_LIB="$BUILD_DIR/src/Release/libwhisper.coreml.a"
elif [ -f "$BUILD_DIR/src/libwhisper.coreml.a" ]; then
    COREML_LIB="$BUILD_DIR/src/libwhisper.coreml.a"
fi

# Helper to find lib (supports CMake Xcode generator output)
find_lib() {
    local name=$1
    if [ -f "$BUILD_DIR/$name" ]; then echo "$BUILD_DIR/$name"; return 0; fi
    local dir=$(dirname "$name")
    local base=$(basename "$name")
    if [ -f "$BUILD_DIR/$dir/Release/$base" ]; then echo "$BUILD_DIR/$dir/Release/$base"; return 0; fi
    return 1
}

LIBS=()
for lib in \
    "src/libwhisper.a" \
    "ggml/src/libggml.a" \
    "ggml/src/libggml-base.a" \
    "ggml/src/libggml-cpu.a" \
    "ggml/src/ggml-metal/libggml-metal.a" \
    "ggml/src/ggml-blas/libggml-blas.a"
do
    FOUND=$(find_lib "$lib")
    if [ -n "$FOUND" ]; then
        LIBS+=("$FOUND")
    else
        echo "⚠️  Warning: Library not found: $lib"
    fi
done

if [ -n "$COREML_LIB" ]; then
    LIBS+=("$COREML_LIB")
fi

libtool -static -o "$BUILD_DIR/combined.a" "${LIBS[@]}" 2>/dev/null

# Create dynamic library
LINK_FRAMEWORKS="-framework Foundation -framework Metal -framework Accelerate"
if [ -n "$COREML_LIB" ]; then
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
    MODEL="${OFFICIAL_MODEL:-base.en}"
    echo ""
    echo "📥 Downloading official model: ggml-$MODEL..."
    bash models/download-ggml-model.sh "$MODEL"
    cp "$WHISPER_CPP_DIR/models/ggml-$MODEL.bin" "$MODELS_OUT/"
    echo "✅ Model copied: ggml-$MODEL.bin"
else
    # BreezeASR25
    if [ -f "$MODELS_OUT/ggml-breeze-asr25.bin" ]; then
        echo ""
        echo "✅ Model already exists: ggml-breeze-asr25.bin (skipping download)"
    else
        echo ""
        echo "📥 Downloading BreezeASR25 from HuggingFace..."

        # Install deps via uv
        if ! "$EXT_PYTHON" -c "import transformers, safetensors, huggingface_hub" 2>/dev/null; then
            echo "📦 Installing Python dependencies with uv..."
            uv_install transformers 'safetensors[torch]' huggingface_hub
        fi
        
        BREEZE_DIR="$SCRIPT_DIR/.breeze-asr25-tmp"
        mkdir -p "$BREEZE_DIR"

        echo "⬇️  Downloading model files (≈3GB)..."
        # Use venv huggingface-cli
        HF_CMD="$SCRIPT_DIR/.venv/bin/huggingface-cli"
        
        $HF_CMD download MediaTek-Research/Breeze-ASR-25 \
            --include "*.safetensors" "config.json" "vocab.json" "added_tokens.json" \
                      "tokenizer.json" "preprocessor_config.json" "special_tokens_map.json" \
                      "merges.txt" "normalizer.json" "generation_config.json" "tokenizer_config.json" \
            --exclude "optimizer.bin" "whisper-github/*" \
            --local-dir "$BREEZE_DIR"

        echo ""
        echo "🔄 Converting safetensors → GGML format..."

        if ! "$EXT_PYTHON" -c "import whisper" 2>/dev/null; then
            uv_install openai-whisper
        fi

        WHISPER_PKG_DIR=$("$EXT_PYTHON" -c "import whisper, os; print(os.path.dirname(os.path.dirname(whisper.__file__)))")
        "$EXT_PYTHON" "$WHISPER_CPP_DIR/models/convert-h5-to-ggml.py" "$BREEZE_DIR" "$WHISPER_PKG_DIR" "$MODELS_OUT"

        mv "$MODELS_OUT/ggml-model.bin" "$MODELS_OUT/ggml-breeze-asr25.bin"
        
        echo "🧹 Cleaning up temp files..."
        rm -rf "$BREEZE_DIR"
        echo "✅ Model ready: ggml-breeze-asr25.bin"
    fi
fi

# ─── CoreML conversion ───

if $USE_COREML; then
    COREML_OUT="$MODELS_OUT/ggml-breeze-asr25-encoder.mlmodelc"

    if [ -d "$COREML_OUT" ]; then
        echo ""
        echo "✅ CoreML model already exists (skipping conversion)"
    else
        echo ""
        echo "🧠 Converting model to CoreML format (Neural Engine acceleration)..."
        echo "   This requires ~10GB RAM and a few minutes."

        # Install deps
        if ! "$EXT_PYTHON" -c "import coremltools, torch, transformers, ane_transformers" 2>/dev/null; then
            echo "📦 Installing CoreML conversion dependencies with uv..."
            uv_install 'torch>=2.1' coremltools openai-whisper transformers ane_transformers 'numpy<2'
        fi

        # Convert
        cd "$WHISPER_CPP_DIR"
        "$EXT_PYTHON" models/convert-h5-to-coreml.py \
            --model-name large-v2 \
            --model-path MediaTek-Research/Breeze-ASR-25 \
            --encoder-only True

        # Compile
        echo "🔧 Compiling CoreML model..."
        if command -v xcrun && xcrun --find coremlc &>/dev/null; then
            xcrun coremlc compile models/coreml-encoder-large-v2.mlpackage models/
            rm -rf "$COREML_OUT"
            mv models/coreml-encoder-large-v2.mlmodelc "$COREML_OUT"
        else
            # Fallback using python coremltools
             "$EXT_PYTHON" -c "
import coremltools as ct, shutil, os
model = ct.models.MLModel('models/coreml-encoder-large-v2.mlpackage')
compiled = model.get_compiled_model_path()
dest = '$COREML_OUT'
if os.path.exists(dest): shutil.rmtree(dest)
shutil.copytree(compiled, dest)
print(f'Compiled to: {dest}')
"
        fi

        rm -rf models/coreml-encoder-large-v2.mlpackage models/hf-large-v2.pt
        echo "✅ CoreML model ready: ggml-breeze-asr25-encoder.mlmodelc"
    fi
fi

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

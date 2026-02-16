#!/bin/bash
# Build whisper.xcframework from the bundled whisper.cpp submodule
# Usage: ./setup.sh [model_name]
#   model_name: optional, default "base.en" (other options: tiny, base, small, medium, large)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHISPER_CPP_DIR="$SCRIPT_DIR/whisper.cpp"
MODEL="${1:-base.en}"

if [ ! -f "$WHISPER_CPP_DIR/CMakeLists.txt" ]; then
    echo "❌ whisper.cpp submodule not initialized. Run:"
    echo "   git submodule update --init --recursive"
    exit 1
fi

echo "📥 Downloading model: ggml-$MODEL..."
cd "$WHISPER_CPP_DIR"
bash models/download-ggml-model.sh "$MODEL"

echo ""
echo "📦 Building whisper.xcframework..."
./build-xcframework.sh

echo ""
echo "📋 Copying xcframework..."
cp -R "$WHISPER_CPP_DIR/build-apple/whisper.xcframework" "$SCRIPT_DIR/whisper.xcframework"

echo "📋 Copying model..."
mkdir -p "$SCRIPT_DIR/WhisperDictation/Resources/models"
cp "$WHISPER_CPP_DIR/models/ggml-$MODEL.bin" "$SCRIPT_DIR/WhisperDictation/Resources/models/"

echo ""
echo "✅ Setup complete!"
echo "   Open WhisperDictation.xcodeproj in Xcode and press ⌘R"

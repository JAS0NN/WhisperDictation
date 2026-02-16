#!/bin/bash
# Build whisper.xcframework from whisper.cpp and copy to this project
# Usage: ./setup.sh /path/to/whisper.cpp

set -e

WHISPER_CPP_DIR="${1:?Usage: ./setup.sh /path/to/whisper.cpp}"

echo "📦 Building whisper.xcframework..."
cd "$WHISPER_CPP_DIR"
./build-xcframework.sh

echo "📋 Copying xcframework..."
cp -R "$WHISPER_CPP_DIR/build-apple/whisper.xcframework" "$(dirname "$0")/whisper.xcframework"

echo "📥 Copying default model (ggml-base.en)..."
if [ -f "$WHISPER_CPP_DIR/models/ggml-base.en.bin" ]; then
    cp "$WHISPER_CPP_DIR/models/ggml-base.en.bin" "$(dirname "$0")/WhisperDictation/Resources/models/"
    echo "✅ Model copied"
else
    echo "⚠️  Model not found. Download it with:"
    echo "   cd $WHISPER_CPP_DIR && bash models/download-ggml-model.sh base.en"
fi

echo ""
echo "✅ Setup complete! Open WhisperDictation.xcodeproj in Xcode and press ⌘R"

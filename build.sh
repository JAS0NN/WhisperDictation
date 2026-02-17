#!/bin/bash
# Build WhisperDictation.app from the command line using swiftc
# No full Xcode app required — just Command Line Tools.
#
# Usage:
#   ./build.sh
#   open build/WhisperDictation.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/WhisperDictation.app"
CONTENTS="$APP_DIR/Contents"

SWIFT_SOURCES="$SCRIPT_DIR/WhisperDictation"
FRAMEWORK_SRC="$SCRIPT_DIR/whisper.xcframework/macos-arm64/whisper.framework"
ENTITLEMENTS="$SWIFT_SOURCES/WhisperDictation.entitlements"
INFO_PLIST="$SWIFT_SOURCES/Info.plist"
MODEL_FILE="$SWIFT_SOURCES/Resources/models/ggml-breeze-asr25.bin"
COREML_MODEL="$SWIFT_SOURCES/Resources/models/ggml-breeze-asr25-encoder.mlmodelc"

# ─── Prerequisites ───

echo "==> Checking prerequisites..."

if ! command -v swiftc &>/dev/null; then
    echo "Error: swiftc not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

if [ ! -d "$FRAMEWORK_SRC" ]; then
    echo "Error: whisper.framework not found at:"
    echo "  $FRAMEWORK_SRC"
    echo "Run ./setup.sh first to build the xcframework."
    exit 1
fi

if [ ! -f "$MODEL_FILE" ]; then
    echo "Error: Model not found at:"
    echo "  $MODEL_FILE"
    echo "Run ./setup.sh first to download and convert the model."
    exit 1
fi

# ─── Create app bundle structure ───

echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Frameworks"
mkdir -p "$CONTENTS/Resources/models"

# ─── Info.plist ───

# Copy the project's Info.plist and add keys required for a standalone .app bundle
cp "$INFO_PLIST" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.whisper.WhisperDictation" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string WhisperDictation" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string WhisperDictation" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS/Info.plist" 2>/dev/null || true

# ─── Embed whisper.framework ───

echo "==> Copying whisper.framework..."
cp -a "$FRAMEWORK_SRC" "$CONTENTS/Frameworks/"

# ─── Symlink model (saves ~3 GB of disk) ───

echo "==> Symlinking model..."
ln -sf "$MODEL_FILE" "$CONTENTS/Resources/models/ggml-breeze-asr25.bin"

# ─── Symlink CoreML model (optional, enables Neural Engine acceleration) ───

if [ -d "$COREML_MODEL" ]; then
    echo "==> Symlinking CoreML encoder model..."
    ln -sf "$COREML_MODEL" "$CONTENTS/Resources/models/ggml-breeze-asr25-encoder.mlmodelc"
else
    echo "==> CoreML model not found, skipping (GPU/CPU will be used instead)"
fi

# ─── Compile ───

echo "==> Compiling Swift sources..."
xcrun swiftc \
    -o "$CONTENTS/MacOS/WhisperDictation" \
    -parse-as-library \
    -F "$SCRIPT_DIR/whisper.xcframework/macos-arm64" \
    -framework whisper \
    -framework Cocoa \
    -framework AVFoundation \
    -framework SwiftUI \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -target arm64-apple-macosx14.0 \
    -O \
    "$SWIFT_SOURCES"/*.swift

# ─── Code sign ───

echo "==> Code signing..."
codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --deep \
    "$APP_DIR"

# ─── Done ───

echo ""
echo "==> Build complete: $APP_DIR"
echo ""
echo "To launch:"
echo "  open $APP_DIR"
echo "  # or: $CONTENTS/MacOS/WhisperDictation"
echo ""
echo "First launch — grant these permissions in System Settings > Privacy & Security:"
echo "  - Microphone (for recording)"
echo "  - Accessibility (for hotkeys and text insertion)"

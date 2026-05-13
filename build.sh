#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Tele Prompter"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME (Release, ad-hoc)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"

xcodebuild \
    -project "$SCRIPT_DIR/Tele Prompter.xcodeproj" \
    -scheme "Tele Prompter" \
    -configuration Release \
    -derivedDataPath "$SCRIPT_DIR/.derivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    build | xcpretty 2>/dev/null || xcodebuild \
        -project "$SCRIPT_DIR/Tele Prompter.xcodeproj" \
        -scheme "Tele Prompter" \
        -configuration Release \
        -derivedDataPath "$SCRIPT_DIR/.derivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=YES \
        AD_HOC_CODE_SIGNING_ALLOWED=YES \
        build

BUILT_APP=$(find "$SCRIPT_DIR/.derivedData/Build/Products/Release" -name "$APP_NAME.app" -maxdepth 2 | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "ERROR: Build output not found in DerivedData"
    exit 1
fi

echo "==> Copying to build/..."
cp -R "$BUILT_APP" "$APP_BUNDLE"

echo "==> Signing ad-hoc..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign -v "$APP_BUNDLE" && echo "==> Signature OK"

echo ""
echo "Build successful: $APP_BUNDLE"

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Tele Prompter"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS="$SCRIPT_DIR/Resources/entitlements.plist"

# Set SIGN_IDENTITY to use Developer ID signing + hardened runtime.
# Leave unset for ad-hoc signing (local dev / CI without certs).
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

echo "==> Building $APP_NAME (Release)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"

# Build without signing — we apply codesign manually after copy
# so SIGN_IDENTITY (which may contain spaces) is handled safely.
xcodebuild \
    -project "$SCRIPT_DIR/Tele Prompter.xcodeproj" \
    -scheme "Tele Prompter" \
    -configuration Release \
    -derivedDataPath "$SCRIPT_DIR/.derivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    build 2>&1 | grep -E "error:|BUILD|Signing"

BUILT_APP=$(find "$SCRIPT_DIR/.derivedData/Build/Products/Release" \
  -name "$APP_NAME.app" -maxdepth 2 | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "ERROR: Build output not found in .derivedData"
    exit 1
fi

echo "==> Copying to build/..."
cp -R "$BUILT_APP" "$APP_BUNDLE"

echo "==> Signing..."
if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
    echo "    Developer ID: $SIGN_IDENTITY"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "    Ad-hoc (local only)"
fi

codesign -v "$APP_BUNDLE" && echo "==> Signature OK"
echo ""
echo "Build successful: $APP_BUNDLE"

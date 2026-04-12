#!/usr/bin/env zsh
# =============================================================================
# ADL ShareFlow — Release Build Script
# =============================================================================
# Usage: ./build_release.sh [android|ios|all]
# =============================================================================

set -e

PLATFORM="${1:-all}"
MOBILE_DIR="$(cd "$(dirname "$0")/mobile" && pwd)"
KEYSTORE_DIR="$(cd "$(dirname "$0")" && pwd)/release_keys"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[Build]${NC} $1"; }
ok()  { echo -e "${GREEN}✓${NC} $1"; }
warn(){ echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; exit 1; }

# ---------------------------------------------------------------------------
# Keystore generation (Android)
# ---------------------------------------------------------------------------
generate_keystore() {
    mkdir -p "$KEYSTORE_DIR"
    KEYSTORE="$KEYSTORE_DIR/shareflow.keystore"

    if [[ -f "$KEYSTORE" ]]; then
        warn "Keystore already exists at $KEYSTORE"
        return
    fi

    log "Generating Android release keystore..."
    keytool -genkeypair \
        -alias shareflow \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -keystore "$KEYSTORE" \
        -storepass shareflow123 \
        -keypass shareflow123 \
        -dname "CN=ADL ShareFlow, OU=ADL, O=ADL, L=TLV, ST=IL, C=IL"

    ok "Keystore created: $KEYSTORE"
    echo ""
    echo "  KEYSTORE_PATH=$KEYSTORE"
    echo "  KEYSTORE_PASSWORD=shareflow123"
    echo "  KEY_ALIAS=shareflow"
    echo "  KEY_PASSWORD=shareflow123"
    echo ""
}

# ---------------------------------------------------------------------------
# Android build
# ---------------------------------------------------------------------------
build_android() {
    log "Building Android release..."
    cd "$MOBILE_DIR"

    # Setup keystore env vars if keystore exists
    KEYSTORE="$KEYSTORE_DIR/shareflow.keystore"
    if [[ -f "$KEYSTORE" ]]; then
        export KEYSTORE_PATH="$KEYSTORE"
        export KEYSTORE_PASSWORD="shareflow123"
        export KEY_ALIAS="shareflow"
        export KEY_PASSWORD="shareflow123"
        log "Using keystore: $KEYSTORE"
    else
        warn "No keystore found — using debug signing. Run with --keygen first."
    fi

    flutter clean
    flutter pub get

    # Build AAB (for Play Store)
    log "Building App Bundle (AAB)..."
    flutter build appbundle --release
    ok "AAB: build/app/outputs/bundle/release/app-release.aab"

    # Build APK (for direct install)
    log "Building APK..."
    flutter build apk --release --split-per-abi
    ok "APKs: build/app/outputs/flutter-apk/"
}

# ---------------------------------------------------------------------------
# iOS build (requires macOS + Xcode)
# ---------------------------------------------------------------------------
build_ios() {
    log "Building iOS release..."
    cd "$MOBILE_DIR"

    if [[ "$(uname)" != "Darwin" ]]; then
        err "iOS builds require macOS"
    fi

    if ! command -v xcodebuild &>/dev/null; then
        err "Xcode not found. Install from App Store then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    fi

    flutter clean
    flutter pub get

    log "Building iOS archive..."
    flutter build ipa --release

    ok "IPA: build/ios/ipa/"
    warn "Remember to configure signing in Xcode before distributing to App Store"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
echo "╔════════════════════════════════════╗"
echo "║   ADL ShareFlow — Release Builder  ║"
echo "╚════════════════════════════════════╝"
echo ""

if [[ "$1" == "--keygen" ]]; then
    generate_keystore
    exit 0
fi

case "$PLATFORM" in
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_android
        if [[ "$(uname)" == "Darwin" ]] && command -v xcodebuild &>/dev/null; then
            build_ios
        else
            warn "Skipping iOS (Xcode not available)"
        fi
        ;;
    *)
        echo "Usage: $0 [android|ios|all|--keygen]"
        exit 1
        ;;
esac

echo ""
ok "Build complete!"

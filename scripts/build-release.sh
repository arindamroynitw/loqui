#!/bin/bash
# build-release.sh - Loqui macOS Release Build Script
# Usage: ./scripts/build-release.sh [version]
# Example: ./scripts/build-release.sh 1.0

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
PROJECT_NAME="Loqui"
SCHEME="Loqui"
CONFIGURATION="Release"
BUILD_DIR="${PROJECT_DIR}/build/Release"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_DIR="${BUILD_DIR}/dmg"

# Get version from argument or Xcode project
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" -showBuildSettings | grep 'MARKETING_VERSION' | head -1 | awk '{print $3}')
fi
BUILD_NUMBER=$(xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" -showBuildSettings | grep 'CURRENT_PROJECT_VERSION' | head -1 | awk '{print $3}')

echo -e "${BLUE}========================================"
echo -e "  Loqui Release Build Script"
echo -e "  Version: ${VERSION} (Build ${BUILD_NUMBER})"
echo -e "========================================${NC}\n"

# Step 1: Clean
echo -e "${YELLOW}[1/7] Cleaning build directory...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
xcodebuild clean -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -configuration "${CONFIGURATION}"
echo -e "${GREEN}✓ Clean complete${NC}\n"

# Step 2: Build archive
echo -e "${YELLOW}[2/7] Building Release archive...${NC}"
xcodebuild archive \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY="-"
echo -e "${GREEN}✓ Archive created (ad-hoc signed)${NC}\n"

# Step 3: Export app bundle
echo -e "${YELLOW}[3/7] Exporting app bundle...${NC}"
mkdir -p "${EXPORT_PATH}"

cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"
echo -e "${GREEN}✓ App exported${NC}\n"

# Step 4: Verify app
echo -e "${YELLOW}[4/7] Verifying app structure...${NC}"
if [ ! -d "${EXPORT_PATH}/${PROJECT_NAME}.app" ]; then
    echo -e "${RED}✗ Error: ${PROJECT_NAME}.app not found${NC}"
    exit 1
fi
APP_VERSION=$(defaults read "${EXPORT_PATH}/${PROJECT_NAME}.app/Contents/Info.plist" CFBundleShortVersionString)
echo -e "${GREEN}✓ App version verified: ${APP_VERSION}${NC}\n"

# Step 5: Create DMG staging directory
echo -e "${YELLOW}[5/7] Creating DMG staging directory...${NC}"
mkdir -p "${DMG_DIR}"
cp -R "${EXPORT_PATH}/${PROJECT_NAME}.app" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"
echo -e "${GREEN}✓ DMG staging ready${NC}\n"

# Step 6: Create DMG
echo -e "${YELLOW}[6/7] Creating DMG...${NC}"
FINAL_DMG="${BUILD_DIR}/${PROJECT_NAME}-v${VERSION}.dmg"
rm -f "${FINAL_DMG}"

hdiutil create -volname "${PROJECT_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    -fs HFS+ \
    "${FINAL_DMG}"

echo -e "${GREEN}✓ DMG created: ${FINAL_DMG}${NC}\n"

# Step 7: Generate checksum
echo -e "${YELLOW}[7/7] Generating SHA256 checksum...${NC}"
shasum -a 256 "${FINAL_DMG}" > "${FINAL_DMG}.sha256"
echo -e "${GREEN}✓ Checksum saved${NC}\n"

# Summary
echo -e "${BLUE}========================================"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  DMG: ${FINAL_DMG}"
echo -e "  Checksum: ${FINAL_DMG}.sha256"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}⚠️  NOTE: This is an AD-HOC SIGNED build${NC}"
echo -e "   • Entitlements preserved (permissions work)"
echo -e "   • Users will see security warning on first launch"
echo -e "   • Workaround: Right-click → Open\n"
echo -e "${GREEN}Ready for distribution!${NC}"

#!/bin/bash
# Build a DMG installer for Matrix Shader
# Usage: ./build_dmg.sh [version]
# Must be run on macOS

set -euo pipefail

VERSION="${1:-1.0.0}"
DMG_NAME="MatrixShader-${VERSION}"
STAGING_DIR="/tmp/dmg-staging-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/../.."

echo "Building DMG: ${DMG_NAME}"

# Create staging directory
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/Matrix Shader"

# Copy required files
cp -R "$REPO_DIR/mac" "$STAGING_DIR/Matrix Shader/"
cp -R "$REPO_DIR/linux" "$STAGING_DIR/Matrix Shader/"
cp -R "$REPO_DIR/shaders-glsl" "$STAGING_DIR/Matrix Shader/"

# Remove unnecessary files
rm -rf "$STAGING_DIR/Matrix Shader/linux/__pycache__"
rm -rf "$STAGING_DIR/Matrix Shader/linux/tests/__pycache__"
rm -rf "$STAGING_DIR/Matrix Shader/mac/__pycache__"
rm -rf "$STAGING_DIR/Matrix Shader/mac/tests/__pycache__"
rm -rf "$STAGING_DIR/Matrix Shader/mac/dmg"
rm -rf "$STAGING_DIR/Matrix Shader/mac/Casks"

# Create install script visible in DMG
cat > "$STAGING_DIR/Install.command" << 'INSTALL_EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/Matrix Shader/mac/install_mac.sh"
INSTALL_EOF
chmod +x "$STAGING_DIR/Install.command"

# Create DMG
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

# Cleanup
rm -rf "$STAGING_DIR"

echo "Created ${DMG_NAME}.dmg"

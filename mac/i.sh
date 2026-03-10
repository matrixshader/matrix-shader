#!/bin/bash
# Matrix Shader - macOS One-Liner Install
# Usage: curl -fsSL https://matrixshader.com/install-mac.sh | bash

set -euo pipefail

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -fsSL "https://github.com/matrixshader/matrix-shader/releases/latest/download/install_mac.sh" -o "$TMPDIR/install_mac.sh"
chmod +x "$TMPDIR/install_mac.sh"
"$TMPDIR/install_mac.sh"

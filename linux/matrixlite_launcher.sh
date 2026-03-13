#!/bin/bash
# MatrixLite - Text-mode Matrix rain for any terminal
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYMOD_DIR="$SCRIPT_DIR"
exec python3 -B "$PYMOD_DIR/matrixlite.py" "$@"

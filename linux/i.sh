#!/bin/bash
# Matrix Shader - Linux One-Liner Installer
# Usage: curl -sL https://raw.githubusercontent.com/matrixshader/matrix-shader/master/linux/i.sh | bash
set -e
T=$(mktemp -d);trap "rm -rf $T" EXIT
echo -e "\033[32m  Downloading Matrix Shader...\033[0m"
curl -sL https://github.com/matrixshader/matrix-shader/releases/latest/download/matrixshader-linux-x86_64.tar.gz|tar xz -C "$T"
bash "$T/matrixshader-linux-x86_64/install.sh"

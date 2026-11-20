#!/usr/bin/env bash
# One-time setup inside WSL (Ubuntu): compiler + QNICE toolchain (assembler and bit2core).
# Run from Windows PowerShell:   wsl bash ./setup_wsl.sh      (in C:\phnx\Phoenix_MEGA65\build)
set -e
cd "$(dirname "$0")/.."

sudo apt-get update
sudo apt-get install -y build-essential dos2unix

# Files that came through Windows may have CRLF line endings, which break bash scripts
find M2M/QNICE CORE/m2m-rom -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.include' -o -name '*.source' \) -exec dos2unix -q {} +

cd M2M/QNICE/tools
yes '' | ./make-toolchain.sh

test -x ../assembler/qasm && test -x ./bit2core && echo "QNICE toolchain and bit2core are ready."

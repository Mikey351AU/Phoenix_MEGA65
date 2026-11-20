#!/usr/bin/env bash
# Builds bit2core from mega65-tools (github.com/MEGA65/mega65-tools, src/tools/bit2core.c, LGPL v3).
# Writes the current MEGA65 core header: board model id, core size and CRC32.
set -e
cd "$(dirname "$0")"
gcc -O2 -w -I. -o bit2core bit2core.c version.c
echo "bit2core built: $(pwd)/bit2core"
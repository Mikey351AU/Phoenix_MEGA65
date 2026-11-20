#!/usr/bin/env bash
# Shows whether the WSL side has everything the build needs.
echo "user: $(whoami)   folder: $(pwd)"
for t in gcc cc make dos2unix awk sudo; do
   printf "%-9s %s\n" "$t" "$(command -v "$t" || echo MISSING)"
done
if [ -x ../M2M/QNICE/assembler/qasm ]; then echo "qasm      built"; else echo "qasm      not built yet"; fi
if [ -x ../M2M/QNICE/tools/bit2core ]; then echo "bit2core  built"; else echo "bit2core  not built yet"; fi

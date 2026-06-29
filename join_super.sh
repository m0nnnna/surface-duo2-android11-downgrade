#!/bin/bash
# Reassemble super_built.img from the release parts (Linux/macOS/Git-Bash).
cd "$(dirname "$0")"
echo "Joining super_built.img.part0* -> super_built.img ..."
cat super_built.img.part0* > super_built.img
echo "Done. Verify with: sha256sum super_built.img  (compare to super_built.img.sha256)"

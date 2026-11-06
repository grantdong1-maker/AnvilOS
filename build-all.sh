#!/bin/bash
# AnvilOS: build variants sequentially and keep every artifact.
# Each lb build overwrites live-image-amd64.hybrid.iso, so this renames
# (and re-checksums) the ISO per variant before cleaning for the next.
#
#   sudo bash build-all.sh            # builds: lite gaming full
#   sudo bash build-all.sh lite full  # or just the ones you still need
set -e
cd "$(dirname "$0")"
VERSION=1.0.0
VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=(lite gaming full)

for v in "${VARIANTS[@]}"; do
    case "$v" in lite|gaming|full) ;; *) echo "E: unknown variant: $v"; exit 1 ;; esac
    echo "==> [$v] lb clean"
    lb clean
    echo "==> [$v] build"
    if [ "$v" = "full" ]; then
        bash build.sh    # full is build.sh's default target (no --full flag)
    else
        bash build.sh "--$v"
    fi
    src=live-image-amd64.hybrid.iso
    dst="anvilos-${VERSION}-${v}-amd64.iso"
    [ -f "$src" ] || { echo "E: no ISO produced for $v"; exit 1; }
    mv "$src" "$dst"
    sha256sum "$dst" > "$dst.sha256"
    echo "==> [$v] done: $dst ($(du -h "$dst" | cut -f1))"
done

echo
echo "All variants:"
ls -lh anvilos-${VERSION}-*-amd64.iso

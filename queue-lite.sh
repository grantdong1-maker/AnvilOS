#!/bin/bash
# Queue the lite build to run AFTER whatever build is currently running.
# Run as root in a terminal:  sudo bash queue-lite.sh
# It waits for the active build.sh/lb build to exit, banks the gaming ISO,
# then clean-builds lite. Everything is logged to queue-lite.log.
set -e
cd "$(dirname "$0")"
VERSION=1.0.0
exec > >(tee -a queue-lite.log) 2>&1
echo "=== queue-lite started $(date) ==="

echo "waiting for the current build to finish..."
while pgrep -f "bash build.sh|lb build" >/dev/null 2>&1; do
    sleep 30
done
sleep 15   # let the other build's cleanup/restore of disabled lists finish

# bank the gaming artifact only if it's newer than the qml-qt6 fix
# (an ISO older than that predates the System Monitor and was not built
# from the fixed tree - don't mislabel it)
GAMING_OK=0
if [ -f live-image-amd64.hybrid.iso ] && \
   [ live-image-amd64.hybrid.iso -nt config/package-lists/hud.list.chroot ]; then
    mv live-image-amd64.hybrid.iso "anvilos-${VERSION}-gaming-amd64.iso"
    rm -f live-image-amd64.hybrid.iso.sha256
    sha256sum "anvilos-${VERSION}-gaming-amd64.iso" > "anvilos-${VERSION}-gaming-amd64.iso.sha256"
    echo "gaming ISO banked: anvilos-${VERSION}-gaming-amd64.iso"
    GAMING_OK=1
else
    echo "WARNING: no up-to-date gaming ISO found; gaming will be rebuilt after lite"
fi

echo "starting lite build $(date)"
lb clean
bash build.sh --lite
mv live-image-amd64.hybrid.iso "anvilos-${VERSION}-lite-amd64.iso"
sha256sum "anvilos-${VERSION}-lite-amd64.iso" > "anvilos-${VERSION}-lite-amd64.iso.sha256"
echo "=== lite done $(date) ==="

if [ "$GAMING_OK" -eq 0 ]; then
    echo "starting gaming build (catch-up) $(date)"
    lb clean
    bash build.sh --gaming
    mv live-image-amd64.hybrid.iso "anvilos-${VERSION}-gaming-amd64.iso"
    sha256sum "anvilos-${VERSION}-gaming-amd64.iso" > "anvilos-${VERSION}-gaming-amd64.iso.sha256"
    echo "=== gaming done $(date) ==="
fi
ls -lh "anvilos-${VERSION}-"*-amd64.iso

#!/usr/bin/env bash
# Forge Linux ISO build wrapper.
#
# Usage:
#   ./build.sh           build the full gaming + AI image
#   ./build.sh --lite    skip nvidia/cuda/ai package lists (smaller image)
#   ./build.sh --help
#
# Must run as root (live-build chroot requires it); re-executes itself with sudo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNRECOGNISED=()


usage() {
    cat <<'EOT'
Forge Linux builder

  ./build.sh            full image (NVIDIA driver + CUDA + PyTorch included)
  ./build.sh --lite     skip nvidia.list + ai.list package lists
  ./build.sh --help
EOT
}


die() { echo "error: $*" >&2; exit 1; }

restore_disabled() {
    if [ -d "$SCRIPT_DIR/.disabled" ]; then
        mv "$SCRIPT_DIR"/.disabled/*.list.chroot "$SCRIPT_DIR/config/package-lists/" 2>/dev/null || true
        rmdir "$SCRIPT_DIR/.disabled" 2>/dev/null || true
        echo "restored disabled package lists"
    fi
}
trap restore_disabled EXIT INT TERM


while [ $# -gt 0 ]; do
    case "$1" in
        --lite) LITE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) UNRECOGNISED+=("$1") ;;
    esac
    shift
done
[ ${#UNRECOGNISED[@]} -eq 0 ] || die "unknown option: ${UNRECOGNISED[*]}"

# live-build needs root to enter the chroot.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "${BASH_SOURCE[0]}")" "$@"
fi

command -v lb >/dev/null 2>&1 || die "live-build not found: apt install live-build"
if ! lb --version | grep -Eq '[0-9]{8}'; then
    die "live-build is too old ($(lb --version | head -n1) from the distro repo).
        Install Debian's: wget https://deb.debian.org/debian/pool/main/l/live-build/live-build_20250814_all.deb && sudo apt install ./live-build_20250814_all.deb"
fi
command -v debootstrap >/dev/null 2>&1 || die "debootstrap missing: apt install debootstrap"

AVAILABLE=$(df --output=avail -B1G "$SCRIPT_DIR" | tail -n1)
if [ "${AVAILABLE:-0}" -lt 20 ]; then
    echo "warning: only ${AVAILABLE} GiB free in $(basename "$SCRIPT_DIR"); a full build needs ~20 GiB"
fi

if [ "${LITE:-0}" -eq 1 ]; then
    mkdir -p "$SCRIPT_DIR/.disabled"
    for list in nvidia ai; do
        src="$SCRIPT_DIR/config/package-lists/${list}.list.chroot"
        [ -f "$src" ] && mv "$src" "$SCRIPT_DIR/.disabled/"
    done
    echo "--lite mode: nvidia/ai package lists disabled for this build"
fi

cd "$SCRIPT_DIR"
echo "==> configuring image (lb build; logs in build.log)"
lb build 2>&1 | tee build.log
BUILD_RC=${PIPESTATUS[0]}
[ "$BUILD_RC" -eq 0 ] || die "lb build failed with $BUILD_RC; see build.log"

ISO_LIVE="$SCRIPT_DIR/live-image-amd64.hybrid.iso"
[ -f "$ISO_LIVE" ] || ISO_LIVE="$(find "$SCRIPT_DIR" -maxdepth 1 -name 'live-image-*.iso' -print -quit)"
[ -n "$ISO_LIVE" ] || die "build reported success but no iso found"

sha256sum "$ISO_LIVE" > "$ISO_LIVE.sha256"
echo "==> done"
ls -lh "$ISO_LIVE" "$ISO_LIVE.sha256"

#!/usr/bin/env bash
# GrantOS ISO build wrapper.
#
# Usage:
#   ./build.sh            full image: drivers (Intel/AMD/NVIDIA) + Steam + AI/CUDA stack
#   ./build.sh --gaming   gaming variant: drivers + Steam baked in, no AI/CUDA stack
#   ./build.sh --lite     barebones branded desktop: no NVIDIA/CUDA/Steam/dev/wine/flatpak
#   ./build.sh --help
#
# Must run as root (live-build chroot requires it); re-executes itself with sudo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNRECOGNISED=()


usage() {
    cat <<'EOT'
GrantOS builder ("anvil" 1.0)

  ./build.sh            full image   - Intel/AMD/Mesa + NVIDIA + Steam + AI/CUDA stack
  ./build.sh --gaming   gaming image - Intel/AMD/Mesa + NVIDIA + Steam, no AI/CUDA
  ./build.sh --lite     mini image   - branded Plasma desktop, no NVIDIA/CUDA/Steam,
                        no dev toolchain/wine/flatpak, docs/locales stripped
  ./build.sh --help

All variants carry the drivers baked into the image, so installed systems
get working GPU support without downloading anything.
EOT
}


die() { echo "error: $*" >&2; exit 1; }

restore_disabled() {
    if [ -d "$SCRIPT_DIR/.disabled" ]; then
        mv "$SCRIPT_DIR"/.disabled/*.list.chroot "$SCRIPT_DIR/config/package-lists/" 2>/dev/null || true
        mv "$SCRIPT_DIR"/.disabled/*.hook.chroot "$SCRIPT_DIR/config/hooks/live/" 2>/dev/null || true
        rmdir "$SCRIPT_DIR/.disabled" 2>/dev/null || true
        echo "restored disabled package lists / hooks"
    fi
}
trap restore_disabled EXIT INT TERM


while [ $# -gt 0 ]; do
    case "$1" in
        --gaming) GAMING=1 ;;
        --lite) LITE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) UNRECOGNISED+=("$1") ;;
    esac
    shift
done
[ ${#UNRECOGNISED[@]} -eq 0 ] 2>/dev/null || { usage >&2; die "unknown option: ${UNRECOGNISED[*]}"; }
[ "${GAMING:-0}" -eq 0 ] || [ "${LITE:-0}" -eq 0 ] || die "--gaming and --lite are mutually exclusive"

VARIANT=full
[ "${GAMING:-0}" -eq 1 ] && VARIANT=gaming
[ "${LITE:-0}" -eq 1 ] && VARIANT=lite

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

mkdir -p "$SCRIPT_DIR/.disabled"
disable() {
    src="$SCRIPT_DIR/config/$1"
    [ -f "$src" ] && mv "$src" "$SCRIPT_DIR/.disabled/"
}
case "$VARIANT" in
    lite)   disable package-lists/nvidia.list.chroot
            disable package-lists/ai.list.chroot
            disable package-lists/dev.list.chroot
            disable package-lists/gaming-heavy.list.chroot
            disable hooks/live/0300-steam-multilib.hook.chroot ;;
    gaming) disable package-lists/ai.list.chroot
            disable hooks/live/0460-lite-diet.hook.chroot
            disable hooks/live/0800-slim.hook.chroot ;;
    full)   disable hooks/live/0460-lite-diet.hook.chroot
            disable hooks/live/0800-slim.hook.chroot ;;
esac
if [ "$VARIANT" != full ]; then
    echo "==> variant: $VARIANT (disabled: $(ls "$SCRIPT_DIR/.disabled" 2>/dev/null || echo -))"
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
echo "==> done ($VARIANT build)"
ls -lh "$ISO_LIVE" "$ISO_LIVE.sha256"

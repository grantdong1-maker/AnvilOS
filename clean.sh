#!/usr/bin/env bash
# Reset build state. Use --purge for a full wipe (also removes the apt cache).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo "$(readlink -f "${BASH_SOURCE[0]}")" "$@"
cd "$(dirname "$0")"
lb clean noauto "${@:---purge}"
rm -f build.log
echo "clean done"

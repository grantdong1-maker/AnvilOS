# GrantOS 1.0 "anvil"

An OS built with the help of AI, optimised for AI and gaming. Built upon **Debian 13 (trixie)** using **live-build**.

## What is this

This repository is the complete build system for a Debian-live based distribution:

- **Live ISO** boots straight to a KDE Plasma desktop (user `forge`), no install required.
- **Variants**: `sudo bash build.sh` (full: drivers + Steam + AI/CUDA), `--gaming` (drivers + Steam, no AI), `--lite` (tiny test image).
- **GPU drivers baked in**: Mesa/VAAPI for Intel+AMD in all variants; NVIDIA driver in gaming/full; Steam in gaming/full (no download needed later).
- **`gforge` CLI** (`config/includes.chroot/usr/bin/gforge`): performance profiles (`gaming`, `training`, `balanced`), GPU status, `gforge doctor` health checks, cleanup.
- **Gaming-ready**: PipeWire audio, MangoHud, Feral GameMode, gamemode-optimized sysctls, Mesa/Vulkan drivers.
- **AI-training-ready** (full build): NVIDIA driver + CUDA from Debian repos, PyTorch/JAX stack builds.
- **Steam is intentionally not included** — install it later with `sudo apt install steam` if you want it.
- Optional Debian text installer (`debian-installer live`) for installing to disk.

## Build it yourself

Requirements: Debian (or a host with `debootstrap` + Debian's `live-build 20250814+`; Ubuntu's live-build is too old), ~20 GiB free disk, sudo.

```bash
git clone https://github.com/grantdong1-maker/GrantOS.git
cd GrantOS

# ~3.1 GiB ISO — everything except NVIDIA/CUDA/AI packages
sudo bash build.sh --lite

# ~5-6 GiB ISO — includes NVIDIA driver + CUDA + AI stack
sudo bash build.sh
```

Output: `live-image-amd64.hybrid.iso` (+ `.sha256`).

### Building on non-Debian hosts

Install Debian's live-build release (Ubuntu's `3.0~a57` is ancient and broken):

```bash
wget https://deb.debian.org/debian/pool/main/l/live-build/live-build_20250814_all.deb
sudo apt install ./live-build_20250814_all.deb debootstrap debian-archive-keyring
```

## Testing in a VM

Works in VirtualBox out of the box — the Debian kernel ships `vboxguest`, `vboxvideo` and `vboxsf` modules, so mouse, keyboard and dynamic display resizing work with zero guest-additions setup.

## Layout

```
auto/                    # build wrapper (invoked by lb build)
build.sh                 # sudo-aware entry point (--lite / full)
config/
  package-lists/         # base, desktop, gaming, development (+ nvidia, ai for full build)
  hooks/live/            # branding, flathub remote, kernel/modules consistency guard
  archives/              # apt pinning (kernel consistency across live-build passes)
  includes.chroot/       # gforge CLI, sysctls, profile.d branding
  preseed/               # debian-installer preseed
```

## Notable build guards

- `config/archives/kernel-consistency.pref(.binary)` — pins `linux-image-*`/`linux-headers-*` to the main archive in **both** live-build passes, so the binary-pass `dist-upgrade` can never inject a kernel newer than the frozen squashfs (which would produce boot-kernel ≠ modules-tree and kill input devices).
- `config/hooks/live/0900-kernel-consistency.hook.chroot` — fails the build loudly if the squashfs would ever ship a kernel without a matching modules tree.

## License

MIT — see `LICENSE`. Covers this repo's build system and scripts; the produced ISO is Debian + packages under their own licenses.

## Status

v1.0.0 "anvil" — Debian trixie snapshot; live ISO verified in VirtualBox.

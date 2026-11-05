# GrantOS changelog

## 1.0.1 "anvil" — 2026-11-05

- Full rebrand: `GrantOS 1.0 (anvil)` identity across the boot chain.
  - GRUB: custom splash + theme (`boot/grub/splash.png`, boot volume `grantos-1.0.0-amd64`).
  - Plymouth: new `grantos` boot splash (anvil logo, slow ember halo) derived from Debian's ceratopsian script theme; `quiet splash` boot by default; default set via `/etc/plymouth/plymouthd.conf`.
  - SDDM: breeze greeter with the GrantOS wallpaper + ember accent.
  - Plasma: GrantOS wallpaper (KDE wallpaper package), `GrantOS Dark` color scheme (Breeze Dark, ember `#d67a3c` accent) and matching Konsole palette/profile, applied on first login by `grantos-firstrun`.
  - `os-release` re-asserted in a hook (base-files overwrite guard); hostname `grantos`; live user display name fixed to "GrantOS User" (`grantos-branding.service`).
  - fastfetch config with ASCII anvil; terminal banner says GrantOS.
- Boot/boot-chain hardening: kernel-consistency pin kept (single 6.12.115+deb13.1-amd64 pair).
- Art sources committed under `art/` (`gen_art.py` regenerates wallpaper, logo, GRUB splash, Plymouth assets).

## 1.0.0 "anvil" — 2026-11-04

- First release: Debian 13 trixie amd64 base, live-build based.
- KDE Plasma 6 desktop; Vulkan/GameMode/MangoHud gaming stack.
- NVIDIA driver + nvidia-cuda-toolkit on the image; PyTorch/Jupyter CPU stack.
- `gforge` performance profile CLI (gaming / training / balanced / doctor / gpu / clean).
- Installers: debian-installer (menu) and Calamares (live desktop).
- Kernel-consistency fix: pins keep the running kernel and squashfs modules in sync (evdev dead-input root cause).

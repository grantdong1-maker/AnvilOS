# AnvilOS changelog

## 1.0.1 Hammer — 2026-11-05

- Full rebrand: `AnvilOS 1.0 (Hammer)` identity across the boot chain.
  - GRUB: custom splash + theme (`boot/grub/splash.png`, boot volume `anvilos-1.0.0-amd64`).
  - Plymouth: new `anvilos` boot splash (anvil logo, slow ember halo) derived from Debian's ceratopsian script theme; `quiet splash` boot by default; default set via `/etc/plymouth/plymouthd.conf`.
  - SDDM: breeze greeter with the AnvilOS wallpaper + ember accent.
  - Plasma: AnvilOS wallpaper (KDE wallpaper package), `AnvilOS Dark` color scheme (Breeze Dark, ember `#d67a3c` accent) and matching Konsole palette/profile, applied on first login by `anvilos-firstrun`.
  - `os-release` re-asserted in a hook (base-files overwrite guard); hostname `anvilos`; live user display name fixed to "AnvilOS User" (`anvilos-branding.service`).
  - fastfetch config with ASCII anvil; terminal banner says AnvilOS.
- Boot/boot-chain hardening: kernel-consistency pin kept (single 6.12.115+deb13.1-amd64 pair).
- Art sources committed under `art/` (`gen_art.py` regenerates wallpaper, logo, GRUB splash, Plymouth assets).
- Launcher button icon = anvil (hicolor theme icon + first-login retarget).
- **Build variants**: `--lite` (desktop + Mesa only), `--gaming` (drivers + Steam baked in, no AI/CUDA), default full (+ AI/CUDA). GPU drivers for Intel/AMD are baked into every variant (VAAPI/VDPAU + video firmware); NVIDIA via Debian's nvidia-driver in gaming/full. Steam (Valve's `steam-installer`) + i386 runtime baked into gaming/full via hook.
- `--lite` is now a barebones branded desktop: wine/flatpak/kernel-headers moved to a gaming-heavy list, dev toolchain dropped, and a lite-only hook strips non-English locales, man/info pages and package docs (copyrights kept).

## 1.0.0 Hammer — 2026-11-04

- First release: Debian 13 trixie amd64 base, live-build based.
- KDE Plasma 6 desktop; Vulkan/GameMode/MangoHud gaming stack.
- NVIDIA driver + nvidia-cuda-toolkit on the image; PyTorch/Jupyter CPU stack.
- `gforge` performance profile CLI (gaming / training / balanced / doctor / gpu / clean).
- Installers: debian-installer (menu) and Calamares (live desktop).
- Kernel-consistency fix: pins keep the running kernel and squashfs modules in sync (evdev dead-input root cause).

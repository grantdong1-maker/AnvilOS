# AnvilOS 1.0 "Hammer" — release notes

First tagged release. Debian 13 (trixie) live-build distribution for gaming
and AI work, with a fully custom boot chain and desktop experience:

- **Boot chain**: GRUB/syslinux menus, Plymouth (breathing forge), SDDM
  chamfered login card, branded lock screen and avatars — no stock Debian
  artwork anywhere in the chain.
- **Desktop**: custom "System Monitor" HUD (Afterburner-style, real sensor
  data + process management), AnvilOSDark colors, Inter font, AnvilOS icon
  set, curated favorites, "AnvilOS Software" instead of Discover.
- **Gaming**: NVIDIA driver + Steam baked in (gaming/full), Mesa/VAAPI for
  Intel/AMD everywhere, MangoHud slab overlay, Feral GameMode, `gforge`
  performance profiles.
- **Full variant adds**: CUDA + PyTorch/JAX stack for AI training.

## Assets (split parts, GitHub's 2 GB asset cap)

| Variant | Size | Contents |
|---|---|---|
| lite | 2.7 GB | branded minimal desktop |
| gaming | 6.5 GB | + NVIDIA driver, Steam |
| full | ~8 GB | + CUDA, AI-training stack |

Assemble and verify:

```bash
cat anvilos-1.0.0-<variant>-amd64.iso.part-* > anvilos-1.0.0-<variant>-amd64.iso
sha256sum -c anvilos-1.0.0-<variant>-amd64.iso.sha256
```

Flash to USB (8 GB+ for lite/gaming, 32 GB+ for full) and boot — live
session, user `forge`, password `live`.

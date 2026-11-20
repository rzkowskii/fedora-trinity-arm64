# Fedora Trinity ARM64 Remix — Build Plan

Goal: turn the working VM into a **reproducible Fedora 44 aarch64 remix image**
with Trinity preinstalled, buildable from the ARM64 VM itself.

## Tooling choice

| Option | Verdict |
|---|---|
| **Image Builder (osbuild)** | Fedora's current-generation image tool, but blueprint customization for third-party repos + custom kickstart-like logic on aarch64 remixes is still clumsier than kickstart for a DIY remix. Revisit when the remix stabilizes. |
| **Kiwi** | Capable, but not the Fedora-native mainstream; extra learning surface for no gain here. |
| **Lorax / livemedia-creator** | ✅ **Chosen.** The classic Fedora remix path: kickstart-driven, runs fine on aarch64, supports live ISO and disk images, and is what most Fedora spins still use. `livemedia-creator --make-disk` (raw image for VMs/SBCs) first; live ISO later. |
| appliance-creator | Legacy; superseded by livemedia-creator. |

## How the local Trinity repo is included
1. Build host (the VM) serves `repo/` — file URL for image builds run in the same VM:
   `--repo file:///home/trinity/fedora-trinity-arm64/repo` alongside the standard
   `fedora` + `updates` repos (kickstart `repo --name=tde-local --baseurl=file://…`).
2. For distributable images, the local repo must graduate to a hosted repo (or a
   COPR project with aarch64 chroots — cleanest long-term home; COPR builds
   aarch64 natively and would replace scripts 10–12 entirely).

## Status: first image built 2026-07-07
`fedora-trinity-arm64-20260707.img` (11 GiB raw / 3.2 GiB used, GPT: 600M ESP +
1G /boot + 9.3G ext4 root) — built by `scripts/40-build-remix-image.sh`, Trinity
payload verified by loop-mount inspection. Boot test in a fresh VM: pending.

## Build procedure (inside the ARM64 VM)
```sh
sudo dnf install lorax-lmc-novirt anaconda-tui pykickstart
sudo livemedia-creator \
  --make-disk \
  --no-virt \
  --ks kickstart/fedora-trinity-arm64.ks \
  --project "Fedora Trinity Remix" \
  --releasever 44 \
  --image-name fedora-trinity-arm64.img \
  --resultdir /var/tmp/tde-image
```
`--no-virt` runs anaconda directly in the build VM (no nested virt on Apple
Silicon Parallels). ksflatten + `ksvalidator` the kickstart first.

## What remains before calling it a distro
- [ ] Branding: cannot ship Fedora trademarks on a remix → `fedora-release` stays,
      but "Fedora Remix" naming/logo rules apply; replace `fedora-logos` with
      `generic-logos` in the kickstart. **Blocked by packaging**: upstream
      `trinity-tdebase` hard-Requires `fedora-logos`, which conflicts with
      generic-logos. Fix: rebuild tdebase with `Requires: system-logos`
      (one-line spec change — also an upstream PR candidate for
      TDE/tde-packaging). Until then images are TEST-ONLY, not redistributable.
- [ ] Signing: local RPMs are unsigned → sign with a project GPG key, enable
      `gpgcheck=1`, publish the key.
- [ ] Repo hosting: move `repo/` to a public host or COPR (aarch64 chroots).
- [ ] tdm vs lightdm decision finalized after Stage 7 validation.
- [ ] Live ISO variant (`--make-iso`) + UEFI boot testing on raw Apple-Silicon-VM
      and real ARM64 hardware (RPi4/5, Ampere) — virtio-gpu assumptions must be
      relaxed to include simpledrm/vc4/etc. (modesetting driver covers all).
- [ ] Wayland track (Labwc/wlroots + Trinity shell + XWayland) — after X11 remix ships.
- [ ] CI: rebuild chain + image build on TDE point releases (R14.1.x).

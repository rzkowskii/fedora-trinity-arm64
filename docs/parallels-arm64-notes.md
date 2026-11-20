# Parallels on Apple Silicon — Fedora ARM64 Guest Notes

Host: macOS, Apple M4 Max, Parallels Desktop **26.4.0**.
Guest: Fedora 44 aarch64 (VM `Fedora_Trinity`, 8 vCPU / 16 GiB after resize on 2026-07-06).

## Display driver
- The VM exposes a **virtio-gpu** device (virtio-mmio transport, no PCI GPU).
  Kernel driver `virtio_gpu` binds it: `/dev/dri/card1` + `/dev/dri/renderD128`,
  16 virtual connectors (`Virtual-1` … `Virtual-16`).
- Consequence for Xorg: the stock **`modesetting`** driver on KMS is the correct and
  only sensible choice. There is **no Parallels-specific Xorg video driver for ARM64**
  (the old `prl_tg`/video-toolgate X driver is x86-only). Do not install
  `xorg-x11-drv-*` vendor drivers.
- 3D: `renderD128` exists; virgl acceleration depends on Parallels' virtio-gpu
  feature set. TDE (TQt3) is pure 2D X11 rendering, so this does not gate the project.

## Parallels Guest Tools on ARM64
- The **ARM64 Linux guest tools ISO ships with Parallels Desktop** and installs
  cleanly on Fedora 44 aarch64 (`prlctl installtools` + `/mnt/install
  --install-unattended-with-deps`, version 26.4.0.57513). x86_64 assumptions do not
  apply, but no x86_64-only tooling was needed.
- What you get on ARM64: `prltoolsd` (control channel → `prlctl exec`, IP reporting),
  time sync, clipboard sharing daemon, shared-folder support (virtiofs), dynamic
  resolution helper (`prlres`/X integration where X is present).
- No `prl_*` kernel modules load on this ARM64 build — integration is
  userspace + virtio (virtiofs module provides shared folders).
- Install warnings observed (non-fatal): SELinux modules `prltimesync` and
  `prltoolsd` failed `semodule` (AST resolve error) — daemons still run under
  `unconfined`/permissive domains; watch `ausearch -m avc` if they misbehave.
  Icon copy to `/usr/share/icons/hicolor/48x48/apps/` failed (dir absent on
  minimal install) — cosmetic.

## Resolution handling
- virtio-gpu KMS accepts mode changes; with Guest Tools running, resizing the
  Parallels window should trigger a resolution change via the tools daemon once
  an X session with RandR is up.
- Manual fallback inside X: `xrandr --output Virtual-1 --mode 1920x1080` (or
  `--auto`). List modes with `xrandr -q`.
- Console (KMS) resolution can be pinned with kernel arg `video=Virtual-1:1920x1080`
  if ever needed; not applied.

## Clipboard integration
- Parallels "Shared clipboard" is enabled in VM config and the ARM64 tools include
  the clipboard agent, but it requires the tools' X11 helper running **inside the
  session**. Status with a Trinity session: *to be validated in Stage 7* — TDE's
  klipper may need `prlcp` running; if absent, copy/paste Mac↔guest won't work and
  should be documented as a known limitation.

## Mouse / keyboard integration
- SmartMouse (unpinned pointer) works through the tools daemon; before tools were
  installed the console grabbed the pointer.
- **Host-side synthetic keystrokes (macOS accessibility events) are dropped by the
  Parallels console** — discovered during bootstrap. Reliable host→guest keyboard
  injection is `prlctl send-key-event <vm> -s <decimal PS/2 set-1 scancode>`
  (hex not accepted; one call = press+release; wrap shifted chars in
  `-e press`/`-e release` shift events). Only relevant for pre-SSH bootstrap.

## Networking
- Shared (NAT) network: guest `10.211.55.4/24`, Mac host reachable at
  `10.211.55.2`, internet works. DHCP — address may drift; use
  `prlctl list -i` to re-discover.

## Summary for the remix
Nothing Parallels-specific needs to be baked into the Fedora Trinity remix image:
virtio-gpu + modesetting + libinput are generic. Guest Tools remain an optional
per-VM post-install step (`prlctl installtools`).

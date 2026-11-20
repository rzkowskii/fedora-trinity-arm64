# System Inventory — Fedora_Trinity VM

Date: 2026-07-06 · Discovery log: `logs/01-discovery-20260706-163145.log`

## Host / control path

| Item | Value |
|---|---|
| Host | macOS on Apple Silicon, Parallels Desktop 26.4.0 |
| VM name | `Fedora_Trinity` (Parallels, shared networking) |
| Guest IP | 10.211.55.4 (DHCP; re-check with `prlctl list -i Fedora_Trinity`) |
| CLI access | `ssh fedora-trinity` (key auth, user `trinity`, wheel) and `prlctl exec Fedora_Trinity <cmd>` (runs as root; Guest Tools 26.4.0-57513 installed 2026-07-06) |

## Guest OS

| Item | Value |
|---|---|
| OS | Fedora Linux 44 (Forty Four), stable, EOL 2027-05-19 |
| Kernel | 7.0.14-201.fc44.aarch64 |
| Architecture | **aarch64** (confirmed) |
| Boot | **UEFI**, GRUB, btrfs root (`subvol=root`), separate `/boot` (2G) + ESP (600M) |
| CPU | 2 vCPU (⚠ low for TDE source builds — consider raising via `prlctl set --cpus` before Stage 4) |
| RAM | 3.8 GiB + 3.8 GiB zram swap (⚠ likewise low for parallel C++ builds) |
| Disk | 40 GB total, 36 GB free on `/` (btrfs, shared with `/home`) |
| SELinux | Enforcing |
| Default target | `multi-user.target` (no GUI installed — expected, minimal install) |

## Graphics stack

| Item | Value |
|---|---|
| GPU | `virtio_gpu` (virtio-mmio), DRM nodes `/dev/dri/card1` + `renderD128`, 16 virtual connectors |
| Implication | Xorg `modesetting` driver will work; no vendor driver needed |
| Xorg availability | `xorg-x11-server-Xorg` 21.1.23-1.fc44, `xorg-x11-xinit` 1.4.3-4.fc44, `xorg-x11-drv-libinput` 1.5.0-4.fc44 — all available for aarch64 |
| Wayland packages installed | none (minimal system) |

## Enabled repositories

- `fedora` (Fedora 44 aarch64)
- `updates`
- `fedora-cisco-openh264`

## Trinity/TDE package availability

| Source | Result |
|---|---|
| Fedora repos (`dnf search trinity`, tdelibs/tdebase/tqt) | **Nothing** |
| COPR (`api_3/project/search?query=trinity`) | **No Trinity projects, none with aarch64 chroots** |
| TDE upstream mirror `mirror.ppa.trinitydesktop.org/trinity/rpm/f44/` | **Exists for Fedora 44** — R14.1.6 (`trinity-r14`): `RPMS/x86_64`, `RPMS/noarch`, full `SRPMS/` with repodata. **No aarch64 binary RPMs.** |

**Conclusion:** binary install path (A) is impossible for aarch64; upstream provides Fedora-44-compatible **SRPMs** → the practical route is **Path B: rebuild upstream SRPMs locally for aarch64** (see `docs/package-source-decision.md`).

## Parallels integration state

- Guest Tools 26.4.0-57513 installed from `prl-tools` ISO (`/mnt/install --install-unattended-with-deps`), `prltoolsd` **active**.
- Install warnings: SELinux modules `prltimesync`/`prltoolsd` failed to resolve AST (semodule failed) — services run anyway; revisit if SELinux denials appear. Icon copy to hicolor failed (cosmetic, dir absent on minimal install).
- No `prl_*` kernel modules loaded on ARM64 (expected — ARM64 tools are mostly userspace + virtio).
- Network: guest reaches the internet (Trinity mirror answered HTTP 200 from guest).

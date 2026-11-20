# Package Manifest — Fedora Trinity ARM64

Status: **complete** — all 14 SRPMs (12 TDE chain + fileshareset + htdig) rebuilt
for aarch64 on 2026-07-06; ~100 binary RPMs in `repo/` (see `ls repo/` for the
authoritative NEVRA list). Core desktop installed in the reference VM (78 pkgs).

## TDE source chain (build order, TDE R14.1.6, .fc44 SRPMs rebuilt for aarch64)

| # | SRPM | Purpose | Binary packages (expected) |
|---|---|---|---|
| 1 | trinity-tqt-3.5.0 | TQt3 toolkit | libtqt3-mt, libtqt3-mt-devel, tqt3-dev-tools |
| 2 | trinity-tde-cmake-14.1.6 | TDE cmake macros (BuildRequires of everything below) | trinity-tde-cmake |
| 3 | trinity-tqtinterface-4.2.0 | TQt abstraction layer | libtqt4, libtqt4-devel |
| 4 | trinity-libart-lgpl-2.3.22 | 2D rendering lib | trinity-libart-lgpl(+devel) |
| 5 | trinity-arts-1.5.10 | Sound server (tdelibs BuildRequires) | trinity-arts(+devel) |
| 6 | trinity-dbus-tqt-0.63 | D-Bus TQt bindings | libdbus-tqt-1(+devel) |
| 7 | trinity-dbus-1-tqt-0.9 | D-Bus-1 TQt bindings | libdbus-1-tqt(+devel) |
| 8 | trinity-avahi-tqt-0.6.30 | Avahi TQt (tdelibs BuildRequires) | libavahi-tqt(+devel) |
| 9 | trinity-tqca-1.0 | TQt crypto architecture | libtqca(+devel) |
| 10 | trinity-filesystem-14.1.6 | /opt/trinity hierarchy + profile.d | trinity-filesystem |
| 11 | trinity-tdelibs-14.1.6 | TDE core libraries | trinity-tdelibs(+devel) |
| 12 | trinity-tdebase-14.1.6 | Base desktop: **twin, kicker, kdesktop, ksmserver, konsole, tdm**, control center, etc. | trinity-tdebase(+subpackages incl. -tdm, -konsole…) |

## Fedora-side runtime set (from Fedora repos, aarch64)
See `scripts/00-bootstrap-fedora-arm64.sh` for the authoritative list:
- Xorg: xorg-x11-server-Xorg, xorg-x11-xinit, xorg-x11-drv-libinput, xauth, mesa-dri-drivers
- DM: lightdm, lightdm-gtk (tdm under evaluation post-validation)
- D-Bus: dbus, dbus-x11
- Fonts: dejavu-*, liberation-*, xorg-x11-fonts-misc, fontconfig
- Sound: pipewire(+alsa,+pulseaudio), wireplumber, alsa-utils
- Net: NetworkManager, network-manager-applet

## Deferred (not in first milestone)
- trinity-tdeartwork, tdemultimedia, tdenetwork, tdepim, tdeutils, tdegraphics
- pinentry-tqt, polkit-tqt, pytqt/sip4-tqt bindings
- gtk3-tqt-engine (GTK app theming)
- akode (media decoding for arts frontends)

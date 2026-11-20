# Validation Results — Trinity R14.1.6 on Fedora 44 aarch64

Date: 2026-07-06 · Validator: `scripts/90-validate-tde-session.sh` + live-session evidence
Environment: VM `Fedora_Trinity` (Parallels, 8 vCPU / 16 GiB), lightdm + Xorg (modesetting on virtio-gpu)

## Automated checklist

| Check | Result |
|---|---|
| `uname -m` is aarch64 | ✅ PASS |
| Binaries present: starttde, twin, kicker, kdesktop, ksmserver, konsole | ✅ PASS (all, `/opt/trinity/bin`) |
| Xorg starts (via lightdm) | ✅ PASS (`/usr/libexec/Xorg :0`, 2 non-fatal (EE) lines) |
| X answers on :0 (`xdpyinfo`) | ✅ PASS |
| konsole binary runs | ✅ PASS |
| Trinity session starts (login → ksmserver) | ✅ PASS |
| twin running in live session | ✅ PASS |
| kicker running in live session | ✅ PASS |
| kdesktop running in live session | ✅ PASS |
| konsole opens a window | ✅ PASS (visual: window + taskbar entry; automated check is process-level) |
| graphical.target default | ✅ PASS |
| lightdm enabled | ✅ PASS |
| systemd reboot path resolvable | ✅ PASS (check fixed: `systemctl show`, `status` exits 3 for inactive targets) |
| Logout/reboot full cycle | ✅ PASS — VM rebooted to lightdm greeter unattended |
| Logs captured | ✅ PASS (`/var/log/Xorg.0.log`, lightdm logs, project `logs/`) |

## Live-session evidence (screenshots in session scratchpad)
1. lightdm GTK greeter with `trinity` user (greeter.png)
2. KPersonalizer "Welcome to Trinity R14.1.6" in twin-decorated window (session1.png)
3. Full desktop: kdesktop icons + wallpaper, kicker panel (menu, 4-desktop pager, taskbar, clock, klipper tray), Trinity Help Center + KTip windows (session4.png)
4. Konsole with live shell `[trinity@fedora ~]$`, title "trinity@fedora:~ - Shell - Konsole" (session5.png)

## Known quirks
- First login opens KPersonalizer + Help Center + KTip (expected TDE first-run behaviour).
- `xwininfo -root -tree` under root's auth cookie does not enumerate the session's client windows reliably; window-mapping verification is visual (prlctl capture) — automated check demoted to process-level.
- Xorg.0.log contains 2 `(EE)` lines (initial modesetting probe noise; no functional impact).
- tdm installed but not yet enabled — lightdm chosen for the first milestone (see docs/session-startup.md rationale); tdm evaluation is a follow-up.

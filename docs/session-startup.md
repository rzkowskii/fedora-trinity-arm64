# Trinity Session Startup — Testing & Recovery

Target: Fedora 44 aarch64 in Parallels, TDE R14.1.6 (local aarch64 rebuild).
All commands run **inside the guest** (`ssh fedora-trinity`, or the VM console).

## Launch paths (in order of preference)

### 1. Display manager (lightdm)
```sh
sudo systemctl set-default graphical.target
sudo systemctl start lightdm        # or reboot
```
Select the **Trinity** session in the lightdm greeter, log in as `trinity`.

Why lightdm and not tdm for the first milestone: lightdm is packaged and
maintained by Fedora for aarch64 and has no dependency on the freshly rebuilt
TDE stack, so a Trinity bug cannot lock us out of the graphical login path.
tdm (part of tdebase) can be swapped in later:
```sh
sudo systemctl disable lightdm && sudo systemctl enable tdm   # after testing tdm manually
```

### 2. startx from the console
As user `trinity` on a console TTY (not over ssh):
```sh
startx                              # uses ~/.xinitrc → exec /opt/trinity/bin/starttde
```

### 3. Raw xinit fallback
```sh
xinit /opt/trinity/bin/starttde -- :1 vt2
```

## Log capture

| What | Where |
|---|---|
| Xorg session log | `/var/log/Xorg.0.log` (DM) or `~/.local/share/xorg/Xorg.*.log` (startx) |
| lightdm | `/var/log/lightdm/` (`lightdm.log`, `seat0-greeter.log`, `x-0.log`) |
| Trinity session stdout/stderr | `~/.xsession-errors` |
| systemd units | `journalctl -b -u lightdm --no-pager` |
| One-shot capture for a bug report | `journalctl -b --no-pager > /tmp/journal.txt; cp ~/.xsession-errors /tmp/` |

## Inspecting failures
```sh
systemctl --failed                          # failed units
journalctl -b -p err --no-pager | tail -50  # errors this boot
grep -iE '\(EE\)|fatal' /var/log/Xorg.0.log # Xorg errors
```

## Recover to console if the GUI wedges
```sh
# from ssh (always works — GUI cannot lock you out of sshd):
sudo systemctl isolate multi-user.target    # stop GUI now
sudo systemctl set-default multi-user.target # keep it off across reboots
# from the VM console: Ctrl+Alt+F3 for a text TTY
```
Because the guest is a Parallels VM, a hard-stuck GUI can also be recovered
from the Mac host: `prlctl restart Fedora_Trinity` (last resort — uncleanly
kills the session but not the safe btrfs root).

## Quick session smoke-test (X + TDE apps, no full login)
```sh
# X server alone answers?
sudo systemctl start lightdm; sleep 5; DISPLAY=:0 xdpyinfo | head -5
# Trinity app launches on the DM's X? (as trinity, with X access)
DISPLAY=:0 /opt/trinity/bin/konsole --version
```

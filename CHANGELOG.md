# Changelog — Fedora Trinity ARM64

All notable changes to the project and to the Fedora_Trinity VM.

## 2026-11-20

### Re-check against TDE R14.1.7, and first public release
- The mirror now carries R14.1.7; the pinned R14.1.6 source packages return 404. Scripts 10 and 11 are pinned to the R14.1.7 names.
- R14.1.7 is signed with a new key (`RPM-GPG-KEY-trinity-2026`, fingerprint `433F 98C4 6DF3 A41D 1277 9D29 BAED FADB 0180 0978`). Scripts 10 and 12 now fetch and import both keys. All 14 source packages verify.
- New build delta: the R14.1.7 SRPMs carry the 14.1.7 tarball, but each spec still falls back to `tde_version 14.1.6` unless the build farm defines it. First failure: trinity-tqt died with "Bad file: …/SOURCES/trinity-tqt-14.1.6.tar.gz". Fix: `config_opts['macros']['%tde_version'] = '14.1.7'` in the mock config (script 12).
- Rebuilt in a clean Fedora 44 aarch64 Lima VM (10 vCPU, 16 GiB, mock 6.9): 14 of 14 SRPMs, 90 RPMs, about 15 minutes. Installed with script 20 and started `starttde` on Xvfb: twin, kicker, kdesktop, ksmserver and konsole ran, and `tde-config --version` reports `TDE: R14.1.7`. Details in `docs/r14.1.7-rebuild-2026-11-20.md`.
- Not re-run: lightdm login (script 30), the validation script (90) and the remix image build (40).
- Published to GitHub without binary RPMs: `repo/` is now gitignored build output.

## 2026-07-07

### Publication
- Git repo initialized on a private GitLab instance, with `logs/` and SRPMs gitignored.

### Stage 8 — remix image build (livemedia-creator --no-virt), fixes en route
- lmc refuses a pre-existing resultdir; logfile moved outside it. `--nomacboot` required (no hfsplus-tools on aarch64).
- lmc has no `--image-size`; disk size = sum of kickstart `part` sizes, and a bare `part / --grow` (size=None) crashes size arithmetic → explicit `--size=9500 --grow`.
- Plain `part / --fstype=btrfs` fails to mount inside the anaconda namespace ("wrong fs type" on p3) → root switched to ext4; btrfs-with-subvolumes deferred.
- anaconda (44.30, cmdline/image mode) registers kickstart `repo` lines but never loads their metadata before %packages resolution — file:// AND http:// alike ("No match for argument: trinity-*"). Workaround: Trinity set moved to `%post --erroronfail` dnf install against a loopback HTTP server (127.0.0.1:8123) started by script 40.
- `reqpart` removed (duplicated the explicit ESP); test user trinity added (documented); `--leavebootorder` added.
- **anaconda bug found**: `EFIBase.efibootmgr()` skips efibootmgr for image installs but `return ""` fails the caller's `rc != 0` check → every UEFI image build dies with "Failed to set new efi boot target". Script 40 patches the skip paths to `return 0` (backup kept; upstream-report candidate for bugzilla.redhat.com against anaconda).

## 2026-07-06

### VM / host configuration
- Installed an SSH public key from the Mac host into `trinity@Fedora_Trinity:~/.ssh/authorized_keys`; added a `Host fedora-trinity` alias to the Mac's `~/.ssh/config`.
- Installed Parallels Guest Tools 26.4.0-57513 in guest (`prlctl installtools` + `/mnt/install --install-unattended-with-deps`). `prltoolsd` active; `prlctl exec` functional. Known warnings: two SELinux modules (prltimesync, prltoolsd) failed to load; hicolor icon copy failed (cosmetic).
- Installed guest build prerequisites for tools: gcc, gcc-c++, make, perl, kernel-devel/headers 7.0.14-201.fc44, elfutils-libelf-devel, checkpolicy, selinux-policy-devel.
- Rebooted guest once after tools install.

### Project
- Created project skeleton: `docs/`, `scripts/`, `logs/`, `kickstart/`.
- Stage 1 discovery completed → `docs/system-inventory.md` (+ raw log in `logs/`).
- Established package-source finding: TDE upstream has f44 SRPMs but no aarch64 binaries; no Fedora/COPR alternatives.
- Resized VM 2→8 vCPU, 4→16 GiB RAM (`prlctl set`) for source builds.
- Stage 4 pipeline created (scripts 10/11/12) and started; all 12 SRPMs verified against the official Trinity GPG key.

### Build fixes discovered (encoded in scripts)
- Mock config: `config_opts[f'{config_opts.package_manager}.conf']` fails on f44 (package_manager is an unexpanded Jinja template at parse time) → use `config_opts['dnf5.conf']`.
- Fedora's `brp-remove-la-files` buildroot policy deletes `.la` files that TDE specs package and TDE's autotools consume → disabled via `config_opts['macros']['%__brp_remove_la_files'] = '%{nil}'` in the mock chroot. First failure mode: trinity-tqt died in `%files` with "File not found: …/libtqt-mt.la".
- `trinity-tde-cmake` is a mandatory BuildRequires of every TDE package after TQt (audit: `rpm -qpR` over all chain SRPMs) — added to download set and build chain.
- F44 buildroots ship no compilers and TDE specs partly omit `BuildRequires: gcc` → `chroot_additional_packages = 'gcc gcc-c++'`.
- TDE specs use legacy `cd build; %cmake ..; make` → `%__cmake_in_source_build 1` **and** `%_cmake_generator '"Unix Makefiles"'` (F44 defaults to Ninja; the macro expands unquoted so the value carries embedded quotes).
- Chain resume logic switched from repo-glob to marker files in `logs/.built/` (SRPM names ≠ binary package names).
- Incident: backticks in an unquoted heredoc comment in script 12 executed `mkdir build` as root during config generation (created stray `/build`, removed); comment rewritten without backticks.
- rpm 6 ignores `%_debugsource_packages 0` in ~/.rpmmacros → debug subpackages disabled entirely (`%debug_package %{nil}`); empty debugsourcefiles.list under ccache was hard-failing tqtinterface.
- Chain order: trinity-filesystem moved before arts (it is a BuildRequires of arts and tdelibs).
- Fedora `check-rpaths` brp rejects TDE's intentional `/opt/trinity/lib64` RPATH (ERROR 0002, fails arts %install) → `%__brp_check_rpaths %{nil}` in the chroot.
- Monitor hygiene: liveness pgrep pattern must be self-match-proof (`pgrep -f "[1]1-build-tde-chain"`).
- tdelibs: CMake CMP0109 OLD rejects Fedora's executable-but-unreadable utempter helper → `%__cmake` overridden to pass `-DCMAKE_POLICY_DEFAULT_CMP0109=NEW`.
- tdebase: needs `htdig` (BuildRequires) and `fileshareset` (tdelibs runtime Requires) — both TDE-mirror SRPMs, added to chain.
- tqca: `%prep` uses perl without BuildRequires → `perl-interpreter` added to chroot baseline.

### Milestone: working Trinity session (2026-07-06 evening)
- **All 14 SRPMs built for aarch64**; tdelibs 4 min, tdebase 5 min on 8 vCPU M4 Max.
- Installed 78 packages in VM via `scripts/20` (local dnf repo `/etc/yum.repos.d/tde-local.repo`).
- Session config via `scripts/30`: lightdm + upstream `tde.desktop` xsession + `~/.xinitrc` fallback; default target graphical.
- **Validated: lightdm greeter → TDE login → full desktop** (twin, kicker, kdesktop, ksmserver, konsole with live shell), plus unattended reboot-to-greeter cycle. 17+ automated checks PASS (`docs/validation-results.md`).
- Validation script fixes: Xorg lives at /usr/libexec/Xorg under DMs; `systemctl status` exits 3 for inactive targets (use `show`); window-mapping check demoted to process-level (root-cookie xwininfo unreliable).

### Stage 8 completed (2026-07-07 afternoon)
- **Remix image builds successfully** (attempt 10): `fedora-trinity-arm64-20260707.img`, 11 GiB raw / 3.2 GiB used, stored in guest at `~/fedora-trinity-arm64-images/`. Trinity payload verified via loop-mount (all session binaries, 37 trinity RPMs, tde.desktop, EFI fallback, graphical default, trinity user).
- Final two fixes: (1) `%post` needed `set -e` — a failing dnf was masked by the trailing `rm`, so `--erroronfail` never fired and attempt 9 produced a Trinity-less "success"; (2) upstream trinity-tdebase hard-Requires fedora-logos, conflicting with the remix's generic-logos swap → test image keeps fedora-logos; distributable images blocked on a tdebase rebuild with `Requires: system-logos` (upstream PR candidate).

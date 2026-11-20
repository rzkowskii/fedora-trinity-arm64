# Package Source Decision — Trinity on Fedora 44 aarch64

Date: 2026-07-06

## Options evaluated (in required order)

### A. Existing Fedora/aarch64 Trinity binary packages — ❌ not available
- Fedora repos (`fedora`, `updates`): `dnf search trinity` and explicit lookups for
  `*tqt*`, `*tdelibs*`, `*tdebase*` return **nothing** (see `docs/system-inventory.md`).
- COPR search API (`project/search?query=trinity`): no Trinity projects at all, and
  no hits with aarch64 chroots.
- TDE upstream binary repo for Fedora 44
  (`https://mirror.ppa.trinitydesktop.org/trinity/rpm/f44/trinity-r14/RPMS/`):
  contains **only `x86_64/` and `noarch/`**. The arch list files at the release root
  (`trinity-r14-x86_64.list`, `trinity-r14-noarch.list`, `trinity-r14-SRPMS.list`)
  confirm no aarch64 build exists upstream.

### B. Rebuild upstream Fedora-compatible SRPMs for aarch64 — ✅ **CHOSEN**
- Upstream publishes a complete, current SRPM repository for exactly our release:
  `https://mirror.ppa.trinitydesktop.org/trinity/rpm/f44/trinity-r14/SRPMS/`
  (TDE **R14.1.6**, `.fc44` dist tag, with repodata — a proper dnf-consumable source repo).
- These SRPMs are built by the Trinity project itself (provenance: official TDE
  release infrastructure, GPG key `RPM-GPG-KEY-trinity` published at the f44 root).
- The specs are already Fedora-44-compatible; the only thing missing upstream is an
  aarch64 build farm. Nothing in TQt3/TDE is x86-specific — Debian/Ubuntu arm64
  builds of the same release exist, so the codebase is known to build on ARM64.
- Local rebuild gives us binary RPMs with full dnf/RPM lifecycle management and a
  local repo we can feed straight into the Stage 8 remix kickstart.

### C. Build TDE from source tarballs into our own specs — not needed
Fallback only if individual SRPMs fail to rebuild on aarch64; failures will be
isolated per package and documented in `docs/build-failures.md` rather than
switching the whole strategy.

### D. Random unofficial binary repos — rejected
None exist for this target anyway; would fail the provenance rule.

## Consequences
- Build with **mock** (`fedora-44-aarch64` chroot) so BuildRequires resolve cleanly
  and output is reproducible; successful packages land in a local repo
  (`repo/`, createrepo_c) that subsequent mock builds and the final system consume.
- GPG: local packages are unsigned; the local repo is enabled with
  `gpgcheck=0` + `priority` scoping. Upstream SRPM sources are fetched over HTTPS
  from the official mirror; the Trinity GPG key is imported for SRPM signature
  verification where signatures exist.
- Build order follows the TDE dependency chain (tqt3 → tqtinterface → arts →
  dbus-tqt/dbus-1-tqt → tdelibs → tdebase → apps); exact list in
  `docs/package-manifest.md` as it firms up.
